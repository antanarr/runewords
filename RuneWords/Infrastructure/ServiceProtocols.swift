//
//  ServiceProtocols.swift
//  RuneWords
//
//  Protocol definitions for service abstraction and dependency injection
//

import Foundation
import SwiftUI
import Combine
import StoreKit
import FirebaseFirestore

// MARK: - Level Service Protocol
@MainActor protocol LevelServiceProtocol: ObservableObject {
    var currentLevel: Level? { get }
    var solutionFormats: [String: SolutionFormat] { get }
    var loadingProgress: Double { get }
    var isLoading: Bool { get }
    var allLevels: [Level] { get }
    
    func loadLevelsFromBundle() async
    func fetchLevel(id: Int) async
    func getLevelsWithDifficulty(_ difficulty: String) -> [Level]
    func getNextLevelID(for playerData: PlayerData) -> Int?
    func preloadNextChunk(for currentLevelID: Int) async
    func optimizeMemory(currentLevelID: Int)
    func validateLevelId(_ levelId: Int) -> Bool
    func clearCache()
}

// MARK: - Dictionary Service Protocol
@MainActor protocol DictionaryServiceProtocol: ObservableObject {
    var isLoaded: Bool { get }
    var loadingProgress: Double { get }
    
    func loadDictionaryAsync() async
    func isValidWord(_ word: String) -> Bool
    func hasPrefix(_ prefix: String) -> Bool
    func findWords(from letters: String, minLength: Int, maxLength: Int) async -> [String]
}

// MARK: - IAP Service Protocol
@MainActor protocol IAPServiceProtocol: ObservableObject {
    var hasPlus: Bool { get }
    var hasRemoveAds: Bool { get }
    var products: [Product] { get }
    var isProcessingPurchase: Bool { get }
    var purchaseError: Error? { get }
    
    func loadProducts() async
    func purchase(_ product: Product) async throws
    func restorePurchases() async
}

// MARK: - Ad Service Protocol
@MainActor protocol AdServiceProtocol: ObservableObject {
    var isInterstitialReady: Bool { get }
    var isRewardedAdAvailable: Bool { get }
    var canShowAds: Bool { get }
    
    func preloadAds()
    func showInterstitial(completion: @escaping (Bool) -> Void)
    func showRewardedAd(completion: @escaping (Bool) -> Void)
    func ensurePreloaded()
}

// MARK: - Audio Service Protocol
@MainActor protocol AudioServiceProtocol {
    func play(_ sound: AudioManager.SoundEffect)
    func playBackgroundMusic()
    func stopBackgroundMusic()
    func setEffectsEnabled(_ enabled: Bool)
    func setMusicEnabled(_ enabled: Bool)
}

// MARK: - Player Service Protocol
@MainActor
protocol PlayerServiceProtocol: ObservableObject {
    // Both Player and PlayerData access for flexibility
    var player: Player? { get set }
    var playerData: PlayerData? { get set }
    
    func initializePlayer()
    func saveProgress(player: PlayerData)
    func updateCurrentLevel(_ levelID: Int)
    func addCoins(_ amount: Int)
    func spendCoins(_ amount: Int) -> Bool
    func generatePlayerData() -> PlayerData
    func update(player: PlayerData)
    func markDailyChallengeCompleted()
    func calculateDynamicDifficulty() -> Int
    func selectLevelWithDynamicDifficulty(from levels: [Level]) -> Level?
}

// MARK: - Analytics Service Protocol
@MainActor protocol AnalyticsServiceProtocol {
    func logEvent(_ event: String, parameters: [String: Any]?)
    func setUserProperty(_ value: String?, forName name: String)
    func logScreenView(_ screenName: String)
}

// MARK: - Game Center Service Protocol
@MainActor protocol GameCenterServiceProtocol {
    var isAuthenticated: Bool { get }
    
    func authenticatePlayer() async
    func submitScore(_ score: Int, to leaderboard: String)
    func unlockAchievement(_ achievementID: String, percentComplete: Double)
    func unlockAchievement(_ achievement: String)  // Added for protocol conformance
    func showLeaderboard()
    func showAchievements()
}

// MARK: - Haptic Service Protocol
@MainActor protocol HapticServiceProtocol {
    func play(_ style: HapticManager.Style)
    func prepare()
}

// MARK: - Service Container
/// Central container for all app services using dependency injection
@MainActor
final class ServiceContainer: ObservableObject {
    // Services
    let levelService: any LevelServiceProtocol
    let dictionaryService: any DictionaryServiceProtocol
    let iapService: any IAPServiceProtocol
    let adService: any AdServiceProtocol
    let audioService: any AudioServiceProtocol
    let playerService: any PlayerServiceProtocol
    let analyticsService: any AnalyticsServiceProtocol
    let gameCenterService: any GameCenterServiceProtocol
    let hapticService: any HapticServiceProtocol
    
    // Singleton for production
    static let shared = ServiceContainer()
    
    // Test initializer for dependency injection
    init(
        levelService: (any LevelServiceProtocol)? = nil,
        dictionaryService: (any DictionaryServiceProtocol)? = nil,
        iapService: (any IAPServiceProtocol)? = nil,
        adService: (any AdServiceProtocol)? = nil,
        audioService: (any AudioServiceProtocol)? = nil,
        playerService: (any PlayerServiceProtocol)? = nil,
        analyticsService: (any AnalyticsServiceProtocol)? = nil,
        gameCenterService: (any GameCenterServiceProtocol)? = nil,
        hapticService: (any HapticServiceProtocol)? = nil
    ) {
        // Use provided services or default to real implementations
        self.levelService = levelService ?? LevelService.shared
        self.dictionaryService = dictionaryService ?? DictionaryService.shared
        self.iapService = iapService ?? IAPManager.shared
        self.adService = adService ?? AdManager.shared
        self.audioService = audioService ?? AudioManager.shared
        self.playerService = playerService ?? PlayerService.shared
        self.analyticsService = analyticsService ?? AnalyticsManager.shared
        self.gameCenterService = gameCenterService ?? GameCenterService.shared
        self.hapticService = hapticService ?? HapticManager.shared
    }
}

// MARK: - Environment Key
struct ServiceContainerKey: EnvironmentKey {
    static var defaultValue: ServiceContainer {
        MainActor.assumeIsolated { ServiceContainer.shared }
    }
}

extension EnvironmentValues {
    var services: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - Service Conformance Extensions
// Make existing services conform to protocols

extension LevelService: LevelServiceProtocol {}
extension DictionaryService: DictionaryServiceProtocol {}
extension PlayerService: PlayerServiceProtocol {}
extension IAPManager: IAPServiceProtocol {}
extension AdManager: AdServiceProtocol {}
extension AudioManager: AudioServiceProtocol {}
extension HapticManager: HapticServiceProtocol {}

// MARK: - Mock Services for Testing

#if DEBUG
// Mock Level Service
final class MockLevelService: LevelServiceProtocol {
    @Published var currentLevel: Level?
    @Published var solutionFormats: [String: SolutionFormat] = [:]
    @Published var loadingProgress: Double = 0
    @Published var isLoading: Bool = false
    
    var allLevels: [Level] = []
    
    func loadLevelsFromBundle() async {
        // Mock implementation
        isLoading = true
        loadingProgress = 1.0
        isLoading = false
    }
    
    func fetchLevel(id: Int) async {
        currentLevel = createMockLevel(id: id)
    }
    
    func getLevelsWithDifficulty(_ difficulty: String) -> [Level] {
        return allLevels.filter { $0.metadata?.difficulty.rawValue == difficulty }
    }
    
    func getNextLevelID(for playerData: PlayerData) -> Int? {
        return (currentLevel?.id ?? 0) + 1
    }
    
    func preloadNextChunk(for currentLevelID: Int) async {
        // Mock implementation
    }
    
    func optimizeMemory(currentLevelID: Int) {
        // Mock implementation
    }
    
    func validateLevelId(_ levelId: Int) -> Bool {
        return levelId > 0 && levelId <= 100
    }
    
    func clearCache() {
        allLevels.removeAll()
    }
    
    private func createMockLevel(id: Int) -> Level {
        return Level(
            id: id,
            realm: "test",
            baseLetters: "TEST",
            solutions: ["TEST": [1, 2, 3, 4]],
            bonusWords: ["THE"],
            metadata: nil
        )
    }
}

// Mock Dictionary Service
final class MockDictionaryService: DictionaryServiceProtocol {
    @Published var isLoaded: Bool = true
    @Published var loadingProgress: Double = 1.0
    
    private let validWords = Set(["THE", "AND", "FOR", "TEST", "WORD"])
    
    func loadDictionaryAsync() async {
        // Already loaded
    }
    
    func isValidWord(_ word: String) -> Bool {
        return validWords.contains(word.uppercased())
    }
    
    func hasPrefix(_ prefix: String) -> Bool {
        return validWords.contains { $0.hasPrefix(prefix.uppercased()) }
    }
    
    func findWords(from letters: String, minLength: Int, maxLength: Int) async -> [String] {
        return Array(validWords.filter { $0.count >= minLength && $0.count <= maxLength })
    }
}

// Mock IAP Service
final class MockIAPService: IAPServiceProtocol {
    @Published var hasPlus: Bool = false
    @Published var hasRemoveAds: Bool = false
    @Published var products: [Product] = []
    @Published var isProcessingPurchase: Bool = false
    @Published var purchaseError: Error?
    
    func loadProducts() async {
        // Mock products
    }
    
    func purchase(_ product: Product) async throws {
        isProcessingPurchase = true
        // Simulate purchase
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isProcessingPurchase = false
    }
    
    func restorePurchases() async {
        // Mock restore
    }
}
#endif
