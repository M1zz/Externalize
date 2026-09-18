import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(MemoModel.self) private var model
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(OnboardingKey.completed) private var hasCompletedOnboarding = false
    @State private var isShowingOnboarding = !UserDefaults.standard.bool(forKey: OnboardingKey.completed)
    @State private var isAdding = false
    @State private var isShowingPaywall = false
    @State private var copiedID: UUID?
    @State private var copyCount = 0

    private var canAdd: Bool {
        purchases.isUnlocked || model.memos.count < ProAccess.freeSlotLimit
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.memos.isEmpty {
                    emptyState
                } else {
                    memoList
                }
            }
            .navigationTitle("Externalize")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !purchases.isUnlocked {
                        Button("\(model.memos.count)/\(ProAccess.freeSlotLimit)") {
                            isShowingPaywall = true
                        }
                        .font(.subheadline.monospacedDigit())
                        .accessibilityLabel("Free slots used")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingOnboarding = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("How it works")

                    Button(action: addTapped) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Remember something")
                }
            }
            .sheet(isPresented: $isAdding) {
                AddMemoView()
                    .environment(model)
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
                    .environment(purchases)
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                OnboardingView {
                    hasCompletedOnboarding = true
                    isShowingOnboarding = false
                }
            }
        }
        .sensoryFeedback(.success, trigger: copyCount)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
            }
        }
        .task {
            // Items vanish on screen as they expire.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                model.refresh()
            }
        }
    }

    // MARK: - Sections

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to remember", systemImage: "brain.head.profile")
        } description: {
            Text("Don't spend your brain on things you don't need to remember.\nEverything you save here deletes itself.")
        } actions: {
            Button("Remember something", action: addTapped)
                .buttonStyle(.borderedProminent)
        }
    }

    private var memoList: some View {
        List {
            Section {
                ForEach(model.memos) { memo in
                    MemoCard(memo: memo, isCopied: copiedID == memo.id)
                        .contentShape(Rectangle())
                        .onTapGesture { copy(memo) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                model.delete(memo)
                            } label: {
                                Label("Forget", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                model.extend(memo)
                            } label: {
                                Label("+24h", systemImage: "clock.arrow.circlepath")
                            }
                            .tint(.blue)
                        }
                }
            } footer: {
                Text("Tap to copy. Swipe right to keep it another 24 hours. Everything else disappears on its own.")
            }

            Section {
                WidgetTip()
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: model.memos)
    }

    // MARK: - Actions

    private func addTapped() {
        if canAdd {
            isAdding = true
        } else {
            isShowingPaywall = true
        }
    }

    @MainActor
    private func copy(_ memo: Memo) {
        UIPasteboard.general.string = memo.value
        copyCount += 1
        withAnimation { copiedID = memo.id }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if copiedID == memo.id {
                withAnimation { copiedID = nil }
            }
        }
    }
}

private enum OnboardingKey {
    static let completed = "onboarding.completed"
}

// MARK: - Card

struct MemoCard: View {
    let memo: Memo
    let isCopied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(memo.displayTitle, systemImage: memo.kind.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if isCopied {
                    Label("Copied", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }

            Text(memo.value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                let fraction = memo.remainingFraction(at: context.date)
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: fraction)
                        .tint(fraction < 0.15 ? Color.orange : Color.accentColor)
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                        Text("Forgets in \(memo.expiresAt, style: .relative)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to copy")
    }
}

// MARK: - Widget tip

struct WidgetTip: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Put it on your Lock Screen")
                    .font(.subheadline.weight(.semibold))
                Text("Long-press the Lock Screen → Customize → Lock Screen → add the Externalize widget.")
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
        .environment(PurchaseManager())
}
