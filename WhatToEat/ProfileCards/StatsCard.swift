//
//  StatsCard.swift
//  WhatToEat
//
//  统计概览卡片 - 集成级联动画系统
//

import SwiftUI

// MARK: - Stats Card Preview
struct StatsCardPreview: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text("数据概览")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
                .tracking(0.5)
            
            // 核心数据：总打卡数
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(viewModel.totalCheckIns)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text("次打卡")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
            
            Spacer(minLength: 0)
            
            // 次要数据
            HStack(spacing: 12) {
                Label("\(viewModel.totalRestaurants)", systemImage: "fork.knife")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Label(viewModel.formatCurrency(viewModel.totalExpense), systemImage: "creditcard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Stats Card Detail with Staggered Animation
struct StatsCardDetail: View {
    let viewModel: ProfileViewModel
    
    @State private var localController = CardAnimationController()
    
    var body: some View {
        VStack(spacing: 24) {
            // 总打卡数大字展示 - 使用与累积消费同款的 AnimatedNumberText 动画
            VStack(spacing: 8) {
                Text("累计打卡次数")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                AnimatedNumberText(
                    value: viewModel.totalCheckIns,
                    font: .system(size: 48, weight: .bold, design: .rounded),
                    color: AppTheme.Colors.coralRed
                )
            }
            .padding(.top, 20)
            .staggeredAnimation(index: 0, controller: localController)
            
            // 详细数据网格 - 级联入场
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatDetailItem(
                    icon: "fork.knife",
                    value: viewModel.totalRestaurants,
                    label: "餐厅总数",
                    color: AppTheme.Colors.darkText
                )
                .staggeredAnimation(index: 1, controller: localController)
                
                StatDetailItem(
                    icon: "creditcard",
                    value: Int(viewModel.totalExpense),
                    label: "总支出",
                    color: AppTheme.Colors.darkText
                )
                .staggeredAnimation(index: 2, controller: localController)
                
                StatDetailItem(
                    icon: "mappin.and.ellipse",
                    value: viewModel.uniqueCities,
                    label: "探索城市",
                    color: AppTheme.Colors.darkText
                )
                .staggeredAnimation(index: 3, controller: localController)
                
                StatDetailItem(
                    icon: "calendar",
                    value: viewModel.joinDays,
                    label: "使用天数",
                    color: AppTheme.Colors.darkText
                )
                .staggeredAnimation(index: 4, controller: localController)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            localController.beginExpansion()
        }
    }
}

// MARK: - Stat Detail Item
private struct StatDetailItem: View {
    let icon: String
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.mediumGray)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.softBackground.opacity(0.5))
        )
    }
}

// MARK: - Preview
#Preview {
    let viewModel = ProfileViewModel()
    viewModel.restaurants = []
    
    return ScrollView {
        VStack(spacing: 20) {
            StatsCardPreview(viewModel: viewModel)
                .background(Color(hex: "#FFFFFF"))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 24)
            
            StatsCardDetail(viewModel: viewModel)
                .frame(height: 500)
        }
    }
    .background(Color.gray.opacity(0.1))
}
