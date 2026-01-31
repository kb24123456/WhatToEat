//
//  CloudKitManager.swift
//  WhatToEat
//
//  CloudKit 管理器 - 处理 iCloud 登录状态和无感登录逻辑
//

import CloudKit
import SwiftUI
import AuthenticationServices

// MARK: - CloudKit 管理器
@Observable
class CloudKitManager: NSObject {
    static let shared = CloudKitManager()
    
    // MARK: - 状态
    var isCloudKitAvailable = false
    var isSignedIn = false
    var userID: String?
    var userName: String?
    var errorMessage: String?
    
    // MARK: - 私有属性
    private let container: CKContainer
    private var authController: ASAuthorizationController?
    
    // MARK: - 初始化
    private override init() {
        self.container = CKContainer.default()
        super.init()
        
        // 启动时检查 CloudKit 状态
        checkCloudKitStatus()
    }
    
    // MARK: - 检查 CloudKit 状态
    func checkCloudKitStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "检查 iCloud 状态失败: \(error.localizedDescription)"
                    self.isCloudKitAvailable = false
                    self.isSignedIn = false
                    return
                }
                
                switch status {
                case .available:
                    self.isCloudKitAvailable = true
                    self.fetchUserRecordID()
                case .noAccount:
                    self.isCloudKitAvailable = false
                    self.isSignedIn = false
                    self.errorMessage = "未登录 iCloud"
                case .restricted:
                    self.isCloudKitAvailable = false
                    self.isSignedIn = false
                    self.errorMessage = "iCloud 访问受限"
                case .couldNotDetermine:
                    self.isCloudKitAvailable = false
                    self.isSignedIn = false
                    self.errorMessage = "无法确定 iCloud 状态"
                default:
                    self.isCloudKitAvailable = false
                    self.isSignedIn = false
                    self.errorMessage = "未知状态"
                }
            }
        }
    }
    
    // MARK: - 获取用户记录 ID
    private func fetchUserRecordID() {
        container.fetchUserRecordID { [weak self] recordID, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "获取用户 ID 失败: \(error.localizedDescription)"
                    self.isSignedIn = false
                    return
                }
                
                if let recordID = recordID {
                    self.userID = recordID.recordName
                    self.isSignedIn = true
                    self.fetchUserName()
                    
                    // 保存到 UserDefaults
                    UserDefaults.standard.set(recordID.recordName, forKey: "cloudKitUserID")
                }
            }
        }
    }
    
    // MARK: - 获取用户名
    // 注意：iOS 17+ 弃用了用户发现 API，这里简化处理
    private func fetchUserName() {
        // 使用 Sign in with Apple 获取的用户名，或从 UserDefaults 读取
        if let savedName = UserDefaults.standard.string(forKey: "cloudKitUserName") {
            self.userName = savedName
        }
    }
    
    // MARK: - Sign in with Apple
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        authController = ASAuthorizationController(authorizationRequests: [request])
        authController?.delegate = self
        authController?.presentationContextProvider = self
        authController?.performRequests()
    }
    
    // MARK: - 登出
    func signOut() {
        isSignedIn = false
        userID = nil
        userName = nil
        UserDefaults.standard.removeObject(forKey: "cloudKitUserID")
        UserDefaults.standard.removeObject(forKey: "cloudKitUserName")
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension CloudKitManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            DispatchQueue.main.async {
                self.userID = appleIDCredential.user
                self.isSignedIn = true
                
                // 获取用户名
                if let fullName = appleIDCredential.fullName {
                    self.userName = "\(fullName.givenName ?? "") \(fullName.familyName ?? "")".trimmingCharacters(in: .whitespaces)
                    UserDefaults.standard.set(self.userName, forKey: "cloudKitUserName")
                }
                
                UserDefaults.standard.set(appleIDCredential.user, forKey: "cloudKitUserID")
                
                // 重新检查 CloudKit 状态
                self.checkCloudKitStatus()
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "登录失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension CloudKitManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 获取当前窗口
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
