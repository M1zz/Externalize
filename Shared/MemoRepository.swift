import Foundation
import WidgetKit

enum AppGroup {
    /// Must match the App Group in both entitlements files.
    static let identifier = "group.com.devkoan.externalize"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Free tier gate. The flag is cached in the App Group so the widget and
/// App Intents can read it without touching StoreKit.
enum ProAccess {
    static let freeSlotLimit = 2
    private static let key = "pro.unlocked"

    static var isUnlocked: Bool {
        get { AppGroup.defaults.bool(forKey: key) }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }

    static func canAdd(currentCount: Int) -> Bool {
        isUnlocked || currentCount < freeSlotLimit
    }
}

/// JSON-in-App-Group storage shared by the app, the widget and App Intents.
/// Expired memos are filtered on every read and physically removed on purge.
struct MemoRepository: Sendable {
    static let shared = MemoRepository()

    private let storageKey = "memos.v1"

    /// Read-only view of live memos, newest first. Safe to call from the widget.
    func load(now: Date = .now) -> [Memo] {
        readAll()
            .filter { !$0.isExpired(at: now) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Deletes expired memos from disk and returns the live ones, newest first.
    @discardableResult
    func purgeExpired(now: Date = .now) -> [Memo] {
        let all = readAll()
        let live = all.filter { !$0.isExpired(at: now) }
        if live.count != all.count {
            write(live)
        }
        return live.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ memo: Memo) {
        var live = purgeExpired()
        live.insert(memo, at: 0)
        write(live)
    }

    func update(_ memo: Memo) {
        var all = readAll()
        guard let index = all.firstIndex(where: { $0.id == memo.id }) else { return }
        all[index] = memo
        write(all)
    }

    func delete(id: UUID) {
        write(readAll().filter { $0.id != id })
    }

    func deleteAll() {
        write([])
    }

    // MARK: - Private

    private func readAll() -> [Memo] {
        guard let data = AppGroup.defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([Memo].self, from: data)) ?? []
    }

    private func write(_ memos: [Memo]) {
        let data = try? JSONEncoder().encode(memos)
        AppGroup.defaults.set(data, forKey: storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
