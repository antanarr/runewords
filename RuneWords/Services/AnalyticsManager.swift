import StoreKit
import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// A centralized manager for logging all analytics events.
/// WO-006: Enhanced with comprehensive event tracking and debug logging.
@MainActor
final class AnalyticsManager: ObservableObject, AnalyticsServiceProtocol {
    static let shared = AnalyticsManager()
    
    @Published var isDebugLoggingEnabled: Bool = true
    @Published private(set) var eventCount: Int = 0
    
    private var isFirebaseAvailable: Bool = false
    private var sessionEvents: [String] = []
    
    private init() {
        checkFirebaseAvailability()
        
        #if DEBUG
        print("📊 AnalyticsManager initialized - Firebase: \(isFirebaseAvailable ? "✅" : "❌"), Debug: \(isDebugLoggingEnabled)")
        #endif
    }
    
    private func checkFirebaseAvailability() {
        #if canImport(FirebaseAnalytics)
        isFirebaseAvailable = true
        #else
        isFirebaseAvailable = false
        #endif
    }

    // MARK: - AnalyticsServiceProtocol conformance

    /// Set a user property for analytics (protocol requirement)
    func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Task.detached(priority: .background) {
            Analytics.setUserProperty(value, forName: name)
        }
        #endif
        #if DEBUG
        Task { @MainActor in
            if self.isDebugLoggingEnabled {
                print("👤 USER_PROPERTY: \(name)=\(value ?? "nil")")
            }
        }
        #endif
    }

    /// Log a screen view event (protocol requirement)
    func logScreenView(_ screenName: String) {
        #if canImport(FirebaseAnalytics)
        Task.detached(priority: .background) {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: screenName
            ])
        }
        #else
        logEvent("screen_view", parameters: [
            "screen_name": screenName
        ])
        #endif
        #if DEBUG
        Task { @MainActor in
            if self.isDebugLoggingEnabled {
                print("🖥️ SCREEN_VIEW: \(screenName)")
            }
        }
        #endif
    }

    // MARK: - WO-006 Core Analytics Methods
    
    /// Logs a standard analytics event with enhanced tracking (WO-006).
    /// - Parameters:
    ///   - event: A standard `AnalyticsEvent` string (e.g., `AnalyticsEventLevelStart`).
    ///   - parameters: A dictionary of event parameters.
    func logEvent(_ event: String, parameters: [String: Any]? = nil) {
        // Update counts on main actor
        Task { @MainActor in
            self.eventCount += 1
            self.sessionEvents.append(event)
        }
        
        // Send to Firebase if FirebaseAnalytics is present at compile time
        #if canImport(FirebaseAnalytics)
        Task.detached(priority: .background) {
            Analytics.logEvent(event, parameters: parameters)
        }
        #endif
        
        // Debug logging (WO-006)
        #if DEBUG
        Task { @MainActor in
            if self.isDebugLoggingEnabled {
                var paramString = ""
                if let params = parameters, !params.isEmpty {
                    let paramPairs = params.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                    paramString = " [\(paramPairs)]"
                }
                print("📊 ANALYTICS: \(event)\(paramString)")
            }
        }
        #endif
    }

    // MARK: - WO-006 Core Analytics Methods
    
    /// Log level start event
    func logLevelStart(id: Int, realm: String, difficulty: String) {
        #if canImport(FirebaseAnalytics)
        logEvent(AnalyticsEventLevelStart, parameters: [
            AnalyticsParameterLevelName: "\(id)",
            "realm": realm,
            "difficulty": difficulty
        ])
        #else
        logEvent("level_start", parameters: [
            "level_id": id,
            "realm": realm,
            "difficulty": difficulty
        ])
        #endif
        
        #if DEBUG
        if isDebugLoggingEnabled {
            print("🎮 LEVEL_START: ID=\(id), Realm=\(realm), Difficulty=\(difficulty)")
        }
        #endif
    }
    
    /// Log level completion event
    func logLevelComplete(id: Int, realm: String, difficulty: String, timeSec: Double, hintsUsed: Int, perfect: Bool) {
        #if canImport(FirebaseAnalytics)
        logEvent(AnalyticsEventLevelEnd, parameters: [
            AnalyticsParameterLevelName: "\(id)",
            "realm": realm,
            "difficulty": difficulty,
            "completion_time": timeSec,
            "hints_used": hintsUsed,
            "perfect_completion": perfect
        ])
        #else
        logEvent("level_complete", parameters: [
            "level_id": id,
            "realm": realm,
            "difficulty": difficulty,
            "completion_time": timeSec,
            "hints_used": hintsUsed,
            "perfect_completion": perfect
        ])
        #endif
        
        #if DEBUG
        if isDebugLoggingEnabled {
            let perfectText = perfect ? "✨PERFECT" : ""
            print("🏆 LEVEL_COMPLETE: ID=\(id) (\(realm)/\(difficulty)) - \(String(format: "%.1f", timeSec))s, \(hintsUsed) hints \(perfectText)")
        }
        #endif
    }

    func logWordFound(word: String, isBonus: Bool) {
        logEvent("word_found", parameters: [
            "word": word,
            "is_bonus": isBonus
        ])
    }

    /// Log hint usage (WO-006)
    func logHintUsed(type: String, cost: Int) {
        #if canImport(FirebaseAnalytics)
        logEvent(AnalyticsEventSpendVirtualCurrency, parameters: [
            AnalyticsParameterVirtualCurrencyName: "coins",
            AnalyticsParameterValue: cost,
            AnalyticsParameterItemName: "hint_\(type)"
        ])
        #else
        logEvent("hint_used", parameters: [
            "hint_type": type,
            "cost": cost
        ])
        #endif
        
        #if DEBUG
        if isDebugLoggingEnabled {
            print("💡 HINT_USED: Type=\(type), Cost=\(cost)")
        }
        #endif
    }
    
    /// Log ad reward collection (WO-006)
    func logAdReward(collected: Bool, placement: String) {
        logEvent("ad_reward", parameters: [
            "reward_collected": collected,
            "placement": placement
        ])
        
        #if DEBUG
        if isDebugLoggingEnabled {
            let status = collected ? "✅COLLECTED" : "❌DECLINED"
            print("📺 AD_REWARD: \(status) at \(placement)")
        }
        #endif
    }
    
    /// Log in-app purchase (WO-006)
    func logIAPPurchase(productId: String, success: Bool) {
        logEvent("iap_purchase", parameters: [
            "product_id": productId,
            "success": success
        ])
        
        #if DEBUG
        if isDebugLoggingEnabled {
            let status = success ? "✅SUCCESS" : "❌FAILED"
            print("💰 IAP_PURCHASE: \(productId) - \(status)")
        }
        #endif
    }
    
    /// Log FTUE state transitions (WO-006)
    func logFTUE(stateTransition: String) {
        logEvent("ftue_transition", parameters: [
            "state_transition": stateTransition
        ])
        
        #if DEBUG
        if isDebugLoggingEnabled {
            print("🎓 FTUE_TRANSITION: \(stateTransition)")
        }
        #endif
    }
    
    /// Log realm unlock (WO-006)
    func logRealmUnlock(realm: String, method: String) {
        logEvent("realm_unlock", parameters: [
            "realm": realm,
            "unlock_method": method  // "levels" or "difficulty"
        ])
        
        #if DEBUG
        if isDebugLoggingEnabled {
            print("🗝️ REALM_UNLOCK: \(realm) via \(method)")
        }
        #endif
    }

    func logPurchase(_ product: Product) {
        logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterItems: [
                [
                    AnalyticsParameterItemID: product.id,
                    AnalyticsParameterItemName: product.displayName,
                    AnalyticsParameterPrice: product.price,
                    AnalyticsParameterCurrency: product.priceFormatStyle.currencyCode
                ]
            ],
            AnalyticsParameterValue: product.price,
            AnalyticsParameterCurrency: product.priceFormatStyle.currencyCode
        ])
    }

    // MARK: - Ad Events
    func logAdImpression(adType: String) {
        logEvent(AnalyticsEventAdImpression, parameters: [
            AnalyticsParameterAdPlatform: "admob",
            AnalyticsParameterAdSource: "google",
            AnalyticsParameterAdFormat: adType
        ])
    }

    func logAdClick(adType: String) {
        logEvent("ad_click", parameters: [
            "ad_platform": "admob",
            "ad_source": "google",
            "ad_format": adType
        ])
    }

    // MARK: - User Engagement
    func logFirstLaunch() {
        logEvent("first_launch", parameters: nil)
    }

    func logDailyReturn() {
        logEvent("daily_return", parameters: nil)
    }

    func logStreakMilestone(days: Int) {
        logEvent("streak_milestone", parameters: [
            "streak_days": days
        ])
    }
    
    // MARK: - Debug & Session Methods (WO-006)
    
    /// Get session events summary
    func getSessionSummary() -> String {
        let eventCounts = sessionEvents.reduce(into: [String: Int]()) { counts, event in
            counts[event, default: 0] += 1
        }
        
        var summary = "📊 SESSION ANALYTICS SUMMARY:\n"
        summary += "  Total Events: \(eventCount)\n"
        summary += "  Event Types:\n"
        
        for (event, count) in eventCounts.sorted(by: { $0.value > $1.value }) {
            summary += "    \(event): \(count)\n"
        }
        
        return summary
    }
    
    /// Clear session events (for testing)
    func clearSessionEvents() {
        sessionEvents.removeAll()
        eventCount = 0
        
        #if DEBUG
        if isDebugLoggingEnabled {
            print("🗑️ Analytics session events cleared")
        }
        #endif
    }
    
    /// Log session start
    func logSessionStart() {
        logEvent("session_start", parameters: [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])
    }
    
    /// Log session end
    func logSessionEnd(duration: TimeInterval) {
        logEvent("session_end", parameters: [
            "session_duration": duration
        ])
        
        #if DEBUG
        if isDebugLoggingEnabled {
            print("⏹️ SESSION_END: Duration=\(String(format: "%.1f", duration))s")
            print(getSessionSummary())
        }
        #endif
    }
}
