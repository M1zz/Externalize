import Foundation
import Observation
import StoreKit

/// Single non-consumable: $2.99 lifetime unlock.
@MainActor
@Observable
final class PurchaseManager {
    static let lifetimeProductID = "com.devkoan.externalize.lifetime"

    private(set) var product: Product?
    private(set) var isUnlocked: Bool = ProAccess.isUnlocked
    private(set) var isPurchasing = false
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    await self?.handle(result)
                }
            }
        }
        await loadProduct()
        await refreshEntitlements()
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.lifetimeProductID]).first
        } catch {
            errorMessage = "Couldn't reach the App Store. Try again later."
        }
    }

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        errorMessage = nil
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlements()
        if !isUnlocked {
            errorMessage = "No previous purchase found for this Apple ID."
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.lifetimeProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        setUnlocked(unlocked)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.lifetimeProductID {
            setUnlocked(transaction.revocationDate == nil)
        }
        await transaction.finish()
    }

    private func setUnlocked(_ unlocked: Bool) {
        isUnlocked = unlocked
        ProAccess.isUnlocked = unlocked
    }
}
