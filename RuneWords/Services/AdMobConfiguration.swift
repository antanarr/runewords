//
//  AdMobConfiguration.swift
//  RuneWords
//
//  Centralized AdMob configuration with production IDs
//  Updated for Google Mobile Ads SDK 11.x (2025)

import Foundation
import GoogleMobileAds

struct AdMobConfiguration {
    // MARK: - AdMob App ID (already in Info.plist)
    static let appID = "ca-app-pub-8632219809769416~2702174558"
    
    // MARK: - Ad Unit IDs
    struct AdUnitIDs {
        #if DEBUG
        // Test IDs for development
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"  // Google test interstitial
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"      // Google test rewarded
        static let banner = "ca-app-pub-3940256099942544/2934735716"        // Google test banner
        #else
        // Production IDs - YOUR REAL MONEY MAKERS
        static let interstitial = "ca-app-pub-8632219809769416/4973114672"  // Your production interstitial
        static let rewarded = "ca-app-pub-8632219809769416/3896337730"      // Your production rewarded
        static let banner = "ca-app-pub-8632219809769416/YOUR_BANNER_ID"    // Add if you have banner ads
        #endif
    }
    
    // MARK: - Test Device IDs
    static var testDeviceIdentifiers: [String] {
    #if DEBUG
        // Add your physical test device IDs here when you see them in console
        // Example: ["abcdef012345678901234567890123456"]
        return []
    #else
        return []
    #endif
    }
    
    // MARK: - Initialization
    static func initialize(completion: @escaping (Bool) -> Void) {
        print("🚀 Initializing AdMob SDK with App ID: \(appID)")
        
        // Configure test devices if in debug
        #if DEBUG
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testDeviceIdentifiers
        print("📱 Running in DEBUG mode with test ads")
        print("📱 Test devices: \(testDeviceIdentifiers)")
        #else
        print("💰 Running in RELEASE mode with production ads")
        #endif
        
        // Start the Mobile Ads SDK
        MobileAds.shared.start { status in
            print("✅ AdMob SDK initialized")
            
            // Log adapter status
            for adapter in status.adapterStatusesByClassName {
                print("  Adapter: \(adapter.key) - State: \(adapter.value.state.rawValue)")
            }
            
            completion(true)
        }
    }
    
    // MARK: - Ad Request Builder (Updated for SDK 11.x)
    static func createAdRequest() -> Request {
        let request = Request()
        // Optional targeting:
        // request.keywords = ["game", "puzzle", "word"]
        return request
    }
}

// MARK: - Info.plist Validator
extension AdMobConfiguration {
    /// Validates that Info.plist has required AdMob configuration
    static func validateInfoPlist() -> Bool {
        guard let infoDictionary = Bundle.main.infoDictionary else {
            print("❌ Could not read Info.plist")
            return false
        }
        
        // Check GADApplicationIdentifier
        if let gadAppId = infoDictionary["GADApplicationIdentifier"] as? String {
            if gadAppId == appID {
                print("✅ GADApplicationIdentifier correctly set: \(gadAppId)")
            } else {
                print("⚠️ GADApplicationIdentifier mismatch. Expected: \(appID), Found: \(gadAppId)")
                return false
            }
        } else {
            print("❌ GADApplicationIdentifier missing from Info.plist")
            return false
        }
        
        // Check SKAdNetworkItems
        if let skAdNetworks = infoDictionary["SKAdNetworkItems"] as? [[String: Any]] {
            print("✅ SKAdNetworkItems found with \(skAdNetworks.count) identifiers")
            if skAdNetworks.count < 50 {
                print("⚠️ Only \(skAdNetworks.count) SKAdNetwork IDs found. Should have 60+")
            }
        } else {
            print("❌ SKAdNetworkItems missing from Info.plist")
            return false
        }
        
        // Check NSUserTrackingUsageDescription
        if let _ = infoDictionary["NSUserTrackingUsageDescription"] as? String {
            print("✅ NSUserTrackingUsageDescription present")
        } else {
            print("⚠️ NSUserTrackingUsageDescription missing (required for iOS 14.5+)")
        }
        
        return true
    }
}
