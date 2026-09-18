import SwiftUI

@main
struct ExternalizeApp: App {
    @State private var model = MemoModel()
    @State private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(purchases)
                .task { await purchases.start() }
        }
    }
}
