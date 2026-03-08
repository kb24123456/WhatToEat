import Foundation
import Combine
import StoreKit

enum PrimeMembershipPlan: String, CaseIterable {
    case monthly
    case yearly
    case lifetime

    var title: String {
        switch self {
        case .monthly:
            return "月付"
        case .yearly:
            return "年付"
        case .lifetime:
            return "永久"
        }
    }

    var productID: String {
        switch self {
        case .monthly:
            return "com.pigdog.WhatToEat.prime.monthly"
        case .yearly:
            return "com.pigdog.WhatToEat.prime.yearly"
        case .lifetime:
            return "com.pigdog.WhatToEat.prime.lifetime"
        }
    }

    var priority: Int {
        switch self {
        case .monthly:
            return 1
        case .yearly:
            return 2
        case .lifetime:
            return 3
        }
    }

    init?(productID: String) {
        switch productID {
        case Self.monthly.productID:
            self = .monthly
        case Self.yearly.productID:
            self = .yearly
        case Self.lifetime.productID:
            self = .lifetime
        default:
            return nil
        }
    }

    static var productIDs: [String] {
        allCases.map(\.productID)
    }
}

enum PrimePurchaseResult {
    case success(PrimeMembershipPlan)
    case pending
    case cancelled
    case failed(String)
}

enum PrimeRestoreResult {
    case restored(PrimeMembershipPlan)
    case nothingToRestore
    case failed(String)
}

@MainActor
final class PrimeAccessManager: ObservableObject {
    static let shared = PrimeAccessManager()

    @Published private(set) var activePlan: PrimeMembershipPlan?
    @Published private(set) var availableProducts: [PrimeMembershipPlan: Product] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var hasLoadedProducts = false
    @Published private(set) var lastStoreError: String?

    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?
    private var hasPreparedStore = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let rawValue = defaults.string(forKey: AppSettingsKeys.primeMembershipPlan) {
            activePlan = PrimeMembershipPlan(rawValue: rawValue)
        } else {
            activePlan = nil
        }

        updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var isPrimeActive: Bool {
        activePlan != nil
    }

    var activePlanTitle: String? {
        activePlan?.title
    }

    var hasAnyPurchasableProduct: Bool {
        !availableProducts.isEmpty
    }

    func prepareStore(forceRefresh: Bool = false) async {
        guard forceRefresh || !hasPreparedStore else { return }
        hasPreparedStore = true
        await loadProducts()
        await refreshEntitlements()
    }

    func displayPrice(for plan: PrimeMembershipPlan) -> String? {
        availableProducts[plan]?.displayPrice
    }

    func product(for plan: PrimeMembershipPlan) -> Product? {
        availableProducts[plan]
    }

    func purchase(_ plan: PrimeMembershipPlan) async -> PrimePurchaseResult {
        guard let product = availableProducts[plan] else {
            return .failed("当前套餐尚未在 App Store Connect 配置完成")
        }

        isPurchasing = true
        lastStoreError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                guard case .verified(let transaction) = verificationResult else {
                    return .failed("交易校验失败，无法确认 Prime 权益")
                }

                await transaction.finish()
                await refreshEntitlements()
                return .success(activePlan ?? plan)

            case .pending:
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                return .failed("出现未识别的购买结果")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> PrimeRestoreResult {
        isRestoring = true
        lastStoreError = nil
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()

            if let activePlan {
                return .restored(activePlan)
            }
            return .nothingToRestore
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: PrimeMembershipPlan.productIDs)
            availableProducts = Dictionary(
                uniqueKeysWithValues: products.compactMap { product in
                    guard let plan = PrimeMembershipPlan(productID: product.id) else { return nil }
                    return (plan, product)
                }
            )
            hasLoadedProducts = true

            if availableProducts.count != PrimeMembershipPlan.allCases.count {
                lastStoreError = "部分 Prime 商品尚未在 App Store Connect 配置完成"
            }
        } catch {
            lastStoreError = "无法连接 App Store 商品：\(error.localizedDescription)"
        }
    }

    private func refreshEntitlements() async {
        var resolvedPlan: PrimeMembershipPlan?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  let plan = PrimeMembershipPlan(productID: transaction.productID) else {
                continue
            }

            if resolvedPlan == nil || plan.priority > (resolvedPlan?.priority ?? 0) {
                resolvedPlan = plan
            }
        }

        activePlan = resolvedPlan
        persistActivePlan(resolvedPlan)
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func persistActivePlan(_ plan: PrimeMembershipPlan?) {
        if let plan {
            defaults.set(plan.rawValue, forKey: AppSettingsKeys.primeMembershipPlan)
        } else {
            defaults.removeObject(forKey: AppSettingsKeys.primeMembershipPlan)
        }
    }
}
