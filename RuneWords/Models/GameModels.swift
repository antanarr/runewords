import Foundation
import CoreGraphics
import SwiftUI

enum Difficulty: String, Codable, Comparable {
    case easy, medium, hard, expert

    /// Numeric weight for difficulty comparisons.
    var weight: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        case .expert: return 3
        }
    }

    static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        return lhs.weight < rhs.weight
    }
}

struct LevelMetadata: Codable {
    var difficulty: Difficulty
    var theme: String
    var hintCost: Int?
    
    // Memberwise initializer
    init(difficulty: Difficulty, theme: String, hintCost: Int? = nil) {
        self.difficulty = difficulty
        self.theme = theme
        self.hintCost = hintCost
    }
    
    // Custom decoder to handle missing hintCost
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        theme = try container.decode(String.self, forKey: .theme)
        hintCost = try container.decodeIfPresent(Int.self, forKey: .hintCost)
    }
    
    enum CodingKeys: String, CodingKey {
        case difficulty, theme, hintCost
    }
}

// Represents a single level's data from Firestore.
struct Level: Codable, Identifiable {
    let id: Int
    let realm: String?
    let baseLetters: String
    let solutions: [String: [Int]]
    let bonusWords: [String]
    let metadata: LevelMetadata?

    // Memberwise initializer
    init(id: Int, realm: String? = nil, baseLetters: String, solutions: [String: [Int]], bonusWords: [String], metadata: LevelMetadata? = nil) {
        self.id = id
        self.realm = realm
        self.baseLetters = baseLetters
        self.solutions = solutions
        self.bonusWords = bonusWords
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case id, realm, baseLetters, solutions, bonusWords, metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        realm = try container.decodeIfPresent(String.self, forKey: .realm)
        baseLetters = try container.decode(String.self, forKey: .baseLetters)

        // Decode solutions directly as [String: [Int]]
        solutions = try container.decode([String: [Int]].self, forKey: .solutions)

        bonusWords = try container.decode([String].self, forKey: .bonusWords)
        metadata = try container.decodeIfPresent(LevelMetadata.self, forKey: .metadata)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(realm, forKey: .realm)
        try container.encode(baseLetters, forKey: .baseLetters)

        // Encode solutions directly as [String: [Int]]
        try container.encode(solutions, forKey: .solutions)

        try container.encode(bonusWords, forKey: .bonusWords)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

// Represents the player's persistent data in Firestore.
struct Player: Codable, Identifiable {
    var id: String?  // Remove @DocumentID - we handle this manually
    let uid: String  // Store uid as normal field
    var currentLevelID: Int
    var coins: Int
    var levelProgress: [String: Set<String>]
    var foundBonusWords: Set<String>
    var lastPlayedDate: Date?
    var lastDailyDate: String?
    var dailyStreak: Int
    var totalHintsUsed: Int
    // WORK ORDER: Added totalLevelsCompleted for analytics
    var totalLevelsCompleted: Int
    var preferredDifficulty: Difficulty
    var totalRevelationsUsed: Int
    var levelsPlayedSinceHint: Int
    var consecutiveFailedGuesses: Int
    var difficultyDrift: Int     // accumulated smoothing drift
    var lastLevelDuration: TimeInterval?  // seconds to complete last level
    var totalWordsFound: Int     // total words found across all levels
    var longestWordFound: Int    // length of longest word found
    var perfectLevels: Int        // number of levels completed perfectly

    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case currentLevelID
        case coins
        case levelProgress
        case foundBonusWords
        case lastPlayedDate
        case lastDailyDate
        case dailyStreak
        case totalHintsUsed
        case totalLevelsCompleted // WORK ORDER: Added coding key
        case preferredDifficulty
        case totalRevelationsUsed
        case levelsPlayedSinceHint
        case consecutiveFailedGuesses
        case difficultyDrift
        case lastLevelDuration
        case totalWordsFound
        case longestWordFound
        case perfectLevels
    }
    
    // Custom decoder to handle missing fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        uid = try container.decode(String.self, forKey: .uid)
        currentLevelID = try container.decode(Int.self, forKey: .currentLevelID)
        coins = try container.decode(Int.self, forKey: .coins)
        
        levelProgress = try container.decodeIfPresent([String: Set<String>].self, forKey: .levelProgress) ?? [:]
        foundBonusWords = try container.decodeIfPresent(Set<String>.self, forKey: .foundBonusWords) ?? []
        lastPlayedDate = try container.decodeIfPresent(Date.self, forKey: .lastPlayedDate)
        lastDailyDate = try container.decodeIfPresent(String.self, forKey: .lastDailyDate)
        dailyStreak = try container.decodeIfPresent(Int.self, forKey: .dailyStreak) ?? 0
        totalHintsUsed = try container.decodeIfPresent(Int.self, forKey: .totalHintsUsed) ?? 0
        totalLevelsCompleted = try container.decodeIfPresent(Int.self, forKey: .totalLevelsCompleted) ?? 0
        preferredDifficulty = try container.decodeIfPresent(Difficulty.self, forKey: .preferredDifficulty) ?? .easy
        totalRevelationsUsed = try container.decodeIfPresent(Int.self, forKey: .totalRevelationsUsed) ?? 0
        levelsPlayedSinceHint = try container.decodeIfPresent(Int.self, forKey: .levelsPlayedSinceHint) ?? 0
        consecutiveFailedGuesses = try container.decodeIfPresent(Int.self, forKey: .consecutiveFailedGuesses) ?? 0
        difficultyDrift = try container.decodeIfPresent(Int.self, forKey: .difficultyDrift) ?? 0
        lastLevelDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .lastLevelDuration)
        totalWordsFound = try container.decodeIfPresent(Int.self, forKey: .totalWordsFound) ?? 0
        longestWordFound = try container.decodeIfPresent(Int.self, forKey: .longestWordFound) ?? 0
        perfectLevels = try container.decodeIfPresent(Int.self, forKey: .perfectLevels) ?? 0
    }
    
    // Memberwise initializer.
    init(
        id: String? = nil,
        uid: String,
        currentLevelID: Int,
        coins: Int,
        levelProgress: [String: Set<String>],
        foundBonusWords: Set<String>,
        lastPlayedDate: Date? = nil,
        lastDailyDate: String? = nil,
        dailyStreak: Int = 0,
        totalHintsUsed: Int = 0,
        totalLevelsCompleted: Int = 0,
        preferredDifficulty: Difficulty = .easy,
        totalRevelationsUsed: Int = 0,
        levelsPlayedSinceHint: Int = 0,
        consecutiveFailedGuesses: Int = 0,
        difficultyDrift: Int = 0,
        lastLevelDuration: TimeInterval? = nil,
        totalWordsFound: Int = 0,
        longestWordFound: Int = 0,
        perfectLevels: Int = 0
    ) {
        self.id = id
        self.uid = uid
        self.currentLevelID = currentLevelID
        self.coins = coins
        self.levelProgress = levelProgress
        self.foundBonusWords = foundBonusWords
        self.lastPlayedDate = lastPlayedDate
        self.lastDailyDate = lastDailyDate
        self.dailyStreak = dailyStreak
        self.totalHintsUsed = totalHintsUsed
        self.totalLevelsCompleted = totalLevelsCompleted
        self.preferredDifficulty = preferredDifficulty
        self.totalRevelationsUsed = totalRevelationsUsed
        self.levelsPlayedSinceHint = levelsPlayedSinceHint
        self.consecutiveFailedGuesses = consecutiveFailedGuesses
        self.difficultyDrift = difficultyDrift
        self.lastLevelDuration = lastLevelDuration
        self.totalWordsFound = totalWordsFound
        self.longestWordFound = longestWordFound
        self.perfectLevels = perfectLevels
    }
}

// Transport struct for player analytics and state.
struct PlayerData: Codable {
    var id: String  // No default UUID - will be set from uid
    let completedLevelIDs: Set<Int>
    let usesHintsOften: Bool
    let isStruggling: Bool
    let preferredDifficulty: Difficulty
    var difficultyDrift: Int
    var coins: Int = 0
    var dailyStreak: Int = 0
    var lastDailyDate: String? = nil  // Per AI brief: date key strings yyyy-MM-dd
    var currentLevelID: Int = 1
    var levelProgress: [String: Set<String>] = [:]
    var foundBonusWords: Set<String> = []
    
    // Required for achievements and analytics
    var totalWordsFound: Int = 0
    var totalLevelsCompleted: Int = 0
    var longestWordFound: Int = 0
    var totalHintsUsed: Int = 0
    var perfectLevels: Int = 0
    
    // Additional fields for compatibility
    var lastPlayedDate: Date? = nil
    var totalRevelationsUsed: Int = 0
    var levelsPlayedSinceHint: Int = 0
    var consecutiveFailedGuesses: Int = 0
    var lastLevelDuration: TimeInterval? = nil
    
    // Custom init with default values for new fields
    init(
        id: String,
        completedLevelIDs: Set<Int>,
        usesHintsOften: Bool,
        isStruggling: Bool,
        preferredDifficulty: Difficulty,
        difficultyDrift: Int,
        coins: Int = 0,
        dailyStreak: Int = 0,
        lastDailyDate: String? = nil,
        currentLevelID: Int = 1,
        levelProgress: [String: Set<String>] = [:],
        foundBonusWords: Set<String> = [],
        totalWordsFound: Int = 0,
        totalLevelsCompleted: Int = 0,
        longestWordFound: Int = 0,
        totalHintsUsed: Int = 0,
        perfectLevels: Int = 0,
        lastPlayedDate: Date? = nil,
        totalRevelationsUsed: Int = 0,
        levelsPlayedSinceHint: Int = 0,
        consecutiveFailedGuesses: Int = 0,
        lastLevelDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.completedLevelIDs = completedLevelIDs
        self.usesHintsOften = usesHintsOften
        self.isStruggling = isStruggling
        self.preferredDifficulty = preferredDifficulty
        self.difficultyDrift = difficultyDrift
        self.coins = coins
        self.dailyStreak = dailyStreak
        self.lastDailyDate = lastDailyDate
        self.currentLevelID = currentLevelID
        self.levelProgress = levelProgress
        self.foundBonusWords = foundBonusWords
        self.totalWordsFound = totalWordsFound
        self.totalLevelsCompleted = totalLevelsCompleted
        self.longestWordFound = longestWordFound
        self.totalHintsUsed = totalHintsUsed
        self.perfectLevels = perfectLevels
        self.lastPlayedDate = lastPlayedDate
        self.totalRevelationsUsed = totalRevelationsUsed
        self.levelsPlayedSinceHint = levelsPlayedSinceHint
        self.consecutiveFailedGuesses = consecutiveFailedGuesses
        self.lastLevelDuration = lastLevelDuration
    }
}

// MARK: - Player/PlayerData Conversion Extensions
extension Player {
    /// Convert Player to PlayerData for transport/analytics
    func toPlayerData() -> PlayerData {
        let completedIDs = Set(levelProgress.keys.compactMap { Int($0) })
        let usesHintsOften = totalLevelsCompleted > 0 ? 
            (Double(totalHintsUsed) / Double(totalLevelsCompleted)) > 1.5 : false
        let isStruggling = consecutiveFailedGuesses > 5
        
        return PlayerData(
            id: uid,
            completedLevelIDs: completedIDs,
            usesHintsOften: usesHintsOften,
            isStruggling: isStruggling,
            preferredDifficulty: preferredDifficulty,
            difficultyDrift: difficultyDrift,
            coins: coins,
            dailyStreak: dailyStreak,
            lastDailyDate: lastDailyDate,
            currentLevelID: currentLevelID,
            levelProgress: levelProgress,
            foundBonusWords: foundBonusWords,
            totalWordsFound: totalWordsFound,
            totalLevelsCompleted: totalLevelsCompleted,
            longestWordFound: longestWordFound,
            totalHintsUsed: totalHintsUsed,
            perfectLevels: perfectLevels,
            lastPlayedDate: lastPlayedDate,
            totalRevelationsUsed: totalRevelationsUsed,
            levelsPlayedSinceHint: levelsPlayedSinceHint,
            consecutiveFailedGuesses: consecutiveFailedGuesses,
            lastLevelDuration: lastLevelDuration
        )
    }
}

extension PlayerData {
    /// Convert PlayerData back to Player
    func toPlayer() -> Player {
        return Player(
            id: nil,  // Never set id when converting back
            uid: id,  // Use PlayerData.id as uid
            currentLevelID: currentLevelID,
            coins: coins,
            levelProgress: levelProgress,
            foundBonusWords: foundBonusWords,
            lastPlayedDate: lastPlayedDate ?? Date(),
            lastDailyDate: lastDailyDate,
            dailyStreak: dailyStreak,
            totalHintsUsed: totalHintsUsed,
            totalLevelsCompleted: totalLevelsCompleted,
            preferredDifficulty: preferredDifficulty,
            totalRevelationsUsed: totalRevelationsUsed,
            levelsPlayedSinceHint: levelsPlayedSinceHint,
            consecutiveFailedGuesses: consecutiveFailedGuesses,
            difficultyDrift: difficultyDrift,
            lastLevelDuration: lastLevelDuration,
            totalWordsFound: totalWordsFound,
            longestWordFound: longestWordFound,
            perfectLevels: perfectLevels
        )
    }
}

// Enum for different outcomes of a word guess.
enum GuessResult {
    case success(word: String)
    case bonus(word: String)
    case invalid
    case alreadyFound
}

// MARK: - Achievement Models
struct Achievement: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let rarity: AchievementRarity
    var requirement: Int  // Made var to match GameViewModel usage
    var progress: Int = 0
    var isUnlocked: Bool = false
    
    init(title: String, description: String, icon: String, rarity: AchievementRarity, requirement: Int, progress: Int = 0, isUnlocked: Bool = false) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.icon = icon
        self.rarity = rarity
        self.requirement = requirement
        self.progress = progress
        self.isUnlocked = isUnlocked
    }
}

enum AchievementRarity: String, CaseIterable, Codable {
    case common, rare, epic, legendary
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .yellow
        }
    }
}

// Represents a single letter in the crossword grid.
struct GridLetter: Identifiable {
    let id = UUID()
    var char: Character?
    var isVisible: Bool = false
}

// Represents a single letter on the input wheel.
struct WheelLetter: Identifiable, Equatable {
    let id = UUID()
    let char: Character
    let originalIndex: Int   // index in baseLetters
    var position: CGPoint = .zero
    
    init(char: Character, originalIndex: Int, position: CGPoint = .zero) {
        self.char = char
        self.originalIndex = originalIndex
        self.position = position
    }
    
    static func == (lhs: WheelLetter, rhs: WheelLetter) -> Bool {
        lhs.id == rhs.id
    }
}

// Represents different layout formats for solution words
enum SolutionFormat: Codable {
    case wheel([Int])        // Array of indices referring to baseLetters positions (1-indexed)
    case grid([(Int, Int)])  // Array of (row, col) coordinates for grid-based layout
    
    enum CodingKeys: String, CodingKey {
        case type, indices, coordinates
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "wheel":
            let indices = try container.decode([Int].self, forKey: .indices)
            self = .wheel(indices)
        case "grid":
            let coords = try container.decode([[Int]].self, forKey: .coordinates)
            let tuples = coords.compactMap { array -> (Int, Int)? in
                guard array.count == 2 else { return nil }
                return (array[0], array[1])
            }
            self = .grid(tuples)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown SolutionFormat type: \(type)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .wheel(let indices):
            try container.encode("wheel", forKey: .type)
            try container.encode(indices, forKey: .indices)
        case .grid(let coords):
            try container.encode("grid", forKey: .type)
            let arrays = coords.map { [$0.0, $0.1] }
            try container.encode(arrays, forKey: .coordinates)
        }
    }
}
