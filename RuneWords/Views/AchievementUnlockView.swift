//
//  AchievementUnlockView.swift
//  RuneWords
//
//  Achievement unlock notification with slide-in animation
//

import SwiftUI

struct AchievementUnlockView: View {
    let achievement: Achievement
    @State private var slideOffset: CGFloat = -500
    @State private var glowOpacity: Double = 0
    @State private var scaleEffect: CGFloat = 0.8
    
    var body: some View {
        VStack {
            // Achievement card
            HStack(spacing: 16) {
                // Icon with rarity glow
                ZStack {
                    Circle()
                        .fill(achievement.rarity.color.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(achievement.rarity.color, lineWidth: 2)
                                .opacity(glowOpacity)
                        )
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(achievement.rarity.color)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievement Unlocked!")
                        .font(.custom("Cinzel-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(achievement.title)
                        .font(.custom("Cinzel-Bold", size: 18))
                        .foregroundColor(.white)
                    
                    Text(achievement.description)
                        .font(.custom("Cinzel-Regular", size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Rarity badge
                Text(achievement.rarity.rawValue.capitalized)
                    .font(.custom("Cinzel-Bold", size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(achievement.rarity.color.opacity(0.8))
                    .clipShape(Capsule())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(achievement.rarity.color, lineWidth: 2)
                    )
            )
            .scaleEffect(scaleEffect)
            .offset(y: slideOffset)
            
            Spacer()
        }
        .onAppear {
            animateSlideIn()
        }
    }
    
    private func animateSlideIn() {
        // Play sound
        HapticManager.shared.play(.success)
        
        // Slide in animation
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
            slideOffset = 20
            scaleEffect = 1.0
        }
        
        // Glow effect
        withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
            glowOpacity = 1.0
        }
        
        // Auto hide after 3.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeIn(duration: 0.5)) {
                slideOffset = -500
                glowOpacity = 0
            }
        }
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        
        AchievementUnlockView(
            achievement: Achievement(
                title: "First Steps",
                description: "Complete your first level",
                icon: "star.fill",
                rarity: .common,
                requirement: 1
            )
        )
    }
}