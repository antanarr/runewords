import Foundation
import Combine
import CoreGraphics
import UIKit
import FirebaseRemoteConfig
import SwiftUI

// MARK: - GameViewModel Core
/// Refactored GameViewModel with feature-scoped extensions


enum StatisticEvent {
    case wordFound(length: Int)
    case hintUsed
    case levelCompleted
    case perfectLevel
    case streakIncreased
}

@MainActor
class GameViewModel: ObservableObject {

    // Note: Achievement types defined in GameModels.swift
    
    // MARK: - Core Properties
    @Published var currentLevel: Level?
    @Published var playerCoins: Int = 0
    @Published var isFirstLaunch: Bool = true
    
    // MARK: - Game State
    @Published var grid: [[GridLetter]] = []
    @Published var letterWheel: [WheelLetter] = []
    @Published var currentGuess: String = ""
    @Published var currentGuessIndices: [Int] = []
    @Published var foundWords: Set<String> = []
    @Published var bonusWordsFound: Set<String> = []
    @Published var isLevelComplete: Bool = false
    @Published var levelCompleted: Bool = false
    @Published var realmName: String?
    @Published var solutionFormats: [String: SolutionFormat] = [:]
    @Published var revealedLettersInSolutions: [String: Set<Int>] = [:]
    
    // Time tracking for Game Center
    var levelStartTime: Date?
    
    // MARK: - UI State
    @Published var shouldShakeGuess: Bool = false
    @Published var lastFoundWord: String?
    @Published var showLevelCompleteCelebration: Bool = false
    @Published var animateCoinGain: Bool = false
    
    // MARK: - Visual Effects Properties (from VisualEffects extension)
    @Published var hintedTileIDs: Set<UUID> = []
    @Published var revealedTileIDs: Set<UUID> = []
    @Published var wordCompletionParticles: [(position: CGPoint, word: String)] = []
    @Published var coinBurstEffects: [(start: CGPoint, end: CGPoint, count: Int)] = []
    @Published var levelTransitionPhase: Int = 0
    @Published var incorrectGuessEffects: [(position: CGPoint, word: String)] = []
    @Published var showErrorOverlay: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Achievement & Combo Properties (from Achievements extension)
    @Published var achievements: [Achievement] = []
    @Published var showAchievementUnlock: Achievement?
    @Published var comboCount: Int = 0
    @Published var comboMultiplier: Int = 1
    @Published var showComboDisplay: Bool = false
    
    // MARK: - Adaptive Difficulty (from Hints extension)
    @Published var consecutiveFailedGuesses: Int = 0
    @Published var levelsPlayedSinceHint: Int = 0
    @Published var isTargetingPrecision: Bool = false
    @Published var hintsUsedCount: Int = 0  // Track hints used in current level
    
    // MARK: - Audio Settings
    @Published var isMusicEnabled: Bool = true
    @Published var isSfxEnabled: Bool = true
    
    // MARK: - Services (Dependency Injection Ready)
    let playerService: PlayerService
    let levelService: LevelService
    let audioManager: AudioManager
    let adManager: AdManager
    let dictionaryService: DictionaryService
    let appState: AppState
    
    // MARK: - Remote Config
    var remoteConfig = RemoteConfig.remoteConfig()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Economy Values (from Remote Config)
    var hintCost = Config.Economy.defaultHintCost
    var revelationCost = Config.Economy.defaultRevelationCost
    var precisionCost = Config.Economy.defaultPrecisionCost
    var momentumCost = Config.Economy.defaultMomentumCost
    var bonusWordReward = Config.Economy.defaultBonusWordReward
    var levelCompleteReward = Config.Economy.defaultLevelCompleteReward
    
    // Combo tracking
    var lastComboTime: Date = Date()
    
    // Level transition timer (from VisualEffects extension)
    var levelTransitionTimer: Timer?
    
    // MARK: - Computed Properties
    var solutionWords: Set<String> {
        guard let solutions = currentLevel?.solutions else { return [] }
        return Set(solutions.keys)
    }
    
    var targetWords: [String] {
        guard let solutions = currentLevel?.solutions else { return [] }
        return Array(solutions.keys).sorted { $0.count > $1.count || ($0.count == $1.count && $0 < $1) }
    }
    
    var revealedIndicesByWord: [String: Set<Int>] {
        return revealedLettersInSolutions
    }
    
    var clarityAffordable: Bool { playerCoins >= hintCost }
    var precisionAffordable: Bool { playerCoins >= precisionCost }
    var momentumAffordable: Bool { playerCoins >= momentumCost }
    
    // MARK: - Initialization
    init(playerService: PlayerService? = nil,
         levelService: LevelService? = nil,
         audioManager: AudioManager? = nil,
         adManager: AdManager? = nil,
         dictionaryService: DictionaryService? = nil,
         appState: AppState? = nil) {
        
        self.playerService = playerService ?? PlayerService.shared
        self.levelService = levelService ?? LevelService.shared
        self.audioManager = audioManager ?? AudioManager.shared
        self.adManager = adManager ?? AdManager.shared
        self.dictionaryService = dictionaryService ?? DictionaryService.shared
        self.appState = appState ?? AppState.shared
        
        self.isFirstLaunch = UserDefaults.standard.object(forKey: Config.Storage.isFirstLaunch) as? Bool ?? true
        
        setupSubscribers()
        setupRemoteConfig()
        initializeLevelService()
    }
    
    // MARK: - Setup Methods
    private func setupSubscribers() {
        // Player data updates
        playerService.$player
            .compactMap { $0 }
            .removeDuplicates { old, new in
                old.currentLevelID == new.currentLevelID &&
                old.coins == new.coins &&
                old.lastPlayedDate == new.lastPlayedDate
            }
            .sink { [weak self] player in
                guard let self = self else { return }
                
                Task {
                    await self.levelService.fetchLevel(id: player.currentLevelID)
                }
                
                self.bonusWordsFound = player.foundBonusWords
                self.playerCoins = player.coins
            }
            .store(in: &cancellables)
        
        // Level updates
        levelService.$currentLevel
            .compactMap { $0 }
            .sink { [weak self] level in
                self?.setupLevel(level: level)
            }
            .store(in: &cancellables)
        
        // Audio settings sync
        audioManager.$isMusicEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: \.isMusicEnabled, on: self)
            .store(in: &cancellables)
        
        audioManager.$isSfxEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSfxEnabled, on: self)
            .store(in: &cancellables)
        
        // Solution formats from LevelService
        levelService.$solutionFormats
            .receive(on: DispatchQueue.main)
            .assign(to: &$solutionFormats)
    }
    
    private func setupRemoteConfig() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings
        
        // Set defaults
        remoteConfig.setDefaults([
            Config.RemoteConfig.adForHintEnabled: false as NSObject,
            Config.RemoteConfig.adForRevelationEnabled: false as NSObject,
            Config.RemoteConfig.rewardCoins: Config.Economy.adRewardCoins as NSObject,
            Config.RemoteConfig.bonusWordCoin: Config.Economy.defaultBonusWordReward as NSObject,
            Config.RemoteConfig.levelCompleteReward: Config.Economy.defaultLevelCompleteReward as NSObject,
            Config.RemoteConfig.clarityCost: Config.Economy.defaultHintCost as NSObject,
            Config.RemoteConfig.precisionCost: Config.Economy.defaultPrecisionCost as NSObject,
            Config.RemoteConfig.momentumCost: Config.Economy.defaultMomentumCost as NSObject,
            Config.RemoteConfig.interstitialEnabled: true as NSObject,
            Config.RemoteConfig.interstitialOnLevelComplete: true as NSObject,
            Config.RemoteConfig.interstitialEveryNLevels: Config.Ads.defaultInterstitialEveryNLevels as NSObject
        ])
        
        // Fetch and activate
        remoteConfig.fetchAndActivate { [weak self] status, error in
            if let error = error {
                print("Remote Config fetch error: \(error)")
            }
            
            DispatchQueue.main.async {
                self?.updateEconomyFromRemoteConfig()
            }
        }
    }
    
    private func updateEconomyFromRemoteConfig() {
        bonusWordReward = remoteConfig.configValue(forKey: Config.RemoteConfig.bonusWordCoin).numberValue.intValue
        levelCompleteReward = remoteConfig.configValue(forKey: Config.RemoteConfig.levelCompleteReward).numberValue.intValue
        hintCost = remoteConfig.configValue(forKey: Config.RemoteConfig.clarityCost).numberValue.intValue
        precisionCost = remoteConfig.configValue(forKey: Config.RemoteConfig.precisionCost).numberValue.intValue
        momentumCost = remoteConfig.configValue(forKey: Config.RemoteConfig.momentumCost).numberValue.intValue
    }
    
    private func initializeLevelService() {
        Task {
            // Ensure auth before loading catalog
            print("🔄 initializeLevelService: Ensuring auth...")
            await AuthService.shared.ensureSignedIn()
            print("🔄 initializeLevelService: Auth ready, loading catalog...")
            await levelService.loadCatalogIfNeeded(preferRemote: true)
            print("🔄 initializeLevelService: Complete - Source: \(levelService.currentCatalogSource.rawValue)")
        }
        // Dictionary service loads automatically on init
        _ = dictionaryService
    }
    
    // MARK: - Prepare for Play (P0 Fix)
    @MainActor
    func prepareForPlay() async {
        print("🎮 prepareForPlay: Starting...")
        print("🎮 Auth status: \(AuthService.shared.isAuthenticated)")
        
        // ALWAYS ensure authentication is complete before loading levels
        // This is CRITICAL for remote catalog loading
        print("⏳ Ensuring authentication...")
        await AuthService.shared.ensureSignedIn()
        print("✅ Auth complete: \(AuthService.shared.uid ?? "nil")")
        
        // Load catalog with remote preference now that auth is ready
        print("📚 Loading catalog with remote preference...")
        await levelService.loadCatalogIfNeeded(preferRemote: true)
        print("📚 Catalog loaded - Source: \(levelService.currentCatalogSource.rawValue), Count: \(levelService.totalLevelCount)")
        
        // Wait for catalog to be fully ready (Slice 4)
        let catalogReady = await levelService.catalogState.waitUntilReady(timeout: 1.5)
        if catalogReady {
            print("✅ Catalog ready for gameplay")
        } else {
            print("⚠️ Catalog readiness timeout - using bootstrap")
        }
        
        // Get current level ID from player or use last completed + 1
        var levelID = playerService.player?.currentLevelID ?? LevelService.bootstrap.id
        
        // Check if we have saved progress in Firestore
        if let uid = AuthService.shared.uid {
            // Get last completed level from Firestore
            if let lastLevelId = await ProgressService.shared.fetchLastLevelId(uid: uid) {
                // Try next level after last completed
                let nextId = lastLevelId + 1
                if levelService.validateLevelId(nextId) {
                    levelID = nextId
                } else {
                    // If next doesn't exist, use the last completed
                    levelID = lastLevelId
                }
            }
            
            // Check if current level is already completed
            let alreadyCompleted = await ProgressService.shared.hasCompleted(uid: uid, levelId: levelID)
            if alreadyCompleted {
                // Find next uncompleted level
                let completedLevels = await ProgressService.shared.fetchCompletedLevelIds(uid: uid)
                // Find first uncompleted level starting from current
                var searchId = levelID + 1
                while searchId < levelID + 100 { // Search up to 100 levels ahead
                    if levelService.validateLevelId(searchId) && !completedLevels.contains(searchId) {
                        levelID = searchId
                        break
                    }
                    searchId += 1
                }
            }
        }
        
        // Fetch the level (will use bootstrap if catalog fails)
        await levelService.fetchLevel(id: levelID)
        
        // Setup the level (bootstrap guaranteed to exist)
        let level = levelService.currentLevel ?? LevelService.bootstrap
        setupLevel(level: level)
        
        // Log catalog info
        print("📦 Final state:")
        print("📦 Catalog source: \(levelService.currentCatalogSource.rawValue)")
        print("📦 Catalog version: \(levelService.catalogVersion)")
        print("📦 Current level: \(level.id) - \(level.baseLetters)")
        
        // If still on bootstrap, try one more time
        if level.id == LevelService.bootstrap.id && levelService.currentCatalogSource == .remote {
            print("⚠️ Still on bootstrap despite remote catalog - fetching actual level")
            if let firstId = levelService.orderedLevelIDs.first(where: { $0 != LevelService.bootstrap.id }) {
                await levelService.fetchLevel(id: firstId)
                if let newLevel = levelService.currentLevel {
                    setupLevel(level: newLevel)
                    print("✅ Loaded actual level: \(newLevel.id)")
                }
            }
        }
    }
    
    // MARK: - Public Methods
    func loadLevel(levelID: Int) {
        print("🎮 Loading specific level: \(levelID)")
        Task {
            // Wait for catalog to be ready (Slice 4)
            let ready = await levelService.catalogState.waitUntilReady()
            if !ready {
                print("⚠️ Catalog not ready after timeout, proceeding anyway")
            }
            
            if var player = playerService.player {
                player.currentLevelID = levelID
                playerService.player = player
                playerService.saveProgress(player: player.toPlayerData())
            }
            
            await levelService.fetchLevel(id: levelID)
        }
    }
    
    func completeOnboarding() {
        isFirstLaunch = false
        UserDefaults.standard.set(false, forKey: Config.Storage.isFirstLaunch)
    }
    
    func toggleMusic() { audioManager.toggleMusic() }
    func toggleSfx() { audioManager.toggleSfx() }
    
    // MARK: - Pill Animation Triggers
    /// Publishes when a word should animate from pill to slot
    @Published var animatingWordToSlot: String? = nil
    @Published var animatingWordToBonus: String? = nil
    
    /// Trigger pill-to-slot animation
    func triggerPillToSlotAnimation(word: String) {
        guard !word.isEmpty else { return }
        
        animatingWordToSlot = word
        HapticManager.shared.play(.success)
        
        // Clear after animation duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.animatingWordToSlot = nil
        }
    }
    
    /// Trigger pill-to-bonus animation
    func triggerPillToBonusAnimation(word: String) {
        guard !word.isEmpty else { return }
        
        animatingWordToBonus = word
        HapticManager.shared.play(.light)
        
        // Clear after animation duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.animatingWordToBonus = nil
        }
    }
}
