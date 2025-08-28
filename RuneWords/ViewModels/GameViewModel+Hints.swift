import Foundation
import SwiftUI

// MARK: - Hints and Runes Extension
extension GameViewModel {
    
    // MARK: - Display Names and Icons
    var clarityDisplayName: String { "Rune of Clarity" }
    var precisionDisplayName: String { "Rune of Precision" }
    var momentumDisplayName: String { "Rune of Momentum" }
    var clarityIconName: String { "lightbulb.max.fill" }
    var precisionIconName: String { "target" }
    var momentumIconName: String { "bolt.circle.fill" }
    
    // MARK: - Shuffle
    func shuffleLetters() {
        audioManager.playSound(effect: .shuffle)
        letterWheel.shuffle()
        
        // Recalculate positions after shuffle
        let angleStep = (2 * .pi) / CGFloat(6)
        let center = CGPoint(x: 140, y: 140)  // Default for 280 size
        let radius: CGFloat = 98  // 140 * 0.7
        
        for i in 0..<min(letterWheel.count, 6) {
            let angle = angleStep * CGFloat(i) - (.pi / 2)
            letterWheel[i].position = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }
        
        HapticManager.shared.play(.light)
    }
    
    // MARK: - Clarity (Basic Hint)
    func useHint() {
        audioManager.playSound(effect: .selectLetter)
        guard var player = playerService.player else { return }
        
        // Check affordability
        if player.coins < hintCost {
            let adEnabled = remoteConfig.configValue(forKey: Config.RemoteConfig.adForHintEnabled).boolValue
            if adEnabled {
                watchAdForCoins()
                return
            } else {
                triggerShakeAnimation()
                appState.showOverlay(.error("Not enough coins"))
                return
            }
        }
        
        // LOCAL-FIRST: Reveal a random letter immediately
        guard revealRandomLetterInSolution() else {
            triggerShakeAnimation()
            appState.showOverlay(.hint("No more hints available"))
            return
        }
        
        // LOCAL-FIRST: Update local state immediately
        player.coins -= hintCost
        player.totalHintsUsed += 1
        hintsUsedCount += 1  // Track for current level
        playerService.player = player  // Update local state first
        playerCoins = player.coins
        
        // Feedback immediately
        audioManager.playSound(effect: .success)
        HapticManager.shared.play(.success)
        resetDifficultyTracking()
        
        // WO-006: Log hint usage
        AnalyticsManager.shared.logHintUsed(type: "clarity", cost: hintCost)
        
        // RESILIENT: Save to Firestore asynchronously without blocking UI
        Task { @MainActor in
            // Try to save progress, but don't fail the hint action if it fails
            playerService.saveProgress(player: player.toPlayerData())
            
            // Also track hint usage asynchronously
            if let uid = AuthService.shared.uid {
                await ProgressService.shared.incrementHintsUsed(uid: uid)
            }
        }
    }
    
    // MARK: - Precision (Targeted Hint)
    func usePrecision() {
        guard var player = playerService.player else { return }
        
        // Check affordability
        guard player.coins >= precisionCost else {
            triggerShakeAnimation()
            appState.showOverlay(.error("Not enough coins"))
            return
        }
        
        guard let level = currentLevel else { return }
        
        // Find shortest unfound word
        let unfoundWords = level.solutions.keys.filter { !foundWords.contains($0) }
        guard let shortestWord = unfoundWords.min(by: { $0.count < $1.count }) else {
            triggerShakeAnimation()
            appState.showOverlay(.hint("All words found!"))
            return
        }
        
        // Find first unrevealed letter
        let currentlyRevealed = revealedLettersInSolutions[shortestWord, default: []]
        guard let firstUnrevealedIndex = (0..<shortestWord.count)
            .first(where: { !currentlyRevealed.contains($0) }) else {
            triggerShakeAnimation()
            appState.showOverlay(.hint("Word already revealed"))
            return
        }
        
        // LOCAL-FIRST: Reveal the letter immediately
        revealedLettersInSolutions[shortestWord, default: []].insert(firstUnrevealedIndex)
        
        // LOCAL-FIRST: Update player state immediately
        player.coins -= precisionCost
        player.totalHintsUsed += 1
        hintsUsedCount += 1  // Track for current level
        playerService.player = player  // Update local state first
        playerCoins = player.coins
        
        // Feedback immediately
        audioManager.playSound(effect: .success)
        HapticManager.shared.play(.success)
        resetDifficultyTracking()
        
        // Show which word was targeted
        appState.showOverlay(.hint("Revealed letter in \(shortestWord.count)-letter word"))
        
        // WO-006: Log hint usage
        AnalyticsManager.shared.logHintUsed(type: "precision", cost: precisionCost)
        
        // RESILIENT: Save to Firestore asynchronously
        Task { @MainActor in
            playerService.saveProgress(player: player.toPlayerData())
        }
    }
    
    // MARK: - Momentum (Multiple Hints)
    func useMomentum(reveals: Int = 3) {
        audioManager.playSound(effect: .selectLetter)
        guard var player = playerService.player else { return }
        
        // Check affordability
        if player.coins < momentumCost {
            triggerShakeAnimation()
            appState.showOverlay(.error("Not enough coins"))
            return
        }
        
        // LOCAL-FIRST: Reveal multiple letters immediately
        var revealedCount = 0
        for _ in 0..<reveals {
            if revealRandomLetterInSolution() {
                revealedCount += 1
            }
        }
        
        // Only charge if something was revealed
        if revealedCount > 0 {
            // LOCAL-FIRST: Update state immediately
            player.coins -= momentumCost
            player.totalHintsUsed += 1
            hintsUsedCount += 1  // Track for current level
            playerService.player = player  // Update local state first
            playerCoins = player.coins
            
            // Feedback immediately
            audioManager.playSound(effect: .success)
            HapticManager.shared.play(.success)
            appState.showOverlay(.hint("Revealed \(revealedCount) letters"))
            
            // WO-006: Log hint usage
            AnalyticsManager.shared.logHintUsed(type: "momentum", cost: momentumCost)
            
            // RESILIENT: Save to Firestore asynchronously
            Task { @MainActor in
                playerService.saveProgress(player: player.toPlayerData())
            }
        } else {
            triggerShakeAnimation()
            appState.showOverlay(.hint("No more hints available"))
        }
        
        resetDifficultyTracking()
    }
    
    // MARK: - Revelation (Full Word)
    func useRevelation() {
        audioManager.playSound(effect: .selectLetter)
        guard var player = playerService.player else { return }
        
        // Check affordability
        if player.coins < revelationCost {
            let adEnabled = remoteConfig.configValue(forKey: Config.RemoteConfig.adForRevelationEnabled).boolValue
            if adEnabled {
                watchAdForCoins()
                return
            } else {
                triggerShakeAnimation()
                appState.showOverlay(.error("Not enough coins"))
                return
            }
        }
        
        // Find an unfound word to reveal
        guard let unfoundWords = currentLevel?.solutions.keys.filter({ !foundWords.contains($0) }),
              let wordToReveal = unfoundWords.randomElement() else {
            appState.showOverlay(.hint("All words found!"))
            return
        }
        
        // LOCAL-FIRST: Update all state immediately
        player.coins -= revelationCost
        player.totalHintsUsed += 1
        hintsUsedCount += 1  // Track for current level
        
        foundWords.insert(wordToReveal)
        guard let levelID = currentLevel?.id else { return }
        if var progressForLevel = player.levelProgress[String(levelID)] {
            progressForLevel.insert(wordToReveal)
            player.levelProgress[String(levelID)] = progressForLevel
        } else {
            player.levelProgress[String(levelID)] = [wordToReveal]
        }
        
        // Update local state immediately
        playerService.player = player
        playerCoins = player.coins
        
        // Show which word was revealed immediately
        appState.showOverlay(.hint("Revealed: \(wordToReveal)"))
        
        // Animate the reveal
        Task {
            await revealWordInGridWithAnimation(wordToReveal, isRevelation: true)
        }
        
        // Check completion
        checkForLevelCompletion()
        resetDifficultyTracking()
        
        // WO-006: Log hint usage
        AnalyticsManager.shared.logHintUsed(type: "revelation", cost: revelationCost)
        
        // RESILIENT: Save to Firestore asynchronously
        Task { @MainActor in
            playerService.saveProgress(player: player.toPlayerData())
        }
    }
    
    // MARK: - Helper Methods
    private func revealRandomLetterInSolution() -> Bool {
        guard let level = currentLevel else { return false }
        
        // Find all unrevealed letter positions
        var candidates: [(word: String, position: Int)] = []
        
        for (word, _) in level.solutions where !foundWords.contains(word) {
            let revealedPositions = revealedLettersInSolutions[word, default: []]
            for position in 0..<word.count {
                if !revealedPositions.contains(position) {
                    candidates.append((word: word, position: position))
                }
            }
        }
        
        guard !candidates.isEmpty else { return false }
        
        // Pick random candidate and reveal
        let chosen = candidates.randomElement()!
        revealedLettersInSolutions[chosen.word, default: []].insert(chosen.position)
        
        // Trigger visual effect
        animateHintReveal(for: chosen.word, at: chosen.position)
        
        return true
    }
    
    private func animateHintReveal(for word: String, at position: Int) {
        // Find the tile in the grid or wheel to animate
        if let format = solutionFormats[word] {
            switch format {
            case .grid(let coords) where position < coords.count:
                let (row, col) = coords[position]
                if row < grid.count, col < grid[row].count {
                    let tileID = grid[row][col].id
                    hintedTileIDs.insert(tileID)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.hintGlowDuration) {
                        self.hintedTileIDs.remove(tileID)
                    }
                }
                
            case .wheel(let indices) where position < indices.count:
                let originalIndex = indices[position]
                if let letter = letterWheel.first(where: { $0.originalIndex == originalIndex }) {
                    hintedTileIDs.insert(letter.id)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.hintGlowDuration) {
                        self.hintedTileIDs.remove(letter.id)
                    }
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Ad Integration for Hints
    func watchAdForCoins() {
        appState.updateAdState(.loading)
        
        adManager.showRewardedAd { [weak self] success in
            guard let self = self else { return }
            
            if success {
                self.grantAdReward()
                self.appState.updateAdState(.rewarded)
            } else {
                // WO-006: Log failed ad reward
                AnalyticsManager.shared.logAdReward(collected: false, placement: "hint_offer")
                self.appState.updateAdState(.failed("Ad failed to load"))
            }
        }
    }
    
    private func grantAdReward() {
        guard var player = playerService.player else { return }
        
        let rewardAmount = remoteConfig.configValue(forKey: Config.RemoteConfig.rewardCoins)
            .numberValue.intValue
        
        player.coins += rewardAmount
        playerCoins = player.coins
        playerService.player = player
        playerService.saveProgress(player: player.toPlayerData())
        
        // WO-006: Log ad reward collection
        AnalyticsManager.shared.logAdReward(collected: true, placement: "hint_offer")
        
        triggerCoinAnimation()
        audioManager.playSound(effect: .success)
        
        appState.showOverlay(.coinGain(rewardAmount))
    }
    
    // MARK: - Adaptive Difficulty
    func checkAdaptiveDifficulty() {
        if consecutiveFailedGuesses >= Config.Gameplay.adaptiveDifficultyThreshold {
            // Could show a hint suggestion here
            appState.showOverlay(.hint("Try using a hint!"))
            consecutiveFailedGuesses = 0
        }
    }
    
    private func resetDifficultyTracking() {
        consecutiveFailedGuesses = 0
        levelsPlayedSinceHint = 0
    }
}
