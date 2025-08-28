//
//  RealmGatingView.swift
//  RuneWords
//
//  WO-003: Realm gating logic and unlock requirements
//

import SwiftUI

// MARK: - Realm Gate Models

struct RealmGate: Identifiable {
    let id: String
    let realm: String
    let title: String
    let description: String
    let icon: String
    let requirements: [UnlockRequirement]
    var isUnlocked: Bool = false
    var progress: Double = 0.0
    
    enum UnlockRequirement {
        case levelsCompleted(realm: String, count: Int)
        case difficultyCompleted(difficulty: String, count: Int)
        
        var description: String {
            switch self {
            case .levelsCompleted(let realm, let count):
                return "Complete \(count) levels in \(realm.capitalized)"
            case .difficultyCompleted(let difficulty, let count):
                return "Complete \(count) \(difficulty.capitalized) difficulty levels"
            }
        }
    }
}

// MARK: - Realm Gating Service

@MainActor
class RealmGatingService: ObservableObject {
    @Published var gates: [RealmGate] = []
    @Published var playerProgress: [String: Int] = [:] // realm/difficulty -> count
    
    private let levelService = LevelService.shared
    
    init() {
        setupRealmGates()
        updateProgress()
    }
    
    private func setupRealmGates() {
        gates = [
            RealmGate(
                id: "crystalforest",
                realm: "crystalforest", 
                title: "Crystal Forest",
                description: "A mystical forest where crystalline formations resonate with word magic.",
                icon: "sparkles",
                requirements: [
                    .levelsCompleted(realm: "treelibrary", count: Config.Gameplay.crystalForestUnlockLevels),
                    .difficultyCompleted(difficulty: "medium", count: Config.Gameplay.mediumTierUnlockCount)
                ]
            ),
            RealmGate(
                id: "sleepingtitan",
                realm: "sleepingtitan",
                title: "Sleeping Titan", 
                description: "Ancient slumbering giant whose dreams shape reality through words.",
                icon: "flame.fill",
                requirements: [
                    .levelsCompleted(realm: "crystalforest", count: Config.Gameplay.sleepingTitanUnlockLevels),
                    .difficultyCompleted(difficulty: "hard", count: Config.Gameplay.hardTierUnlockCount)
                ]
            ),
            RealmGate(
                id: "astralpeak",
                realm: "astralpeak", 
                title: "Astral Peak",
                description: "The highest point where words transcend earthly bounds.",
                icon: "star.circle.fill",
                requirements: [
                    .levelsCompleted(realm: "sleepingtitan", count: Config.Gameplay.astralPeakUnlockLevels),
                    .difficultyCompleted(difficulty: "expert", count: Config.Gameplay.expertTierUnlockCount)
                ]
            )
        ]
    }
    
    func updateProgress() {
        // Mock player progress - in real app this would come from PlayerService
        playerProgress = [
            "treelibrary": 280,    // Enough to unlock Crystal Forest
            "crystalforest": 150,  // Not enough for Sleeping Titan (needs 200)
            "sleepingtitan": 0,
            "astralpeak": 0,
            "easy": 250,
            "medium": 120,         // Enough for Crystal Forest alternate path
            "hard": 5,             // Not enough for Sleeping Titan (needs 10)  
            "expert": 0
        ]
        
        // Update gate unlock status
        for i in gates.indices {
            gates[i].isUnlocked = checkUnlockStatus(for: gates[i])
            gates[i].progress = calculateProgress(for: gates[i])
        }
    }
    
    private func checkUnlockStatus(for gate: RealmGate) -> Bool {
        // Check if any requirement is satisfied (OR logic)
        return gate.requirements.contains { requirement in
            switch requirement {
            case .levelsCompleted(let realm, let count):
                return (playerProgress[realm] ?? 0) >= count
            case .difficultyCompleted(let difficulty, let count):
                return (playerProgress[difficulty] ?? 0) >= count
            }
        }
    }
    
    private func calculateProgress(for gate: RealmGate) -> Double {
        // Return highest progress toward any requirement
        let progresses = gate.requirements.map { requirement -> Double in
            switch requirement {
            case .levelsCompleted(let realm, let count):
                let current = playerProgress[realm] ?? 0
                return min(Double(current) / Double(count), 1.0)
            case .difficultyCompleted(let difficulty, let count):
                let current = playerProgress[difficulty] ?? 0
                return min(Double(current) / Double(count), 1.0)
            }
        }
        
        return progresses.max() ?? 0.0
    }
    
    func getFirstLevelID(in realm: String) -> Int? {
        return levelService.firstID(in: realm)
    }
}

// MARK: - Realm Selection View

struct RealmSelectionView: View {
    @StateObject private var gatingService = RealmGatingService()
    @State private var selectedGate: RealmGate?
    @State private var showRequirements = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color(red: 0.05, green: 0.02, blue: 0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Tree Library (always unlocked)
                        RealmGateView(
                            title: "Tree Library",
                            description: "Ancient repository of knowledge where your journey begins.",
                            icon: "tree.fill",
                            color: .green,
                            isUnlocked: true,
                            progress: 1.0,
                            onTap: {
                                navigateToRealm("treelibrary")
                            }
                        )
                        
                        // Gated Realms
                        ForEach(gatingService.gates) { gate in
                            RealmGateView(
                                title: gate.title,
                                description: gate.description,
                                icon: gate.icon,
                                color: colorForRealm(gate.realm),
                                isUnlocked: gate.isUnlocked,
                                progress: gate.progress,
                                onTap: {
                                    if gate.isUnlocked {
                                        navigateToRealm(gate.realm)
                                    } else {
                                        selectedGate = gate
                                        showRequirements = true
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Your Realm")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showRequirements) {
            if let gate = selectedGate {
                RealmRequirementsSheet(gate: gate, progress: gatingService.playerProgress)
            }
        }
    }
    
    private func colorForRealm(_ realm: String) -> Color {
        switch realm {
        case "crystalforest": return .blue
        case "sleepingtitan": return .orange
        case "astralpeak": return .pink
        default: return .gray
        }
    }
    
    private func navigateToRealm(_ realm: String) {
        // Navigate to first level in realm
        if let firstLevelID = gatingService.getFirstLevelID(in: realm) {
            // In real app, this would navigate to GameView with the specific level
            print("🎮 Navigate to Level \(firstLevelID) in \(realm)")
        }
    }
}

// MARK: - Realm Gate Component

struct RealmGateView: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    let progress: Double
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.5
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Gate Icon
                ZStack {
                    // Glow effect for unlocked gates
                    if isUnlocked {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [color.opacity(glowIntensity), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                    }
                    
                    // Main gate circle
                    Circle()
                        .fill(
                            isUnlocked ? 
                            LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(isUnlocked ? color : .gray, lineWidth: 3)
                        )
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(isUnlocked ? .white : .gray)
                    
                    // Lock overlay for locked gates
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                            .offset(x: 30, y: -30)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 30, height: 30)
                            )
                    }
                }
                
                // Title and Description
                VStack(spacing: 8) {
                    Text(title)
                        .font(.custom("Cinzel-Bold", size: 24))
                        .foregroundColor(isUnlocked ? .white : .gray)
                    
                    Text(description)
                        .font(.custom("Cinzel-Regular", size: 14))
                        .foregroundColor(isUnlocked ? .white.opacity(0.8) : .gray.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
                // Progress bar for locked gates
                if !isUnlocked && progress > 0 {
                    VStack(spacing: 4) {
                        Text("Progress: \(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progress, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isUnlocked ? color.opacity(0.5) : .gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            if isUnlocked {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.8
                }
            }
        }
    }
}

// MARK: - Requirements Sheet

struct RealmRequirementsSheet: View {
    let gate: RealmGate
    let progress: [String: Int]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Gate Icon
                Image(systemName: gate.icon)
                    .font(.system(size: 60))
                    .foregroundColor(colorForRealm(gate.realm))
                    .padding()
                
                // Title
                Text(gate.title)
                    .font(.custom("Cinzel-Bold", size: 28))
                    .foregroundColor(.white)
                
                Text("Realm Locked")
                    .font(.custom("Cinzel-Regular", size: 18))
                    .foregroundColor(.gray)
                
                // Requirements
                VStack(alignment: .leading, spacing: 16) {
                    Text("Unlock Requirements:")
                        .font(.custom("Cinzel-Bold", size: 20))
                        .foregroundColor(.white)
                    
                    Text("Complete ANY ONE of the following:")
                        .font(.custom("Cinzel-Regular", size: 14))
                        .foregroundColor(.yellow)
                    
                    ForEach(Array(gate.requirements.enumerated()), id: \.offset) { index, requirement in
                        RequirementRow(
                            requirement: requirement,
                            progress: progress,
                            index: index + 1
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(colorForRealm(gate.realm).opacity(0.3), lineWidth: 1)
                        )
                )
                
                Spacer()
                
                // Close button
                Button("Continue Journey") {
                    dismiss()
                }
                .font(.custom("Cinzel-Bold", size: 18))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(colorForRealm(gate.realm))
                .clipShape(Capsule())
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color(red: 0.05, green: 0.02, blue: 0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Unlock Requirements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func colorForRealm(_ realm: String) -> Color {
        switch realm {
        case "crystalforest": return .blue
        case "sleepingtitan": return .orange
        case "astralpeak": return .pink
        default: return .gray
        }
    }
}

struct RequirementRow: View {
    let requirement: RealmGate.UnlockRequirement
    let progress: [String: Int]
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Index number
            Text("\(index).")
                .font(.custom("Cinzel-Bold", size: 16))
                .foregroundColor(.yellow)
                .frame(width: 20, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                // Requirement description
                Text(requirement.description)
                    .font(.custom("Cinzel-Regular", size: 16))
                    .foregroundColor(.white)
                
                // Progress
                HStack(spacing: 8) {
                    Text(progressText)
                        .font(.custom("Cinzel-Regular", size: 14))
                        .foregroundColor(isComplete ? .green : .orange)
                    
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var progressText: String {
        switch requirement {
        case .levelsCompleted(let realm, let count):
            let current = progress[realm] ?? 0
            return "\(current) / \(count)"
        case .difficultyCompleted(let difficulty, let count):
            let current = progress[difficulty] ?? 0
            return "\(current) / \(count)"
        }
    }
    
    private var isComplete: Bool {
        switch requirement {
        case .levelsCompleted(let realm, let count):
            return (progress[realm] ?? 0) >= count
        case .difficultyCompleted(let difficulty, let count):
            return (progress[difficulty] ?? 0) >= count
        }
    }
}

#Preview {
    RealmSelectionView()
}