//
//  RealmMapViewRefactored.swift
//  RuneWords
//
//  Simplified realm map view using extracted components and view model
//

import SwiftUI

struct RealmMapView: View {
    @StateObject private var viewModel = RealmMapViewModel()
    @State private var selectedLevel: RealmLevel?
    @State private var showLevelDetail = false
    @State private var mapScale: CGFloat = 1.0
    @State private var mapOffset: CGSize = .zero
    @State private var showCollectionView = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Dynamic background
            RealmBackgroundLayer(realm: viewModel.selectedRealm)
            
            // Map content
            mapContent
            
            // UI Overlay
            overlayUI
        }
        .sheet(isPresented: $showLevelDetail) {
            if let level = selectedLevel {
                LevelDetailView(level: level)
            }
        }
        .sheet(isPresented: $showCollectionView) {
            CollectionView(wisps: viewModel.wisps)
        }
        .sheet(isPresented: $viewModel.showingStoryModal) {
            if let storyLevel = viewModel.selectedStoryLevel {
                StoryModalView(level: storyLevel) {
                    selectedLevel = storyLevel
                    showLevelDetail = true
                    viewModel.showingStoryModal = false
                }
            }
        }
    }
    
    // MARK: - Map Content
    private var mapContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack {
                    // Path connecting levels
                    PathLayer(levels: viewModel.levels)
                    
                    // Journey Landmarks
                    ForEach(viewModel.landmarks) { landmark in
                        JourneyLandmarkView(
                            landmark: landmark,
                            onTap: { viewModel.discoverLandmark(landmark) }
                        )
                    }
                    
                    // Magical Wisps
                    ForEach(viewModel.wisps) { wisp in
                        MagicalWispView(
                            wisp: wisp,
                            onTap: { viewModel.collectWisp(wisp) }
                        )
                    }
                    
                    // Level nodes
                    ForEach(viewModel.levels) { level in
                        LevelNodeView(
                            level: level,
                            isCurrent: level.id == viewModel.currentLevelID,
                            onTap: {
                                handleLevelTap(level)
                            }
                        )
                        .id(level.id)
                    }
                }
                .frame(width: UIScreen.main.bounds.width, height: CGFloat(viewModel.levels.count) * 120 + 200)
                .scaleEffect(mapScale)
                .offset(mapOffset)
            }
            .onAppear {
                withAnimation {
                    proxy.scrollTo(viewModel.currentLevelID, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Overlay UI
    private var overlayUI: some View {
        VStack {
            // Header with journey progress
            JourneyMapHeaderView(
                totalStars: viewModel.totalStars,
                totalWisps: viewModel.totalWisps,
                journeyProgress: viewModel.journeyProgress,
                currentLevel: viewModel.currentLevelID,
                onCollectionTap: { showCollectionView = true },
                onCloseTap: { dismiss() }
            )
            
            Spacer()
            
            // Realm selector
            RealmSelectorView(
                selectedRealm: $viewModel.selectedRealm,
                onRealmSelected: { realm in
                    withAnimation(.spring()) {
                        viewModel.selectedRealm = realm
                        // Could add scrolling to realm functionality here
                    }
                }
            )
        }
    }
    
    // MARK: - Actions
    private func handleLevelTap(_ level: RealmLevel) {
        guard level.isUnlocked else { return }
        
        if level.levelType == .story && level.storyText != nil {
            viewModel.showStoryForLevel(level)
        } else {
            selectedLevel = level
            showLevelDetail = true
        }
    }
}

// MARK: - Supporting Views

struct RealmBackgroundLayer: View {
    let realm: RealmLevel.RealmType
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: gradientColors(for: realm),
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            
            // Parallax layers
            ParallaxLayer(imageName: backgroundImage(for: realm), speed: 0.5)
            ParallaxLayer(imageName: foregroundImage(for: realm), speed: 0.8)
                .opacity(0.3)
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
    
    private func gradientColors(for realm: RealmLevel.RealmType) -> [Color] {
        switch realm {
        case .treeLibrary:
            return [.green.opacity(0.8), .green, .green.opacity(0.6)]
        case .crystalForest:
            return [.blue.opacity(0.8), .blue, .blue.opacity(0.6)]
        case .sleepingTitan:
            return [.orange.opacity(0.8), .orange, .orange.opacity(0.6)]
        case .astralPeak:
            return [.pink.opacity(0.8), .pink, .pink.opacity(0.6)]
        }
    }
    
    private func backgroundImage(for realm: RealmLevel.RealmType) -> String {
        switch realm {
        case .treeLibrary: return "realm_treelibrary"
        case .crystalForest: return "realm_crystalforest"
        case .sleepingTitan: return "realm_sleepingtitan"
        case .astralPeak: return "realm_astralpeak"
        }
    }
    
    private func foregroundImage(for realm: RealmLevel.RealmType) -> String {
        backgroundImage(for: realm)
    }
}

struct ParallaxLayer: View {
    let imageName: String
    let speed: CGFloat
    
    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
    }
}

struct JourneyMapHeaderView: View {
    let totalStars: Int
    let totalWisps: Int
    let journeyProgress: Double
    let currentLevel: Int
    let onCollectionTap: () -> Void
    let onCloseTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Top row with close button and stats
            HStack {
                Button(action: onCloseTap) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Current level
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.yellow)
                    Text("Level \(currentLevel)")
                        .font(.custom("Cinzel-Bold", size: 18))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
                
                Spacer()
                
                // Progress indicators
                HStack(spacing: 16) {
                    // Stars
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(totalStars)")
                            .font(.custom("Cinzel-Bold", size: 16))
                            .foregroundColor(.white)
                    }
                    
                    // Wisps
                    Button(action: onCollectionTap) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(RadialGradient(colors: [.cyan, .blue], center: .center, startRadius: 2, endRadius: 8))
                                .frame(width: 16, height: 16)
                            Text("\(totalWisps)")
                                .font(.custom("Cinzel-Bold", size: 16))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
            }
            
            // Journey progress bar
            JourneyProgressBar(progress: journeyProgress)
        }
        .padding()
    }
}

struct LevelDetailView: View {
    let level: RealmLevel
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToGame = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Level icon
                ZStack {
                    Circle()
                        .fill(level.realm.color)
                        .frame(width: 100, height: 100)
                    
                    Text("\(level.id)")
                        .font(.custom("Cinzel-Bold", size: 40))
                        .foregroundColor(.white)
                }
                
                // Realm info
                Text(level.realm.rawValue)
                    .font(.custom("Cinzel-Bold", size: 24))
                
                // Stars
                StarsView(count: level.stars)
                    .scaleEffect(2)
                    .padding()
                
                // Play button
                Button {
                    navigateToGame = true
                } label: {
                    Text(level.isCompleted ? "Replay Level" : "Play Level")
                        .font(.custom("Cinzel-Bold", size: 20))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(level.realm.color)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Level \(level.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $navigateToGame) {
                GameView()
            }
        }
    }
}

struct StoryModalView: View {
    let level: RealmLevel
    let onPlayLevel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var textOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    level.realm.color.opacity(0.8),
                    level.realm.color.opacity(0.4),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Realm icon
                Image(systemName: level.realm.icon)
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(level.realm.color)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 120, height: 120)
                    )
                    .scaleEffect(titleScale)
                
                // Story title
                Text("Level \(level.id) - \(level.realm.rawValue)")
                    .font(.custom("Cinzel-Bold", size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                
                // Story text
                ScrollView {
                    Text(level.storyText ?? "")
                        .font(.custom("Cinzel-Regular", size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 32)
                        .opacity(textOpacity)
                }
                .frame(maxHeight: 200)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    Button("Continue Reading") {
                        dismiss()
                    }
                    .font(.custom("Cinzel-Bold", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.6))
                    .clipShape(Capsule())
                    
                    Button("Play Level") {
                        onPlayLevel()
                    }
                    .font(.custom("Cinzel-Bold", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(level.realm.color)
                    .clipShape(Capsule())
                    .shadow(color: level.realm.color.opacity(0.5), radius: 8)
                }
                .opacity(textOpacity)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                titleScale = 1.0
            }
            
            withAnimation(.easeIn(duration: 1.0).delay(0.3)) {
                textOpacity = 1.0
            }
        }
    }
}

struct CollectionView: View {
    let wisps: [MagicalWisp]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                    ForEach(wisps) { wisp in
                        VStack {
                            Circle()
                                .fill(RadialGradient(colors: [wisp.rarity.color, wisp.rarity.color.opacity(0.3)], center: .center, startRadius: 2, endRadius: 20))
                                .frame(width: 40, height: 40)
                                .opacity(wisp.isCollected ? 1.0 : 0.3)
                            
                            Text("Level \(wisp.levelID)")
                                .font(.caption)
                                .foregroundColor(wisp.isCollected ? .white : .gray)
                            
                            Text(wisp.rarity == .legendary ? "★★★" : wisp.rarity == .epic ? "★★" : wisp.rarity == .rare ? "★" : "")
                                .font(.caption2)
                                .foregroundColor(wisp.rarity.color)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Wisp Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    RealmMapView()
}
