//
//  DiffuseGradientBackground.swift
//  WhatToEat
//
//  弥散渐变背景组件 - 参考抖音/剪映设计风格
//  扩大色彩面积到整个背景的上四分之三部分
//

import SwiftUI

// MARK: - 弥散渐变背景
struct DiffuseGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    // 可自定义的颜色配置
    var topLeadingColor: Color = Color(hex: "#FFB6C1")  // 淡粉色
    var topTrailingColor: Color = Color(hex: "#B0E0E6") // 淡青色
    var bottomColor: Color = AppTheme.Colors.pageBackground
    var warmGlowColor: Color? = nil
    var useGlobalDarkPalette: Bool = true
    
    // 模糊半径
    var blurRadius: CGFloat = 80
    
    // 渐变扩散范围 - 扩大到覆盖上四分之三
    var gradientRadius: CGFloat = 600
    
    // 颜色透明度
    var colorOpacity: Double = 0.5

    private var resolvedTopLeadingColor: Color {
        if colorScheme == .dark && useGlobalDarkPalette {
            return Color.fixedHex("#162338")
        }
        return topLeadingColor
    }

    private var resolvedTopTrailingColor: Color {
        if colorScheme == .dark && useGlobalDarkPalette {
            return Color.fixedHex("#2D4652")
        }
        return topTrailingColor
    }

    private var resolvedBottomColor: Color {
        if colorScheme == .dark && useGlobalDarkPalette {
            return AppTheme.Colors.pageBackground
        }
        return bottomColor
    }

    private var resolvedWarmGlowColor: Color {
        if let warmGlowColor {
            return warmGlowColor
        }
        return colorScheme == .dark ? Color.fixedHex("#585149") : Color.fixedHex("#D9C8B9")
    }

    private var resolvedOpacity: Double {
        colorScheme == .dark ? colorOpacity * 0.46 : colorOpacity
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 底层：白色底色
                resolvedBottomColor
                    .ignoresSafeArea()
                
                // 左上角：淡粉色光晕 - 超大幅扩大面积
                RadialGradient(
                    colors: [
                        resolvedTopLeadingColor.opacity(resolvedOpacity),
                        resolvedTopLeadingColor.opacity(resolvedOpacity * 0.75),
                        resolvedTopLeadingColor.opacity(resolvedOpacity * 0.45),
                        resolvedTopLeadingColor.opacity(resolvedOpacity * 0.2),
                        resolvedTopLeadingColor.opacity(resolvedOpacity * 0.05),
                        Color.clear
                    ],
                    center: .init(x: 0.0, y: 0.08),
                    startRadius: 0,
                    endRadius: geometry.size.width * 1.2
                )
                .blur(radius: blurRadius)
                .ignoresSafeArea()
                
                // 右上角：淡青色光晕 - 超大幅扩大面积
                RadialGradient(
                    colors: [
                        resolvedTopTrailingColor.opacity(resolvedOpacity * 0.95),
                        resolvedTopTrailingColor.opacity(resolvedOpacity * 0.7),
                        resolvedTopTrailingColor.opacity(resolvedOpacity * 0.4),
                        resolvedTopTrailingColor.opacity(resolvedOpacity * 0.15),
                        resolvedTopTrailingColor.opacity(resolvedOpacity * 0.04),
                        Color.clear
                    ],
                    center: .init(x: 1.0, y: 0.06),
                    startRadius: 0,
                    endRadius: geometry.size.width * 1.15
                )
                .blur(radius: blurRadius * 1.4)
                .ignoresSafeArea()
                
                // 中上部：粉青混合过渡区 - 大幅扩大覆盖
                RadialGradient(
                    colors: [
                        resolvedTopLeadingColor.opacity(resolvedOpacity * 0.5),
                        resolvedTopTrailingColor.opacity(resolvedOpacity * 0.35),
                        resolvedTopLeadingColor.opacity(resolvedOpacity * 0.15),
                        Color.clear
                    ],
                    center: .init(x: 0.5, y: 0.35),
                    startRadius: 0,
                    endRadius: geometry.size.width * 1.0
                )
                .blur(radius: blurRadius * 2.0)
                .ignoresSafeArea()
                
                // 顶部中央：额外光晕增加层次感
                RadialGradient(
                    colors: [
                        (
                            colorScheme == .dark && useGlobalDarkPalette
                            ? Color.fixedHex("#101A2B")
                            : Color(hex: "#FFFFFF")
                        ).opacity(colorScheme == .dark ? 0.3 : 0.35),
                        Color.clear
                    ],
                    center: .init(x: 0.5, y: 0.03),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.7
                )
                .blur(radius: blurRadius * 1.3)
                .ignoresSafeArea()
                
                // 左中侧：延伸粉色到中下部
                RadialGradient(
                    colors: [
                        resolvedTopLeadingColor.opacity(resolvedOpacity * 0.3),
                        resolvedTopLeadingColor.opacity(resolvedOpacity * 0.1),
                        Color.clear
                    ],
                    center: .init(x: 0.1, y: 0.55),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.7
                )
                .blur(radius: blurRadius * 2.2)
                .ignoresSafeArea()
                
                // 右中侧：延伸青色到中下部
                RadialGradient(
                    colors: [
                        resolvedTopTrailingColor.opacity(resolvedOpacity * 0.28),
                        resolvedTopTrailingColor.opacity(resolvedOpacity * 0.1),
                        Color.clear
                    ],
                    center: .init(x: 0.9, y: 0.52),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.7
                )
                .blur(radius: blurRadius * 2.2)
                .ignoresSafeArea()
                
                // 底部中央：补充光晕
                RadialGradient(
                    colors: [
                        resolvedTopLeadingColor.opacity(resolvedOpacity * 0.12),
                        resolvedTopTrailingColor.opacity(resolvedOpacity * 0.1),
                        Color.clear
                    ],
                    center: .init(x: 0.5, y: 0.68),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.5
                )
                .blur(radius: blurRadius * 2.5)
                .ignoresSafeArea()

                // 底部暖色弥散：参考 Profile/Fortune 的温柔收尾，不做强对比
                RadialGradient(
                    colors: [
                        resolvedWarmGlowColor.opacity(colorScheme == .dark ? 0.18 : 0.18),
                        resolvedWarmGlowColor.opacity(colorScheme == .dark ? 0.09 : 0.1),
                        Color.clear
                    ],
                    center: .init(x: 0.52, y: 0.9),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.92
                )
                .blur(radius: blurRadius * 1.9)
                .ignoresSafeArea()
                
                // 底部渐变：从彩色过渡到白色，从 72% 位置开始（上四分之三）
                LinearGradient(
                    colors: [
                        resolvedBottomColor.opacity(colorScheme == .dark ? 0.02 : 0.08),
                        resolvedBottomColor.opacity(colorScheme == .dark ? 0.25 : 0.3),
                        resolvedBottomColor.opacity(colorScheme == .dark ? 0.6 : 0.65),
                        resolvedBottomColor.opacity(colorScheme == .dark ? 0.85 : 0.9),
                        resolvedBottomColor
                    ],
                    startPoint: .init(x: 0.5, y: 0.72),
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - 带弥散渐变背景的容器视图
struct DiffuseGradientContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content
    
    // 背景配置
    var topLeadingColor: Color = Color(hex: "#FFB6C1")
    var topTrailingColor: Color = Color(hex: "#B0E0E6")
    var bottomColor: Color = AppTheme.Colors.pageBackground
    var warmGlowColor: Color? = nil
    var useGlobalDarkPalette: Bool = true
    var blurRadius: CGFloat = 80
    var gradientRadius: CGFloat = 600
    var colorOpacity: Double = 0.5
    
    var body: some View {
        ZStack {
            // 背景层
            DiffuseGradientBackground(
                topLeadingColor: topLeadingColor,
                topTrailingColor: topTrailingColor,
                bottomColor: bottomColor,
                warmGlowColor: warmGlowColor,
                useGlobalDarkPalette: useGlobalDarkPalette,
                blurRadius: blurRadius,
                gradientRadius: gradientRadius,
                colorOpacity: colorOpacity
            )
            
            // 内容层
            content()
        }
    }
}

// MARK: - 视图扩展，方便使用
extension View {
    /// 添加弥散渐变背景
    func diffuseGradientBackground(
        topLeadingColor: Color = Color(hex: "#FFB6C1"),
        topTrailingColor: Color = Color(hex: "#B0E0E6"),
        bottomColor: Color = AppTheme.Colors.pageBackground,
        warmGlowColor: Color? = nil,
        useGlobalDarkPalette: Bool = true,
        blurRadius: CGFloat = 80,
        gradientRadius: CGFloat = 600,
        colorOpacity: Double = 0.5
    ) -> some View {
        ZStack {
            DiffuseGradientBackground(
                topLeadingColor: topLeadingColor,
                topTrailingColor: topTrailingColor,
                bottomColor: bottomColor,
                warmGlowColor: warmGlowColor,
                useGlobalDarkPalette: useGlobalDarkPalette,
                blurRadius: blurRadius,
                gradientRadius: gradientRadius,
                colorOpacity: colorOpacity
            )
            
            self
        }
    }
}

// MARK: - 预览
#Preview {
    DiffuseGradientContainer {
        VStack {
            Text("弥散渐变背景")
                .font(.largeTitle)
                .padding()
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#FFFFFF"))
                .frame(height: 200)
                .padding()
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            Spacer()
        }
    }
}
