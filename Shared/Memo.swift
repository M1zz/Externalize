import Foundation

/// Something that popped into your head and has to be dealt with.
/// A memo never just sits there: it is either waiting for a decision (`isOpen`)
/// or parked until a time you chose (`isScheduled`). Doing it or dropping it deletes it.
struct Memo: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var text: String
    var createdAt: Date
    /// When it comes back for a decision. `nil` means it is waiting right now.
    var remindAt: Date?
    /// How many times it has been put off. Shown so nothing gets pushed forever unnoticed.
    var postponeCount: Int

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, remindAt: Date? = nil, postponeCount: Int = 0) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.remindAt = remindAt
        self.postponeCount = postponeCount
    }

    /// Waiting for a decision at `date`: never scheduled, or its time has come.
    func isOpen(at date: Date = .now) -> Bool {
        guard let remindAt else { return true }
        return remindAt <= date
    }

    func isScheduled(at date: Date = .now) -> Bool {
        !isOpen(at: date)
    }

    /// The moment it started (or restarted) waiting for a decision.
    var waitingSince: Date {
        remindAt ?? createdAt
    }

    /// Left undecided for more than a day.
    func isStale(at date: Date = .now) -> Bool {
        isOpen(at: date) && date.timeIntervalSince(waitingSince) > 86_400
    }

    func scheduled(for date: Date) -> Memo {
        var copy = self
        copy.remindAt = date
        copy.postponeCount += 1
        return copy
    }

    static let sample = Memo(text: String(localized: "Pick up the dry cleaning"))
}

/// Ready-made answers to "when, then?" so scheduling is one tap.
enum ScheduleOption: String, CaseIterable, Identifiable, Sendable {
    case inAnHour
    case tonight
    case tomorrowMorning
    case thisWeekend
    case nextWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inAnHour: return String(localized: "In an hour")
        case .tonight: return String(localized: "This evening")
        case .tomorrowMorning: return String(localized: "Tomorrow morning")
        case .thisWeekend: return String(localized: "This weekend")
        case .nextWeek: return String(localized: "Next week")
        }
    }

    var symbol: String {
        switch self {
        case .inAnHour: return "clock"
        case .tonight: return "moon"
        case .tomorrowMorning: return "sunrise"
        case .thisWeekend: return "sofa"
        case .nextWeek: return "calendar"
        }
    }

    /// `nil` when the option makes no sense right now (e.g. "this evening" at 11pm).
    func date(from now: Date = .now, calendar: Calendar = .current) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        func at(_ hour: Int, daysFromToday days: Int) -> Date? {
            calendar.date(byAdding: .day, value: days, to: startOfToday)
                .flatMap { calendar.date(bySettingHour: hour, minute: 0, second: 0, of: $0) }
        }

        switch self {
        case .inAnHour:
            return now.addingTimeInterval(3_600)
        case .tonight:
            guard let evening = at(19, daysFromToday: 0), evening > now.addingTimeInterval(30 * 60) else { return nil }
            return evening
        case .tomorrowMorning:
            return at(9, daysFromToday: 1)
        case .thisWeekend:
            // Saturday 10am; if it's already the weekend, next Saturday.
            let weekday = calendar.component(.weekday, from: now) // 1 = Sunday, 7 = Saturday
            let days = weekday == 7 ? 7 : (7 - weekday)
            return at(10, daysFromToday: days)
        case .nextWeek:
            // Monday 9am.
            let weekday = calendar.component(.weekday, from: now)
            let days = (9 - weekday) % 7 == 0 ? 7 : (9 - weekday) % 7
            return at(9, daysFromToday: days)
        }
    }
}
