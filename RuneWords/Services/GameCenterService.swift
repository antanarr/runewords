//
//  GameCenterService.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/29/25.
//

import Foundation
import GameKit
import UIKit

@MainActor
final class GameCenterService: NSObject, ObservableObject, GameCenterServiceProtocol {
    static let shared = GameCenterService()
    private override init() {}

    @Published var isAuthenticated = false

    // MARK: - Authentication

    func authenticateIfNeeded() async {
        let localPlayer = GKLocalPlayer.local
        guard !localPlayer.isAuthenticated else {
            self.isAuthenticated = true
            return
        }

        localPlayer.authenticateHandler = { [weak self] viewController, error in
            if let viewController {
                // Present manually using the topmost view controller
                if let top = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow })?
                    .rootViewController {
                    top.present(viewController, animated: true)
                }
            } else if let error {
                print("[GameCenter] auth error: \(error)")
                self?.isAuthenticated = false
            } else {
                self?.isAuthenticated = localPlayer.isAuthenticated
            }
        }
    }

    // MARK: - Leaderboards

    enum Leaderboard: String {
        case totalWords   = "rw_total_words"
        case fastestDaily = "rw_fastest_daily"
        case fastestSolveTime = "rw_fastest_solve"
        case weeklyScore = "rw_weekly_score"
        case allTimeScore = "rw_all_time_score"
        case longestStreak = "rw_longest_streak"
    }

    func report(score: Int, to board: Leaderboard) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(score,
                                  context: 0,
                                  player: GKLocalPlayer.local,
                                  leaderboardIDs: [board.rawValue]) { error in
            if let error { print("[GameCenter] submit score error: \(error)") }
        }
    }

    // MARK: - Achievements

    enum GCAchievement: String {
        // Progression achievements
        case firstRealm        = "rw_ach_first_realm"
        case allRealms         = "rw_ach_all_realms"
        case level100          = "rw_ach_level_100"
        case level500          = "rw_ach_level_500"
        
        // Streak achievements
        case sevenDayStreak    = "rw_ach_7_day_streak"
        case thirtyDayStreak   = "rw_ach_30_day_streak"
        
        // Skill achievements
        case noHintLevel       = "rw_ach_no_hint"
        case speedDemon        = "rw_ach_speed_demon" // Complete level in under 30 seconds
        case perfectLevel      = "rw_ach_perfect"     // Find all words including bonus
        case wordMaster        = "rw_ach_word_master" // Find 1000 words total
        case bonusHunter       = "rw_ach_bonus_hunter" // Find 100 bonus words
        
        // Daily challenge achievements
        case dailyChampion     = "rw_ach_daily_champion"
        case dailyConsistent   = "rw_ach_daily_consistent" // Complete 30 daily challenges
    }

    func unlock(_ achievement: GCAchievement, percent: Double = 100.0) {
        guard isAuthenticated else { return }
        let ach = GKAchievement(identifier: achievement.rawValue)
        ach.percentComplete = percent
        ach.showsCompletionBanner = true
        GKAchievement.report([ach]) { error in
            if let error { print("[GameCenter] report achievement error: \(error)") }
        }
    }
    
    // Protocol conformance methods
    func authenticatePlayer() async {
        await authenticateIfNeeded()
    }
    
    func submitScore(_ score: Int, to leaderboard: String) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(score,
                                  context: 0,
                                  player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboard]) { error in
            if let error { print("[GameCenter] submit score error: \(error)") }
        }
    }
    
    func unlockAchievement(_ achievementID: String, percentComplete: Double) {
        guard isAuthenticated else { return }
        let ach = GKAchievement(identifier: achievementID)
        ach.percentComplete = percentComplete
        ach.showsCompletionBanner = true
        GKAchievement.report([ach]) { error in
            if let error { print("[GameCenter] report achievement error: \(error)") }
        }
    }
    
    func unlockAchievement(_ achievement: String) {
        unlockAchievement(achievement, percentComplete: 100.0)
    }
    
    // MARK: - Game Integration Helpers
    
    func reportLevelComplete(levelNumber: Int, solveTime: TimeInterval, wordsFound: Int, bonusWordsFound: Int, hintsUsed: Int) {
        guard isAuthenticated else { return }
        
        // Report fastest solve time
        let timeInSeconds = Int(solveTime)
        report(score: timeInSeconds, to: .fastestSolveTime)
        
        // Check for achievements
        if solveTime < 30 {
            unlock(.speedDemon)
        }
        
        if hintsUsed == 0 {
            unlock(.noHintLevel)
        }
        
        // Check level milestones
        if levelNumber == 100 {
            unlock(.level100)
        } else if levelNumber == 500 {
            unlock(.level500)
        }
    }
    
    func reportDailyChallengeComplete(solveTime: TimeInterval, streak: Int) {
        guard isAuthenticated else { return }
        
        // Report to daily leaderboard
        let timeInSeconds = Int(solveTime)
        report(score: timeInSeconds, to: .fastestDaily)
        
        // Report streak
        report(score: streak, to: .longestStreak)
        
        // Check streak achievements
        if streak >= 7 {
            unlock(.sevenDayStreak)
        }
        if streak >= 30 {
            unlock(.thirtyDayStreak)
        }
    }
    
    func reportTotalProgress(totalWords: Int, totalBonusWords: Int, realmsCompleted: Int, totalRealms: Int) {
        guard isAuthenticated else { return }
        
        // Report total words
        report(score: totalWords, to: .totalWords)
        
        // Check word achievements
        if totalWords >= 1000 {
            unlock(.wordMaster)
        }
        
        if totalBonusWords >= 100 {
            unlock(.bonusHunter)
        }
        
        // Check realm achievements
        if realmsCompleted >= 1 {
            unlock(.firstRealm)
        }
        
        if realmsCompleted >= totalRealms && totalRealms > 0 {
            unlock(.allRealms)
        }
    }
    
    // MARK: - UI Presentation
    
    func showLeaderboard(for leaderboard: Leaderboard = .totalWords) {
        guard isAuthenticated else {
            Task { await authenticateIfNeeded() }
            return
        }
        
        let viewController = GKGameCenterViewController(leaderboardID: leaderboard.rawValue, playerScope: .global, timeScope: .allTime)
        viewController.gameCenterDelegate = self
        
        presentViewController(viewController)
    }
    
    func showLeaderboard() {
        showLeaderboard(for: .totalWords)
    }
    
    func showAchievements() {
        guard isAuthenticated else {
            Task { await authenticateIfNeeded() }
            return
        }
        
        let viewController = GKGameCenterViewController(state: .achievements)
        viewController.gameCenterDelegate = self
        
        presentViewController(viewController)
    }
    
    private func presentViewController(_ viewController: UIViewController) {
        if let topController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController {
            topController.present(viewController, animated: true)
        }
    }
}

// MARK: - GKGameCenterControllerDelegate

extension GameCenterService: GKGameCenterControllerDelegate {
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
