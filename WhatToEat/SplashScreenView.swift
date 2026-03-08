//
//  SplashScreenView.swift
//  WhatToEat
//
//  Created by Codex on 2026/3/8.
//

import SwiftUI

struct SplashScreenView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPresented = false

    var body: some View {
        ZStack {
            AppTheme.Colors.pageBackground
                .overlay(backgroundGlow)
                .ignoresSafeArea()

            centerMark
        }
        .onAppear {
            if reduceMotion {
                isPresented = true
            } else {
                withAnimation(.easeOut(duration: 0.55)) {
                    isPresented = true
                }
            }
        }
    }

    private var backgroundGlow: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.78))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .offset(x: -88, y: -156)

            Circle()
                .fill(AppTheme.Colors.accent.opacity(0.14))
                .frame(width: 212, height: 212)
                .blur(radius: 46)
                .offset(x: 96, y: 168)

            Circle()
                .fill(AppTheme.Colors.babyBlue.opacity(0.1))
                .frame(width: 180, height: 180)
                .blur(radius: 40)
                .offset(x: 110, y: -124)
        }
    }

    private var centerMark: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: 128, height: 128)
                .blur(radius: 24)

            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                )
                .frame(width: 110, height: 110)
                .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 10)

            Image(systemName: "fork.knife")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.darkText,
                            AppTheme.Colors.textSecondary.opacity(0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolRenderingMode(.hierarchical)
        }
        .scaleEffect(isPresented ? 1 : 0.9)
        .opacity(isPresented ? 1 : 0)
        .offset(y: isPresented ? 0 : 8)
    }
}

#Preview {
    SplashScreenView()
}
