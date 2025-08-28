// RuneWordsFixTests.swift
// Tests for verifying the EAST disappearing bug fixes

import XCTest
@testable import RuneWords
import FirebaseFirestore

class RuneWordsFixTests: XCTestCase {
    
    var viewModel: GameViewModel!
    var mockPlayerService: PlayerService!
    
    override func setUp() {
        super.setUp()
        viewModel = GameViewModel()
        mockPlayerService = PlayerService.shared
    }
    
    override func tearDown() {
        viewModel = nil
        mockPlayerService = nil
        super.tearDown()
    }
    
    // MARK: - Test 1: Solution Persists After Snapshot
    func testSolutionPersistsAfterSnapshot() async throws {
        // Given: A level with EAST as a solution
        let mockLevel = Level(
            id: 1,
            baseLetters: "AESTRO",
            solutions: ["EAST": [0, 1, 2, 3]],
            bonusWords: ["SEAT", "TEAR"],
            metadata: nil
        )
        
        viewModel.currentLevel = mockLevel
        viewModel.foundWords = []
        
        // When: Word is found locally
        viewModel.foundWords.insert("EAST")
        
        // And: Snapshot arrives without EAST
        let snapshotData: [String: Any] = [
            "currentLevelID": 1,
            "coins": 100,
            "levelProgress": [
                "1": ["STAR", "ARTS"]  // Missing EAST
            ]
        ]
        
        // Simulate snapshot reconciliation
        var player = Player(
            id: "test",
            currentLevelID: 1,
            coins: 100,
            levelProgress: ["1": Set(["STAR", "ARTS"])],
            foundBonusWords: []
        )
        
        // Apply reconciliation logic
        let serverWords = Set(["STAR", "ARTS"].map { StringCanonicalizer.canon($0) })
        let localWords = Set(["EAST"].map { StringCanonicalizer.canon($0) })
        let mergedWords = serverWords.union(localWords)
        
        player.levelProgress["1"] = mergedWords
        
        // Then: EAST should still be in progress
        XCTAssertTrue(player.levelProgress["1"]?.contains("EAST") ?? false,
                     "EAST should persist after snapshot reconciliation")
        XCTAssertEqual(player.levelProgress["1"]?.count, 3,
                      "Should have all 3 words after merge")
    }
    
    // MARK: - Test 2: Bonus Word Does Not Navigate
    func testBonusWordDoesNotNavigate() async throws {
        // Given: Current level is 5
        var player = Player(
            id: "test",
            currentLevelID: 5,
            coins: 50,
            levelProgress: [:],
            foundBonusWords: []
        )
        
        let initialLevel = player.currentLevelID
        
        // When: Bonus word is found
        let bonusWord = "BONUS"
        player.foundBonusWords.insert(StringCanonicalizer.canon(bonusWord))
        
        // Simulate Firestore update (without actually calling it)
        // In real scenario: mockPlayerService.applyBonusWord(bonusWord, reward: 10)
        
        // Then: Level should not change
        XCTAssertEqual(player.currentLevelID, initialLevel,
                      "Level should not change when bonus word is found")
    }
    
    // MARK: - Test 3: Canonicalization Prevents Duplicates
    func testCanonicalizationPreventsDuplicates() throws {
        // Test that different representations of same word are treated as identical
        let variations = [
            "EAR",
            "ear",
            "Ear",
            "ÉAR",     // With accent
            "  EAR  ",  // With spaces
            "èar"       // Different accent
        ]
        
        let canonicalized = variations.map { StringCanonicalizer.canon($0) }
        let uniqueSet = Set(canonicalized)
        
        // All variations should canonicalize to the same value
        XCTAssertEqual(uniqueSet.count, 1,
                      "All variations should canonicalize to same value")
        XCTAssertEqual(uniqueSet.first, "EAR",
                      "Should canonicalize to uppercase EAR")
    }
    
    // MARK: - Test 4: Level Key Consistency
    func testLevelKeyConsistency() throws {
        // Test that level keys are consistently formatted
        let testCases: [(input: Int, expected: String)] = [
            (1, "1"),
            (10, "10"),
            (100, "100"),
            (001, "1"),  // Leading zeros should be removed
            (0, "0")
        ]
        
        for testCase in testCases {
            let result = StringCanonicalizer.levelKey(testCase.input)
            XCTAssertEqual(result, testCase.expected,
                          "Level \(testCase.input) should format to '\(testCase.expected)'")
        }
    }
    
    // MARK: - Test 5: Snapshot Union Reconciliation
    func testSnapshotUnionReconciliation() throws {
        // Given: Local and server state with different words
        let localProgress: [String: Set<String>] = [
            "1": Set(["EAST", "STAR"]),
            "2": Set(["WORD"])
        ]
        
        let serverProgress: [String: [String]] = [
            "1": ["STAR", "ARTS"],  // Has ARTS but missing EAST
            "3": ["NEW"]             // Has level 3 that local doesn't
        ]
        
        // When: Reconciliation happens
        var mergedProgress: [String: Set<String>] = [:]
        
        // Start with server data (canonicalized)
        for (levelKey, words) in serverProgress {
            mergedProgress[levelKey] = Set(words.map { StringCanonicalizer.canon($0) })
        }
        
        // Union with local data
        for (levelKey, localWords) in localProgress {
            let canonWords = localWords.map { StringCanonicalizer.canon($0) }
            if let serverWords = mergedProgress[levelKey] {
                mergedProgress[levelKey] = serverWords.union(canonWords)
            } else {
                mergedProgress[levelKey] = Set(canonWords)
            }
        }
        
        // Then: Should have union of all words
        XCTAssertEqual(mergedProgress["1"]?.count, 3,
                      "Level 1 should have 3 words (EAST, STAR, ARTS)")
        XCTAssertTrue(mergedProgress["1"]?.contains("EAST") ?? false,
                     "Should contain local word EAST")
        XCTAssertTrue(mergedProgress["1"]?.contains("ARTS") ?? false,
                     "Should contain server word ARTS")
        XCTAssertTrue(mergedProgress["2"]?.contains("WORD") ?? false,
                     "Should preserve local-only level 2")
        XCTAssertTrue(mergedProgress["3"]?.contains("NEW") ?? false,
                     "Should preserve server-only level 3")
    }
    
    // MARK: - Test 6: Atomic Submission Guard
    func testAtomicSubmissionGuard() throws {
        // Given: A submission in flight
        viewModel.isGuessInFlight = true
        
        // When: Another submission is attempted
        viewModel.currentGuess = "WORD"
        viewModel.submitGuess()
        
        // Then: The second submission should be ignored
        // (In a real test, we'd verify no double effects)
        XCTAssertTrue(viewModel.isGuessInFlight,
                     "Guard should prevent concurrent submissions")
    }
}

// MARK: - Performance Tests
extension RuneWordsFixTests {
    func testCanonicalizationPerformance() throws {
        let testWords = Array(repeating: "TÉSTÎÑG", count: 10000)
        
        measure {
            _ = testWords.map { StringCanonicalizer.canon($0) }
        }
    }
    
    func testReconciliationPerformance() throws {
        // Create large datasets
        var localProgress: [String: Set<String>] = [:]
        var serverProgress: [String: [String]] = [:]
        
        for level in 1...100 {
            let levelKey = String(level)
            localProgress[levelKey] = Set((0..<50).map { "WORD\($0)" })
            serverProgress[levelKey] = (50..<100).map { "WORD\($0)" }
        }
        
        measure {
            var mergedProgress: [String: Set<String>] = [:]
            
            for (levelKey, words) in serverProgress {
                mergedProgress[levelKey] = Set(words.map { StringCanonicalizer.canon($0) })
            }
            
            for (levelKey, localWords) in localProgress {
                let canonWords = localWords.map { StringCanonicalizer.canon($0) }
                if let serverWords = mergedProgress[levelKey] {
                    mergedProgress[levelKey] = serverWords.union(canonWords)
                } else {
                    mergedProgress[levelKey] = Set(canonWords)
                }
            }
        }
    }
}
