// HintHelpView.swift - Modern comprehensive help system with latest SwiftUI patterns

import SwiftUI

/// Comprehensive help system using modern SwiftUI navigation and layout
struct HintHelpView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss  // Modern dismiss pattern
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    // Modern data structure with comprehensive help content
    private let pages: [HelpPage] = [
        HelpPage(
            title: "Welcome to RuneWords",
            content: "Discover hidden words by tracing letters on the mystical wheel. Master powerful runes to reveal letters when you need guidance on your word-finding journey!",
            icon: "sparkles.rectangle.stack",
            color: .blue,
            details: ["Trace connected letters", "Find all target words", "Earn coins for progress"]
        ),
        HelpPage(
            title: "How to Play",
            content: "The art of word discovery combines intuition with strategy. Use the letter wheel to spell words and watch as your progress unfolds in the word slots above.",
            icon: "gamecontroller.fill",
            color: .green,
            details: [
                "Drag your finger across letters on the wheel",
                "Form valid English words of 3+ letters", 
                "Complete all target words to finish the level",
                "Find bonus words for extra coin rewards"
            ]
        ),
        HelpPage(
            title: "Rune of Clarity",
            content: "The most accessible of the ancient runes, Clarity illuminates a single hidden letter when the path forward seems unclear.",
            icon: "lightbulb.max.fill",
            color: .yellow,
            details: [
                "Cost: 25 coins",
                "Reveals one random letter",
                "Perfect for small hints",
                "Most economical option"
            ]
        ),
        HelpPage(
            title: "Rune of Precision", 
            content: "A strategic rune that focuses your energy on the shortest remaining word, revealing its first letter to guide your path.",
            icon: "target",
            color: .blue,
            details: [
                "Cost: 50 coins",
                "Reveals first letter of shortest word",
                "Strategic advantage",
                "Helps complete easier words first"
            ]
        ),
        HelpPage(
            title: "Rune of Momentum",
            content: "Harness the power of momentum to reveal multiple letters at once, breaking through the most challenging puzzles with force.",
            icon: "bolt.circle.fill",
            color: .purple,
            details: [
                "Cost: 75 coins", 
                "Reveals 3 random letters",
                "Great value for difficult levels",
                "Accelerates progress significantly"
            ]
        ),
        HelpPage(
            title: "Rune of Revelation",
            content: "The most powerful rune in your arsenal, capable of unveiling an entire word in a flash of mystical insight.",
            icon: "eye.circle.fill",
            color: .red,
            details: [
                "Cost: 125 coins",
                "Reveals complete word instantly", 
                "Ultimate problem solver",
                "Use when completely stuck"
            ]
        ),
        HelpPage(
            title: "Understanding Word Slots",
            content: "The sacred word slots above the wheel show your destiny - each number represents a letter position waiting to be revealed through your skill or the power of runes.",
            icon: "square.grid.3x3.square",
            color: .green,
            details: [
                "Numbers show letter positions (1, 2, 3...)",
                "Letters appear when revealed by runes",
                "Green checkmark shows completed words",
                "Visual progress tracking"
            ]
        )
    ]
    
    var body: some View {
        NavigationStack {  // Modern NavigationStack
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [.black, .gray.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Modern header with better accessibility
                    headerView
                    
                    // Page indicator with modern styling
                    pageIndicator
                    
                    // Content with modern TabView
                    contentTabView
                    
                    // Modern navigation controls
                    navigationControls
                }
            }
        }
        .presentationDetents([.large])  // Modern presentation style
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Modern View Components
    
    private var headerView: some View {
        HStack {
            Button("Skip") {
                isPresented = false
            }
            .foregroundStyle(.white.opacity(0.7))
            .accessibilityLabel("Skip tutorial")
            
            Spacer()
            
            Text("Rune Guide")
                .font(.custom("Cinzel-Bold", size: 20))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button("Done") {
                isPresented = false
            }
            .foregroundStyle(.white)
            .opacity(currentPage == pages.count - 1 ? 1.0 : 0.3)
            .accessibilityLabel("Complete tutorial")
        }
        .padding()
    }
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? .white : .white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
        .padding(.bottom, 20)
    }
    
    private var contentTabView: some View {
        TabView(selection: $currentPage) {
            ForEach(pages.indices, id: \.self) { index in
                HelpPageView(page: pages[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }
    
    private var navigationControls: some View {
        HStack(spacing: 20) {
            // Previous button with modern styling
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if currentPage > 0 {
                        currentPage -= 1
                    }
                }
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(currentPage > 0 ? .white : .white.opacity(0.3))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.white.opacity(currentPage > 0 ? 0.1 : 0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(currentPage == 0)
            .accessibilityLabel("Previous page")
            
            Spacer()
            
            // Next/Start button with dynamic content
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                    } else {
                        isPresented = false
                    }
                }
            } label: {
                Label {
                    Text(currentPage == pages.count - 1 ? "Start Playing" : "Next")
                } icon: {
                    Image(systemName: currentPage == pages.count - 1 ? "play.fill" : "chevron.right")
                }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.blue.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(currentPage == pages.count - 1 ? "Start playing game" : "Next page")
        }
        .padding()
    }
}

/// Modern help page with enhanced layout and animations
private struct HelpPageView: View {
    let page: HelpPage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ScrollView {  // Make content scrollable for accessibility
            VStack(spacing: 30) {
                // Modern icon with enhanced styling
                iconView
                
                // Title with better typography
                titleView
                
                // Main content with improved readability
                contentView
                
                // Details section with modern list styling
                if !page.details.isEmpty {
                    detailsView
                }
                
                Spacer(minLength: 40)
            }
            .padding(.top, 40)
            .padding(.horizontal, 30)
        }
    }
    
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(page.color.opacity(0.2))
                .frame(width: 120, height: 120)
            
            Image(systemName: page.icon)
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(page.color)
        }
        .scaleEffect(reduceMotion ? 1.0 : 1.1)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: page.title)
    }
    
    private var titleView: some View {
        Text(page.title)
            .font(.custom("Cinzel-Bold", size: 28))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
    }
    
    private var contentView: some View {
        Text(page.content)
            .font(.custom("Cinzel-Regular", size: 18))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .lineSpacing(8)
    }
    
    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(page.details.enumerated()), id: \.offset) { index, detail in
                HStack(alignment: .top, spacing: 12) {
                    // Modern bullet point
                    Circle()
                        .fill(page.color)
                        .frame(width: 6, height: 6)
                        .padding(.top, 8)
                    
                    Text(detail)
                        .font(.custom("Cinzel-Regular", size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.3))
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }
}

/// Modern data structure for help content
private struct HelpPage {
    let title: String
    let content: String
    let icon: String
    let color: Color
    let details: [String]
}

// MARK: - Enhanced Onboarding with Modern Patterns

/// Enhanced onboarding using latest SwiftUI features
struct EnhancedOnboardingView: View {
    let action: () -> Void
    @State private var showHelpGuide = false
    @State private var animateContent = false
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    var body: some View {
        ZStack {
            // Modern background with enhanced blur
            backgroundView
            
            // Content with modern layout and animations
            contentView
        }
        .sheet(isPresented: $showHelpGuide) {
            HintHelpView(isPresented: $showHelpGuide)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateContent = true
            }
        }
    }
    
    private var backgroundView: some View {
        Image("realm_treelibrary")
            .resizable()
            .scaledToFill()
            .overlay {
                Rectangle()
                    .fill(.black.opacity(0.4))
            }
            .blur(radius: 10)
            .ignoresSafeArea()
    }
    
    private var contentView: some View {
        VStack(spacing: 25) {
            // Header content with modern typography
            headerContent
            
            // Action buttons with enhanced styling
            actionButtons
        }
        .padding(30)
        .background {
            ZStack {
                BlurView()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.25))
            }
        }
        .padding(.horizontal, 40)
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0.0)
    }
    
    private var headerContent: some View {
        VStack(spacing: 16) {
            Text("Welcome to RuneWords")
                .font(.custom("Cinzel-Bold", size: 32))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                .multilineTextAlignment(.center)
            
            Text("Trace letters on the wheel to form words and complete the mystical word puzzles.")
                .font(.custom("Cinzel-Regular", size: 18))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
        }
        .frame(maxWidth: 400, alignment: .center)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // How to Play button with modern styling
            Button {
                showHelpGuide = true
            } label: {
                Label("How to Play", systemImage: "questionmark.circle.fill")
                    .font(.custom("Cinzel-Regular", size: 20))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(.blue.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .blue.opacity(0.3), radius: 8)
            }
            .accessibilityLabel("Learn how to play the game")
            
            // Start Playing button with enhanced appeal
            Button(action: action) {
                Label("Start Playing", systemImage: "play.fill")
                    .font(.custom("Cinzel-Regular", size: 22))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 15)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .white.opacity(0.5), radius: 10)
            }
            .accessibilityLabel("Start playing immediately")
        }
        .padding(.top)
    }
}

// MARK: - Quick Help Components

/// Modern help button for header integration
struct QuickHelpButton: View {
    @State private var showHelp = false
    
    var body: some View {
        Button {
            showHelp = true
        } label: {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityLabel("Open help guide")
        }
        .sheet(isPresented: $showHelp) {
            HintHelpView(isPresented: $showHelp)
        }
    }
}

/// Modern blur effect view
private struct BlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Modern Previews

#Preview("Help System") {
    HintHelpView(isPresented: .constant(true))
}

#Preview("Enhanced Onboarding") {
    EnhancedOnboardingView {
        print("Start playing tapped")
    }
}

#Preview("Quick Help Button") {
    ZStack {
        Color.black.ignoresSafeArea()
        QuickHelpButton()
    }
}
