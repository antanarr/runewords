//
//  GameViewComponents.swift
//  RuneWords
//
//  Extracted components from GameView for better maintainability
//

import SwiftUI

// MARK: - Letter Wheel View
struct LetterWheelView: View {
    let letters: [Character]
    let selectedIndices: Set<Int>
    let onLetterTap: (Int, Character) -> Void
    let wheelRadius: CGFloat
    @State private var rotationAngle: Double = 0
    @State private var letterScales: [CGFloat]
    
    init(letters: [Character], 
         selectedIndices: Set<Int>, 
         onLetterTap: @escaping (Int, Character) -> Void,
         wheelRadius: CGFloat = 120) {
        self.letters = letters
        self.selectedIndices = selectedIndices
        self.onLetterTap = onLetterTap
        self.wheelRadius = wheelRadius
        self._letterScales = State(initialValue: Array(repeating: 1.0, count: letters.count))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Wheel background
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .frame(width: wheelRadius * 2, height: wheelRadius * 2)
                    .position(center)
                
                // Letter buttons
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    LetterButton(
                        letter: letter,
                        isSelected: selectedIndices.contains(index),
                        scale: letterScales[index],
                        position: letterPosition(for: index, center: center),
                        onTap: {
                            animateLetterTap(at: index)
                            onLetterTap(index, letter)
                        }
                    )
                }
            }
            .rotationEffect(.degrees(rotationAngle))
        }
    }
    
    private func letterPosition(for index: Int, center: CGPoint) -> CGPoint {
        let angle = (CGFloat(index) / CGFloat(letters.count)) * 2 * .pi - .pi / 2
        let x = center.x + wheelRadius * cos(angle)
        let y = center.y + wheelRadius * sin(angle)
        return CGPoint(x: x, y: y)
    }
    
    private func animateLetterTap(at index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            letterScales[index] = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                letterScales[index] = 1.0
            }
        }
    }
    
    func shuffle() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            rotationAngle += 360
        }
    }
}

// MARK: - Letter Button
struct LetterButton: View {
    let letter: Character
    let isSelected: Bool
    let scale: CGFloat
    let position: CGPoint
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(String(letter))
                .font(.custom("Cinzel-Bold", size: 28))
                .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            ) :
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.yellow : Color.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: isSelected ? .green.opacity(0.5) : .black.opacity(0.3), radius: 4)
                .scaleEffect(scale)
        }
        .position(position)
    }
}

// MARK: - Word Display View
struct WordDisplayView: View {
    let currentWord: String
    let isValid: Bool
    @State private var shake = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(currentWord.enumerated()), id: \.offset) { _, letter in
                Text(String(letter))
                    .font(.custom("Cinzel-Bold", size: 32))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: isValid ?
                                        [Color.green.opacity(0.8), Color.green.opacity(0.6)] :
                                        [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .modifier(ShakeEffect(animatableData: shake ? 1 : 0))
        .animation(.default, value: currentWord)
    }
    
    func triggerShake() {
        shake.toggle()
    }
}

// MARK: - HUD View
struct GameHUDView: View {
    let score: Int
    let coins: Int
    let level: Int
    let wordsFound: Int
    let totalWords: Int
    let hints: Int
    let revelations: Int
    let shuffles: Int
    let onPause: () -> Void
    
    var body: some View {
        VStack {
            // Top bar
            HStack {
                // Level indicator
                LevelBadge(level: level)
                
                Spacer()
                
                // Score
                ScoreBadge(score: score)
                
                Spacer()
                
                // Coins
                CoinsBadge(coins: coins)
                
                Spacer()
                
                // Pause button
                Button(action: onPause) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                }
            }
            .padding(.horizontal)
            
            // Progress bar
            ProgressBarView(
                current: wordsFound,
                total: totalWords,
                color: progressColor
            )
            .padding(.horizontal)
            
            // Power-ups bar
            HStack(spacing: 20) {
                PowerUpButton(
                    icon: "lightbulb.fill",
                    count: hints,
                    color: .yellow,
                    isInfinite: hints < 0
                )
                
                PowerUpButton(
                    icon: "eye.fill",
                    count: revelations,
                    color: .purple,
                    isInfinite: false
                )
                
                PowerUpButton(
                    icon: "shuffle",
                    count: shuffles,
                    color: .blue,
                    isInfinite: false
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var progressColor: Color {
        let progress = Float(wordsFound) / Float(max(totalWords, 1))
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .yellow }
        if progress >= 0.4 { return .orange }
        return .red
    }
}

// MARK: - Found Words Grid
struct FoundWordsGridView: View {
    let foundWords: [String]
    let solutions: [String: [Int]]
    @State private var animatedWords: Set<String> = []
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                ForEach(Array(solutions.keys.sorted()), id: \.self) { word in
                    WordTile(
                        word: word,
                        isFound: foundWords.contains(word),
                        isAnimating: animatedWords.contains(word)
                    )
                    .onAppear {
                        if foundWords.contains(word) && !animatedWords.contains(word) {
                            _ = animatedWords.insert(word)
                        }
                    }
                    .animation(.spring(), value: animatedWords)
                }
            }
            .padding()
        }
    }
}

// MARK: - Supporting Components

struct LevelBadge: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 14))
            Text("Level \(level)")
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.blue.opacity(0.8)))
    }
}

struct ScoreBadge: View {
    let score: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 14))
            Text("\(score)")
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.yellow)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.5)))
    }
}

struct CoinsBadge: View {
    let coins: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image("icon_coin")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text("\(coins)")
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.yellow)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.yellow.opacity(0.2)))
    }
}

struct ProgressBarView: View {
    let current: Int
    let total: Int
    let color: Color
    @State private var animatedProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 12)
                
                // Progress
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * animatedProgress, height: 12)
                
                // Text overlay
                HStack {
                    Spacer()
                    Text("\(current)/\(total)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
            }
        }
        .frame(height: 12)
        .onAppear {
            withAnimation(.spring()) {
                animatedProgress = CGFloat(current) / CGFloat(max(total, 1))
            }
        }
        .onChange(of: current) { _, _ in
            withAnimation(.spring()) {
                animatedProgress = CGFloat(current) / CGFloat(max(total, 1))
            }
        }
    }
}

struct PowerUpButton: View {
    let icon: String
    let count: Int
    let color: Color
    let isInfinite: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            if isInfinite {
                Image(systemName: "infinity")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            } else {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 50, height: 50)
        .background(
            Circle()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
        .opacity(count > 0 || isInfinite ? 1 : 0.5)
    }
}

struct WordTile: View {
    let word: String
    let isFound: Bool
    let isAnimating: Bool
    
    var body: some View {
        Text(isFound ? word : String(repeating: "?", count: word.count))
            .font(.custom("Cinzel-Bold", size: 16))
            .foregroundColor(isFound ? .white : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isFound ?
                        LinearGradient(
                            colors: [Color.green.opacity(0.8), Color.green.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .scaleEffect(isAnimating ? 1 : 0.8)
            .opacity(isAnimating ? 1 : 0.6)
    }
}

// MARK: - Effects

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 2), y: 0))
    }
}
