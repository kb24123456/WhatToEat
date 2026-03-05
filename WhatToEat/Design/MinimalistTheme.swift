//
//  MinimalistTheme.swift
//  WhatToEat
//
//  极简INS风主题配置
//  设计理念：静谧的东方美学
//

import SwiftUI

// MARK: - 极简主题配置
enum MinimalistTheme {
    
    // MARK: - 色彩系统
    enum Colors {
        // 背景 - 纯净米白渐变
        static let backgroundStart = Color(hex: "#FAFAF8")  // 暖白
        static let backgroundEnd = Color(hex: "#F5F5F3")    // 浅灰
        
        // 卡片 - 毛玻璃基础
        static let cardBackground = Color(hex: "#FFFFFF").opacity(0.25)
        static let cardBorder = Color(hex: "#FFFFFF").opacity(0.6)
        static let cardInnerBorder = Color(hex: "#FFFFFF").opacity(0.4)
        
        // 文字 - 层次灰
        static let textPrimary = Color(hex: "#2C2C2C")      // 深灰
        static let textSecondary = Color(hex: "#6B6B6B")    // 中灰
        static let textTertiary = Color(hex: "#9B9B9B")     // 浅灰
        
        // 点缀 - 淡粉
        static let accentPink = Color(hex: "#FFB5B5")       // 淡粉
        static let accentPinkLight = Color(hex: "#FFE0E0")  // 浅粉
        static let accentPinkUltraLight = Color(hex: "#FFF0F0") // 极浅粉
        
        // 宜忌
        static let yiColor = Color(hex: "#7CB342")          // 柔和绿
        static let yiBackground = Color(hex: "#7CB342").opacity(0.08)
        static let jiColor = Color(hex: "#E57373")          // 柔和红
        static let jiBackground = Color(hex: "#E57373").opacity(0.08)
    }
    
    // MARK: - 字体规范
    enum Typography {
        // 大标题
        static let titleLarge = Font.system(size: 28, weight: .light, design: .rounded)
        
        // 中标题
        static let titleMedium = Font.system(size: 20, weight: .light, design: .rounded)
        
        // 正文
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        
        // 小字
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        
        // 大字强调
        static let display = Font.system(size: 32, weight: .light, design: .rounded)
    }
    
    // MARK: - 间距系统
    enum Spacing {
        // 卡片内边距
        static let cardPadding: CGFloat = 32
        
        // 元素间距
        static let large: CGFloat = 24
        static let medium: CGFloat = 16
        static let small: CGFloat = 8
        
        // 圆角
        static let cardCornerRadius: CGFloat = 32      // 超圆角
        static let innerCornerRadius: CGFloat = 16     // 内部组件
        static let smallCornerRadius: CGFloat = 12     // 小元素
    }
    
    // MARK: - 阴影
    enum Shadows {
        // 卡片阴影 - 柔和
        static let card = ShadowStyle(
            color: Color.black.opacity(0.04),
            radius: 40,
            x: 0,
            y: 20
        )
        
        // 小元素阴影
        static let small = ShadowStyle(
            color: Color.black.opacity(0.06),
            radius: 10,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - 动画
    enum Animations {
        // 入场动画
        static let entrance = Animation.easeOut(duration: 0.6)
        static let entranceDelayed = Animation.easeOut(duration: 0.4).delay(0.2)
        
        // 交互动画
        static let interaction = Animation.easeInOut(duration: 0.2)
        
        // 弹簧动画
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    }
}

// MARK: - 阴影样式结构
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View扩展
extension View {
    /// 应用毛玻璃卡片样式
    func minimalistCardStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#FFFFFF").opacity(0.3),
                        Color(hex: "#FFFFFF").opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(MinimalistTheme.Spacing.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: MinimalistTheme.Spacing.cardCornerRadius)
                    .stroke(MinimalistTheme.Colors.cardBorder, lineWidth: 0.5)
            )
            .shadow(
                color: MinimalistTheme.Shadows.card.color,
                radius: MinimalistTheme.Shadows.card.radius,
                x: MinimalistTheme.Shadows.card.x,
                y: MinimalistTheme.Shadows.card.y
            )
    }
    
    /// 应用毛玻璃小卡片样式
    func minimalistInnerCardStyle() -> some View {
        self
            .background(.thinMaterial)
            .cornerRadius(MinimalistTheme.Spacing.innerCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: MinimalistTheme.Spacing.innerCornerRadius)
                    .stroke(MinimalistTheme.Colors.cardInnerBorder, lineWidth: 0.5)
            )
    }
}
