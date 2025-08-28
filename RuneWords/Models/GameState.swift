//
//  GameState.swift
//  RuneWords
//
//  Unified game state model for single source of truth
//

import Foundation
import SwiftUI

// MARK: - Game State Model
struct GameState: Codable {
    // MARK: - Core Game Properties
    var currentLevel: Level?
    var currentLevelID: Int = 1
    var gamePhase: GamePhase = .idle
    var selectedLetters: [LetterSelection] = []
    var foundWords: Set<String> = []
    var currentWord: String = ""
    var score: Int = 0
    var coins: Int = 0
    var hints: Int = 3
    var revelations: Int = 1
    var shuffles: Int = 3
    
    // MARK: - Level Progress
    var levelStartTime: Date?
    var levelCompletionTime: TimeInterval?
    var wordsFoundInLevel: [String] = []
    var bonusWordsFound: Set<String> = []
    var starsEarned: Int = 0
    var perfectStreak: Int = 0
    
    // MARK: - UI State
    var showingPauseMenu: Bool = false
    var showingLevelComplete: Bool = false
    var showingHintAnimation: Bool = false
    var showingCelebration: Bool = false
    var errorMessage: String?
    var comboCount: Int = 0
    var lastWordTime: Date?
    
    // MARK: - Power-up States
    var activeHint: HintState?
    var revelationActive: Bool = false
    var doubleCoinsActive: Bool = false
    var infiniteHintsActive: Bool = false
    
    // MARK: - Statistics
    var totalWordsFound: Int = 0
    var longestWord: String = ""
    var fastestSolveTime: TimeInterval?
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    
    // MARK: - Enums
    enum GamePhase: String, Codable {
        case idle
        case loading
        case playing
        case paused
        case levelComplete
        case transitioning
        case celebration
    }
    
    struct LetterSelection: Codable, Equatable {
        let letter: String  // Changed from Character to conform to Codable
        let index: Int
        let position: CGPoint
    }
    
    struct HintState: Codable, Equatable {
        let word: String
        let revealedLetters: Int
        let cost: Int
    }
    
    // MARK: - Computed Properties
    var isLevelComplete: Bool {
        guard let level = currentLevel else { return false }
        return foundWords.count >= level.solutions.count
    }
    
    var completionPercentage: Float {
        guard let level = currentLevel else { return 0 }
        guard level.solutions.count > 0 else { return 0 }
        return Float(foundWords.count) / Float(level.solutions.count)
    }
    
    var timeElapsed: TimeInterval {
        guard let startTime = levelStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    var canUseHint: Bool {
        hints > 0 || infiniteHintsActive
    }
    
    var canUseRevelation: Bool {
        revelations > 0
    }
    
    var canShuffle: Bool {
        shuffles > 0
    }
    
    // MARK: - Methods
    mutating func startLevel(_ level: Level) {
        currentLevel = level
        currentLevelID = level.id
        gamePhase = .playing
        selectedLetters = []
        foundWords = []
        currentWord = ""
        wordsFoundInLevel = []
        bonusWordsFound = []
        levelStartTime = Date()
        levelCompletionTime = nil
        starsEarned = 0
        errorMessage = nil
        comboCount = 0
        lastWordTime = nil
        activeHint = nil
        revelationActive = false
    }
    
    mutating func selectLetter(_ letter: Character, at index: Int, position: CGPoint) {
        let selection = LetterSelection(letter: String(letter), index: index, position: position)
        selectedLetters.append(selection)
        currentWord = selectedLetters.map { $0.letter }.joined()
    }
    
    mutating func deselectLetter() {
        guard !selectedLetters.isEmpty else { return }
        selectedLetters.removeLast()
        currentWord = selectedLetters.map { $0.letter }.joined()
    }
    
    mutating func clearSelection() {
        selectedLetters = []
        currentWord = ""
    }
    
    mutating func submitWord() -> WordSubmissionResult {
        guard !currentWord.isEmpty else {
            return .failure("No word selected")
        }
        
        guard let level = currentLevel else {
            return .failure("No active level")
        }
        
        // Check if already found
        if foundWords.contains(currentWord) {
            clearSelection()
            return .failure("Already found")
        }
        
        // Check if valid solution
        if level.solutions.keys.contains(currentWord) {
            foundWords.insert(currentWord)
            wordsFoundInLevel.append(currentWord)
            totalWordsFound += 1
            
            // Update longest word
            if currentWord.count > longestWord.count {
                longestWord = currentWord
            }
            
            // Calculate score
            let wordScore = calculateWordScore(currentWord)
            score += wordScore
            
            // Award coins
            let coinsEarned = calculateCoinsForWord(currentWord)
            coins += doubleCoinsActive ? coinsEarned * 2 : coinsEarned
            
            // Update combo
            updateCombo()
            
            // Clear selection
            clearSelection()
            
            // Check level completion
            if isLevelComplete {
                completeLevel()
            }
            
            return .success(wordScore: wordScore, coinsEarned: coinsEarned)
        }
        
        // Check if bonus word
        if level.bonusWords.contains(currentWord) {
            bonusWordsFound.insert(currentWord)
            let bonusCoins = 5
            coins += doubleCoinsActive ? bonusCoins * 2 : bonusCoins
            clearSelection()
            return .bonus(coinsEarned: bonusCoins)
        }
        
        clearSelection()
        return .failure("Not a valid word")
    }
    
    mutating func useHint() -> Bool {
        guard canUseHint else { return false }
        
        if !infiniteHintsActive {
            hints -= 1
        }
        
        // Find an unfound word to hint
        guard let level = currentLevel else { return false }
        let unfoundWords = level.solutions.keys.filter { !foundWords.contains($0) }
        guard let wordToHint = unfoundWords.randomElement() else { return false }
        
        activeHint = HintState(word: wordToHint, revealedLetters: 1, cost: 25)
        showingHintAnimation = true
        
        return true
    }
    
    mutating func useRevelation() -> Bool {
        guard canUseRevelation else { return false }
        
        revelations -= 1
        revelationActive = true
        
        // Reveal a random unfound word
        guard let level = currentLevel else { return false }
        let unfoundWords = level.solutions.keys.filter { !foundWords.contains($0) }
        guard let wordToReveal = unfoundWords.randomElement() else { return false }
        
        foundWords.insert(wordToReveal)
        wordsFoundInLevel.append(wordToReveal)
        totalWordsFound += 1
        
        // Check level completion
        if isLevelComplete {
            completeLevel()
        }
        
        return true
    }
    
    mutating func shuffleLetters() -> Bool {
        guard canShuffle else { return false }
        
        shuffles -= 1
        clearSelection()
        
        // Shuffle animation would be triggered in the view
        return true
    }
    
    mutating func pauseGame() {
        if gamePhase == .playing {
            gamePhase = .paused
            showingPauseMenu = true
        }
    }
    
    mutating func resumeGame() {
        if gamePhase == .paused {
            gamePhase = .playing
            showingPauseMenu = false
        }
    }
    
    private mutating func completeLevel() {
        gamePhase = .levelComplete
        levelCompletionTime = timeElapsed
        
        // Calculate stars
        starsEarned = calculateStars()
        
        // Update fastest time
        if let time = levelCompletionTime {
            if fastestSolveTime == nil || time < fastestSolveTime! {
                fastestSolveTime = time
            }
        }
        
        // Trigger celebration
        showingCelebration = true
        showingLevelComplete = true
    }
    
    private mutating func updateCombo() {
        let now = Date()
        
        if let lastTime = lastWordTime {
            let timeSinceLastWord = now.timeIntervalSince(lastTime)
            
            if timeSinceLastWord < 5 { // Within 5 seconds
                comboCount += 1
                if comboCount > bestStreak {
                    bestStreak = comboCount
                }
            } else {
                comboCount = 1
            }
        } else {
            comboCount = 1
        }
        
        lastWordTime = now
        currentStreak = comboCount
    }
    
    private func calculateWordScore(_ word: String) -> Int {
        var score = word.count * 10
        
        // Bonus for longer words
        if word.count >= 6 { score += 50 }
        if word.count >= 7 { score += 100 }
        
        // Combo multiplier
        if comboCount > 1 {
            score = Int(Double(score) * (1.0 + Double(comboCount) * 0.1))
        }
        
        return score
    }
    
    private func calculateCoinsForWord(_ word: String) -> Int {
        var coins = word.count * 2
        
        // Bonus for longer words
        if word.count >= 5 { coins += 5 }
        if word.count >= 6 { coins += 10 }
        if word.count >= 7 { coins += 20 }
        
        return coins
    }
    
    private func calculateStars() -> Int {
        if completionPercentage >= 1.0 { return 3 }
        if completionPercentage >= 0.8 { return 2 }
        if completionPercentage >= 0.6 { return 1 }
        return 0
    }
    
    // MARK: - Result Types
    enum WordSubmissionResult {
        case success(wordScore: Int, coinsEarned: Int)
        case bonus(coinsEarned: Int)
        case failure(String)
    }
}

// MARK: - Equatable Conformance
extension GameState: Equatable {
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        // Compare all properties except currentLevel (which isn't Equatable)
        return lhs.currentLevelID == rhs.currentLevelID &&
               lhs.gamePhase == rhs.gamePhase &&
               lhs.selectedLetters == rhs.selectedLetters &&
               lhs.foundWords == rhs.foundWords &&
               lhs.currentWord == rhs.currentWord &&
               lhs.score == rhs.score &&
               lhs.coins == rhs.coins &&
               lhs.hints == rhs.hints &&
               lhs.revelations == rhs.revelations &&
               lhs.shuffles == rhs.shuffles &&
               lhs.levelStartTime == rhs.levelStartTime &&
               lhs.levelCompletionTime == rhs.levelCompletionTime &&
               lhs.wordsFoundInLevel == rhs.wordsFoundInLevel &&
               lhs.bonusWordsFound == rhs.bonusWordsFound &&
               lhs.starsEarned == rhs.starsEarned &&
               lhs.perfectStreak == rhs.perfectStreak &&
               lhs.showingPauseMenu == rhs.showingPauseMenu &&
               lhs.showingLevelComplete == rhs.showingLevelComplete &&
               lhs.showingHintAnimation == rhs.showingHintAnimation &&
               lhs.showingCelebration == rhs.showingCelebration &&
               lhs.errorMessage == rhs.errorMessage &&
               lhs.comboCount == rhs.comboCount &&
               lhs.lastWordTime == rhs.lastWordTime &&
               lhs.activeHint == rhs.activeHint &&
               lhs.revelationActive == rhs.revelationActive &&
               lhs.doubleCoinsActive == rhs.doubleCoinsActive &&
               lhs.infiniteHintsActive == rhs.infiniteHintsActive &&
               lhs.totalWordsFound == rhs.totalWordsFound &&
               lhs.longestWord == rhs.longestWord &&
               lhs.fastestSolveTime == rhs.fastestSolveTime &&
               lhs.currentStreak == rhs.currentStreak &&
               lhs.bestStreak == rhs.bestStreak &&
               lhs.currentLevel?.id == rhs.currentLevel?.id  // Compare level IDs instead of full Level
    }
}

// MARK: - Game State Manager
@MainActor
final class GameStateManager: ObservableObject {
    @Published var gameState: GameState = GameState()
    @Published var isLoading: Bool = false
    
    // Singleton
    static let shared = GameStateManager()
    private init() {}
    
    // MARK: - Public Methods
    func loadLevel(_ levelID: Int) async {
        isLoading = true
        
        await LevelService.shared.fetchLevel(id: levelID)
        
        if let level = LevelService.shared.currentLevel {
            gameState.startLevel(level)
        }
        
        isLoading = false
    }
    
    func selectLetter(_ letter: Character, at index: Int, position: CGPoint) {
        gameState.selectLetter(letter, at: index, position: position)
        HapticManager.shared.play(.light)
    }
    
    func deselectLetter() {
        gameState.deselectLetter()
        HapticManager.shared.play(.light)
    }
    
    func submitWord() {
        let result = gameState.submitWord()
        
        switch result {
        case .success(let wordScore, let coinsEarned):
            HapticManager.shared.play(.success)
            AudioManager.shared.play(.success)
            Log.game("Word found: \(gameState.currentWord) - Score: \(wordScore), Coins: \(coinsEarned)")
            
        case .bonus(let coinsEarned):
            HapticManager.shared.play(.medium)
            AudioManager.shared.play(.bonus)
            Log.game("Bonus word found: \(gameState.currentWord) - Coins: \(coinsEarned)")
            
        case .failure(let reason):
            HapticManager.shared.play(.error)
            AudioManager.shared.play(.fail)
            gameState.errorMessage = reason
            Log.game("Word submission failed: \(reason)")
        }
    }
    
    func useHint() {
        if gameState.useHint() {
            HapticManager.shared.play(.medium)
            Log.game("Hint used")
        }
    }
    
    func useRevelation() {
        if gameState.useRevelation() {
            HapticManager.shared.play(.success)
            Log.game("Revelation used")
        }
    }
    
    func shuffleLetters() {
        if gameState.shuffleLetters() {
            HapticManager.shared.play(.medium)
            AudioManager.shared.play(.shuffle)
            Log.game("Letters shuffled")
        }
    }
    
    func pauseGame() {
        gameState.pauseGame()
    }
    
    func resumeGame() {
        gameState.resumeGame()
    }
    
    func nextLevel() async {
        let nextID = gameState.currentLevelID + 1
        await loadLevel(nextID)
    }
    
    // MARK: - Persistence
    func saveState() {
        if let encoded = try? JSONEncoder().encode(gameState) {
            UserDefaults.standard.set(encoded, forKey: "gameState")
        }
    }
    
    func loadState() {
        if let data = UserDefaults.standard.data(forKey: "gameState"),
           let decoded = try? JSONDecoder().decode(GameState.self, from: data) {
            gameState = decoded
        }
    }
}
