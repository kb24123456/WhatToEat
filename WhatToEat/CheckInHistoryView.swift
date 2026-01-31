//
//  CheckInHistoryView.swift
//  WhatToEat
//
//  打卡记录时间线视图 - 按时间收集所有打卡记录
//

import SwiftUI
import SwiftData

// MARK: - 打卡记录视图
struct CheckInHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 可选：如果传入 restaurant，则只显示该餐厅的打卡记录
    var restaurant: Restaurant?
    
    @Query(sort: \Restaurant.createdAt, order: .reverse) private var allRestaurants: [Restaurant]
    
    @State private var showSheet = false
    @State private var logToEdit: VisitLog? = nil
    @State private var selectedRestaurant: Restaurant? = nil
    
    // 动画状态
    @State private var isAnimated = false
    
    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 顶部标题栏
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                        .padding(.bottom, 20)
                    
                    // 打卡记录列表
                    checkInListSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            if let restaurant = selectedRestaurant {
                CheckInView(restaurant: restaurant, editingLog: logToEdit, onClose: {
                    showSheet = false
                })
            }
        }
        .onAppear {
            withAnimation(AppTheme.Animations.standardSpring) {
                isAnimated = true
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        MilkyDiffuseBackground()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text(subtitleText)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
            
            Spacer()
            
            // 关闭按钮
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.5))
                    )
            }
        }
    }
    
    // MARK: - Title Text
    private var titleText: String {
        if let restaurant = restaurant {
            return restaurant.name
        }
        return "打卡记录"
    }
    
    // MARK: - Subtitle Text
    private var subtitleText: String {
        let count = allLogs.count
        if restaurant != nil {
            return "共 \(count) 次打卡"
        }
        return "共 \(count) 条美食足迹"
    }
    
    // MARK: - Check In List Section
    private var checkInListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if allLogs.isEmpty {
                emptyStateView
            } else {
                // 按日期分组显示
                ForEach(groupedLogs.keys.sorted(by: >), id: \.self) { dateKey in
                    VStack(alignment: .leading, spacing: 12) {
                        // 日期标题
                        Text(dateKey)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                            .padding(.horizontal, 4)
                        
                        // 该日期的打卡记录
                        VStack(spacing: 12) {
                            ForEach(groupedLogs[dateKey] ?? []) { item in
                                checkInLogCard(item: item)
                                    .offset(y: isAnimated ? 0 : 30)
                                    .opacity(isAnimated ? 1 : 0)
                                    .animation(
                                        AppTheme.Animations.staggeredEntrance(index: logIndex(for: item)),
                                        value: isAnimated
                                    )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.lightText)
            
            Text("暂无打卡记录")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            if restaurant == nil {
                Text("快去添加你的第一家餐厅吧")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.lightText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Check In Log Card (与 RestaurantDetailView 同款)
    private func checkInLogCard(item: LogItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 餐厅名称（仅在全局视图显示）
            if restaurant == nil {
                Text(item.restaurantName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .padding(.bottom, 8)
            }
            
            // 日期行
            Text(item.log.date.chineseDateTime)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            // 指标水平栏
            HStack(spacing: 0) {
                // 人均
                metricCell(
                    title: "人均",
                    value: Int(item.log.peopleCount > 0 ? item.log.expense / Double(item.log.peopleCount) : 0),
                    unit: "¥",
                    valueColor: AppTheme.Colors.accent
                )
                
                // 分隔线
                Divider()
                    .frame(height: 20)
                    .opacity(0.1)
                
                // 总额
                metricCell(
                    title: "总额",
                    value: Int(item.log.expense),
                    unit: "¥"
                )
                
                // 分隔线
                Divider()
                    .frame(height: 20)
                    .opacity(0.1)
                
                // 人数
                metricCell(
                    title: "人数",
                    value: item.log.peopleCount,
                    unit: "人"
                )
            }
            .padding(.top, 12)
            
            // 图片
            if let firstFilename = item.log.photoFilenames.first {
                AsyncImageView(
                    filename: firstFilename,
                    placeholder: AnyView(EmptyView())
                )
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .cornerRadius(16)
                .padding(.top, 12)
            }
            
            // 菜品标签
            if !item.log.goodDishes.isEmpty || !item.log.badDishes.isEmpty {
                HStack(spacing: 16) {
                    if !item.log.goodDishes.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.accent)
                            Text(item.log.goodDishes)
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.darkText)
                        }
                    }
                    if !item.log.badDishes.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.mediumGray)
                            Text(item.log.badDishes)
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.darkText)
                        }
                    }
                }
                .padding(.top, 12)
            }
            
            // 评价
            if !item.log.review.isEmpty {
                Text(item.log.review)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Colors.softBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                            )
                    )
                    .padding(.top, 12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.02), radius: 20, x: 0, y: 10)
        .contextMenu {
            Button {
                logToEdit = item.log
                selectedRestaurant = item.restaurant
                showSheet = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                deleteLog(item: item)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Metric Cell
    private func metricCell(title: String, value: Int, unit: String, valueColor: Color = AppTheme.Colors.darkText) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if unit == "¥" {
                    Text("¥")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
                
                Text("\(value)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(valueColor)
                
                if unit == "人" {
                    Text("人")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Data Processing
    
    // 获取所有打卡记录
    private var allLogs: [LogItem] {
        var logs: [LogItem] = []
        
        let restaurantsToProcess: [Restaurant]
        if let restaurant = restaurant {
            restaurantsToProcess = [restaurant]
        } else {
            restaurantsToProcess = allRestaurants
        }
        
        for restaurant in restaurantsToProcess {
            for log in restaurant.logs {
                logs.append(LogItem(
                    log: log,
                    restaurant: restaurant,
                    restaurantName: restaurant.name
                ))
            }
        }
        
        // 按日期倒序排序
        return logs.sorted(by: { $0.log.date > $1.log.date })
    }
    
    // 按日期分组
    private var groupedLogs: [String: [LogItem]] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        
        var groups: [String: [LogItem]] = [:]
        
        for item in allLogs {
            let key = formatter.string(from: item.log.date)
            if groups[key] == nil {
                groups[key] = []
            }
            groups[key]?.append(item)
        }
        
        return groups
    }
    
    // 计算日志索引用于动画
    private func logIndex(for item: LogItem) -> Int {
        return allLogs.firstIndex(where: { $0.log.id == item.log.id }) ?? 0
    }
    
    // MARK: - Delete Log
    private func deleteLog(item: LogItem) {
        modelContext.delete(item.log)
        item.restaurant.updateAveragePrice()
        try? modelContext.save()
    }
}

// MARK: - Log Item
struct LogItem: Identifiable {
    let id = UUID()
    let log: VisitLog
    let restaurant: Restaurant
    let restaurantName: String
}

// MARK: - Preview
#Preview {
    CheckInHistoryView()
}
