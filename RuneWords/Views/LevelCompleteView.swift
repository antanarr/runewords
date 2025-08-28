//
//  LevelCompleteView.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/27/25.
//

import Foundation
import SwiftUI

struct LevelCompleteView: View {
    let coinsEarned: Int
    let onContinue: () -> Void
    
    @State private var showParticles = false
    @State private var animateTitle = false
    @State private var animateStar = false
    @State private var showCoinBurst = false
    @EnvironmentObject private var audioManager: AudioManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if showParticles && !reduceMotion {
                // Simple confetti effect
                Canvas { context, size in
                    for _ in 0..<50 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let color = [Color.yellow, .orange, .white].randomElement()!
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 6, height: 6)),
                            with: .color(color)
                        )
                    }
                }
                .ignoresSafeArea()
            }
            if showCoinBurst && !reduceMotion {
                CoinBurstOverlayView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            VStack(spacing: 20) {
                Text("Level Complete!")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.yellow)
                    .scaleEffect(animateTitle ? 1.06 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: animateTitle)
                
                Image(systemName: "star.circle.fill")
                    .resizable()
                    .frame(width: 110, height: 110)
                    .foregroundColor(.orange)
                    .rotationEffect(.degrees(animateStar ? 4 : 0))
                    .shadow(color: .yellow.opacity(0.6), radius: 12)
                    .animation(.easeInOut(duration: 0.45).repeatCount(1, autoreverses: true), value: animateStar)
                
                HStack(spacing: 8) {
                    Image("icon_coin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("+\(coinsEarned)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .scaleEffect(showCoinBurst ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCoinBurst)
                
                Button(action: {
                    HapticManager.shared.play(.light)
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(Color.black.opacity(0.80))
            .cornerRadius(16)
            .shadow(radius: 14)
        }
        .onAppear {
            audioManager.playSound(effect: .levelComplete)
            HapticManager.shared.play(.success)
            animateTitle = true
            animateStar = true
            if !reduceMotion {
                showParticles = true
                showCoinBurst = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showParticles = false
                    showCoinBurst = false
                }
            }
        }
    }
}

private struct CoinBurstOverlayView: View {
    var body: some View {
        Canvas { context, size in
            let colors: [Color] = [.yellow, .orange, .white]
            let count = 48
            for i in 0..<count {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let r = CGFloat.random(in: 6...14)
                let color = colors[i % colors.count]
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.9)))
                context.stroke(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.7)), lineWidth: 0.8)
            }
        }
    }
}

struct LevelCompleteView_Previews: PreviewProvider {
    static var previews: some View {
        LevelCompleteView(coinsEarned: 25, onContinue: {})
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
    }
}
