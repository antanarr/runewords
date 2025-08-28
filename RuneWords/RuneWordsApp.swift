import AVFoundation
import UIKit
import SwiftUI
import FirebaseCore
import GoogleMobileAds
import Combine
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

// This class will help us configure Firebase.
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // Configure App Check for simulator and debug builds - MUST be before configure()
    #if DEBUG && canImport(FirebaseAppCheck)
    print("🔐 Setting up App Check Debug Provider…")
    let providerFactory = AppCheckDebugProviderFactory()
    AppCheck.setAppCheckProviderFactory(providerFactory)
    print("✅ App Check Debug Provider configured")
    #endif
    
    print("🔥 Configuring Firebase...")
    FirebaseApp.configure()
    print("✅ Firebase configured")
    // DO NOT initialize Ad SDK here - wait for consent
    // MobileAds initialization moved to ConsentManager after UMP/ATT complete

    // Sign the user in (will be handled in the app's task)
    // Removed: AuthService.shared.signInAnonymously()

    // Initialize the PlayerService so it can listen for the user ID
    let _ = PlayerService.shared
    // Start observing StoreKit transactions on app launch
    IAPManager.shared.observeTransactions()
    Task { await GameCenterService.shared.authenticateIfNeeded() }

    // Prewarm haptics and audio session
    UIImpactFeedbackGenerator(style: .light).prepare()
    _ = AudioManager.shared
    // Initialize dictionary service (loading happens automatically)
    _ = DictionaryService.shared

    return true
  }
}

@main
struct RuneWordsApp: App {
  // register app delegate for Firebase setup
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var storeVM = StoreViewModel.shared
  @StateObject private var appState = AppState.shared
  @StateObject private var auth = AuthService.shared
  @StateObject private var progress = ProgressService.shared
  @StateObject private var audio = AudioManager.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(storeVM)
        .environmentObject(appState)
        .environmentObject(auth)
        .environmentObject(progress)
        .environmentObject(audio)
        .preferredColorScheme(.dark) // Force dark mode for consistent UI
        .task {
          // Ensure user is signed in anonymously
          await AuthService.shared.ensureSignedIn()
          
          // Set up player document and update last seen
          if let uid = AuthService.shared.uid {
            await ProgressService.shared.ensurePlayerDoc(uid: uid)
            await ProgressService.shared.touchLastSeen(uid: uid)
          }
        }
        .onAppear {
          // Request consent first, then initialize ads if allowed
          ConsentManager.initializeOnAppLaunch { canShowAds in
            Log.info("Consent complete, can show ads: \(canShowAds)", category: Log.ads)
            if canShowAds {
              AdManager.shared.ensurePreloaded()
            }
          }
          AdManager.shared.adsDisabled = storeVM.hasRemoveAds || storeVM.hasPlus
        }
        .onChange(of: storeVM.hasRemoveAds, initial: true) {
          AdManager.shared.adsDisabled = storeVM.hasRemoveAds || storeVM.hasPlus
        }
        .onChange(of: storeVM.hasPlus, initial: true) {
          AdManager.shared.adsDisabled = storeVM.hasRemoveAds || storeVM.hasPlus
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
          // Re-preload ads on foreground to keep Rewarded ready
          AdManager.shared.ensurePreloaded()
        }
    }
  }
}
