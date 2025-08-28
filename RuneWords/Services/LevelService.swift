import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import OSLog

/// Service for managing game levels with catalog-based indexing
/// WO-001: Refactored to use LevelCatalog for robust level management
/// Part B: Added local catalog loading with remote switch support
@MainActor
final class LevelService: ObservableObject {
    static let shared = LevelService()
    
    // MARK: - Catalog Source Configuration
    enum CatalogSource: String {
        case local = "local"
        case remote = "remote"
    }
    
    @Published var currentCatalogSource: CatalogSource = .local
    @Published var catalogVersion: String = "1.0.0"
    
    // MARK: - Bootstrap Level (P0 Fix)
    static let bootstrap = Level(
        id: 1000001,
        realm: "Tree Library",
        baseLetters: "RETAIN",
        solutions: [
            "RETAIN": [0, 1, 2, 3, 4, 5],  // 6-letter pangram
            "TRAIN": [2, 0, 3, 4, 5],      // 5-letter
            "INTER": [4, 5, 2, 1, 0],      // 5-letter  
            "INERT": [4, 5, 1, 0, 2],      // 5-letter
            "RAIN": [0, 3, 4, 5],          // 4-letter
            "RATE": [0, 3, 2, 1],          // 4-letter
            "TEAR": [2, 1, 3, 0],          // 4-letter
            "TIRE": [2, 4, 0, 1],          // 4-letter
            "NEAR": [5, 1, 3, 0],          // 4-letter
            "NEAT": [5, 1, 3, 2],          // 4-letter
            "ANT": [3, 5, 2],              // 3-letter
            "ART": [3, 0, 2],              // 3-letter
            "ATE": [3, 2, 1],              // 3-letter
            "EAR": [1, 3, 0],              // 3-letter
            "EAT": [1, 3, 2],              // 3-letter
            "NET": [5, 1, 2],              // 3-letter
            "RAN": [0, 3, 5],              // 3-letter
            "RAT": [0, 3, 2],              // 3-letter
            "TAN": [2, 3, 5],              // 3-letter
            "TAR": [2, 3, 0],              // 3-letter
            "TEA": [2, 1, 3],              // 3-letter
            "TEN": [2, 1, 5],              // 3-letter
            "TIE": [2, 4, 1]               // 3-letter
        ],
        bonusWords: ["RET", "REI", "ETA", "ERA", "ANE", "ANI", "IRE", "NIT"], // Bonus words
        metadata: LevelMetadata(
            difficulty: .easy,
            theme: "treelibrary",
            hintCost: nil
        )
    )
    
    @MainActor @Published var currentLevel: Level?
    @MainActor @Published var solutionFormats: [String: SolutionFormat] = [:]
    @MainActor @Published var loadingProgress: Double = 0
    @MainActor @Published var isLoading: Bool = false
    
    // Level catalog for index-based lookup (WO-004: Nil-safe)
    private var catalog: LevelCatalog?
    
    /// Public access to catalog for UI components
    public var levelCatalog: LevelCatalog? {
        return catalog
    }
    
    // Realm mapping for WO-003
    private var realmMap: [LevelRealmAssignment]?
    
    // Performance lookup maps (WO-003 FINALIZE)
    private var idToRealm: [Int: LevelRealmAssignment] = [:]
    private var realmToOrdered: [String: [LevelRealmAssignment]] = [:] // sorted by indexInRealm
    
    // Track difficulty and hasIso6 per level ID loaded from Firestore
    private(set) var difficultyById: [Int:String] = [:]
    private(set) var hasIso6ById: [Int:Bool] = [:]
    
    /// All available level IDs from the catalog
    var orderedLevelIDs: [Int] {
        return allLevels.map { $0.id }.sorted()
    }
    
    // LRU cache for parsed chunks (file path -> levels)
    private var levelCache: [String: [Level]] = [:]
    private var cacheAccessOrder: [String] = []  // For LRU eviction
    private let maxCachedFiles = 5              // Maximum files in memory cache
    
    // Preload strategy
    private let preloadBuffer = 1               // Files to preload ahead/behind
    
    // Legacy compatibility - now only returns loaded levels from cache
    var allLevels: [Level] {
        return levelCache.values.flatMap { $0 }.sorted { $0.id < $1.id }
    }
    
    // Legacy support for difficulty-based organization
    private var levelsByDifficulty: [String: [Level]] = [:]
    
    private init() {
        // Catalog will be initialized in loadLevelsFromBundle()
    }

    /// Ensure catalog is loaded or use bootstrap (P0 Fix)
    @MainActor
    func ensureLoaded() async {
        if catalog == nil || isLoading {
            await loadLevelsFromBundle()
        }
        // If still no catalog after load attempt, use bootstrap
        if catalog == nil {
            print("⚠️ Using bootstrap level as fallback")
            self.currentLevel = Self.bootstrap
            self.solutionFormats = parseSolutionFormats(for: Self.bootstrap)
        }
    }
    
    /// Get first playable level (never nil)
    func firstPlayable() -> Level {
        return currentLevel ?? Self.bootstrap
    }
    
    // MARK: - Remote (Firestore)
    private let levelsCollectionName = "levels"
    
    /// Load catalog based on current source setting
    @MainActor
    func loadCatalogIfNeeded(preferRemote: Bool = true) async {
        // If we want remote but have local loaded, clear and reload
        if preferRemote && currentCatalogSource == .local && totalLevelCount > 0 {
            print("[Levels] Switching from local to remote catalog")
            clearCache()
            catalog = nil
        } else if totalLevelCount > 0 {
            // Already loaded with correct source
            print("[Levels] Already loaded with source: \(currentCatalogSource.rawValue), count: \(totalLevelCount)")
            return
        }
        
        // For remote loading, ensure auth is ready
        if preferRemote {
            // Wait for auth if not ready
            if !AuthService.shared.isAuthenticated {
                print("[Levels] Waiting for authentication...")
                await AuthService.shared.ensureSignedIn()
                print("[Levels] Auth complete, uid: \(AuthService.shared.uid ?? "nil")")
            }
            
            // Try remote with authenticated user
            print("[Levels] Attempting to load from Firestore...")
            do {
                try await loadFromFirestore()
                self.currentCatalogSource = .remote
                print("[Levels] REMOTE OK · loaded=\(self.totalLevelCount)")
                return // Success, don't fall back
            } catch {
                print("[Levels] ⚠️ Firestore load failed: \(error)")
                // Only fall back if we absolutely need to
            }
        }
        
        // Fall back to local or load local if preferred
        print("[Levels] Loading local catalog as fallback")
        await loadLocalCatalog()
        self.currentCatalogSource = .local
        print("[Levels] LOCAL fallback · loaded=\(self.totalLevelCount)")
    }
    
    /// Get a level by ID
    func levelByID(_ id: Int) -> Level? {
        // Check bootstrap first
        if id == Self.bootstrap.id {
            return Self.bootstrap
        }
        
        // Check cache
        for levels in levelCache.values {
            if let level = levels.first(where: { $0.id == id }) {
                return level
            }
        }
        
        // Load from catalog if needed
        Task {
            await fetchLevel(id: id)
        }
        
        return currentLevel
    }
    
    /// Get a random level
    func randomLevel() -> Level? {
        guard let catalog = catalog else {
            return Self.bootstrap
        }
        
        if let randomID = catalog.randomLevelID() {
            return levelByID(randomID)
        }
        
        return Self.bootstrap
    }
    
    /// Load local catalog from Assets/Levels/v1
    private func loadLocalCatalog() async {
        await MainActor.run {
            isLoading = true
            loadingProgress = 0
        }
        
        print("📚 Loading LOCAL catalog from Assets/Levels/v1...")
        
        // Load index.json from local assets using subdirectory
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Assets/Levels/v1") else {
            print("❌ Local catalog index not found at Assets/Levels/v1/index.json")
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        do {
            let indexData = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            let catalogIndex = try decoder.decode(LocalCatalogIndex.self, from: indexData)
            
            // Create LevelCatalog from local index
            var entries: [LevelIndex] = []
            for chunk in catalogIndex.chunks {
                entries.append(LevelIndex(
                    file: "Assets/Levels/v1/\(chunk.file)",
                    firstID: chunk.startId,
                    lastID: chunk.endId,
                    count: chunk.count
                ))
            }
            
            catalog = LevelCatalog(entries: entries)
            catalogVersion = catalogIndex.version
            
            // Enhanced logging as requested
            print("[Levels] source=local path=Assets/Levels/v1 version=\(catalogVersion)")
            print("✅ LOCAL catalog loaded: v\(catalogVersion) with \(catalogIndex.totalLevels) levels")
            print("📁 Chunks: \(catalogIndex.chunks.map { $0.file }.joined(separator: ", "))")
            
            // Load first chunk automatically
            if let firstChunk = catalogIndex.chunks.first {
                let chunkPath = "Assets/Levels/v1/\(firstChunk.file)"
                _ = await loadLocalChunkFile(path: chunkPath)
                print("✅ Preloaded first chunk: \(firstChunk.file)")
            }
            
        } catch {
            print("❌ Failed to load local catalog: \(error)")
            #if DEBUG
            assertionFailure("Catalog load failed in DEBUG: \(error)")
            #endif
        }
        
        await MainActor.run {
            loadingProgress = 1.0
            isLoading = false
        }
    }
    
    /// Load a local chunk file
    private func loadLocalChunkFile(path: String) async -> [Level]? {
        // Check cache first
        if let cachedLevels = levelCache[path] {
            updateCacheAccess(for: path)
            return cachedLevels
        }
        
        // Parse the path to get just the filename
        let filename = path
            .replacingOccurrences(of: "Assets/Levels/v1/", with: "")
            .replacingOccurrences(of: ".json", with: "")
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Assets/Levels/v1") else {
            print("❌ Local chunk file not found: \(path)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            var levels = try JSONDecoder().decode([Level].self, from: data)
            
            // PART A: NORMALIZE DATA AT LOAD
            levels = normalizeLevels(levels)
            
            #if DEBUG
            print("[Levels] normalized chunk \(filename) (uppercased, indices fixed)")
            #endif
            
            // Cache the normalized levels
            cacheLevels(levels, forFile: path)
            
            print("✅ Loaded \(levels.count) levels from local chunk: \(filename)")
            if let firstLevel = levels.first, let lastLevel = levels.last {
                print("   Level range: \(firstLevel.id) - \(lastLevel.id)")
            }
            
            return levels
        } catch {
            print("❌ Error loading local chunk \(path): \(error)")
            return nil
        }
    }
    
    /// Load remote catalog from Firebase Storage
    private func loadRemoteCatalog() async {
        await MainActor.run {
            isLoading = true
            loadingProgress = 0
        }
        
        print("📚 Loading REMOTE catalog from Firebase Storage...")
        
        // TODO: Implement Firebase Storage loading
        // For now, fall back to local
        print("⚠️ Remote catalog not yet implemented, falling back to local")
        await loadLocalCatalog()
    }
    
    // MARK: - Firestore Loading Methods
    
    private func decodeSolutions(_ raw: [String: Any]) -> [String: [Int]] {
        var out: [String: [Int]] = [:]
        for (k, v) in raw {
            if let arr = v as? [Int] {
                out[k.uppercased()] = arr
            } else if let anyArr = v as? [Any] {
                out[k.uppercased()] = anyArr.compactMap { $0 as? Int }
            } else if let s = v as? String {
                // Handle "3,1,4,0" edge case defensively
                let idxs = s
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                out[k.uppercased()] = idxs
            }
        }
        return out
    }
    
    private func sanitizeLevel(id: Int,
                               realm: String?,
                               base: String,
                               solutions: [String: [Int]],
                               bonus: [String]) -> Level? {
        let BASE = base.uppercased()
        guard BASE.count == 6, BASE.allSatisfy({ $0.isLetter }) else { return nil }
        
        // Recompute/verify indices and prune impossible words (safety)
        func idxs(for word: String) -> [Int]? {
            let wordU = word.uppercased()
            var buckets: [Character:[Int]] = [:]
            for (i, ch) in BASE.enumerated() { buckets[ch, default: []].append(i) }
            var used: [Character:Int] = [:]
            var out: [Int] = []
            for ch in wordU {
                let k = used[ch, default: 0]
                guard let list = buckets[ch], k < list.count else { return nil }
                out.append(list[k]); used[ch] = k + 1
            }
            return out
        }
        
        var fixed: [String:[Int]] = [:]
        for (w, idxs0) in solutions {
            let wU = w.uppercased()
            guard (3...6).contains(wU.count) else { continue }
            // if stored indices mismatch, recompute
            if idxs0.count != wU.count || idxs0.contains(where: { $0 < 0 || $0 > 5 }) {
                if let recomputed = idxs(for: wU) { fixed[wU] = recomputed }
            } else {
                // verify rebuild
                let rebuilt = String(idxs0.map { Array(BASE)[$0] })
                if rebuilt == wU, let verified = idxs(for: wU) { fixed[wU] = verified }
            }
        }
        
        // bonus = buildable from base, not in solutions
        let solSet = Set(fixed.keys)
        let bonusClean = Array(Set(bonus.map { $0.uppercased() })
                            .filter { (3...6).contains($0.count) })
                            .filter { !solSet.contains($0) }
                            .sorted()
        
        guard !fixed.isEmpty else { return nil }
        
        return Level(
            id: id,
            realm: realm,
            baseLetters: BASE,
            solutions: fixed,
            bonusWords: bonusClean,
            metadata: nil
        )
    }
    
    private func loadFromFirestore() async throws {
        let db = Firestore.firestore()
        // Load all levels (or add a .limit() if you want fewer)
        let snap = try await db.collection(levelsCollectionName)
            .order(by: "id")
            .getDocuments()
        
        #if DEBUG
        print("[Levels] Firestore: fetched \(snap.documents.count) documents")
        #endif
        
        var loaded: [Level] = []
        var dropped: [(Int, String)] = []  // Track dropped levels for diagnostics
        loaded.reserveCapacity(snap.documents.count)
        
        for doc in snap.documents {
            let data = doc.data()
            guard
                let id = data["id"] as? Int,
                let base = data["baseLetters"] as? String
            else {
                #if DEBUG
                let docId = data["id"] as? Int ?? -1
                dropped.append((docId, "Missing id or baseLetters"))
                #endif
                continue
            }
            
            let realm = data["realm"] as? String
            let solutionsRaw = data["solutions"] as? [String: Any] ?? [:]
            let bonus = data["bonusWords"] as? [String] ?? []

            // Capture difficulty and hasIso6 from Firestore metadata for progression ordering
            if let meta = data["metadata"] as? [String: Any] {
                if let diff = (meta["difficulty"] as? String)?.lowercased() {
                    self.difficultyById[id] = diff
                } else {
                    self.difficultyById[id] = "medium" // sensible default
                }
                
                if let hasIso = meta["hasIso6"] as? Bool {
                    self.hasIso6ById[id] = hasIso
                } else {
                    self.hasIso6ById[id] = false // default to false if not specified
                }
            } else {
                self.difficultyById[id] = "medium"
                self.hasIso6ById[id] = false
            }
            
            let decoded = decodeSolutions(solutionsRaw)
            if let lvl = sanitizeLevel(id: id,
                                       realm: realm,
                                       base: base,
                                       solutions: decoded,
                                       bonus: bonus) {
                loaded.append(lvl)
            } else {
                #if DEBUG
                dropped.append((id, "Failed sanitization"))
                #endif
            }
        }
        
        loaded.sort { $0.id < $1.id }
        
        #if DEBUG
        print("[Levels] ✅ Loaded \(loaded.count) from Firestore.")
        if !dropped.isEmpty {
            print("[Levels] ⚠️ Dropped \(dropped.count) levels:")
            for (id, reason) in dropped.prefix(5) {
                print("  - Level \(id): \(reason)")
            }
            if dropped.count > 5 {
                print("  ... and \(dropped.count - 5) more")
            }
        }
        if let first = loaded.first, let last = loaded.last {
            print("[Levels] Range: \(first.id) - \(last.id)")
        }
        #endif
        
        // Throw if no levels loaded to trigger fallback
        if loaded.isEmpty {
            throw NSError(domain: "LevelService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No valid levels in Firestore"])
        }
        
        // Build catalog entries from loaded levels
        var entries: [LevelIndex] = []
        if !loaded.isEmpty {
            // Group levels into virtual chunks for compatibility with catalog system
            let chunkSize = 100
            for chunkIndex in stride(from: 0, to: loaded.count, by: chunkSize) {
                let endIndex = min(chunkIndex + chunkSize, loaded.count)
                let chunkLevels = Array(loaded[chunkIndex..<endIndex])
                
                if let firstLevel = chunkLevels.first,
                   let lastLevel = chunkLevels.last {
                    // Store levels in cache directly
                    let chunkPath = "firestore_chunk_\(chunkIndex / chunkSize)"
                    levelCache[chunkPath] = chunkLevels
                    
                    entries.append(LevelIndex(
                        file: chunkPath,
                        firstID: firstLevel.id,
                        lastID: lastLevel.id,
                        count: chunkLevels.count
                    ))
                }
            }
        }
        
        await MainActor.run {
            self.catalog = LevelCatalog(entries: entries)
            // totalLevelCount is computed from catalog.totalLevelCount automatically
            self.catalogVersion = "firestore:\(loaded.count)"
        }

        // Ensure difficulty map only contains IDs that exist in the catalog
        let valid = Set(loaded.map { $0.id })
        self.difficultyById = self.difficultyById.filter { valid.contains($0.key) }
    }
    
    /// Get configured catalog source from Remote Config
    private func getConfiguredCatalogSource() async -> CatalogSource {
        // TODO: Read from Firebase Remote Config
        // For now, always return local
        return .local
    }
    
    /// Force reload from Firestore (useful for source switching)
    @MainActor
    func forceReloadFromRemote() async {
        print("[Levels] Force reloading from Firestore...")
        clearCache()
        catalog = nil
        
        // Ensure auth first
        if !AuthService.shared.isAuthenticated {
            await AuthService.shared.ensureSignedIn()
        }
        
        do {
            try await loadFromFirestore()
            self.currentCatalogSource = .remote
            print("[Levels] ✅ Force reload successful: \(self.totalLevelCount) levels")
        } catch {
            print("[Levels] ❌ Force reload failed: \(error)")
            // Fall back to local if absolutely necessary
            await loadLocalCatalog()
            self.currentCatalogSource = .local
        }
    }
    
    /// Reload catalog (for Dev Tools)
    func reloadCatalog() async {
        clearCache()
        catalog = nil
        await loadCatalogIfNeeded(preferRemote: true)
    }
    
    /// Initialize level catalog and prepare for level loading - FULLY ASYNC
    func loadLevelsFromBundle() async {
        // Use the new catalog loading method with remote preference
        await loadCatalogIfNeeded(preferRemote: true)
    }
    
    /// Load a specific level file and cache it - FULLY ASYNC
    private func loadLevelFile(path: String) async -> [Level]? {
        // Check cache first (Firestore levels are pre-cached)
        if let cachedLevels = levelCache[path] {
            // Update access order for LRU
            updateCacheAccess(for: path)
            #if DEBUG
            print("🎯 Cache hit for \(path)")
            #endif
            return cachedLevels
        }
        
        // Use local chunk loading for local catalog
        if currentCatalogSource == .local {
            return await loadLocalChunkFile(path: path)
        }
        
        // For Firestore source, levels should already be in cache
        // If not, it's an error as Firestore loads all at once
        if currentCatalogSource == .remote {
            print("⚠️ Firestore level not in cache: \(path)")
            return nil
        }
        
        // Original implementation for other remote files (if needed)
        // Check cache again (redundant but safe)
        if let cachedLevels = levelCache[path] {
            // Update access order for LRU
            updateCacheAccess(for: path)
            #if DEBUG
            print("🎯 Cache hit for \(path)")
            #endif
            return cachedLevels
        }
        
        // Load from bundle
        guard let url = Bundle.main.url(forResource: path.replacingOccurrences(of: ".json", with: ""), withExtension: "json") else {
            print("❌ Level file not found: \(path)")
            return nil
        }
        
        let loadedLevels = await Task.detached(priority: .userInitiated) { () -> [Level]? in
            do {
                let data = try Data(contentsOf: url)
                let levels = try JSONDecoder().decode([Level].self, from: data)
                return levels
            } catch {
                print("❌ Error loading level file \(path): \(error)")
                return nil
            }
        }.value
        
        if let levels = loadedLevels {
            // Cache the loaded levels with LRU management
            cacheLevels(levels, forFile: path)
            #if DEBUG
            print("💾 Loaded and cached \(levels.count) levels from \(path)")
            #endif
            return levels
        }
        
        return nil
    }
    
    
    
    
    
    
    /// Legacy method - now organizes levels by difficulty from cache
    private func organizeLevelsByDifficulty() {
        levelsByDifficulty = [:]
        
        for levels in levelCache.values {
            for level in levels {
                let difficulty = level.metadata?.difficulty.rawValue ?? "easy"
                if levelsByDifficulty[difficulty] == nil {
                    levelsByDifficulty[difficulty] = []
                }
                levelsByDifficulty[difficulty]?.append(level)
            }
        }
        
        #if DEBUG
        print("📊 Organized levels by difficulty:")
        for (difficulty, levels) in levelsByDifficulty {
            print("  \(difficulty): \(levels.count) levels")
        }
        #endif
    }

    /// Fetch a specific level using catalog-based lookup - FULLY ASYNC
    @MainActor
    func fetchLevel(id: Int) async {
        // IDEMPOTENT: Skip if already on this level
        if currentLevel?.id == id {
            Logger.game.debug("SETUP_LEVEL idempotent skip id=\(id)")
            return
        }
        
        // Special handling for bootstrap level
        if id == Self.bootstrap.id {
            self.currentLevel = Self.bootstrap
            self.solutionFormats = parseSolutionFormats(for: Self.bootstrap)
            print("✅ Loaded bootstrap level")
            return
        }
        
        guard let catalog = catalog else {
            print("❌ Level catalog not initialized, using bootstrap")
            self.currentLevel = Self.bootstrap
            self.solutionFormats = parseSolutionFormats(for: Self.bootstrap)
            return
        }
        
        guard let entry = catalog.entry(containing: id) else {
            print("⚠️ Level \(id) not found in catalog")
            // Try to load first available level as fallback
            if let firstEntry = catalog.entries.first {
                await fetchLevel(id: firstEntry.firstID)
            }
            return
        }
        
        // Load the file containing this level
        if let levels = await loadLevelFile(path: entry.file) {
            if let level = levels.first(where: { $0.id == id }) {
                self.currentLevel = level
                self.solutionFormats = parseSolutionFormats(for: level)
                print("✅ Loaded Level \(id) from \(entry.file)")
                
                // Preload neighboring files for smooth navigation
                await preloadNeighboringFiles(for: entry)
            } else {
                print("⚠️ Level \(id) not found in file \(entry.file)")
            }
        }
    }
    
    
    /// Parse solution formats for a level
    private func parseSolutionFormats(for level: Level) -> [String: SolutionFormat] {
        var formats: [String: SolutionFormat] = [:]
        
        for (word, indices) in level.solutions {
            formats[word] = parseSolutionFormat(word: word, indices: indices)
        }
        
        return formats
    }
    
    /// Parse solution format from indices
    private func parseSolutionFormat(word: String, indices: [Int]) -> SolutionFormat {
        if indices.count == word.count {
            return .wheel(indices)
        }
        
        if indices.count == word.count * 2 {
            let coords: [(Int, Int)] = stride(from: 0, to: indices.count, by: 2).compactMap { i -> (Int, Int)? in
                guard i + 1 < indices.count else { return nil }
                return (indices[i], indices[i + 1])
            }
            return .grid(coords)
        }
        
        return .wheel(indices)
    }

    /// Get levels for a specific difficulty
    func getLevelsWithDifficulty(_ difficulty: String) -> [Level] {
        return levelsByDifficulty[difficulty] ?? []
    }

    /// Get next level ID using catalog navigation (WO-004: Nil-safe)
    func nextLevelID(from currentID: Int) -> Int? {
        guard let catalog = catalog else {
            ToastManager.shared.showError("Level catalog not loaded")
            return nil
        }
        return catalog.nextExistingID(after: currentID)
    }
    
    /// Get previous level ID using catalog navigation (WO-004: Nil-safe)  
    func previousLevelID(from currentID: Int) -> Int? {
        guard let catalog = catalog else {
            ToastManager.shared.showError("Level catalog not loaded")
            return nil
        }
        return catalog.previousExistingID(before: currentID)
    }
    
    /// Get total level count from catalog (WO-004: Nil-safe)
    var totalLevelCount: Int {
        guard let catalog = catalog else {
            ToastManager.shared.showWarning("Level catalog not loaded, returning 0")
            return 0
        }
        return catalog.totalLevelCount
    }

    /// First level ID in the catalog (if loaded)
    var firstLevelId: Int? {
        return catalog?.minLevelID
    }

    /// Last level ID in the catalog (if loaded)
    var lastLevelId: Int? {
        return catalog?.maxLevelID
    }
    
    /// Get next level with smart selection (WO-004: Nil-safe)
    func getNextLevelID(for playerData: PlayerData) -> Int? {
        guard let catalog = catalog else {
            ToastManager.shared.showError("Level catalog not loaded for smart selection")
            return nil
        }
        
        // For now, use simple next level logic
        if let currentLevel = currentLevel {
            return nextLevelID(from: currentLevel.id)
        }
        
        // Fallback to first level
        return catalog.minLevelID
    }
    
    
    
    
    /// Validate level ID using catalog (WO-004: Nil-safe)
    func validateLevelId(_ levelId: Int) -> Bool {
        guard let catalog = catalog else {
            ToastManager.shared.showError("Cannot validate level ID - catalog not loaded")
            return false
        }
        return catalog.isValidLevelID(levelId)
    }

    /// Convenience: does a level with this ID exist in the current catalog?
    func hasLevel(id: Int) -> Bool {
        // Bootstrap is always considered available
        if id == Self.bootstrap.id { return true }
        return validateLevelId(id)
    }
    
    
    /// Clear all cached levels to free memory
    func clearCache() {
        levelCache.removeAll()
        cacheAccessOrder.removeAll()
        print("🧹 Cleared level cache to free memory")
    }
    
    /// Handle memory pressure
    func handleMemoryPressure() {
        guard let currentLevel = currentLevel,
              let catalog = catalog,
              let currentEntry = catalog.entry(containing: currentLevel.id) else {
            // If no current level, clear everything
            clearCache()
            return
        }
        
        // Keep only current file and remove others
        let currentFilePath = currentEntry.file
        levelCache = levelCache.filter { $0.key == currentFilePath }
        cacheAccessOrder = cacheAccessOrder.filter { $0 == currentFilePath }
        
        print("⚠️ Memory pressure handled, kept only \(currentFilePath)")
    }
    
    // MARK: - Cache Management
    
    /// Cache levels with LRU eviction
    private func cacheLevels(_ levels: [Level], forFile filePath: String) {
        // Add to cache
        levelCache[filePath] = levels
        
        // Update access order (remove if exists, then add to end)
        cacheAccessOrder.removeAll { $0 == filePath }
        cacheAccessOrder.append(filePath)
        
        // Evict oldest if over limit
        while levelCache.count > maxCachedFiles {
            if let oldestFile = cacheAccessOrder.first {
                levelCache.removeValue(forKey: oldestFile)
                cacheAccessOrder.removeFirst()
                #if DEBUG
                print("🗑️ Evicted cache for \(oldestFile)")
                #endif
            }
        }
    }
    
    /// Update cache access order for LRU
    private func updateCacheAccess(for filePath: String) {
        cacheAccessOrder.removeAll { $0 == filePath }
        cacheAccessOrder.append(filePath)
    }
    
    /// Preload neighboring files for smooth navigation
    private func preloadNeighboringFiles(for entry: LevelIndex) async {
        guard let catalog = catalog else { return }
        
        // Find neighboring entries
        let currentIndex = catalog.entries.firstIndex { $0.file == entry.file } ?? 0
        let rangesToPreload = [
            max(0, currentIndex - preloadBuffer)...min(catalog.entries.count - 1, currentIndex + preloadBuffer)
        ]
        
        for range in rangesToPreload {
            for index in range where index != currentIndex {
                let neighborEntry = catalog.entries[index]
                // Non-blocking preload
                Task.detached(priority: .background) { [weak self] in
                    await self?.loadLevelFile(path: neighborEntry.file)
                }
            }
        }
    }
    
    /// Get a random level ID for daily challenges (WO-004: Nil-safe)
    func getRandomLevelID() -> Int? {
        guard let catalog = catalog else {
            ToastManager.shared.showError("Cannot get random level - catalog not loaded")
            return nil
        }
        return catalog.randomLevelID()
    }
    
    /// Preload next chunk of levels for smooth gameplay
    func preloadNextChunk(for currentLevelID: Int) async {
        guard let catalog = catalog,
              let currentEntry = catalog.entry(containing: currentLevelID) else {
            return
        }
        
        // Preload neighboring files
        await preloadNeighboringFiles(for: currentEntry)
    }
    
    /// Optimize memory by clearing unneeded cached levels
    func optimizeMemory(currentLevelID: Int) {
        guard let catalog = catalog,
              let currentEntry = catalog.entry(containing: currentLevelID) else {
            // If no current level, clear everything
            clearCache()
            return
        }
        
        // Keep only current file and neighboring files
        let currentIndex = catalog.entries.firstIndex { $0.file == currentEntry.file } ?? 0
        let keepRange = max(0, currentIndex - preloadBuffer)...min(catalog.entries.count - 1, currentIndex + preloadBuffer)
        let filesToKeep = Set(keepRange.map { catalog.entries[$0].file })
        
        // Remove files not in the keep range
        levelCache = levelCache.filter { filesToKeep.contains($0.key) }
        cacheAccessOrder = cacheAccessOrder.filter { filesToKeep.contains($0) }
        
        #if DEBUG
        print("🧹 Optimized memory, kept \(levelCache.count) files")
        #endif
    }
    
    // MARK: - Level Data Normalization
    
    /// Normalize level data at load time (uppercase, fix indices, validate)
    private func normalizeLevels(_ levels: [Level]) -> [Level] {
        return levels.map { level in
            // 1) Uppercase everything once
            let normalizedBaseLetters = level.baseLetters.uppercased()
            
            // Normalize solutions (uppercase keys and fix indices)
            var normalizedSolutions: [String: [Int]] = [:]
            for (word, indices) in level.solutions {
                let uppercasedWord = word.uppercased()
                
                // 2) Fix index base if needed (1-based to 0-based conversion)
                let fixedIndices: [Int]
                if indices.allSatisfy({ $0 >= 1 && $0 <= 6 }) {
                    // All indices are 1-based, convert to 0-based
                    fixedIndices = indices.map { $0 - 1 }
                } else {
                    // Already 0-based or mixed, keep as-is
                    fixedIndices = indices
                }
                
                #if DEBUG
                // Assert indices are valid
                assert(fixedIndices.count == uppercasedWord.count, 
                       "Level \(level.id): Indices count \(fixedIndices.count) != word length \(uppercasedWord.count) for word '\(uppercasedWord)'")
                assert(fixedIndices.allSatisfy { $0 >= 0 && $0 < normalizedBaseLetters.count },
                       "Level \(level.id): Invalid indices \(fixedIndices) for word '\(uppercasedWord)'")
                #endif
                
                normalizedSolutions[uppercasedWord] = fixedIndices
            }
            
            // Normalize bonus words and ensure they don't overlap with solutions
            let solutionSet = Set(normalizedSolutions.keys)
            let normalizedBonusWords = Array(Set(level.bonusWords.map { $0.uppercased() })
                .subtracting(solutionSet))
            
            #if DEBUG
            // 5) DEBUG guardrails
            assert(Set(normalizedBonusWords).isDisjoint(with: solutionSet),
                   "Level \(level.id): Bonus words overlap with solutions!")
            
            // Validate a sample of words can be made from base letters
            let sampleWords = Array(normalizedSolutions.keys.prefix(3))
            for word in sampleWords {
                assert(canMakeWord(word, from: normalizedBaseLetters),
                       "Level \(level.id): Cannot make word '\(word)' from base letters '\(normalizedBaseLetters)'")
            }
            #endif
            
            // Return normalized level
            return Level(
                id: level.id,
                realm: level.realm,
                baseLetters: normalizedBaseLetters,
                solutions: normalizedSolutions,
                bonusWords: normalizedBonusWords,
                metadata: level.metadata
            )
        }
    }
    
    /// Helper to check if a word can be made from base letters
    private func canMakeWord(_ word: String, from baseLetters: String) -> Bool {
        var letterCounts: [Character: Int] = [:]
        for char in baseLetters {
            letterCounts[char, default: 0] += 1
        }
        
        for char in word {
            guard let count = letterCounts[char], count > 0 else {
                return false
            }
            letterCounts[char] = count - 1
        }
        
        return true
    }
    
    // MARK: - Realm & Difficulty APIs (WO-003)
    
    /// Get the realm for a specific level ID (O(1) lookup)
    func realm(of levelID: Int) -> String? {
        return idToRealm[levelID]?.realm
    }
    
    /// Get the difficulty for a specific level ID (O(1) lookup)
    func difficulty(of levelID: Int) -> Difficulty? {
        guard let difficultyString = idToRealm[levelID]?.difficulty else {
            return nil
        }
        return Difficulty(rawValue: difficultyString)
    }
    
    /// Get the first level ID in a specific realm (O(1) lookup)
    func firstID(in realm: String) -> Int? {
        return realmToOrdered[realm]?.first?.id
    }
    
    /// Get the next level ID within the same realm (O(1) lookup)
    func nextID(in realm: String, after levelID: Int) -> Int? {
        guard let currentAssignment = idToRealm[levelID],
              currentAssignment.realm == realm,
              let orderedLevels = realmToOrdered[realm] else {
            return nil
        }
        
        // Find next level in same realm using indexed lookup
        let nextIndex = currentAssignment.indexInRealm + 1
        guard nextIndex < orderedLevels.count else { return nil }
        
        return orderedLevels[nextIndex].id
    }
    
    /// Get the previous level ID within the same realm (O(1) lookup)
    func previousID(in realm: String, before levelID: Int) -> Int? {
        guard let currentAssignment = idToRealm[levelID],
              currentAssignment.realm == realm,
              currentAssignment.indexInRealm > 0,
              let orderedLevels = realmToOrdered[realm] else {
            return nil
        }
        
        // Find previous level in same realm using indexed lookup
        let prevIndex = currentAssignment.indexInRealm - 1
        return orderedLevels[prevIndex].id
    }
    
    /// Get all level IDs in a specific realm, ordered by progression (O(1) lookup)
    func levelIDs(in realm: String) -> [Int] {
        return realmToOrdered[realm]?.map(\.id) ?? []
    }
    
    // MARK: - Private Helpers (WO-003)
    
    /// Load realm map from bundle or generate if missing
    private func loadRealmMap() async -> [LevelRealmAssignment]? {
        // Try to load from bundle first
        if let url = Bundle.main.url(forResource: "LevelRealmMap", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let realmMap = try? JSONDecoder().decode([LevelRealmAssignment].self, from: data) {
            print("✅ Loaded realm map with \(realmMap.count) assignments")
            buildLookupMaps(from: realmMap)
            return realmMap
        }
        
        // Try to load from Documents directory (Debug)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let documentsURL = documentsURL {
            let realmMapURL = documentsURL.appendingPathComponent("LevelRealmMap.json")
            if let data = try? Data(contentsOf: realmMapURL),
               let realmMap = try? JSONDecoder().decode([LevelRealmAssignment].self, from: data) {
                print("✅ Loaded realm map from Documents with \(realmMap.count) assignments")
                buildLookupMaps(from: realmMap)
                return realmMap
            }
        }
        
        print("⚠️ No realm map found, falling back to basic difficulty inference")
        return nil
    }
    
    /// Build performance lookup maps from realm assignments (WO-003 FINALIZE)
    private func buildLookupMaps(from realmMap: [LevelRealmAssignment]) {
        // Build ID -> Assignment map for O(1) lookups
        idToRealm = Dictionary(uniqueKeysWithValues: realmMap.map { ($0.id, $0) })
        
        // Build Realm -> Ordered Assignments map
        let realmGroups = Dictionary(grouping: realmMap, by: { $0.realm })
        realmToOrdered = realmGroups.mapValues { assignments in
            assignments.sorted { $0.indexInRealm < $1.indexInRealm }
        }
        
        print("🚀 Built performance lookup maps:")
        print("  ID->Realm: \(idToRealm.count) entries")
        print("  Realm->Ordered: \(realmToOrdered.keys.count) realms")
    }
    
    // MARK: - Helpers
    private func difficultyRank(for id: Int) -> Int {
        switch difficultyById[id]?.lowercased() {
        case "easy": return 0
        case "medium": return 1
        case "hard": return 2
        default: return 3
        }
    }

    /// All level IDs ordered for progression:
    /// 1. EASY → MEDIUM → HARD → UNKNOWN
    /// 2. Within each difficulty, prefer hasIso6 == true
    /// 3. Then stable by ID
    var orderedProgressionIDs: [Int] {
        orderedLevelIDs.sorted { id1, id2 in
            let diff1 = difficultyRank(for: id1)
            let diff2 = difficultyRank(for: id2)
            
            // First sort by difficulty
            if diff1 != diff2 {
                return diff1 < diff2
            }
            
            // Within same difficulty, prefer hasIso6
            let iso1 = hasIso6ById[id1] ?? false
            let iso2 = hasIso6ById[id2] ?? false
            if iso1 != iso2 {
                return iso1 && !iso2  // true comes before false
            }
            
            // Finally, sort by ID for stability
            return id1 < id2
        }
    }

    /// Next ID in progression order strictly after `lastId`; if nil/unknown, returns first.
    func nextProgressionLevelId(after lastId: Int?) -> Int? {
        let ids = orderedProgressionIDs
        guard let last = lastId, let idx = ids.firstIndex(of: last) else { return ids.first }
        let nextIdx = ids.index(after: idx)
        return nextIdx < ids.endIndex ? ids[nextIdx] : nil
    }

    /// Previous ID in progression order strictly before `currentId`.
    func previousProgressionLevelId(before currentId: Int?) -> Int? {
        let ids = orderedProgressionIDs
        guard let cur = currentId, let idx = ids.firstIndex(of: cur), idx > 0 else { return nil }
        return ids[ids.index(before: idx)]
    }
    
    // MARK: - Debug Helpers
    
    /// Print catalog debug information
    func printCatalogDebug() {
        print("\n=== CATALOG DEBUG ===")
        print("Source: \(currentCatalogSource.rawValue)")
        print("Version: \(catalogVersion)")
        print("Total levels: \(totalLevelCount)")
        
        if let catalog = catalog {
            print("Catalog entries: \(catalog.entries.count)")
            let first = catalog.minLevelID
            let last = catalog.maxLevelID
            print("Level range: \(first) - \(last)")
        } else {
            print("Catalog: NOT LOADED")
        }
        
        print("\nCache status:")
        print("  Cached files: \(levelCache.count)")
        for (file, levels) in levelCache {
            print("  - \(file): \(levels.count) levels")
        }
        
        print("\nProgression stats:")
        let ids = orderedProgressionIDs
        if !ids.isEmpty {
            let easyCount = ids.filter { difficultyRank(for: $0) == 0 }.count
            let mediumCount = ids.filter { difficultyRank(for: $0) == 1 }.count
            let hardCount = ids.filter { difficultyRank(for: $0) == 2 }.count
            let unknownCount = ids.filter { difficultyRank(for: $0) == 3 }.count
            
            print("  Easy: \(easyCount)")
            print("  Medium: \(mediumCount)")
            print("  Hard: \(hardCount)")
            print("  Unknown: \(unknownCount)")
            
            let iso6Count = ids.filter { hasIso6ById[$0] ?? false }.count
            print("  With hasIso6: \(iso6Count)")
            
            if let first = ids.first {
                let diff = difficultyById[first] ?? "unknown"
                let iso = hasIso6ById[first] ?? false
                print("\nFirst level in progression: \(first) (\(diff), hasIso6=\(iso))")
            }
        }
        print("==================\n")
    }
}

// MARK: - Seeded Random Generator for consistent procedural generation
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 1103515245 &+ 12345
        return state
    }
}
