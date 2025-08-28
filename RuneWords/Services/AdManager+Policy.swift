//
//  AdManager+Policy.swift
//  RuneWords
//
//  Ad presentation policy enforcement to prevent inappropriate ad timing

import Foundation
import UIKit

extension AdManager {
    
    // MARK: - Policy Constants
    private static let firstLaunchGracePeriod: TimeInterval = 300 // 5 minutes
    private static let postPurchaseCooldown: TimeInterval = 600 // 10 minutes
    private static let minimumSessionsBeforeAds = 2
    private static let minimumLevelsBeforeAds = 3
    
    // MARK: - Policy State Keys
    private struct PolicyKeys {
        static let firstLaunchTime = "AdPolicy.firstLaunchTime"
        static let lastPurchaseTime = "AdPolicy.lastPurchaseTime"
        static let sessionCount = "AdPolicy.sessionCount"
        static let hasSeenTutorial = "AdPolicy.hasSeenTutorial"
        static let adsDisabledUntil = "AdPolicy.adsDisabledUntil"
    }
    
    // MARK: - Policy Checks
    
    /// Check if ads should be shown based on all policy rules
    @MainActor
    func shouldShowAds() -> Bool {
        // Check if ads are permanently disabled
        if adsDisabled {
            Log.ads("Ads disabled by purchase")
            return false
        }
        
        // Check Plus/Remove Ads status
        if StoreViewModel.shared.hasPlus || StoreViewModel.shared.hasRemoveAds {
            Log.ads("Ads disabled by subscription")
            return false
        }
        
        // Check first launch grace period
        if isInFirstLaunchGracePeriod() {
            Log.ads("Ads disabled during first launch grace period")
            return false
        }
        
        // Check post-purchase cooldown
        if isInPostPurchaseCooldown() {
            Log.ads("Ads disabled during post-purchase cooldown")
            return false
        }
        
        // Check minimum sessions
        if !hasMetMinimumSessions() {
            Log.ads("Ads disabled - minimum sessions not met")
            return false
        }
        
        // Check minimum levels completed
        if !hasMetMinimumLevels() {
            Log.ads("Ads disabled - minimum levels not met")
            return false
        }
        
        // Check if tutorial is active
        if isTutorialActive() {
            Log.ads("Ads disabled during tutorial")
            return false
        }
        
        // Check temporary disable
        if isTemporarilyDisabled() {
            Log.ads("Ads temporarily disabled")
            return false
        }
        
        return true
    }
    
    /// Check if interstitial should be shown
    @MainActor
    func shouldShowInterstitial() -> Bool {
        guard shouldShowAds() else { return false }
        
        // Additional interstitial-specific checks
        
        // Don't show on level 1-3
        let currentLevel = PlayerService.shared.player?.currentLevelID ?? 1
        if currentLevel <= 3 {
            Log.ads("Interstitial blocked for early levels")
            return false
        }
        
        // Check frequency cap
        if let lastShow = lastInterstitialShow {
            let timeSince = Date().timeIntervalSince(lastShow)
            if timeSince < interstitialMinInterval {
                Log.ads("Interstitial frequency cap active: \(Int(interstitialMinInterval - timeSince))s remaining")
                return false
            }
        }
        
        return true
    }
    
    /// Check if rewarded ad should be shown
    @MainActor
    func shouldShowRewardedAd() -> Bool {
        // Rewarded ads have more lenient policy
        
        // Check if ads are permanently disabled
        if adsDisabled {
            return false
        }
        
        // Check Plus/Remove Ads status
        if StoreViewModel.shared.hasPlus || StoreViewModel.shared.hasRemoveAds {
            return false
        }
        
        // Allow rewarded ads even during grace periods if user explicitly requests
        // But still check tutorial
        if isTutorialActive() {
            Log.ads("Rewarded ads disabled during tutorial")
            return false
        }
        
        return true
    }
    
    // MARK: - Policy Helpers
    
    private func isInFirstLaunchGracePeriod() -> Bool {
        let defaults = UserDefaults.standard
        
        // Check if this is first launch
        if let firstLaunchTime = defaults.object(forKey: PolicyKeys.firstLaunchTime) as? Date {
            let timeSinceFirstLaunch = Date().timeIntervalSince(firstLaunchTime)
            return timeSinceFirstLaunch < Self.firstLaunchGracePeriod
        } else {
            // Record first launch time
            defaults.set(Date(), forKey: PolicyKeys.firstLaunchTime)
            return true // This is the first launch
        }
    }
    
    private func isInPostPurchaseCooldown() -> Bool {
        let defaults = UserDefaults.standard
        
        if let lastPurchaseTime = defaults.object(forKey: PolicyKeys.lastPurchaseTime) as? Date {
            let timeSincePurchase = Date().timeIntervalSince(lastPurchaseTime)
            return timeSincePurchase < Self.postPurchaseCooldown
        }
        
        return false
    }
    
    private func hasMetMinimumSessions() -> Bool {
        let defaults = UserDefaults.standard
        let sessionCount = defaults.integer(forKey: PolicyKeys.sessionCount)
        return sessionCount >= Self.minimumSessionsBeforeAds
    }
    
    private func hasMetMinimumLevels() -> Bool {
        let currentLevel = PlayerService.shared.player?.currentLevelID ?? 1
        return currentLevel > Self.minimumLevelsBeforeAds
    }
    
    @MainActor
    private func isTutorialActive() -> Bool {
        // Check multiple tutorial indicators
        let hasSeenTutorial = UserDefaults.standard.bool(forKey: PolicyKeys.hasSeenTutorial)
        let hasCompletedTutorial = UserDefaults.standard.bool(forKey: "hasCompletedTutorial")
        let currentLevel = PlayerService.shared.player?.currentLevelID ?? 1
        
        // Tutorial is active if:
        // - User hasn't seen tutorial yet
        // - User hasn't completed tutorial
        // - User is on level 1
        return !hasSeenTutorial || !hasCompletedTutorial || currentLevel == 1
    }
    
    private func isTemporarilyDisabled() -> Bool {
        let defaults = UserDefaults.standard
        
        if let disabledUntil = defaults.object(forKey: PolicyKeys.adsDisabledUntil) as? Date {
            if Date() < disabledUntil {
                return true
            } else {
                // Clear expired disable
                defaults.removeObject(forKey: PolicyKeys.adsDisabledUntil)
            }
        }
        
        return false
    }
    
    // MARK: - Policy Updates
    
    /// Record that a purchase was made
    static func recordPurchase() {
        UserDefaults.standard.set(Date(), forKey: PolicyKeys.lastPurchaseTime)
        Log.ads("Purchase recorded, starting cooldown period")
    }
    
    /// Record that tutorial was completed
    static func recordTutorialComplete() {
        UserDefaults.standard.set(true, forKey: PolicyKeys.hasSeenTutorial)
        Log.ads("Tutorial completed, ads may now be shown")
    }
    
    /// Increment session count
    static func incrementSessionCount() {
        let defaults = UserDefaults.standard
        let currentCount = defaults.integer(forKey: PolicyKeys.sessionCount)
        defaults.set(currentCount + 1, forKey: PolicyKeys.sessionCount)
        Log.ads("Session count: \(currentCount + 1)")
    }
    
    /// Temporarily disable ads
    static func temporarilyDisableAds(for duration: TimeInterval) {
        let disableUntil = Date().addingTimeInterval(duration)
        UserDefaults.standard.set(disableUntil, forKey: PolicyKeys.adsDisabledUntil)
        Log.ads("Ads temporarily disabled for \(Int(duration))s")
    }
    
    // MARK: - Enhanced Ad Methods with Policy
    
    /// Show interstitial with policy check
    @MainActor
    func showInterstitialAdWithPolicy() {
        guard shouldShowInterstitial() else {
            Log.ads("Interstitial blocked by policy")
            return
        }
        
        showInterstitialAd()
    }
    
    /// Show rewarded ad with policy check
    @MainActor
    func showRewardedAdWithPolicy(completion: @escaping (Bool) -> Void) {
        guard shouldShowRewardedAd() else {
            Log.ads("Rewarded ad blocked by policy")
            completion(false)
            return
        }
        
        showRewardedAd(completion: completion)
    }
}

// MARK: - App Lifecycle Integration

extension AdManager {
    
    /// Call when app launches
    static func handleAppLaunch() {
        incrementSessionCount()
        
        // Initialize first launch time if needed
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PolicyKeys.firstLaunchTime) == nil {
            defaults.set(Date(), forKey: PolicyKeys.firstLaunchTime)
            Log.ads("First app launch recorded")
        }
    }
    
    /// Call when returning from background
    static func handleAppBecomeActive() {
        // Check if we should increment session count
        // (Only if app was in background for more than 30 seconds)
        // This prevents multiple session counts for quick app switches
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension AdManager {
    
    /// Reset all policy flags for testing
    static func resetPolicyForTesting() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: PolicyKeys.firstLaunchTime)
        defaults.removeObject(forKey: PolicyKeys.lastPurchaseTime)
        defaults.removeObject(forKey: PolicyKeys.sessionCount)
        defaults.removeObject(forKey: PolicyKeys.hasSeenTutorial)
        defaults.removeObject(forKey: PolicyKeys.adsDisabledUntil)
        print("🔧 Ad policy reset for testing")
    }
    
    /// Force enable ads for testing
    static func forceEnableAdsForTesting() {
        let defaults = UserDefaults.standard
        defaults.set(Date().addingTimeInterval(-3600), forKey: PolicyKeys.firstLaunchTime)
        defaults.set(10, forKey: PolicyKeys.sessionCount)
        defaults.set(true, forKey: PolicyKeys.hasSeenTutorial)
        defaults.removeObject(forKey: PolicyKeys.lastPurchaseTime)
        defaults.removeObject(forKey: PolicyKeys.adsDisabledUntil)
        print("🔧 Ads force-enabled for testing")
    }
}
#endif
