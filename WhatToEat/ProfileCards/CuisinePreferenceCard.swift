//
//  CuisinePreferenceCard.swift
//  WhatToEat
//
//  餐饮偏好卡片 - 集成级联动画系统
//

import SwiftUI

// MARK: - Cuisine Preference Card Preview
struct CuisinePreferenceCardPreview: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        let data = viewModel.getCuisineTypeDistribution()

        VStack(alignment: .leading, spacing: 10) {
            PreviewCardTitle(title: "餐饮偏好")

            if data.first != nil {
                CuisineMiniRingChart(data: data)
                    .frame(width: 92, height: 92)
            } else {
                ZStack {
                    Circle()
                        .stroke(AppTheme.Colors.softBackground, lineWidth: 10)

                    Text("暂无\n偏好")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 92, height: 92)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Mini Ring Chart
private struct CuisineMiniRingChart: View {
    let data: [(type: String, count: Int, percent: Double, color: Color)]

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Colors.softBackground, lineWidth: 10)

            ForEach(Array(data.prefix(3).enumerated()), id: \.offset) { index, item in
                Circle()
                    .trim(from: getStartAngle(for: index), to: getEndAngle(for: index))
                    .stroke(
                        item.color,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            if let topType = data.first {
                VStack(spacing: 2) {
                    Text(topType.type)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(Int(topType.percent * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            }
        }
    }

    private func getStartAngle(for index: Int) -> CGFloat {
        let previousPercentages = data.prefix(index).map { $0.percent }
        return previousPercentages.reduce(0, +)
    }

    private func getEndAngle(for index: Int) -> CGFloat {
        getStartAngle(for: index) + data[index].percent
    }
}

// MARK: - Cuisine Preference Card Detail with Staggered Animation
struct CuisinePreferenceCardDetail: View {
    let viewModel: ProfileViewModel
    
    @State private var localController = CardAnimationController()
    
    var body: some View {
        VStack(spacing: 24) {
            // 标题
            Text("餐饮偏好分布")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.top, 20)
                .staggeredAnimation(index: 0, controller: localController)
            
            // 圆形进度指示器 + 品类列表
            let data = viewModel.getCuisineTypeDistribution()
            
            HStack(spacing: 24) {
                // 圆形图表
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(AppTheme.Colors.softBackground, lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    // 数据圆环 - 使用多色分段
                    ForEach(Array(data.prefix(4).enumerated()), id: \.offset) { index, item in
                        Circle()
                            .trim(from: getStartAngle(for: index, in: data), to: getEndAngle(for: index, in: data))
                            .stroke(
                                item.color,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    // 中心文字
                    if let topType = data.first {
                        VStack(spacing: 2) {
                            Text("\(Int(topType.percent * 100))%")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Colors.darkText)
                                .contentTransition(.numericText())
                            Text(topType.type)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                        }
                    }
                }
                .staggeredAnimation(index: 1, controller: localController)
                
                // 品类列表
                VStack(spacing: 12) {
                    ForEach(Array(data.prefix(5).enumerated()), id: \.element.type) { index, item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            
                            Text(item.type)
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.darkText)
                                .frame(width: 60, alignment: .leading)
                            
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(item.color.opacity(0.3))
                                    .frame(height: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(item.color)
                                            .frame(width: geo.size.width * item.percent, height: 4)
                                        , alignment: .leading
                                    )
                            }
                            .frame(height: 4)
                            
                            Text("\(Int(item.percent * 100))%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                                .frame(width: 36, alignment: .trailing)
                                .contentTransition(.numericText())
                        }
                        .staggeredAnimation(index: 2 + index, controller: localController)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            
            // 统计摘要
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(data.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .contentTransition(.numericText())
                    Text("尝试品类")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    if let topType = data.first {
                        Text(topType.type)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                    }
                    Text("最爱品类")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            }
            .padding(.horizontal, 20)
            .staggeredAnimation(index: 7, controller: localController)
        }
        .onAppear {
            localController.beginExpansion()
        }
    }
}

// MARK: - Helper Functions for Detail View
private func getStartAngle(for index: Int, in data: [(type: String, count: Int, percent: Double, color: Color)]) -> CGFloat {
    let previousPercentages = data.prefix(index).map { $0.percent }
    return previousPercentages.reduce(0, +)
}

private func getEndAngle(for index: Int, in data: [(type: String, count: Int, percent: Double, color: Color)]) -> CGFloat {
    return getStartAngle(for: index, in: data) + data[index].percent
}

// MARK: - Preview
#Preview {
    let viewModel = ProfileViewModel()
    
    return ScrollView {
        VStack(spacing: 20) {
            CuisinePreferenceCardPreview(viewModel: viewModel)
                .background(Color(hex: "#FFFFFF"))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 24)
            
            CuisinePreferenceCardDetail(viewModel: viewModel)
                .frame(height: 400)
        }
    }
    .background(Color.gray.opacity(0.1))
}
