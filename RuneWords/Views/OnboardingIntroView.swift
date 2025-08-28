// OnboardingIntroView.swift - Single Onboarding Flow
// Removes duplicate onboarding, keeps only the clean intro

import SwiftUI

// MARK: - Single Onboarding Flow
struct OnboardingIntroView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var dragOffset: CGSize = .zero
    
    let pages = [
        OnboardingPage(
            title: "Welcome to RuneWords",
            subtitle: "Discover hidden words in mystical realms",
            imageName: "sparkles",
            color: Color(red: 0.557, green: 0.553, blue: 0.8),
            description: "Swipe letters to form words and unlock the secrets of ancient runes"
        ),
        OnboardingPage(
            title: "How to Play",
            subtitle: "Connect letters to create words",
            imageName: "hand.draw",
            color: .blue,
            description: "Drag your finger across letters to spell words. Find all the hidden words to complete each level!"
        ),
        OnboardingPage(
            title: "Magical Hints",
            subtitle: "Use power-ups when stuck",
            imageName: "wand.and.stars",
            color: .purple,
            description: "• Clarity reveals random letters\n• Precision targets specific words\n• Momentum gives multiple hints\n• Revelation shows entire words"
        ),
        OnboardingPage(
            title: "Explore Four Realms",
            subtitle: "Journey through mystical worlds",
            imageName: "map.fill",
            color: .green,
            description: "Progress through increasingly challenging realms, from the peaceful Tree Library to the mysterious Astral Peak"
        ),
        OnboardingPage(
            title: "Ready to Begin?",
            subtitle: "Your adventure awaits",
            imageName: "play.circle.fill",
            color: .orange,
            description: "Start with simple 3-letter words and progress to challenging 6-letter puzzles!"
        )
    ]
    
    var body: some View {
        ZStack {
            // Dynamic background
            LinearGradient(
                colors: [
                    pages[currentPage].color.opacity(0.6),
                    pages[currentPage].color.opacity(0.2),
                    Color.black.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack(spacing: 0) {
                // Skip button (top right)
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            HapticManager.shared.play(.light)
                            completeOnboarding()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                    }
                }
                .padding(.top, 10)
                
                // Content pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
                
                // Bottom navigation
                VStack(spacing: 24) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: currentPage == index ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 20) {
                        // Previous button
                        if currentPage > 0 {
                            Button {
                                HapticManager.shared.play(.light)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentPage -= 1
                                }
                            } label: {
                                Image(systemName: "arrow.left.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                        
                        // Next/Start button
                        Button {
                            HapticManager.shared.play(.light)
                            if currentPage < pages.count - 1 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentPage += 1
                                }
                            } else {
                                completeOnboarding()
                            }
                        } label: {
                            if currentPage == pages.count - 1 {
                                Text("Start Playing")
                                    .font(.custom("Cinzel-Bold", size: 18))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [pages[currentPage].color, pages[currentPage].color.opacity(0.7)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                                    .shadow(color: pages[currentPage].color.opacity(0.4), radius: 10)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if value.translation.width < -threshold && currentPage < pages.count - 1 {
                            currentPage += 1
                            HapticManager.shared.play(.light)
                        } else if value.translation.width > threshold && currentPage > 0 {
                            currentPage -= 1
                            HapticManager.shared.play(.light)
                        }
                        dragOffset = .zero
                    }
                }
        )
    }
    
    private func completeOnboarding() {
        HapticManager.shared.play(.medium)
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
        
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        // Note: Don't set hasCompletedTutorial here - let the game handle that
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let color: Color
    let description: String
}

// MARK: - Individual Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var imageScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0
    @State private var iconRotation: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated icon
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.color.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 15)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, page.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(imageScale)
                    .rotationEffect(.degrees(iconRotation))
                    .shadow(color: page.color.opacity(0.3), radius: 15)
            }
            
            // Text content
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.custom("Cinzel-Bold", size: 28))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(page.subtitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                
                Text(page.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(textOpacity)
            
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                imageScale = 1.0
                iconRotation = 10
            }
            withAnimation(.easeIn(duration: 0.8).delay(0.2)) {
                textOpacity = 1.0
            }
            
            // Subtle continuous animation
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                iconRotation = -10
            }
        }
    }
}

// MARK: - Preview
#Preview("Onboarding") {
    OnboardingIntroView(isPresented: .constant(true))
        .preferredColorScheme(.dark)
}