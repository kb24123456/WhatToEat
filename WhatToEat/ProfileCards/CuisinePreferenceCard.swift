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
        VStack(alignment: .leading, spacing: 10) {
            // 标题
            HStack {
                Text("餐饮偏好")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.lightText)
                    .tracking(0.5)
                
                Spacer()
            }
            
            // 圆环图 + 主要偏好
            let data = viewModel.getCuisineTypeDistribution()
            HStack(spacing: 12) {
                // 迷你圆环图
                CuisineMiniRingChart(data: data)
                    .frame(width: 60, height: 60)
                
                // 主要偏好文字
                if let topType = data.first {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(topType.type)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                        
                        Text("最爱吃的品类")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            Spacer(minLength: 0)
            
            // 品类预览
            HStack(spacing: 6) {
                ForEach(data.prefix(3), id: \.type) { item in
                    HStack(spacing: 2) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 6, height: 6)
                        Text(item.type)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.softBackground)
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

// MARK: - Mini Ring Chart
private struct CuisineMiniRingChart: View {
    let data: [(type: String, count: Int, percent: Double, color: Color)]
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(AppTheme.Colors.softBackground, lineWidth: 8)
            
            // 数据圆环 - 多层叠加
            ForEach(Array(data.prefix(3).enumerated()), id: \.offset) { index, item in
                Circle()
                    .trim(from: getStartAngle(for: index), to: getEndAngle(for: index))
                    .stroke(
                        item.color,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            
            // 中心文字
            if let topType = data.first {
                VStack(spacing: 0) {
                    Text("\(Int(topType.percent * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
            }
        }
    }
    
    private func getStartAngle(for index: Int) -> CGFloat {
        let previousPercentages = data.prefix(index).map { $0.percent }
        return previousPercentages.reduce(0, +)
    }
    
    private func getEndAngle(for index: Int) -> CGFloat {
        return getStartAngle(for: index) + data[index].percent
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
