//
//  CheckInHistoryView.swift
//  WhatToEat
//
//  打卡记录时间线视图 - 按时间收集所有打卡记录
//

import SwiftUI
import SwiftData

// MARK: - 日期格式化扩展
extension Date {
    /// 带年份的日期时间格式：yyyy年M月d日 HH:mm
    var formattedWithYear: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: self)
    }
}

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
        .cardStyle()
    }
    
    // MARK: - Check In Log Card (优化版)
    private func checkInLogCard(item: LogItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部：餐厅封面 + 名称 + 心情
            HStack(spacing: 12) {
                // 餐厅封面缩略图
                restaurantThumbnail(item: item)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    // 餐厅名称
                    Text(item.restaurantName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .lineLimit(1)
                    
                    // 日期（带年份）+ 心情
                    HStack(spacing: 6) {
                        Text(item.log.date.formattedWithYear)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                        
                        if let mood = item.log.mood, let moodType = MoodType.allCases.first(where: { $0.rawValue == mood }) {
                            Text(moodType.rawValue)
                                .font(.system(size: 14))
                            Text(moodType.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.darkText)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.bottom, 16)
            
            // 消费信息行（文本标签 + 统一黑色字体）
            HStack(spacing: 0) {
                // 消费
                VStack(alignment: .leading, spacing: 2) {
                    Text("消费")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                    Text("¥\(Int(item.log.expense))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 人数
                VStack(alignment: .leading, spacing: 2) {
                    Text("人数")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                    Text("\(item.log.peopleCount)人")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 人均
                VStack(alignment: .leading, spacing: 2) {
                    Text("人均")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                    Text("¥\(Int(item.log.peopleCount > 0 ? item.log.expense / Double(item.log.peopleCount) : 0))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 12)
            
            // 菜品标签（优化样式）
            if !item.log.goodDishes.isEmpty || !item.log.badDishes.isEmpty {
                HStack(spacing: 12) {
                    if !item.log.goodDishes.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            
                            Text(item.log.goodDishes)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.accent)
                        )
                    }
                    
                    if !item.log.badDishes.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                            
                            Text(item.log.badDishes)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.darkText)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.softBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(AppTheme.Colors.lightGray, lineWidth: 0.5)
                                )
                        )
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
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
    
    // MARK: - 餐厅封面缩略图
    private func restaurantThumbnail(item: LogItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.lightGray)
            
            // 尝试加载餐厅封面
            if let coverFilename = item.restaurant.coverPhotoFilename {
                AsyncImageView(
                    filename: coverFilename,
                    placeholder: AnyView(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.lighterGray)
                    )
                )
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipped()
            } else {
                // 默认图标
                Image(systemName: "fork.knife")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.lighterGray)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
        )
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
