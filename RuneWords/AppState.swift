import Foundation
import SwiftUI
import Combine

// MARK: - App State Management
/// Centralized app state to replace scattered @Published flags
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Navigation State
    @Published var currentScreen: Screen = .loading
    @Published var isShowingOnboarding = false
    @Published var isShowingTutorial = false
    @Published var isShowingMainMenu = false
    
    // MARK: - Game Phase State
    @Published var gamePhase: GamePhase = .idle
    @Published var isLevelTransitioning = false
    @Published var transitionProgress: CGFloat = 0
    
    // MARK: - Ad State
    @Published var adState: AdState = .idle
    @Published var pendingAdReward: AdReward?
    
    // MARK: - UI State
    @Published var activeModal: ModalType?
    @Published var activeOverlay: OverlayType?
    @Published var pendingNotification: NotificationType?
    
    // MARK: - Error State
    @Published var currentError: AppError?
    @Published var isShowingError = false
    
    // MARK: - FTUE State (WO-002)
    @Published var ftueState: FTUEState = .intro {
        didSet {
            // Persist to UserDefaults
            UserDefaults.standard.set(ftueState.rawValue, forKey: "FTUEState")
            
            // WO-006: Log FTUE transitions
            let transition = "\(oldValue.rawValue)_to_\(ftueState.rawValue)"
            AnalyticsManager.shared.logFTUE(stateTransition: transition)
        }
    }
    
    // Singleton
    static let shared = AppState()
    private init() {
        // Initialize FTUE state from UserDefaults
        if let savedStateRaw = UserDefaults.standard.object(forKey: "FTUEState") as? String,
           let savedState = FTUEState(rawValue: savedStateRaw) {
            ftueState = savedState
        } else {
            // First time user
            ftueState = .intro
        }
    }
    
    // MARK: - Screen Types
    enum Screen: Equatable {
        case loading
        case mainMenu
        case game
        case store
        case realmMap
        case dailyChallenge
        case settings
        case onboarding
        case tutorial
    }
    
    // MARK: - Game Phases
    enum GamePhase: Equatable {
        case idle
        case playing
        case paused
        case levelComplete
        case transitioning
        case celebration
    }
    
    // MARK: - Ad States
    enum AdState: Equatable {
        case idle
        case loading
        case presenting
        case rewarded
        case failed(String)
    }
    
    // MARK: - Modal Types
    enum ModalType: Identifiable, Equatable {
        case pause
        case levelComplete
        case achievement(String)
        case store
        case settings
        case hint
        
        var id: String {
            switch self {
            case .pause: return "pause"
            case .levelComplete: return "levelComplete"
            case .achievement(let title): return "achievement_\(title)"
            case .store: return "store"
            case .settings: return "settings"
            case .hint: return "hint"
            }
        }
    }
    
    // MARK: - Overlay Types
    enum OverlayType: Identifiable, Equatable {
        case celebration
        case combo(Int)
        case coinGain(Int)
        case error(String)
        case hint(String)
        
        var id: String {
            switch self {
            case .celebration: return "celebration"
            case .combo(let count): return "combo_\(count)"
            case .coinGain(let amount): return "coin_\(amount)"
            case .error(let msg): return "error_\(msg)"
            case .hint(let msg): return "hint_\(msg)"
            }
        }
    }
    
    // MARK: - Notification Types
    enum NotificationType: Identifiable {
        case achievement(title: String, icon: String)
        case dailyBonus(coins: Int)
        case levelUp(level: Int)
        case streakBonus(days: Int)
        
        var id: String {
            switch self {
            case .achievement(let title, _): return "achievement_\(title)"
            case .dailyBonus(let coins): return "daily_\(coins)"
            case .levelUp(let level): return "levelup_\(level)"
            case .streakBonus(let days): return "streak_\(days)"
            }
        }
    }
    
    // MARK: - FTUE States (WO-002)
    enum FTUEState: String, Codable, CaseIterable {
        case intro      // Show intro/onboarding screens
        case coachmarks // Show coach-marks tutorial in game
        case complete   // FTUE completed
        
        var isCompleted: Bool {
            return self == .complete
        }
        
        var needsIntro: Bool {
            return self == .intro
        }
        
        var needsCoachmarks: Bool {
            return self == .coachmarks
        }
    }
    
    // MARK: - Ad Reward
    struct AdReward: Equatable {
        let type: RewardType
        let amount: Int
        
        enum RewardType {
            case coins
            case hint
            case revelation
        }
    }
    
    // MARK: - App Error
    struct AppError: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let isRecoverable: Bool
        
        static func == (lhs: AppError, rhs: AppError) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - State Management Methods
    func navigate(to screen: Screen) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = screen
        }
    }
    
    func showModal(_ modal: ModalType) {
        withAnimation(.spring()) {
            activeModal = modal
        }
    }
    
    func dismissModal() {
        withAnimation(.spring()) {
            activeModal = nil
        }
    }
    
    func showOverlay(_ overlay: OverlayType, duration: TimeInterval = Config.Animation.errorMessageDuration) {
        withAnimation(.easeIn(duration: 0.2)) {
            activeOverlay = overlay
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.activeOverlay = nil
            }
        }
    }
    
    func showError(_ error: AppError) {
        currentError = error
        isShowingError = true
    }
    
    func clearError() {
        currentError = nil
        isShowingError = false
    }
    
    func updateGamePhase(_ phase: GamePhase) {
        withAnimation {
            gamePhase = phase
        }
    }
    
    func updateAdState(_ state: AdState) {
        adState = state
        
        // Auto-clear failed state after delay
        if case .failed = state {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if case .failed = self?.adState {
                    self?.adState = .idle
                }
            }
        }
    }
    
    // MARK: - FTUE Management (WO-002)
    
    /// Complete intro and advance to coach-marks
    func completeIntro() {
        withAnimation(.easeInOut(duration: 0.5)) {
            ftueState = .coachmarks
        }
    }
    
    /// Complete coach-marks and finish FTUE
    func completeCoachmarks() {
        withAnimation(.easeInOut(duration: 0.3)) {
            ftueState = .complete
        }
    }
    
    /// Reset FTUE to intro (for Settings replay)
    func resetFTUEToIntro() {
        ftueState = .intro
    }
    
    /// Reset FTUE to coach-marks only (for Settings tutorial replay)
    func resetFTUEToCoachmarks() {
        ftueState = .coachmarks
    }
    
    /// Check if first-time flow is needed on app launch
    func shouldShowIntroFlow() -> Bool {
        return ftueState.needsIntro
    }
    
    /// Check if coach-marks should show when entering game
    func shouldShowCoachmarks() -> Bool {
        return ftueState.needsCoachmarks
    }
}

// MARK: - Environment Key
struct AppStateKey: EnvironmentKey {
    typealias Value = AppState
    @MainActor static var defaultValue: AppState { AppState.shared }
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
