import SwiftUI

/// First-launch walkthrough: what the app is for and how to use it.
/// Also reachable later from the "How it works" toolbar button.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var selection = 0

    private let pages = OnboardingPage.all

    private var isLastPage: Bool {
        selection == pages.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            TabView(selection: $selection) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: advance) {
                Group {
                    if isLastPage {
                        Text("Get Started")
                    } else {
                        Text("Next")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func advance() {
        if isLastPage {
            onFinish()
        } else {
            withAnimation { selection += 1 }
        }
    }
}

// MARK: - Page

struct OnboardingPage {
    struct Point: Identifiable {
        let id = UUID()
        let symbol: String
        let text: LocalizedStringResource
    }

    let symbol: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let points: [Point]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            symbol: "brain.head.profile",
            title: "Get it out of your head",
            message: "“Oh right, I need to…” — write it down here and stop holding onto it.",
            points: [
                Point(symbol: "tshirt.fill", text: "Pick up the dry cleaning"),
                Point(symbol: "envelope.fill", text: "Reply to that email"),
                Point(symbol: "cart.fill", text: "Buy batteries"),
            ]
        ),
        OnboardingPage(
            symbol: "square.and.pencil",
            title: "Three seconds, then let go",
            message: "Type a few words and you're done. No lists, no folders, no due dates.",
            points: [
                Point(symbol: "lock.iphone", text: "Tap the Lock Screen widget to open a blank line"),
                Point(symbol: "waveform", text: "Or say “Remember in Externalize”"),
                Point(symbol: "bolt.fill", text: "Or put it on the Action Button"),
            ]
        ),
        OnboardingPage(
            symbol: "moon.stars.fill",
            title: "In the evening, settle them",
            message: "At 9 PM you get one reminder if anything is still open. Each one gets an ending:",
            points: [
                Point(symbol: "checkmark.circle.fill", text: "Do it now — if it takes two minutes"),
                Point(symbol: "calendar.badge.clock", text: "Pick a time — you'll be reminded then"),
                Point(symbol: "trash.fill", text: "Drop it — if it doesn't really need doing"),
            ]
        ),
        OnboardingPage(
            symbol: "sparkles",
            title: "Nothing is left to rot",
            message: "Unlike a notes app, nothing piles up here. A clear list means a clear head.",
            points: [
                Point(symbol: "exclamationmark.circle", text: "Things waiting over a day are marked"),
                Point(symbol: "bell.fill", text: "Scheduled ones come back on time"),
                Point(symbol: "gearshape.fill", text: "Change the reminder time in Settings"),
            ]
        ),
    ]
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: page.symbol)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 112, height: 112)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                    .padding(.top, 24)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(page.title)
                        .font(.title.bold())
                    Text(page.message)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(page.points) { point in
                        Label {
                            Text(point.text)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: point.symbol)
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview {
    OnboardingView {}
}
