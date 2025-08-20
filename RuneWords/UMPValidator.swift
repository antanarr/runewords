//
//  UMPValidator.swift
//  RuneWords
//
//  Quick validation that UMP SDK is properly integrated

import Foundation
import UserMessagingPlatform
import GoogleMobileAds

/// Add this class to your project and call validate() to confirm UMP is working
class UMPValidator {
    
    static func validate() {
        print("=" * 50)
        print("🔍 UMP SDK VALIDATION CHECK")
        print("=" * 50)
        
        // 1. Check if UMP SDK classes are available
        let consentInfo = ConsentInformation.shared
        print("✅ UMP SDK is integrated - UMPConsentInformation available")
        
        // 2. Check Google Mobile Ads SDK
        let gadVersion = string(for: MobileAds.shared.versionNumber)
        print("✅ Google Mobile Ads SDK version: \(gadVersion)")
        
        // 3. Check current consent status
        print("\n📊 Current Consent Status:")
        switch consentInfo.consentStatus {
        case .unknown:
            print("  • Status: Unknown (first time or reset)")
        case .required:
            print("  • Status: Required (user needs to give consent)")
        case .notRequired:
            print("  • Status: Not Required (not in privacy region)")
        case .obtained:
            print("  • Status: Obtained (user has given consent)")
        @unknown default:
            print("  • Status: Unknown new status")
        }
        
        // 4. Check form availability
        switch consentInfo.formStatus {
        case .unknown:
            print("  • Form: Unknown status")
        case .available:
            print("  • Form: Available (can be shown)")
        case .unavailable:
            print("  • Form: Unavailable")
        @unknown default:
            print("  • Form: Unknown new status")
        }
        
        // 5. Check if ads can be requested
        print("  • Can Request Ads: \(consentInfo.canRequestAds)")
        
        // 6. Check your App ID
        print("\n📱 AdMob Configuration:")
        if let appID = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String {
            print("  • App ID in Info.plist: \(appID)")
            
            if appID == "ca-app-pub-8632219809769416~2702174558" {
                print("  ✅ App ID matches your production ID")
            } else {
                print("  ⚠️ App ID doesn't match expected: ca-app-pub-8632219809769416~2702174558")
            }
        } else {
            print("  ❌ GADApplicationIdentifier not found in Info.plist")
        }
        
        // 7. Test making a consent request
        print("\n🔄 Testing Consent Request:")
        
        let parameters = RequestParameters()
        
        #if DEBUG
        // Force EEA for testing
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        print("  • Debug Mode: Simulating EEA location")
        #endif
        
        consentInfo.requestConsentInfoUpdate(with: parameters) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("\n❌ CONSENT ERROR:")
                    print("  Error: \(error.localizedDescription)")
                    
                    if error.localizedDescription.contains("publisher's account configuration") {
                        print("\n🚨 THE FIX:")
                        print("  1. Go to https://apps.admob.com")
                        print("  2. Select your app: ca-app-pub-8632219809769416~2702174558")
                        print("  3. Go to Privacy & messaging")
                        print("  4. Create and PUBLISH (not draft) GDPR and CCPA messages")
                        print("  5. Wait 5-10 minutes for propagation")
                    }
                } else {
                    print("\n✅ SUCCESS! Consent request completed")
                    print("  • Consent Status: \(self.statusString(consentInfo.consentStatus))")
                    print("  • Form Status: \(self.formStatusString(consentInfo.formStatus))")
                    print("  • Can Request Ads: \(consentInfo.canRequestAds)")
                    
                    if consentInfo.formStatus == .available {
                        print("\n📋 Consent form is available and ready to show!")
                    }
                }
                
                print("\n" + "=" * 50)
                print("VALIDATION COMPLETE")
                print("=" * 50)
            }
        }
    }
    
    private static func statusString(_ status: ConsentStatus) -> String {
        switch status {
        case .unknown: return "Unknown"
        case .required: return "Required"
        case .notRequired: return "Not Required"
        case .obtained: return "Obtained"
        @unknown default: return "New Status"
        }
    }
    
    private static func formStatusString(_ status: FormStatus) -> String {
        switch status {
        case .unknown: return "Unknown"
        case .available: return "Available"
        case .unavailable: return "Unavailable"
        @unknown default: return "New Status"
        }
    }
}

// MARK: - Easy Integration

extension AppDelegate {
    
    /// Call this to validate UMP setup
    func validateUMPSetup() {
        UMPValidator.validate()
    }
}

// Helper for string multiplication
fileprivate func *(left: String, right: Int) -> String {
    return String(repeating: left, count: right)
}
