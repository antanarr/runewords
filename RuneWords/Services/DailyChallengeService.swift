
//
//  DailyChallengeService.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/29/25.
//

import Foundation

struct DailyChallenge {
    let dateKey: String   // "YYYY-MM-DD"
    let levelID: Int
}

/// Result when completing a daily challenge (awarded coins & streak info)
struct DailyChallengePayout {
    let dateKey: String
    let levelID: Int
    let coinsAwarded: Int
    let streak: Int
    let isMilestone: Bool
}

extension Notification.Name {
    static let dailyChallengeCompleted = Notification.Name("DailyChallenge.Completed")
}

@MainActor
final class DailyChallengeService: ObservableObject {
    static let shared = DailyChallengeService()
    private init() {}

    // Economy tuning (Remote Config could override later)
    private let baseRewardCoins: Int = 50
    private let perDayStreakBonus: Int = 5      // +5 coins per consecutive day
    private let perDayStreakCap: Int = 10       // cap extra at 10 days (i.e., +50)
    private let milestoneEvery: Int = 7         // every 7th day gets a bonus
    private let milestoneBonusCoins: Int = 100

    // Cached formatters - FORCE UTC TIMEZONE
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")!  // Force UTC
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let parseFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")!  // Force UTC
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Returns today's challenge based on deterministic hashing across available level IDs.
    func challengeForToday(availableLevelIDs: [Int]) -> DailyChallenge? {
        guard let id = pickLevel(for: Date(), from: availableLevelIDs) else { return nil }
        return DailyChallenge(dateKey: Self.dateKey(for: Date()), levelID: id)
    }

    /// Returns true if the player has already completed today's challenge.
    func isCompletedToday(player: Player?) -> Bool {
        guard let player else { return false }
        return player.lastDailyDate == Self.dateKey(for: Date())
    }

    /// Records completion, updates streak, and persists changes.
    func recordCompletion(for player: inout Player) {
        let today = Self.dateKey(for: Date())
        if player.lastDailyDate == today { return } // already recorded

        let cal = Calendar.current
        if
            let last = player.lastDailyDate,
            let lastDate = Self.date(fromKey: last),
            let yesterday = cal.date(byAdding: .day, value: -1, to: Date()),
            cal.isDate(yesterday, inSameDayAs: lastDate)
        {
            player.dailyStreak += 1   // consecutive day
        } else {
            player.dailyStreak = 1    // reset streak
        }

        player.lastDailyDate = today
    }

    /// Marks today as completed if not already, updates streak, grants coins, persists, and returns the payout.
    /// Returns nil if there is no available level or today was already completed.
    func completeTodayIfNeeded(availableLevelIDs: [Int]) -> DailyChallengePayout? {
        guard let levelID = pickLevel(for: Date(), from: availableLevelIDs) else { return nil }
        let today = Self.dateKey(for: Date())
        guard var player = PlayerService.shared.player else { return nil }
        // Already completed today? Bail early.
        if player.lastDailyDate == today { return nil }

        // Compute new streak (consecutive day vs reset)
        let cal = Calendar.current
        var newStreak = 1
        if let last = player.lastDailyDate,
           let lastDate = Self.date(fromKey: last),
           let yesterday = cal.date(byAdding: .day, value: -1, to: Date()),
           cal.isDate(yesterday, inSameDayAs: lastDate) {
            newStreak = max(1, player.dailyStreak + 1)
        }

        // Calculate coins: base + per-day (capped) + milestone bonus
        let streakExtra = perDayStreakBonus * min(max(newStreak - 1, 0), perDayStreakCap)
        var coins = baseRewardCoins + streakExtra
        let isMilestone = (newStreak % milestoneEvery == 0)
        if isMilestone { coins += milestoneBonusCoins }

        // Persist
        player.dailyStreak = newStreak
        player.lastDailyDate = today
        player.coins += coins
        PlayerService.shared.player = player
        PlayerService.shared.saveProgress(player: player.toPlayerData())

        // Notify listeners (HUD pulse, etc.)
        NotificationCenter.default.post(name: .dailyChallengeCompleted,
                                        object: nil,
                                        userInfo: [
                                            "dateKey": today,
                                            "levelID": levelID,
                                            "coins": coins,
                                            "streak": newStreak,
                                            "milestone": isMilestone
                                        ])

        return DailyChallengePayout(dateKey: today, levelID: levelID, coinsAwarded: coins, streak: newStreak, isMilestone: isMilestone)
    }

    // MARK: - Helpers

    private func pickLevel(for date: Date, from ids: [Int]) -> Int? {
        guard !ids.isEmpty else { return nil }
        let key = Self.dateKey(for: date)
        let hash = key.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        let index = abs(hash) % ids.count
        return ids[index]
    }

    static func dateKey(for date: Date) -> String {
        keyFormatter.string(from: date)
    }

    static func date(fromKey key: String) -> Date? {
        parseFormatter.date(from: key)
    }
}
