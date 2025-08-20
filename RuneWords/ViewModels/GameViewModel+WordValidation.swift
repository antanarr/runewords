import Foundation
import SwiftUI
import UIKit

// MARK: - Word Validation and Submission Extension
extension GameViewModel {
    
    // MARK: - Guess Submission (FIXED to match described flow)
    func submitGuess() {
        // Debounce: ignore submissions during animation
        if animatingWordToSlot != nil || animatingWordToBonus != nil {
            print("⚠️ Ignoring guess submission during animation")
            return
        }
        
        // Step 1: Normalize - uppercase the guess
        let submittedGuess = currentGuess.uppercased()
        let submittedIndices = currentGuessIndices
        
        print("📝 Submitting guess: \(submittedGuess) with indices: \(submittedIndices)")
        
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
                print("  ✅ Valid solution with correct indices!")
                triggerPillToSlotAnimation(word: animationWord)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard var player = self.playerService.player else { return }
                    let levelIDString = String(level.id)
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
            // Check dictionary - pass raw string (DictionaryService normalizes internally)
            if dictionaryService.isValidWord(submittedGuess) {
                // Step 5: Check for duplicates
                if bonusWordsFound.contains(submittedGuess) {
                    handleDuplicateWord(submittedGuess)
                    return
                }
                
                // Valid bonus word!
                print("  ✅ Valid bonus word!")
                triggerPillToBonusAnimation(word: animationWord)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard var player = self.playerService.player else { return }
                    self.handleBonusWord(submittedGuess, player: &player)
                }
                return
            }
        }
        
        // Not a valid word
        handleInvalidWord(submittedGuess)
    }
    
    // MARK: - Helper: Can Make From Base Letters (multiset check)
    func canMakeWordFromBaseLetters(_ word: String) -> Bool {
        guard let baseLetters = currentLevel?.baseLetters else { return false }
        
        // Count letter frequencies in base
        var baseCount: [Character: Int] = [:]
        for char in baseLetters.uppercased() {
            baseCount[char, default: 0] += 1
        }
        
        // Count letter frequencies in word
        var wordCount: [Character: Int] = [:]
        for char in word.uppercased() {
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
        // Add to found words
        foundWords.insert(word)
        audioManager.playSound(effect: .success)
        HapticManager.shared.play(.success)
        
        // Update progress
        var progressForLevel = player.levelProgress[levelID, default: []]
        progressForLevel.insert(word)
        player.levelProgress[levelID] = progressForLevel
        
        // Award coins based on word length
        let wordReward = Config.Economy.wordReward(for: word.count)
        player.coins += wordReward
        
        // Bonus for long words
        if word.count >= 6 {
            player.coins += Config.Economy.longWordBonus
        }
        
        playerCoins = player.coins
        
        // Save progress
        playerService.player = player
        playerService.saveProgress(player: player.toPlayerData())
        
        // Visual effects
        Task {
            await revealWordInGridWithAnimation(word)
        }
        
        triggerCoinAnimation()
        lastFoundWord = word
        
        // Update combo
        updateCombo()
        
        // Trigger particles (would need actual UI position)
        let position = CGPoint(x: 200, y: 400)
        triggerWordCompletionParticles(at: position, for: word)
        triggerCoinBurstEffect(from: position, to: CGPoint(x: 100, y: 100), coinCount: wordReward)
        
        // Reset difficulty tracking
        consecutiveFailedGuesses = 0
        
        // Step 6: Single source of truth for completion - check if all targets found (and record in Firestore)
        // SINGLE SOURCE OF TRUTH: Only checkAndRecordLevelCompletionIfNeeded handles completion
        Task { await self.checkAndRecordLevelCompletionIfNeeded() }
        
        // Clear last found word after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.lastFoundWord = nil
        }
    }
    
    private func handleBonusWord(_ word: String, player: inout Player) {
        // Atomic insert to check if this is truly new
        let (inserted, _) = bonusWordsFound.insert(word)
        guard inserted else {
            // Already found before - should not happen due to duplicate check above
            print("⚠️ Bonus word already in set: \(word)")
            return
        }
        
        audioManager.playSound(effect: .bonus)
        HapticManager.shared.play(.light)
        
        // Update player - atomic insert again for persistence
        let (playerInserted, _) = player.foundBonusWords.insert(word)
        if playerInserted {
            // Only award coins if truly new to player's lifetime collection
            let bonusReward = Config.Economy.defaultBonusWordReward
            player.coins += bonusReward
            playerCoins = player.coins
            
            // Visual feedback for coin gain
            triggerCoinAnimation()
            
            // Show bonus message with reward amount
            appState.showOverlay(.hint("Bonus word! +\(bonusReward) coins"))
            
            // Particles with cleanup
            let position = CGPoint(x: 200, y: 400)
            triggerWordCompletionParticles(at: position, for: word)
            triggerCoinBurstEffect(from: position, to: CGPoint(x: 100, y: 100), coinCount: bonusReward)
        } else {
            print("ℹ️ Bonus word already in player's lifetime collection: \(word)")
        }
        
        // Save progress
        playerService.player = player
        playerService.saveProgress(player: player.toPlayerData())
        
        // Update combo
        updateCombo()
        
        // Check achievements
        checkAchievements(bonusWordFound: true)
        
        // Reset difficulty
        consecutiveFailedGuesses = 0
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
        // Per work order: Keep it simple - fixed reward or length-based
        return Config.Economy.defaultBonusWordReward
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
