import Foundation
import UserNotifications

/// When the evening "settle what's left" reminder rings. Lives in the App Group
/// because whoever writes memos (app or Siri) re-plans notifications.
enum ReviewSettings {
    private static let enabledKey = "review.enabled"
    private static let hourKey = "review.hour"
    private static let minuteKey = "review.minute"

    static var isEnabled: Bool {
        get { AppGroup.defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { AppGroup.defaults.set(newValue, forKey: enabledKey) }
    }

    /// Defaults to 9pm.
    static var time: DateComponents {
        get {
            let defaults = AppGroup.defaults
            let hour = defaults.object(forKey: hourKey) as? Int ?? 21
            let minute = defaults.object(forKey: minuteKey) as? Int ?? 0
            return DateComponents(hour: hour, minute: minute)
        }
        set {
            AppGroup.defaults.set(newValue.hour ?? 21, forKey: hourKey)
            AppGroup.defaults.set(newValue.minute ?? 0, forKey: minuteKey)
        }
    }
}

/// Plans every local notification from the current memo list:
/// one at each scheduled memo's time, and an evening review on each of the
/// next days that still has something open — carrying the count left at that moment.
enum ReminderScheduler {
    static let memoCategory = "MEMO"
    static let doneAction = "MEMO_DONE"
    static let tomorrowAction = "MEMO_TOMORROW"
    static let dropAction = "MEMO_DROP"
    static let reviewIdentifierPrefix = "review."
    static let memoIdentifierPrefix = "memo."

    private static let scheduledIDsKey = "reminders.scheduledIDs"
    private static let reviewDays = 7
    /// iOS keeps at most 64 pending requests per app.
    private static let maxMemoReminders = 50

    static func memoID(fromIdentifier identifier: String) -> UUID? {
        guard identifier.hasPrefix(memoIdentifierPrefix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(memoIdentifierPrefix.count)))
    }

    static func sync(_ memos: [Memo], now: Date = .now, calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        let defaults = AppGroup.defaults

        let previous = defaults.stringArray(forKey: scheduledIDsKey) ?? []
        center.removePendingNotificationRequests(withIdentifiers: previous)

        // Resolved memos shouldn't linger in Notification Center either.
        let liveIdentifiers = Set(memos.map { memoIdentifierPrefix + $0.id.uuidString })
        let gone = previous.filter { $0.hasPrefix(memoIdentifierPrefix) && !liveIdentifiers.contains($0) }
        center.removeDeliveredNotifications(withIdentifiers: gone)

        var requests: [UNNotificationRequest] = []

        let upcoming = memos
            .compactMap { memo in memo.remindAt.map { (memo, $0) } }
            .filter { $0.1 > now }
            .sorted { $0.1 < $1.1 }
            .prefix(maxMemoReminders)
        for (memo, date) in upcoming {
            let content = UNMutableNotificationContent()
            content.title = memo.text
            content.body = String(localized: "It's time. Do it, reschedule it, or drop it.")
            content.sound = .default
            content.categoryIdentifier = memoCategory
            content.badge = NSNumber(value: memos.filter { $0.isOpen(at: date) }.count)
            content.userInfo = ["memoID": memo.id.uuidString]
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date),
                repeats: false
            )
            requests.append(UNNotificationRequest(identifier: memoIdentifierPrefix + memo.id.uuidString, content: content, trigger: trigger))
        }

        if ReviewSettings.isEnabled {
            for date in reviewDates(from: now, calendar: calendar) {
                let count = memos.filter { $0.isOpen(at: date) }.count
                guard count > 0 else { continue }
                let content = UNMutableNotificationContent()
                content.title = String(localized: "Time to clear your head")
                content.body = String(localized: "\(count) things you wrote down are still open. Settle them now?")
                content.sound = .default
                content.badge = NSNumber(value: count)
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date),
                    repeats: false
                )
                let identifier = reviewIdentifierPrefix + String(Int(date.timeIntervalSince1970))
                requests.append(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            }
        }

        for request in requests {
            center.add(request)
        }
        defaults.set(requests.map(\.identifier), forKey: scheduledIDsKey)
    }

    /// The review time on each of the next `reviewDays` days, skipping today's if it has passed.
    static func reviewDates(from now: Date, calendar: Calendar = .current) -> [Date] {
        let time = ReviewSettings.time
        let startOfToday = calendar.startOfDay(for: now)
        return (0...reviewDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfToday)
                .flatMap { calendar.date(bySettingHour: time.hour ?? 21, minute: time.minute ?? 0, second: 0, of: $0) }
        }
        .filter { $0 > now }
        .prefix(reviewDays)
        .map { $0 }
    }
}
