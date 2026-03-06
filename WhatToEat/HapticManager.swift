import Foundation
import UIKit
import ObjectiveC.runtime

/// 全局触觉反馈控制中心
final class HapticManager {
    static let shared = HapticManager()
    private static var hasInstalledHooks = false

    private init() {}

    static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: AppSettingsKeys.hapticFeedbackEnabled) != nil else {
            return true
        }
        return defaults.bool(forKey: AppSettingsKeys.hapticFeedbackEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: AppSettingsKeys.hapticFeedbackEnabled)
    }

    static func installGlobalHooksIfNeeded() {
        guard !hasInstalledHooks else { return }
        hasInstalledHooks = true

        swizzle(
            in: UIImpactFeedbackGenerator.self,
            originalName: "impactOccurred",
            replacementName: "wte_impactOccurredNoArgs"
        )
        swizzle(
            in: UIImpactFeedbackGenerator.self,
            originalName: "impactOccurredWithIntensity:",
            replacementName: "wte_impactOccurredWithIntensity:"
        )
        swizzle(
            in: UINotificationFeedbackGenerator.self,
            originalName: "notificationOccurred:",
            replacementName: "wte_notificationOccurred:"
        )
        swizzle(
            in: UISelectionFeedbackGenerator.self,
            originalName: "selectionChanged",
            replacementName: "wte_selectionChangedNoArgs"
        )
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private static func swizzle(in cls: AnyClass, originalName: String, replacementName: String) {
        let original = NSSelectorFromString(originalName)
        let replacement = NSSelectorFromString(replacementName)
        guard
            let originalMethod = class_getInstanceMethod(cls, original),
            let replacementMethod = class_getInstanceMethod(cls, replacement)
        else {
            return
        }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }
}

private extension UIImpactFeedbackGenerator {
    @objc(wte_impactOccurredNoArgs)
    func wte_impactOccurredNoArgs() {
        guard HapticManager.isEnabled else { return }
        self.wte_impactOccurredNoArgs()
    }

    @objc(wte_impactOccurredWithIntensity:)
    func wte_impactOccurredWithIntensity(_ intensity: CGFloat) {
        guard HapticManager.isEnabled else { return }
        self.wte_impactOccurredWithIntensity(intensity)
    }
}

private extension UINotificationFeedbackGenerator {
    @objc(wte_notificationOccurred:)
    func wte_notificationOccurred(_ notificationType: UINotificationFeedbackGenerator.FeedbackType) {
        guard HapticManager.isEnabled else { return }
        self.wte_notificationOccurred(notificationType)
    }
}

private extension UISelectionFeedbackGenerator {
    @objc(wte_selectionChangedNoArgs)
    func wte_selectionChangedNoArgs() {
        guard HapticManager.isEnabled else { return }
        self.wte_selectionChangedNoArgs()
    }
}
