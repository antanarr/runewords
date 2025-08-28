// Fixed FoundWordsView.swift - Prominent word target display using modern SwiftUI

import SwiftUI

/// Displays target words as individual rows using modern SwiftUI layout
/// Each word gets its own row with letter slots - VISUAL ONLY, NOT INTERACTIVE
struct FoundWordsView: View {
    let solutionWords: [String]        
    let foundWords: Set<String>        
    let revealIndices: [String: Set<Int>]

    // Modern computed property with cleaner syntax
    private var sortedSolutions: [String] {
        solutionWords.sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs < rhs : lhs.count < rhs.count
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {  // Modern LazyVStack for performance
                ForEach(sortedSolutions, id: \.self) { word in
                    WordTargetRow(
                        word: word,
                        isFound: foundWords.contains(word),
                        revealIndices: revealIndices[word, default: []]  // Modern default syntax
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
}

/// Individual word row using modern SwiftUI patterns
private struct WordTargetRow: View {
    let word: String
    let isFound: Bool
    let revealIndices: Set<Int>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var letters: [Character] { Array(word) }

    var body: some View {
        VStack(spacing: 6) {
            // Modern header with better layout
            HStack {
                // Simple text display without the 123 icon
                Text("\(letters.count) LETTERS")
                    .font(.custom("Cinzel-Regular", size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                if isFound {
                    // Modern Label with system image
                    Label("FOUND", systemImage: "checkmark.circle.fill")
                        .font(.custom("Cinzel-Bold", size: 12))
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }
            
            // Letter slots with modern HStack layout
            HStack(spacing: 4) {
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    LetterSlot(
                        letter: letter,
                        isRevealed: isFound || revealIndices.contains(index),
                        position: index + 1,
                        totalLetters: letters.count
                    )
                }
                
                Spacer()  // Push letters to leading edge
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            // Modern background with conditional styling
            RoundedRectangle(cornerRadius: 12)
                .fill(isFound ? .green.opacity(0.15) : .black.opacity(0.25))
                .strokeBorder(
                    isFound ? .green.opacity(0.5) : .white.opacity(0.2), 
                    lineWidth: 1.5
                )
        }
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.4), 
            value: isFound
        )
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.2), 
            value: revealIndices
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(letters.count) letter word" + (isFound ? " - completed" : " - in progress"))
    }
}

/// Modern letter slot with latest SwiftUI patterns
private struct LetterSlot: View {
    let letter: Character
    let isRevealed: Bool
    let position: Int
    let totalLetters: Int
    
    var body: some View {
        ZStack {
            // Modern background with conditional styling
            RoundedRectangle(cornerRadius: 6)
                .fill(isRevealed ? .white.opacity(0.9) : .black.opacity(0.4))
                .strokeBorder(
                    isRevealed ? .green.opacity(0.8) : .white.opacity(0.5), 
                    lineWidth: 2
                )
                .frame(width: 36, height: 44)

            Group {
                if isRevealed {
                    Text(String(letter))
                        .font(.custom("Cinzel-Bold", size: 24))
                        .foregroundStyle(.black)
                        .fontWeight(.bold)
                } else {
                    // Position number for unrevealed letters
                    Text("\(position)")
                        .font(.custom("Cinzel-Regular", size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
        .scaleEffect(isRevealed ? 1.05 : 1.0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.6), 
            value: isRevealed
        )
    }
}

// MARK: - Modern Preview with comprehensive examples

#Preview("Word Progress States") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            Text("Find These Words")
                .font(.custom("Cinzel-Bold", size: 18))
                .foregroundStyle(.white)
            
            FoundWordsView(
                solutionWords: ["SWIFT", "CODE", "APP", "DEVELOP", "PROGRAM"],
                foundWords: ["SWIFT", "APP"],
                revealIndices: [
                    "CODE": [0, 2], 
                    "DEVELOP": [1, 3, 5],
                    "PROGRAM": [0]
                ]
            )
            .frame(height: 300)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.3))
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
        }
        .padding()
    }
}

#Preview("Empty State") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Text("Find These Words")
                .font(.custom("Cinzel-Bold", size: 18))
                .foregroundStyle(.white)
            
            FoundWordsView(
                solutionWords: ["MYSTERY", "PUZZLE", "ENIGMA"],
                foundWords: [],
                revealIndices: [:]
            )
            .frame(height: 200)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.3))
            }
        }
        .padding()
    }
}
