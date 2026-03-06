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
        appleUserID = UserDefaults.standard.string(forKey: AppSettingsKeys.appleUserID)
        displayName = UserDefaults.standard.string(forKey: AppSettingsKeys.appleUserDisplayName) ?? ""
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
            UserDefaults.standard.set(credential.user, forKey: AppSettingsKeys.appleUserID)

            let assembledName = [credential.fullName?.familyName, credential.fullName?.givenName]
                .compactMap { $0 }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !assembledName.isEmpty {
                displayName = assembledName
                UserDefaults.standard.set(assembledName, forKey: AppSettingsKeys.appleUserDisplayName)
            } else {
                displayName = UserDefaults.standard.string(forKey: AppSettingsKeys.appleUserDisplayName) ?? ""
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
        UserDefaults.standard.removeObject(forKey: AppSettingsKeys.appleUserID)
        UserDefaults.standard.removeObject(forKey: AppSettingsKeys.appleUserDisplayName)
    }

    func switchAccount() {
        signOut(keepLocalData: true)
        startSignIn()
    }
}
