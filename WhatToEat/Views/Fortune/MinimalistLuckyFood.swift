//
//  MinimalistLuckyFood.swift
//  WhatToEat
//
//  极简INS风开运食物组件 - 轻量化左右布局
//

import SwiftUI

// MARK: - 极简开运食物
struct MinimalistLuckyFood: View {
    let food: String
    let showContent: Bool
    @State private var show: Bool = false
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧：梦幻星星图标
            ZStack {
                // 外发光效果
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                MinimalistTheme.Colors.accentPink.opacity(0.3),
                                MinimalistTheme.Colors.accentPink.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .frame(width: 40, height: 40)
                    .opacity(glowOpacity)
                
                // 星星图标
                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(MinimalistTheme.Colors.accentPink)
            }
            
            // 右侧：标签和食物名称
            VStack(alignment: .leading, spacing: 2) {
                Text("开运食物")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MinimalistTheme.Colors.textTertiary)
                
                Text(food)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(MinimalistTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .opacity(show ? 1 : 0)
        .offset(y: show ? 0 : 15)
        .onChange(of: showContent) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(MinimalistTheme.Animations.spring) {
                        show = true
                    }
                }
                // 启动发光动画
                startGlowAnimation()
            }
        }
    }
    
    // 发光动画
    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowOpacity = 1
        }
    }
}

#Preview {
    MinimalistLuckyFood(food: "肯德基吮指原味鸡", showContent: true)
        .padding()
}
