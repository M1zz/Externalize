import SwiftUI

@main
struct ExternalizeApp: App {
    @State private var model = MemoModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
