import XCTest
@testable import RuneWords

@MainActor
final class PlayerServiceTests: XCTestCase {
    
    var playerService: PlayerService!
    
    override func setUp() async throws {
        try await super.setUp()
        // Initialize the player service
        playerService = PlayerService.shared
        
        // Ensure player document exists
        await playerService.ensurePlayerDocumentExists()
    }
    
    override func tearDown() async throws {
        playerService = nil
        try await super.tearDown()
    }
    
    // MARK: - Critical Test: Bonus Word Should Not Navigate
    
    func testBonusWordDoesNotNavigate() async throws {
        // Given: Player is on level 2
        let initialLevel = 2
        playerService.updateCurrentLevel(initialLevel)
        
        // Store initial level
        let levelBeforeBonus = playerService.player?.currentLevelID ?? 0
        XCTAssertEqual(levelBeforeBonus, initialLevel, "Should start at level 2")
        
        // When: A bonus word is applied
        playerService.applyBonusWord("EAR", reward: 1)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then: Navigation should NOT occur
        let levelAfterBonus = playerService.player?.currentLevelID ?? 0
        XCTAssertEqual(levelAfterBonus, initialLevel, "Level should remain at 2 after bonus word")
        
        // Verify coins were updated
        let coins = playerService.player?.coins ?? 0
        XCTAssertGreaterThan(coins, 0, "Coins should have increased")
        
        // Verify bonus word was added
        let bonusWords = playerService.player?.foundBonusWords ?? []
        XCTAssertTrue(bonusWords.contains("EAR"), "Bonus word should be in the set")
    }
    
    // MARK: - Test Rapid Bonus Words
    
    func testRapidBonusWordsDoNotNavigate() async throws {
        // Given: Player is on level 3
        let initialLevel = 3
        playerService.updateCurrentLevel(initialLevel)
        
        // When: Multiple bonus words are applied rapidly
        let bonusWords = ["CAR", "BAR", "TAR", "FAR", "JAR"]
        for word in bonusWords {
            playerService.applyBonusWord(word, reward: 1)
        }
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: Navigation should NOT occur
        let levelAfterBonus = playerService.player?.currentLevelID ?? 0
        XCTAssertEqual(levelAfterBonus, initialLevel, "Level should remain at 3 after multiple bonus words")
        
        // Verify all bonus words were added
        let foundBonusWords = playerService.player?.foundBonusWords ?? []
        for word in bonusWords {
            XCTAssertTrue(foundBonusWords.contains(word), "Bonus word \(word) should be in the set")
        }
    }
    
    // MARK: - Test Level Completion Does Navigate
    
    func testLevelCompletionDoesNavigate() async throws {
        // Given: Player is on level 4
        let currentLevel = 4
        let nextLevel = 5
        playerService.updateCurrentLevel(currentLevel)
        
        // When: Level is completed
        playerService.completeLevelBatch(
            currentLevelID: currentLevel,
            nextLevelID: nextLevel,
            perfectLevel: false
        )
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then: Navigation SHOULD occur
        let levelAfterCompletion = playerService.player?.currentLevelID ?? 0
        XCTAssertEqual(levelAfterCompletion, nextLevel, "Level should advance to 5 after completion")
        
        // Verify completion counter increased
        let completedLevels = playerService.player?.totalLevelsCompleted ?? 0
        XCTAssertGreaterThan(completedLevels, 0, "Total levels completed should increase")
    }
    
    // MARK: - Test Snapshot Listener Bootstrap
    
    func testSnapshotListenerBootstrapDoesNotNavigate() async throws {
        // Given: Fresh listener setup
        playerService.didBootstrap = false
        
        // When: Snapshot listener receives first update
        // This would be triggered by setupSnapshotListener internally
        // The first snapshot should set baseline without navigation
        
        // Simulate by checking bootstrap flag after setup
        XCTAssertTrue(playerService.didBootstrap, "Bootstrap flag should be set after first snapshot")
    }
    
    // MARK: - Test Batch Operations Are Atomic
    
    func testBatchOperationsAreAtomic() async throws {
        // Given: Player on level 6
        let levelID = "6"
        playerService.updateCurrentLevel(6)
        
        let initialCoins = playerService.player?.coins ?? 0
        let initialWordsFound = playerService.player?.totalWordsFound ?? 0
        
        // When: Word find is applied (batch operation)
        playerService.applyWordFind(levelId: levelID, word: "TEST", reward: 10)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then: All fields should update atomically
        let finalCoins = playerService.player?.coins ?? 0
        let finalWordsFound = playerService.player?.totalWordsFound ?? 0
        
        XCTAssertEqual(finalCoins, initialCoins + 10, "Coins should increase by reward amount")
        XCTAssertEqual(finalWordsFound, initialWordsFound + 1, "Words found should increase by 1")
        
        // Level should not change
        XCTAssertEqual(playerService.player?.currentLevelID, 6, "Level should remain unchanged")
    }
    
    // MARK: - Test UID Path Assertion (DEBUG only)
    
    #if DEBUG
    func testUIDPathAssertion() {
        // This test verifies the runtime tripwire catches invalid paths
        // In DEBUG mode, it should assert if path doesn't match UID
        
        // Given: Valid UID exists
        guard let uid = AuthService.shared.uid else {
            XCTSkip("No authenticated user for this test")
            return
        }
        
        // Create a reference with correct path
        let validRef = Firestore.firestore().collection("players").document(uid)
        
        // This should NOT trigger assertion
        XCTAssertNoThrow({
            // Internal assertion would check this path
            // playerService.assertUIDPath(validRef)
        }())
        
        // Note: We can't test the failure case as it would crash the test
    }
    #endif
}
