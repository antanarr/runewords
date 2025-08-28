//
//  RealmBalancerCommand.swift
//  RuneWords
//
//  WO-003: CLI-style command for re-running realm balancer (Debug only)
//

import Foundation
import SwiftUI

#if DEBUG
/// Debug-only command to regenerate realm maps and difficulty buckets
struct RealmBalancerCommand {
    
    /// Run the complete balancing process and save results
    static func runBalancer() async {
        print("🚀 Running Realm Balancer...")
        
        guard let catalog = await loadCatalog() else {
            print("❌ Failed to load level catalog")
            return
        }
        
        // 1. Score all levels
        let params = DifficultyScorer.ScoringParams.default
        let scores = await DifficultyScorer.scoreAllLevels(
            catalog: catalog,
            levelService: LevelService.shared,
            params: params
        )
        
        guard !scores.isEmpty else {
            print("❌ No levels scored")
            return
        }
        
        // 2. Generate difficulty buckets
        let buckets = DifficultyScorer.generateBuckets(from: scores)
        
        // 3. Generate realm assignments
        let targets = RealmBalancer.RealmTargets.adaptive(totalLevels: scores.count)
        let realmMap = RealmBalancer.generateRealmMap(from: buckets, targets: targets)
        
        // 4. Save results
        await saveResults(scores: scores, buckets: buckets, realmMap: realmMap)
        
        // 5. Print summary
        printBalancerSummary(scores: scores, buckets: buckets, realmMap: realmMap)
    }
    
    // MARK: - Private Helpers
    
    /// Load the level catalog
    private static func loadCatalog() async -> LevelCatalog? {
        return await LevelCatalogLoader.loadCatalog()
    }
    
    /// Save all generated data files
    private static func saveResults(
        scores: [LevelScore],
        buckets: DifficultyBuckets,  
        realmMap: [LevelRealmAssignment]
    ) async {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            // Save difficulty scores cache
            let scoresData = try JSONEncoder().encode(scores)
            let scoresURL = documentsURL.appendingPathComponent("level_difficulty.json")
            try scoresData.write(to: scoresURL)
            print("💾 Saved level difficulty scores to Documents/level_difficulty.json")
            
            // Save buckets
            let bucketsURL = documentsURL.appendingPathComponent("LevelBuckets.json")
            try RealmBalancer.saveBuckets(buckets, to: bucketsURL.path)
            
            // Save realm map
            let realmMapURL = documentsURL.appendingPathComponent("LevelRealmMap.json")
            try RealmBalancer.saveRealmMap(realmMap, to: realmMapURL.path)
            
            print("📁 All files saved to Documents directory")
            print("  - level_difficulty.json (\(scores.count) entries)")
            print("  - LevelBuckets.json (\(buckets.allScores.count) entries)")
            print("  - LevelRealmMap.json (\(realmMap.count) entries)")
            
        } catch {
            print("❌ Error saving files: \(error)")
        }
    }
    
    /// Print comprehensive summary
    private static func printBalancerSummary(
        scores: [LevelScore],
        buckets: DifficultyBuckets,
        realmMap: [LevelRealmAssignment]
    ) {
        print("\n" + String(repeating: "=", count: 50))
        print("📊 REALM BALANCER SUMMARY")
        print(String(repeating: "=", count: 50))
        
        // Score distribution
        let sortedScores = scores.sorted { $0.score < $1.score }
        let minScore = sortedScores.first?.score ?? 0
        let maxScore = sortedScores.last?.score ?? 0
        let medianScore = sortedScores[sortedScores.count / 2].score
        let p95Score = sortedScores[Int(Double(sortedScores.count) * 0.95)].score
        let p99Score = sortedScores[Int(Double(sortedScores.count) * 0.99)].score
        
        print("\n🎯 DIFFICULTY SCORE DISTRIBUTION")
        print("  Min: \(String(format: "%.2f", minScore))")
        print("  Median: \(String(format: "%.2f", medianScore))")
        print("  95th percentile: \(String(format: "%.2f", p95Score))")
        print("  99th percentile: \(String(format: "%.2f", p99Score))")
        print("  Max: \(String(format: "%.2f", maxScore))")
        
        // Bucket counts
        print("\n📦 DIFFICULTY BUCKETS")
        print("  Easy (0-40th): \(buckets.easy.count) levels")
        print("  Medium (40-80th): \(buckets.medium.count) levels")
        print("  Hard (80-95th): \(buckets.hard.count) levels")
        print("  Expert (95-100th): \(buckets.expert.count) levels")
        
        // Realm assignments
        let realmGroups = Dictionary(grouping: realmMap) { $0.realm }
        print("\n🗺️ REALM ASSIGNMENTS")
        for realm in ["treelibrary", "crystalforest", "sleepingtitan", "astralpeak"] {
            if let levels = realmGroups[realm] {
                let difficulties = Dictionary(grouping: levels) { $0.difficulty }
                print("  \(realm): \(levels.count) levels")
                print("    Easy: \(difficulties["easy"]?.count ?? 0)")
                print("    Medium: \(difficulties["medium"]?.count ?? 0)")
                print("    Hard: \(difficulties["hard"]?.count ?? 0)")
                print("    Expert: \(difficulties["expert"]?.count ?? 0)")
            }
        }
        
        print("\n✅ Balancer completed successfully!")
        print(String(repeating: "=", count: 50) + "\n")
    }
}

// MARK: - Debug Menu Integration

#if DEBUG
extension RealmBalancerCommand {
    /// Add to a debug menu or settings
    static func addToDebugMenu() -> some View {
        Button("🔄 Regenerate Realm Balance") {
            Task {
                await runBalancer()
            }
        }
    }
}
#endif

#endif