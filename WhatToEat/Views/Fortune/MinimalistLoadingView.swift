//
//  MinimalistLoadingView.swift
//  WhatToEat
//
//  极简INS风加载视图
//

import SwiftUI

// MARK: - 极简加载视图
struct MinimalistLoadingView: View {
    var cardWidth: CGFloat = 340
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // 简约旋转指示器
            ZStack {
                Circle()
                    .stroke(MinimalistTheme.Colors.textTertiary.opacity(0.2), lineWidth: 1)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(MinimalistTheme.Colors.accentPink, lineWidth: 1.5)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            
            Text("正在翻阅今日黄历...")
                .font(MinimalistTheme.Typography.body)
                .foregroundColor(MinimalistTheme.Colors.textSecondary)
        }
        .frame(width: cardWidth, height: 480)
        .minimalistCardStyle()
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ZStack {
        MinimalistTheme.Colors.backgroundStart
            .ignoresSafeArea()
        MinimalistLoadingView()
    }
}
