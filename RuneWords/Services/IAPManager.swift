//
//  IAPManager.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/27/25.
//

import Foundation
import StoreKit

// Notification names
extension Notification.Name {
    static let iapPurchaseSuccess   = Notification.Name("IAPManagerPurchaseSuccess")
    static let iapPurchaseFailed    = Notification.Name("IAPManagerPurchaseFailed")
    static let iapRestoreCompleted  = Notification.Name("IAPManagerRestoreCompleted")
}

@MainActor
final class IAPManager: ObservableObject {
    static let shared = IAPManager()
    private init() {}
    
    // MARK: - IAPServiceProtocol conformance
    @Published var hasPlus: Bool = false
    @Published var hasRemoveAds: Bool = false
    @Published var products: [Product] = []
    @Published var isProcessingPurchase: Bool = false
    @Published var purchaseError: Error?

    enum ProductID: String, CaseIterable {
        case coinsTiny     = "coins.tiny"
        case coinsSmall    = "coins.small"
        case coinsMedium   = "coins.medium"
        case coinsLarge    = "coins.large"
        case coinsXLarge   = "coins.xlarge"
        case starterBundle = "starter.bundle"
        case removeAds     = "entitlement.removeads"
        case plusMonthly   = "sub.plus.monthly"
    }

    func loadProducts() async {
        do {
            let ids = ProductID.allCases.map { $0.rawValue }
            let fetchedProducts = try await Product.products(for: ids)
            products = fetchedProducts
            
            // Update entitlement states based on current transactions
            let entitlements = await loadEntitlements()
            hasPlus = entitlements[.plusMonthly] ?? false
            hasRemoveAds = entitlements[.removeAds] ?? false
        } catch {
            print("IAP loadProducts error: \(error)")
            purchaseError = error
            products = []
        }
    }

    // Legacy purchase method by product ID
    func purchase(productID: String) async -> Bool {
        do {
            let fetched = try await Product.products(for: [productID])
            guard let product = fetched.first else {
                print("IAP: product not found: \(productID)")
                return false
            }
            // Use the protocol method
            try await purchase(product)
            return true
        } catch {
            print("IAP purchase error: \(error)")
            NotificationCenter.default.post(name: .iapPurchaseFailed, object: productID)
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            NotificationCenter.default.post(name: .iapRestoreCompleted, object: nil)
            NotificationCenter.default.post(name: .iapEntitlementsUpdated, object: nil)
        } catch {
            print("IAP restore error: \(error)")
            NotificationCenter.default.post(name: .iapPurchaseFailed, object: nil)
        }
    }
    
    // MARK: - IAPServiceProtocol methods
    func purchase(_ product: Product) async throws {
        isProcessingPurchase = true
        purchaseError = nil
        defer { isProcessingPurchase = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handle(transaction: transaction)
                await transaction.finish()
                NotificationCenter.default.post(name: .iapEntitlementsUpdated, object: nil)
            case .userCancelled, .pending:
                let error = NSError(domain: "IAPManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Purchase cancelled or pending"])
                purchaseError = error
                throw error
            @unknown default:
                let error = NSError(domain: "IAPManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown purchase result"])
                purchaseError = error
                throw error
            }
        } catch {
            purchaseError = error
            throw error
        }
    }

    private func coinGrant(for productID: String) -> Int? {
        switch productID {
        case ProductID.coinsTiny.rawValue:     return 200
        case ProductID.coinsSmall.rawValue:    return 700
        case ProductID.coinsMedium.rawValue:   return 1300
        case ProductID.coinsLarge.rawValue:    return 2800
        case ProductID.coinsXLarge.rawValue:   return 6000
        case ProductID.starterBundle.rawValue: return 900
        default: return nil
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func grantEntitlement(for productID: String) {
        // Non‑consumables & subs: persist legacy remove-ads flag and notify; subscription state comes from StoreKit.
        if productID == ProductID.removeAds.rawValue {
            UserDefaults.standard.set(true, forKey: "removeAdsPurchased")
            NotificationCenter.default.post(name: .iapEntitlementsUpdated, object: nil)
        }
        if productID == ProductID.plusMonthly.rawValue {
            NotificationCenter.default.post(name: .iapEntitlementsUpdated, object: nil)
        }

        // Consumables (coins) — grant immediately
        if let delta = coinGrant(for: productID) {
            guard var player = PlayerService.shared.player else { return }
            player.coins += delta
            PlayerService.shared.player = player
            PlayerService.shared.saveProgress(player: player.toPlayerData())
            HapticManager.shared.play(.success)  // Add haptic feedback
            NotificationCenter.default.post(name: .iapPurchaseSuccess, object: productID)
            return
        }

        // Unknown product or non-consumable: still signal success for UI
        NotificationCenter.default.post(name: .iapPurchaseSuccess, object: productID)
    }

    private func handle(transaction: Transaction) async {
        let productID = transaction.productID
        grantEntitlement(for: productID)
    }

    func observeTransactions() {
        Task.detached(priority: .background) {
            for await update in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(update)
                    await self.handle(transaction: transaction)
                    await transaction.finish()
                    NotificationCenter.default.post(name: .iapEntitlementsUpdated, object: nil)
                } catch {
                    print("IAP update error: \(error)")
                }
            }
        }
    }

    func loadEntitlements() async -> [ProductID: Bool] {
        var entitlements: [ProductID: Bool] = [:]
        // Defaults
        for id in ProductID.allCases { entitlements[id] = false }

        // Check current entitlements via StoreKit 2
        for await result in Transaction.currentEntitlements {
            do {
                let transaction: Transaction = try checkVerified(result)
                switch transaction.productID {
                case ProductID.removeAds.rawValue:
                    entitlements[.removeAds] = true
                case ProductID.plusMonthly.rawValue:
                    entitlements[.plusMonthly] = true
                default:
                    break
                }
            } catch {
                print("IAP currentEntitlements verify error: \(error)")
            }
        }

        // Fallback for legacy remove-ads purchases stored in defaults
        if UserDefaults.standard.bool(forKey: "removeAdsPurchased") {
            entitlements[.removeAds] = true
        }
        return entitlements
    }
}
