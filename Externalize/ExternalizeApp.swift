import SwiftUI
import UIKit
import UserNotifications
import LeeoKit

@main
struct ExternalizeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                .environment(AppRouter.shared)
                .onOpenURL { AppRouter.shared.handle($0) }
        }
    }
}

/// Where the app should land: typing a new thought, or settling open ones.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Destination: Equatable {
        case capture
        case review
    }

    static let captureURL = URL(string: "externalize://capture")!

    var pending: Destination?

    func handle(_ url: URL) {
        switch url.host() {
        case "capture": pending = .capture
        case "review": pending = .review
        default: break
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: ReminderScheduler.memoCategory,
                actions: [
                    UNNotificationAction(identifier: ReminderScheduler.doneAction, title: String(localized: "Done"), options: []),
                    UNNotificationAction(identifier: ReminderScheduler.tomorrowAction, title: String(localized: "Tomorrow morning"), options: []),
                    UNNotificationAction(identifier: ReminderScheduler.dropAction, title: String(localized: "Drop it"), options: [.destructive]),
                ],
                intentIdentifiers: []
            )
        ])
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await MainActor.run { NotificationCenter.default.post(name: .memosDidChangeExternally, object: nil) }
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let repository = MemoRepository.shared
        let memoID = ReminderScheduler.memoID(fromIdentifier: response.notification.request.identifier)
        let memo = memoID.flatMap { id in repository.load().first { $0.id == id } }

        switch response.actionIdentifier {
        case ReminderScheduler.doneAction, ReminderScheduler.dropAction:
            if let memo { repository.resolve(id: memo.id) }
        case ReminderScheduler.tomorrowAction:
            if let memo, let date = ScheduleOption.tomorrowMorning.date() {
                repository.update(memo.scheduled(for: date))
            }
        case UNNotificationDefaultActionIdentifier:
            await MainActor.run { AppRouter.shared.pending = .review }
        default:
            break
        }
        await MainActor.run { NotificationCenter.default.post(name: .memosDidChangeExternally, object: nil) }
    }
}

extension Notification.Name {
    static let memosDidChangeExternally = Notification.Name("memosDidChangeExternally")
}
