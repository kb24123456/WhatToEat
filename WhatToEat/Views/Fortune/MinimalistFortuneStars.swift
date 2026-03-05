//
//  MinimalistFortuneStars.swift
//  WhatToEat
//
//  极简INS风运势星级组件
//

import SwiftUI

// MARK: - 极简运势星级
struct MinimalistFortuneStars: View {
    let stars: Int
    let showContent: Bool
    @State private var animatedStars: Int = 0
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { index in
                MinimalistStar(
                    isFilled: index < animatedStars,
                    delay: Double(index) * 0.08
                )
            }
        }
        .onChange(of: showContent) { _, newValue in
            if newValue {
                animateStars()
            }
        }
    }
    
    private func animateStars() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(MinimalistTheme.Animations.spring) {
                animatedStars = stars
            }
        }
    }
}

// MARK: - 极简星星
struct MinimalistStar: View {
    let isFilled: Bool
    let delay: Double
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        Image(systemName: isFilled ? "star.fill" : "star")
            .font(.system(size: 20, weight: .thin))
            .foregroundColor(isFilled ? MinimalistTheme.Colors.accentPink : MinimalistTheme.Colors.textTertiary)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(MinimalistTheme.Animations.spring) {
                        scale = 1.0
                        opacity = 1.0
                    }
                }
            }
    }
}

#Preview {
    MinimalistFortuneStars(stars: 4, showContent: true)
        .padding()
}
