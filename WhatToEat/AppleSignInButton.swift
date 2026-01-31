//
//  AppleSignInButton.swift
//  WhatToEat
//
//  奶脂风格 Apple ID 登录按钮
//

import SwiftUI
import AuthenticationServices

// MARK: - 奶脂风格 Apple ID 登录按钮
struct MilkyAppleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Apple Logo
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                // 文字
                Text("使用 Apple ID 登录")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                ZStack {
                    // 渐变背景
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.9),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // 玻璃质感叠加
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.15),
                radius: 20,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(MilkyButtonStyle())
    }
}

// MARK: - 奶脂按钮样式
struct MilkyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 登录提示卡片
struct SignInPromptCard: View {
    let onSignIn: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.Colors.darkText)
            }
            
            // 标题和描述
            VStack(spacing: 8) {
                Text("开启云端同步")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text("登录 Apple ID 以在多台设备间同步您的餐厅收藏")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // 登录按钮
            MilkyAppleSignInButton(action: onSignIn)
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
        )
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 24,
            x: 0,
            y: 8
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - 登录状态指示器
struct CloudSyncStatusView: View {
    @State private var cloudKitManager = CloudKitManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // 状态图标
            Image(systemName: statusIcon)
                .font(.system(size: 14))
                .foregroundColor(statusColor)
            
            // 状态文字
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.mediumGray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.5))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
        )
    }
    
    private var statusIcon: String {
        if cloudKitManager.isSignedIn {
            return "checkmark.circle.fill"
        } else if cloudKitManager.isCloudKitAvailable {
            return "icloud.fill"
        } else {
            return "icloud.slash.fill"
        }
    }
    
    private var statusColor: Color {
        if cloudKitManager.isSignedIn {
            return AppTheme.Colors.accent
        } else if cloudKitManager.isCloudKitAvailable {
            return AppTheme.Colors.babyBlue
        } else {
            return AppTheme.Colors.mediumGray
        }
    }
    
    private var statusText: String {
        if cloudKitManager.isSignedIn {
            return "云端同步已开启"
        } else if cloudKitManager.isCloudKitAvailable {
            return "iCloud 可用"
        } else {
            return "未登录 iCloud"
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        MilkyDiffuseBackground()
        
        VStack(spacing: 20) {
            SignInPromptCard {
                print("Sign in tapped")
            }
            
            CloudSyncStatusView()
        }
    }
}
