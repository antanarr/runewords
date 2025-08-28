//
//  RealmMapComponents.swift
//  RuneWords
//
//  Reusable components for the realm map view
//

import SwiftUI

// Note: RealmLevel, JourneyLandmark, and MagicalWisp are defined in RealmMapModels.swift

// MARK: - Level Node View
struct LevelNodeView: View {
    let level: RealmLevel
    let isCurrent: Bool
    let onTap: () -> Void
    @State private var pulse = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Special level type background
                if level.levelType != .normal {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [level.levelType.color.opacity(0.8), level.levelType.color.opacity(0.3)],
                                center: .center,
                                startRadius: 0,
                                endRadius: nodeSize/2
                            )
                        )
                        .frame(width: nodeSize + 10, height: nodeSize + 10)
                        .scaleEffect(pulse && level.levelType == .boss ? 1.1 : 1.0)
                }
                
                // Node background
                nodeBackground
                    .frame(width: nodeSize, height: nodeSize)
                    .overlay(
                        Circle()
                            .stroke(nodeBorder, lineWidth: level.levelType == .boss ? 4 : 3)
                    )
                
                // Level type icon overlay
                if level.levelType != .normal {
                    levelTypeIcon
                }
                
                // Level content
                levelContent
                
                // Stars
                if level.stars > 0 {
                    StarsView(count: level.stars)
                        .offset(y: -35)
                }
                
                // Crown for perfect
                if level.hasCrown {
                    crownView
                }
                
                // Current level indicator
                if isCurrent {
                    currentLevelIndicator
                }
            }
        }
        .position(level.position)
        .disabled(!level.isUnlocked)
        .onAppear {
            startAnimations()
        }
    }
    
    private var nodeSize: CGFloat {
        let baseSize: CGFloat = level.levelType == .boss ? 80 : 60
        return isCurrent ? baseSize + 10 : baseSize
    }
    
    @ViewBuilder
    private var nodeBackground: some View {
        if !level.isUnlocked {
            Circle()
                .fill(Color.gray.opacity(0.5))
        } else if level.isCompleted {
            Circle()
                .fill(level.realm.color)
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [level.realm.color.opacity(0.8), level.realm.color.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
    
    private var nodeBorder: Color {
        if isCurrent {
            return .yellow
        } else if level.isCompleted {
            return .white
        } else if level.isUnlocked {
            return level.realm.color
        } else {
            return .gray
        }
    }
    
    private var levelTypeIcon: some View {
        Image(systemName: level.levelType.icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(level.levelType.color)
            .offset(x: 18, y: -18)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 20, height: 20)
            )
    }
    
    @ViewBuilder
    private var levelContent: some View {
        if level.levelType == .story {
            Image(systemName: "book.fill")
                .font(.system(size: 24))
                .foregroundColor(level.isUnlocked ? .white : .gray)
        } else {
            Text("\(level.id)")
                .font(.custom("Cinzel-Bold", size: level.levelType == .boss ? 24 : 20))
                .foregroundColor(level.isUnlocked ? .white : .gray)
        }
    }
    
    private var crownView: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: 16))
            .foregroundColor(.yellow)
            .offset(y: -50)
            .rotationEffect(.degrees(rotation))
    }
    
    private var currentLevelIndicator: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: nodeSize + 20, height: nodeSize + 20)
            .scaleEffect(pulse ? 1.1 : 1.0)
    }
    
    private func startAnimations() {
        if isCurrent {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        if level.hasCrown {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Stars View
struct StarsView: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(i < count ? .yellow : .gray)
            }
        }
    }
}

// MARK: - Magical Wisp View
struct MagicalWispView: View {
    let wisp: MagicalWisp
    let onTap: () -> Void
    @State private var floatOffset = CGSize.zero
    @State private var glowIntensity: Double = 0.5
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer glow
                if !wisp.isCollected {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [wisp.color.opacity(glowIntensity), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseScale)
                }
                
                // Main wisp
                Circle()
                    .fill(
                        RadialGradient(
                            colors: wisp.isCollected ? 
                                [Color.gray.opacity(0.3), Color.gray.opacity(0.1)] :
                                [wisp.color, wisp.color.opacity(0.6)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 12
                        )
                    )
                    .frame(width: wisp.isCollected ? 16 : 24, height: wisp.isCollected ? 16 : 24)
                    .shadow(color: wisp.isCollected ? .clear : wisp.color, radius: 4)
                    .scaleEffect(pulseScale)
            }
            .offset(floatOffset)
            .opacity(wisp.isCollected ? 0.4 : 1.0)
        }
        .position(wisp.position)
        .disabled(wisp.isCollected)
        .onAppear {
            if !wisp.isCollected {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            floatOffset = CGSize(
                width: CGFloat.random(in: -8...8),
                height: CGFloat.random(in: -12...12)
            )
        }
        
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
}

// MARK: - Journey Landmark View
struct JourneyLandmarkView: View {
    let landmark: JourneyLandmark
    let onTap: () -> Void
    @State private var glowIntensity: Double = 0.5
    @State private var floatOffset = CGSize.zero
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glow effect
                if !landmark.isDiscovered {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [landmark.realm.color.opacity(glowIntensity), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                }
                
                // Landmark structure
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: landmark.isDiscovered ? 
                                [landmark.realm.color, landmark.realm.color.opacity(0.7)] :
                                [.gray.opacity(0.6), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 40, height: 50)
                    .overlay(
                        Image(systemName: landmark.type.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(landmark.isDiscovered ? .white : .gray)
                    )
                    .shadow(color: landmark.isDiscovered ? landmark.realm.color.opacity(0.5) : .clear, radius: 4)
            }
            .offset(floatOffset)
            .opacity(landmark.isDiscovered ? 1.0 : 0.7)
        }
        .position(landmark.position)
        .disabled(landmark.isDiscovered)
        .onAppear {
            if !landmark.isDiscovered {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            floatOffset = CGSize(width: 0, height: -8)
        }
        
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }
}

// MARK: - Path Layer
struct PathLayer: View {
    let levels: [RealmLevel]
    
    var body: some View {
        ZStack {
            // Main journey path
            mainPath
            
            // Completed path highlight
            completedPath
            
            // Realm boundary markers
            realmBoundaries
        }
    }
    
    private var mainPath: some View {
        Path { path in
            guard !levels.isEmpty else { return }
            
            path.move(to: levels[0].position)
            
            for i in 1..<levels.count {
                let start = levels[i-1].position
                let end = levels[i].position
                let control1 = CGPoint(x: start.x + (end.x - start.x) * 0.3, y: start.y + 20)
                let control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y - 20)
                
                path.addCurve(to: end, control1: control1, control2: control2)
            }
        }
        .stroke(
            LinearGradient(
                colors: [.white.opacity(0.4), .yellow.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            ),
            style: StrokeStyle(lineWidth: 6, lineCap: .round)
        )
    }
    
    private var completedPath: some View {
        Path { path in
            guard !levels.isEmpty else { return }
            
            let completedLevels = levels.filter { $0.isCompleted }
            if completedLevels.isEmpty { return }
            
            path.move(to: levels[0].position)
            
            for i in 1..<levels.count {
                let level = levels[i]
                if !level.isCompleted { break }
                
                let start = levels[i-1].position
                let end = level.position
                let control1 = CGPoint(x: start.x + (end.x - start.x) * 0.3, y: start.y + 20)
                let control2 = CGPoint(x: start.x + (end.x - start.x) * 0.7, y: end.y - 20)
                
                path.addCurve(to: end, control1: control1, control2: control2)
            }
        }
        .stroke(
            LinearGradient(
                colors: [.yellow, .orange, .red],
                startPoint: .top,
                endPoint: .bottom
            ),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )
        .shadow(color: .yellow.opacity(0.5), radius: 2)
    }
    
    private var realmBoundaries: some View {
        ForEach([25, 50, 75], id: \.self) { boundary in
            if let level = levels.first(where: { $0.id == boundary }) {
                RealmBoundaryMarker(position: level.position, realm: level.realm)
            }
        }
    }
}

// MARK: - Realm Boundary Marker
struct RealmBoundaryMarker: View {
    let position: CGPoint
    let realm: RealmLevel.RealmType
    @State private var pulse: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(realm.color, lineWidth: 3)
                .frame(width: 80, height: 80)
                .scaleEffect(pulse ? 1.1 : 1.0)
                .opacity(0.6)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [realm.color.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
            
            Image(systemName: realm.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(realm.color)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 40, height: 40)
                )
        }
        .position(position)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Journey Progress Bar
struct JourneyProgressBar: View {
    let progress: Double
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Journey Progress")
                    .font(.custom("Cinzel-Bold", size: 14))
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.custom("Cinzel-Bold", size: 14))
                    .foregroundColor(.yellow)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 16)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * animatedProgress, height: 16)
                        .shadow(color: .blue.opacity(0.5), radius: 4, y: 2)
                    
                    // Milestone markers
                    HStack {
                        ForEach([0.25, 0.5, 0.75], id: \.self) { milestone in
                            Spacer()
                                .frame(width: geometry.size.width * milestone - 2)
                            Circle()
                                .fill(animatedProgress >= milestone ? .yellow : .white.opacity(0.5))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(height: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Realm Selector View
struct RealmSelectorView: View {
    @Binding var selectedRealm: RealmLevel.RealmType
    let onRealmSelected: (RealmLevel.RealmType) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(RealmLevel.RealmType.allCases, id: \.self) { realm in
                Button(action: { onRealmSelected(realm) }) {
                    VStack(spacing: 4) {
                        Image(systemName: realm.icon)
                            .font(.title2)
                            .foregroundColor(selectedRealm == realm ? .white : .gray)
                        
                        Text(realm.rawValue)
                            .font(.caption)
                            .foregroundColor(selectedRealm == realm ? .white : .gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedRealm == realm ? realm.color : Color.clear
                    )
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .padding()
    }
}
