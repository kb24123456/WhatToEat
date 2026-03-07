import Foundation
import Combine

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
}

@MainActor
final class PrimeAccessManager: ObservableObject {
    static let shared = PrimeAccessManager()

    @Published private(set) var activePlan: PrimeMembershipPlan?

    private init(defaults: UserDefaults = .standard) {
        if let rawValue = defaults.string(forKey: AppSettingsKeys.primeMembershipPlan) {
            activePlan = PrimeMembershipPlan(rawValue: rawValue)
        } else {
            activePlan = nil
        }
    }

    var isPrimeActive: Bool {
        activePlan != nil
    }

    func activate(_ plan: PrimeMembershipPlan, defaults: UserDefaults = .standard) {
        activePlan = plan
        defaults.set(plan.rawValue, forKey: AppSettingsKeys.primeMembershipPlan)
    }

    func restore(defaults: UserDefaults = .standard) -> Bool {
        guard let rawValue = defaults.string(forKey: AppSettingsKeys.primeMembershipPlan),
              let plan = PrimeMembershipPlan(rawValue: rawValue) else {
            activePlan = nil
            return false
        }

        activePlan = plan
        return true
    }
}
