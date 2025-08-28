//
//  DeepLinkRouter.swift
//  RuneWords
//
//  Handles deep links from widgets and other sources
//

import SwiftUI

enum DeepLink: Equatable {
    case daily
    case level(Int)
    case realm(String)
    case store
    case settings
    
    init?(url: URL) {
        guard url.scheme == "runewords" else { return nil }
        
        switch url.host {
        case "daily":
            self = .daily
        case "level":
            if let levelStr = url.pathComponents.last,
               let levelNum = Int(levelStr) {
                self = .level(levelNum)
            } else {
                return nil
            }
        case "realm":
            if let realmName = url.pathComponents.last {
                self = .realm(realmName)
            } else {
                return nil
            }
        case "store":
            self = .store
        case "settings":
            self = .settings
        default:
            return nil
        }
    }
}

@MainActor
class DeepLinkRouter: ObservableObject {
    @Published var pendingDeepLink: DeepLink?
    
    func handle(_ url: URL) {
        guard let deepLink = DeepLink(url: url) else {
            Log.warning("Invalid deep link URL: \(url)")
            return
        }
        
        Log.info("Handling deep link: \(deepLink)")
        pendingDeepLink = deepLink
    }
    
    func navigate(to deepLink: DeepLink, using appState: AppState) {
        switch deepLink {
        case .daily:
            // Navigate to daily challenge
            appState.currentScreen = .dailyChallenge
            
        case .level(_):
            // Navigate to specific level
            appState.currentScreen = .game
            // You would also need to pass the level number to GameViewModel
            
        case .realm(_):
            // Navigate to realm map with specific realm
            appState.currentScreen = .realmMap
            // You would pass the realm name to RealmMapViewModel
            
        case .store:
            // Navigate to store
            appState.currentScreen = .store
            
        case .settings:
            // Navigate to settings
            appState.currentScreen = .settings
        }
        
        // Clear pending deep link after navigation
        pendingDeepLink = nil
    }
    
    func processPendingDeepLink(using appState: AppState) {
        if let pending = pendingDeepLink {
            navigate(to: pending, using: appState)
        }
    }
}

// MARK: - View Modifier for Deep Link Handling

struct DeepLinkHandler: ViewModifier {
    @StateObject private var router = DeepLinkRouter()
    @EnvironmentObject var appState: AppState
    
    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                router.handle(url)
            }
            .onChange(of: router.pendingDeepLink) { oldValue, newValue in
                let deepLink = newValue
                if deepLink != nil {
                    router.processPendingDeepLink(using: appState)
                }
            }
            .environmentObject(router)
    }
}

extension View {
    func handleDeepLinks() -> some View {
        modifier(DeepLinkHandler())
    }
}
