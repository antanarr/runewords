import Foundation
import StoreKit
import Combine

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: self.map { (transform($0.key), $0.value) })
    }
}

typealias ProductID = String
// Known product identifiers (configure these in App Store Connect)
enum StoreProductID: String, CaseIterable {
    case coinsTiny       = "coins.tiny"
    case coinsSmall      = "coins.small"
    case coinsMedium     = "coins.medium"
    case coinsLarge      = "coins.large"
    case coinsXLarge     = "coins.xlarge"
    case starterBundle   = "starter.bundle"
    case removeAds       = "entitlement.removeads"
    case plusMonthly     = "sub.plus.monthly"
}

struct StoreConstants {
    static let plusDailyBonus: Int = 75
    static let freeClarityHintPerDay: Int = 1
}

extension Notification.Name {
    static let iapEntitlementsUpdated = Notification.Name("IAP.entitlementsUpdated")
    static let storeGrantCoins        = Notification.Name("Store.GrantCoins")
    static let storeFreeClarityAvail  = Notification.Name("Store.FreeClarityAvailable")
}

@MainActor
final class StoreViewModel: ObservableObject {
    static let shared = StoreViewModel()

    @Published var isPurchasing = false
    @Published var products: [Product] = []
    @Published var purchaseSuccess = false
    @Published var purchaseFailure = false
    @Published var entitlements: [ProductID: Bool] = [:]
    @Published var hasRemoveAds: Bool = false
    @Published var hasPlus: Bool = false
    @Published var dailyBonusClaimedToday: Bool = false

    // Convenience groupings for the Store UI
    var coinProducts: [Product] {
        products.filter { $0.id.hasPrefix("coins.") }.sorted {
            (coinAmount(for: $0) ?? 0) < (coinAmount(for: $1) ?? 0)
        }
    }
    var starterBundleProduct: Product? { products.first(where: { $0.id == StoreProductID.starterBundle.rawValue }) }
    var removeAdsProduct: Product? { products.first(where: { $0.id == StoreProductID.removeAds.rawValue }) }
    var plusMonthlyProduct: Product? { products.first(where: { $0.id == StoreProductID.plusMonthly.rawValue }) }

    /// Map a coin product id to its coin amount for UI badges and analytics
    func coinAmount(for product: Product) -> Int? {
        switch product.id {
        case StoreProductID.coinsTiny.rawValue:    return 200
        case StoreProductID.coinsSmall.rawValue:   return 700
        case StoreProductID.coinsMedium.rawValue:  return 1300
        case StoreProductID.coinsLarge.rawValue:   return 2800
        case StoreProductID.coinsXLarge.rawValue:  return 6000
        case StoreProductID.starterBundle.rawValue:return 900
        default: return nil
        }
    }

    private var observers: [AnyCancellable] = []
    private let iap = IAPManager.shared

    private init() {
        // NotificationCenter Combine publishers are cleaner than the old target/selector pattern
        NotificationCenter.default.publisher(for: .iapPurchaseSuccess)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isPurchasing = false
                self?.purchaseSuccess = true
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: .iapPurchaseFailed)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isPurchasing = false
                self?.purchaseFailure = true
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: .iapRestoreCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isPurchasing = false
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: .iapEntitlementsUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.updateAllEntitlements()
                }
            }
            .store(in: &observers)

        // Load available products and entitlements
        Task {
            await self.reload()
        }
    }

    private func updateAllEntitlements() async {
        self.entitlements = await self.iap.loadEntitlements().mapKeys { $0.rawValue }
        self.updateEntitlementFlags()
        self.refreshDailyBonusStatus()
    }

    private func updateEntitlementFlags() {
        let e = entitlements
        hasRemoveAds = e[StoreProductID.removeAds.rawValue] ?? false
        hasPlus      = e[StoreProductID.plusMonthly.rawValue] ?? false
    }

    private func refreshDailyBonusStatus() {
        let key = "plus.daily.lastClaimDate"
        if let last = UserDefaults.standard.object(forKey: key) as? Date {
            dailyBonusClaimedToday = Calendar.current.isDate(last, inSameDayAs: Date())
        } else {
            dailyBonusClaimedToday = false
        }
    }

    /// Public: reload products & entitlements (e.g., pull-to-refresh)
    func reload() async {
        isPurchasing = true
        defer { isPurchasing = false }
        await iap.loadProducts()
        // Products are now accessible via iap.products after loadProducts
        products = iap.products
        await updateAllEntitlements()
    }

    /// Claim daily subscription stipend if eligible.
    func claimPlusDailyBonusIfEligible() {
        guard hasPlus else { return }
        let key = "plus.daily.lastClaimDate"
        let today = Calendar.current.startOfDay(for: Date())
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) {
            dailyBonusClaimedToday = true
            return
        }
        // Mark claimed and award
        dailyBonusClaimedToday = true
        UserDefaults.standard.set(today, forKey: key)
        
        // Grant coins via notification to ensure a single source of truth for coin changes
        let payload: [String: Any] = ["amount": StoreConstants.plusDailyBonus, "source": "plus_daily_bonus"]
        NotificationCenter.default.post(name: .storeGrantCoins, object: nil, userInfo: payload)
        NotificationCenter.default.post(name: .storeFreeClarityAvail, object: nil)
    }

    func purchase(product: Product) async {
        isPurchasing = true
        purchaseSuccess = false
        purchaseFailure = false
        let purchaseResult = await iap.purchase(productID: product.id)
        if purchaseResult {
            AnalyticsManager.shared.logPurchase(product)
        }
    }

    func restore() async {
        isPurchasing = true
        purchaseSuccess = false
        purchaseFailure = false
        await iap.restorePurchases()
    }
}
