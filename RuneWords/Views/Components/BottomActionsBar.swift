import SwiftUI

/// Adaptive bottom actions bar that always fits on all device sizes
/// On compact width (≤375pt): horizontal scroll with compact buttons (44-48pt tall)
/// On wider devices: simple HStack with equal widths
/// Essential actions first: Shuffle, Hints, Clarity, Precision. Others in "More" menu if needed.
struct BottomActionsBar: View {
    let shuffleAction: () -> Void
    let hintsAction: () -> Void
    let clarityAction: () -> Void
    let precisionAction: () -> Void
    let momentumAction: () -> Void
    let revealAction: () -> Void
    
    let clarityCost: Int
    let precisionCost: Int
    let momentumCost: Int
    let revealCost: Int
    
    let clarityAffordable: Bool
    let precisionAffordable: Bool
    let momentumAffordable: Bool
    let revealAffordable: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width <= 375 {
                // Compact width: horizontal scroll with compact buttons
                compactActionsBar
            } else {
                // Wide width: simple HStack with all actions
                wideActionsBar
            }
        }
        .frame(minHeight: 64, maxHeight: 90) // FIXED: Flexible height based on requirements
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0.6)],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
    
    // MARK: - Compact Actions Bar (ScrollView)
    private var compactActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Essential actions (always visible)
                essentialActions
                
                // More actions in menu for space efficiency
                moreActionsMenu
            }
            .padding(.horizontal, 16)  // FIXED: Proper padding to prevent cut-off
        }
    }
    
    // MARK: - Wide Actions Bar (HStack)
    private var wideActionsBar: some View {
        HStack(spacing: 8) {
            // All actions visible with equal widths
            allActions
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Essential Actions (Always Visible on Compact)
    private var essentialActions: some View {
        HStack(spacing: 8) {
            // Shuffle button (always free)
            ActionButton(
                title: "Shuffle",
                icon: "arrow.2.circlepath",
                subtitle: "Free",
                color: .purple,
                isAffordable: true,
                size: .compact,
                action: shuffleAction
            )
            
            // Help button (always available)
            ActionButton(
                title: "Hints",
                icon: "questionmark.circle.fill",
                subtitle: "Help",
                color: .yellow,
                isAffordable: true,
                size: .compact,
                action: hintsAction
            )
            
            // Clarity button (main hint)
            ActionButton(
                title: "Clarity",
                icon: "lightbulb.max.fill",
                subtitle: "\(clarityCost)",
                color: .yellow,
                isAffordable: clarityAffordable,
                size: .compact,
                action: clarityAction
            )
            
            // Precision button (word-specific hint)
            ActionButton(
                title: "Precision",
                icon: "target",
                subtitle: "\(precisionCost)",
                color: .blue,
                isAffordable: precisionAffordable,
                size: .compact,
                action: precisionAction
            )
        }
    }
    
    // MARK: - All Actions (For Wide Screens)
    private var allActions: some View {
        HStack(spacing: 8) {
            // Essential actions
            ActionButton(
                title: "Shuffle",
                icon: "arrow.2.circlepath",
                subtitle: "Free",
                color: .purple,
                isAffordable: true,
                size: .normal,
                action: shuffleAction
            )
            
            ActionButton(
                title: "Hints",
                icon: "questionmark.circle.fill",
                subtitle: "Help",
                color: .yellow,
                isAffordable: true,
                size: .normal,
                action: hintsAction
            )
            
            ActionButton(
                title: "Clarity",
                icon: "lightbulb.max.fill",
                subtitle: "\(clarityCost)",
                color: .yellow,
                isAffordable: clarityAffordable,
                size: .normal,
                action: clarityAction
            )
            
            ActionButton(
                title: "Precision",
                icon: "target",
                subtitle: "\(precisionCost)",
                color: .blue,
                isAffordable: precisionAffordable,
                size: .normal,
                action: precisionAction
            )
            
            // Additional actions for wide screens
            ActionButton(
                title: "Momentum",
                icon: "bolt.circle.fill",
                subtitle: "\(momentumCost)",
                color: .orange,
                isAffordable: momentumAffordable,
                size: .normal,
                action: momentumAction
            )
            
            ActionButton(
                title: "Reveal",
                icon: "eye.circle.fill",
                subtitle: "\(revealCost)",
                color: .red,
                isAffordable: revealAffordable,
                size: .normal,
                action: revealAction
            )
        }
    }
    
    // MARK: - More Actions Menu (For Compact)
    @ViewBuilder
    private var moreActionsMenu: some View {
        Menu {
            Button {
                momentumAction()
            } label: {
                Label("Momentum (\(momentumCost) coins)", systemImage: "bolt.circle.fill")
            }
            .disabled(!momentumAffordable)
            
            Button {
                revealAction()
            } label: {
                Label("Reveal (\(revealCost) coins)", systemImage: "eye.circle.fill")
            }
            .disabled(!revealAffordable)
        } label: {
            ActionButton(
                title: "More",
                icon: "ellipsis.circle.fill",
                subtitle: "",
                color: .gray,
                isAffordable: true,
                size: .compact,
                action: {}
            )
        }
    }
}

// MARK: - Action Button Component
private struct ActionButton: View {
    let title: String
    let icon: String
    let subtitle: String
    let color: Color
    let isAffordable: Bool
    let size: ButtonSize
    let action: () -> Void
    
    enum ButtonSize {
        case compact // 44-48pt tall for compact screens
        case normal  // Full size for wide screens
    }
    
    private var buttonWidth: CGFloat {
        switch size {
        case .compact: return 70 // FIXED: Wider for better touch targets and spacing
        case .normal: return 75
        }
    }
    
    private var buttonHeight: CGFloat {
        switch size {
        case .compact: return 70 // FIXED: Taller for better usability and balance
        case .normal: return 75
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .compact: return 26 // FIXED: Larger icons for visibility
        case .normal: return 28
        }
    }
    
    private var titleFont: Font {
        switch size {
        case .compact: return .system(size: 11, weight: .medium) // FIXED: More readable
        case .normal: return .system(size: 12, weight: .medium)
        }
    }
    
    private var subtitleFont: Font {
        switch size {
        case .compact: return .system(size: 10, weight: .semibold) // FIXED: More readable
        case .normal: return .system(size: 11, weight: .semibold)
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(isAffordable ? color : .gray)
                
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if !subtitle.isEmpty {
                    HStack(spacing: 2) {
                        if subtitle != "Free" && subtitle != "Help" && !subtitle.isEmpty {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(.yellow.opacity(0.8))
                        }
                        Text(subtitle)
                            .font(subtitleFont)
                            .foregroundStyle(isAffordable ? .white : .gray)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: buttonWidth, height: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(isAffordable ? 0.25 : 0.1))
                    .strokeBorder(color.opacity(isAffordable ? 0.5 : 0.2), lineWidth: 1)
            )
        }
        .disabled(!isAffordable && title != "Shuffle" && title != "Hints" && title != "More")
        .accessibilityLabel(title)
        .accessibilityHint(isAffordable ? "Double tap to use \(title.lowercased())" : "Not enough coins for \(title.lowercased())")
        .scaleEffect(isAffordable ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.15), value: isAffordable)
    }
}

// MARK: - Preview
struct BottomActionsBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Compact width preview (iPhone SE)
            VStack {
                Spacer()
                BottomActionsBar(
                    shuffleAction: {},
                    hintsAction: {},
                    clarityAction: {},
                    precisionAction: {},
                    momentumAction: {},
                    revealAction: {},
                    clarityCost: 25,
                    precisionCost: 50,
                    momentumCost: 75,
                    revealCost: 125,
                    clarityAffordable: true,
                    precisionAffordable: false,
                    momentumAffordable: true,
                    revealAffordable: false
                )
                .padding(.bottom, 16)
            }
            .frame(width: 375, height: 667)
            .background(Color.black)
            .previewDisplayName("Compact (375pt) - iPhone SE")
            
            // Wide width preview (iPhone Pro Max)
            VStack {
                Spacer()
                BottomActionsBar(
                    shuffleAction: {},
                    hintsAction: {},
                    clarityAction: {},
                    precisionAction: {},
                    momentumAction: {},
                    revealAction: {},
                    clarityCost: 25,
                    precisionCost: 50,
                    momentumCost: 75,
                    revealCost: 125,
                    clarityAffordable: true,
                    precisionAffordable: true,
                    momentumAffordable: true,
                    revealAffordable: true
                )
                .padding(.bottom, 16)
            }
            .frame(width: 430, height: 932)
            .background(Color.black)
            .previewDisplayName("Wide (430pt) - iPhone Pro Max")
        }
        .preferredColorScheme(.dark)
    }
}
