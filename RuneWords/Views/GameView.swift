// GameView.swift - Optimized Version with Fixes
// Addresses: Menu overlay pattern, background visibility, layout optimization

import SwiftUI
import UIKit

// MARK: - Modern Shake Effect
struct GameShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)), 
                y: 0
            )
        )
    }
}

// MARK: - Main Game View - Fixed Architecture
struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss  // For dismissing when in sheet
    @EnvironmentObject private var storeVM: StoreViewModel
    @EnvironmentObject private var appState: AppState

    // Navigation state - simplified
    @State private var showBonusWords = false
    @State private var showSettings = false
    @State private var showStore = false
    @State private var showPauseMenu = false
    
    // Track if we're in Daily Challenge mode (shown as sheet)
    var isDailyChallenge: Bool = false
    
    // UI state
    @State private var previousBonusCount = 0
    @State private var showBonusBanner = false
    @State private var shuffleRotation = 0.0
    @State private var isShuffling = false
    @State private var showHintExplanation = false
    @State private var bonusWordAnimation = false
    @State private var isLoadingLevel = true
    
    // Pill-to-boxes animation state
    @Namespace private var animNS
    @State private var animatingWord: String? = nil
    @State private var slotAnchors: [String: Anchor<CGRect>] = [:]
    
    init(isDailyChallenge: Bool = false) {
        _viewModel = StateObject(wrappedValue: GameViewModel())
        self.isDailyChallenge = isDailyChallenge
    }
    
    init(viewModel: GameViewModel, isDailyChallenge: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.isDailyChallenge = isDailyChallenge
    }

    private var overlayActive: Bool {
        viewModel.isLevelComplete || showBonusWords || showSettings || 
        showStore || showPauseMenu
    }
    
    // MARK: - Background Image Selection
    private var realmBackgroundImage: String {
        switch viewModel.currentLevel?.metadata?.difficulty {
        case .easy:
            return "realm_treelibrary"  
        case .medium:
            return "realm_sleepingtitan"  
        case .hard:
            return "realm_crystalforest"   
        case .expert:
            return "realm_astralpeak"  
        default:
            return "realm_treelibrary"  
        }
    }

    var body: some View {
        ZStack {
            // FIXED: Clean background with minimal overlay
            Image(realmBackgroundImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // FIXED: Ultra-light vignette for maximum visibility
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.03)  // Even lighter
                ],
                center: .center,
                startRadius: 250,
                endRadius: 600
            )
            .ignoresSafeArea()
            
            // Runtime truth badge (helpful for debugging catalog source)
            VStack {
                HStack {
                    Text("Source: \(viewModel.levelService.currentCatalogSource.rawValue.uppercased()) · \(viewModel.levelService.totalLevelCount)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding([.top, .leading], 8)
                    Spacer()
                }
                Spacer()
            }
            
            // Main content 
            GeometryReader { geometry in
                if isLoadingLevel {
                    loadingView
                } else {
                    // FIXED: Optimized layout with better spacing
                    VStack(spacing: 0) { // No spacing - control each gap individually
                        // Header
                        HeaderView(
                            coins: viewModel.playerCoins,
                            animateCoinGain: $viewModel.animateCoinGain,
                            settingsAction: { showSettings = true },
                            storeAction: { showStore = true },
                            pauseAction: { showPauseMenu = true }
                        )
                        .padding(.horizontal, 16)
                        .safeAreaPadding(.top)  // Proper safe area handling for header
                    
                        // Words board - MAXIMIZE this area
                        WordsBoardView(
                            targets: viewModel.targetWords,
                            found: viewModel.foundWords,
                            animatingWord: animatingWord,
                            animationNamespace: animNS
                        ) { anchors in
                            slotAnchors = anchors
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .frame(maxHeight: .infinity) // Take all available space
                    
                        // Bonus chip - moved closer to pill
                        HStack {
                            BonusChip(
                                bonusCount: viewModel.bonusWordsFound.count,
                                animNS: animNS,
                                onTap: {
                                    if !viewModel.bonusWordsFound.isEmpty {
                                        showBonusWords = true
                                    }
                                }
                            )
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6) // Small gap between board and pill
                    
                        // Current guess display
                        CurrentGuessPill(
                            guess: viewModel.currentGuess,
                            isForming: !viewModel.currentGuessIndices.isEmpty,
                            animatingWord: animatingWord,
                            animationNamespace: animNS
                        )
                        .padding(.bottom, 8)
                    
                        // Wheel section
                        wheelSection(geometry: geometry)
                            .padding(.bottom, 8)
                    }
                    // RW PATCH: Add identity based on current level
                    .id(viewModel.currentLevel?.id ?? 0)
                    // FIXED: Removed excessive blur - use proper sheet presentation
                    .animation(.easeOut(duration: 0.3), value: overlayActive)
                }
                
                // Overlays
                overlaySystem
            }
        }
        // Bottom actions bar with proper safe area handling
        .safeAreaInset(edge: .bottom) {
            BottomActionsBar(
                shuffleAction: performShuffle,
                hintsAction: { showHintExplanation = true },
                clarityAction: viewModel.useHint,
                precisionAction: viewModel.usePrecision,
                momentumAction: { viewModel.useMomentum() },
                revealAction: viewModel.useRevelation,
                clarityCost: viewModel.hintCost,
                precisionCost: viewModel.precisionCost,
                momentumCost: viewModel.momentumCost,
                revealCost: viewModel.revelationCost,
                clarityAffordable: viewModel.clarityAffordable,
                precisionAffordable: viewModel.precisionAffordable,
                momentumAffordable: viewModel.momentumAffordable,
                revealAffordable: viewModel.playerCoins >= viewModel.revelationCost
            )
            .background(Color.clear)
        }
        // RW PATCH: Use transition with scale and opacity
        .overlay {
            if viewModel.isLevelComplete {
                LevelCompleteView(
                    coinsEarned: viewModel.levelCompleteReward,
                    onContinue: {
                        viewModel.advanceToNextLevelWithReset()
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.isLevelComplete)
        .sheet(isPresented: $showStore) {
            StoreView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHintExplanation) {
            HintExplanationView(isPresented: $showHintExplanation)
        }
        // FIXED: Pause menu as proper overlay
        .fullScreenCover(isPresented: $showPauseMenu) {
            ZStack {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showPauseMenu = false
                    }
                
                PauseMenuView(
                    isPresented: $showPauseMenu,
                    currentLevel: viewModel.currentLevel?.id ?? 1,
                    wordsFound: viewModel.foundWords.count,
                    totalWords: viewModel.currentLevel?.solutions.count ?? 0,
                    onRestart: {
                        viewModel.resetLevel()
                        HapticManager.shared.play(.medium)
                    },
                    onExitToMenu: {
                        // FIX: Handle exit properly based on context
                        showPauseMenu = false  // Always close pause menu first
                        
                        if isDailyChallenge {
                            // In Daily Challenge: Just dismiss the sheet
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                dismiss()
                            }
                        } else {
                            // In regular game: Navigate to main menu
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                appState.navigate(to: .mainMenu)
                            }
                        }
                    }
                )
            }
            .background(BackgroundBlurView())
        }
        .onReceive(viewModel.$bonusWordsFound) { newBonusWords in
            handleBonusWordAnimation(newBonusWords)
        }
        .onReceive(viewModel.$animatingWordToSlot) { word in
            if let word = word {
                triggerSlotAnimation(word: word)
            }
        }
        .onReceive(viewModel.$animatingWordToBonus) { word in
            if let word = word {
                triggerBonusAnimation(word: word)
            }
        }
        .task {
            await viewModel.prepareForPlay()
            isLoadingLevel = false
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Loading Level...")
                .font(.custom("Cinzel-Regular", size: 18))
                .foregroundStyle(.white)
                .padding(.top, 16)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))  // FIXED: Simple opacity for loading view
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Wheel Section - FIXED sizing
    private func wheelSection(geometry: GeometryProxy) -> some View {
        let safeWidth = geometry.size.width - 32
        
        // FIXED: Consistent wheel size that doesn't compete with words board
        let wheelSize = min(
            safeWidth * 0.75,      // Reasonable horizontal space
            300                     // Fixed reasonable max
        ).clamped(to: 260...300)   // Smaller range to give more room to words
        
        if UIAccessibility.isVoiceOverRunning {
            return AnyView(
                AccessibleLetterWheel(
                    letters: viewModel.letterWheel,
                    selectedIndices: Set(viewModel.currentGuessIndices),
                    onLetterTap: { index in
                        if viewModel.letterWheel.indices.contains(index) {
                            viewModel.selectLetter(at: index)
                        }
                    }
                )
                .frame(width: wheelSize, height: wheelSize)
                .frame(maxWidth: .infinity)
            )
        } else {
            return AnyView(
                GameLetterWheelView(
                    letters: $viewModel.letterWheel,
                    currentGuess: $viewModel.currentGuess,
                    currentGuessIndices: $viewModel.currentGuessIndices,
                    onGestureEnd: viewModel.submitGuess,
                    isShuffling: isShuffling,
                    wheelSize: wheelSize
                )
                .frame(width: wheelSize, height: wheelSize)
                .frame(maxWidth: .infinity)
            )
        }
    }
    
    // MARK: - Overlay System (simplified)
    @ViewBuilder
    private var overlaySystem: some View {
        // Tutorial overlay (coach marks)
        if appState.shouldShowCoachmarks() {
            InteractiveTutorialView(isPresented: Binding(
                get: { appState.shouldShowCoachmarks() },
                set: { _ in 
                    appState.completeCoachmarks()
                }
            ))
            .transition(.opacity)
            .zIndex(200)
        }
        
        // Bonus word notification
        if showBonusBanner {
            BonusWordNotification(
                wordCount: viewModel.bonusWordsFound.count,
                coinsEarned: 5
            )
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .zIndex(100)
        }
        
        // Achievement overlay
        if let achievement = viewModel.showAchievementUnlock {
            AchievementUnlockView(achievement: achievement)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
        }
        
        // Bonus words list
        if showBonusWords {
            BonusWordsListView(
                words: Array(viewModel.bonusWordsFound),
                isPresented: $showBonusWords
            )
            .transition(.opacity)
            .zIndex(98)
        }
    }
    
    // MARK: - Helper Methods
    private func performShuffle() {
        HapticManager.shared.play(.light)
        AudioManager.shared.playSound(effect: .shuffle)
        
        isShuffling = true
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.shuffleLetters()
            shuffleRotation += 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isShuffling = false
        }
    }
    
    private func triggerSlotAnimation(word: String) {
        animatingWord = word
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            // matchedGeometryEffect handles the visual transition
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animatingWord = nil
        }
    }
    
    private func triggerBonusAnimation(word: String) {
        animatingWord = "BONUS"
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            // matchedGeometryEffect flies to bonus chip
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animatingWord = nil
        }
    }
    
    private func handleBonusWordAnimation(_ newBonusWords: Set<String>) {
        let newCount = newBonusWords.count
        if previousBonusCount < newCount {
            bonusWordAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                bonusWordAnimation = false
            }
            
            showBonusBanner = true
            HapticManager.shared.play(.success)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showBonusBanner = false
            }
        }
        previousBonusCount = newCount
    }
}

// MARK: - Background Blur View
struct BackgroundBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Supporting Components (keeping existing implementations)

struct BonusChip: View {
    let bonusCount: Int
    let animNS: Namespace.ID
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.yellow)
                
                Text("Bonus Words Found")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if bonusCount > 0 {
                    Text("\(bonusCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.2))  // FIXED: Simple opacity instead of material
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08))
                    )
            )
        }
        .disabled(bonusCount == 0)
        .background {
            Text("BONUS")
                .opacity(0)
                .matchedGeometryEffect(id: "BONUS", in: animNS)
        }
        .accessibilityLabel("Bonus words found: \(bonusCount)")
        .accessibilityHint(bonusCount > 0 ? "Double tap to view bonus words" : "No bonus words found yet")
    }
}

struct HeaderView: View {
    let coins: Int
    @Binding var animateCoinGain: Bool
    let settingsAction: () -> Void
    let storeAction: () -> Void
    let pauseAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: pauseAction) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedCircleShadow(color: .black.opacity(0.3), blur: 2, y: 1)
            }
            .accessibilityLabel("Pause game")
            
            Spacer()
            
            Text("RUNEWORDS")
                .font(.custom("Cinzel-Bold", size: 22))
                .foregroundStyle(.white)
                .fixedCircleShadow(color: .black.opacity(0.3), blur: 2, y: 1, cornerRadius: 4)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image("icon_coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                
                Text("\(coins)")
                    .font(.custom("Cinzel-Bold", size: 20))
                    .foregroundStyle(.white)
                    .scaleEffect(animateCoinGain ? 1.3 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.3), value: animateCoinGain)
                
                Button(action: storeAction) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.yellow)
                }
                .accessibilityLabel("Open store")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.black.opacity(0.15))  // FIXED: Much lighter coin badge
            )
        }
    }
}

// Rest of components remain the same...
// (GameLetterWheelView, CurrentGuessPill, BonusWordNotification, etc.)

struct GameLetterWheelView: View {
    @Binding var letters: [WheelLetter]
    @Binding var currentGuess: String
    @Binding var currentGuessIndices: [Int]
    let onGestureEnd: () -> Void
    var isShuffling: Bool = false
    var wheelSize: CGFloat = 280
    
    // Hit detection constants
    private let tileDiameter: CGFloat = 55  // matches WheelTileView
    private var hitRadius: CGFloat { tileDiameter * 0.45 }  // ≈ 24.75
    
    @State private var selectedIndices: [Int] = []
    @State private var linePoints: [CGPoint] = []
    @State private var pillState: PillState = .neutral
    
    enum PillState {
        case neutral
        case valid
        case invalid
    }
    @State private var positionsInitialized: Bool = false
    @State private var letterPositions: [CGPoint] = []

    var body: some View {
        let center = CGPoint(x: wheelSize / 2, y: wheelSize / 2)
        let radius = wheelSize * 0.35
        let traceColor = Color.yellow.opacity(0.7) // Always full opacity during drag
        
        let drag = DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard let index = letterIndex(at: value.location, radius: hitRadius) else { return }
                
                // Simple hysteresis: only switch tiles when clearly closer to the new one
                if let last = selectedIndices.last, index != last {
                    let lastPos = letterPositions[last]
                    let newPos = letterPositions[index]
                    let distToLast = hypot(value.location.x - lastPos.x, value.location.y - lastPos.y)
                    let distToNew = hypot(value.location.x - newPos.x, value.location.y - newPos.y)
                    
                    // Require ~6pt advantage to switch
                    guard distToNew + 6 < distToLast else { return }
                }
                
                if let last = selectedIndices.last, index == last {
                    return
                }
                if selectedIndices.count >= 2 && index == selectedIndices[selectedIndices.count - 2] {
                    selectedIndices.removeLast()
                    updateGuessAndLine()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    return
                }
                if !selectedIndices.contains(index) {
                    selectedIndices.append(index)
                    updateGuessAndLine()
                    AudioManager.shared.playSound(effect: .selectLetter)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                // Keep pill neutral while dragging
                pillState = .neutral
            }
            .onEnded { _ in
                // Validate once at finger-up
                if !currentGuess.isEmpty {
                    let normalizedGuess = DictionaryService.normalizeWord(currentGuess)
                    let isValid = DictionaryService.shared.isValidWord(normalizedGuess)
                    pillState = isValid ? .valid : .invalid
                    
                    // Provide feedback based on validation
                    if pillState == .invalid {
                        HapticManager.shared.play(.error)
                    } else {
                        HapticManager.shared.play(.light)
                    }
                }
                
                onGestureEnd()
                
                // Clear state after brief delay for visual feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    selectedIndices.removeAll()
                    linePoints.removeAll()
                    pillState = .neutral
                }
            }

        ZStack {
            // Removed wheel backing for cleaner look

            Path { path in
                if !linePoints.isEmpty {
                    path.move(to: linePoints[0])
                    for i in 1..<linePoints.count {
                        path.addLine(to: linePoints[i])
                    }
                }
            }
            .stroke(traceColor, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

            ForEach(letters.indices, id: \.self) { index in
                if index < letters.count && index < letterPositions.count {
                    let isSelected = selectedIndices.contains(index)
                    WheelTileView(letter: letters[index], isSelected: isSelected)
                        .position(letterPositions[index])
                        .rotationEffect(isShuffling ? Angle(degrees: 360) : .zero)
                        .animation(.easeInOut(duration: 0.5), value: isShuffling)
                }
            }
        }
        .frame(width: wheelSize, height: wheelSize)
        .gesture(drag)
        .onAppear {
            initializePositions(center: center, radius: radius)
        }
        .onChange(of: letters) { _, _ in
            initializePositions(center: center, radius: radius)
        }
    }
    
    private func initializePositions(center: CGPoint, radius: CGFloat) {
        guard !letters.isEmpty else { return }
        
        let angleStep = (2 * .pi) / CGFloat(6)
        letterPositions = (0..<min(letters.count, 6)).map { i in
            let angle = angleStep * CGFloat(i) - (.pi / 2)
            return CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }
        
        // Update letter positions
        for i in 0..<min(letters.count, letterPositions.count) {
            letters[i].position = letterPositions[i]
        }
        
        positionsInitialized = true
    }

    private func letterIndex(at point: CGPoint, radius: CGFloat) -> Int? {
        guard !letterPositions.isEmpty else { return nil }
        
        for (index, position) in letterPositions.enumerated() {
            let distance = hypot(point.x - position.x, point.y - position.y)
            if distance < radius {
                return index
            }
        }
        return nil
    }
    
    private func updateGuessAndLine() {
        currentGuess = selectedIndices.map { String(letters[$0].char) }.joined()
        currentGuessIndices = selectedIndices.map { letters[$0].originalIndex }
        linePoints = selectedIndices.compactMap { 
            $0 < letterPositions.count ? letterPositions[$0] : nil
        }
        // No validation during drag - keep pill neutral
    }
}

private struct WheelTileView: View {
    let letter: WheelLetter
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.yellow.opacity(0.3) : Color(red: 0.106, green: 0.102, blue: 0.188))
                .frame(width: 55, height: 55)
            
            Circle()
                .stroke(isSelected ? Color.yellow : Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 55, height: 55)
            
            Text(String(letter.char))
                .font(.custom("Cinzel-Bold", size: 26))
                .foregroundColor(.white)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .fixedCircleShadow(
            color: isSelected ? .yellow.opacity(0.4) : .black.opacity(0.2), 
            blur: isSelected ? 8 : 4
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .accessibilityLabel("Letter \(letter.char)")
        .accessibilityHint(isSelected ? "Selected" : "Available")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CurrentGuessPill: View {
    let guess: String
    let isForming: Bool
    let animatingWord: String?
    let animationNamespace: Namespace.ID
    @State private var bounce = false
    @State private var pulseAnimation = false
    @State private var showHint = true
    @State private var hasInteracted = false

    var body: some View {
        let isValidPrefix = guess.isEmpty || DictionaryService.shared.hasPrefix(guess)
        let shouldShowHint = guess.isEmpty && showHint && !hasInteracted
        let displayText = shouldShowHint ? "Drag to form words" : guess.uppercased()
        let isPlaceholder = guess.isEmpty
        
        HStack(spacing: 4) {
            if isForming && !guess.isEmpty {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            
            Text(displayText)
                .font(.custom(isPlaceholder ? "Cinzel-Regular" : "Cinzel-Bold", size: isPlaceholder ? 16 : 24))
                .kerning(isPlaceholder ? 0 : 2)
                .foregroundColor(isPlaceholder ? .white.opacity(0.5) : .white)
                .animation(.easeInOut(duration: 0.15), value: guess)
                .matchedGeometryEffect(
                    id: guess.uppercased().isEmpty ? "EMPTY_PILL" : guess.uppercased(),
                    in: animationNamespace,
                    properties: .frame,
                    anchor: .center,
                    isSource: animatingWord == nil
                )
            
            if !guess.isEmpty {
                Text("(\(guess.count))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, guess.isEmpty ? 16 : 24)
        .padding(.vertical, guess.isEmpty ? 8 : 12)
        .frame(minWidth: 200)
        .background(
            Capsule()
                .fill(Color.black.opacity(isPlaceholder ? 0.3 : 0.6))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            borderColor(isValidPrefix: isValidPrefix, isEmpty: guess.isEmpty),
                            lineWidth: guess.isEmpty ? 1 : 2
                        )
                )
        )
        .fixedCircleShadow(
            color: shadowColor(isValidPrefix: isValidPrefix, isEmpty: guess.isEmpty),
            blur: guess.isEmpty ? 3 : 8,
            cornerRadius: 50
        )
        .scaleEffect(bounce ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: bounce)
        .onChange(of: guess) { oldValue, newValue in
            if !newValue.isEmpty {
                hasInteracted = true
                if oldValue != newValue {
                    bounce = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { 
                        bounce = false 
                    }
                }
            }
        }
        .onAppear {
            pulseAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showHint = false
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(guess.isEmpty ? "Word formation area" : "Current word: \(guess)")
    }
    
    private func borderColor(isValidPrefix: Bool, isEmpty: Bool) -> Color {
        if isEmpty {
            return Color.white.opacity(0.2)
        } else if isValidPrefix {
            return Color.green.opacity(0.8)
        } else {
            return Color.red.opacity(0.8)
        }
    }
    
    private func shadowColor(isValidPrefix: Bool, isEmpty: Bool) -> Color {
        if isEmpty {
            return Color.clear
        } else if isValidPrefix {
            return Color.green.opacity(0.3)
        } else {
            return Color.red.opacity(0.3)
        }
    }
}

struct BonusWordNotification: View {
    let wordCount: Int
    let coinsEarned: Int
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bonus Word!")
                        .font(.custom("Cinzel-Bold", size: 20))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Image("icon_coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text("+\(coinsEarned)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.yellow)
                    }
                }
                
                Spacer()
                
                Text("\(wordCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.orange))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.85))
                    .strokeBorder(.yellow.opacity(0.3), lineWidth: 1)
            )
            .fixedCircleShadow(color: .black.opacity(0.3), blur: 10, y: 5, cornerRadius: 16)
            .padding(.horizontal)
            .padding(.top, 60)
            
            Spacer()
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

struct BonusWordsListView: View {
    let words: [String]
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Bonus Words")
                    .font(.custom("Cinzel-Bold", size: 28))
                    .foregroundStyle(.white)
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                        ForEach(words.sorted(), id: \.self) { word in
                            Text(word.uppercased())
                                .font(.custom("Cinzel-Regular", size: 18))
                                .foregroundStyle(.white)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.yellow.opacity(0.2))
                                        .strokeBorder(.yellow.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 400)
                
                Button("Close") {
                    isPresented = false
                }
                .font(.custom("Cinzel-Bold", size: 18))
                .foregroundStyle(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(.white)
                .clipShape(Capsule())
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.95))
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 40)
        }
    }
}

// Helper extension
extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - SwiftUI Previews
#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    GameView()
        .environmentObject(StoreViewModel.shared)
        .environmentObject(AppState.shared)
}

#Preview("iPhone 15 Pro", traits: .fixedLayout(width: 393, height: 852)) {
    GameView()
        .environmentObject(StoreViewModel.shared)
        .environmentObject(AppState.shared)
}
