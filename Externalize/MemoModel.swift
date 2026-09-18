import Foundation
import Observation

@MainActor
@Observable
final class MemoModel {
    private(set) var memos: [Memo] = []

    private let repository = MemoRepository.shared

    init() {
        refresh()
    }

    /// Re-reads storage and physically deletes anything past its expiry.
    func refresh() {
        let live = repository.purgeExpired()
        if live != memos {
            memos = live
        }
    }

    func add(kind: MemoKind, label: String, value: String, lifetime: MemoLifetime) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return }
        let memo = Memo(
            kind: kind,
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            value: trimmedValue,
            lifetime: lifetime
        )
        repository.add(memo)
        refresh()
    }

    func delete(_ memo: Memo) {
        repository.delete(id: memo.id)
        refresh()
    }

    func extend(_ memo: Memo) {
        repository.update(memo.extended())
        refresh()
    }
}
