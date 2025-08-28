//
//  LevelIndex.swift
//  RuneWords
//
//  WO-001: Level indexing system for robust level management
//

import Foundation

/// Represents a single level chunk file entry
struct LevelIndex: Codable, Equatable {
    let file: String
    let firstID: Int
    let lastID: Int
    let count: Int
    
    /// Check if this entry contains the given level ID
    func contains(_ levelID: Int) -> Bool {
        return levelID >= firstID && levelID <= lastID
    }
}

/// Level catalog that provides efficient lookup and navigation across level chunks
@MainActor
final class LevelCatalog: ObservableObject {
    private(set) var entries: [LevelIndex] = []
    private(set) var totalLevelCount: Int = 0
    
    // Cache for valid level IDs for fast random selection
    private var validLevelIDs: Set<Int> = []
    
    init() {}
    
    /// Initialize with level index entries (sorted by firstID)
    init(entries: [LevelIndex]) {
        self.entries = entries.sorted { $0.firstID < $1.firstID }
        self.totalLevelCount = entries.reduce(0) { $0 + $1.count }
        self.validLevelIDs = Set(entries.flatMap { entry in
            entry.firstID...entry.lastID
        })
        
        validateEntries()
    }
    
    // MARK: - Public API
    
    /// Find the entry that contains the given level ID
    func entry(containing levelID: Int) -> LevelIndex? {
        return entries.first { $0.contains(levelID) }
    }
    
    /// Get the next existing level ID after the given ID
    func nextExistingID(after levelID: Int) -> Int? {
        // Find next ID in same entry first
        if let entry = entry(containing: levelID), levelID < entry.lastID {
            return levelID + 1
        }
        
        // Find next entry
        if let nextEntry = entries.first(where: { $0.firstID > levelID }) {
            return nextEntry.firstID
        }
        
        return nil
    }
    
    /// Get the previous existing level ID before the given ID
    func previousExistingID(before levelID: Int) -> Int? {
        // Find previous ID in same entry first
        if let entry = entry(containing: levelID), levelID > entry.firstID {
            return levelID - 1
        }
        
        // Find previous entry
        if let previousEntry = entries.last(where: { $0.lastID < levelID }) {
            return previousEntry.lastID
        }
        
        return nil
    }
    
    /// Get a random valid level ID
    func randomLevelID() -> Int? {
        guard !validLevelIDs.isEmpty else { return nil }
        return validLevelIDs.randomElement()
    }
    
    /// Check if a level ID exists in any chunk
    func isValidLevelID(_ levelID: Int) -> Bool {
        return validLevelIDs.contains(levelID)
    }
    
    /// Get all valid level IDs in sorted order
    func allLevelIDs() -> [Int] {
        return validLevelIDs.sorted()
    }
    
    /// Get the minimum level ID across all chunks
    var minLevelID: Int {
        return entries.first?.firstID ?? 1
    }
    
    /// Get the maximum level ID across all chunks
    var maxLevelID: Int {
        return entries.last?.lastID ?? 1
    }
    
    // MARK: - Internal Validation
    
    /// Validate that entries have no overlaps and are properly ordered
    private func validateEntries() {
        guard !entries.isEmpty else { return }
        
        for i in 1..<entries.count {
            let previous = entries[i-1]
            let current = entries[i]
            
            // Check for overlaps
            if current.firstID <= previous.lastID {
                print("⚠️ LevelCatalog: Overlap detected between \(previous.file) and \(current.file)")
            }
            
            // Check for gaps (warn but don't fail)
            if current.firstID > previous.lastID + 1 {
                let gapStart = previous.lastID + 1
                let gapEnd = current.firstID - 1
                print("ℹ️ LevelCatalog: Gap in level IDs from \(gapStart) to \(gapEnd)")
            }
        }
        
        print("✅ LevelCatalog initialized with \(entries.count) files, \(totalLevelCount) total levels")
        print("📍 Level ID range: \(minLevelID) - \(maxLevelID)")
    }
}

/// Loader for level catalog with fallback to runtime generation
final class LevelCatalogLoader {
    
    /// Load level catalog from bundled LevelIndex.json or generate from files
    static func loadCatalog() async -> LevelCatalog {
        // First try to load from bundled index
        if let catalog = await loadFromBundledIndex() {
            return catalog
        }
        
        // Fallback to runtime generation
        print("⚠️ Bundled LevelIndex.json not found or invalid, generating from bundle files...")
        return await generateFromBundle()
    }
    
    // MARK: - Private Loading Methods
    
    /// Load from bundled LevelIndex.json file
    private static func loadFromBundledIndex() async -> LevelCatalog? {
        guard let url = Bundle.main.url(forResource: "LevelIndex", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("📄 LevelIndex.json not found in bundle")
            return nil
        }
        
        do {
            let entries = try JSONDecoder().decode([LevelIndex].self, from: data)
            print("✅ Loaded LevelIndex.json with \(entries.count) entries")
            return await MainActor.run { LevelCatalog(entries: entries) }
        } catch {
            print("❌ Error decoding LevelIndex.json: \(error)")
            return nil
        }
    }
    
    /// Generate catalog by scanning bundle files
    private static func generateFromBundle() async -> LevelCatalog {
        var discoveredEntries: [LevelIndex] = []
        
        // Look for level chunk files
        guard let bundlePath = Bundle.main.resourcePath else {
            print("❌ Could not access bundle path")
            return await MainActor.run { LevelCatalog() }
        }
        
        // Scan for level files with various patterns
        let patterns = ["levels-chunk-*.json", "levels-*.json"]
        
        for pattern in patterns {
            let files = findFiles(matching: pattern, in: bundlePath)
            
            for filePath in files {
                if let entry = await processLevelFile(at: filePath) {
                    discoveredEntries.append(entry)
                }
            }
        }
        
        if discoveredEntries.isEmpty {
            print("⚠️ No level files discovered during runtime scan")
        } else {
            print("🔍 Runtime scan discovered \(discoveredEntries.count) level files")
        }
        
        let finalEntries = discoveredEntries
        return await MainActor.run { LevelCatalog(entries: finalEntries) }
    }
    
    /// Find files matching pattern in directory
    private static func findFiles(matching pattern: String, in directory: String) -> [String] {
        // Simple glob implementation for level files
        let fileManager = FileManager.default
        
        do {
            let allFiles = try fileManager.contentsOfDirectory(atPath: directory)
            
            // Convert glob pattern to simple matching
            if pattern.contains("levels-chunk-") {
                return allFiles.filter { $0.hasPrefix("levels-chunk-") && $0.hasSuffix(".json") }
                    .map { directory + "/" + $0 }
            } else if pattern.contains("levels-") {
                return allFiles.filter { $0.hasPrefix("levels-") && $0.hasSuffix(".json") }
                    .map { directory + "/" + $0 }
            }
        } catch {
            print("❌ Error scanning directory \(directory): \(error)")
        }
        
        return []
    }
    
    /// Process a single level file and extract metadata
    private static func processLevelFile(at filePath: String) async -> LevelIndex? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            
            // Parse as array of levels to extract IDs
            if let levels = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let ids = levels.compactMap { $0["id"] as? Int }
                
                guard !ids.isEmpty else {
                    print("⚠️ No valid level IDs found in \(filePath)")
                    return nil
                }
                
                let firstID = ids.min() ?? 0
                let lastID = ids.max() ?? 0
                let count = levels.count
                
                // Convert to bundle-relative path
                let bundleRelativePath = filePath.replacingOccurrences(
                    of: Bundle.main.resourcePath! + "/", 
                    with: ""
                )
                
                return LevelIndex(
                    file: bundleRelativePath,
                    firstID: firstID,
                    lastID: lastID,
                    count: count
                )
            }
        } catch {
            print("❌ Error processing level file \(filePath): \(error)")
        }
        
        return nil
    }
}
