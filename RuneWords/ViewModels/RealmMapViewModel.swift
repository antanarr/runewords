//
//  RealmMapViewModel.swift
//  RuneWords
//
//  View model for realm map progression and state management
//

import Foundation
import SwiftUI
import Combine

// MARK: - View Model
@MainActor
final class RealmMapViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var levels: [RealmLevel] = []
    @Published var wisps: [MagicalWisp] = []
    @Published var currentLevelID: Int = 1
    @Published var totalStars: Int = 0
    @Published var totalWisps: Int = 0
    @Published var landmarks: [JourneyLandmark] = []
    @Published var selectedRealm: RealmLevel.RealmType = .treeLibrary
    @Published var scrollPosition: CGFloat = 0
    @Published var showingStoryModal: Bool = false
    @Published var selectedStoryLevel: RealmLevel?
    @Published var journeyProgress: Double = 0
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadLevelData()
        setupBindings()
    }
    
    // MARK: - Public Methods
    func collectWisp(_ wisp: MagicalWisp) {
        guard var player = PlayerService.shared.player else { return }
        
        // Mark as collected
        if let index = wisps.firstIndex(where: { $0.id == wisp.id }) {
            wisps[index].isCollected = true
        }
        
        // Award coins based on rarity
        let reward: Int
        switch wisp.rarity {
        case .common: reward = 10
        case .rare: reward = 25
        case .epic: reward = 50
        case .legendary: reward = 100
        }
        
        player.coins += reward
        player.foundBonusWords.insert("wisp_\(wisp.levelID)")
        PlayerService.shared.player = player
        PlayerService.shared.saveProgress(player: player.toPlayerData())
        
        // Show collection animation
        HapticManager.shared.play(.success)
        Log.game("Collected wisp at level \(wisp.levelID) for \(reward) coins")
    }
    
    func showStoryForLevel(_ level: RealmLevel) {
        selectedStoryLevel = level
        showingStoryModal = true
    }
    
    func discoverLandmark(_ landmark: JourneyLandmark) {
        if let index = landmarks.firstIndex(where: { $0.id == landmark.id }) {
            landmarks[index].isDiscovered = true
            HapticManager.shared.play(.medium)
            Log.game("Discovered landmark: \(landmark.title)")
        }
    }
    
    func isCompleted(levelID: Int) -> Bool {
        guard let player = PlayerService.shared.player else { return false }
        return player.levelProgress[String(levelID)] != nil
    }
    
    func getStars(for levelID: Int) -> Int {
        guard let player = PlayerService.shared.player,
              let progress = player.levelProgress[String(levelID)] else { return 0 }
        
        // Award stars based on completion percentage
        let completionRate = Float(progress.count) / Float(10) // Assuming 10 words per level
        if completionRate >= 1.0 { return 3 }
        if completionRate >= 0.8 { return 2 }
        if completionRate >= 0.5 { return 1 }
        return 0
    }
    
    // MARK: - Private Methods
    private func loadLevelData() {
        var currentPosition = CGPoint(x: 200, y: 100)
        let baseSpacing: CGFloat = 100
        
        for i in 1...100 {
            let realm = determineRealm(for: i)
            let difficulty = determineDifficulty(for: i)
            let levelType = determineLevelType(for: i)
            let storyText = getStoryText(for: i, levelType: levelType)
            
            // Create path variation
            let pathVariation = createPathVariation(for: i, realm: realm)
            currentPosition.x += pathVariation.x
            currentPosition.y += baseSpacing + pathVariation.y
            
            let level = RealmLevel(
                id: i,
                position: currentPosition,
                realm: realm,
                difficulty: difficulty,
                levelType: levelType,
                isUnlocked: i <= PlayerService.shared.player?.currentLevelID ?? 1,
                isCompleted: isCompleted(levelID: i),
                stars: getStars(for: i),
                hasWisp: hasWisp(at: i),
                hasCrown: hasCrown(at: i),
                storyText: storyText
            )
            levels.append(level)
            
            // Add wisps at special levels
            if i % 10 == 0 {
                addWisp(at: i, position: currentPosition, realm: realm)
            }
            
            // Add landmarks at realm boundaries
            if i == 1 || i == 26 || i == 51 || i == 76 {
                let landmark = createLandmark(for: i, realm: realm, position: currentPosition)
                landmarks.append(landmark)
            }
        }
        
        updateJourneyProgress()
    }
    
    private func determineRealm(for level: Int) -> RealmLevel.RealmType {
        switch level {
        case 1...25: return .treeLibrary
        case 26...50: return .crystalForest
        case 51...75: return .sleepingTitan
        default: return .astralPeak
        }
    }
    
    private func determineDifficulty(for level: Int) -> Difficulty {
        switch level {
        case 1...25: return .easy
        case 26...50: return .medium
        case 51...75: return .hard
        default: return .expert
        }
    }
    
    private func determineLevelType(for level: Int) -> RealmLevel.LevelType {
        if level % 25 == 0 { return .boss }
        if level % 10 == 0 { return .story }
        if level % 15 == 0 { return .challenge }
        if level % 20 == 0 { return .bonus }
        return .normal
    }
    
    private func getStoryText(for level: Int, levelType: RealmLevel.LevelType) -> String? {
        if levelType == .boss {
            return getBossStoryText(for: level)
        } else if levelType == .story {
            return getRegularStoryText(for: level)
        }
        return nil
    }
    
    private func getRegularStoryText(for level: Int) -> String {
        switch level {
        case 10: return "You discover an ancient scroll revealing the first secrets of word magic..."
        case 20: return "The librarian's ghost whispers tales of forgotten lexicons..."
        case 30: return "Crystal formations begin to resonate with your growing vocabulary..."
        case 40: return "The forest spirits acknowledge your linguistic prowess..."
        case 60: return "Deep rumbles suggest the Titan stirs in its eternal slumber..."
        case 70: return "You feel the weight of ancient words pressing down from above..."
        case 80: return "The astral winds carry echoes of cosmic vocabularies..."
        case 90: return "Reality itself bends to the power of your accumulated words..."
        default: return "The journey continues, each word a step toward mastery..."
        }
    }
    
    private func getBossStoryText(for level: Int) -> String {
        switch level {
        case 25: return "The Library's Guardian awakens, challenging your knowledge with ancient riddles..."
        case 50: return "The Crystal Heart pulses with power, testing your resolve with complex patterns..."
        case 75: return "The Sleeping Titan's dreams become reality, manifesting word-puzzles of immense difficulty..."
        case 100: return "At the Astral Peak, you face the ultimate test of your word mastery..."
        default: return "A powerful entity guards this realm, ready to test your skills..."
        }
    }
    
    private func createPathVariation(for level: Int, realm: RealmLevel.RealmType) -> CGPoint {
        switch realm {
        case .treeLibrary:
            // Gentle winding path
            return CGPoint(
                x: CGFloat(sin(Double(level) * 0.3)) * 40,
                y: CGFloat.random(in: -20...20)
            )
        case .crystalForest:
            // Zigzag crystal formation
            return CGPoint(
                x: (level % 2 == 0) ? 60 : -60,
                y: CGFloat.random(in: -10...30)
            )
        case .sleepingTitan:
            // Ascending spiral
            let angle = Double(level - 50) * 0.4
            return CGPoint(
                x: CGFloat(cos(angle)) * 80,
                y: CGFloat(sin(angle)) * 20 + 40
            )
        case .astralPeak:
            // Steep mountainous ascent
            return CGPoint(
                x: CGFloat.random(in: -100...100),
                y: CGFloat.random(in: 40...80)
            )
        }
    }
    
    private func addWisp(at level: Int, position: CGPoint, realm: RealmLevel.RealmType) {
        let wisp = MagicalWisp(
            levelID: level,
            position: CGPoint(
                x: position.x + CGFloat.random(in: -50...50),
                y: position.y + CGFloat.random(in: -30...30)
            ),
            color: realm.color,
            isCollected: isWispCollected(at: level),
            rarity: determineWispRarity(for: level)
        )
        wisps.append(wisp)
    }
    
    private func determineWispRarity(for level: Int) -> MagicalWisp.Rarity {
        if level % 25 == 0 { return .legendary }
        if level % 15 == 0 { return .epic }
        if level % 10 == 0 { return .rare }
        return .common
    }
    
    private func createLandmark(for level: Int, realm: RealmLevel.RealmType, position: CGPoint) -> JourneyLandmark {
        let landmarkPosition = CGPoint(
            x: position.x + CGFloat.random(in: -80...80),
            y: position.y + CGFloat.random(in: -60...0)
        )
        
        switch realm {
        case .treeLibrary:
            return JourneyLandmark(
                position: landmarkPosition,
                type: .library,
                realm: realm,
                title: "The Great Library",
                description: "Ancient tomes of forgotten words await discovery.",
                isDiscovered: level <= (PlayerService.shared.player?.currentLevelID ?? 1)
            )
        case .crystalForest:
            return JourneyLandmark(
                position: landmarkPosition,
                type: .shrine,
                realm: realm,
                title: "Crystal Shrine",
                description: "Resonating crystals amplify the power of words.",
                isDiscovered: level <= (PlayerService.shared.player?.currentLevelID ?? 1)
            )
        case .sleepingTitan:
            return JourneyLandmark(
                position: landmarkPosition,
                type: .monument,
                realm: realm,
                title: "Titan's Monument",
                description: "A colossal guardian slumbers beneath.",
                isDiscovered: level <= (PlayerService.shared.player?.currentLevelID ?? 1)
            )
        case .astralPeak:
            return JourneyLandmark(
                position: landmarkPosition,
                type: .tower,
                realm: realm,
                title: "Astral Observatory",
                description: "Where words transcend earthly bounds.",
                isDiscovered: level <= (PlayerService.shared.player?.currentLevelID ?? 1)
            )
        }
    }
    
    private func updateJourneyProgress() {
        let completedLevels = levels.filter { $0.isCompleted }.count
        journeyProgress = Double(completedLevels) / Double(levels.count)
    }
    
    private func setupBindings() {
        PlayerService.shared.$player
            .compactMap { $0 }
            .sink { [weak self] player in
                self?.currentLevelID = player.currentLevelID
                self?.updateProgress()
            }
            .store(in: &cancellables)
    }
    
    private func updateProgress() {
        // Update unlocked states
        for i in levels.indices {
            levels[i].isUnlocked = levels[i].id <= currentLevelID
            levels[i].isCompleted = isCompleted(levelID: levels[i].id)
            levels[i].stars = getStars(for: levels[i].id)
        }
        
        // Update total counts
        totalStars = levels.reduce(0) { $0 + $1.stars }
        totalWisps = wisps.filter { $0.isCollected }.count
        
        updateJourneyProgress()
    }
    
    private func hasWisp(at levelID: Int) -> Bool {
        wisps.contains { $0.levelID == levelID && $0.isCollected }
    }
    
    private func hasCrown(at levelID: Int) -> Bool {
        // Crown for perfect completion
        getStars(for: levelID) == 3
    }
    
    private func isWispCollected(at levelID: Int) -> Bool {
        // Check player's collected wisps
        guard let player = PlayerService.shared.player else { return false }
        return player.foundBonusWords.contains("wisp_\(levelID)")
    }
}
