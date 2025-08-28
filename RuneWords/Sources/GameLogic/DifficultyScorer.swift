//
//  DifficultyScorer.swift
//  RuneWords
//
//  WO-003: Difficulty scoring system for balanced progression
//

import Foundation

/// Scores level difficulty based on letter weights, solution count, and other factors
struct DifficultyScorer {
    
    // MARK: - Configuration
    
    /// Tuneable scoring parameters (RemoteConfig-backed)
    struct ScoringParams {
        let solutionCountWeight: Double    // α: penalty for many solutions
        let averageWordLengthWeight: Double // β: bonus for longer words
        let rareLetterWeight: Double       // γ: bonus for rare letters
        
        static let `default` = ScoringParams(
            solutionCountWeight: 0.015,
            averageWordLengthWeight: 0.25,
            rareLetterWeight: 0.8
        )
    }
    
    // MARK: - Letter Frequency Weights
    
    /// English letter frequency-based weights (higher = rarer/harder)
    private static let letterWeights: [Character: Double] = [
        // Common letters (lower weight)
        "E": 0.5, "T": 0.6, "A": 0.7, "O": 0.8, "I": 0.9, "N": 1.0,
        "S": 1.0, "H": 1.1, "R": 1.2,
        
        // Medium frequency
        "D": 1.3, "L": 1.4, "C": 1.5, "U": 1.6, "M": 1.7, "W": 1.8,
        "F": 1.9, "G": 2.0, "Y": 2.1, "P": 2.2, "B": 2.3,
        
        // Less common
        "V": 2.5, "K": 2.7, "J": 3.0, "X": 3.2, "Q": 3.5, "Z": 3.8
    ]
    
    /// Letters that get rare letter bonus
    private static let rareLetters: Set<Character> = ["J", "Q", "X", "Z", "K", "V"]
    
    // MARK: - Public API
    
    /// Score a single level's difficulty
    static func score(for level: Level, params: ScoringParams = .default) -> Double {
        let baseLetters = level.baseLetters.uppercased()
        let solutions = level.solutions
        
        // 1. Base letter weight sum
        let letterScore = baseLetters.compactMap { letterWeights[$0] }.reduce(0, +)
        
        // 2. Solution count penalty (more solutions = easier)
        let solutionPenalty = params.solutionCountWeight * Double(solutions.count)
        
        // 3. Average word length bonus (longer words = harder)
        let averageLength = solutions.isEmpty ? 0 : 
            Double(solutions.keys.map(\.count).reduce(0, +)) / Double(solutions.count)
        let lengthBonus = params.averageWordLengthWeight * averageLength
        
        // 4. Rare letter bonus
        let rareLetterCount = baseLetters.filter { rareLetters.contains($0) }.count
        let rareBonus = params.rareLetterWeight * Double(rareLetterCount)
        
        let totalScore = letterScore - solutionPenalty + lengthBonus + rareBonus
        
        #if DEBUG
        print("Level \(level.id): letters=\(letterScore), solutions=-\(solutionPenalty), length=+\(lengthBonus), rare=+\(rareBonus) → \(totalScore)")
        #endif
        
        return max(0.1, totalScore) // Ensure positive score
    }
    
    /// Score all levels and return sorted by score
    static func scoreAllLevels(
        catalog: LevelCatalog, 
        levelService: LevelService,
        params: ScoringParams = .default
    ) async -> [LevelScore] {
        var scores: [LevelScore] = []
        
        print("🔢 Scoring \(await catalog.totalLevelCount) levels for difficulty...")
        
        // Load and score levels from each file
        for entry in await catalog.entries {
            guard let levels = await loadLevelsFromFile(entry.file) else {
                continue
            }
            
            for level in levels {
                let score = self.score(for: level, params: params)
                scores.append(LevelScore(id: level.id, score: score))
            }
        }
        
        // Sort by score (ascending = easier first)
        scores.sort { $0.score < $1.score }
        
        print("✅ Scored \(scores.count) levels")
        print("📊 Score range: \(scores.first?.score ?? 0) - \(scores.last?.score ?? 0)")
        
        return scores
    }
    
    /// Generate difficulty buckets from score distribution
    static func generateBuckets(from scores: [LevelScore]) -> DifficultyBuckets {
        guard !scores.isEmpty else {
            return DifficultyBuckets(easy: [], medium: [], hard: [], expert: [])
        }
        
        let sortedScores = scores.sorted { $0.score < $1.score }
        let count = sortedScores.count
        
        // Calculate quantile indices
        let easyEnd = Int(Double(count) * 0.40)      // 0-40th percentile
        let mediumEnd = Int(Double(count) * 0.80)    // 40-80th percentile  
        let hardEnd = Int(Double(count) * 0.95)      // 80-95th percentile
        // Expert is 95-100th percentile
        
        let easy = Array(sortedScores[0..<easyEnd])
        let medium = Array(sortedScores[easyEnd..<mediumEnd])
        let hard = Array(sortedScores[mediumEnd..<hardEnd])
        let expert = Array(sortedScores[hardEnd..<count])
        
        let buckets = DifficultyBuckets(easy: easy, medium: medium, hard: hard, expert: expert)
        
        print("📊 Difficulty buckets generated:")
        print("  Easy: \(easy.count) levels (scores \(easy.first?.score ?? 0) - \(easy.last?.score ?? 0))")
        print("  Medium: \(medium.count) levels (scores \(medium.first?.score ?? 0) - \(medium.last?.score ?? 0))")
        print("  Hard: \(hard.count) levels (scores \(hard.first?.score ?? 0) - \(hard.last?.score ?? 0))")
        print("  Expert: \(expert.count) levels (scores \(expert.first?.score ?? 0) - \(expert.last?.score ?? 0))")
        
        return buckets
    }
    
    // MARK: - Helper Functions
    
    /// Load levels from a specific file (similar to CorpusIntegrityTests)
    private static func loadLevelsFromFile(_ filePath: String) async -> [Level]? {
        let fileName = filePath.replacingOccurrences(of: ".json", with: "")
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("⚠️ Could not find file: \(filePath)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let levels = try JSONDecoder().decode([Level].self, from: data)
            return levels
        } catch {
            print("❌ Error loading levels from \(filePath): \(error)")
            return nil
        }
    }
}

// MARK: - Data Structures

/// A level's computed difficulty score
struct LevelScore: Codable, Equatable {
    let id: Int
    let score: Double
}

/// Organized difficulty buckets
struct DifficultyBuckets {
    let easy: [LevelScore]
    let medium: [LevelScore]
    let hard: [LevelScore]
    let expert: [LevelScore]
    
    var allScores: [LevelScore] {
        return easy + medium + hard + expert
    }
    
    func difficulty(for levelID: Int) -> Difficulty? {
        if easy.contains(where: { $0.id == levelID }) { return .easy }
        if medium.contains(where: { $0.id == levelID }) { return .medium }
        if hard.contains(where: { $0.id == levelID }) { return .hard }
        if expert.contains(where: { $0.id == levelID }) { return .expert }
        return nil
    }
}

/// Realm assignment with progression metadata
struct LevelRealmAssignment: Codable {
    let id: Int
    let realm: String
    let difficulty: String
    let indexInRealm: Int
    let scoreQuantile: Double // 0.0-1.0 position in overall distribution
}