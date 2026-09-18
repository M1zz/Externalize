import SwiftUI
import WidgetKit

// MARK: - Timeline

struct MemoEntry: TimelineEntry {
    let date: Date
    let memos: [Memo]
}

struct MemoTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoEntry {
        MemoEntry(date: .now, memos: [.sample])
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoEntry) -> Void) {
        let memos = MemoRepository.shared.load()
        completion(MemoEntry(date: .now, memos: context.isPreview && memos.isEmpty ? [.sample] : memos))
    }

    /// One entry now, plus one at every expiry so items drop off the Lock Screen on time.
    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoEntry>) -> Void) {
        let now = Date.now
        let memos = MemoRepository.shared.load(now: now)
        let expiryDates = Set(memos.map(\.expiresAt)).filter { $0 > now }.sorted()
        let entryDates = [now] + expiryDates.prefix(30)
        let entries = entryDates.map { date in
            MemoEntry(date: date, memos: memos.filter { !$0.isExpired(at: date) })
        }
        // The app reloads timelines on every write, so an empty state never needs polling.
        let policy: TimelineReloadPolicy = memos.isEmpty ? .never : .atEnd
        completion(Timeline(entries: entries, policy: policy))
    }
}

// MARK: - Views

struct ExternalizeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MemoEntry

    private var primary: Memo? { entry.memos.first }

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let memo = primary {
            let values = entry.memos.map(\.value).joined(separator: " · ")
            Label(values, systemImage: memo.kind.symbol)
        } else {
            Label("Nothing to remember", systemImage: "brain.head.profile")
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let memo = primary {
                VStack(spacing: 1) {
                    Image(systemName: memo.kind.symbol)
                        .font(.caption2)
                        .widgetAccentable()
                    Text(memo.value)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
                .padding(4)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
            }
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let memo = primary {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: memo.kind.symbol)
                    Text(memo.displayTitle)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if entry.memos.count > 1 {
                        Text("+\(entry.memos.count - 1)")
                    }
                }
                .font(.caption2.weight(.semibold))
                .widgetAccentable()

                Text(memo.value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                HStack(spacing: 3) {
                    Image(systemName: "hourglass")
                    Text(memo.expiresAt, style: .timer)
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("Externalize", systemImage: "brain.head.profile")
                    .font(.caption2.weight(.semibold))
                    .widgetAccentable()
                Text("Nothing to remember")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Externalize", systemImage: "brain.head.profile")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if entry.memos.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing to remember")
                    .font(.headline)
                Spacer(minLength: 0)
            } else {
                ForEach(entry.memos.prefix(3)) { memo in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(memo.displayTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(memo.value)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Widget

struct ExternalizeWidget: Widget {
    let kind = "ExternalizeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoTimelineProvider()) { entry in
            ExternalizeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Externalize")
        .description("What you don't need to remember, right on your Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .systemSmall])
    }
}

@main
struct ExternalizeWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExternalizeWidget()
    }
}

// MARK: - Previews

#Preview(as: .accessoryRectangular) {
    ExternalizeWidget()
} timeline: {
    MemoEntry(date: .now, memos: [
        Memo(kind: .parking, value: "B3 · 12"),
        Memo(kind: .locker, value: "0424"),
    ])
    MemoEntry(date: .now, memos: [])
}

#Preview(as: .accessoryCircular) {
    ExternalizeWidget()
} timeline: {
    MemoEntry(date: .now, memos: [Memo(kind: .room, value: "507")])
}

#Preview(as: .systemSmall) {
    ExternalizeWidget()
} timeline: {
    MemoEntry(date: .now, memos: [
        Memo(kind: .parking, value: "B3 · 12"),
        Memo(kind: .locker, value: "0424"),
        Memo(kind: .room, value: "507"),
    ])
}
