import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var appleUserID: String?
    @Published private(set) var displayName: String = ""
    @Published var showSignInSheet = false

    private init() {
        do {
            appleUserID = try KeychainStore.loadString(forKey: AppSettingsKeys.appleUserID)
            displayName = try KeychainStore.loadString(forKey: AppSettingsKeys.appleUserDisplayName) ?? ""
            migrateLegacyDefaultsIfNeeded()
        } catch {
            appleUserID = nil
            displayName = ""
            AppLogger.error("读取登录凭据失败: \(error.localizedDescription)", category: .auth)
        }
    }

    var isSignedIn: Bool {
        guard let appleUserID else { return false }
        return !appleUserID.isEmpty
    }

    var displayLabel: String {
        if !displayName.isEmpty {
            return displayName
        }
        guard let appleUserID else { return "未登录" }
        return "Apple ID · \(appleUserID.suffix(6))"
    }

    func startSignIn() {
        showSignInSheet = true
    }

    func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) -> String {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return "登录失败：凭据类型不支持"
            }

            appleUserID = credential.user
            try? KeychainStore.saveString(credential.user, forKey: AppSettingsKeys.appleUserID)

            let assembledName = [credential.fullName?.familyName, credential.fullName?.givenName]
                .compactMap { $0 }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !assembledName.isEmpty {
                displayName = assembledName
                try? KeychainStore.saveString(assembledName, forKey: AppSettingsKeys.appleUserDisplayName)
            } else {
                displayName = (try? KeychainStore.loadString(forKey: AppSettingsKeys.appleUserDisplayName)) ?? ""
            }

            showSignInSheet = false
            return "已登录 Apple ID"

        case .failure(let error):
            showSignInSheet = false
            return "登录失败：\(error.localizedDescription)"
        }
    }

    func signOut(keepLocalData: Bool = true) {
        _ = keepLocalData
        appleUserID = nil
        displayName = ""
        try? KeychainStore.deleteValue(forKey: AppSettingsKeys.appleUserID)
        try? KeychainStore.deleteValue(forKey: AppSettingsKeys.appleUserDisplayName)
    }

    func deleteAccountAssociation() {
        signOut(keepLocalData: true)
    }

    func switchAccount() {
        signOut(keepLocalData: true)
        startSignIn()
    }

    private func migrateLegacyDefaultsIfNeeded() {
        let defaults = UserDefaults.standard

        if appleUserID == nil,
           let legacyUserID = defaults.string(forKey: AppSettingsKeys.appleUserID),
           !legacyUserID.isEmpty {
            appleUserID = legacyUserID
            try? KeychainStore.saveString(legacyUserID, forKey: AppSettingsKeys.appleUserID)
            defaults.removeObject(forKey: AppSettingsKeys.appleUserID)
        }

        if displayName.isEmpty,
           let legacyDisplayName = defaults.string(forKey: AppSettingsKeys.appleUserDisplayName),
           !legacyDisplayName.isEmpty {
            displayName = legacyDisplayName
            try? KeychainStore.saveString(legacyDisplayName, forKey: AppSettingsKeys.appleUserDisplayName)
            defaults.removeObject(forKey: AppSettingsKeys.appleUserDisplayName)
        }
    }
}
