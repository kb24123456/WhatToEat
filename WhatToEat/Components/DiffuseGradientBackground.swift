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

    // 可自定义的颜色配置 - 参考剪映风格
    var topLeadingColor: Color = Color(hex: "#FFE4EC")  // 淡粉色 - 头部左侧
    var topTrailingColor: Color = Color(hex: "#E0F7FA") // 淡青色 - 头部右侧
    var middleAccentColor: Color = Color(hex: "#FFF8E7") // 淡米黄色 - 过渡
    var bottomColor: Color = Color.white                 // 纯白色底色
    
    // 模糊半径
    var blurRadius: CGFloat = 60
    
    // 颜色透明度 - 更淡更柔和
    var colorOpacity: Double = 0.45

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 底层：纯白色底色
                Color.white
                    .ignoresSafeArea()
                
                // 只在头部区域（上半部分）显示弥散色彩
                
                // 左上角：淡粉色光晕
                RadialGradient(
                    colors: [
                        topLeadingColor.opacity(colorOpacity),
                        topLeadingColor.opacity(colorOpacity * 0.6),
                        topLeadingColor.opacity(colorOpacity * 0.2),
                        Color.clear
                    ],
                    center: .init(x: 0.15, y: 0.08),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.7
                )
                .blur(radius: blurRadius)
                .frame(height: geometry.size.height * 0.35)
                .ignoresSafeArea()
                
                // 右上角：淡青色光晕
                RadialGradient(
                    colors: [
                        topTrailingColor.opacity(colorOpacity),
                        topTrailingColor.opacity(colorOpacity * 0.6),
                        topTrailingColor.opacity(colorOpacity * 0.2),
                        Color.clear
                    ],
                    center: .init(x: 0.85, y: 0.08),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.6
                )
                .blur(radius: blurRadius * 1.2)
                .frame(height: geometry.size.height * 0.35)
                .ignoresSafeArea()
                
                // 顶部中间：粉青混合过渡
                RadialGradient(
                    colors: [
                        topLeadingColor.opacity(colorOpacity * 0.5),
                        topTrailingColor.opacity(colorOpacity * 0.5),
                        Color.clear
                    ],
                    center: .init(x: 0.5, y: 0.12),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.5
                )
                .blur(radius: blurRadius * 1.5)
                .frame(height: geometry.size.height * 0.3)
                .ignoresSafeArea()
                
                // 顶部线性渐变：柔和的粉-白-青丝带
                LinearGradient(
                    colors: [
                        topLeadingColor.opacity(0.25),
                        Color.white.opacity(0.1),
                        topTrailingColor.opacity(0.25),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .topTrailing
                )
                .frame(height: geometry.size.height * 0.25)
                .blur(radius: blurRadius * 0.5)
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - 带弥散渐变背景的容器视图
struct DiffuseGradientContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content
    
    // 背景配置
    var topLeadingColor: Color = Color(hex: "#FFE4EC")
    var topTrailingColor: Color = Color(hex: "#E0F7FA")
    var middleAccentColor: Color = Color(hex: "#FFF8E7")
    var bottomColor: Color = Color.white
    var blurRadius: CGFloat = 60
    var colorOpacity: Double = 0.45
    
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
        topLeadingColor: Color = Color(hex: "#FFE4EC"),
        topTrailingColor: Color = Color(hex: "#E0F7FA"),
        middleAccentColor: Color = Color(hex: "#FFF8E7"),
        bottomColor: Color = Color.white,
        blurRadius: CGFloat = 60,
        colorOpacity: Double = 0.45
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
