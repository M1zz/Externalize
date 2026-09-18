import AppIntents
import Foundation

extension MemoKind: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Type"

    static let caseDisplayRepresentations: [MemoKind: DisplayRepresentation] = [
        .parking: DisplayRepresentation(title: "Parking", image: .init(systemName: "car.fill")),
        .locker: DisplayRepresentation(title: "Locker", image: .init(systemName: "lock.fill")),
        .room: DisplayRepresentation(title: "Room", image: .init(systemName: "bed.double.fill")),
        .code: DisplayRepresentation(title: "Code", image: .init(systemName: "number")),
        .other: DisplayRepresentation(title: "Note", image: .init(systemName: "brain.head.profile")),
    ]
}

/// "Hey Siri, remember in Externalize" / Action Button / Shortcuts.
struct RememberIntent: AppIntent {
    static var title: LocalizedStringResource { "Remember Something" }
    static var description: IntentDescription { "Store a short-lived value that deletes itself in 24 hours." }

    @Parameter(title: "Value")
    var value: String

    @Parameter(title: "Type", default: .other)
    var kind: MemoKind

    @Parameter(title: "Label")
    var label: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Remember \(\.$value) as \(\.$kind)") {
            \.$label
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw $value.needsValueError("What should I remember?")
        }

        let repository = MemoRepository.shared
        let live = repository.purgeExpired()
        guard ProAccess.canAdd(currentCount: live.count) else {
            return .result(dialog: "Your free slots are full. Open Externalize to unlock unlimited slots.")
        }

        repository.add(Memo(kind: kind, label: label ?? "", value: trimmed))
        return .result(dialog: "Got it. I'll forget \(trimmed) in 24 hours.")
    }
}

struct ExternalizeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RememberIntent(),
            phrases: [
                "Remember in \(.applicationName)",
                "\(.applicationName) this",
            ],
            shortTitle: "Remember",
            systemImageName: "brain.head.profile"
        )
    }
}
