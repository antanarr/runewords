import Foundation
import FirebaseFirestore
import Combine
import SwiftUI

@MainActor
final class PlayerService: ObservableObject {
    static let shared = PlayerService()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // Internal storage for the actual Player model
    @Published private var internalPlayer: Player?
    
    // Expose Player for view models with explicit publisher
    @Published var player: Player? {
        didSet {
            if let p = player {
                playerData = p.toPlayerData()
            } else {
                playerData = nil
            }
        }
    }
    
    // Protocol conformance - wrapper for PlayerData type
    @Published var playerData: PlayerData?
    
    // Explicit publisher for Combine subscriptions
    var playerPublisher: AnyPublisher<Player?, Never> {
        $player.eraseToAnyPublisher()
    }
    
    var playerDataPublisher: AnyPublisher<PlayerData?, Never> {
        $playerData.eraseToAnyPublisher()
    }
    
    // Private mappers
    private static func playerData(from p: Player) -> PlayerData {
        let completedIDs = Set(p.levelProgress.keys.compactMap { Int($0) })
        let usesHintsOften = p.totalLevelsCompleted > 0 ? 
            (Double(p.totalHintsUsed) / Double(p.totalLevelsCompleted)) > 1.5 : false
        let isStruggling = p.consecutiveFailedGuesses > 5
        
        return PlayerData(
            id: p.uid,
            completedLevelIDs: completedIDs,
            usesHintsOften: usesHintsOften,
            isStruggling: isStruggling,
            preferredDifficulty: p.preferredDifficulty,
            difficultyDrift: p.difficultyDrift,
            coins: p.coins,
            dailyStreak: p.dailyStreak,
            lastDailyDate: p.lastDailyDate,  // String? for daily challenge keys
            currentLevelID: p.currentLevelID,
            levelProgress: p.levelProgress,
            foundBonusWords: p.foundBonusWords,
            totalWordsFound: p.totalWordsFound,
            totalLevelsCompleted: p.totalLevelsCompleted,
            longestWordFound: p.longestWordFound,
            totalHintsUsed: p.totalHintsUsed,
            perfectLevels: p.perfectLevels,
            lastPlayedDate: p.lastPlayedDate,
            totalRevelationsUsed: p.totalRevelationsUsed,
            levelsPlayedSinceHint: p.levelsPlayedSinceHint,
            consecutiveFailedGuesses: p.consecutiveFailedGuesses,
            lastLevelDuration: p.lastLevelDuration
        )
    }
    
    private static func player(from d: PlayerData) -> Player {
        return Player(
            id: nil,  // Never set id when creating from PlayerData
            uid: d.id,
            currentLevelID: d.currentLevelID,
            coins: d.coins,
            levelProgress: d.levelProgress,
            foundBonusWords: d.foundBonusWords,
            lastPlayedDate: d.lastPlayedDate ?? Date(),
            lastDailyDate: d.lastDailyDate,
            dailyStreak: d.dailyStreak,
            totalHintsUsed: d.totalHintsUsed,
            totalLevelsCompleted: d.totalLevelsCompleted,
            preferredDifficulty: d.preferredDifficulty,
            totalRevelationsUsed: d.totalRevelationsUsed,
            levelsPlayedSinceHint: d.levelsPlayedSinceHint,
            consecutiveFailedGuesses: d.consecutiveFailedGuesses,
            difficultyDrift: d.difficultyDrift,
            lastLevelDuration: d.lastLevelDuration,
            totalWordsFound: d.totalWordsFound,
            longestWordFound: d.longestWordFound,
            perfectLevels: d.perfectLevels
        )
    }

    private var playerCollection: CollectionReference {
        return db.collection("players")
    }

    private init() {
        // Sync internal player to public player
        $internalPlayer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newPlayer in
                self?.player = newPlayer
            }
            .store(in: &cancellables)
            
        // Listen for the user ID from the AuthService
        AuthService.shared.$uid
            .compactMap { $0 } // Ensure userId is not nil
            .sink { [weak self] userId in
                self?.fetchOrCreatePlayer(userId: userId)
            }
            .store(in: &cancellables)
    }

    private func fetchOrCreatePlayer(userId: String) {
        let playerDocRef = playerCollection.document(userId)

        playerDocRef.getDocument { [weak self] document, error in
            // If the document exists, decode it into our Player model
            if let document = document, document.exists {
                do {
                    let playerModel = try document.data(as: Player.self)
                    self?.internalPlayer = playerModel
                    self?.playerData = playerModel.toPlayerData()
                    print("Player data fetched for user \(userId).")
                } catch {
                    print("Error decoding existing player document: \(error)")
                }
                return
            }
            
            if let error = error {
                 print("Error checking for player document: \(error)")
                 return
            }

            // If the document doesn't exist, create a new one for the new user
            print("Creating new player document for user \(userId)...")
            guard var player = self?.internalPlayer else {
                let newPlayer = Player(
                    id: nil,  // Never set @DocumentID manually
                    uid: userId,
                    currentLevelID: 1,
                    coins: 50,
                    levelProgress: [:],
                    foundBonusWords: [],
                    lastPlayedDate: Date(),
                    dailyStreak: 1,
                    totalHintsUsed: 0,
                    totalLevelsCompleted: 0,
                    preferredDifficulty: .easy,
                    totalRevelationsUsed: 0,
                    levelsPlayedSinceHint: 0,
                    consecutiveFailedGuesses: 0
                )
                do {
                    try playerDocRef.setData(from: newPlayer)
                    self?.internalPlayer = newPlayer
                    self?.playerData = newPlayer.toPlayerData()
                    print("Successfully created and fetched new player document.")
                } catch let error {
                    print("Error creating new player document: \(error)")
                }
                return
            }
            player.dailyStreak = 1
            do {
                try playerDocRef.setData(from: player)
                self?.internalPlayer = player
                self?.playerData = player.toPlayerData()
                print("Successfully created and fetched new player document.")
            } catch let error {
                print("Error creating new player document: \(error)")
            }
        }
    }
    
    // Saves the player's current progress to Firestore.
    func saveProgress(player: PlayerData) {
        guard let uid = AuthService.shared.uid else {
            print("Error: Could not save progress, no auth uid.")
            return
        }
        
        let playerDocRef = playerCollection.document(uid)
        
        do {
            // Convert PlayerData back to Player for storage
            var playerModel = Self.player(from: player)
            playerModel.id = nil  // Ensure we never write @DocumentID
            // Using merge: true prevents overwriting fields not included in the local Player struct,
            // which is safer for forward compatibility.
            try playerDocRef.setData(from: playerModel, merge: true)
            print("Player progress saved successfully to players/\(uid).")
        } catch {
            print("Error saving player progress: \(error)")
            // Do NOT navigate away on save failure - just log the error
        }
    }

    /// Generates a simplified PlayerData struct for adaptive level logic
    // Protocol methods implementation
    func initializePlayer() {
        // Already handled in fetchOrCreatePlayer
    }
    
    func updateCurrentLevel(_ levelID: Int) {
        guard var currentPlayer = self.internalPlayer else { return }
        currentPlayer.currentLevelID = levelID
        self.internalPlayer = currentPlayer
        saveProgress(player: Self.playerData(from: currentPlayer))
    }
    
    func addCoins(_ amount: Int) {
        guard var currentPlayer = self.internalPlayer else { return }
        currentPlayer.coins += amount
        self.internalPlayer = currentPlayer
        saveProgress(player: Self.playerData(from: currentPlayer))
    }
    
    func spendCoins(_ amount: Int) -> Bool {
        guard var currentPlayer = self.internalPlayer else { return false }
        if currentPlayer.coins >= amount {
            currentPlayer.coins -= amount
            self.internalPlayer = currentPlayer
            saveProgress(player: Self.playerData(from: currentPlayer))
            return true
        }
        return false
    }
    
    func generatePlayerData() -> PlayerData {
        guard let player = self.internalPlayer else {
            let uid = AuthService.shared.uid ?? ""
            return PlayerData(
                id: uid,
                completedLevelIDs: [],
                usesHintsOften: false,
                isStruggling: false,
                preferredDifficulty: .easy,
                difficultyDrift: 0,
                coins: 0,
                dailyStreak: 0,
                lastDailyDate: nil,
                currentLevelID: 1,
                levelProgress: [:],
                foundBonusWords: [],
                totalWordsFound: 0,
                totalLevelsCompleted: 0,
                longestWordFound: 0,
                totalHintsUsed: 0,
                perfectLevels: 0,
                lastPlayedDate: Date(),
                totalRevelationsUsed: 0,
                levelsPlayedSinceHint: 0,
                consecutiveFailedGuesses: 0,
                lastLevelDuration: nil
            )
        }

        return Self.playerData(from: player)
    }
    
    func update(player: PlayerData) {
        // This function exists to allow PlayerData-driven systems to influence the full Player model.
        self.playerData = player
        self.internalPlayer = player.toPlayer()
    }
    
    /// Call this when today's Daily Challenge level is completed.
    func markDailyChallengeCompleted() {
        guard var currentPlayer = self.internalPlayer else { return }
        DailyChallengeService.shared.recordCompletion(for: &currentPlayer)
        self.internalPlayer = currentPlayer
        self.playerData = currentPlayer.toPlayerData()
        saveProgress(player: Self.playerData(from: currentPlayer))
        // Unlock 7‑Day streak achievement via Game Center
        if currentPlayer.dailyStreak == 7 {
            GameCenterService.shared.unlock(.sevenDayStreak)
        }
    }
    
    func calculateDynamicDifficulty() -> Int {
        guard let player = self.internalPlayer else { return 0 }
        var modifier = 0
        
        // Time away adjustment (easier comeback)
        if let lastPlayed = player.lastPlayedDate {
            let daysSince = Date().timeIntervalSince(lastPlayed) / (24 * 60 * 60)
            if daysSince > 7 { modifier -= 2 }
            else if daysSince > 3 { modifier -= 1 }
        }
        
        // Performance adjustment  
        if let avgTime = player.lastLevelDuration {
            if avgTime < 60 { modifier += 2 }      // Very fast = much harder
            else if avgTime < 120 { modifier += 1 } // Fast = slightly harder
            else if avgTime > 300 { modifier -= 1 } // Slow = easier
        }
        
        // Streak bonus (confident players get harder levels)
        if player.dailyStreak > 7 { modifier += 1 }
        
        // Hint dependency (heavy hint users get easier levels)
        let hintsPerLevel = player.totalLevelsCompleted > 0 ? 
            Double(player.totalHintsUsed) / Double(player.totalLevelsCompleted) : 0
        if hintsPerLevel > 2 { modifier -= 1 }
        
        return max(-2, min(2, modifier)) // Cap at ±2 difficulty shifts
    }

    func selectLevelWithDynamicDifficulty(from levels: [Level]) -> Level? {
        guard let player = self.internalPlayer else { return levels.first }
        
        let dynamicModifier = calculateDynamicDifficulty()
        let difficulties = ["easy", "medium", "hard", "expert"]
        let baseIndex = difficulties.firstIndex(of: player.preferredDifficulty.rawValue) ?? 0
        let targetIndex = max(0, min(3, baseIndex + dynamicModifier))
        let targetDifficulty = difficulties[targetIndex]
        
        // Filter to target difficulty + unplayed levels
        let candidates = levels.filter { level in
            level.metadata?.difficulty.rawValue == targetDifficulty &&
            !player.levelProgress.keys.contains(String(level.id))
        }
        
        // Fallback chain if no candidates
        if !candidates.isEmpty {
            return candidates.randomElement()
        } else {
            // Try any unplayed level
            let anyUnplayed = levels.filter { level in
                !player.levelProgress.keys.contains(String(level.id))
            }
            return anyUnplayed.randomElement() ?? levels.randomElement()
        }
    }
}
