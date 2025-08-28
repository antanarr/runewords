//
//  NotificationsHelper.swift
//  RuneWords
//
//  Focus Filter and notification management helpers
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
final class NotificationsHelper: ObservableObject {
    static let shared = NotificationsHelper()
    private init() {}
    
    @Published var focusModeEnabled = false
    @Published var notificationSettings: UNNotificationSettings?
    
    // MARK: - Focus Filter Support
    
    /// Check if Focus filters are available (iOS 15+)
    var focusFiltersAvailable: Bool {
        if #available(iOS 15.0, *) {
            return true
        }
        return false
    }
    
    /// Get guidance text for setting up Focus mode
    func getFocusGuidanceText() -> String {
        if #available(iOS 15.0, *) {
            return """
            📱 **Reduce Interruptions During Gameplay**
            
            You can set up a Focus mode to minimize notifications while playing:
            
            1. Open **Settings** > **Focus**
            2. Tap the **+** button to create a new Focus
            3. Choose **Gaming** or **Custom**
            4. Name it "RuneWords" or similar
            5. Configure which notifications to allow
            6. Enable it when you start playing
            
            **Pro Tip:** You can also add RuneWords as an allowed app so you still receive game-related notifications!
            """
        } else {
            return """
            📱 **Reduce Interruptions During Gameplay**
            
            You can use Do Not Disturb to minimize notifications while playing:
            
            1. Open **Control Center** (swipe down from top-right)
            2. Tap the **Focus** button (moon icon)
            3. Select **Do Not Disturb**
            
            Remember to turn it off when you're done playing!
            """
        }
    }
    
    // MARK: - Notification Management
    
    func checkNotificationSettings() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        await MainActor.run {
            self.notificationSettings = settings
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await checkNotificationSettings()
            return granted
        } catch {
            Log.error("Notification permission error: \(error)")
            return false
        }
    }
    
    // MARK: - Game Session Management
    
    /// Suggest enabling Focus when starting a game session
    func suggestFocusForGameSession() -> Alert {
        Alert(
            title: Text("Minimize Distractions?"),
            message: Text("Would you like to enable Focus mode for an uninterrupted gaming experience?"),
            primaryButton: .default(Text("Enable Focus")) {
                self.openFocusSettings()
            },
            secondaryButton: .cancel()
        )
    }
    
    /// Open Focus settings in the Settings app
    func openFocusSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Notification Categories
    
    func setupNotificationCategories() {
        let gameCategory = UNNotificationCategory(
            identifier: "GAME_EVENTS",
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Game Update",
            options: .customDismissAction
        )
        
        let dailyCategory = UNNotificationCategory(
            identifier: "DAILY_CHALLENGE",
            actions: [
                UNNotificationAction(
                    identifier: "PLAY_NOW",
                    title: "Play Now",
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Daily Challenge Available",
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([gameCategory, dailyCategory])
    }
    
    // MARK: - Scheduled Notifications
    
    func scheduleDailyChallengeReminder(at hour: Int = 10) async {
        guard await requestNotificationPermission() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Challenge Available! 🎯"
        content.body = "Your daily RuneWords challenge is waiting. Can you beat yesterday's time?"
        content.categoryIdentifier = "DAILY_CHALLENGE"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_challenge_reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            Log.info("Daily challenge reminder scheduled")
        } catch {
            Log.error("Failed to schedule daily reminder: \(error)")
        }
    }
    
    func cancelDailyChallengeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_challenge_reminder"]
        )
    }
}

// MARK: - Settings View Integration

struct FocusSettingsSection: View {
    @StateObject private var helper = NotificationsHelper.shared
    @AppStorage("show_focus_suggestions") private var showFocusSuggestions = true
    @AppStorage("daily_reminder_enabled") private var dailyReminderEnabled = false
    @AppStorage("daily_reminder_hour") private var dailyReminderHour = 10
    
    var body: some View {
        Section("Focus & Notifications") {
            // Focus Mode Toggle
            Toggle(isOn: $showFocusSuggestions) {
                Label("Suggest Focus Mode", systemImage: "moon.circle.fill")
            }
            
            // Focus Setup Button
            Button(action: {
                helper.openFocusSettings()
            }) {
                HStack {
                    Label("Set Up Focus Mode", systemImage: "moon.fill")
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundColor(.secondary)
                }
            }
            
            // Daily Reminder Toggle
            Toggle(isOn: $dailyReminderEnabled) {
                Label("Daily Challenge Reminder", systemImage: "bell.badge")
            }
            .onChange(of: dailyReminderEnabled) { _, enabled in
                Task {
                    if enabled {
                        await helper.scheduleDailyChallengeReminder(at: dailyReminderHour)
                    } else {
                        helper.cancelDailyChallengeReminder()
                    }
                }
            }
            
            // Reminder Time Picker
            if dailyReminderEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: Binding(
                        get: {
                            let components = DateComponents(hour: dailyReminderHour, minute: 0)
                            return Calendar.current.date(from: components) ?? Date()
                        },
                        set: { date in
                            let components = Calendar.current.dateComponents([.hour], from: date)
                            dailyReminderHour = components.hour ?? 10
                            Task {
                                await helper.scheduleDailyChallengeReminder(at: dailyReminderHour)
                            }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
            
            // Focus Guide
            DisclosureGroup("How to Reduce Interruptions") {
                Text(helper.getFocusGuidanceText())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
    }
}