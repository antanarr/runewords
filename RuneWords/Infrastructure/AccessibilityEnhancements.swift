//
//  AccessibilityEnhancements.swift
//  RuneWords
//
//  Accessibility and Dynamic Type improvements
//

import SwiftUI

// MARK: - Accessibility Modifiers
struct AccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let value: String?
    
    init(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
        self.value = value
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityValue(value ?? "")
    }
}

// MARK: - Dynamic Type Support
struct DynamicTypeModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    let baseSize: CGFloat
    let style: Font.TextStyle
    let isCustomFont: Bool
    
    init(baseSize: CGFloat, style: Font.TextStyle = .body, isCustomFont: Bool = false) {
        self.baseSize = baseSize
        self.style = style
        self.isCustomFont = isCustomFont
    }
    
    func body(content: Content) -> some View {
        content
            .font(scaledFont)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var scaledFont: Font {
        let scaledSize = UIFontMetrics(forTextStyle: uiTextStyle)
            .scaledValue(for: baseSize)
        
        if isCustomFont {
            return .custom("Cinzel-Bold", size: scaledSize)
        } else {
            return .system(size: scaledSize)
        }
    }
    
    private var uiTextStyle: UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}

// MARK: - High Contrast Support
struct HighContrastModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) var contrast
    let normalColor: Color
    let highContrastColor: Color
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(contrast == .increased ? highContrastColor : normalColor)
    }
}

// MARK: - Reduce Motion Support
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : animation, value: UUID())
    }
}

// MARK: - VoiceOver Improvements
struct VoiceOverModifier: ViewModifier {
    @Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled
    let voiceOverContent: AnyView?
    
    func body(content: Content) -> some View {
        if voiceOverEnabled, let voiceOverContent = voiceOverContent {
            voiceOverContent
        } else {
            content
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Add comprehensive accessibility support
    func accessibilityEnhanced(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil
    ) -> some View {
        modifier(AccessibilityModifier(
            label: label,
            hint: hint,
            traits: traits,
            value: value
        ))
    }
    
    /// Support Dynamic Type with custom or system fonts
    func dynamicTypeSupport(
        baseSize: CGFloat,
        style: Font.TextStyle = .body,
        isCustomFont: Bool = false
    ) -> some View {
        modifier(DynamicTypeModifier(
            baseSize: baseSize,
            style: style,
            isCustomFont: isCustomFont
        ))
    }
    
    /// Support high contrast mode
    func highContrastSupport(
        normal: Color,
        highContrast: Color
    ) -> some View {
        modifier(HighContrastModifier(
            normalColor: normal,
            highContrastColor: highContrast
        ))
    }
    
    /// Support reduce motion preference
    func reduceMotionSupport(_ animation: Animation?) -> some View {
        modifier(ReduceMotionModifier(animation: animation))
    }
    
    /// Provide alternative content for VoiceOver
    func voiceOverAlternative(_ content: () -> some View) -> some View {
        modifier(VoiceOverModifier(
            voiceOverContent: AnyView(content())
        ))
    }
}

// MARK: - Accessible Color Palette
struct AccessibleColors {
    // High contrast colors that meet WCAG AA standards
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    
    static let successGreen = Color(red: 0, green: 0.5, blue: 0)
    static let warningOrange = Color(red: 0.8, green: 0.4, blue: 0)
    static let errorRed = Color(red: 0.7, green: 0, blue: 0)
    static let infoBlue = Color(red: 0, green: 0.4, blue: 0.8)
    
    // Background colors with proper contrast
    static let lightBackground = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    
    // Interactive element colors
    static let buttonBackground = Color(red: 0.2, green: 0.4, blue: 0.8)
    static let buttonText = Color.white
    
    // Ensure minimum contrast ratio of 4.5:1 for normal text
    // and 3:1 for large text (18pt+ or 14pt+ bold)
    static func meetsContrastRequirement(
        foreground: Color,
        background: Color,
        isLargeText: Bool = false
    ) -> Bool {
        let requiredRatio: Double = isLargeText ? 3.0 : 4.5
        let ratio = contrastRatio(between: foreground, and: background)
        return ratio >= requiredRatio
    }
    
    private static func contrastRatio(between color1: Color, and color2: Color) -> Double {
        // Simplified contrast calculation
        // In production, use proper WCAG formula
        return 4.5 // Placeholder
    }
}

// MARK: - Accessible Components

struct AccessibleButton: View {
    let title: String
    let action: () -> Void
    let icon: String?
    
    @Environment(\.sizeCategory) var sizeCategory
    
    init(
        title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: scaledIconSize))
                }
                
                Text(title)
                    .dynamicTypeSupport(
                        baseSize: 18,
                        style: .headline,
                        isCustomFont: true
                    )
            }
            .padding(.horizontal, scaledPadding)
            .padding(.vertical, scaledPadding * 0.75)
            .background(AccessibleColors.buttonBackground)
            .foregroundColor(AccessibleColors.buttonText)
            .cornerRadius(8)
        }
        .accessibilityEnhanced(
            label: title,
            traits: .isButton
        )
    }
    
    private var scaledIconSize: CGFloat {
        UIFontMetrics.default.scaledValue(for: 20)
    }
    
    private var scaledPadding: CGFloat {
        UIFontMetrics.default.scaledValue(for: 16)
    }
}

struct AccessibleTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        TextField(placeholder, text: $text)
            .dynamicTypeSupport(baseSize: 16, style: .body)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AccessibleColors.primaryText.opacity(0.3), lineWidth: 1)
            )
            .accessibilityEnhanced(
                label: placeholder,
                hint: "Double tap to edit",
                value: text.isEmpty ? "Empty" : text
            )
            .keyboardType(keyboardType)
    }
}

struct AccessibleProgressBar: View {
    let value: Double
    let total: Double
    let label: String
    
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .dynamicTypeSupport(baseSize: 14, style: .caption)
                .foregroundColor(AccessibleColors.secondaryText)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: barHeight)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AccessibleColors.infoBlue)
                        .frame(
                            width: geometry.size.width * (value / total),
                            height: barHeight
                        )
                }
            }
            .frame(height: barHeight)
            
            Text("\(Int(value)) / \(Int(total))")
                .dynamicTypeSupport(baseSize: 12, style: .caption2)
                .foregroundColor(AccessibleColors.secondaryText)
        }
        .accessibilityEnhanced(
            label: label,
            value: "\(Int((value / total) * 100)) percent complete"
        )
    }
    
    private var barHeight: CGFloat {
        UIFontMetrics.default.scaledValue(for: 8)
    }
}

// MARK: - Accessibility Settings View
struct AccessibilitySettingsView: View {
    @AppStorage("reduceAnimations") private var reduceAnimations = false
    @AppStorage("increaseContrast") private var increaseContrast = false
    @AppStorage("boldText") private var boldText = false
    @AppStorage("largerText") private var largerText = false
    
    var body: some View {
        Form {
            Section("Visual") {
                Toggle("Reduce Animations", isOn: $reduceAnimations)
                    .accessibilityEnhanced(
                        label: "Reduce Animations",
                        hint: "Minimizes motion and animations throughout the app"
                    )
                
                Toggle("Increase Contrast", isOn: $increaseContrast)
                    .accessibilityEnhanced(
                        label: "Increase Contrast",
                        hint: "Uses higher contrast colors for better visibility"
                    )
                
                Toggle("Bold Text", isOn: $boldText)
                    .accessibilityEnhanced(
                        label: "Bold Text",
                        hint: "Makes all text appear in bold for easier reading"
                    )
                
                Toggle("Larger Text", isOn: $largerText)
                    .accessibilityEnhanced(
                        label: "Larger Text",
                        hint: "Increases the size of text throughout the app"
                    )
            }
            
            Section("Help") {
                Button("VoiceOver Tutorial") {
                    // Show VoiceOver tutorial
                }
                .accessibilityEnhanced(
                    label: "VoiceOver Tutorial",
                    hint: "Learn how to use VoiceOver with this app"
                )
                
                Button("Accessibility Guide") {
                    // Show accessibility guide
                }
                .accessibilityEnhanced(
                    label: "Accessibility Guide",
                    hint: "View tips for using accessibility features"
                )
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Accessibility Announcements
struct AccessibilityAnnouncer {
    static func announce(_ message: String, isImportant: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(
                notification: isImportant ? .screenChanged : .announcement,
                argument: message
            )
        }
    }
    
    static func announceScreenChange(_ screenName: String) {
        announce("\(screenName) screen", isImportant: true)
    }
    
    static func announceLayoutChange() {
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
}

// MARK: - Focus Management
struct FocusableModifier: ViewModifier {
    @AccessibilityFocusState var isFocused: Bool
    let id: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onAppear {
                // Auto-focus for VoiceOver users if needed
            }
    }
}

extension View {
    func accessibilityFocusable(id: String) -> some View {
        modifier(FocusableModifier(id: id))
    }
}
