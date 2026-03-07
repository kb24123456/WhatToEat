//
//  PreviewCardElements.swift
//  WhatToEat
//
//  Shared building blocks for compact dashboard preview cards.
//

import SwiftUI

struct PreviewCardTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.Colors.lightText)
            .tracking(0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }
}

struct PreviewChip: View {
    let text: String
    var tint: Color? = nil

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint ?? AppTheme.Colors.mediumGray)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((tint ?? AppTheme.Colors.softBackground).opacity(tint == nil ? 1 : 0.12))
            )
    }
}
