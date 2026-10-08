import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(MemoModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isReviewEnabled = ReviewSettings.isEnabled
    @State private var reviewTime = SettingsView.date(from: ReviewSettings.time)
    @State private var authorization: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Evening reminder", isOn: $isReviewEnabled)
                    if isReviewEnabled {
                        DatePicker("Time", selection: $reviewTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("Once a day, if anything is still open, you'll get a nudge to settle it. Nothing open, no nudge.")
                }

                if authorization == .denied {
                    Section {
                        Button("Turn on notifications in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    } footer: {
                        Text("Notifications are off, so reminders can't reach you.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            }
            .onChange(of: isReviewEnabled) { _, enabled in
                ReviewSettings.isEnabled = enabled
                model.resyncReminders()
                if enabled { NotificationPermission.requestIfNeeded() }
            }
            .onChange(of: reviewTime) { _, time in
                ReviewSettings.time = Calendar.current.dateComponents([.hour, .minute], from: time)
                model.resyncReminders()
            }
        }
    }

    private static func date(from components: DateComponents) -> Date {
        Calendar.current.date(bySettingHour: components.hour ?? 21, minute: components.minute ?? 0, second: 0, of: .now) ?? .now
    }
}

#Preview {
    SettingsView()
        .environment(MemoModel())
}
