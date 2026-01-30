import SwiftUI

// MARK: - WhatToEat Design System v2.0
// 设计原则：奶脂实色卡片风格 (Milky Solid Card Style)
// 核心特征：纯白实色背景 + 物理深度阴影 + 边缘高光
// 已废弃：Glassmorphism 毛玻璃风格 (v1.0)

// MARK: - 奶脂实色卡片规范 (Design System v2.0)
// 使用场景：所有卡片容器、模块包装、内容分组
// 视觉特征：温润奶白色、物理深度、柔和阴影
struct MilkyCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 32
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            )
    }
}

extension View {
    /// 奶脂实色卡片 (Design System v2.0 标准)
    /// - 背景：纯白实色 (Color.white)
    /// - 圆角：28pt (continuous)
    /// - 阴影：双层复合阴影
    /// - 高光：边缘白色描边 0.5pt
    func milkyCard(cornerRadius: CGFloat = 28) -> some View {
        modifier(MilkyCardStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - 内部输入框背景规范
// 使用场景：卡片内部的输入框、按钮、标签容器
// 视觉特征：极浅背景色，产生微弱下陷感
struct InsetBackgroundStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.softBackground)
            )
    }
}

extension View {
    /// 内部输入框背景 (产生下陷感)
    func insetBackground() -> some View {
        modifier(InsetBackgroundStyle())
    }
}

// MARK: - Premium Soft UI & Glassmorphism 组件库 (v1.0 已废弃)
// ⚠️ 以下组件已废弃，请使用新的奶脂实色卡片规范

// ✅ 规范化的标签组件
struct StandardTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// ✅ 规范化的主操作按钮 (修正版)
struct PrimaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.Colors.accent)
            .cornerRadius(AppTheme.Radius.base)
            .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Card Style ViewModifier (已更新为 MilkyCardStyle)
/// 已更新：内部实现改为 MilkyCardStyle，保持向后兼容
struct PremiumCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .milkyCard(cornerRadius: 32)
    }
}

extension View {
    /// 已更新：内部实现改为 MilkyCardStyle
    func premiumCard() -> some View {
        modifier(PremiumCardStyle())
    }
}

// MARK: - Staggered Entrance Animation
struct StaggeredEntrance: ViewModifier {
    let index: Int
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.82)
                .delay(Double(index) * 0.05),
                value: isVisible
            )
    }
}

extension View {
    func staggeredEntrance(index: Int, isVisible: Bool) -> some View {
        modifier(StaggeredEntrance(index: index, isVisible: isVisible))
    }
}

// MARK: - Glassmorphism Background (已更新为 MilkyCardStyle)
/// 已更新：内部实现改为 MilkyCardStyle，保持向后兼容
/// 注意：tint 参数已忽略，统一使用 MilkyCardStyle
struct GlassmorphismBackground: ViewModifier {
    let tint: Color
    
    func body(content: Content) -> some View {
        content
            .milkyCard(cornerRadius: 24)
    }
}

extension View {
    /// 已更新：内部实现改为 MilkyCardStyle
    func glassmorphism(tint: Color = .white) -> some View {
        modifier(GlassmorphismBackground(tint: tint))
    }
}

// MARK: - Floating Action Button (带弥散阴影)
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let accentColor: Color
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Capsule()
                        .fill(accentColor)
                )
                .shadow(color: accentColor.opacity(0.3), radius: 12, x: 0, y: 8)
                .shadow(color: accentColor.opacity(0.15), radius: 20, x: 0, y: 12)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Inset Input Style (CheckInView 收据风格)
struct InsetInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#F0F2F5"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
    }
}

extension View {
    func insetInput() -> some View {
        modifier(InsetInputStyle())
    }
}

// MARK: - Premium Accent Gradient
struct PremiumAccentGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FF6B6B"),
                Color(hex: "#FF5252")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Soft Neutral Colors
extension Color {
    static let softBackground = Color(hex: "#F8F9FB")
    static let softGray = Color(hex: "#F0F2F5")
    static let softText = Color(hex: "#2C3E50")
    static let softSecondary = Color(hex: "#7F8C8D")
}
