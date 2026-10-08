import Foundation
import Observation

@MainActor
@Observable
final class MemoModel {
    private(set) var open: [Memo] = []
    private(set) var scheduled: [Memo] = []
    private(set) var resolvedToday = 0

    private let repository = MemoRepository.shared

    init() {
        refresh()
    }

    /// Re-reads storage. Scheduled memos whose time has come move back to `open`.
    func refresh(now: Date = .now) {
        let all = repository.load()
        let newOpen = all.filter { $0.isOpen(at: now) }
        let newScheduled = all
            .filter { $0.isScheduled(at: now) }
            .sorted { ($0.remindAt ?? .distantPast) < ($1.remindAt ?? .distantPast) }
        if newOpen != open { open = newOpen }
        if newScheduled != scheduled { scheduled = newScheduled }
        resolvedToday = ResolvedCounter.today(now: now)
    }

    func capture(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        repository.add(Memo(text: trimmed))
        refresh()
    }

    /// "Do it now" — a two-minute thing you just took care of.
    func complete(_ memo: Memo) {
        repository.resolve(id: memo.id)
        refresh()
    }

    /// "Drop it" — turns out it didn't need doing.
    func drop(_ memo: Memo) {
        repository.resolve(id: memo.id)
        refresh()
    }

    func schedule(_ memo: Memo, at date: Date) {
        repository.update(memo.scheduled(for: date))
        refresh()
    }

    /// Re-plan notifications without changing anything — after a settings change or on launch.
    func resyncReminders() {
        ReminderScheduler.sync(repository.load())
    }
}
