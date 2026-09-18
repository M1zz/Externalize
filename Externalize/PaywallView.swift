import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 12)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Unlimited slots")
                        .font(.largeTitle.bold())
                    Text("Free keeps \(ProAccess.freeSlotLimit) things at a time. Lifetime keeps as many as your day needs — parking, locker, room, gate code, all at once.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    feature("infinity", "Unlimited active items")
                    feature("lock.iphone", "Everything on your Lock Screen widget")
                    feature("heart.fill", "One payment. No subscription. Ever.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)

                Spacer()

                if purchases.isUnlocked {
                    Label("Unlocked. Thank you.", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    VStack(spacing: 12) {
                        Button {
                            Task { await purchases.purchase() }
                        } label: {
                            Group {
                                if purchases.isPurchasing {
                                    ProgressView()
                                } else {
                                    Text(buyTitle)
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(purchases.product == nil || purchases.isPurchasing)

                        Button("Restore Purchase") {
                            Task { await purchases.restore() }
                        }
                        .font(.footnote)
                    }
                }

                if let message = purchases.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if purchases.product == nil {
                    await purchases.loadProduct()
                }
            }
        }
    }

    private var buyTitle: String {
        if let product = purchases.product {
            return String(localized: "Unlock Lifetime — \(product.displayPrice)")
        }
        return String(localized: "Loading…")
    }

    private func feature(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    PaywallView()
        .environment(PurchaseManager())
}
