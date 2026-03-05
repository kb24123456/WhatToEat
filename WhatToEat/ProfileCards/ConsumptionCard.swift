//
//  ConsumptionCard.swift
//  WhatToEat
//
//  消费洞察卡片 - 集成级联动画系统
//

import SwiftUI
import Charts

// MARK: - Consumption Card Preview
struct ConsumptionCardPreview: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text("消费洞察")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
                .tracking(0.5)
            
            // 本月消费
            VStack(alignment: .leading, spacing: 4) {
                Text("本月消费")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Text(viewModel.formatCurrency(viewModel.totalExpense))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            Spacer(minLength: 0)
            
            // 迷你趋势图
            ConsumptionMiniChart(viewModel: viewModel)
                .frame(height: 36)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Consumption Card Detail with Staggered Animation
struct ConsumptionCardDetail: View {
    let viewModel: ProfileViewModel
    
    @State private var localController = CardAnimationController()
    @State private var showChart = false
    
    var body: some View {
        VStack(spacing: 24) {
            // 总消费展示
            VStack(spacing: 8) {
                Text("累计消费")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                AnimatedNumberText(
                    value: Int(viewModel.totalExpense),
                    font: .system(size: 48, weight: .bold, design: .rounded),
                    color: AppTheme.Colors.darkText
                )
            }
            .padding(.top, 20)
            .staggeredAnimation(index: 0, controller: localController)
            
            // 6个月趋势图
            VStack(alignment: .leading, spacing: 12) {
                Text("近6个月消费趋势")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                ConsumptionTrendChart(viewModel: viewModel)
                    .frame(height: 150)
                    .opacity(showChart ? 1 : 0)
                    .scaleEffect(showChart ? 1 : 0.9, anchor: .center)
            }
            .padding(.horizontal, 20)
            .staggeredAnimation(index: 1, controller: localController)
            
            // 消费统计摘要
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(viewModel.formatCurrency(viewModel.totalExpense / max(1, Double(viewModel.totalCheckIns))))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                    Text("平均单次")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
                .staggeredAnimation(index: 2, controller: localController)
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text(viewModel.formatCurrency(viewModel.totalExpense))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                    Text("累计消费")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
                .staggeredAnimation(index: 3, controller: localController)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            localController.beginExpansion()
            
            // 延迟显示图表动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showChart = true
                }
            }
        }
    }
}

// MARK: - Mini Chart (Preview) - 条形图
private struct ConsumptionMiniChart: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        let data = viewModel.getMonthlyExpenses()
        
        Chart(data, id: \.month) { item in
            BarMark(
                x: .value("月份", item.month),
                y: .value("金额", item.amount)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [AppTheme.Colors.coralRed, AppTheme.Colors.coralRed.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(4)
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
    }
}

// MARK: - Trend Chart (Detail)
private struct ConsumptionTrendChart: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        let data = viewModel.getMonthlyExpenses()
        
        Chart(data, id: \.month) { item in
            LineMark(
                x: .value("月份", item.month),
                y: .value("金额", item.amount)
            )
            .foregroundStyle(AppTheme.Colors.coralRed)
            .lineStyle(StrokeStyle(lineWidth: 3))
            
            AreaMark(
                x: .value("月份", item.month),
                y: .value("金额", item.amount)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.coralRed.opacity(0.15),
                        AppTheme.Colors.coralRed.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            PointMark(
                x: .value("月份", item.month),
                y: .value("金额", item.amount)
            )
            .foregroundStyle(AppTheme.Colors.coralRed)
            .symbol {
                Circle()
                    .stroke(AppTheme.Colors.coralRed, lineWidth: 2)
                    .background(Circle().fill(Color(hex: "#FFFFFF")))
                    .frame(width: 8, height: 8)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let stringValue = value.as(String.self) {
                        Text(stringValue)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.lightText)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let viewModel = ProfileViewModel()
    
    return ScrollView {
        VStack(spacing: 20) {
            ConsumptionCardPreview(viewModel: viewModel)
                .background(Color(hex: "#FFFFFF"))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 24)
            
            ConsumptionCardDetail(viewModel: viewModel)
                .frame(height: 500)
        }
    }
    .background(Color.gray.opacity(0.1))
}
