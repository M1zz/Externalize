import SwiftUI

/// The evening ritual: one memo at a time, each gets an ending.
struct ReviewView: View {
    @Environment(MemoModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var total = 0
    @State private var settledCount = 0
    @State private var doingSince: Date?
    @State private var isPickingTime = false
    @State private var feedback = 0

    private var current: Memo? { model.open.first }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let memo = current {
                card(for: memo)
                    .id(memo.id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                finished
            }
        }
        .animation(.snappy, value: current?.id)
        .sensoryFeedback(.success, trigger: feedback)
        .onAppear {
            total = model.open.count
        }
        .sheet(isPresented: $isPickingTime) {
            SchedulePicker { date in
                isPickingTime = false
                if let memo = current {
                    settle { model.schedule(memo, at: date) }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            if current != nil, total > 0 {
                Text("\(min(settledCount + 1, total)) of \(total)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(settledCount), total: Double(max(total, 1)))
                    .frame(maxWidth: 120)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func card(for memo: Memo) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Text(memo.text)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                MemoMeta(memo: memo, now: .now)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            if let doingSince {
                doing(memo, since: doingSince)
            } else {
                choices(for: memo)
            }
        }
        .padding(.bottom, 24)
    }

    private func choices(for memo: Memo) -> some View {
        VStack(spacing: 10) {
            Button {
                withAnimation { doingSince = .now }
            } label: {
                VStack(spacing: 2) {
                    Label("Do it now", systemImage: "bolt.fill")
                    Text("If it takes two minutes, just do it")
                        .font(.caption)
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button {
                isPickingTime = true
            } label: {
                Label("Pick a time", systemImage: "calendar.badge.clock")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.blue)

            Button(role: .destructive) {
                settle { model.drop(memo) }
            } label: {
                Label("Drop it — doesn't need doing", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .font(.headline)
        .padding(.horizontal, 24)
    }

    /// "Do it now" — go do it, then come back and tick it off.
    private func doing(_ memo: Memo, since start: Date) -> some View {
        VStack(spacing: 14) {
            Text(timerInterval: start...start.addingTimeInterval(120), countsDown: true)
                .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.green)
            Text("Go do it. Come back when it's done.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                settle { model.complete(memo) }
            } label: {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button("Not now — back to choices") {
                withAnimation { doingSince = nil }
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 24)
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Your head is clear")
                .font(.largeTitle.bold())
            if settledCount > 0 {
                Text("You settled \(settledCount) things. Nothing is left hanging.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }

    private func settle(_ action: () -> Void) {
        action()
        doingSince = nil
        settledCount += 1
        feedback += 1
    }
}

#Preview {
    ReviewView()
        .environment(MemoModel())
}
