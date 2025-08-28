import SwiftUI
import Foundation
import Combine

// MARK: - Core Particle System Components Only
// Dedicated to particle effects that don't have separate files

struct ParticleEmitterView: View {
    let position: CGPoint
    let particleCount: Int
    let colors: [Color]
    let duration: Double
    @State private var particles: [Particle] = []
    @State private var isAnimating = false
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var color: Color
        var size: CGFloat
        var opacity: Double
        var rotation: Double
    }
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                ParticleView(particle: particle, isAnimating: isAnimating)
            }
        }
        .onAppear {
            createParticles()
            withAnimation(.linear(duration: duration)) {
                isAnimating = true
            }
            
            // Clean up after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                particles.removeAll()
            }
        }
    }
    
    private func createParticles() {
        for _ in 0..<particleCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let velocity = CGFloat.random(in: 100...300)
            
            particles.append(
                Particle(
                    position: position,
                    velocity: CGVector(
                        dx: CGFloat(cos(angle)) * velocity,
                        dy: CGFloat(sin(angle)) * velocity
                    ),
                    color: colors.randomElement() ?? .yellow,
                    size: CGFloat.random(in: 4...12),
                    opacity: 1.0,
                    rotation: Double.random(in: 0...360)
                )
            )
        }
    }
}

struct ParticleView: View {
    let particle: ParticleEmitterView.Particle
    let isAnimating: Bool
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: particle.size))
            .foregroundColor(particle.color)
            .rotationEffect(.degrees(particle.rotation))
            .position(
                x: isAnimating ? particle.position.x + particle.velocity.dx : particle.position.x,
                y: isAnimating ? particle.position.y + particle.velocity.dy : particle.position.y
            )
            .opacity(isAnimating ? 0 : particle.opacity)
            .scaleEffect(isAnimating ? 0.1 : 1.0)
    }
}

// MARK: - Coin Burst Effect
struct CoinBurstView: View {
    let startPosition: CGPoint
    let endPosition: CGPoint
    let coinCount: Int
    @State private var coins: [CoinParticle] = []
    @State private var phase = 0
    
    struct CoinParticle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var controlPoint: CGPoint
        var rotation: Double
    }
    
    var body: some View {
        ZStack {
            ForEach(coins) { coin in
                CoinAnimationView(
                    coin: coin,
                    endPosition: endPosition,
                    phase: phase
                )
            }
        }
        .onAppear {
            createCoins()
            animateCoins()
        }
    }
    
    private func createCoins() {
        for i in 0..<coinCount {
            let spreadAngle = Double(i) / Double(coinCount) * .pi * 2
            let spreadRadius = CGFloat.random(in: 30...80)
            
            coins.append(
                CoinParticle(
                    position: startPosition,
                    controlPoint: CGPoint(
                        x: startPosition.x + CGFloat(cos(spreadAngle)) * spreadRadius,
                        y: startPosition.y + CGFloat(sin(spreadAngle)) * spreadRadius - 50
                    ),
                    rotation: Double.random(in: 0...360)
                )
            )
        }
    }
    
    private func animateCoins() {
        // Phase 1: Burst outward
        withAnimation(.easeOut(duration: 0.3)) {
            phase = 1
        }
        
        // Phase 2: Converge to target
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.5)) {
                phase = 2
            }
        }
        
        // Phase 3: Disappear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                phase = 3
            }
        }
    }
}

struct CoinAnimationView: View {
    let coin: CoinBurstView.CoinParticle
    let endPosition: CGPoint
    let phase: Int
    
    private var currentPosition: CGPoint {
        switch phase {
        case 0: return coin.position
        case 1: return coin.controlPoint
        case 2, 3: return endPosition
        default: return coin.position
        }
    }
    
    private var opacity: Double {
        phase == 3 ? 0 : 1
    }
    
    private var scale: CGFloat {
        switch phase {
        case 0: return 0.5
        case 1: return 1.2
        case 2: return 1.0
        case 3: return 0.3
        default: return 1.0
        }
    }
    
    var body: some View {
        Image("icon_coin")
            .resizable()
            .frame(width: 24, height: 24)
            .rotationEffect(.degrees(coin.rotation + Double(phase) * 180))
            .scaleEffect(scale)
            .position(currentPosition)
            .opacity(opacity)
    }
}

// MARK: - Supporting Particle Effects (No external dependencies)

struct RippleEffectView: View {
    let position: CGPoint
    let color: Color
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: 100, height: 100)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(position)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    scale = 2.0
                    opacity = 0
                }
            }
    }
}

struct LetterCascadeView: View {
    let letters: [Character]
    let startDelay: Double
    @State private var visibleLetters: [Bool] = []
    @State private var glowEffects: [Bool] = []
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                ZStack {
                    // Background glow
                    if glowEffects.indices.contains(index) && glowEffects[index] {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.yellow.opacity(0.6), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 0.5).repeatCount(2, autoreverses: true), value: glowEffects[index])
                    }
                    
                    // Letter with enhanced animations
                    Text(String(letter))
                        .font(.custom("Cinzel-Bold", size: 32))
                        .fontWeight(.heavy)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .yellow],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .yellow.opacity(0.8), radius: 4, x: 0, y: 2)
                        .scaleEffect(visibleLetters.indices.contains(index) && visibleLetters[index] ? 1.0 : 0.1)
                        .opacity(visibleLetters.indices.contains(index) && visibleLetters[index] ? 1.0 : 0)
                        .rotationEffect(.degrees(visibleLetters.indices.contains(index) && visibleLetters[index] ? 0 : 180))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.5)
                            .delay(startDelay + Double(index) * 0.08),
                            value: visibleLetters.indices.contains(index) ? visibleLetters[index] : false
                        )
                }
            }
        }
        .onAppear {
            visibleLetters = Array(repeating: false, count: letters.count)
            glowEffects = Array(repeating: false, count: letters.count)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
                for i in letters.indices {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                        visibleLetters[i] = true
                        
                        // Trigger glow effect after letter appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            glowEffects[i] = true
                            
                            // Remove glow after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                glowEffects[i] = false
                            }
                        }
                    }
                }
            }
        }
    }
}

struct LetterPopEffect: View {
    let letter: Character
    let position: CGPoint
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = -30
    @State private var opacity: Double = 0
    
    var body: some View {
        Text(String(letter))
            .font(.custom("Cinzel-Bold", size: 48))
            .fontWeight(.heavy)
            .foregroundStyle(
                LinearGradient(
                    colors: [.yellow, .orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .yellow.opacity(0.8), radius: 8, x: 0, y: 4)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .position(position)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
                    scale = 1.2
                    rotation = 0
                    opacity = 1.0
                }
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.3)) {
                    scale = 1.0
                }
                
                withAnimation(.easeOut(duration: 0.5).delay(1.5)) {
                    opacity = 0
                    scale = 0.5
                }
            }
    }
}

struct WordFormationView: View {
    let word: String
    let startPosition: CGPoint
    let endPosition: CGPoint
    @State private var progress: Double = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .font(.custom("Cinzel-Bold", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 36, height: 36)
                    )
                    .scaleEffect(progress >= Double(index) / Double(word.count) ? 1.0 : 0.5)
                    .opacity(progress >= Double(index) / Double(word.count) ? 1.0 : 0.3)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6)
                        .delay(Double(index) * 0.1),
                        value: progress
                    )
            }
        }
        .position(
            x: startPosition.x + (endPosition.x - startPosition.x) * progress,
            y: startPosition.y + (endPosition.y - startPosition.y) * progress
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                progress = 1.0
            }
        }
    }
}

// MARK: - View Modifiers and Extensions

struct GlowEffect: ViewModifier {
    let color: Color
    let intensity: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .blur(radius: 5)
                    .opacity(intensity)
                    .blendMode(.plusLighter)
            )
            .shadow(color: color, radius: 10 * intensity)
    }
}

extension View {
    func glow(color: Color, intensity: Double) -> some View {
        modifier(GlowEffect(color: color, intensity: intensity))
    }
}

struct FloatingEffect: ViewModifier {
    @State private var offset: CGFloat = 0
    let amplitude: CGFloat
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    offset = amplitude
                }
            }
    }
}

extension View {
    func floating(amplitude: CGFloat = 10, duration: Double = 2) -> some View {
        modifier(FloatingEffect(amplitude: amplitude, duration: duration))
    }
}

struct EnhancedShakeEffect: ViewModifier {
    @State private var offset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    let intensity: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.1).repeatCount(isActive ? 6 : 0, autoreverses: true), value: isActive)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    // Shake horizontally
                    withAnimation(.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true)) {
                        offset = intensity
                    }
                    
                    // Slight rotation shake
                    withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                        rotation = 2
                    }
                    
                    // Scale pulse
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scale = 1.1
                    }
                    
                    // Reset after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        offset = 0
                        rotation = 0
                        scale = 1.0
                    }
                }
            }
    }
}

extension View {
    func enhancedShake(intensity: CGFloat = 10, isActive: Bool) -> some View {
        modifier(EnhancedShakeEffect(intensity: intensity, isActive: isActive))
    }
}
