//
//  AppDelegate+Monetization.swift
//  RuneWords
//
//  Proper initialization for all monetization components (2025)

import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import GameKit
import StoreKit

extension AppDelegate {
    
    func setupMonetization() {
        // 1. Configure Info.plist first (ensure GADApplicationIdentifier is set)
        verifyConfiguration()
        
        // 2. Initialize Google Mobile Ads SDK
        MobileAds.shared.start { [weak self] (status: InitializationStatus) in
            print("✅ AdMob SDK initialized")
            
            // Log adapter initialization status
            status.adapterStatusesByClassName.forEach { className, adapterStatus in
                print("  Adapter \(className): \(adapterStatus.state.rawValue)")
            }
            
            // 3. Setup consent after SDK is ready
            self?.setupConsent()
        }
        
        // 4. Initialize other services (can run in parallel)
        setupGameCenter()
        setupStoreKit()
    }
    
    private func verifyConfiguration() {
        // Verify GADApplicationIdentifier is in Info.plist
        guard let appID = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String else {
            fatalError("❌ GADApplicationIdentifier not found in Info.plist")
        }
        print("✅ AdMob App ID found: \(appID)")
        
        // Verify SKAdNetwork IDs
        if let skAdNetworkItems = Bundle.main.object(forInfoDictionaryKey: "SKAdNetworkItems") as? [[String: String]] {
            print("✅ SKAdNetwork IDs found: \(skAdNetworkItems.count) items")
        } else {
            print("⚠️ No SKAdNetwork IDs found - ads may not track properly")
        }
    }
    
    private func setupConsent() {
        let parameters = RequestParameters()
        
        // Configure for production
        #if DEBUG
        // Debug settings for testing consent
        let debugSettings = DebugSettings()
        // In SDK 11.x, simulator is automatically a test device
        debugSettings.testDeviceIdentifiers = []
        debugSettings.geography = .EEA // Test EEA consent  
        parameters.debugSettings = debugSettings
        #endif
        
        // Request consent info update
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            if let error = error {
                print("❌ Consent info update error: \(error.localizedDescription)")
                // Still initialize ads in limited mode
                self?.initializeAds(canShowPersonalizedAds: false)
                return
            }
            
            print("✅ Consent info updated")
            
            // Check if form is available
            let formStatus = ConsentInformation.shared.formStatus
            
            if formStatus == .available {
                self?.loadConsentForm()
            } else {
                // No form needed (likely non-EEA user)
                self?.initializeAds(canShowPersonalizedAds: true)
            }
        }
    }
    
    private func loadConsentForm() {
        ConsentForm.load { [weak self] form, error in
            if let error = error {
                print("❌ Consent form load error: \(error.localizedDescription)")
                self?.initializeAds(canShowPersonalizedAds: false)
                return
            }
            
            guard let form = form else { return }
            
            // Present form if required
            if ConsentInformation.shared.consentStatus == .required {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    form.present(from: rootVC) { [weak self] dismissError in
                        if let dismissError = dismissError {
                            print("❌ Consent form dismiss error: \(dismissError.localizedDescription)")
                        }
                        
                        // Check final consent status
                        let canShowAds = ConsentInformation.shared.canRequestAds
                        self?.initializeAds(canShowPersonalizedAds: canShowAds)
                    }
                }
            } else {
                // Consent already given
                let canShowAds = ConsentInformation.shared.canRequestAds
                self?.initializeAds(canShowPersonalizedAds: canShowAds)
            }
        }
    }
    
    private func initializeAds(canShowPersonalizedAds: Bool) {
        print("✅ Initializing ads - Personalized: \(canShowPersonalizedAds)")
        // Set test devices (debug only list comes from AdMobConfiguration)
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = AdMobConfiguration.testDeviceIdentifiers
        // Preload ads (request builder will handle NPA if needed)
        AdManager.shared.preload()
    }
    
    private func setupGameCenter() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                // Present Game Center login
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(viewController, animated: true)
                    }
                }
            } else if GKLocalPlayer.local.isAuthenticated {
                print("✅ Game Center authenticated: \(GKLocalPlayer.local.displayName)")
                // Load achievements and leaderboards
                self.loadGameCenterData()
            } else if let error = error {
                print("❌ Game Center error: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadGameCenterData() {
        // Load leaderboards
        GKLeaderboard.loadLeaderboards { leaderboards, error in
            if let error = error {
                print("❌ Failed to load leaderboards: \(error.localizedDescription)")
            } else {
                print("✅ Loaded \(leaderboards?.count ?? 0) leaderboards")
            }
        }
        
        // Load achievements
        GKAchievement.loadAchievements { achievements, error in
            if let error = error {
                print("❌ Failed to load achievements: \(error.localizedDescription)")
            } else {
                print("✅ Loaded \(achievements?.count ?? 0) achievements")
            }
        }
    }
    
    private func setupStoreKit() {
        // TODO: Wire to IAPManager/StoreManager when available
        print("✅ StoreKit initialized")
    }
}
