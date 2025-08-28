import Foundation
import SwiftUI
import UIKit

// MARK: - Word Validation and Submission Extension
extension GameViewModel {
    
    // MARK: - Guess Submission (FIXED to match described flow)
    func submitGuess() {
        // Atomic guard: prevent double submissions
        guard !isGuessInFlight else {
            print("⚠️ Ignoring guess submission - already processing")
            return
        }
        
        // Debounce: ignore submissions during animation
        if animatingWordToSlot != nil || animatingWordToBonus != nil {
            print("⚠️ Ignoring guess submission during animation")
            return
        }
        
        isGuessInFlight = true
        defer { 
            DispatchQueue.main.async {
                self.isGuessInFlight = false
            }
        }
        
        // Step 1: Canonicalize the guess (uppercase, remove diacritics, trim)
        let submittedGuess = StringCanonicalizer.canon(currentGuess)
        let submittedIndices = currentGuessIndices
        
        // Telemetry
        print("🔍 TELEMETRY | Submit:")
        print("  - Raw: '\(currentGuess)'")
        print("  - Canon: '\(submittedGuess)'")
        print("  - LevelKey: '\(StringCanonicalizer.levelKey(currentLevel?.id ?? 0))'")
        print("  - Indices: \(submittedIndices)")
        
        // Keep current guess for animation
        let animationWord = submittedGuess
        
        // Clear current guess immediately
        currentGuess = ""
        currentGuessIndices = []
        
        // Step 2: Length gate - reject if <3 or >6
        guard submittedGuess.count >= 3 && submittedGuess.count <= 6 else {
            print("❌ Invalid length: \(submittedGuess.count)")
            if submittedGuess.count > 0 {
                handleInvalidWord(submittedGuess)
            }
            return
        }
        
        // Step 3: Target (solution) check
        if let level = currentLevel,
           let solutionIndices = level.solutions[submittedGuess] {
            
            // FIXED: Stored solution indices are 0-based into baseLetters; compare directly
            print("  - Checking solution indices (0-based)")
            print("    Expected: \(solutionIndices)")
            print("    Got: \(submittedIndices)")
            
            // Compare exact swipe order (REQUIRED for targets)
            if submittedIndices == solutionIndices {
                // Step 5: Check for duplicates
                if foundWords.contains(submittedGuess) {
                    handleDuplicateWord(submittedGuess)
                    return
                }
                
                // Valid solution found!
                print("  ✅ VALID_SOLUTION: \(submittedGuess) | audio=positive | persisted=pending")
                
                // Add to local optimistic set immediately
                foundWords.insert(submittedGuess)
                
                // Then trigger animations and persist
                triggerPillToSlotAnimation(word: animationWord)
                audioManager.playSound(effect: .success)
                HapticManager.shared.play(.success)
                
                // RW PATCH: Use handleAcceptedSolution for proper timing
                handleAcceptedSolution(submittedGuess)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard var player = self.playerService.player else { return }
                    let levelIDString = StringCanonicalizer.levelKey(level.id)
                    self.handleCorrectSolution(submittedGuess, player: &player, levelID: levelIDString)
                }
                return
            } else {
                print("  ❌ Indices don't match expected solution path")
                // Fall through to bonus check
            }
        }
        
        // Step 4: Bonus check (only if not a target)
        // First check if it can be made from base letters
        if canMakeWordFromBaseLetters(submittedGuess) {
            // Check dictionary with canonicalized string
            if dictionaryService.isValidWord(submittedGuess) {
                // Step 5: Check for duplicates (canonicalized comparison)
                let canonBonus = StringCanonicalizer.canon(submittedGuess)
                if bonusWordsFound.contains(canonBonus) {
                    handleDuplicateWord(canonBonus)
                    return
                }
                
                // Valid bonus word!
                print("  ✅ VALID_BONUS: \(submittedGuess) | audio=bonus | persisted=pending")
                
                // Add to local optimistic set immediately
                bonusWordsFound.insert(canonBonus)
                
                // Then trigger animations and persist
                triggerPillToBonusAnimation(word: animationWord)
                audioManager.playSound(effect: .bonus)
                HapticManager.shared.play(.light)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard var player = self.playerService.player else { return }
                    self.handleBonusWord(submittedGuess, player: &player)
                }
                return
            }
        }
        
        // Not a valid word
        print("  ❌ INVALID_GUESS: \(submittedGuess) | audio=negative | persisted=false")
        handleInvalidWord(submittedGuess)
    }
    
    // MARK: - Helper: Can Make From Base Letters (multiset check)
    func canMakeWordFromBaseLetters(_ word: String) -> Bool {
        guard let baseLetters = currentLevel?.baseLetters else { return false }
        
        // Count letter frequencies in base (canonicalized)
        var baseCount: [Character: Int] = [:]
        for char in StringCanonicalizer.canon(baseLetters) {
            baseCount[char, default: 0] += 1
        }
        
        // Count letter frequencies in word (canonicalized)
        var wordCount: [Character: Int] = [:]
        for char in StringCanonicalizer.canon(word) {
            wordCount[char, default: 0] += 1
        }
        
        // Check if word can be formed (multiset containment)
        for (char, count) in wordCount {
            if baseCount[char, default: 0] < count {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Submission Handlers
    private func handleCorrectSolution(_ word: String, player: inout Player, levelID: String) {
        let canonWord = StringCanonicalizer.canon(word)
        let levelKey = StringCanonicalizer.levelKey(Int(levelID) ?? 0)
        
        // Don't add to found words here - already added optimistically
        // Don't play audio here - already played in submitGuess
        
        // Update progress locally
        var progressForLevel = player.levelProgress[levelKey, default: []]
        progressForLevel.insert(canonWord)
        player.levelProgress[levelKey] = progressForLevel
        
        // Calculate rewards
        let wordReward = Config.Economy.wordReward(for: word.count)
        var totalReward = wordReward
        
        // Bonus for long words
        if word.count >= 6 {
            totalReward += Config.Economy.longWordBonus
        }
        
        // Update player locally
        player.coins += totalReward
        playerCoins = player.coins
        playerService.player = player
        
        // Use batch update for Firestore to prevent half-applied states
        Task {
            await MainActor.run {
                self.playerService.applyWordFind(levelId: levelKey, word: canonWord, reward: totalReward)
            }
        }
        
        // Visual effects
        Task {
            await revealWordInGridWithAnimation(canonWord)
        }
        
        triggerCoinAnimation()
        lastFoundWord = canonWord
        
        // Update combo
        updateCombo()
        
        // Trigger particles
        let position = CGPoint(x: 200, y: 400)
        triggerWordCompletionParticles(at: position, for: canonWord)
        triggerCoinBurstEffect(from: position, to: CGPoint(x: 100, y: 100), coinCount: totalReward)
        
        // Reset difficulty tracking
        consecutiveFailedGuesses = 0
        
        // RW PATCH: Removed duplicate completion check - handleAcceptedSolution handles it
        // Task { await self.checkAndRecordLevelCompletionIfNeeded() }
        
        // Clear last found word after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.lastFoundWord = nil
        }
    }
    
    private func handleBonusWord(_ word: String, player: inout Player) {
        let canonWord = StringCanonicalizer.canon(word)
        
        // Don't add to bonus words here - already added optimistically
        // Don't play audio here - already played in submitGuess
        
        // Calculate reward
        let bonusReward = calculateBonusWordReward(word: word)
        
        // Update player model locally
        player.foundBonusWords.insert(canonWord)
        player.coins += bonusReward
        playerCoins = player.coins
        
        // Update local state
        playerService.player = player
        
        // Use batch update for Firestore to prevent half-applied states
        Task {
            await MainActor.run {
                self.playerService.applyBonusWord(canonWord, reward: bonusReward)
            }
        }
        
        // Visual feedback
        triggerCoinAnimation()
        updateCombo()
        
        // Particles with cleanup
        let position = CGPoint(x: 200, y: 400)
        triggerWordCompletionParticles(at: position, for: word)
        triggerCoinBurstEffect(from: position, to: CGPoint(x: 100, y: 100), coinCount: bonusReward)
        
        // Check achievements
        checkAchievements(bonusWordFound: true)
        
        // Reset difficulty
        consecutiveFailedGuesses = 0
        
        // Show bonus message with reward amount
        appState.showOverlay(.hint("Bonus word! +\(bonusReward) coins"))
    }
    
    private func handleInvalidWord(_ word: String) {
        audioManager.playSound(effect: .fail)
        triggerShakeAnimation(for: word)
        HapticManager.shared.play(.error)
        consecutiveFailedGuesses += 1
        checkAdaptiveDifficulty()
        
        // More specific error messages - pass raw string (DictionaryService normalizes internally)
        if !dictionaryService.isValidWord(word) {
            appState.showOverlay(.error("Not a valid word"))
        } else if currentLevel?.solutions[word] != nil {
            appState.showOverlay(.error("Wrong swipe pattern"))
        } else {
            appState.showOverlay(.error("Not in this puzzle"))
        }
        
        // Visual effect
        triggerIncorrectGuessEffects(for: word, at: CGPoint(x: 200, y: 400))
    }
    
    private func handleDuplicateWord(_ word: String) {
        audioManager.playSound(effect: .fail)
        triggerShakeAnimation(for: word)
        consecutiveFailedGuesses += 1
        checkAdaptiveDifficulty()
        appState.showOverlay(.error("Already found!"))
        
        // Visual effect
        triggerIncorrectGuessEffects(for: word, at: CGPoint(x: 200, y: 400))
    }
    
    // MARK: - Word Reward Calculation
    private func calculateBonusWordReward(word: String) -> Int {
        // Scale bonus word rewards by length
        let baseBonusReward = bonusWordReward
        let lengthMultiplier = max(1, word.count - 2) // 3-letter = 1x, 4-letter = 2x, etc.
        return baseBonusReward * lengthMultiplier * comboMultiplier
    }
    
    // MARK: - Level Completion Check
    // Completion is handled via checkAndRecordLevelCompletionIfNeeded() in this file.
    
    // MARK: - Firestore Completion Recording (SINGLE SOURCE OF TRUTH)
    func checkAndRecordLevelCompletionIfNeeded() async {
        guard let level = currentLevel,
              let uid = AuthService.shared.uid else { return }
        
        // Check if all solutions found
        let allSolutionsFound = Set(level.solutions.keys).isSubset(of: foundWords)
        
        if allSolutionsFound {
            // Calculate actual solve time
            let solveTime: TimeInterval = levelStartTime?.timeIntervalSinceNow.magnitude ?? 60.0
            
            // Record stats for Firestore
            let stats: [String: Any] = [
                "foundWords": Array(foundWords),
                "bonusWords": Array(bonusWordsFound),
                "totalFoundWords": foundWords.count,
                "totalBonusWords": bonusWordsFound.count,
                "hintsUsed": hintsUsedCount,
                "completed": true
            ]
            
            // Record in Firestore: players/{uid}/progress/{levelId}
            await ProgressService.shared.markLevelComplete(
                uid: uid,
                levelId: level.id,
                stats: stats
            )
            
            print("✅ Level \(level.id) completion recorded in Firestore")
            
            // Report to Game Center
            await MainActor.run {
                GameCenterService.shared.reportLevelComplete(
                    levelNumber: level.id,
                    solveTime: solveTime,
                    wordsFound: self.foundWords.count,
                    bonusWordsFound: self.bonusWordsFound.count,
                    hintsUsed: self.hintsUsedCount
                )
                
                // Report total progress for achievements
                if let player = self.playerService.player {
                    let totalWords = player.totalWordsFound + self.foundWords.count
                    let totalBonusWords = player.foundBonusWords.count + self.bonusWordsFound.count
                    let realmsCompleted = player.totalLevelsCompleted + 1
                    
                    GameCenterService.shared.reportTotalProgress(
                        totalWords: totalWords,
                        totalBonusWords: totalBonusWords,
                        realmsCompleted: realmsCompleted,
                        totalRealms: 100 // Adjust based on actual realm count
                    )
                }
            }
            
            // Trigger UI level complete state
            await MainActor.run {
                self.isLevelComplete = true
                
                // Award completion bonus coins
                guard var player = self.playerService.player else { return }
                let completionBonus = Config.Economy.levelCompletionBonus
                player.coins += completionBonus
                self.playerCoins = player.coins
                self.playerService.player = player
                self.playerService.saveProgress(player: player.toPlayerData())
                
                // Play completion effects
                self.audioManager.playSound(effect: .levelComplete)
                HapticManager.shared.play(.success)
                
                print("🎉 Level \(level.id) completed! Bonus: +\(completionBonus) coins")
            }
        }
    }
    
    // MARK: - Accessibility Support (WO-007)
    
    /// Select a letter at the given index for VoiceOver users
    /// This allows building words through individual letter taps
    func selectLetter(at index: Int) {
        guard letterWheel.indices.contains(index) else { return }
        
        let letter = letterWheel[index]
        
        // Toggle selection
        if let existingIndex = currentGuessIndices.firstIndex(of: index) {
            // Deselect letter
            currentGuessIndices.remove(at: existingIndex)
        } else {
            // Select letter
            currentGuessIndices.append(index)
        }
        
        // Update current guess string
        currentGuess = currentGuessIndices.compactMap { idx in
            letterWheel.indices.contains(idx) ? String(letterWheel[idx].char) : nil
        }.joined()
        
        // Provide haptic feedback
        HapticManager.shared.play(.light)
        
        // Announce current word for VoiceOver
        if UIAccessibility.isVoiceOverRunning {
            let announcement = currentGuess.isEmpty ? "Word cleared" : "Current word: \(currentGuess)"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
        
        print("🔤 VoiceOver letter selection: \(letter.char), current word: \(currentGuess)")
    }
}
