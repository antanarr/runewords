//
//  NotificationsManager.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/29/25.
//

import Foundation

//
//  NotificationsManager.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/29/25.
//

import Foundation
import UIKit
import UserNotifications
import SwiftUI

@MainActor
final class NotificationsManager: ObservableObject {
    static let shared = NotificationsManager()
    private init() {}

    /// Requests notification permission from the user.
    /// - Returns: `true` if granted, `false` otherwise.
    func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            return granted
        } catch {
            print("[Notifications] Authorization error: \(error)")
            return false
        }
    }

    /// Schedules a daily reminder notification at the given hour/minute.
    /// Defaults to 7:00 PM if parameters omitted.
    func scheduleDailyReminder(hour: Int = 19, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("daily_title", comment: "Daily Challenge")
        content.body = NSLocalizedString("daily_body", comment: "Your new daily puzzle is ready!")
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_challenge", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[Notifications] Schedule error: \(error)") }
        }
    }

    /// Cancels the scheduled daily reminder, if any.
    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_challenge"])
    }
}
