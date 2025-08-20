import SwiftUI

// MARK: - Accessibility Extensions
extension View {
    
    /// Apply dynamic type scaling with a maximum size limit
    func dynamicTypeSize() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    
    /// Add VoiceOver label with automatic trait detection
    func accessibilityLabelWithTrait(_ label: String, trait: AccessibilityTraits? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(trait ?? [])
    }
    
    /// Make view accessible as a button with label
    func accessibleButton(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Make view accessible with hint
    func accessibleWithHint(_ label: String, hint: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
    }
    
    /// Apply standard game button accessibility
    func gameButtonAccessibility(_ label: String, enabled: Bool = true) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(enabled ? [] : .isStaticText)
            .accessibilityHint(enabled ? "Double tap to activate" : "Not available")
    }
}

// MARK: - Text Accessibility
struct AccessibleText: View {
    let text: String
    let style: TextStyle
    
    enum TextStyle {
        case title
        case headline
        case body
        case caption
        case button
        
        var font: Font {
            switch self {
            case .title:
                return .custom(Config.UI.primaryFont, size: 32)
            case .headline:
                return .custom(Config.UI.primaryFont, size: 24)
            case .body:
                return .system(size: 16)
            case .caption:
                return .system(size: 14)
            case .button:
                return .system(size: 18, weight: .semibold)
            }
        }
        
        var dynamicFont: Font {
            switch self {
            case .title:
                return .largeTitle
            case .headline:
                return .headline
            case .body:
                return .body
            case .caption:
                return .caption
            case .button:
                return .headline
            }
        }
    }
    
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        Text(text)
            .font(sizeCategory.isAccessibilityCategory ? style.dynamicFont : style.font)
            .dynamicTypeSize()
    }
}

// MARK: - Accessible Game Components
struct AccessibleTileView: View {
    let letter: Character?
    let isRevealed: Bool
    let isHighlighted: Bool
    let position: (row: Int, col: Int)
    
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(tileBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(tileBorder, lineWidth: 2)
                )
            
            if let letter = letter, isRevealed {
                Text(String(letter))
                    .font(tileFont)
                    .foregroundColor(.white)
                    .dynamicTypeSize()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }
    
    private var tileBackground: Color {
        if isHighlighted {
            return .yellow.opacity(0.3)
        } else if isRevealed {
            return .blue.opacity(0.2)
        } else {
            return .gray.opacity(0.1)
        }
    }
    
    private var tileBorder: Color {
        isHighlighted ? .yellow : .white.opacity(0.3)
    }
    
    private var tileFont: Font {
        sizeCategory.isAccessibilityCategory
            ? .system(size: 24, weight: .bold)
            : .custom(Config.UI.primaryFont, size: 20)
    }
    
    private var accessibilityLabel: String {
        if let letter = letter, isRevealed {
            return "Letter \(letter) at row \(position.row + 1), column \(position.col + 1)"
        } else {
            return "Hidden tile at row \(position.row + 1), column \(position.col + 1)"
        }
    }
    
    private var accessibilityHint: String {
        if isRevealed {
            return "Letter is revealed"
        } else {
            return "Letter not yet discovered"
        }
    }
}

// MARK: - Accessible Letter Wheel
// Note: AccessibleLetterWheel is defined in Views/Components/AccessibleLetterWheel.swift

// MARK: - Accessible Coin Display
struct AccessibleCoinDisplay: View {
    let coins: Int
    let isAnimating: Bool
    
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        HStack(spacing: 8) {
            Image("icon_coin")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
            
            Text("\(coins)")
                .font(coinFont)
                .foregroundStyle(.yellow)
                .dynamicTypeSize()
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.spring(response: 0.3), value: isAnimating)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.3)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(coins) coins")
        .accessibilityHint("Your current coin balance")
    }
    
    private var iconSize: CGFloat {
        sizeCategory.isAccessibilityCategory ? 28 : 20
    }
    
    private var coinFont: Font {
        sizeCategory.isAccessibilityCategory
            ? .system(size: 20, weight: .bold)
            : .system(size: 16, weight: .bold)
    }
}

// MARK: - Color Blind Mode Support
struct ColorBlindPalette {
    static let shared = ColorBlindPalette()
    
    enum Mode: String, CaseIterable {
        case normal = "Normal"
        case protanopia = "Protanopia"
        case deuteranopia = "Deuteranopia"
        case tritanopia = "Tritanopia"
        
        var displayName: String { rawValue }
    }
    
    @AppStorage("colorBlindMode") var mode: Mode = .normal
    
    func adjustedColor(_ color: Color) -> Color {
        switch mode {
        case .normal:
            return color
            
        case .protanopia:
            // Red-blind adjustments
            if color == .red { return .orange }
            if color == .green { return .blue }
            return color
            
        case .deuteranopia:
            // Green-blind adjustments
            if color == .green { return .blue }
            if color == .red { return .orange }
            return color
            
        case .tritanopia:
            // Blue-blind adjustments
            if color == .blue { return .cyan }
            if color == .yellow { return .orange }
            return color
        }
    }
}

// MARK: - Haptic Feedback Preferences
struct HapticPreferences {
    @AppStorage("hapticFeedbackEnabled") static var isEnabled: Bool = true
    @AppStorage("hapticIntensity") static var intensity: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    
    static func performHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: intensity)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Reduced Motion Support
extension View {
    func reducedMotionAnimation<V>(_ animation: Animation?, value: V) -> some View where V: Equatable {
        self.animation(
            UIAccessibility.isReduceMotionEnabled ? .linear(duration: 0.1) : animation,
            value: value
        )
    }
}
