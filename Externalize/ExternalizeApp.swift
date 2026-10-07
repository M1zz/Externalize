import SwiftUI
import LeeoKit

@main
struct ExternalizeApp: App {
    @State private var model = MemoModel()

    init() {
        // LeeoKit 계약을 켜는 한 줄 (→ ExternalizeSpec.swift). 실행 횟수 기록 · DEBUG 프리플라이트.
        // ⚠️ 크래시 진단은 끈다(`diagnostics: false`). 진단은 FeedbackHub(CloudKit)로 올리는데
        //    이 앱엔 아직 그 iCloud 컨테이너 권한이 없다 — 권한 없이 CKContainer 를 만들면 앱이 죽는다.
        LeeoKit.bootstrap(ExternalizeSpec.self, diagnostics: false)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
