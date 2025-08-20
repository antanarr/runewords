import Foundation
import SwiftUI
import UIKit

// MARK: - Visual Effects Extension
extension GameViewModel {
    
    // MARK: - Cleanup Method (NEW)
    /// Clean up all visual effects - call this on view dismissal
    func cleanupVisualEffects() {
        wordCompletionParticles.removeAll()
        coinBurstEffects.removeAll()
        incorrectGuessEffects.removeAll()
        hintedTileIDs.removeAll()
        revealedTileIDs.removeAll()
        levelTransitionPhase = 0
        showErrorOverlay = false
        errorMessage = ""
        print("🧹 Visual effects cleaned up")
    }
    
    // MARK: - Shake Animation
    func triggerShakeAnimation(for guess: String? = nil) {
        if let guess = guess, !guess.isEmpty {
            self.currentGuess = guess
            triggerIncorrectGuessEffects(for: guess, at: CGPoint(x: 200, y: 400))
        }
        
        shouldShakeGuess = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.shakeAnimationDuration) { [weak self] in
            self?.shouldShakeGuess = false
            self?.currentGuess = ""
        }
    }
    
    // MARK: - Coin Animation
    func triggerCoinAnimation() {
        animateCoinGain = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.coinAnimationDuration) { [weak self] in
            self?.animateCoinGain = false
        }
    }
    
    // MARK: - Word Completion Particles (FIXED with cleanup tracking)
    func triggerWordCompletionParticles(at position: CGPoint, for word: String) {
        // Add unique identifier to track this specific particle effect
        let particleId = UUID().uuidString
        let particleEntry = (position: position, word: "\(word)_\(particleId)")
        wordCompletionParticles.append(particleEntry)
        
        // FIXED: Use weak self to prevent retain cycles
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            // Remove specific particle by ID
            self.wordCompletionParticles.removeAll { $0.word == particleEntry.word }
        }
        
        // Safety limit - prevent unbounded growth
        if wordCompletionParticles.count > 10 {
            wordCompletionParticles.removeFirst()
        }
    }
    
    // MARK: - Coin Burst Effect (FIXED with queue management)
    func triggerCoinBurstEffect(from startPosition: CGPoint, to endPosition: CGPoint, coinCount: Int) {
        // Prevent overlapping animations - queue management
        if coinBurstEffects.count >= 3 {
            // Remove oldest if too many animations
            coinBurstEffects.removeFirst()
        }
        
        coinBurstEffects.append((start: startPosition, end: endPosition, count: coinCount))
        
        // FIXED: Use weak self and ensure cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if !self.coinBurstEffects.isEmpty {
                self.coinBurstEffects.removeFirst()
            }
        }
    }
    
    // MARK: - Incorrect Guess Effects (FIXED with proper cleanup)
    func triggerIncorrectGuessEffects(for word: String, at position: CGPoint) {
        // Add unique identifier
        let effectId = UUID().uuidString
        let effectEntry = (position: position, word: "\(word)_\(effectId)")
        incorrectGuessEffects.append(effectEntry)
        
        // FIXED: Weak self reference
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.incorrectGuessEffects.removeAll { $0.word == effectEntry.word }
        }
        
        // Safety limit
        if incorrectGuessEffects.count > 5 {
            incorrectGuessEffects.removeFirst()
        }
    }
    
    // MARK: - Error Overlay
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showErrorOverlay = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.errorMessageDuration) { [weak self] in
            self?.showErrorOverlay = false
        }
    }
    
    // MARK: - Level Transition Management
    func cancelLevelTransition() {
        levelTransitionTimer?.invalidate()
        levelTransitionTimer = nil
        levelTransitionPhase = 0
    }
    
    // MARK: - Level Transition
    func triggerLevelTransition(from oldLevel: Int, to newLevel: Int) {
        // Phase 1: Level complete
        levelTransitionPhase = 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.levelTransitionPhaseDelay) {
            // Phase 2: Swoosh
            self.levelTransitionPhase = 2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.levelTransitionPhaseDelay * 1.5) {
            // Phase 3: Realm info
            self.levelTransitionPhase = 3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.levelTransitionPhaseDelay * 2.5) {
            // Phase 4: Level number
            self.levelTransitionPhase = 4
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.levelTransitionPhaseDelay * 3.5) {
            // Reset
            self.levelTransitionPhase = 0
        }
    }
    
    // MARK: - Word Reveal Animation
    func revealWordInGridWithAnimation(_ word: String, isRevelation: Bool = false) async {
        guard let format = solutionFormats[word] else { return }
        
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        
        var idsToFlash: Set<UUID> = []
        
        switch format {
        case .grid(let coords):
            // Enhanced grid reveal with cascade
            for (index, (row, col)) in coords.enumerated() {
                guard row < grid.count, col < grid[row].count else { continue }
                
                // Animated reveal
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.4)
                        .delay(Double(index) * Config.Animation.tileRevealDelay)) {
                        grid[row][col].isVisible = true
                    }
                    
                    // Glow for revelations
                    if isRevelation {
                        withAnimation(.easeInOut(duration: 0.3)
                            .delay(Double(index) * Config.Animation.tileRevealDelay)) {
                            hintedTileIDs.insert(grid[row][col].id)
                        }
                        
                        // Remove glow
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.8 + Double(index) * Config.Animation.tileRevealDelay
                        ) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                _ = self.hintedTileIDs.remove(self.grid[row][col].id)
                            }
                        }
                    }
                    
                    feedback.impactOccurred()
                    idsToFlash.insert(grid[row][col].id)
                }
                
                // Cascade delay
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        continuation.resume()
                    }
                }
            }
            
        case .wheel(let indices):
            // Enhanced wheel reveal
            for (index, originalIndex) in indices.enumerated() {
                if let letter = letterWheel.first(where: { $0.originalIndex == originalIndex }) {
                    await MainActor.run {
                        // Ripple animation
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)
                            .delay(Double(index) * Config.Animation.wheelRevealDelay)) {
                            hintedTileIDs.insert(letter.id)
                        }
                        
                        feedback.impactOccurred()
                        idsToFlash.insert(letter.id)
                    }
                    
                    // Cascade delay
                    await withCheckedContinuation { continuation in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            continuation.resume()
                        }
                    }
                    
                    // Remove highlight
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                            hintedTileIDs.remove(letter.id)
                        }
                        feedback.impactOccurred()
                    }
                }
            }
        }
        
        // Revelation sparkle
        if isRevelation {
            await MainActor.run {
                revealedTileIDs = idsToFlash
                
                // Add sparkle particles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    for id in idsToFlash {
                        if self.findGridPosition(for: id) != nil {
                            let screenPosition = CGPoint(x: 200, y: 300)
                            self.wordCompletionParticles.append((position: screenPosition, word: "✨"))
                        }
                    }
                }
                
                // Clear revelation highlight
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.revealedTileIDs.removeAll()
                    }
                }
                
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }
    
    // MARK: - Grid Reveal (Non-animated)
    func revealWordInGrid(_ word: String) {
        guard let format = solutionFormats[word] else { return }
        
        switch format {
        case .grid(let coords):
            for (row, col) in coords where row < grid.count && col < grid[row].count {
                grid[row][col].isVisible = true
            }
            
        case .wheel(let indices):
            for index in indices {
                if let letter = letterWheel.first(where: { $0.originalIndex == index }) {
                    hintedTileIDs.insert(letter.id)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.hintGlowDuration) {
                        self.hintedTileIDs.remove(letter.id)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func findGridPosition(for id: UUID) -> (row: Int, col: Int)? {
        for (row, rowArray) in grid.enumerated() {
            for (col, letter) in rowArray.enumerated() {
                if letter.id == id {
                    return (row: row, col: col)
                }
            }
        }
        return nil
    }
}
