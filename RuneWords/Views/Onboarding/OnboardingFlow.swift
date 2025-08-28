//
//  OnboardingFlow.swift
//  RuneWords
//
//  3-step interactive FTUE onboarding experience
//

import SwiftUI

// MARK: - Onboarding Flow Container
struct OnboardingFlow: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentPage = 0
    @State private var showSkipConfirmation = false
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            // Content
            VStack {
                // Progress indicator
                progressIndicator
                    .padding(.top, 50)
                    .padding(.horizontal)
                
                // Page content
                TabView(selection: $currentPage) {
                    OnboardingPageOne()
                        .tag(0)
                    
                    OnboardingPageTwo()
                        .tag(1)
                    
                    OnboardingPageThree()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Bottom navigation
                bottomNavigation
                    .padding(.horizontal)
                    .padding(.bottom, 30)
            }
        }
        .alert("Skip Tutorial?", isPresented: $showSkipConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Skip", role: .destructive) {
                completeOnboarding()
            }
        } message: {
            Text("You can always view the tutorial again from Settings.")
        }
    }
    
    // MARK: - Components
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.2, green: 0.15, blue: 0.3),
                Color(red: 0.15, green: 0.1, blue: 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index <= currentPage ? Color.yellow : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }
    
    private var bottomNavigation: some View {
        HStack {
            // Skip button
            Button(action: { showSkipConfirmation = true }) {
                Text("Skip")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .opacity(currentPage < 2 ? 1 : 0)
            
            Spacer()
            
            // Next/Get Started button
            Button(action: handleNextAction) {
                Text(currentPage < 2 ? "Next" : "Get Started")
                    .font(.custom("Cinzel-Bold", size: 18))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: currentPage < 2 ? 
                                [Color.blue.opacity(0.8), Color.blue.opacity(0.6)] :
                                [Color.green, Color.green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: currentPage < 2 ? .blue.opacity(0.3) : .green.opacity(0.3), radius: 8)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Actions
    private func handleNextAction() {
        if currentPage < 2 {
            withAnimation(.spring()) {
                currentPage += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        // Complete intro phase and advance to coach-marks
        appState.completeIntro()
        
        // Navigate to main menu (coach-marks will show when entering game)
        withAnimation(.easeInOut(duration: 0.5)) {
            appState.navigate(to: .mainMenu)
        }
        
        Log.ui("Intro onboarding completed, advancing to coach-marks phase")
    }
}

// MARK: - Page One: Welcome & Core Gameplay
struct OnboardingPageOne: View {
    @State private var animateTitle = false
    @State private var animateContent = false
    @State private var floatingLetters: [FloatingLetter] = []
    
    struct FloatingLetter: Identifiable {
        let id = UUID()
        let letter: String
        let startPosition: CGPoint
        var currentPosition: CGPoint
        let targetPosition: CGPoint
        let delay: Double
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Title with animation
            VStack(spacing: 16) {
                Text("Welcome to")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(animateTitle ? 1 : 0)
                    .offset(y: animateTitle ? 0 : 20)
                
                Text("RUNEWORDS")
                    .font(.custom("Cinzel-Bold", size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .yellow.opacity(0.3), radius: 10)
                    .scaleEffect(animateTitle ? 1 : 0.8)
                    .opacity(animateTitle ? 1 : 0)
            }
            
            // Interactive letter demo
            ZStack {
                // Letter wheel visualization
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 200, height: 200)
                    .opacity(animateContent ? 1 : 0)
                
                // Animated letters
                ForEach(floatingLetters) { letter in
                    Text(letter.letter)
                        .font(.custom("Cinzel-Bold", size: 32))
                        .foregroundColor(.white)
                        .position(letter.currentPosition)
                }
                
                // Center word formation
                if animateContent {
                    Text("MAGIC")
                        .font(.custom("Cinzel-Bold", size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 300, height: 250)
            
            // Description
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)
                    .opacity(animateContent ? 1 : 0)
                    .rotationEffect(.degrees(animateContent ? 0 : -180))
                
                Text("Discover Hidden Words")
                    .font(.custom("Cinzel-Bold", size: 22))
                    .foregroundColor(.white)
                    .opacity(animateContent ? 1 : 0)
                
                Text("Connect letters to form words and unlock the magic within ancient runes")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(animateContent ? 1 : 0)
            }
            
            Spacer()
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Animate title
        withAnimation(.easeOut(duration: 0.8)) {
            animateTitle = true
        }
        
        // Animate content
        withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
            animateContent = true
        }
        
        // Setup floating letters
        setupFloatingLetters()
        
        // Animate letters to form word
        for (index, _) in floatingLetters.enumerated() {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.0 + Double(index) * 0.1)) {
                floatingLetters[index].currentPosition = floatingLetters[index].targetPosition
            }
        }
    }
    
    private func setupFloatingLetters() {
        let letters = ["M", "A", "G", "I", "C"]
        let centerX = CGFloat(150)
        let centerY = CGFloat(125)
        let radius: CGFloat = 80
        
        for (index, letter) in letters.enumerated() {
            let angle = (CGFloat(index) / CGFloat(letters.count)) * 2 * .pi - .pi / 2
            let startX = centerX + radius * cos(angle)
            let startY = centerY + radius * sin(angle)
            let targetX = centerX + CGFloat(index - 2) * 35
            
            floatingLetters.append(
                FloatingLetter(
                    letter: letter,
                    startPosition: CGPoint(x: startX, y: startY),
                    currentPosition: CGPoint(x: startX, y: startY),
                    targetPosition: CGPoint(x: targetX, y: centerY),
                    delay: Double(index) * 0.1
                )
            )
        }
    }
}

// MARK: - Page Two: Daily Challenge & Progression
struct OnboardingPageTwo: View {
    @State private var animateContent = false
    @State private var showRealmProgress = false
    @State private var currentRealm = 0
    
    let realms = [
        ("Tree Library", Color.green, "tree.fill"),
        ("Crystal Forest", Color.blue, "sparkles"),
        ("Sleeping Titan", Color.orange, "flame.fill"),
        ("Astral Peak", Color.pink, "star.circle.fill")
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Title
            VStack(spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateContent ? 1 : 0)
                    .rotationEffect(.degrees(animateContent ? 0 : -90))
                
                Text("Epic Journey Awaits")
                    .font(.custom("Cinzel-Bold", size: 28))
                    .foregroundColor(.white)
                    .opacity(animateContent ? 1 : 0)
            }
            
            // Realm showcase
            VStack(spacing: 20) {
                // Realm cards
                HStack(spacing: 15) {
                    ForEach(0..<4) { index in
                        OnboardingRealmCard(
                            name: realms[index].0,
                            color: realms[index].1,
                            icon: realms[index].2,
                            isActive: index == currentRealm,
                            isUnlocked: index <= currentRealm
                        )
                        .scaleEffect(showRealmProgress ? 1 : 0.8)
                        .opacity(showRealmProgress ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(Double(index) * 0.1), value: showRealmProgress)
                    }
                }
                
                // Progress indicator
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        
                        // Progress bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [realms[currentRealm].1, realms[min(currentRealm + 1, 3)].1],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(currentRealm + 1) / 4, height: 8)
                            .animation(.spring(), value: currentRealm)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 20)
                .opacity(showRealmProgress ? 1 : 0)
            }
            .padding(.horizontal, 20)
            
            // Daily Challenge feature
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Challenges")
                            .font(.custom("Cinzel-Bold", size: 20))
                            .foregroundColor(.white)
                        
                        Text("New puzzles every day!")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Reward preview
                    HStack(spacing: 4) {
                        Image("icon_coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("+50")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.yellow.opacity(0.2)))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .scaleEffect(animateContent ? 1 : 0.9)
                .opacity(animateContent ? 1 : 0)
            }
            .padding(.horizontal, 20)
            
            // Description
            Text("Journey through mystical realms, complete daily challenges, and become a word master!")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(animateContent ? 1 : 0)
            
            Spacer()
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateContent = true
        }
        
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            showRealmProgress = true
        }
        
        // Cycle through realms
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.spring()) {
                currentRealm = (currentRealm + 1) % 4
            }
        }
    }
}

// MARK: - Page Three: Power-ups & Store
struct OnboardingPageThree: View {
    @State private var animateContent = false
    @State private var selectedPowerUp = 0
    @State private var pulseAnimation = false
    
    let powerUps = [
        ("Hint", "lightbulb.fill", Color.yellow, "Reveals the first letter of an unfound word"),
        ("Shuffle", "shuffle", Color.blue, "Rearrange letters for a fresh perspective"),
        ("Revelation", "eye.fill", Color.purple, "Instantly reveals a complete word")
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Title
            VStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .shadow(color: .yellow.opacity(0.5), radius: 10)
                
                Text("Power-Ups & Rewards")
                    .font(.custom("Cinzel-Bold", size: 28))
                    .foregroundColor(.white)
                    .opacity(animateContent ? 1 : 0)
            }
            
            // Power-up showcase
            VStack(spacing: 20) {
                // Power-up selector
                HStack(spacing: 20) {
                    ForEach(0..<3) { index in
                        PowerUpIcon(
                            icon: powerUps[index].1,
                            color: powerUps[index].2,
                            isSelected: index == selectedPowerUp,
                            onTap: { selectedPowerUp = index }
                        )
                        .scaleEffect(animateContent ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(Double(index) * 0.1), value: animateContent)
                    }
                }
                
                // Description of selected power-up
                VStack(spacing: 8) {
                    Text(powerUps[selectedPowerUp].0)
                        .font(.custom("Cinzel-Bold", size: 20))
                        .foregroundColor(powerUps[selectedPowerUp].2)
                    
                    Text(powerUps[selectedPowerUp].3)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(height: 40)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(powerUps[selectedPowerUp].2.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(powerUps[selectedPowerUp].2.opacity(0.3), lineWidth: 1)
                        )
                )
                .animation(.spring(), value: selectedPowerUp)
            }
            .padding(.horizontal, 30)
            .opacity(animateContent ? 1 : 0)
            
            // Plus membership preview
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                    
                    Text("RuneWords Plus")
                        .font(.custom("Cinzel-Bold", size: 20))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Premium")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.yellow.opacity(0.2)))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "infinity", text: "Unlimited hints")
                    FeatureRow(icon: "gift.fill", text: "Daily bonus coins")
                    FeatureRow(icon: "nosign", text: "Remove all ads")
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.2), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            colors: [.yellow.opacity(0.5), .orange.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .padding(.horizontal, 20)
            .scaleEffect(animateContent ? 1 : 0.9)
            .opacity(animateContent ? 1 : 0)
            
            // Final message
            Text("Ready to begin your word adventure?")
                .font(.custom("Cinzel-Bold", size: 18))
                .foregroundColor(.white)
                .opacity(animateContent ? 1 : 0)
            
            Spacer()
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateContent = true
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }
}

// MARK: - Supporting Components

struct OnboardingRealmCard: View {
    let name: String
    let color: Color
    let icon: String
    let isActive: Bool
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isUnlocked ? color : .gray)
            
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isUnlocked ? .white : .gray)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .frame(width: 85, height: 75)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? color.opacity(0.3) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? color : Color.clear, lineWidth: 2)
                )
        )
    }
}

struct PowerUpIcon: View {
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(isSelected ? .white : color)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(isSelected ? color : Color.white.opacity(0.1))
                        .overlay(
                            Circle()
                                .stroke(color, lineWidth: isSelected ? 0 : 2)
                        )
                )
                .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 8)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.yellow)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

// ScaleButtonStyle now defined globally in Theme.swift

// MARK: - Legacy View Model (WO-002: Removed in favor of AppState FTUE management)

#Preview {
    OnboardingFlow()
        .environmentObject(AppState.shared)
}
