import SwiftUI

/// Words board that shows ONLY actual target words (placeholders). Found targets fill with letters.
/// Bonus words DO NOT appear in this board. Translucent Wordscapes-style panel with grouped layout.
struct WordsBoardView: View {
    let targets: [String]
    let found: Set<String>
    let animatingWord: String?
    let animationNamespace: Namespace.ID
    let onSlotsChanged: ([String: Anchor<CGRect>]) -> Void
    
    init(
        targets: [String],
        found: Set<String>,
        animatingWord: String?,
        animationNamespace: Namespace.ID,
        onSlotsChanged: @escaping ([String: Anchor<CGRect>]) -> Void
    ) {
        self.targets = targets
        self.found = found
        self.animatingWord = animatingWord
        self.animationNamespace = animationNamespace
        self.onSlotsChanged = onSlotsChanged
    }
    
    var body: some View {
        GeometryReader { geometry in
            let safeHeight = geometry.size.height
            
            VStack(spacing: 10) {
                // Optional title row centered - more subtle
                Text("WORDS")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .tracking(2)
                
                // Group targets by length and pack into lines
                ScrollView(.vertical, showsIndicators: false) {
                    wordGroups(containerWidth: geometry.size.width)
                        .padding(.vertical, 4)
                }
                .frame(maxHeight: safeHeight * 0.36) // Slightly more room for content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                // FIXED: Much lighter translucent panel
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                // Subtle inner glow for depth
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.05),
                            lineWidth: 1
                        )
                        .blur(radius: 1)
                        .padding(1)
                )
                .fixedCircleShadow(
                    color: .black.opacity(0.3),
                    blur: 12,
                    y: 4,
                    cornerRadius: 20
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .onPreferenceChange(SlotAnchorPreference.self) { anchors in
            onSlotsChanged(anchors)
        }
    }
    
    @ViewBuilder
    private func wordGroups(containerWidth: CGFloat) -> some View {
        let availableWidth = containerWidth - 28 // Container width minus padding
        
        // Group by length (6→3) for better organization
        let groupedWords = Dictionary(grouping: targets) { $0.count }
        let sortedLengths = groupedWords.keys.sorted(by: >)
        
        VStack(alignment: .center, spacing: 10) {
            ForEach(sortedLengths, id: \.self) { length in
                if let words = groupedWords[length], !words.isEmpty {
                    lengthGroup(
                        length: length,
                        words: words,
                        availableWidth: availableWidth
                    )
                    
                    // Subtle separator between groups (except last)
                    if length != sortedLengths.last {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: availableWidth * 0.4, height: 0.5)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func lengthGroup(length: Int, words: [String], availableWidth: CGFloat) -> some View {
        // Pack words into centered lines based on available width
        let packedLines = packWordsIntoLines(words: words, length: length, availableWidth: availableWidth)
        
        VStack(alignment: .center, spacing: 7) {
            ForEach(Array(packedLines.enumerated()), id: \.offset) { lineIndex, lineWords in
                HStack(spacing: 8) {
                    ForEach(lineWords, id: \.self) { word in
                        wordSlots(for: word, length: length, availableWidth: availableWidth)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func wordSlots(for word: String, length: Int, availableWidth: CGFloat) -> some View {
        let isFound = found.contains(word)
        let tileSize = calculateTileSize(for: length, availableWidth: availableWidth)
        
        HStack(spacing: 2) {
            ForEach(0..<word.count, id: \.self) { index in
                letterSlot(word: word, index: index, isFound: isFound, tileSize: tileSize)
            }
        }
        .opacity(word == animatingWord ? 0 : 1) // Hide during pill → slot animation
        .background {
            // Hidden matched host for pill → slot animation
            if word == animatingWord {
                Text(word.uppercased())
                    .opacity(0)
                    .matchedGeometryEffect(id: word, in: animationNamespace)
            }
        }
        .anchorPreference(
            key: SlotAnchorPreference.self,
            value: .bounds
        ) { anchor in
            // Capture anchors for animation targeting
            return [word: anchor]
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isFound ? "Found word: \(word)" : "\(word.count) letter word slot")
        .accessibilityHint(isFound ? "Word completed" : "Empty word slot")
    }
    
    @ViewBuilder
    private func letterSlot(word: String, index: Int, isFound: Bool, tileSize: CGFloat) -> some View {
        let char = String(word[word.index(word.startIndex, offsetBy: index)])
        
        ZStack {
            // Slot background
            slotBackground(isFound: isFound)
            
            // Letter text
            Text(isFound ? char.uppercased() : "")
                .font(.system(size: max(12, tileSize * 0.4), weight: .bold, design: .rounded))
                .foregroundStyle(isFound ? Color.white : Color.clear)
                // Subtle text shadow for found letters
                .fixedCircleShadow(
                    color: isFound ? .black.opacity(0.3) : .clear,
                    blur: 1,
                    y: 1
                )
        }
        .frame(width: tileSize, height: tileSize)
        .animation(.easeInOut(duration: 0.25), value: isFound)
    }
    
    @ViewBuilder
    private func slotBackground(isFound: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isFound
                        ? [
                            Color.green.opacity(0.7),  // FIXED: Less opaque when found
                            Color.green.opacity(0.6)
                        ]
                        : [
                            Color.white.opacity(0.08),  // FIXED: Much lighter when empty
                            Color.white.opacity(0.06)
                        ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isFound
                            ? Color.green.opacity(0.8)  // FIXED: Lighter border
                            : Color.white.opacity(0.15),  // FIXED: Subtler border
                        lineWidth: isFound ? 1.2 : 0.5
                    )
            )
            // Inner shadow for depth on empty slots
            .overlay(
                Group {
                    if !isFound {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                            .padding(0.5)
                    }
                }
            )
    }
    
    // Calculate tile size based on word length and available space
    private func calculateTileSize(for length: Int, availableWidth: CGFloat) -> CGFloat {
        let inter: CGFloat = 6.0
        let maxCols = length
        let tile = floor((availableWidth - inter * CGFloat(maxCols - 1)) / CGFloat(maxCols))
        return tile.clamped(to: 24...38) // Slightly smaller range for cleaner look
    }
    
    // Greedy packing algorithm for better space utilization
    private func packWordsIntoLines(words: [String], length: Int, availableWidth: CGFloat) -> [[String]] {
        guard !words.isEmpty else { return [] }
        
        let baseTileSize = calculateTileSize(for: length, availableWidth: availableWidth)
        let wordSpacing: CGFloat = 8 // Space between words
        let charSpacing: CGFloat = 2 // Space between characters
        
        var lines: [[String]] = []
        var currentLine: [String] = []
        var currentLineWidth: CGFloat = 0
        
        for word in words {
            let wordWidth = CGFloat(word.count) * baseTileSize + CGFloat(word.count - 1) * charSpacing
            let totalWidth = currentLine.isEmpty ? wordWidth : currentLineWidth + wordSpacing + wordWidth
            
            if currentLine.isEmpty || totalWidth <= availableWidth {
                // Fits on current line
                currentLine.append(word)
                currentLineWidth = totalWidth
            } else {
                // Start new line
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = [word]
                currentLineWidth = wordWidth
            }
        }
        
        // Add final line
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines
    }
}

// MARK: - Preference Key for Slot Anchors
private struct SlotAnchorPreference: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Helper Extension
// Note: clamped extension is defined in GameView.swift

// MARK: - Preview
struct WordsBoardView_Previews: PreviewProvider {
    static var previews: some View {
        WordsBoardPreview()
    }
}

private struct WordsBoardPreview: View {
    @Namespace private var animNS
    @State private var found: Set<String> = ["TRAIN", "ART"]
    
    var body: some View {
        ZStack {
            // Scenic background to test translucency
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                WordsBoardView(
                    targets: ["TRAINS", "STRAIN", "TRAIN", "STAIN", "RAIN", "RANTS", "HINT", "ART", "TIN", "RAT", "ANT", "SIT"],
                    found: found,
                    animatingWord: nil,
                    animationNamespace: animNS
                ) { anchors in
                    print("Anchors updated: \(anchors.keys)")
                }
                
                // Test button to add found words
                Button("Find Random Word") {
                    let targets = ["TRAINS", "STRAIN", "TRAIN", "STAIN", "RAIN", "RANTS", "HINT", "ART", "TIN", "RAT", "ANT", "SIT"]
                    let unfound = targets.filter { !found.contains($0) }
                    if let random = unfound.randomElement() {
                        found.insert(random)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .preferredColorScheme(.dark)
    }
}