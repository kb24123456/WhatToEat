import Foundation
import LocalAuthentication
import Combine

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    @Published var isLocked = false
    @Published var lastErrorMessage: String?

    private var hasEvaluatedColdStart = false

    private init() {}

    var isFaceIDEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppSettingsKeys.faceIDEnabled) && PrimeAccessManager.shared.isPrimeActive
    }

    func setFaceIDEnabled(_ enabled: Bool) {
        guard PrimeAccessManager.shared.isPrimeActive || !enabled else { return }
        UserDefaults.standard.set(enabled, forKey: AppSettingsKeys.faceIDEnabled)
    }

    var isFaceIDAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return canEvaluate && context.biometryType == .faceID
    }

    func evaluateColdStartIfNeeded() {
        guard !hasEvaluatedColdStart else { return }
        hasEvaluatedColdStart = true

        guard isFaceIDEnabled, AuthManager.shared.isSignedIn else {
            isLocked = false
            return
        }

        unlockWithFaceID()
    }

    func unlockWithFaceID() {
        guard isFaceIDEnabled, AuthManager.shared.isSignedIn else {
            isLocked = false
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "稍后"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error),
              context.biometryType == .faceID else {
            isLocked = false
            lastErrorMessage = "当前设备不支持面容 ID"
            return
        }

        isLocked = true
        lastErrorMessage = nil
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "使用面容 ID 解锁 WhatToEat"
        ) { success, authError in
            Task { @MainActor in
                if success {
                    self.isLocked = false
                    self.lastErrorMessage = nil
                } else {
                    self.isLocked = true
                    self.lastErrorMessage = authError?.localizedDescription ?? "面容 ID 验证失败"
                }
            }
        }
    }
}
