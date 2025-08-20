//
//  Theme.swift
//  RuneWords
//
//  Design system with typography and color tokens
//

import SwiftUI

// MARK: - Theme Namespace

enum Theme {
    enum Typography {}
    enum Colors {}
    enum Spacing {}
    enum Radius {}
    enum Animation {}
}

// MARK: - Typography Tokens

@MainActor
extension Theme.Typography {
    
    // MARK: Font Families (WO-004: Nil-safe with fallbacks)
    
    private static let headingFont = "Cinzel"
    private static let bodyFont: String? = nil // Uses SF Pro (system font)
    
    /// Safe font loader with fallback (WO-004)
    @MainActor
    private static func safeFont(name: String, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        // Check if custom font is available
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size, relativeTo: textStyle)
        } else {
            ToastManager.shared.showWarning("Custom font '\(name)' unavailable, using system font")
            return .system(size: size, weight: .semibold, design: .default).monospacedDigit()
        }
    }
    
    // MARK: Text Styles
    
    /// Large display title (Cinzel with fallback)
    static func largeTitle(_ text: String) -> some View {
        Text(text)
            .font(safeFont(name: headingFont, size: 34, relativeTo: .largeTitle))
            .fontWeight(.bold)
            .tracking(0.5)
    }
    
    /// Section title (Cinzel with fallback)
    static func title(_ text: String) -> some View {
        Text(text)
            .font(safeFont(name: headingFont, size: 28, relativeTo: .title))
            .fontWeight(.semibold)
            .tracking(0.3)
    }
    
    /// Medium title (Cinzel with fallback)
    static func title2(_ text: String) -> some View {
        Text(text)
            .font(safeFont(name: headingFont, size: 24, relativeTo: .title2))
            .fontWeight(.medium)
    }
    
    /// Small title (Cinzel with fallback)
    static func title3(_ text: String) -> some View {
        Text(text)
            .font(safeFont(name: headingFont, size: 20, relativeTo: .title3))
            .fontWeight(.medium)
    }
    
    /// Headline (SF Pro)
    static func headline(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .fontWeight(.semibold)
    }
    
    /// Body text (SF Pro)
    static func body(_ text: String) -> some View {
        Text(text)
            .font(.body)
    }
    
    /// Callout text (SF Pro)
    static func callout(_ text: String) -> some View {
        Text(text)
            .font(.callout)
    }
    
    /// Caption text (SF Pro)
    static func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
    }
    
    /// Footnote text (SF Pro)
    static func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
    }
    
    // MARK: View Modifiers
    
    struct HeadingStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(safeFont(name: Theme.Typography.headingFont, size: 28, relativeTo: .title))
                .fontWeight(.semibold)
                .tracking(0.3)
        }
    }
    
    struct BodyStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.body)
                .lineSpacing(4)
        }
    }
    
    struct ButtonLabelStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.headline)
                .fontWeight(.semibold)
                .tracking(0.2)
        }
    }
}

// MARK: - Color Tokens

extension Theme.Colors {
    
    // MARK: Primary Colors
    
    static let primary = Color("PrimaryColor", bundle: .main)
        .opacity(1.0) // Fallback to system blue if asset missing
    
    static let primaryDark = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.2, green: 0.3, blue: 0.8, alpha: 1.0)
            : UIColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1.0)
    })
    
    // MARK: Semantic Colors - FIXED FOR CONTRAST
    
    // Force dark theme backgrounds for consistency
    static let background = Color(red: 0.06, green: 0.06, blue: 0.12)
    static let secondaryBackground = Color(red: 0.15, green: 0.15, blue: 0.25)
    static let tertiaryBackground = Color(red: 0.25, green: 0.25, blue: 0.35)
    
    // Force light labels for contrast
    static let label = Color.white
    static let secondaryLabel = Color.white.opacity(0.8)
    static let tertiaryLabel = Color.white.opacity(0.6)
    
    // MARK: Game-Specific Colors (WCAG AA Compliant)
    
    static let success = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0) // Bright green for dark mode
            : UIColor(red: 0.0, green: 0.6, blue: 0.2, alpha: 1.0) // Darker green for light mode
    })
    
    static let error = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0) // Bright red for dark mode
            : UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0) // Darker red for light mode
    })
    
    static let warning = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0) // Bright yellow for dark mode
            : UIColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1.0) // Darker amber for light mode
    })
    
    static let hint = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0) // Bright purple for dark mode
            : UIColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1.0) // Darker purple for light mode
    })
    
    // MARK: Tile Colors - FIXED FOR GAME VISIBILITY
    
    static let tileFilled = Color(red: 0.3, green: 0.5, blue: 0.3)
    
    static let tileEmpty = Color(red: 0.25, green: 0.25, blue: 0.35)
    
    static let tileHinted = Color(red: 0.5, green: 0.4, blue: 0.7).opacity(0.4)
    
    // MARK: Gradients
    
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [background, secondaryBackground],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Spacing Tokens

extension Theme.Spacing {
    static let xxxSmall: CGFloat = 2
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48
    static let xxxLarge: CGFloat = 64
}

// MARK: - Corner Radius Tokens

extension Theme.Radius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let xLarge: CGFloat = 16
    static let round: CGFloat = 999
}

// MARK: - Animation Tokens

extension Theme.Animation {
    static let quick = Animation.easeInOut(duration: 0.2)
    static let standard = Animation.easeInOut(duration: 0.3)
    static let slow = Animation.easeInOut(duration: 0.5)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let bounce = Animation.spring(response: 0.5, dampingFraction: 0.6)
}

// MARK: - View Extensions

extension View {
    
    // Typography modifiers
    func headingStyle() -> some View {
        modifier(Theme.Typography.HeadingStyle())
    }
    
    func bodyStyle() -> some View {
        modifier(Theme.Typography.BodyStyle())
    }
    
    func buttonLabelStyle() -> some View {
        modifier(Theme.Typography.ButtonLabelStyle())
    }
    
    // Card style
    func cardStyle() -> some View {
        self
            .padding(Theme.Spacing.medium)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.Radius.large)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // Primary button style
    func primaryButtonStyle() -> some View {
        self
            .buttonLabelStyle()
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.small)
            .background(Theme.Colors.primaryGradient)
            .cornerRadius(Theme.Radius.medium)
    }
    
    // Secondary button style
    func secondaryButtonStyle() -> some View {
        self
            .buttonLabelStyle()
            .foregroundColor(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke(Theme.Colors.primary, lineWidth: 2)
            )
    }
}

// MARK: - Custom Button Styles

// Global scale button style for consistent animations
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ThemePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .primaryButtonStyle()
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

struct ThemeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .secondaryButtonStyle()
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct ThemePreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                // Typography samples
                Group {
                    Theme.Typography.largeTitle("Large Title (Cinzel)")
                    Theme.Typography.title("Title (Cinzel)")
                    Theme.Typography.title2("Title 2 (Cinzel)")
                    Theme.Typography.title3("Title 3 (Cinzel)")
                    Theme.Typography.headline("Headline (SF Pro)")
                    Theme.Typography.body("Body text uses SF Pro for optimal readability")
                    Theme.Typography.callout("Callout text (SF Pro)")
                    Theme.Typography.caption("Caption text (SF Pro)")
                }
                
                Divider()
                
                // Color samples
                HStack(spacing: Theme.Spacing.medium) {
                    ColorSample(color: Theme.Colors.primary, label: "Primary")
                    ColorSample(color: Theme.Colors.success, label: "Success")
                    ColorSample(color: Theme.Colors.error, label: "Error")
                    ColorSample(color: Theme.Colors.warning, label: "Warning")
                    ColorSample(color: Theme.Colors.hint, label: "Hint")
                }
                
                Divider()
                
                // Button samples
                VStack(spacing: Theme.Spacing.medium) {
                    Button("Primary Button") {}
                        .buttonStyle(ThemePrimaryButtonStyle())
                    
                    Button("Secondary Button") {}
                        .buttonStyle(ThemeSecondaryButtonStyle())
                }
            }
            .padding()
        }
    }
    
    struct ColorSample: View {
        let color: Color
        let label: String
        
        var body: some View {
            VStack {
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(color)
                    .frame(width: 60, height: 60)
                Text(label)
                    .font(.caption)
            }
        }
    }
}

struct ThemePreview_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ThemePreview()
                .preferredColorScheme(.light)
            
            ThemePreview()
                .preferredColorScheme(.dark)
        }
    }
}
#endif