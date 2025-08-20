//
//  AdManager.swift
//  RuneWords
//
//  Fixed: Use test AdMob IDs in Debug/AdHoc, production IDs only in Release
//  Updated for Google Mobile Ads SDK 11.x API changes

import Foundation
import GoogleMobileAds
import UIKit
import Combine

@MainActor final class AdManager: NSObject, ObservableObject {
    
    private var interstitial: InterstitialAd?
    private var isShowingInterstitial = false
    private var rewarded: RewardedAd?
    private var isShowingRewarded = false
    private var rewardCompletion: ((Bool) -> Void)?

    // Backoff & gating
    private var interstitialLoadAttempt: Int = 0
    private var rewardedLoadAttempt: Int = 0
    private let maxBackoff: TimeInterval = 64
    let interstitialMinInterval: TimeInterval = 120  // Made accessible for Policy extension
    var lastInterstitialShow: Date?  // Made accessible for Policy extension
    private var pendingRewardedPresentation: Bool = false

    // Published state exposed so GameViewModel can observe it
    @Published private(set) var isRewardedAdAvailable: Bool = false
    @Published private(set) var isShowingAd: Bool = false
    @Published var adRewardPending: Bool = false
    @Published private(set) var isLoadingRewarded: Bool = false
    @Published var adsDisabled: Bool = false

    static let shared = AdManager()
    
    // MARK: - AdMob Configuration Based on Build
    private var interstitialUnitID: String {
        #if DEBUG
        // Google Test IDs for Debug builds
        return "ca-app-pub-3940256099942544/4411468910"  // Test Interstitial
        #else
        // Production IDs only for Release builds
        return "ca-app-pub-8632219809769416/4973114672"
        #endif
    }
    
    private var rewardedUnitID: String {
        #if DEBUG
        // Google Test IDs for Debug builds
        return "ca-app-pub-3940256099942544/1712485313"  // Test Rewarded
        #else
        // Production IDs only for Release builds
        return "ca-app-pub-8632219809769416/3896337730"
        #endif
    }
    
    // Test device IDs for additional safety in debug
    private var testDeviceIdentifiers: [String] {
        #if DEBUG
        // Simulators are automatically test devices in SDK 11.x
        // Add physical test device IDs here if needed
        // Look in console for: "To get test ads on this device, add it to the testDeviceIdentifiers"
        return []
        #else
        return []
        #endif
    }
    
    private override init() {
        super.init()
        
        #if DEBUG
        print("🔧 AdManager: Running in DEBUG mode with test ads")
        print("📱 Test Interstitial ID: \(interstitialUnitID)")
        print("📱 Test Rewarded ID: \(rewardedUnitID)")
        
        // Configure test devices
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testDeviceIdentifiers
        #else
        print("🚀 AdManager: Running in RELEASE mode with production ads")
        #endif
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    func preload() {
        loadInterstitial()
        loadRewarded()
    }
    
    func preloadAds() {
        preload()
    }

    func ensurePreloaded() {
        if interstitial == nil { loadInterstitial() }
        if rewarded == nil { loadRewarded() }
    }

    @objc private func appDidBecomeActive() {
        ensurePreloaded()
    }

    private func backoffDelay(forAttempt attempt: Int) -> TimeInterval {
        min(pow(2.0, Double(attempt)), maxBackoff)
    }

    private func loadInterstitial() {
        guard !adsDisabled else { return }
        
        let request = Request()
        InterstitialAd.load(with: interstitialUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let error = error {
                #if DEBUG
                print("⚠️ Debug: Interstitial load failed (expected with test ads): \(error)")
                #endif
                self.interstitial = nil
                self.interstitialLoadAttempt += 1
                let delay = self.backoffDelay(forAttempt: self.interstitialLoadAttempt)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in 
                    self?.loadInterstitial() 
                }
                return
            }
            
            #if DEBUG
            print("✅ Debug: Test interstitial loaded successfully")
            #endif
            
            self.interstitialLoadAttempt = 0
            self.interstitial = ad
            ad?.fullScreenContentDelegate = self
        }
    }

    private func loadRewarded() {
        guard !adsDisabled else { return }
        
        isLoadingRewarded = true
        isRewardedAdAvailable = false
        
        let request = Request()
        RewardedAd.load(with: rewardedUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let error = error {
                #if DEBUG
                print("⚠️ Debug: Rewarded load failed (expected with test ads): \(error)")
                #endif
                self.rewarded = nil
                self.isLoadingRewarded = false
                self.rewardedLoadAttempt += 1
                let delay = self.backoffDelay(forAttempt: self.rewardedLoadAttempt)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in 
                    self?.loadRewarded() 
                }
                return
            }
            
            #if DEBUG
            print("✅ Debug: Test rewarded ad loaded successfully")
            #endif
            
            self.rewardedLoadAttempt = 0
            self.rewarded = ad
            ad?.fullScreenContentDelegate = self
            self.isLoadingRewarded = false
            self.isRewardedAdAvailable = (ad != nil)

            // If the UI asked to show as soon as ready, present now.
            if self.pendingRewardedPresentation, let ad = ad, let vc = Self.topViewController() {
                self.pendingRewardedPresentation = false
                self.isShowingRewarded = true
                self.isShowingAd = true
                self.isRewardedAdAvailable = false
                ad.present(from: vc) { [weak self] in
                    guard let self else { return }
                    self.isShowingRewarded = false
                    self.adRewardPending = true
                    self.rewardCompletion?(true)
                    self.rewardCompletion = nil
                }
            }
        }
    }

    // MARK: - AdServiceProtocol conformance
    var isInterstitialReady: Bool {
        return interstitial != nil && !adsDisabled
    }
    
    var canShowAds: Bool {
        return !adsDisabled
    }
    
    func showInterstitial(completion: @escaping (Bool) -> Void) {
        guard !adsDisabled else {
            completion(false)
            return
        }
        guard !isShowingInterstitial else {
            completion(false)
            return
        }
        
        // Frequency cap
        let now = Date()
        if let last = lastInterstitialShow, now.timeIntervalSince(last) < interstitialMinInterval {
            #if DEBUG
            print("⏰ Debug: Interstitial frequency cap active, skipping")
            #endif
            completion(false)
            return
        }
        
        guard let ad = interstitial, let vc = Self.topViewController() else {
            loadInterstitial()
            completion(false)
            return
        }
        
        #if DEBUG
        print("📺 Debug: Showing test interstitial ad")
        #endif
        
        isShowingAd = true
        isShowingInterstitial = true
        lastInterstitialShow = now
        AnalyticsManager.shared.logAdImpression(adType: "interstitial")
        DispatchQueue.main.async {
            ad.present(from: vc)
            completion(true)
        }
    }
    
    func showInterstitialAd() {
        guard !adsDisabled else { return }
        guard !isShowingInterstitial else { return }
        
        // Frequency cap
        let now = Date()
        if let last = lastInterstitialShow, now.timeIntervalSince(last) < interstitialMinInterval { 
            #if DEBUG
            print("⏰ Debug: Interstitial frequency cap active, skipping")
            #endif
            return 
        }
        
        guard let ad = interstitial, let vc = Self.topViewController() else {
            loadInterstitial()
            return
        }
        
        #if DEBUG
        print("📺 Debug: Showing test interstitial ad")
        #endif
        
        isShowingAd = true
        isShowingInterstitial = true
        lastInterstitialShow = now
        AnalyticsManager.shared.logAdImpression(adType: "interstitial")
        DispatchQueue.main.async { ad.present(from: vc) }
    }

    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        guard !adsDisabled else { 
            completion(false)
            return 
        }
        
        if let ad = rewarded, let vc = Self.topViewController() {
            #if DEBUG
            print("🎁 Debug: Showing test rewarded ad")
            #endif
            
            isShowingRewarded = true
            isShowingAd = true
            isRewardedAdAvailable = false     // consuming the loaded ad
            rewardCompletion = completion
            AnalyticsManager.shared.logAdImpression(adType: "rewarded")
            DispatchQueue.main.async {
                ad.present(from: vc) { [weak self] in
                    guard let self else { return }
                    self.isShowingRewarded = false
                    self.adRewardPending = true
                    self.rewardCompletion?(true)
                    self.rewardCompletion = nil
                }
            }
        } else {
            #if DEBUG
            print("⏳ Debug: Queueing rewarded ad presentation")
            #endif
            // Queue a presentation when the next rewarded ad finishes loading.
            pendingRewardedPresentation = true
            rewardCompletion = completion
            isShowingAd = true // reflects "Loading Ad…" in UI
            loadRewarded()
        }
    }

    @MainActor
    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        // Compute the starting controller on the main actor
        let starting: UIViewController? = {
            if let base = base { return base }
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                if let win = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    return win.rootViewController
                }
            }
            return nil
        }()

        if let nav = starting as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = starting as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = starting?.presentedViewController {
            return topViewController(base: presented)
        }
        return starting
    }
}

// MARK: - FullScreenContentDelegate
extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if ad === interstitial {
            #if DEBUG
            print("✅ Debug: Interstitial dismissed, loading next")
            #endif
            interstitial = nil
            isShowingAd = false
            isShowingInterstitial = false
            loadInterstitial()
        }
        if ad === rewarded {
            #if DEBUG
            print("✅ Debug: Rewarded ad dismissed, loading next")
            #endif
            rewarded = nil
            // If a reward wasn't granted (completion still pending), resolve as false.
            if let completion = rewardCompletion {
                completion(false)
                rewardCompletion = nil
            }
            isShowingAd = false
            isShowingRewarded = false
            loadRewarded()
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("❌ Debug: Ad failed to present: \(error)")
        #endif
        
        if ad === interstitial {
            interstitial = nil
            loadInterstitial()
            isShowingInterstitial = false
        }
        if ad === rewarded {
            rewarded = nil
            loadRewarded()
            isShowingRewarded = false
            isShowingAd = false
            rewardCompletion?(false)
            rewardCompletion = nil
        }
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        // Optional: Track clicks
    }
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        // Optional: Track impressions
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Optional: Handle will present
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Optional: Handle will dismiss
    }
}

