import Foundation

/// What kind of short-lived thing is being remembered.
enum MemoKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case parking
    case locker
    case room
    case code
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .parking: return "Parking"
        case .locker: return "Locker"
        case .room: return "Room"
        case .code: return "Code"
        case .other: return "Note"
        }
    }

    var symbol: String {
        switch self {
        case .parking: return "car.fill"
        case .locker: return "lock.fill"
        case .room: return "bed.double.fill"
        case .code: return "number"
        case .other: return "brain.head.profile"
        }
    }

    var placeholder: String {
        switch self {
        case .parking: return "B3 · Pillar 12"
        case .locker: return "0424"
        case .room: return "507"
        case .code: return "4719#"
        case .other: return "Anything short-lived"
        }
    }

    var prefersNumericKeyboard: Bool {
        self == .locker || self == .room || self == .code
    }
}

/// How long a memo lives before it deletes itself.
enum MemoLifetime: TimeInterval, CaseIterable, Identifiable, Sendable {
    case oneHour = 3_600
    case eightHours = 28_800
    case oneDay = 86_400

    static let standard: MemoLifetime = .oneDay

    var id: TimeInterval { rawValue }

    var label: String {
        switch self {
        case .oneHour: return "1h"
        case .eightHours: return "8h"
        case .oneDay: return "24h"
        }
    }
}

struct Memo: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: MemoKind
    var label: String
    var value: String
    var createdAt: Date
    var expiresAt: Date

    init(
        id: UUID = UUID(),
        kind: MemoKind,
        label: String = "",
        value: String,
        lifetime: MemoLifetime = .standard,
        now: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.value = value
        self.createdAt = now
        self.expiresAt = now.addingTimeInterval(lifetime.rawValue)
    }

    var displayTitle: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.title : trimmed
    }

    func isExpired(at date: Date = .now) -> Bool {
        expiresAt <= date
    }

    /// 1.0 right after creation, 0.0 at expiry.
    func remainingFraction(at date: Date = .now) -> Double {
        let total = expiresAt.timeIntervalSince(createdAt)
        guard total > 0 else { return 0 }
        return min(max(expiresAt.timeIntervalSince(date) / total, 0), 1)
    }

    /// Restarts the clock for another full day.
    func extended(now: Date = .now) -> Memo {
        var copy = self
        copy.createdAt = now
        copy.expiresAt = now.addingTimeInterval(MemoLifetime.oneDay.rawValue)
        return copy
    }

    static let sample = Memo(kind: .parking, value: "B3 · 12")
}
