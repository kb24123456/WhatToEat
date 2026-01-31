//
//  AnnualReportOverlay.swift
//  WhatToEat
//
//  年度美食报告全屏覆盖层
//

import SwiftUI
import SwiftData

// MARK: - 年度统计数据结构
struct AnnualStats {
    let year: Int
    let topRestaurant: Restaurant?
    let totalCheckIns: Int
    let totalExpense: Double
    let topCuisine: String
    let totalRestaurants: Int
    let uniqueCities: Int
    
    // 从餐厅数据计算年度统计
    static func calculate(from restaurants: [Restaurant], year: Int) -> AnnualStats {
        let calendar = Calendar.current
        
        // 筛选当年的打卡记录
        let yearLogs = restaurants.flatMap { $0.logs }.filter { log in
            calendar.component(.year, from: log.date) == year
        }
        
        // 计算总打卡次数
        let totalCheckIns = yearLogs.count
        
        // 计算总支出
        let totalExpense = yearLogs.reduce(0) { $0 + $1.expense }
        
        // 找出打卡最多的餐厅
        var restaurantVisitCounts: [UUID: (count: Int, restaurant: Restaurant)] = [:]
        for restaurant in restaurants {
            let yearVisitCount = restaurant.logs.filter { log in
                calendar.component(.year, from: log.date) == year
            }.count
            if yearVisitCount > 0 {
                restaurantVisitCounts[restaurant.id] = (count: yearVisitCount, restaurant: restaurant)
            }
        }
        let topRestaurant = restaurantVisitCounts.values.sorted { $0.count > $1.count }.first?.restaurant
        
        // 找出最多的品类
        var cuisineCounts: [String: Int] = [:]
        for restaurant in restaurants {
            let yearVisitCount = restaurant.logs.filter { log in
                calendar.component(.year, from: log.date) == year
            }.count
            if yearVisitCount > 0 {
                cuisineCounts[restaurant.type, default: 0] += yearVisitCount
            }
        }
        let topCuisine = cuisineCounts.max { $0.value < $1.value }?.key ?? "未知"
        
        // 统计餐厅数量（当年有打卡的）
        let totalRestaurants = restaurantVisitCounts.count
        
        // 统计城市数量
        let uniqueCities = Set(restaurants.filter { restaurant in
            restaurant.logs.contains { log in
                calendar.component(.year, from: log.date) == year
            }
        }.map { $0.city }).count
        
        return AnnualStats(
            year: year,
            topRestaurant: topRestaurant,
            totalCheckIns: totalCheckIns,
            totalExpense: totalExpense,
            topCuisine: topCuisine,
            totalRestaurants: totalRestaurants,
            uniqueCities: uniqueCities
        )
    }
}

// MARK: - 年度报告覆盖层
struct AnnualReportOverlay: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Restaurant.createdAt, order: .reverse) private var restaurants: [Restaurant]
    
    // 3D 旋转效果状态
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    
    // 动画状态
    @State private var isAppeared = false
    
    // 当前年份
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    // 年度统计数据
    private var annualStats: AnnualStats {
        AnnualStats.calculate(from: restaurants, year: currentYear)
    }
    
    var body: some View {
        ZStack {
            // 背景：使用 MilkyDiffuseBackground，动画速度提升2倍
            MilkyDiffuseBackground(animationSpeed: 2.0)
                .ignoresSafeArea()
            
            // 主内容
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // 顶部标题栏
                    headerSection
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                    
                    // 英雄海报区域
                    heroSection
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                    
                    // 统计数据区域
                    statsSection
                        .padding(.top, 48)
                        .padding(.horizontal, 24)
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAppeared = true
            }
        }
    }
    
    // MARK: - 顶部标题栏
    private var headerSection: some View {
        HStack {
            // 左上角：年份/美食印记
            VStack(alignment: .leading, spacing: 4) {
                Text("\(currentYear)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text("美食印记")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
            
            Spacer()
            
            // 右上角：关闭按钮
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            )
                    )
            }
        }
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : -20)
    }
    
    // MARK: - 英雄海报区域
    private var heroSection: some View {
        VStack(spacing: 24) {
            // 英雄卡片：Top 1 餐厅
            if let restaurant = annualStats.topRestaurant {
                heroCard(restaurant: restaurant)
            } else {
                // 无数据时的占位
                emptyHeroCard
            }
            
            // 餐厅名称
            if let restaurant = annualStats.topRestaurant {
                Text(restaurant.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .multilineTextAlignment(.center)
                    .opacity(isAppeared ? 1 : 0)
                    .offset(y: isAppeared ? 0 : 20)
            }
        }
    }
    
    // MARK: - 英雄卡片（带 3D 效果）
    private func heroCard(restaurant: Restaurant) -> some View {
        ZStack(alignment: .bottom) {
            // 餐厅封面图
            Group {
                if let coverFilename = restaurant.coverPhotoFilename,
                   let uiImage = ImageManager.shared.loadImage(filename: coverFilename) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    // 默认占位图
                    ZStack {
                        LinearGradient(
                            colors: [AppTheme.Colors.babyBlue.opacity(0.3), AppTheme.Colors.accent.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            
            // 磨砂遮罩层
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            
            // 底部文字：年度最爱
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    
                    Text("年度最爱")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text("打卡 \(annualStats.topRestaurant?.logs.count ?? 0) 次")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 20)
        }
        .frame(width: 280, height: 280)
        .background(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
        )
        // 3D 旋转效果
        .rotation3DEffect(
            .degrees(rotationX),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(rotationY),
            axis: (x: 0, y: 1, z: 0)
        )
        // 物理厚度感
        .overlay(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .padding(1)
        )
        .opacity(isAppeared ? 1 : 0)
        .scaleEffect(isAppeared ? 1 : 0.8)
        .onAppear {
            // 简单的呼吸动画模拟 3D 效果
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                rotationX = 2
                rotationY = 3
            }
        }
    }
    
    // MARK: - 空数据占位
    private var emptyHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(AppTheme.Colors.softBackground)
            
            VStack(spacing: 16) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppTheme.Colors.lightGray)
                
                Text("还没有打卡记录")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
        }
        .frame(width: 280, height: 280)
        .opacity(isAppeared ? 1 : 0)
    }
    
    // MARK: - 统计数据区域
    private var statsSection: some View {
        VStack(spacing: 20) {
            // 主统计卡片
            HStack(spacing: 0) {
                AnnualStatItem(value: "\(annualStats.totalCheckIns)", label: "总打卡", unit: "次")
                Divider().frame(height: 40)
                AnnualStatItem(value: formatCurrency(annualStats.totalExpense), label: "总支出", unit: "")
                Divider().frame(height: 40)
                AnnualStatItem(value: "\(annualStats.totalRestaurants)", label: "探索餐厅", unit: "家")
            }
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
            )
            
            // 次要统计
            HStack(spacing: 12) {
                SecondaryStatCard(
                    icon: "mappin.and.ellipse",
                    value: "\(annualStats.uniqueCities)",
                    label: "城市足迹"
                )
                
                SecondaryStatCard(
                    icon: "fork.knife",
                    value: annualStats.topCuisine,
                    label: "最爱品类"
                )
            }
        }
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : 30)
    }
    
    // MARK: - 格式化金额
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "¥0"
    }
}

// MARK: - 年度报告统计项组件
struct AnnualStatItem: View {
    let value: String
    let label: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            }
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.mediumGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 次要统计卡片
struct SecondaryStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.babyBlue)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(AppTheme.Colors.babyBlue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
        )
    }
}

// MARK: - 预览
#Preview {
    AnnualReportOverlay()
}
