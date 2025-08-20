// PauseMenuView.swift - In-Game Pause Menu System
// RuneWords

import SwiftUI

struct PauseMenuView: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeVM: StoreViewModel
    
    // Navigation states
    @State private var navigateToMainMenu = false
    @State private var showRestartConfirmation = false
    @State private var showExitConfirmation = false
    @State private var showSettings = false
    
    // Game state from parent
    let currentLevel: Int
    let wordsFound: Int
    let totalWords: Int
    let onRestart: () -> Void
    let onExitToMenu: () -> Void
    
    var body: some View {
        ZStack {
            // Background blur (handled by parent)
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Resume on background tap
                    isPresented = false
                }
            
            VStack(spacing: 0) {
                // Header
                pauseHeader
                    .padding(.bottom, 24)
                
                // Level Progress
                levelProgressCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                // Menu Options
                VStack(spacing: 12) {
                    // Resume Button (Primary)
                    PauseMenuButton(
                        title: "Resume",
                        icon: "play.circle.fill",
                        style: .primary,
                        action: { isPresented = false }
                    )
                    
                    // Restart Level
                    PauseMenuButton(
                        title: "Restart Level",
                        icon: "arrow.counterclockwise",
                        style: .secondary,
                        action: { showRestartConfirmation = true }
                    )
                    
                    // Settings
                    PauseMenuButton(
                        title: "Settings",
                        icon: "gearshape.fill",
                        style: .secondary,
                        action: { showSettings = true }
                    )
                    
                    // Main Menu
                    PauseMenuButton(
                        title: "Main Menu",
                        icon: "house.fill",
                        style: .destructive,
                        action: { showExitConfirmation = true }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
            .frame(maxWidth: 380)
            .padding(.vertical, 40)
        }
        .confirmationDialog(
            "Restart Level?",
            isPresented: $showRestartConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restart", role: .destructive) {
                onRestart()
                isPresented = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current progress will be lost.")
        }
        .confirmationDialog(
            "Exit to Main Menu?",
            isPresented: $showExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Exit", role: .destructive) {
                isPresented = false  // Close pause menu first
                // Small delay to let the pause menu close before triggering exit
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onExitToMenu()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress will be saved.")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Components
    
    private var pauseHeader: some View {
        VStack(spacing: 8) {
            // Pause Icon
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .fixedCircleShadow(color: .black.opacity(0.3), blur: 4, y: 2)
            
            Text("Game Paused")
                .font(.custom("Cinzel-Bold", size: 32))
                .foregroundStyle(.white)
                .fixedCircleShadow(color: .black.opacity(0.3), blur: 2, y: 1, cornerRadius: 4)
        }
    }
    
    private var levelProgressCard: some View {
        VStack(spacing: 12) {
            // Level indicator
            HStack {
                Text("Level \(currentLevel)")
                    .font(.custom("Cinzel-Bold", size: 18))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Progress percentage
                let progress = totalWords > 0 ? Int((Double(wordsFound) / Double(totalWords)) * 100) : 0
                Text("\(progress)%")
                    .font(.custom("Cinzel-Bold", size: 18))
                    .foregroundStyle(.yellow)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.2))
                    
                    // Progress
                    if totalWords > 0 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(wordsFound) / CGFloat(totalWords))
                    }
                }
            }
            .frame(height: 12)
            
            // Words found
            HStack {
                Image(systemName: "text.word.spacing")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                
                Text("Words Found: \(wordsFound) / \(totalWords)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.3))
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Button Component
struct PauseMenuButton: View {
    let title: String
    let icon: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary, destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return Color(red: 0.557, green: 0.553, blue: 0.8)
            case .secondary:
                return Color.white.opacity(0.15)
            case .destructive:
                return Color.red.opacity(0.2)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary:
                return .white
            case .secondary:
                return .white.opacity(0.9)
            case .destructive:
                return Color(red: 1.0, green: 0.7, blue: 0.7)
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary:
                return Color(red: 0.657, green: 0.653, blue: 0.9)
            case .secondary:
                return Color.white.opacity(0.3)
            case .destructive:
                return Color.red.opacity(0.4)
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                
                Text(title)
                    .font(.custom("Cinzel-Bold", size: 18))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.6)
            }
            .foregroundStyle(style.foregroundColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(style.backgroundColor)
                    .strokeBorder(style.borderColor, lineWidth: 1)
            )
            .fixedCircleShadow(color: .black.opacity(0.2), blur: 4, y: 2, cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Pause Menu") {
    ZStack {
        Color.purple.opacity(0.3)
            .ignoresSafeArea()
        
        PauseMenuView(
            isPresented: .constant(true),
            currentLevel: 42,
            wordsFound: 8,
            totalWords: 12,
            onRestart: {},
            onExitToMenu: {}
        )
        .environmentObject(StoreViewModel.shared)
    }
}
