//
//  MinimalistYiJiRow.swift
//  WhatToEat
//
//  极简INS风宜忌行组件
//

import SwiftUI

// MARK: - 极简宜忌行
struct MinimalistYiJiRow: View {
    let type: YiJiType
    let highlight: String
    let detail: String
    let delay: Double
    @State private var show: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标 - 红色勾勾、绿色叉叉（特殊设计）
            Image(systemName: type == .yi ? "checkmark" : "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(type == .yi ? MinimalistTheme.Colors.jiColor : MinimalistTheme.Colors.yiColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(highlight)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(MinimalistTheme.Colors.textPrimary)
                
                Text(detail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(MinimalistTheme.Colors.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .minimalistInnerCardStyle()
        .opacity(show ? 1 : 0)
        .offset(x: show ? 0 : -20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(MinimalistTheme.Animations.spring) {
                    show = true
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        MinimalistYiJiRow(type: .yi, highlight: "吃红烧肉", detail: "补充能量，心情愉悦", delay: 0)
        MinimalistYiJiRow(type: .ji, highlight: "吃生冷食物", detail: "容易肠胃不适", delay: 0.1)
    }
    .padding()
}
