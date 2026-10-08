import SwiftUI
import WidgetKit

/// Every widget opens straight onto a blank line: tap, type, done.
private let captureURL = URL(string: "externalize://capture")!

// MARK: - Timeline

struct MemoEntry: TimelineEntry {
    let date: Date
    /// Waiting for a decision at `date`, oldest first.
    let open: [Memo]
}

struct MemoTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoEntry {
        MemoEntry(date: .now, open: [.sample])
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoEntry) -> Void) {
        let open = MemoRepository.shared.open()
        completion(MemoEntry(date: .now, open: context.isPreview && open.isEmpty ? [.sample] : open))
    }

    /// One entry now, plus one whenever a scheduled memo comes back, so the count is right on the Lock Screen.
    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoEntry>) -> Void) {
        let now = Date.now
        let memos = MemoRepository.shared.load()
        let returnDates = Set(memos.compactMap(\.remindAt)).filter { $0 > now }.sorted()
        let entries = ([now] + returnDates.prefix(30)).map { date in
            MemoEntry(date: date, open: memos.filter { $0.isOpen(at: date) })
        }
        // The app reloads timelines on every write, so nothing needs polling.
        completion(Timeline(entries: entries, policy: .never))
    }
}

// MARK: - Views

struct ExternalizeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MemoEntry

    private var count: Int { entry.open.count }

    var body: some View {
        content
            .widgetURL(captureURL)
    }

    @ViewBuilder
    private var content: some View {
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
        if count > 0 {
            Label("\(count) on your mind", systemImage: "brain.head.profile")
        } else {
            Label("Head clear", systemImage: "brain.head.profile")
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if count > 0 {
                VStack(spacing: 0) {
                    Text("\(count)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .widgetAccentable()
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                }
            } else {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .widgetAccentable()
            }
        }
        .accessibilityLabel(count > 0 ? Text("\(count) on your mind") : Text("Write it down"))
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                Text(count > 0 ? "\(count) on your mind" : "Head clear")
                    .lineLimit(1)
            }
            .font(.caption2.weight(.semibold))
            .widgetAccentable()

            if let first = entry.open.first {
                Text(first.text)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack(spacing: 3) {
                Image(systemName: "plus.circle.fill")
                Text("Tap to write it down")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Externalize", systemImage: "brain.head.profile")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                }
            }

            if entry.open.isEmpty {
                Spacer(minLength: 0)
                Text("Head clear")
                    .font(.headline)
            } else {
                ForEach(entry.open.prefix(3)) { memo in
                    Text(memo.text)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Label("Write it down", systemImage: "plus.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
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
        .description("Tap to get a thought out of your head. See how many are still open.")
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
    MemoEntry(date: .now, open: [Memo(text: "Pick up the dry cleaning"), Memo(text: "Reply to Mina")])
    MemoEntry(date: .now, open: [])
}

#Preview(as: .accessoryCircular) {
    ExternalizeWidget()
} timeline: {
    MemoEntry(date: .now, open: [Memo(text: "Pick up the dry cleaning")])
}

#Preview(as: .systemSmall) {
    ExternalizeWidget()
} timeline: {
    MemoEntry(date: .now, open: [
        Memo(text: "Pick up the dry cleaning"),
        Memo(text: "Book dentist"),
        Memo(text: "Reply to Mina"),
    ])
}
