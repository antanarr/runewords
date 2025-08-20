// ContentView.swift - Fixed Onboarding & Loading
// Removes duplicate onboarding and adds proper loading screen

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeVM: StoreViewModel
    @State private var contentReady = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                Group {
                    if !contentReady {
                        // Loading screen with app icon
                        LoadingScreenView()
                    } else {
                        // Route based on FTUE state and app state
                        switch (appState.ftueState, appState.currentScreen) {
                        case (.intro, _):
                            // First-time user - show onboarding
                            OnboardingFlow()
                        case (_, .game):
                            // Game view (coach-marks will show if needed)
                            GameView()
                        case (_, .store):
                            StoreView()
                        case (_, .settings):
                            SettingsView()
                        case (_, .realmMap):
                            RealmProgressView()
                        case (_, .dailyChallenge):
                            DailyChallengeView()
                        default:
                            // Main menu for all other cases
                            MainMenuView()
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.black.opacity(0.2), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .onAppear {
                // Show loading briefly, then initialize app state
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        contentReady = true
                        
                        // Set initial screen based on FTUE state
                        if appState.ftueState.isCompleted {
                            appState.navigate(to: .mainMenu)
                            
                            // Request ATT after FTUE is complete
                            Task {
                                await ATTManager.requestIfNeeded()
                            }
                        }
                        // If ftue is .intro, OnboardingFlow will show automatically
                    }
                }
            }
        }
    }
}

// MARK: - Loading Screen with App Icon
struct LoadingScreenView: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var iconScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.02, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // App Icon
                ZStack {
                    // Glow effect - enhanced for electric theme
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.6), 
                                    Color(red: 0.8, green: 0.4, blue: 1.0).opacity(0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .blur(radius: 30)
                        .scaleEffect(iconScale)
                    
                    // Actual app icon - try multiple methods to load it
                    Group {
                        if let uiImage = UIImage(named: "appicon") {
                            // Direct reference to appicon.png
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .shadow(color: .purple.opacity(0.3), radius: 15)
                                .scaleEffect(iconScale)
                        } else {
                            // Fallback: Electric R logo matching the actual app icon
                            ZStack {
                                // Dark background with subtle gradient
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color(red: 0.05, green: 0.02, blue: 0.15),
                                                Color.black
                                            ],
                                            center: .center,
                                            startRadius: 10,
                                            endRadius: 80
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                // Electric R letter
                                ZStack {
                                    // Multiple glowing layers for electric effect
                                    ForEach(0..<3, id: \.self) { layer in
                                        Text("R")
                                            .font(.custom("Cinzel-Bold", size: 72))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        Color.purple.opacity(0.9),
                                                        Color(red: 0.8, green: 0.4, blue: 1.0),
                                                        Color.purple.opacity(0.7)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(
                                                color: Color.purple.opacity(0.8),
                                                radius: CGFloat(8 - layer * 2),
                                                x: 0,
                                                y: 0
                                            )
                                            .blur(radius: CGFloat(layer))
                                    }
                                    
                                    // Core sharp R
                                    Text("R")
                                        .font(.custom("Cinzel-Bold", size: 72))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color.white,
                                                    Color(red: 0.9, green: 0.7, blue: 1.0),
                                                    Color.purple.opacity(0.9)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: .white.opacity(0.5), radius: 1)
                                    
                                    // Electric sparkle accents with subtle animation
                                    ForEach(0..<8, id: \.self) { spark in
                                        Image(systemName: ["sparkles", "sparkle", "star.fill"][spark % 3])
                                            .font(.system(size: [6, 8, 4, 10, 5, 7, 9, 6][spark], weight: .bold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.white, .purple.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .offset(
                                                x: [25, -30, 20, -25, 30, -20, 15, -35][spark],
                                                y: [-35, -15, 25, 30, -25, 35, -40, 10][spark]
                                            )
                                            .opacity([0.8, 0.6, 0.9, 0.5, 0.7, 0.4, 0.8, 0.6][spark])
                                            .rotationEffect(.degrees(Double(spark) * 45))
                                    }
                                }
                            }
                            .scaleEffect(iconScale)
                            .shadow(color: .purple.opacity(0.6), radius: 20)
                        }
                    }
                }
                
                // Title
                VStack(spacing: 8) {
                    Text("RUNEWORDS")
                        .font(.custom("Cinzel-Bold", size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                    
                    Text("Word Puzzle Adventure")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                    .scaleEffect(1.2)
                    .padding(.top, 20)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1.0
                scale = 1.0
            }
            
            // Subtle pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                iconScale = 1.1
            }
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(StoreViewModel.shared)
}