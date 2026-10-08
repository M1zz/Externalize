import Foundation
import WidgetKit

enum AppGroup {
    /// Must match the App Group in both entitlements files.
    static let identifier = "group.com.devkoan.externalize"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// JSON-in-App-Group storage shared by the app, the widget and App Intents.
/// Every write reloads the widget and re-plans notifications, so whoever writes
/// (app, Siri, a notification action) leaves everything consistent.
struct MemoRepository: Sendable {
    static let shared = MemoRepository()

    private let storageKey = "thoughts.v1"
    private let legacyStorageKey = "memos.v1"

    /// All memos, oldest first — the order they should be dealt with.
    func load() -> [Memo] {
        readAll().sorted { $0.waitingSince < $1.waitingSince }
    }

    func open(at date: Date = .now) -> [Memo] {
        load().filter { $0.isOpen(at: date) }
    }

    func scheduled(at date: Date = .now) -> [Memo] {
        load()
            .filter { $0.isScheduled(at: date) }
            .sorted { ($0.remindAt ?? .distantPast) < ($1.remindAt ?? .distantPast) }
    }

    func add(_ memo: Memo) {
        var all = readAll()
        all.append(memo)
        write(all)
    }

    func update(_ memo: Memo) {
        var all = readAll()
        guard let index = all.firstIndex(where: { $0.id == memo.id }) else { return }
        all[index] = memo
        write(all)
    }

    /// Done or dropped — either way it leaves your head and this list.
    func resolve(id: UUID) {
        let all = readAll()
        let remaining = all.filter { $0.id != id }
        guard remaining.count != all.count else { return }
        write(remaining)
        ResolvedCounter.increment()
    }

    // MARK: - Private

    private func readAll() -> [Memo] {
        if let data = AppGroup.defaults.data(forKey: storageKey) {
            do {
                return try JSONDecoder().decode([Memo].self, from: data)
            } catch {
                assertionFailure("Undecodable memos: \(error)")
                return []
            }
        }
        return migrateLegacy()
    }

    private func write(_ memos: [Memo]) {
        do {
            let data = try JSONEncoder().encode(memos)
            AppGroup.defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Could not encode memos: \(error)")
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
        ReminderScheduler.sync(memos)
    }

    /// 1.0 stored short-lived values ("Parking: B3"). Carry the unexpired ones over as open memos once.
    private func migrateLegacy() -> [Memo] {
        struct LegacyMemo: Decodable {
            var label: String
            var value: String
            var createdAt: Date
            var expiresAt: Date
        }
        let defaults = AppGroup.defaults
        guard let data = defaults.data(forKey: legacyStorageKey) else { return [] }
        let legacy = (try? JSONDecoder().decode([LegacyMemo].self, from: data)) ?? []
        let migrated = legacy
            .filter { $0.expiresAt > .now }
            .map { old -> Memo in
                let label = old.label.trimmingCharacters(in: .whitespacesAndNewlines)
                return Memo(text: label.isEmpty ? old.value : "\(label): \(old.value)", createdAt: old.createdAt)
            }
        if let encoded = try? JSONEncoder().encode(migrated) {
            defaults.set(encoded, forKey: storageKey)
        }
        defaults.removeObject(forKey: legacyStorageKey)
        return migrated
    }
}

/// How many things have been taken off your mind today — the small reward for finishing.
enum ResolvedCounter {
    private static let countKey = "resolved.count"
    private static let dayKey = "resolved.day"

    static func today(now: Date = .now) -> Int {
        let defaults = AppGroup.defaults
        guard let day = defaults.object(forKey: dayKey) as? Date,
              Calendar.current.isDate(day, inSameDayAs: now) else { return 0 }
        return defaults.integer(forKey: countKey)
    }

    static func increment(now: Date = .now) {
        AppGroup.defaults.set(today(now: now) + 1, forKey: countKey)
        AppGroup.defaults.set(now, forKey: dayKey)
    }
}
