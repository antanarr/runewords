import Foundation
import FirebaseFirestore
import Combine
import SwiftUI

@MainActor
final class PlayerService: ObservableObject {
    static let shared = PlayerService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // Internal storage for the actual Player model
    @Published private var internalPlayer: Player?
    
    // Track last known level to prevent unnecessary navigation
    private var lastKnownLevelID: Int?
    private var isFetchingPlayer = false
    private var playerListener: ListenerRegistration?
    private var didBootstrap = false  // Prevent navigation on first snapshot
    
    // Publisher for GameViewModel to reconcile progress (prevents bounce-back)
    private let progressSubject = PassthroughSubject<PlayerData, Never>()
    var progressPublisher: AnyPublisher<PlayerData, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    // Expose Player for view models with explicit publisher
    @Published var player: Player? {
        didSet {
            if let p = player {
                playerData = p.toPlayerData()
            } else {
                playerData = nil
            }
        }
    }
    
    // Protocol conformance - wrapper for PlayerData type
    @Published var playerData: PlayerData?
    
    // Explicit publisher for Combine subscriptions
    var playerPublisher: AnyPublisher<Player?, Never> {
        $player.eraseToAnyPublisher()
    }
    
    var playerDataPublisher: AnyPublisher<PlayerData?, Never> {
        $playerData.eraseToAnyPublisher()
    }
    
    // Private mappers
    private static func playerData(from p: Player) -> PlayerData {
        let completedIDs = Set(p.levelProgress.keys.compactMap { Int($0) })
        let usesHintsOften = p.totalLevelsCompleted > 0 ? 
            (Double(p.totalHintsUsed) / Double(p.totalLevelsCompleted)) > 1.5 : false
        let isStruggling = p.consecutiveFailedGuesses > 5
        
        return PlayerData(
            id: p.id ?? AuthService.shared.uid ?? "temp-user",
            completedLevelIDs: completedIDs,
            usesHintsOften: usesHintsOften,
            isStruggling: isStruggling,
            preferredDifficulty: p.preferredDifficulty,
            difficultyDrift: p.difficultyDrift,
            coins: p.coins,
            dailyStreak: p.dailyStreak,
            lastDailyDate: p.lastDailyDate,  // String? for daily challenge keys
            currentLevelID: p.currentLevelID,
            levelProgress: p.levelProgress,
            foundBonusWords: p.foundBonusWords,
            totalWordsFound: p.totalWordsFound,
            totalLevelsCompleted: p.totalLevelsCompleted,
            longestWordFound: p.longestWordFound,
            totalHintsUsed: p.totalHintsUsed,
            perfectLevels: p.perfectLevels,
            lastPlayedDate: p.lastPlayedDate,
            totalRevelationsUsed: p.totalRevelationsUsed,
            levelsPlayedSinceHint: p.levelsPlayedSinceHint,
            consecutiveFailedGuesses: p.consecutiveFailedGuesses,
            lastLevelDuration: p.lastLevelDuration
        )
    }
    
    private static func player(from d: PlayerData) -> Player {
        return Player(
            id: d.id,
            currentLevelID: d.currentLevelID,
            coins: d.coins,
            levelProgress: d.levelProgress,
            foundBonusWords: d.foundBonusWords,
            lastPlayedDate: d.lastPlayedDate ?? Date(),
            lastDailyDate: d.lastDailyDate,
            dailyStreak: d.dailyStreak,
            totalHintsUsed: d.totalHintsUsed,
            totalLevelsCompleted: d.totalLevelsCompleted,
            preferredDifficulty: d.preferredDifficulty,
            totalRevelationsUsed: d.totalRevelationsUsed,
            levelsPlayedSinceHint: d.levelsPlayedSinceHint,
            consecutiveFailedGuesses: d.consecutiveFailedGuesses,
            difficultyDrift: d.difficultyDrift,
            lastLevelDuration: d.lastLevelDuration,
            totalWordsFound: d.totalWordsFound,
            longestWordFound: d.longestWordFound,
            perfectLevels: d.perfectLevels
        )
    }

    private var playerCollection: CollectionReference {
        return db.collection("players")
    }

    private init() {
        // Sync internal player to public player
        $internalPlayer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newPlayer in
                self?.player = newPlayer
            }
            .store(in: &cancellables)
            
        // Listen for the user ID from the AuthService
        AuthService.shared.$uid
            .compactMap { $0 } // Ensure userId is not nil
            .sink { [weak self] userId in
                self?.fetchOrCreatePlayer(userId: userId)
            }
            .store(in: &cancellables)
    }

    private func fetchOrCreatePlayer(userId: String) {
        // Prevent multiple simultaneous fetches
        guard !isFetchingPlayer else { 
            print("Already fetching player, skipping...")
            return 
        }
        isFetchingPlayer = true
        
        let playerDocRef = playerCollection.document(userId)
        
        // Set up snapshot listener with navigation gating
        setupSnapshotListener(for: userId)

        // Do initial fetch to create if needed
        playerDocRef.getDocument { [weak self] document, error in
            defer { self?.isFetchingPlayer = false }
            // If the document exists, decode it into our Player model
            if let document = document, document.exists {
                do {
                    let playerModel = try document.data(as: Player.self)
                    
                    // Only update if level actually changed to prevent navigation bouncing
                    let currentLevel = playerModel.currentLevelID
                    if self?.lastKnownLevelID != nil && self?.lastKnownLevelID != currentLevel {
                        print("⚠️ Level changed from \(self?.lastKnownLevelID ?? 0) to \(currentLevel)")
                    }
                    self?.lastKnownLevelID = currentLevel
                    
                    self?.internalPlayer = playerModel
                    self?.playerData = playerModel.toPlayerData()
                    print("Player data fetched for user \(userId) at level \(currentLevel).")
                } catch {
                    print("Error decoding existing player document: \(error)")
                }
                return
            }
            
            if let error = error {
                 print("Error checking for player document: \(error)")
                 return
            }

            // If the document doesn't exist, create a new one for the new user
            print("Creating new player document for user \(userId)...")
            guard var player = self?.internalPlayer else {
                let newPlayer = Player(
                    id: userId,
                    currentLevelID: 1,
                    coins: 50,
                    levelProgress: [:],
                    foundBonusWords: [],
                    lastPlayedDate: Date(),
                    dailyStreak: 1,
                    totalHintsUsed: 0,
                    totalLevelsCompleted: 0,
                    preferredDifficulty: .easy,
                    totalRevelationsUsed: 0,
                    levelsPlayedSinceHint: 0,
                    consecutiveFailedGuesses: 0
                )
                do {
                    try playerDocRef.setData(from: newPlayer)
                    self?.lastKnownLevelID = newPlayer.currentLevelID
                    self?.internalPlayer = newPlayer
                    self?.playerData = newPlayer.toPlayerData()
                    print("Successfully created new player at level \(newPlayer.currentLevelID).")
                } catch let error {
                    print("Error creating new player document: \(error)")
                }
                return
            }
            player.dailyStreak = 1
            do {
                try playerDocRef.setData(from: player)
                self?.lastKnownLevelID = player.currentLevelID
                self?.internalPlayer = player
                self?.playerData = player.toPlayerData()
                print("Successfully created player at level \(player.currentLevelID).")
            } catch let error {
                print("Error creating new player document: \(error)")
            }
        }
    }
    
    // MARK: - Snapshot Listener with Navigation Gating
    
    private func setupSnapshotListener(for userId: String) {
        // Remove any existing listener
        playerListener?.remove()
        
        let playerDocRef = playerCollection.document(userId)
        
        // Set up listener with navigation gating and metadata tracking
        playerListener = playerDocRef.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Snapshot listener error: \(error)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("⚠️ No data in snapshot")
                return
            }
            
            // Extract currentLevelID from snapshot
            guard let newLevel = data["currentLevelID"] as? Int else {
                print("⚠️ Snapshot missing currentLevelID, ignoring")
                return
            }
            
            // First snapshot: set baseline, don't navigate
            if !self.didBootstrap {
                self.didBootstrap = true
                self.lastKnownLevelID = newLevel
                do {
                    self.internalPlayer = try snapshot?.data(as: Player.self)
                    self.playerData = self.internalPlayer?.toPlayerData()
                    print("🎯 Bootstrap complete at level \(newLevel)")
                } catch {
                    print("❌ Error decoding player during bootstrap: \(error)")
                }
                return  // Don't navigate on bootstrap
            }
            
            // Handle pending writes carefully - merge, don't ignore
            let hasPendingWrites = snapshot?.metadata.hasPendingWrites ?? false
            let isFromCache = snapshot?.metadata.isFromCache ?? false
            
            print("🔄 TELEMETRY | Snapshot:")
            print("  - PendingWrites: \(hasPendingWrites)")
            print("  - IsFromCache: \(isFromCache)")
            print("  - Level: \(newLevel)")
            
            // CRITICAL: Only rebuild level if levelID actually changed
            guard newLevel != self.lastKnownLevelID else {
                // Level unchanged - just patch fields without rebuild
                
                // Update coins (scalar, no merge needed)
                if let coins = data["coins"] as? Int {
                    self.internalPlayer?.coins = coins
                }
                
                // UNION-BASED RECONCILIATION for arrays
                // Merge server bonus words with local optimistic state
                if let serverBonusWords = data["foundBonusWords"] as? [String] {
                    let serverSet = Set(serverBonusWords.map { StringCanonicalizer.canon($0) })
                    let localSet = self.internalPlayer?.foundBonusWords ?? []
                    
                    // Union server and local to preserve optimistic updates
                    let merged = serverSet.union(localSet)
                    self.internalPlayer?.foundBonusWords = merged
                    
                    print("  - Bonus delta: +\(merged.count - localSet.count) words")
                }
                
                // Union-based reconciliation for level progress
                if let serverProgress = data["levelProgress"] as? [String: [String]] {
                    var mergedProgress: [String: Set<String>] = [:]
                    
                    // Start with server data (canonicalized)
                    for (levelKey, words) in serverProgress {
                        mergedProgress[levelKey] = Set(words.map { StringCanonicalizer.canon($0) })
                    }
                    
                    // Union with local data to preserve optimistic updates
                    if let localProgress = self.internalPlayer?.levelProgress {
                        for (levelKey, localWords) in localProgress {
                            let canonWords = localWords.map { StringCanonicalizer.canon($0) }
                            if let serverWords = mergedProgress[levelKey] {
                                mergedProgress[levelKey] = serverWords.union(canonWords)
                            } else {
                                mergedProgress[levelKey] = Set(canonWords)
                            }
                        }
                    }
                    
                    // Check if EAST is present for telemetry
                    let currentLevelKey = StringCanonicalizer.levelKey(self.lastKnownLevelID ?? 0)
                    let hasEast = mergedProgress[currentLevelKey]?.contains("EAST") ?? false
                    print("  - Has 'EAST': \(hasEast)")
                    print("  - Level \(currentLevelKey) words: \(mergedProgress[currentLevelKey]?.count ?? 0)")
                    
                    self.internalPlayer?.levelProgress = mergedProgress
                }
                
                // Update playerData for UI
                if let player = self.internalPlayer {
                    let playerData = player.toPlayerData()
                    self.playerData = playerData
                    // Publish for GameViewModel reconciliation instead of direct navigation
                    self.progressSubject.send(playerData)
                }
                
                print("🔄 Reconciled with union semantics (no rebuild)")
                return
            }
            
            // Level actually changed - publish for reconciliation instead of direct navigation
            print("🚀 Level changed from \(self.lastKnownLevelID ?? 0) to \(newLevel)")
            self.lastKnownLevelID = newLevel
            
            // Update internal player with all data
            do {
                let playerModel = try snapshot?.data(as: Player.self)
                self.internalPlayer = playerModel
                if let playerData = playerModel?.toPlayerData() {
                    self.playerData = playerData
                    // Publish for GameViewModel to handle navigation logic
                    self.progressSubject.send(playerData)
                }
            } catch {
                print("❌ Error decoding player in snapshot: \(error)")
            }
        }
    }
    
    // Saves the player's current progress to Firestore using atomic updates
    // IMPORTANT: Only updates non-critical scalar fields, NOT arrays/counters/level
    func saveProgress(player: PlayerData) {
        guard let uid = AuthService.shared.uid else {
            print("Error: No authenticated user ID for saving progress")
            return
        }
        
        let playerDocRef = playerCollection.document(uid)
        
        // Only update non-critical scalar fields
        // DO NOT touch: currentLevelID, coins, totalWordsFound, arrays
        var updates: [String: Any] = [
            // currentLevelID - REMOVED, use updateCurrentLevelAtomic only
            // coins - REMOVED, use updateCoinsAtomic only
            "preferredDifficulty": player.preferredDifficulty.rawValue,
            "difficultyDrift": player.difficultyDrift,
            // totalWordsFound - REMOVED, increment atomically only
            "totalLevelsCompleted": player.totalLevelsCompleted,
            "longestWordFound": player.longestWordFound,
            "totalHintsUsed": player.totalHintsUsed,
            "perfectLevels": player.perfectLevels,
            "levelsPlayedSinceHint": player.levelsPlayedSinceHint,
            "consecutiveFailedGuesses": player.consecutiveFailedGuesses,
            "dailyStreak": player.dailyStreak,
            "totalRevelationsUsed": player.totalRevelationsUsed,
            "lastPlayedDate": FieldValue.serverTimestamp() // Use server timestamp to avoid clock skew
        ]
        
        // Handle optional fields
        if let lastDailyDate = player.lastDailyDate {
            updates["lastDailyDate"] = lastDailyDate
        }
        
        if let lastLevelDuration = player.lastLevelDuration {
            updates["lastLevelDuration"] = lastLevelDuration
        }
        
        // DO NOT update foundBonusWords or levelProgress here - use atomic helpers instead
        
        // Use updateData for atomic field updates
        playerDocRef.updateData(updates) { error in
            if let error = error {
                // If document doesn't exist, create it with setData
                if (error as NSError).code == FirestoreErrorCode.notFound.rawValue {
                    print("Document doesn't exist, creating new player document")
                    do {
                        let playerModel = Self.player(from: player)
                        var playerToSave = playerModel
                        playerToSave.id = nil  // Let Firestore manage the document ID
                        try playerDocRef.setData(from: playerToSave, merge: true) // Use merge for safety
                        print("Player document created successfully for uid: \(uid)")
                    } catch let createError {
                        print("❌ Error creating player document: \(createError.localizedDescription)")
                        print("❌ Full error: \(createError)")
                    }
                } else {
                    print("Error updating player progress: \(error)")
                }
            } else {
                print("Player progress updated successfully for uid: \(uid)")
            }
        }
    }

    // MARK: - Atomic Update Methods
    
    func updateBonusWords(_ words: Set<String>) {
        guard let uid = AuthService.shared.uid else { return }
        
        let playerDocRef = playerCollection.document(uid)
        // Update both the array and the counter atomically
        playerDocRef.updateData([
            "foundBonusWords": FieldValue.arrayUnion(Array(words)),
            "totalBonusWords": FieldValue.increment(Int64(words.count))
        ]) { error in
            if let error = error {
                print("Error updating bonus words: \(error)")
            }
        }
    }
    
    func updateLevelProgress(levelId: String, words: Set<String>) {
        guard let uid = AuthService.shared.uid else { return }
        
        let playerDocRef = playerCollection.document(uid)
        // Use arrayUnion to add words without overwriting
        playerDocRef.updateData([
            "levelProgress.\(levelId)": FieldValue.arrayUnion(Array(words)),
            "totalWordsFound": FieldValue.increment(Int64(words.count))
        ]) { error in
            if let error = error {
                print("Error updating level progress: \(error)")
            }
        }
    }
    
    func updateCoinsAtomic(_ amount: Int) {
        guard let uid = AuthService.shared.uid else { return }
        
        let playerDocRef = playerCollection.document(uid)
        playerDocRef.updateData([
            "coins": FieldValue.increment(Int64(amount))
        ]) { error in
            if let error = error {
                print("Error updating coins: \(error)")
            }
        }
    }
    
    func updateCurrentLevelAtomic(_ levelID: Int) {
        guard let uid = AuthService.shared.uid else { return }
        
        let playerDocRef = playerCollection.document(uid)
        playerDocRef.updateData([
            "currentLevelID": levelID,
            "lastSeenAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating current level: \(error)")
            }
        }
    }
    
    // MARK: - Debug Assertions
    
    #if DEBUG
    /// Runtime tripwire to catch rogue writers
    private func assertUIDPath(_ ref: DocumentReference) {
        guard let uid = AuthService.shared.uid else {
            preconditionFailure("🚨 No authenticated UID available")
        }
        let expectedPath = "players/\(uid)"
        precondition(ref.path == expectedPath, "🚨 Non-UID player write detected! Expected: \(expectedPath), Got: \(ref.path)")
    }
    #endif
    
    // MARK: - Batch Update for Word Finds
    
    /// Apply word find with coins and progress in a single batch to prevent half-applied states
    func applyWordFind(levelId: String, word: String, reward: Int) {
        guard let uid = AuthService.shared.uid else { return }
        
        let canonWord = StringCanonicalizer.canon(word)
        let levelKey = StringCanonicalizer.levelKey(Int(levelId) ?? 0)
        
        let ref = playerCollection.document(uid)
        
        #if DEBUG
        assertUIDPath(ref)
        #endif
        
        let batch = db.batch()
        
        // Telemetry
        let changes = ["levelProgress.\(levelKey)", "totalWordsFound", "coins"]
        print("📦 TELEMETRY | Batch Write:")
        print("  - Fields: \(changes)")
        print("  - Word: '\(canonWord)'")
        print("  - LevelKey: '\(levelKey)'")
        print("  - Reward: \(reward)")
        
        // Update level progress
        batch.updateData([
            "levelProgress.\(levelKey)": FieldValue.arrayUnion([canonWord])
        ], forDocument: ref)
        
        // Update total words counter
        batch.updateData([
            "totalWordsFound": FieldValue.increment(Int64(1))
        ], forDocument: ref)
        
        // Update coins
        batch.updateData([
            "coins": FieldValue.increment(Int64(reward))
        ], forDocument: ref)
        
        // Commit batch with retry on not-found
        batch.commit { [weak self] error in
            if let error = error {
                if (error as NSError).code == FirestoreErrorCode.notFound.rawValue {
                    print("⚠️ Document not found, ensuring it exists and retrying...")
                    Task {
                        await ProgressService.shared.ensurePlayerDoc(uid: uid)
                        // Retry once after ensuring doc exists
                        self?.applyWordFind(levelId: levelKey, word: canonWord, reward: reward)
                    }
                } else {
                    print("❌ Batch error applying word find: \(error)")
                }
            } else {
                print("✅ TELEMETRY | Firestore Write Confirmed:")
                print("  - Word persisted: '\(canonWord)'")
                print("  - Level: '\(levelKey)'")
            }
        }
    }
    
    /// Apply bonus word with coins in a single batch
    func applyBonusWord(_ word: String, reward: Int) {
        guard let uid = AuthService.shared.uid else { return }
        
        let canonWord = StringCanonicalizer.canon(word)
        let ref = playerCollection.document(uid)
        
        #if DEBUG
        assertUIDPath(ref)
        #endif
        
        let batch = db.batch()
        
        // Telemetry
        let changes = ["foundBonusWords", "totalBonusWords", "coins"]
        print("📦 TELEMETRY | Batch Write (Bonus):")
        print("  - Fields: \(changes)")
        print("  - Word: '\(canonWord)'")
        print("  - Reward: \(reward)")
        
        // Update bonus words array
        batch.updateData([
            "foundBonusWords": FieldValue.arrayUnion([canonWord])
        ], forDocument: ref)
        
        // Update bonus words counter
        batch.updateData([
            "totalBonusWords": FieldValue.increment(Int64(1))
        ], forDocument: ref)
        
        // Update coins
        batch.updateData([
            "coins": FieldValue.increment(Int64(reward))
        ], forDocument: ref)
        
        // Commit batch with retry on not-found
        batch.commit { [weak self] error in
            if let error = error {
                if (error as NSError).code == FirestoreErrorCode.notFound.rawValue {
                    print("⚠️ Document not found, ensuring it exists and retrying...")
                    Task {
                        await ProgressService.shared.ensurePlayerDoc(uid: uid)
                        // Retry once after ensuring doc exists
                        self?.applyBonusWord(canonWord, reward: reward)
                    }
                } else {
                    print("❌ Batch error applying bonus word: \(error)")
                }
            } else {
                print("✅ TELEMETRY | Firestore Write Confirmed (Bonus):")
                print("  - Bonus persisted: '\(canonWord)'")
                print("  - Reward: \(reward)")
            }
        }
    }

    // MARK: - Batch Level Completion
    
    /// Complete level with all updates in a single batch
    func completeLevelBatch(currentLevelID: Int, nextLevelID: Int, perfectLevel: Bool = false) {
        guard let uid = AuthService.shared.uid else { return }
        
        let ref = playerCollection.document(uid)
        
        #if DEBUG
        assertUIDPath(ref)
        #endif
        
        let batch = db.batch()
        
        // Log what we're changing
        let changes = ["currentLevelID", "totalLevelsCompleted", "perfectLevels", "lastSeenAt"]
        print("🏆 Completing level \(currentLevelID) -> \(nextLevelID) - fields: \(changes)")
        
        // Update current level
        batch.updateData([
            "currentLevelID": nextLevelID,
            "lastSeenAt": FieldValue.serverTimestamp()
        ], forDocument: ref)
        
        // Increment completion counter
        batch.updateData([
            "totalLevelsCompleted": FieldValue.increment(Int64(1))
        ], forDocument: ref)
        
        // Update perfect levels if applicable
        if perfectLevel {
            batch.updateData([
                "perfectLevels": FieldValue.increment(Int64(1))
            ], forDocument: ref)
        }
        
        // Commit batch
        batch.commit { error in
            if let error = error {
                print("❌ Batch error completing level: \(error)")
            } else {
                print("✅ Level completion batch applied: \(currentLevelID) -> \(nextLevelID)")
            }
        }
    }
    
    // MARK: - Ensure Document Exists
    
    /// Ensure player document exists before any operations
    func ensurePlayerDocumentExists() async {
        guard let uid = AuthService.shared.uid else {
            print("❌ No UID available for ensurePlayerDocumentExists")
            return
        }
        
        await ProgressService.shared.ensurePlayerDoc(uid: uid)
    }

    /// Generates a simplified PlayerData struct for adaptive level logic
    // Protocol methods implementation
    func initializePlayer() {
        // Already handled in fetchOrCreatePlayer
    }
    
    func updateCurrentLevel(_ levelID: Int) {
        guard var currentPlayer = self.internalPlayer else { return }
        
        // Only update if level actually changed
        guard currentPlayer.currentLevelID != levelID else {
            print("Level already set to \(levelID), skipping update")
            return
        }
        
        currentPlayer.currentLevelID = levelID
        self.lastKnownLevelID = levelID
        self.internalPlayer = currentPlayer
        
        // Use atomic update for currentLevelID to avoid overwriting other fields
        updateCurrentLevelAtomic(levelID)
    }
    
    func addCoins(_ amount: Int) {
        guard var currentPlayer = self.internalPlayer else { return }
        currentPlayer.coins += amount
        self.internalPlayer = currentPlayer
        // Use atomic update to avoid overwriting other fields
        updateCoinsAtomic(amount)
    }
    
    func spendCoins(_ amount: Int) -> Bool {
        guard var currentPlayer = self.internalPlayer else { return false }
        if currentPlayer.coins >= amount {
            currentPlayer.coins -= amount
            self.internalPlayer = currentPlayer
            // Use atomic update to avoid overwriting other fields
            updateCoinsAtomic(-amount)
            return true
        }
        return false
    }
    
    func generatePlayerData() -> PlayerData {
        guard let player = self.internalPlayer else {
            // Use authenticated user ID if available, never create random UUIDs
            let playerId = AuthService.shared.uid ?? "temp-user"
            return PlayerData(
                id: playerId,
                completedLevelIDs: [],
                usesHintsOften: false,
                isStruggling: false,
                preferredDifficulty: .easy,
                difficultyDrift: 0,
                coins: 0,
                dailyStreak: 0,
                lastDailyDate: nil,
                currentLevelID: 1,
                levelProgress: [:],
                foundBonusWords: [],
                totalWordsFound: 0,
                totalLevelsCompleted: 0,
                longestWordFound: 0,
                totalHintsUsed: 0,
                perfectLevels: 0,
                lastPlayedDate: Date(),
                totalRevelationsUsed: 0,
                levelsPlayedSinceHint: 0,
                consecutiveFailedGuesses: 0,
                lastLevelDuration: nil
            )
        }

        return Self.playerData(from: player)
    }
    
    func update(player: PlayerData) {
        // This function exists to allow PlayerData-driven systems to influence the full Player model.
        self.playerData = player
        self.internalPlayer = player.toPlayer()
    }
    
    /// Call this when today's Daily Challenge level is completed.
    func markDailyChallengeCompleted() {
        guard var currentPlayer = self.internalPlayer else { return }
        DailyChallengeService.shared.recordCompletion(for: &currentPlayer)
        self.internalPlayer = currentPlayer
        self.playerData = currentPlayer.toPlayerData()
        saveProgress(player: Self.playerData(from: currentPlayer))
        // Unlock 7‑Day streak achievement via Game Center
        if currentPlayer.dailyStreak == 7 {
            GameCenterService.shared.unlock(.sevenDayStreak)
        }
    }
    
    func calculateDynamicDifficulty() -> Int {
        guard let player = self.internalPlayer else { return 0 }
        var modifier = 0
        
        // Time away adjustment (easier comeback)
        if let lastPlayed = player.lastPlayedDate {
            let daysSince = Date().timeIntervalSince(lastPlayed) / (24 * 60 * 60)
            if daysSince > 7 { modifier -= 2 }
            else if daysSince > 3 { modifier -= 1 }
        }
        
        // Performance adjustment  
        if let avgTime = player.lastLevelDuration {
            if avgTime < 60 { modifier += 2 }      // Very fast = much harder
            else if avgTime < 120 { modifier += 1 } // Fast = slightly harder
            else if avgTime > 300 { modifier -= 1 } // Slow = easier
        }
        
        // Streak bonus (confident players get harder levels)
        if player.dailyStreak > 7 { modifier += 1 }
        
        // Hint dependency (heavy hint users get easier levels)
        let hintsPerLevel = player.totalLevelsCompleted > 0 ? 
            Double(player.totalHintsUsed) / Double(player.totalLevelsCompleted) : 0
        if hintsPerLevel > 2 { modifier -= 1 }
        
        return max(-2, min(2, modifier)) // Cap at ±2 difficulty shifts
    }

    func selectLevelWithDynamicDifficulty(from levels: [Level]) -> Level? {
        guard let player = self.internalPlayer else { return levels.first }
        
        let dynamicModifier = calculateDynamicDifficulty()
        let difficulties = ["easy", "medium", "hard", "expert"]
        let baseIndex = difficulties.firstIndex(of: player.preferredDifficulty.rawValue) ?? 0
        let targetIndex = max(0, min(3, baseIndex + dynamicModifier))
        let targetDifficulty = difficulties[targetIndex]
        
        // Filter to target difficulty + unplayed levels
        let candidates = levels.filter { level in
            level.metadata?.difficulty.rawValue == targetDifficulty &&
            !player.levelProgress.keys.contains(String(level.id))
        }
        
        // Fallback chain if no candidates
        if !candidates.isEmpty {
            return candidates.randomElement()
        } else {
            // Try any unplayed level
            let anyUnplayed = levels.filter { level in
                !player.levelProgress.keys.contains(String(level.id))
            }
            return anyUnplayed.randomElement() ?? levels.randomElement()
        }
    }
}
