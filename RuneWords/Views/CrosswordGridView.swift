import SwiftUI

/// A view that displays solution words in a clean, readable grid
struct CrosswordGridView: View {
    let solutions: [String: [Int]]
    let foundWords: Set<String>
    let baseLetters: String
    let revealedIndices: [String: Set<Int>]
    
    // Group words by length for better organization
    private var wordsByLength: [(length: Int, words: [String])] {
        let grouped = Dictionary(grouping: Array(solutions.keys)) { $0.count }
        return grouped.sorted { $0.key > $1.key }.map { (length: $0.key, words: $0.value.sorted()) }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(wordsByLength, id: \.length) { group in
                    VStack(spacing: 8) {
                        // Length indicator
                        HStack {
                            Text("\(group.length) Letters")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("\(group.words.filter { foundWords.contains($0.uppercased()) }.count)/\(group.words.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 4)
                        
                        // Words in this length group
                        VStack(spacing: 6) {
                            ForEach(group.words, id: \.self) { word in
                                ModernWordRow(
                                    word: word,
                                    isFound: foundWords.contains(word.uppercased()),  // Ensure uppercase comparison
                                    revealedIndices: revealedIndices[word.uppercased()] ?? revealedIndices[word] ?? []
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.2))
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

/// Modern word row display with improved visuals
struct ModernWordRow: View {
    let word: String
    let isFound: Bool
    let revealedIndices: Set<Int>
    
    @State private var animateReveal = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<word.count, id: \.self) { index in
                ModernLetterBox(
                    letter: String(Array(word.uppercased())[index]),  // Ensure uppercase
                    isRevealed: isFound || revealedIndices.contains(index),
                    isFound: isFound,
                    animationDelay: Double(index) * 0.05
                )
            }
        }
        .onChange(of: isFound) { _, newValue in
            if newValue {
                animateReveal = true
            }
        }
    }
}

/// Individual letter box with modern design
struct ModernLetterBox: View {
    let letter: String
    let isRevealed: Bool
    let isFound: Bool
    let animationDelay: Double
    
    @State private var scale: CGFloat = 1.0
    @State private var showLetter: Bool = false
    
    private var boxSize: CGFloat { 32 }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .frame(width: boxSize, height: boxSize)
            
            // Border
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(borderColor, lineWidth: borderWidth)
                .frame(width: boxSize, height: boxSize)
            
            // Letter - Show immediately if found, with animation if revealed
            if showLetter {
                Text(letter.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                    .scaleEffect(scale)
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Empty placeholder dot
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
        .onAppear {
            // Set initial state based on whether word is found
            showLetter = isFound || isRevealed
            if isFound {
                scale = 1.0
            }
        }
        .onChange(of: isFound) { _, newValue in
            if newValue {
                // Show letter immediately when found
                withAnimation(.easeIn(duration: 0.1)) {
                    showLetter = true
                }
                // Then do the pop animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(animationDelay)) {
                    scale = 1.1
                }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8).delay(animationDelay + 0.1)) {
                    scale = 1.0
                }
            }
        }
        .onChange(of: isRevealed) { _, newValue in
            if newValue && !isFound {
                // Show letter when revealed as hint
                withAnimation(.easeIn(duration: 0.1)) {
                    showLetter = true
                }
                // Very subtle scale for hints
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = 1.05
                }
                withAnimation(.easeInOut(duration: 0.15).delay(0.1)) {
                    scale = 1.0
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if isFound {
            return Color.green.opacity(0.25)
        } else if isRevealed {
            return Color.yellow.opacity(0.15)
        } else {
            return Color.white.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        if isFound {
            return Color.green.opacity(0.6)
        } else if isRevealed {
            return Color.yellow.opacity(0.5)
        } else {
            return Color.white.opacity(0.2)
        }
    }
    
    private var borderWidth: CGFloat {
        if isFound {
            return 2
        } else if isRevealed {
            return 1.5
        } else {
            return 1
        }
    }
    
    private var textColor: Color {
        if isFound {
            return .white
        } else {
            return .white.opacity(0.8)
        }
    }
}

// MARK: - Simplified fallback for complex layouts
struct SimpleWordListView: View {
    let solutions: [String: [Int]]
    let foundWords: Set<String>
    let baseLetters: String
    let revealedIndices: [String: Set<Int>]
    
    var sortedWords: [String] {
        Array(solutions.keys).sorted { $0.count > $1.count }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(sortedWords, id: \.self) { word in
                    ModernWordRow(
                        word: word,
                        isFound: foundWords.contains(word),
                        revealedIndices: revealedIndices[word] ?? []
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview
struct CrosswordGridView_Previews: PreviewProvider {
    static var previews: some View {
        CrosswordGridView(
            solutions: [
                "STREAM": [1, 2, 3, 4, 5, 6],
                "TEAM": [2, 4, 5, 6],
                "MEAT": [6, 4, 5, 2],
                "ATE": [5, 2, 4]
            ],
            foundWords: ["TEAM", "ATE"],
            baseLetters: "STREAM",
            revealedIndices: ["MEAT": [0, 2]]
        )
        .preferredColorScheme(.dark)
        .padding()
        .background(Color.black)
    }
}
