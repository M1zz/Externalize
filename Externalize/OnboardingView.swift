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
            title: "Don't spend your brain on it",
            message: "Externalize holds the things you only need for a few hours, then forgets them for you.",
            points: [
                Point(symbol: "car.fill", text: "Where you parked"),
                Point(symbol: "lock.fill", text: "Your locker code"),
                Point(symbol: "bed.double.fill", text: "Your hotel room number"),
                Point(symbol: "number", text: "Door and gate codes"),
            ]
        ),
        OnboardingPage(
            symbol: "plus.circle.fill",
            title: "Save it in seconds",
            message: "Tap + in the top corner, then:",
            points: [
                Point(symbol: "square.grid.2x2.fill", text: "Pick a type — parking, locker, room, code"),
                Point(symbol: "keyboard", text: "Type the value (a label is optional)"),
                Point(symbol: "timer", text: "Choose when to forget: 1h, 8h, or 24h"),
                Point(symbol: "gift.fill", text: "Free keeps \(ProAccess.freeSlotLimit) items at a time. Unlock unlimited anytime."),
            ]
        ),
        OnboardingPage(
            symbol: "hourglass",
            title: "It forgets for you",
            message: "When time runs out, it deletes itself. No archive, no history.",
            points: [
                Point(symbol: "hand.tap.fill", text: "Tap a card to copy the value"),
                Point(symbol: "arrow.right", text: "Swipe right to keep it 24 more hours"),
                Point(symbol: "arrow.left", text: "Swipe left to forget it now"),
            ]
        ),
        OnboardingPage(
            symbol: "lock.iphone",
            title: "Keep it on your Lock Screen",
            message: "Add the widget and see it without unlocking your phone.",
            points: [
                Point(symbol: "hand.point.up.left.fill", text: "Long-press the Lock Screen and tap Customize"),
                Point(symbol: "rectangle.stack.fill", text: "Choose Lock Screen, then tap the widget area"),
                Point(symbol: "plus.square.fill", text: "Add the Externalize widget"),
            ]
        ),
        OnboardingPage(
            symbol: "mic.fill",
            title: "Save without opening the app",
            message: "Use Siri, the Shortcuts app, or the Action Button.",
            points: [
                Point(symbol: "waveform", text: "Say “Remember in Externalize”"),
                Point(symbol: "bolt.fill", text: "Assign the Remember shortcut to the Action Button"),
                Point(symbol: "square.on.square", text: "Or add it to any shortcut in the Shortcuts app"),
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
