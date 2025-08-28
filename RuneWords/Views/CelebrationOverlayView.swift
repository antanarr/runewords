//
//  CelebrationOverlayView.swift
//  RuneWords
//
//  Level completion celebration overlay with particle effects
//

import SwiftUI

struct CelebrationOverlayView: View {
    @EnvironmentObject private var audioManager: AudioManager
    @State private var showFireworks = false
    @State private var showStars = false
    @State private var textScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background with celebration colors
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            .purple.opacity(0.3),
                            .blue.opacity(0.2),
                            .clear
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 300
                    )
                )
                .ignoresSafeArea()
            
            // Particle effects
            if showFireworks {
                ForEach(0..<12, id: \.self) { index in
                    ParticleEmitterView(
                        position: CGPoint(
                            x: CGFloat.random(in: 50...350),
                            y: CGFloat.random(in: 100...600)
                        ),
                        particleCount: 8,
                        colors: [.yellow, .orange, .purple, .blue],
                        duration: 1.5
                    )
                }
            }
            
            // Celebration text
            VStack(spacing: 24) {
                Text("🎉 Level Complete! 🎉")
                    .font(.custom("Cinzel-Bold", size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(textScale)
                    .opacity(textOpacity)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                
                if showStars {
                    HStack(spacing: 16) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.yellow)
                                .opacity(0.8)
                                .scaleEffect(1.2)
                                .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1), value: showStars)
                        }
                    }
                }
            }
        }
        .onAppear {
            playAudio()
            animateCelebration()
        }
    }
    
    private func playAudio() {
        audioManager.playSound(effect: .levelComplete)
    }
    
    private func animateCelebration() {
        // Text animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            textScale = 1.0
            textOpacity = 1.0
        }
        
        // Show stars after text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                showStars = true
            }
        }
        
        // Show fireworks after stars
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showFireworks = true
        }
        
        // Auto dismiss after celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                textOpacity = 0
                showFireworks = false
            }
        }
    }
}

#Preview {
    CelebrationOverlayView()
        .environmentObject(AudioManager.shared)
}