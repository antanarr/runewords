import Foundation
import SwiftUI

// MARK: - Seeded Random Number Generator
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // Linear congruential generator
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Level Management Extension
extension GameViewModel {
    
    // MARK: - Data Hygiene (Computed Properties)
    // PART B: Clear, non-conflicting names
    // Note: targetWords is defined in GameViewModel+Core.swift
    
    // 'bonusNonTargets' to avoid shadowing the model's 'bonusWords'
    var bonusNonTargets: [String] {
        // Already uppercased thanks to normalization
        guard let level = currentLevel else { return [] }
        let targets = Set(level.solutions.keys)
        return Array(Set(level.bonusWords).subtracting(targets)).sorted()
    }
    
    // MARK: - Level Setup
    func setupLevel(level: Level) {
        // Ignore same-level re-setup to prevent whiplash
        if currentLevel?.id == level.id {
            print("🎮 Ignoring same-level setup for level \(level.id)")
            return
        }
        
        print("🎮 LEVEL_START: Setting up level \(level.id)")
        print("  - Base letters: \(level.baseLetters) (\(level.baseLetters.count) letters)")
        print("  - Solutions: \(level.solutions)")
        
        // Validate level has correct letter count
        guard level.baseLetters.count == Config.Gameplay.requiredLetterCount else {
            print("❌ ERROR: Level \(level.id) has \(level.baseLetters.count) letters, expected \(Config.Gameplay.requiredLetterCount)")
            appState.showError(AppState.AppError(
                title: "Invalid Level",
                message: "This level has an incorrect number of letters.",
                isRecoverable: true
            ))
            return
        }
        
        // Reset level state and start timer
        resetLevelState()
        levelStartTime = Date()
        
        // Set current level
        self.currentLevel = level
        self.realmName = backgroundImageName(for: level.metadata?.difficulty)
        
        // WO-006: Log level start
        let realm = LevelService.shared.realm(of: level.id) ?? "unknown"
        let difficulty = level.metadata?.difficulty.rawValue ?? "unknown"
        AnalyticsManager.shared.logLevelStart(id: level.id, realm: realm, difficulty: difficulty)
        
        // Initialize wheel letters with seeded scrambling
        var tempLetters = level.baseLetters
            .enumerated()
            .map { WheelLetter(char: $0.element, originalIndex: $0.offset) }
        
        // Seeded scramble based on levelID
        var generator = SeededRandomNumberGenerator(seed: UInt64(level.id))
        tempLetters.shuffle(using: &generator)
        
        // Check if clockwise path spells the base word
        let clockwiseString = tempLetters.map { String($0.char) }.joined()
        if clockwiseString == level.baseLetters {
            // Swap two non-adjacent indices to avoid spelling the word
            if tempLetters.count >= 4 {
                tempLetters.swapAt(0, 2) // Swap first and third
            }
        }
        
        // Store the final scrambled order
        self.letterWheel = tempLetters
        
        // Note: Positions will be calculated by GameLetterWheelView on first render
        
        print("  - Wheel letters: \(letterWheel.map { "\($0.char)@\($0.position)" })")
        print("  - Letter count: \(letterWheel.count)")
        print("  - Solution words: \(Array(level.solutions.keys))")
        
        // Parse and build grid
        self.solutionFormats = parseSolutionFormats(for: level)
        buildGrid(for: level)
        
        // Restore previous progress
        restoreLevelProgress(for: level)
        
        // Check completion status
        checkForLevelCompletion()
    }
    
    private func resetLevelState() {
        isLevelComplete = false
        levelCompleted = false
        showLevelCompleteCelebration = false
        currentGuess = ""
        currentGuessIndices = []
        revealedLettersInSolutions = [:]
        consecutiveFailedGuesses = 0
        levelsPlayedSinceHint += 1
        hintsUsedCount = 0  // Reset hints count for new level
        // RW PATCH: Reset bonus words state
        bonusWordsFound.removeAll()
        bonusCount = 0
        showBonusSheet = false
    }
    
    private func buildGrid(for level: Level) {
        var maxRow = 0, maxCol = 0
        
        // Calculate grid dimensions
        for format in solutionFormats.values {
            if case let .grid(coords) = format {
                for (row, col) in coords {
                    maxRow = max(maxRow, row)
                    maxCol = max(maxCol, col)
                }
            }
        }
        
        // Initialize empty grid
        self.grid = Array(
            repeating: Array(repeating: GridLetter(char: nil), count: maxCol + 1),
            count: maxRow + 1
        )
        
        // Populate grid cells
        for (word, format) in solutionFormats {
            if case let .grid(coords) = format {
                let letters = Array(word)
                for (index, (row, col)) in coords.enumerated() where index < letters.count {
                    if row < grid.count, col < grid[row].count {
                        self.grid[row][col].char = letters[index]
                    }
                }
            }
        }
        
        // Fallback to wheel layout if needed
        let hasGridFormat = solutionFormats.values.contains { format in
            if case .grid = format { return true } else { return false }
        }
        if !hasGridFormat {
            self.grid = buildGridFromWheelPaths(level: level)
        }
    }
    
    private func restoreLevelProgress(for level: Level) {
        if let player = playerService.player,
           let progress = player.levelProgress[StringCanonicalizer.levelKey(level.id)] {
            // Canonicalize all restored words
            let canonProgress = Set(progress.map { StringCanonicalizer.canon($0) })
            self.foundWords = canonProgress
            
            // Reveal each word in the grid
            for word in canonProgress {
                revealWordInGrid(word)
            }
        } else {
            self.foundWords = []
        }
    }
    
    // MARK: - Level Completion
    // REMOVED: checkForLevelCompletion() - moved to single source of truth in GameViewModel+WordValidation.swift
    // All completion logic is now handled by checkAndRecordLevelCompletionIfNeeded() in WordValidation
    
    func checkForLevelCompletion() {
        // This function is kept for compatibility but does nothing
        // Real completion is handled in GameViewModel+WordValidation.swift -> checkAndRecordLevelCompletionIfNeeded()
        // DO NOT add completion logic here - it will cause duplicates
    }
    
    func advanceToNextLevel() {
        guard var player = playerService.player else { return }
        levelsPlayedSinceHint += 1
        
        Task {
            // Ensure levels are loaded
            if levelService.totalLevelCount == 0 {
                await levelService.loadCatalogIfNeeded()
            }
            
            // Get next level ID using progression order (gap-safe)
            var nextLevelID: Int?
            
            // Check if we have saved progress in Firestore
            if let uid = AuthService.shared.uid,
               let lastLevelId = await ProgressService.shared.fetchLastLevelId(uid: uid) {
                // Use progression order to find next level (gap-safe)
                nextLevelID = levelService.nextProgressionLevelId(after: lastLevelId)
                
                // If no next level in progression, restart from beginning
                if nextLevelID == nil {
                    nextLevelID = levelService.orderedProgressionIDs.first
                }
            } else {
                // No saved progress, start with first level in progression
                // This will prefer easy + hasIso6 levels first
                nextLevelID = levelService.orderedProgressionIDs.first
            }
            
            // Load the next level
            if let nextID = nextLevelID {
                player.currentLevelID = nextID
                await levelService.fetchLevel(id: nextID)
                playerService.player = player
                playerService.saveProgress(player: player.toPlayerData())
            }
            
            await MainActor.run {
                self.triggerLevelTransition(from: player.currentLevelID, to: player.currentLevelID)
                self.isLevelComplete = false
                self.resetCombo()
                self.appState.updateGamePhase(.playing)
            }
        }
    }
    
    // MARK: - Level Reset (PART F)
    func resetLevel() {
        // Clear all state as required
        foundWords.removeAll()
        bonusWordsFound.removeAll()
        currentGuess = ""
        currentGuessIndices.removeAll()
        revealedLettersInSolutions.removeAll()
        incorrectGuessEffects.removeAll()
        showErrorOverlay = false
        errorMessage = ""
        consecutiveFailedGuesses = 0
        hintsUsedCount = 0  // Reset hints count on level reset
        
        // RW PATCH: Reset ephemeral state
        bonusCount = 0
        showBonusSheet = false
        lastSubmittedWord = nil
        
        // Clear animation states
        animatingWordToSlot = nil
        animatingWordToBonus = nil
        
        if let level = currentLevel {
            setupLevel(level: level)
            
            // Clear saved progress
            if var player = playerService.player {
                player.levelProgress.removeValue(forKey: String(level.id))
                playerService.player = player
                playerService.saveProgress(player: player.toPlayerData())
            }
        }
        
        audioManager.playSound(effect: .shuffle)
    }
    
    // MARK: - Background Selection
    func backgroundImageName(for difficulty: Difficulty?) -> String {
        let levelId = currentLevel?.id ?? 0
        let theme = currentLevel?.metadata?.theme
        
        // Special case for first level
        if levelId == 1 {
            return "realm_treelibrary"
        }
        
        // Theme-based selection
        if let theme = theme {
            switch theme {
            case "treelibrary":   return "realm_treelibrary"
            case "crystalforest": return "realm_crystalforest"
            case "sleepingtitan": return "realm_sleepingtitan"
            case "astralpeak":    return "realm_astralpeak"
            default:              return difficultyBasedBackground(difficulty)
            }
        }
        
        return difficultyBasedBackground(difficulty)
    }
    
    private func difficultyBasedBackground(_ difficulty: Difficulty?) -> String {
        switch difficulty {
        case .easy:   return "realm_treelibrary"
        case .medium: return "realm_crystalforest"
        case .hard:   return "realm_sleepingtitan"
        case .expert: return "realm_astralpeak"
        case .none:   return "realm_treelibrary"
        }
    }
    
    // MARK: - Daily Challenge
    private func checkAndCompleteDailyChallenge() {
        guard let currentLevel = currentLevel else { return }
        
        let availableLevelIDs = Array(1...max(100, currentLevel.id + 50))
        
        guard let todaysChallenge = DailyChallengeService.shared.challengeForToday(availableLevelIDs: availableLevelIDs),
              todaysChallenge.levelID == currentLevel.id else {
            return
        }
        
        if let payout = DailyChallengeService.shared.completeTodayIfNeeded(availableLevelIDs: availableLevelIDs) {
            playerCoins = playerService.player?.coins ?? playerCoins
            
            // Calculate actual solve time
            let solveTime: TimeInterval = levelStartTime?.timeIntervalSinceNow.magnitude ?? 60.0
            
            // Report to Game Center
            GameCenterService.shared.reportDailyChallengeComplete(
                solveTime: solveTime,
                streak: payout.streak
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🎉 Daily Challenge Completed! Streak: \(payout.streak), Coins: \(payout.coinsAwarded)")
                
                if payout.isMilestone {
                    print("🏆 Milestone reached! Extra bonus coins awarded!")
                }
                
                self.triggerCoinAnimation()
            }
        }
    }
    
    // MARK: - Level Progression
    // Progression chooser: prefers EASY first (then MEDIUM, HARD), gap-safe.
    func nextLevelId() async -> Int? {
        if let uid = AuthService.shared.uid {
            let last = await ProgressService.shared.fetchLastLevelId(uid: uid)
            if let next = levelService.nextProgressionLevelId(after: last) {
                return next
            }
        }
        return levelService.orderedProgressionIDs.first
    }
}
