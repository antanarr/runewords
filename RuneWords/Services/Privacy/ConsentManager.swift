//
//  ConsentManager.swift
//  RuneWords
//
//  Manages Google User Messaging Platform (UMP) consent flow for GDPR/CCPA compliance

import Foundation
import UserMessagingPlatform
import GoogleMobileAds
import UIKit

/// Manages user consent for ads and data collection
@MainActor
final class ConsentManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = ConsentManager()
    private override init() {
        super.init()
    }
    
    // MARK: - Published Properties
    @Published private(set) var consentStatus: ConsentStatus = .unknown
    @Published private(set) var isConsentFormAvailable = false
    @Published private(set) var isProcessingConsent = false
    @Published private(set) var canShowAds = false
    @Published private(set) var hasCompletedConsent = false
    
    // MARK: - Private Properties
    private var consentInformation: ConsentInformation {
        ConsentInformation.shared
    }
    
    private var pendingConsentCompletion: ((Bool) -> Void)?
    
    // MARK: - Consent State Keys
    private struct ConsentKeys {
        static let hasRequestedConsent = "Consent.hasRequested"
        static let lastConsentCheck = "Consent.lastCheck"
        static let consentVersion = "Consent.version"
    }
    
    // MARK: - Public Methods
    
    /// Request consent on app launch
    func requestConsentOnLaunch(completion: @escaping (Bool) -> Void) {
        Log.info("Requesting consent status", category: Log.ads)
        
        isProcessingConsent = true
        pendingConsentCompletion = completion
        
        // Create request parameters
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false // Set to true if targeting children
        
        // Configure debug settings for testing
        #if DEBUG
        configureDebugSettings(for: parameters)
        #endif
        
        consentInformation.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.handleConsentError(error)
                    return
                }
                
                self.handleConsentInfoUpdate()
            }
        }
    }
    
    /// Check if consent is required
    func isConsentRequired() -> Bool {
        return consentInformation.consentStatus == .required
    }
    
    /// Check if user is in EEA or UK
    func isInPrivacyRegion() -> Bool {
        // This is determined by UMP SDK based on user location
        return consentInformation.consentStatus != .notRequired
    }
    
    /// Manually show consent form (for settings)
    func showConsentForm(from viewController: UIViewController? = nil, completion: @escaping (Bool) -> Void) {
        guard isConsentFormAvailable else {
            Log.warning("Consent form not available", category: Log.ads)
            completion(false)
            return
        }
        
        ConsentForm.loadAndPresentIfRequired(from: viewController ?? topViewController()) { [weak self] error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    Log.error("Failed to present consent form", error: error, category: Log.ads)
                    completion(false)
                } else {
                    self.updateConsentStatus()
                    completion(true)
                }
            }
        }
    }
    
    /// Reset consent (for testing or user request)
    func resetConsent() {
        Log.info("Resetting consent", category: Log.ads)
        consentInformation.reset()
        
        // Clear stored consent data
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: ConsentKeys.hasRequestedConsent)
        defaults.removeObject(forKey: ConsentKeys.lastConsentCheck)
        defaults.removeObject(forKey: ConsentKeys.consentVersion)
        
        // Reset published properties
        consentStatus = .unknown
        isConsentFormAvailable = false
        canShowAds = false
        hasCompletedConsent = false
        
        Log.info("Consent reset complete", category: Log.ads)
    }
    
    /// Check if ads can be shown based on consent
    func canRequestAds() -> Bool {
        // Can request ads if:
        // 1. Consent not required (non-EEA/UK users)
        // 2. Consent obtained
        // 3. Limited ads allowed (user opted out of personalization)
        return consentInformation.canRequestAds
    }
    
    // MARK: - Private Methods
    
    private func handleConsentInfoUpdate() {
        consentStatus = consentInformation.consentStatus
        isConsentFormAvailable = consentInformation.formStatus == .available
        
        Log.info("Consent status: \(consentStatusString), Form available: \(isConsentFormAvailable)", category: Log.ads)
        
        // Record that we've requested consent
        UserDefaults.standard.set(true, forKey: ConsentKeys.hasRequestedConsent)
        UserDefaults.standard.set(Date(), forKey: ConsentKeys.lastConsentCheck)
        
        // Check if we need to show the consent form
        if isConsentFormAvailable && consentStatus == .required {
            loadAndShowConsentForm()
        } else {
            // No consent form needed or already obtained
            finalizeConsentProcess()
        }
    }
    
    private func loadAndShowConsentForm() {
        Log.info("Loading consent form", category: Log.ads)
        
        ConsentForm.loadAndPresentIfRequired(from: topViewController()) { [weak self] error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.handleConsentError(error)
                } else {
                    self.handleConsentFormDismissal()
                }
            }
        }
    }
    
    private func handleConsentFormDismissal() {
        Log.info("Consent form dismissed", category: Log.ads)
        updateConsentStatus()
        finalizeConsentProcess()
    }
    
    private func handleConsentError(_ error: Error) {
        Log.error("Consent error occurred", error: error, category: Log.ads)
        
        isProcessingConsent = false
        
        // In case of error, we should still allow the app to function
        // but without personalized ads
        canShowAds = false
        
        // Notify completion
        pendingConsentCompletion?(false)
        pendingConsentCompletion = nil
        
        // Retry consent after delay if needed
        if consentStatus == .required {
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                requestConsentOnLaunch { _ in }
            }
        }
    }
    
    private func updateConsentStatus() {
        consentStatus = consentInformation.consentStatus
        canShowAds = consentInformation.canRequestAds
        hasCompletedConsent = consentStatus == .obtained || consentStatus == .notRequired
        
        Log.info("Updated consent - Status: \(consentStatusString), Can show ads: \(canShowAds)", category: Log.ads)
    }
    
    private func finalizeConsentProcess() {
        updateConsentStatus()
        isProcessingConsent = false
        
        // Initialize Ad SDK ONLY after consent is obtained or not required
        if canShowAds {
            Log.info("Initializing Ad SDK after consent obtained", category: Log.ads)
            
            // Configure and start MobileAds SDK
            MobileAds.shared.start { _ in
                Log.info("Ad SDK initialized successfully", category: Log.ads)
            }
            
            // Configure global ad settings
            let config = MobileAds.shared.requestConfiguration
            config.maxAdContentRating = GADMaxAdContentRating.general
            config.tagForChildDirectedTreatment = false
            config.tagForUnderAgeOfConsent = false
            
            // Now preload ads
            AdManager.shared.preload()
        } else {
            Log.info("Ad SDK not initialized - consent not obtained", category: Log.ads)
            AdManager.shared.adsDisabled = true
        }
        
        // Check ATT status after UMP
        Task {
            await ATTManager.requestIfNeeded()
            Log.info("ATT authorization complete", category: Log.ads)
        }
        
        // Notify completion
        pendingConsentCompletion?(canShowAds)
        pendingConsentCompletion = nil
        
        Log.info("Consent process complete - Can show ads: \(canShowAds)", category: Log.ads)
    }
    
    private var consentStatusString: String {
        switch consentStatus {
        case .unknown:
            return "Unknown"
        case .required:
            return "Required"
        case .notRequired:
            return "Not Required"
        case .obtained:
            return "Obtained"
        @unknown default:
            return "Unknown Status"
        }
    }
    
    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        return findTopViewController(from: rootViewController)
    }
    
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return findTopViewController(from: presented)
        }
        
        if let navigation = viewController as? UINavigationController,
           let visible = navigation.visibleViewController {
            return findTopViewController(from: visible)
        }
        
        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return findTopViewController(from: selected)
        }
        
        return viewController
    }
    
    // MARK: - Debug Configuration
    
    #if DEBUG
    private func configureDebugSettings(for parameters: RequestParameters) {
        let debugSettings = DebugSettings()
        
        // Force geography for testing (EEA for GDPR testing)
        debugSettings.geography = .EEA
        
        // Add test device IDs
        debugSettings.testDeviceIdentifiers = [
            "YOUR_TEST_DEVICE_ID", // Add your device ID here
            // You can find this in the console logs when running the app
        ]
        
        // Attach debug settings to the parameters
        parameters.debugSettings = debugSettings
        
        Log.debug("Configured UMP debug settings for EEA testing", category: Log.ads)
    }
    #endif
}

// MARK: - App Integration

extension ConsentManager {
    
    /// Initialize consent on app launch
    static func initializeOnAppLaunch(completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            shared.requestConsentOnLaunch { canShowAds in
                Log.info("Consent initialization complete - Can show ads: \(canShowAds)", category: Log.ads)
                completion(canShowAds)
            }
        }
    }
    
    /// Check if consent needs refresh (e.g., after app becomes active)
    static func checkConsentStatus() {
        let defaults = UserDefaults.standard
        
        // Check if we should refresh consent (e.g., once per day)
        if let lastCheck = defaults.object(forKey: ConsentKeys.lastConsentCheck) as? Date {
            let hoursSinceCheck = Date().timeIntervalSince(lastCheck) / 3600
            
            if hoursSinceCheck > 24 {
                // Refresh consent status
                Task { @MainActor in
                    shared.requestConsentOnLaunch { _ in }
                }
            }
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct ConsentAwareModifier: ViewModifier {
    @ObservedObject private var consentManager = ConsentManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if consentManager.isProcessingConsent {
                        ConsentProcessingOverlay()
                    }
                }
            )
    }
}

struct ConsentProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Setting up your experience...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

extension View {
    /// Apply consent-aware overlay
    func consentAware() -> some View {
        self.modifier(ConsentAwareModifier())
    }
}
