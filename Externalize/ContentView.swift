import SwiftUI
import UIKit
import UserNotifications

struct ContentView: View {
    @Environment(MemoModel.self) private var model
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(OnboardingKey.completed) private var hasCompletedOnboarding = false
    @State private var isShowingOnboarding = !UserDefaults.standard.bool(forKey: OnboardingKey.completed)
    @State private var isReviewing = false
    @State private var isShowingSettings = false
    @State private var deciding: Memo?
    @State private var scheduling: Memo?
    @State private var draft = ""
    @State private var captureCount = 0
    @State private var resolveCount = 0
    @FocusState private var isCaptureFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if model.open.isEmpty && model.scheduled.isEmpty {
                    clearState
                } else {
                    memoList
                }
            }
            .navigationTitle("Externalize")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingOnboarding = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("How it works")

                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .safeAreaInset(edge: .bottom) { captureBar }
            .sheet(item: $deciding) { memo in
                DecisionSheet(memo: memo) { decision in
                    deciding = nil
                    apply(decision, to: memo)
                }
            }
            .sheet(item: $scheduling) { memo in
                SchedulePicker { date in
                    scheduling = nil
                    model.schedule(memo, at: date)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .environment(model)
            }
            .fullScreenCover(isPresented: $isReviewing) {
                ReviewView()
                    .environment(model)
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                OnboardingView {
                    hasCompletedOnboarding = true
                    isShowingOnboarding = false
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: captureCount)
        .sensoryFeedback(.success, trigger: resolveCount)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
                model.resyncReminders()
                UNUserNotificationCenter.current().setBadgeCount(model.open.count)
                routeIfNeeded()
            }
        }
        .onChange(of: router.pending) { _, _ in routeIfNeeded() }
        .onChange(of: model.open.count) { _, count in
            UNUserNotificationCenter.current().setBadgeCount(count)
        }
        .onReceive(NotificationCenter.default.publisher(for: .memosDidChangeExternally)) { _ in
            model.refresh()
        }
        .task {
            // Scheduled memos come back into the open list when their time arrives.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                model.refresh()
            }
        }
    }

    // MARK: - Sections

    private var clearState: some View {
        ContentUnavailableView {
            Label("Your head is clear", systemImage: "brain.head.profile")
        } description: {
            if model.resolvedToday > 0 {
                Text("You settled \(model.resolvedToday) things today.")
            } else {
                Text("When something pops into your head, write it below and let it go.\nTonight you'll decide what to do with it.")
            }
        }
    }

    private var memoList: some View {
        List {
            if !model.open.isEmpty {
                Section {
                    Button {
                        isReviewing = true
                    } label: {
                        Label("Settle them now (\(model.open.count))", systemImage: "checklist")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(model.open) { memo in
                        row(for: memo)
                    }
                } header: {
                    Text("On your mind")
                } footer: {
                    Text("Each one needs an ending: do it, schedule it, or drop it.")
                }
            }

            if !model.scheduled.isEmpty {
                Section("Scheduled") {
                    ForEach(model.scheduled) { memo in
                        row(for: memo)
                    }
                }
            }

            if model.open.count + model.scheduled.count <= 2 {
                Section {
                    WidgetTip()
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: model.open)
        .animation(.default, value: model.scheduled)
        .scrollDismissesKeyboard(.interactively)
    }

    private func row(for memo: Memo) -> some View {
        Button {
            deciding = memo
        } label: {
            MemoRow(memo: memo)
        }
        .tint(.primary)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                apply(.done, to: memo)
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                apply(.drop, to: memo)
            } label: {
                Label("Drop it", systemImage: "trash")
            }
            Button {
                scheduling = memo
            } label: {
                Label("Schedule", systemImage: "calendar")
            }
            .tint(.blue)
        }
    }

    private var captureBar: some View {
        HStack(spacing: 10) {
            TextField("What's on your mind?", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($isCaptureFocused)
                .submitLabel(.done)
                .onSubmit(capture)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

            Button(action: capture) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Write it down")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Actions

    private func capture() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.capture(text)
        draft = ""
        captureCount += 1
        isCaptureFocused = true
        NotificationPermission.requestIfNeeded()
    }

    private func apply(_ decision: Decision, to memo: Memo) {
        switch decision {
        case .done:
            model.complete(memo)
            resolveCount += 1
        case .drop:
            model.drop(memo)
            resolveCount += 1
        case .schedule(let date):
            model.schedule(memo, at: date)
        }
    }

    private func routeIfNeeded() {
        guard scenePhase == .active, let destination = router.pending else { return }
        router.pending = nil
        isShowingOnboarding = false
        switch destination {
        case .capture:
            isReviewing = false
            isCaptureFocused = true
        case .review:
            isReviewing = !model.open.isEmpty
        }
    }
}

private enum OnboardingKey {
    static let completed = "onboarding.completed"
}

enum Decision: Equatable {
    case done
    case drop
    case schedule(Date)
}

enum NotificationPermission {
    /// Asked right after the first capture — the moment the evening reminder starts to matter.
    static func requestIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            ReminderScheduler.sync(MemoRepository.shared.load())
        }
    }
}

// MARK: - Row

struct MemoRow: View {
    let memo: Memo

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(memo.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                MemoMeta(memo: memo, now: context.date)
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to decide what to do with it")
    }
}

/// "3 hours ago", "Tomorrow 9:00 AM", "Waiting over a day".
struct MemoMeta: View {
    let memo: Memo
    let now: Date

    var body: some View {
        HStack(spacing: 4) {
            if let remindAt = memo.remindAt, remindAt > now {
                Image(systemName: "bell")
                Text(remindAt, format: .relative(presentation: .named))
                Text(remindAt, style: .time)
            } else if memo.isStale(at: now) {
                Image(systemName: "exclamationmark.circle")
                Text("Waiting over a day")
            } else {
                Image(systemName: "clock")
                Text(memo.waitingSince, format: .relative(presentation: .named))
            }
            if memo.postponeCount >= 2 {
                Text("· Put off \(memo.postponeCount) times")
            }
        }
        .font(.caption)
        .foregroundStyle(memo.isStale(at: now) || memo.postponeCount >= 3 ? Color.orange : Color.secondary)
    }
}

// MARK: - Decision

/// Tap a memo anywhere → the same three endings.
struct DecisionSheet: View {
    let memo: Memo
    let onDecide: (Decision) -> Void

    @State private var isPickingTime = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(memo.text)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                MemoMeta(memo: memo, now: .now)
            }
            .padding(.top, 28)
            .padding(.horizontal)

            DecisionButtons(
                onDone: { onDecide(.done) },
                onSchedule: { isPickingTime = true },
                onDrop: { onDecide(.drop) }
            )
            .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isPickingTime) {
            SchedulePicker { date in
                isPickingTime = false
                onDecide(.schedule(date))
            }
        }
    }
}

struct DecisionButtons: View {
    var doneTitle: LocalizedStringKey = "Done — it's handled"
    let onDone: () -> Void
    let onSchedule: () -> Void
    let onDrop: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onDone) {
                Label(doneTitle, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button(action: onSchedule) {
                Label("Pick a time", systemImage: "calendar.badge.clock")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.blue)

            Button(role: .destructive, action: onDrop) {
                Label("Drop it — doesn't need doing", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .font(.headline)
    }
}

// MARK: - Schedule

struct SchedulePicker: View {
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var custom = Date.now.addingTimeInterval(3_600)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ScheduleOption.allCases) { option in
                        if let date = option.date() {
                            Button {
                                onPick(date)
                            } label: {
                                HStack {
                                    Label(option.title, systemImage: option.symbol)
                                    Spacer()
                                    Text(date, format: .dateTime.weekday(.abbreviated).hour().minute())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                Section("Other time") {
                    DatePicker("Remind me", selection: $custom, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    Button("Remind me then") { onPick(custom) }
                }
            }
            .navigationTitle("When will you do it?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Widget tip

struct WidgetTip: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Write it down from your Lock Screen")
                    .font(.subheadline.weight(.semibold))
                Text("Long-press the Lock Screen → Customize → Lock Screen → add the Externalize widget. One tap opens a blank line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "lock.iphone")
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    ContentView()
        .environment(MemoModel())
        .environment(AppRouter.shared)
}
