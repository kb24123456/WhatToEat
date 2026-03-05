import UIKit

enum ScreenMetrics {
    static var bounds: CGRect {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        if let activeScene = scenes.first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
            return activeScene.screen.bounds
        }

        if let firstScene = scenes.first {
            return firstScene.screen.bounds
        }

        return .zero
    }
}
