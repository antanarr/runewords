// AccessibleLetterWheel.swift
// RuneWords - WO-007 Accessibility Support

import SwiftUI

/// Accessible letter wheel for VoiceOver users
/// Provides a grid-based layout with clear tap targets
struct AccessibleLetterWheel: View {
    let letters: [WheelLetter]
    let selectedIndices: Set<Int>
    let onLetterTap: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Current word display
            if !selectedIndices.isEmpty {
                let currentWord = selectedIndices.sorted()
                    .compactMap { idx in
                        letters.indices.contains(idx) ? String(letters[idx].char) : nil
                    }
                    .joined()
                
                Text("Current: \(currentWord)")
                    .font(.custom("Cinzel-Bold", size: 24))
                    .foregroundStyle(.white)
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                    .accessibilityLabel("Current word: \(currentWord)")
            }
            
            // Letter grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(letters.indices, id: \.self) { index in
                    if index < letters.count {
                        AccessibleLetterButton(
                            letter: letters[index],
                            isSelected: selectedIndices.contains(index),
                            onTap: { onLetterTap(index) }
                        )
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 20) {
                // Clear button
                Button(action: {
                    // Clear all selections
                    for index in selectedIndices {
                        onLetterTap(index)
                    }
                }) {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.3))
                        )
                }
                .accessibilityLabel("Clear word")
                .accessibilityHint("Double tap to clear the current word")
                
                // Submit button
                Button(action: {
                    // Trigger submission (handled by parent)
                    UIAccessibility.post(notification: .announcement, argument: "Word submitted")
                }) {
                    Label("Submit", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.3))
                        )
                }
                .accessibilityLabel("Submit word")
                .accessibilityHint("Double tap to submit the current word")
                .disabled(selectedIndices.isEmpty)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
}

/// Individual letter button for accessible wheel
struct AccessibleLetterButton: View {
    let letter: WheelLetter
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.yellow.opacity(0.3) : Color(red: 0.106, green: 0.102, blue: 0.188))
                    .frame(width: 70, height: 70)
                
                Circle()
                    .stroke(isSelected ? Color.yellow : Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 70, height: 70)
                
                Text(String(letter.char))
                    .font(.custom("Cinzel-Bold", size: 32))
                    .foregroundColor(.white)
            }
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .fixedCircleShadow(
                color: isSelected ? .yellow.opacity(0.4) : .black.opacity(0.2),
                blur: isSelected ? 8 : 4
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .accessibilityLabel("Letter \(letter.char)")
        .accessibilityHint(isSelected ? "Selected. Double tap to deselect" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        AccessibleLetterWheel(
            letters: [
                WheelLetter(char: "T", originalIndex: 0, position: .zero),
                WheelLetter(char: "R", originalIndex: 1, position: .zero),
                WheelLetter(char: "A", originalIndex: 2, position: .zero),
                WheelLetter(char: "I", originalIndex: 3, position: .zero),
                WheelLetter(char: "N", originalIndex: 4, position: .zero),
                WheelLetter(char: "S", originalIndex: 5, position: .zero)
            ],
            selectedIndices: [0, 1, 2],
            onLetterTap: { index in
                print("Tapped letter at index: \(index)")
            }
        )
    }
    .preferredColorScheme(.dark)
}
