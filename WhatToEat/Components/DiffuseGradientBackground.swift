//
//  DiffuseGradientBackground.swift
//  WhatToEat
//
//  弥散渐变背景组件 - 参考剪映设计风格
//  色彩主要分布在头部，底色为白色，主色调白色
//

import SwiftUI

// MARK: - 弥散渐变背景
struct DiffuseGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    // 可自定义颜色，默认值已对深浅模式做适配
    var topLeadingColor: Color = Color.adaptiveHex(light: "#FFE4EC", dark: "#22324A")
    var topTrailingColor: Color = Color.adaptiveHex(light: "#E0F7FA", dark: "#1D3A43")
    var middleAccentColor: Color = Color.adaptiveHex(light: "#FFF8E7", dark: "#2A2840")
    var bottomColor: Color = Color.adaptiveHex(light: "#FFFFFF", dark: "#0A111A")

    var blurRadius: CGFloat = 72
    var colorOpacity: Double = 0.5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if colorScheme == .dark {
                    darkBackground(geometry: geometry)
                } else {
                    lightBackground(geometry: geometry)
                }
            }
        }
    }

    private func lightBackground(geometry: GeometryProxy) -> some View {
        ZStack {
            bottomColor.ignoresSafeArea()

            RadialGradient(
                colors: [
                    topLeadingColor.opacity(colorOpacity),
                    topLeadingColor.opacity(colorOpacity * 0.62),
                    topLeadingColor.opacity(colorOpacity * 0.2),
                    .clear
                ],
                center: .init(x: 0.15, y: 0.08),
                startRadius: 0,
                endRadius: geometry.size.width * 0.74
            )
            .blur(radius: blurRadius)
            .frame(height: geometry.size.height * 0.42)
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    topTrailingColor.opacity(colorOpacity),
                    topTrailingColor.opacity(colorOpacity * 0.62),
                    topTrailingColor.opacity(colorOpacity * 0.2),
                    .clear
                ],
                center: .init(x: 0.87, y: 0.09),
                startRadius: 0,
                endRadius: geometry.size.width * 0.72
            )
            .blur(radius: blurRadius * 1.2)
            .frame(height: geometry.size.height * 0.42)
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    middleAccentColor.opacity(colorOpacity * 0.42),
                    .clear
                ],
                center: .init(x: 0.52, y: 0.54),
                startRadius: 0,
                endRadius: geometry.size.width * 1.1
            )
            .blur(radius: blurRadius * 1.45)
            .ignoresSafeArea()
        }
    }

    private func darkBackground(geometry: GeometryProxy) -> some View {
        let glowStrength = max(0.2, min(0.55, colorOpacity))

        return ZStack {
            LinearGradient(
                colors: [
                    Color.fixedHex("#090E17"),
                    bottomColor.opacity(0.96),
                    Color.fixedHex("#0B121D")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    topLeadingColor.opacity(glowStrength * 0.84),
                    topLeadingColor.opacity(glowStrength * 0.42),
                    .clear
                ],
                center: .init(x: 0.1, y: 0.04),
                startRadius: 0,
                endRadius: geometry.size.width * 0.96
            )
            .blur(radius: blurRadius * 1.5)
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    topTrailingColor.opacity(glowStrength * 0.8),
                    topTrailingColor.opacity(glowStrength * 0.4),
                    .clear
                ],
                center: .init(x: 0.88, y: 0.08),
                startRadius: 0,
                endRadius: geometry.size.width * 0.9
            )
            .blur(radius: blurRadius * 1.72)
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    middleAccentColor.opacity(glowStrength * 0.42),
                    middleAccentColor.opacity(glowStrength * 0.2),
                    .clear
                ],
                center: .init(x: 0.5, y: 0.56),
                startRadius: 0,
                endRadius: geometry.size.width * 1.34
            )
            .blur(radius: blurRadius * 2.0)
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.1),
                    .clear,
                    Color.black.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - 带弥散渐变背景的容器视图
struct DiffuseGradientContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content
    
    // 背景配置
    var topLeadingColor: Color = Color.adaptiveHex(light: "#FFE4EC", dark: "#22324A")
    var topTrailingColor: Color = Color.adaptiveHex(light: "#E0F7FA", dark: "#1D3A43")
    var middleAccentColor: Color = Color.adaptiveHex(light: "#FFF8E7", dark: "#2A2840")
    var bottomColor: Color = Color.adaptiveHex(light: "#FFFFFF", dark: "#0A111A")
    var blurRadius: CGFloat = 72
    var colorOpacity: Double = 0.5
    
    var body: some View {
        ZStack {
            // 背景层
            DiffuseGradientBackground(
                topLeadingColor: topLeadingColor,
                topTrailingColor: topTrailingColor,
                middleAccentColor: middleAccentColor,
                bottomColor: bottomColor,
                blurRadius: blurRadius,
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
        topLeadingColor: Color = Color.adaptiveHex(light: "#FFE4EC", dark: "#22324A"),
        topTrailingColor: Color = Color.adaptiveHex(light: "#E0F7FA", dark: "#1D3A43"),
        middleAccentColor: Color = Color.adaptiveHex(light: "#FFF8E7", dark: "#2A2840"),
        bottomColor: Color = Color.adaptiveHex(light: "#FFFFFF", dark: "#0A111A"),
        blurRadius: CGFloat = 72,
        colorOpacity: Double = 0.5
    ) -> some View {
        ZStack {
            DiffuseGradientBackground(
                topLeadingColor: topLeadingColor,
                topTrailingColor: topTrailingColor,
                middleAccentColor: middleAccentColor,
                bottomColor: bottomColor,
                blurRadius: blurRadius,
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
                .fill(Color.white)
                .frame(height: 200)
                .padding()
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            Spacer()
        }
    }
}
