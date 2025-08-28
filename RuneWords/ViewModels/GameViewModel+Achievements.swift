import Foundation
import SwiftUI

// MARK: - Achievements & Combo Extension
extension GameViewModel {
    
    // MARK: - Achievement Methods
    func initializeAchievements() {
        achievements = [
            Achievement(
                title: "Word Hunter",
                description: "Find \(Config.Achievements.wordHunterRequirement) words",
                icon: "magnifyingglass",
                rarity: .common,
                requirement: Config.Achievements.wordHunterRequirement
            ),
            Achievement(
                title: "Bonus Seeker",
                description: "Find \(Config.Achievements.bonusSeekerRequirement) bonus words",
                icon: "star.fill",
                rarity: .rare,
                requirement: Config.Achievements.bonusSeekerRequirement
            ),
            Achievement(
                title: "Level Master",
                description: "Complete \(Config.Achievements.levelMasterRequirement) levels",
                icon: "flag.checkered",
                rarity: .epic,
                requirement: Config.Achievements.levelMasterRequirement
            ),
            Achievement(
                title: "Coin Collector",
                description: "Earn \(Config.Achievements.coinCollectorRequirement) coins",
                icon: "dollarsign.circle.fill",
                rarity: .legendary,
                requirement: Config.Achievements.coinCollectorRequirement
            ),
            Achievement(
                title: "Combo King",
                description: "Achieve a \(Config.Achievements.comboKingRequirement)x combo",
                icon: "flame.fill",
                rarity: .epic,
                requirement: Config.Achievements.comboKingRequirement
            )
        ]
        
        // Load saved achievement progress
        loadAchievementProgress()
    }
    
    func checkAchievements(bonusWordFound: Bool = false) {
        guard let player = playerService.player else { return }
        
        // Word Hunter
        updateAchievementProgress(index: 0, progress: player.totalWordsFound)
        
        // Bonus Seeker
        if bonusWordFound {
            updateAchievementProgress(index: 1, progress: player.foundBonusWords.count)
        }
        
        // Level Master
        updateAchievementProgress(index: 2, progress: player.totalLevelsCompleted)
        
        // Coin Collector
        updateAchievementProgress(index: 3, progress: player.coins)
        
        // Combo King
        updateAchievementProgress(index: 4, progress: comboMultiplier)
    }
    
    private func updateAchievementProgress(index: Int, progress: Int) {
        guard index < achievements.count else { return }
        
        achievements[index].progress = progress
        
        // Check for unlock
        if !achievements[index].isUnlocked && progress >= achievements[index].requirement {
            unlockAchievement(at: index)
        }
    }
    
    private func unlockAchievement(at index: Int) {
        guard index < achievements.count else { return }
        
        achievements[index].isUnlocked = true
        showAchievementUnlock = achievements[index]
        
        // Award bonus coins
        let rarityString = achievements[index].rarity.rawValue
        let bonus = Config.Achievements.coinReward(for: rarityString)
        
        if var player = playerService.player {
            player.coins += bonus
            playerCoins = player.coins
            playerService.player = player
            playerService.saveProgress(player: player.toPlayerData())
        }
        
        // Save achievement progress
        saveAchievementProgress()
        
        // Play celebration sound
        audioManager.playSound(effect: .levelComplete)
        HapticManager.shared.play(.heavy)
        
        // Show notification
        appState.pendingNotification = .achievement(
            title: achievements[index].title,
            icon: achievements[index].icon
        )
    }
    
    private func loadAchievementProgress() {
        // Load from UserDefaults or persistent storage
        if let data = UserDefaults.standard.data(forKey: "achievements"),
           let saved = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = saved
        }
    }
    
    private func saveAchievementProgress() {
        // Save to UserDefaults or persistent storage
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: "achievements")
        }
    }
    
    // MARK: - Combo System
    func updateCombo() {
        let now = Date()
        let timeSinceLastCombo = now.timeIntervalSince(lastComboTime)
        
        if timeSinceLastCombo < Config.Gameplay.comboTimeWindow {
            // Continue combo
            comboCount += 1
            comboMultiplier = min(comboCount, Config.Gameplay.maxComboMultiplier)
            showComboDisplay = true
            
            // Apply combo multiplier to coins
            if var player = playerService.player {
                let bonusCoins = comboMultiplier - 1 // Extra coins from combo
                if bonusCoins > 0 {
                    player.coins += bonusCoins
                    playerCoins = player.coins
                    playerService.player = player
                    playerService.saveProgress(player: player.toPlayerData())
                }
            }
            
            // Show combo overlay
            appState.showOverlay(.combo(comboMultiplier), duration: Config.Animation.comboDisplayDuration)
            
            // Check combo achievement
            checkAchievements()
            
            // Hide display after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + Config.Animation.comboDisplayDuration) {
                self.showComboDisplay = false
            }
        } else {
            // Start new combo
            resetCombo()
            comboCount = 1
            comboMultiplier = 1
        }
        
        lastComboTime = now
    }
    
    func resetCombo() {
        comboCount = 0
        comboMultiplier = 1
        showComboDisplay = false
    }
    
    // MARK: - Statistics Tracking
    func trackStatistics(for event: StatisticEvent) {
        guard var player = playerService.player else { return }
        
        switch event {
        case .wordFound(let length):
            player.totalWordsFound += 1
            if length >= 6 {
                player.longestWordFound = max(player.longestWordFound, length)
            }
            
        case .hintUsed:
            player.totalHintsUsed += 1
            
        case .levelCompleted:
            player.totalLevelsCompleted += 1
            
        case .perfectLevel:
            player.perfectLevels += 1
            
        case .streakIncreased:
            // Handled elsewhere
            break
        }
        
        playerService.player = player
        playerService.saveProgress(player: player.toPlayerData())
    }
    

}
