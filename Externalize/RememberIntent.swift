import AppIntents
import Foundation

/// "Hey Siri, remember in Externalize" / Action Button / Shortcuts.
/// Writes the thought down without opening the app; the evening review takes it from there.
struct RememberIntent: AppIntent {
    static var title: LocalizedStringResource { "Write It Down" }
    static var description: IntentDescription { "Get a thought out of your head. You'll decide what to do with it in the evening." }

    @Parameter(title: "Thought")
    var value: String

    static var parameterSummary: some ParameterSummary {
        Summary("Write down \(\.$value)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw $value.needsValueError("What's on your mind?")
        }

        MemoRepository.shared.add(Memo(text: trimmed))
        NotificationCenter.default.post(name: .memosDidChangeExternally, object: nil)
        return .result(dialog: "Got it. You can let go of \(trimmed) for now.")
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
            shortTitle: "Write It Down",
            systemImageName: "brain.head.profile"
        )
    }
}
