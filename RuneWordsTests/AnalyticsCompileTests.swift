//
//  AnalyticsCompileTests.swift
//  RuneWordsTests
//
//  WO-006: Compile-time validation and parameter verification for analytics events
//

import XCTest
@testable import RuneWords

final class AnalyticsCompileTests: XCTestCase {
    
    private var analyticsManager: AnalyticsManager!
    
    override func setUp() {
        super.setUp()
        analyticsManager = AnalyticsManager.shared
        analyticsManager.clearSessionEvents() // Start with clean slate
    }
    
    override func tearDown() {
        analyticsManager.clearSessionEvents()
        super.tearDown()
    }
    
    // MARK: - Compilation Tests
    
    func testAllAnalyticsMethodsCompile() {
        // Test that all WO-006 required methods compile with correct parameters
        
        // Core gameplay methods
        analyticsManager.logLevelStart(id: 1, realm: "treelibrary", difficulty: "easy")
        analyticsManager.logLevelComplete(id: 1, realm: "treelibrary", difficulty: "easy", 
                                        timeSec: 45.0, hintsUsed: 2, perfect: false)
        
        // Hint system
        analyticsManager.logHintUsed(type: "clarity", cost: 25)
        
        // Ad rewards
        analyticsManager.logAdReward(collected: true, placement: "level_complete")
        
        // In-app purchases
        analyticsManager.logIAPPurchase(productId: "coin_pack_small", success: true)
        
        // FTUE tracking
        analyticsManager.logFTUE(stateTransition: "intro_to_coachmarks")
        
        // Realm progression
        analyticsManager.logRealmUnlock(realm: "crystalforest", method: "levels")
        
        // Session tracking
        analyticsManager.logSessionStart()
        analyticsManager.logSessionEnd(duration: 300.0)
        
        // Legacy methods (ensure backward compatibility)
        analyticsManager.logWordFound(word: "TEST", isBonus: false)
        analyticsManager.logFirstLaunch()
        analyticsManager.logDailyReturn()
        
        XCTAssertTrue(true, "All analytics methods compiled successfully")
    }
    
    // MARK: - Parameter Validation Tests
    
    func testLevelStartRequiredParameters() {
        let initialCount = analyticsManager.eventCount
        
        // Test with valid parameters
        analyticsManager.logLevelStart(id: 42, realm: "sleepingtitan", difficulty: "hard")
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 1, 
                      "logLevelStart should increment event count")
        
        // Test edge cases
        analyticsManager.logLevelStart(id: 1, realm: "", difficulty: "easy")
        analyticsManager.logLevelStart(id: 9999, realm: "astralpeak", difficulty: "expert")
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 3, 
                      "All logLevelStart calls should be tracked")
    }
    
    func testLevelCompleteRequiredParameters() {
        let initialCount = analyticsManager.eventCount
        
        // Test normal completion
        analyticsManager.logLevelComplete(id: 1, realm: "treelibrary", difficulty: "easy", 
                                        timeSec: 30.5, hintsUsed: 0, perfect: true)
        
        // Test slow completion with hints
        analyticsManager.logLevelComplete(id: 100, realm: "crystalforest", difficulty: "medium", 
                                        timeSec: 180.7, hintsUsed: 3, perfect: false)
        
        // Test edge cases
        analyticsManager.logLevelComplete(id: 3000, realm: "astralpeak", difficulty: "expert", 
                                        timeSec: 0.1, hintsUsed: 99, perfect: false)
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 3, 
                      "All logLevelComplete calls should be tracked")
    }
    
    func testHintUsedParameters() {
        let initialCount = analyticsManager.eventCount
        
        // Test all hint types
        let hintTypes = ["clarity", "precision", "momentum", "revelation"]
        let costs = [25, 50, 75, 125]
        
        for (hintType, cost) in zip(hintTypes, costs) {
            analyticsManager.logHintUsed(type: hintType, cost: cost)
        }
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + hintTypes.count, 
                      "All hint types should be tracked")
    }
    
    func testAdRewardParameters() {
        let initialCount = analyticsManager.eventCount
        
        // Test collected vs declined
        analyticsManager.logAdReward(collected: true, placement: "level_complete")
        analyticsManager.logAdReward(collected: false, placement: "hint_offer")
        analyticsManager.logAdReward(collected: true, placement: "daily_bonus")
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 3, 
                      "All ad reward events should be tracked")
    }
    
    func testIAPPurchaseParameters() {
        let initialCount = analyticsManager.eventCount
        
        // Test successful purchases
        analyticsManager.logIAPPurchase(productId: "coin_pack_small", success: true)
        analyticsManager.logIAPPurchase(productId: "coin_pack_large", success: true)
        analyticsManager.logIAPPurchase(productId: "remove_ads", success: true)
        
        // Test failed purchases
        analyticsManager.logIAPPurchase(productId: "coin_pack_medium", success: false)
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 4, 
                      "All IAP events should be tracked")
    }
    
    func testFTUEParameters() {
        let initialCount = analyticsManager.eventCount
        
        // Test FTUE state transitions
        let transitions = [
            "app_start_to_intro",
            "intro_to_level1", 
            "level1_to_coachmarks",
            "coachmarks_to_complete"
        ]
        
        for transition in transitions {
            analyticsManager.logFTUE(stateTransition: transition)
        }
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + transitions.count, 
                      "All FTUE transitions should be tracked")
    }
    
    func testRealmUnlockParameters() {
        let initialCount = analyticsManager.eventCount
        
        // Test both unlock methods
        analyticsManager.logRealmUnlock(realm: "crystalforest", method: "levels")
        analyticsManager.logRealmUnlock(realm: "sleepingtitan", method: "difficulty")
        analyticsManager.logRealmUnlock(realm: "astralpeak", method: "levels")
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 3, 
                      "All realm unlock events should be tracked")
    }
    
    // MARK: - Session Tracking Tests
    
    func testSessionTracking() {
        let initialCount = analyticsManager.eventCount
        
        analyticsManager.logSessionStart()
        
        // Simulate some gameplay events
        analyticsManager.logLevelStart(id: 1, realm: "treelibrary", difficulty: "easy")
        analyticsManager.logHintUsed(type: "clarity", cost: 25)
        analyticsManager.logLevelComplete(id: 1, realm: "treelibrary", difficulty: "easy", 
                                        timeSec: 45.0, hintsUsed: 1, perfect: false)
        
        analyticsManager.logSessionEnd(duration: 120.0)
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 5, 
                      "Session tracking with gameplay events should work")
    }
    
    // MARK: - Debug Features Tests
    
    func testDebugLogging() {
        // Test that debug logging can be toggled
        let originalState = analyticsManager.isDebugLoggingEnabled
        
        analyticsManager.isDebugLoggingEnabled = false
        analyticsManager.logLevelStart(id: 1, realm: "treelibrary", difficulty: "easy")
        
        analyticsManager.isDebugLoggingEnabled = true
        analyticsManager.logLevelStart(id: 2, realm: "treelibrary", difficulty: "easy")
        
        // Restore original state
        analyticsManager.isDebugLoggingEnabled = originalState
        
        XCTAssertTrue(true, "Debug logging toggle should work without crashes")
    }
    
    func testSessionSummary() {
        analyticsManager.clearSessionEvents()
        
        // Generate some events
        analyticsManager.logLevelStart(id: 1, realm: "treelibrary", difficulty: "easy")
        analyticsManager.logLevelStart(id: 2, realm: "treelibrary", difficulty: "easy")
        analyticsManager.logHintUsed(type: "clarity", cost: 25)
        analyticsManager.logLevelComplete(id: 1, realm: "treelibrary", difficulty: "easy", 
                                        timeSec: 45.0, hintsUsed: 1, perfect: false)
        
        let summary = analyticsManager.getSessionSummary()
        
        XCTAssertTrue(summary.contains("Total Events:"), "Summary should contain event count")
        XCTAssertTrue(summary.contains("Event Types:"), "Summary should contain event breakdown")
        XCTAssertGreaterThan(summary.count, 50, "Summary should be substantive")
        
        print("📊 Sample Session Summary:")
        print(summary)
    }
    
    // MARK: - Performance Tests
    
    func testAnalyticsPerformance() {
        measure {
            for i in 0..<100 {
                analyticsManager.logLevelStart(id: i, realm: "treelibrary", difficulty: "easy")
            }
        }
    }
    
    func testConcurrentAnalytics() {
        let expectation = XCTestExpectation(description: "Concurrent analytics")
        expectation.expectedFulfillmentCount = 10
        
        let initialCount = analyticsManager.eventCount
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                DispatchQueue.main.async {
                    self.analyticsManager.logLevelStart(id: i, realm: "treelibrary", difficulty: "easy")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 10, 
                      "Concurrent analytics calls should all be tracked")
    }
    
    // MARK: - Error Handling Tests
    
    func testEmptyStringParameters() {
        let initialCount = analyticsManager.eventCount
        
        // Test with empty strings (should not crash)
        analyticsManager.logLevelStart(id: 1, realm: "", difficulty: "")
        analyticsManager.logHintUsed(type: "", cost: 0)
        analyticsManager.logAdReward(collected: true, placement: "")
        analyticsManager.logIAPPurchase(productId: "", success: false)
        analyticsManager.logFTUE(stateTransition: "")
        analyticsManager.logRealmUnlock(realm: "", method: "")
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 6, 
                      "Empty string parameters should not prevent event tracking")
    }
    
    func testExtremeValues() {
        let initialCount = analyticsManager.eventCount
        
        // Test with extreme values
        analyticsManager.logLevelComplete(id: Int.max, realm: "test", difficulty: "test", 
                                        timeSec: Double.greatestFiniteMagnitude, 
                                        hintsUsed: Int.max, perfect: true)
        
        analyticsManager.logLevelComplete(id: Int.min, realm: "test", difficulty: "test", 
                                        timeSec: 0.0, hintsUsed: 0, perfect: false)
        
        XCTAssertEqual(analyticsManager.eventCount, initialCount + 2, 
                      "Extreme values should be handled gracefully")
    }
    
    // MARK: - Integration Tests
    
    func testAnalyticsWithGameFlow() {
        analyticsManager.clearSessionEvents()
        
        // Simulate a complete game session
        analyticsManager.logSessionStart()
        analyticsManager.logFTUE(stateTransition: "app_start_to_intro")
        
        // First level
        analyticsManager.logLevelStart(id: 1, realm: "treelibrary", difficulty: "easy")
        analyticsManager.logHintUsed(type: "clarity", cost: 25)
        analyticsManager.logLevelComplete(id: 1, realm: "treelibrary", difficulty: "easy", 
                                        timeSec: 65.0, hintsUsed: 1, perfect: false)
        
        // Ad reward
        analyticsManager.logAdReward(collected: true, placement: "level_complete")
        
        // Second level (perfect)
        analyticsManager.logLevelStart(id: 2, realm: "treelibrary", difficulty: "easy")
        analyticsManager.logLevelComplete(id: 2, realm: "treelibrary", difficulty: "easy", 
                                        timeSec: 32.0, hintsUsed: 0, perfect: true)
        
        // Realm unlock
        analyticsManager.logRealmUnlock(realm: "crystalforest", method: "levels")
        
        analyticsManager.logSessionEnd(duration: 180.0)
        
        let summary = analyticsManager.getSessionSummary()
        
        XCTAssertTrue(summary.contains("level_start"), "Should track level starts")
        XCTAssertTrue(summary.contains("level_complete"), "Should track level completions")
        XCTAssertTrue(summary.contains("hint_used"), "Should track hint usage")
        XCTAssertTrue(summary.contains("ad_reward"), "Should track ad rewards")
        XCTAssertTrue(summary.contains("realm_unlock"), "Should track realm unlocks")
        
        print("🎮 Complete Game Session Analytics:")
        print(summary)
    }
}