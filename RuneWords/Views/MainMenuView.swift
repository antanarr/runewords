//
//  MainMenuView.swift
//  RuneWords
//
//  Main menu screen with navigation to all game features

import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var storeVM: StoreViewModel
    @EnvironmentObject private var appState: AppState
    @State private var coins: Int = PlayerService.shared.player?.coins ?? 0
    @State private var navigateToGame = false
    @State private var navigateToStore = false
    @State private var navigateToRealms = false
    @State private var navigateToDaily = false
    @State private var navigateToSettings = false
    @State private var currentLevel = 1
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // FIXED: Proper gradient background instead of missing image
                backgroundView
                    .ignoresSafeArea()
                
                // Content
                VStack(spacing: 0) {
                    // Header with title and player info
                    headerView
                        .padding(.top, 60)
                        .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Main menu buttons
                    menuContent
                        .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                    
                    // Bottom bar with settings
                    bottomBar
                        .padding(.bottom, 30)
                }
            }
            .onAppear {
                coins = PlayerService.shared.player?.coins ?? 0
                currentLevel = PlayerService.shared.player?.currentLevelID ?? 1
                AdManager.shared.ensurePreloaded()
                Log.ui("Main menu appeared")
            }
            .onReceive(NotificationCenter.default.publisher(for: .storeGrantCoins)) { _ in
                coins = PlayerService.shared.player?.coins ?? 0
            }
            .navigationDestination(isPresented: $navigateToGame) {
                GameView()
                    .navigationBarHidden(true)
            }
            .navigationDestination(isPresented: $navigateToRealms) {
                RealmProgressView()
                    .navigationBarHidden(true)
            }
            .navigationDestination(isPresented: $navigateToStore) {
                StoreView()
                    .navigationBarHidden(true)
            }
            .navigationDestination(isPresented: $navigateToDaily) {
                DailyChallengeView()
                    .navigationBarHidden(true)
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView()
                    .navigationBarHidden(true)
            }
        }
        .navigationBarHidden(true)
        .alert("Start Fresh?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Start Fresh", role: .destructive) {
                resetProgress()
            }
        } message: {
            Text("This will reset your progress to Level 1. Your coins and purchases will be kept.")
        }
    }
    
    // MARK: - Background View - FIXED
    private var backgroundView: some View {
        ZStack {
            // FIXED: Beautiful gradient background that actually works
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.11, blue: 0.2),  // Dark blue-purple
                    Color(red: 0.06, green: 0.06, blue: 0.12), // Darker blue
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle animated overlay for depth
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.clear
                ],
                center: .top,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
        }
    }
    
    // MARK: - Header View - FIXED
    private var headerView: some View {
        VStack(spacing: 20) {
            // Title - More prominent
            Text("RUNEWORDS")
                .font(.custom("Cinzel-Bold", size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 0.8, green: 0.8, blue: 1.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .purple.opacity(0.3), radius: 10, y: 4)
                .shadow(color: .black, radius: 2, y: 2)
            
            // Player info bar - More visible
            HStack(spacing: 20) {
                // Coins - FIXED with system icon
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.yellow)
                    Text("\(coins)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Level indicator - More visible
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.yellow)
                    Text("Level \(currentLevel)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Menu Content - COMPLETELY FIXED
    private var menuContent: some View {
        VStack(spacing: 16) {
            // Primary play button - HIGHLY VISIBLE
            Button(action: { navigateToGame = true }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentLevel == 1 ? "Start Playing" : "Continue")
                            .font(.custom("Cinzel-Bold", size: 22))
                            .foregroundStyle(.white)
                        Text(currentLevel == 1 ? "Begin Tutorial" : "Level \(currentLevel)")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.5, green: 0.4, blue: 0.9),  // Bright purple
                            Color(red: 0.4, green: 0.3, blue: 0.8)   // Darker purple
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(LocalScaleButtonStyle())
            
            // Secondary buttons - HIGH CONTRAST FIX
            
            // Daily Challenge
            Button(action: { navigateToDaily = true }) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Daily Challenge")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            if !DailyChallengeService.shared.isCompletedToday(player: PlayerService.shared.player) {
                                Text("NEW")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(.red))
                            }
                        }
                        
                        Text(dailyChallengeSubtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.25, green: 0.25, blue: 0.35)) // Visible background
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(LocalScaleButtonStyle())
            
            // Store
            Button(action: { navigateToStore = true }) {
                HStack {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.yellow)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Store")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Get coins & power-ups")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Coin indicator
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.yellow)
                        Text("+")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.yellow.opacity(0.2)))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.25, green: 0.25, blue: 0.35)) // Visible background
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.yellow.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(LocalScaleButtonStyle())
            
            // Watch Ad for Coins - if ads available
            if !storeVM.hasRemoveAds && AdManager.shared.isRewardedAdAvailable {
                Button(action: { showRewardedAd() }) {
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Watch Ad")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Get 25 free coins")
                                .font(.system(size: 12))
                                .foregroundStyle(.green.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("25")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.green.opacity(0.2)))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                    RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.2, green: 0.35, blue: 0.25)) // Visible green-tinted background
                    .overlay(
                    RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.green.opacity(0.6), lineWidth: 1)
                    )
                    )
                }
                .buttonStyle(LocalScaleButtonStyle())
            }
        }
    }
    
    // MARK: - Bottom Bar - FIXED VISIBILITY
    private var bottomBar: some View {
        HStack(spacing: 40) {
            // Settings
            Button(action: { navigateToSettings = true }) {
                VStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                    Text("Settings")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .buttonStyle(LocalScaleButtonStyle(scale: 0.9))
            
            // Leaderboard
            Button(action: { showLeaderboard() }) {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                    Text("Leaderboard")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .buttonStyle(LocalScaleButtonStyle(scale: 0.9))
            
            // Achievements
            Button(action: { showAchievements() }) {
                VStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                    Text("Achievements")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .buttonStyle(LocalScaleButtonStyle(scale: 0.9))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 32)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Computed Properties
    private var dailyChallengeSubtitle: String {
        if DailyChallengeService.shared.isCompletedToday(player: PlayerService.shared.player) {
            return "Completed today! ✓"
        } else {
            return "New puzzle every day"
        }
    }
    
    // MARK: - Actions
    private func resetProgress() {
        Log.game("Player reset progress from level \(currentLevel)")
        if var player = PlayerService.shared.player {
            player.currentLevelID = 1
            player.levelProgress.removeAll()
            PlayerService.shared.player = player
            PlayerService.shared.saveProgress(player: player.toPlayerData())
        }
        navigateToGame = true
    }
    
    private func showRewardedAd() {
        Log.ads("Showing rewarded ad from main menu")
        AdManager.shared.showRewardedAd { success in
            if success {
                if var player = PlayerService.shared.player {
                    player.coins += 25
                    PlayerService.shared.player = player
                    PlayerService.shared.saveProgress(player: player.toPlayerData())
                    coins = player.coins
                    HapticManager.shared.play(.success)
                    Log.ads("Rewarded ad completed, granted 25 coins")
                }
            }
        }
    }
    
    private func showLeaderboard() {
        GameCenterService.shared.showLeaderboard()
    }
    
    private func showAchievements() {
        GameCenterService.shared.showAchievements()
    }
}

// MARK: - Local Scale Button Style (renamed to avoid conflict)
struct LocalScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    MainMenuView()
        .environmentObject(StoreViewModel.shared)
        .environmentObject(AppState.shared)
}
