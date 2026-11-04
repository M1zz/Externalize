import AppIntents
import CoreSpotlight
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "Hey Siri, remember in Externalize" / Action Button / Shortcuts.
/// Writes the thought down without opening the app; the evening review takes it from there.
struct RememberIntent: AppIntent {
    static var title: LocalizedStringResource { "Write It Down" }
    static var description: IntentDescription { "Get a thought out of your head. You'll decide what to do with it in the evening." }

    @Parameter(title: "Thought", description: "What to write down, in your own words.")
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

        // 한 번에 여러 개를 말해도 받는다("우유 사고 세탁소 들르고 엄마한테 전화").
        // 기기 안 AI 가 있으면 따로따로 나눠 적고, 없으면 말한 그대로 하나로 적는다.
        let thoughts = await ThoughtSplitter.split(trimmed)
        for thought in thoughts { MemoRepository.shared.add(Memo(text: thought)) }
        NotificationCenter.default.post(name: .memosDidChangeExternally, object: nil)
        if thoughts.count > 1 {
            return .result(dialog: "Got it. I wrote down \(thoughts.count) things. You can let go of them for now.")
        }
        return .result(dialog: "Got it. You can let go of \(trimmed) for now.")
    }

    /// 앱에서 적을 때도 Siri 에게 알려 준다 — 다음에 Siri 가 "적어 둬" 를 이 앱으로 고르기 쉽게.
    static func donate(_ text: String) {
        var intent = RememberIntent()
        intent.value = text
        Task { _ = try? await intent.donate() }
    }
}

// MARK: - 적어 둔 생각 (Siri · Spotlight 가 찾는다)

/// 아직 머릿속에서 내려놓기만 하고 끝내지 않은 생각. 끝내거나 버리면 목록에서도 색인에서도 빠진다.
struct MemoEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Thought")
    static let defaultQuery = MemoQuery()

    let id: UUID
    let text: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(text)") }

    init(_ memo: Memo) {
        id = memo.id
        text = memo.text
    }

    static func all() -> [MemoEntity] { MemoRepository.shared.load().map(MemoEntity.init) }

    /// 앱을 열 때 · 뒤로 보낼 때 다시 색인한다.
    static func reindex() async {
        guard #available(iOS 18.0, *) else { return }
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: MemoEntity.self)
        try? await index.indexAppEntities(all())
    }
}

@available(iOS 18.0, *)
extension MemoEntity: IndexedEntity {}

struct MemoQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [MemoEntity] {
        let wanted = Set(identifiers)
        return MemoEntity.all().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [MemoEntity] {
        MemoEntity.all().filter { $0.text.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [MemoEntity] {
        MemoEntity.all()
    }
}

/// 적어 둔 생각을 열어 끝낼 방법(하기 · 미루기 · 버리기)을 고르게 한다. Spotlight · Siri 결과를 누르면 여기로 온다.
struct OpenMemoIntent: OpenIntent {
    static var title: LocalizedStringResource { "Open Thought" }
    static var description: IntentDescription { "Opens a thought you wrote down so you can do it, schedule it, or drop it." }

    @Parameter(title: "Thought", description: "A thought you wrote down and haven't settled yet.")
    var target: MemoEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pending = .memo(target.id)
        return .result()
    }
}

/// 말 한 덩어리를 따로 할 일들로 나눈다. 기기 안에서만 돈다(iOS 26+, Apple Intelligence).
enum ThoughtSplitter {
    static func split(_ text: String) async -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable,
           let parts = try? await ModelSplitter.split(text), parts.count > 1 {
            return parts
        }
        #endif
        return [text]
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct SplitThoughts {
    @Guide(description: "Each separate thing the person wants to remember, in their own words and language. Keep one item if it is a single thought.", .count(1...6))
    var items: [String]
}

@available(iOS 26.0, *)
private enum ModelSplitter {
    static func split(_ text: String) async throws -> [String] {
        let session = LanguageModelSession(instructions: """
            Split what the person said into separate things to remember.
            Do not add, reword, translate, or drop anything. Keep each item short and in the original language.
            """)
        return try await session.respond(to: text, generating: SplitThoughts.self).content.items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
#endif

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
