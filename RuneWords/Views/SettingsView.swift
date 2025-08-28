//
//  SettingsView.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/29/25.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @AppStorage("isMusicEnabled") private var isMusicEnabled = true
    @AppStorage("isSfxEnabled")   private var isSfxEnabled   = true
    @AppStorage("colorBlindMode") private var colorBlindMode = false
    @State private var notificationsEnabled: Bool = false
    @State private var showNotifAlert = false
    @State private var showReplayConfirmation = false
    @State private var showTutorialConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                soundSection
                accessibilitySection
                notificationSection
                tutorialSection
                purchaseSection
                aboutSection
            }
            .navigationTitle(NSLocalizedString("settings", comment: "Settings"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadNotificationStatus() }
            .alert("Replay Tutorial?", isPresented: $showTutorialConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Replay", role: .destructive) {
                    appState.resetFTUEToCoachmarks()
                }
            } message: {
                Text("The tutorial will show next time you enter a level.")
            }
            .alert("Replay Full Introduction?", isPresented: $showReplayConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Replay", role: .destructive) {
                    appState.resetFTUEToIntro()
                    dismiss()
                }
            } message: {
                Text("This will show the complete onboarding flow again.")
            }
        }
    }

    // MARK: - Sections

    private var soundSection: some View {
        Section(header: Text(NSLocalizedString("sound", comment: "Sound"))) {
            Toggle(NSLocalizedString("music", comment: "Music"), isOn: $isMusicEnabled)
                .onChange(of: isMusicEnabled, initial: false) { oldValue, newValue in
                    AudioManager.shared.isMusicEnabled = newValue
                }
            Toggle(NSLocalizedString("sfx", comment: "Sound Effects"), isOn: $isSfxEnabled)
                .onChange(of: isSfxEnabled, initial: false) { _, newValue in
                    AudioManager.shared.isSfxEnabled = newValue
                }
        }
    }

    private var accessibilitySection: some View {
        Section(header: Text(NSLocalizedString("accessibility", comment: "Accessibility"))) {
            Toggle(NSLocalizedString("color_blind", comment: "Color-blind Mode"), isOn: $colorBlindMode)
        }
    }

    private var notificationSection: some View {
        Section(header: Text(NSLocalizedString("notifications", comment: "Notifications"))) {
            Toggle(NSLocalizedString("daily_reminder", comment: "Daily Challenge Reminder"), isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled, initial: false) { _, newValue in
                    Task {
                        if newValue {
                            let granted = await NotificationsManager.shared.requestAuthorization()
                            if granted {
                                NotificationsManager.shared.scheduleDailyReminder()
                            } else {
                                notificationsEnabled = false
                                showNotifAlert = true
                            }
                        } else {
                            NotificationsManager.shared.cancelDailyReminder()
                        }
                    }
                }
        }
        .alert(NSLocalizedString("notifications_denied", comment: "Notification denied"),
               isPresented: $showNotifAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(NSLocalizedString("enable_notifications_in_settings",
                                   comment: "Enable notifications in system settings."))
        }
    }
    
    private var tutorialSection: some View {
        Section {
            Button("Replay Tutorial") {
                showTutorialConfirmation = true
            }
            .foregroundColor(.primary)
            
            Button("Replay Full Introduction") {
                showReplayConfirmation = true
            }
            .foregroundColor(.primary)
            
            if appState.ftueState.isCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Tutorial Complete")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Spacer()
                }
            }
        } header: {
            Text("Tutorial")
        } footer: {
            Text("Replay the tutorial or full introduction at any time.")
        }
    }

    private var purchaseSection: some View {
        Section(header: Text(NSLocalizedString("purchases", comment: "Purchases"))) {
            Button(NSLocalizedString("restore_purchases", comment: "Restore Purchases")) {
                Task { await StoreViewModel.shared.restore() }
            }
        }
    }

    private var aboutSection: some View {
        Section(header: Text(NSLocalizedString("about", comment: "About"))) {
            NavigationLink(NSLocalizedString("privacy_policy", comment: "Privacy Policy")) { PrivacyPolicyView() }
            NavigationLink(NSLocalizedString("terms_of_service", comment: "Terms of Service")) { TermsView() }
            HStack {
                Text(NSLocalizedString("version", comment: "Version"))
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func loadNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            notificationsEnabled = settings.authorizationStatus == .authorized
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.locale, .init(identifier: "en"))
}
