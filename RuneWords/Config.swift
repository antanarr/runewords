import Foundation
import SwiftUI

// MARK: - Configuration Constants
enum Config {
    
    // MARK: - Economy
    enum Economy {
        static let defaultHintCost = 25
        static let defaultRevelationCost = 125
        static let defaultPrecisionCost = 50
        static let defaultMomentumCost = 75
        static let defaultBonusWordReward = 5
        static let defaultLevelCompleteReward = 25
        static let levelCompletionBonus = 50  // Bonus for completing a level
        static let perfectLevelBonus = 50
        static let longWordBonus = 5 // For 6+ letter words
        static let adRewardCoins = 25
        
        static func wordReward(for length: Int) -> Int {
            switch length {
            case 3: return 3
            case 4: return 5
            case 5: return 8
            case 6...: return 12 // Anagram bonus
            default: return 1
            }
        }
    }
    
    // MARK: - Gameplay (WO-003)
    enum Gameplay {
        // Difficulty scoring parameters (RemoteConfig-backed)
        static let defaultSolutionCountWeight = 0.015  // α: penalty for many solutions
        static let defaultAverageWordLengthWeight = 0.25  // β: bonus for longer words  
        static let defaultRareLetterWeight = 0.8  // γ: bonus for rare letters
        
        // Realm unlock requirements
        static let crystalForestUnlockLevels = 250  // Tree Library levels needed
        static let sleepingTitanUnlockLevels = 200  // Crystal Forest levels needed
        static let astralPeakUnlockLevels = 150     // Sleeping Titan levels needed
        
        // Alternative unlock paths
        static let mediumTierUnlockCount = 40    // Medium difficulty levels for Crystal Forest
        static let hardTierUnlockCount = 10      // Hard difficulty levels for Sleeping Titan
        static let expertTierUnlockCount = 10    // Expert difficulty levels for Astral Peak
        
        // General gameplay
        static let comboTimeWindow: TimeInterval = 5.0
        static let maxComboMultiplier = 5
        static let adaptiveDifficultyThreshold = 5 // Failed guesses before hint
        static let requiredLetterCount = 6 // All levels must have exactly 6 letters
        
        // Word validation settings (from GameViewModel+WordValidation)
        static let requireExactIndices = true // Strict index validation (as per spec)
        static let minBonusWordLength = 3
        static let maxBonusWordLength = 5
    }
    
    // MARK: - Ads
    enum Ads {
        static let interstitialMinInterval: TimeInterval = 120
        static let defaultInterstitialEveryNLevels = 3
        static let maxBackoffDelay: TimeInterval = 64
    }
    
    // MARK: - Animations
    enum Animation {
        static let tileRevealDelay = 0.08
        static let wheelRevealDelay = 0.1
        static let shakeAnimationDuration = 0.5
        static let coinAnimationDuration = 0.5
        static let celebrationDismissDelay = 2.0
        static let comboDisplayDuration = 2.0
        static let errorMessageDuration = 2.0
        static let hintGlowDuration = 0.75
        static let levelTransitionPhaseDelay = 1.0
    }
    
    // MARK: - UI
    enum UI {
        static let primaryFont = "Cinzel-Bold"
        static let secondaryFont = "Cinzel-VariableFont_wght"
        
        // Colors
        static let primaryGradient = LinearGradient(
            colors: [Color(red: 0.557, green: 0.553, blue: 0.8), 
                    Color(red: 0.4, green: 0.4, blue: 0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let darkBackgroundGradient = LinearGradient(
            colors: [Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.02, blue: 0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Remote Config Keys
    enum RemoteConfig {
        static let adForHintEnabled = "ad_for_hint_enabled"
        static let adForRevelationEnabled = "ad_for_revelation_enabled"
        static let rewardCoins = "reward_coins"
        static let bonusWordCoin = "bonus_word_coin"
        static let levelCompleteReward = "level_complete_reward"
        static let clarityCost = "clarity_cost"
        static let precisionCost = "precision_cost"
        static let momentumCost = "momentum_cost"
        static let interstitialEnabled = "interstitial_enabled"
        static let interstitialOnLevelComplete = "interstitial_on_level_complete"
        static let interstitialEveryNLevels = "interstitial_every_n_levels"
    }
    
    // MARK: - Achievement Requirements
    enum Achievements {
        static let wordHunterRequirement = 10
        static let bonusSeekerRequirement = 25
        static let levelMasterRequirement = 50
        static let coinCollectorRequirement = 1000
        static let comboKingRequirement = 5

        static func coinReward(for rarityString: String) -> Int {
            switch rarityString {
            case "common": return 50
            case "rare": return 100
            case "epic": return 200
            case "legendary": return 500
            default: return 50
            }
        }
    }
    
    // MARK: - Storage Keys
    enum Storage {
        static let isFirstLaunch = "isFirstLaunch"
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let hasCompletedTutorial = "hasCompletedTutorial"
        static let showMainMenu = "showMainMenu"
    }
}
