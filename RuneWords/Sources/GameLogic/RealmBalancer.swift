//
//  RealmBalancer.swift
//  RuneWords
//
//  WO-003: Realm assignment and balancing logic
//

import Foundation

/// Assigns levels to realms based on difficulty scores and target distributions
struct RealmBalancer {
    
    // MARK: - Configuration
    
    /// Target counts for each realm (adaptive to corpus size)
    struct RealmTargets {
        let treelibrary: Int    // Easy + low Medium
        let crystalforest: Int  // Mid Medium + some Easy/Hard 
        let sleepingtitan: Int  // Hard
        let astralpeak: Int     // Expert + late Hard
        
        /// Default targets for ~3790 levels
        static let `default` = RealmTargets(
            treelibrary: 1000,
            crystalforest: 1700, 
            sleepingtitan: 700,
            astralpeak: 390
        )
        
        /// Adaptive targets based on actual level count
        static func adaptive(totalLevels: Int) -> RealmTargets {
            let scale = Double(totalLevels) / 3790.0
            return RealmTargets(
                treelibrary: Int(1000 * scale),
                crystalforest: Int(1700 * scale),
                sleepingtitan: Int(700 * scale),
                astralpeak: Int(390 * scale)
            )
        }
    }
    
    // MARK: - Public API
    
    /// Generate complete realm map from difficulty buckets
    static func generateRealmMap(
        from buckets: DifficultyBuckets,
        targets: RealmTargets = .default
    ) -> [LevelRealmAssignment] {
        print("🗺️ Generating realm map with targets:")
        print("  Tree Library: \(targets.treelibrary)")
        print("  Crystal Forest: \(targets.crystalforest)")
        print("  Sleeping Titan: \(targets.sleepingtitan)")
        print("  Astral Peak: \(targets.astralpeak)")
        
        var assignments: [LevelRealmAssignment] = []
        let totalLevels = buckets.allScores.count
        
        // Create pools of levels organized by difficulty
        var easyPool = buckets.easy
        var mediumPool = buckets.medium
        var hardPool = buckets.hard
        let expertPool = buckets.expert
        
        // 1. TREE LIBRARY: Easy + low Medium (first ~40% of Medium)
        let mediumForTree = Int(Double(mediumPool.count) * 0.4)
        let treeLevels = fillRealm(
            realm: "treelibrary",
            targetCount: targets.treelibrary,
            sources: [
                ArraySlice(easyPool),
                mediumPool.prefix(mediumForTree)
            ],
            totalLevels: totalLevels
        )
        assignments.append(contentsOf: treeLevels)
        
        // Clear the used easy pool
        easyPool.removeAll()
        
        // Remove used medium levels
        if mediumForTree > 0 {
            mediumPool.removeFirst(min(mediumForTree, mediumPool.count))
        }
        
        // 2. CRYSTAL FOREST: Remaining Medium + Easy overflow + early Hard
        let hardForCrystal = Int(Double(hardPool.count) * 0.2) // First 20% of hard
        let crystalLevels = fillRealm(
            realm: "crystalforest", 
            targetCount: targets.crystalforest,
            sources: [
                ArraySlice(easyPool), // Any remaining easy
                ArraySlice(mediumPool),
                hardPool.prefix(hardForCrystal)
            ],
            totalLevels: totalLevels
        )
        assignments.append(contentsOf: crystalLevels)
        
        // Clear used pools
        easyPool.removeAll()
        mediumPool.removeAll()
        
        // Remove used hard levels
        if hardForCrystal > 0 {
            hardPool.removeFirst(min(hardForCrystal, hardPool.count))
        }
        
        // 3. SLEEPING TITAN: Remaining Hard + overflow Medium
        let sleepingLevels = fillRealm(
            realm: "sleepingtitan",
            targetCount: targets.sleepingtitan, 
            sources: [
                ArraySlice(hardPool),
                ArraySlice(mediumPool) // Any overflow medium
            ],
            totalLevels: totalLevels
        )
        assignments.append(contentsOf: sleepingLevels)
        
        // Clear used pools
        hardPool.removeAll()
        mediumPool.removeAll()
        
        // 4. ASTRAL PEAK: Expert + remaining Hard
        let astralLevels = fillRealm(
            realm: "astralpeak",
            targetCount: targets.astralpeak,
            sources: [
                ArraySlice(expertPool),
                ArraySlice(hardPool) // Any remaining hard
            ],
            totalLevels: totalLevels
        )
        assignments.append(contentsOf: astralLevels)
        
        // Sort by realm order and index within realm
        assignments.sort { lhs, rhs in
            if lhs.realm != rhs.realm {
                return realmOrder(lhs.realm) < realmOrder(rhs.realm)
            }
            return lhs.indexInRealm < rhs.indexInRealm
        }
        
        printRealmSummary(assignments, targets: targets)
        
        return assignments
    }
    
    // MARK: - Private Helpers
    
    /// Fill a realm with levels from multiple sources up to target count
    private static func fillRealm(
        realm: String,
        targetCount: Int,
        sources: [ArraySlice<LevelScore>],
        totalLevels: Int
    ) -> [LevelRealmAssignment] {
        var assignments: [LevelRealmAssignment] = []
        var remainingTarget = targetCount
        
        // Flatten sources while maintaining difficulty order
        let allSources = sources.flatMap { Array($0) }
        let sortedLevels = allSources.sorted { $0.score < $1.score }
        
        for (index, levelScore) in sortedLevels.enumerated() {
            guard remainingTarget > 0 else { break }
            
            // Calculate quantile position (0.0 - 1.0)
            let quantile = Double(index) / Double(max(1, sortedLevels.count - 1))
            
            let assignment = LevelRealmAssignment(
                id: levelScore.id,
                realm: realm,
                difficulty: inferDifficulty(from: levelScore.score, quantile: quantile),
                indexInRealm: assignments.count,
                scoreQuantile: quantile
            )
            
            assignments.append(assignment)
            remainingTarget -= 1
        }
        
        return assignments
    }
    
    /// Infer difficulty string from score and quantile
    private static func inferDifficulty(from score: Double, quantile: Double) -> String {
        // Use quantile-based assignment for consistency
        switch quantile {
        case 0.0..<0.40: return "easy"
        case 0.40..<0.80: return "medium"
        case 0.80..<0.95: return "hard"
        default: return "expert"
        }
    }
    
    /// Realm ordering for sorting
    private static func realmOrder(_ realm: String) -> Int {
        switch realm {
        case "treelibrary": return 0
        case "crystalforest": return 1
        case "sleepingtitan": return 2
        case "astralpeak": return 3
        default: return 999
        }
    }
    
    /// Print summary of realm assignments
    private static func printRealmSummary(_ assignments: [LevelRealmAssignment], targets: RealmTargets) {
        let grouped = Dictionary(grouping: assignments) { $0.realm }
        
        print("✅ Realm assignment complete:")
        
        for realm in ["treelibrary", "crystalforest", "sleepingtitan", "astralpeak"] {
            let levels = grouped[realm] ?? []
            let target = [targets.treelibrary, targets.crystalforest, 
                         targets.sleepingtitan, targets.astralpeak][realmOrder(realm)]
            
            let difficulties = Dictionary(grouping: levels) { $0.difficulty }
            let diffCounts = difficulties.mapValues { $0.count }
            
            let percentage = target > 0 ? Double(levels.count) / Double(target) * 100 : 0
            
            print("  \(realm): \(levels.count)/\(target) (\(Int(percentage))%)")
            print("    Easy: \(diffCounts["easy"] ?? 0), Medium: \(diffCounts["medium"] ?? 0), Hard: \(diffCounts["hard"] ?? 0), Expert: \(diffCounts["expert"] ?? 0)")
        }
        
        print("📊 Total assigned: \(assignments.count) levels")
    }
    
    // MARK: - Data Persistence
    
    /// Save realm map to Sources/Data/LevelRealmMap.json
    static func saveRealmMap(_ assignments: [LevelRealmAssignment], to filePath: String) throws {
        let data = try JSONEncoder().encode(assignments)
        try data.write(to: URL(fileURLWithPath: filePath))
        print("💾 Saved realm map to \(filePath)")
    }
    
    /// Save level buckets to Sources/Data/LevelBuckets.json
    static func saveBuckets(_ buckets: DifficultyBuckets, to filePath: String) throws {
        let allLevels = buckets.allScores.map { score in
            return [
                "id": score.id,
                "difficulty": buckets.difficulty(for: score.id)?.rawValue ?? "unknown",
                "score": score.score
            ]
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: allLevels, options: .prettyPrinted)
        try jsonData.write(to: URL(fileURLWithPath: filePath))
        print("💾 Saved difficulty buckets to \(filePath)")
    }
}