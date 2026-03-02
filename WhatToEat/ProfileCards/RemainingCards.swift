//
//  RemainingCards.swift
//  WhatToEat
//
//  包含 RestaurantsCard、TimelineCard、ZodiacCard - 集成级联动画系统
//

import SwiftUI

// MARK: - Restaurants Card
struct RestaurantsCardPreview: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常去餐厅")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
                .tracking(0.5)
            
            let topRestaurants = viewModel.getTopRestaurants(limit: 1)
            if let top = topRestaurants.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(top.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .lineLimit(1)

                    Text("\(top.logs.count)次打卡")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            } else {
                Text("暂无数据")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }

            Spacer(minLength: 0)

            // TOP3 预览
            HStack(spacing: 8) {
                ForEach(0..<min(3, viewModel.getTopRestaurants(limit: 3).count), id: \.self) { index in
                    Circle()
                        .fill(AppTheme.Colors.coralRed.opacity(0.1))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.Colors.darkText)
                        )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Restaurants Card Detail with Staggered Animation (单列显示前五，删除标题)
struct RestaurantsCardDetail: View {
    let viewModel: ProfileViewModel
    
    @State private var localController = CardAnimationController()
    
    var body: some View {
        VStack(spacing: 16) {
            // 删除标题行，直接显示餐厅列表
            let topRestaurants = viewModel.getTopRestaurants(limit: 5)
            VStack(spacing: 12) {
                ForEach(Array(topRestaurants.enumerated()), id: \.element.id) { index, restaurant in
                    RestaurantListItem(restaurant: restaurant, rank: index + 1)
                        .staggeredAnimation(index: index, controller: localController)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer(minLength: 0)
        }
        .onAppear {
            localController.beginExpansion()
        }
    }
}

// MARK: - 单列餐厅列表项
private struct RestaurantListItem: View {
    let restaurant: Restaurant
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // 排名
            ZStack {
                Circle()
                    .fill(rank <= 3 ? AppTheme.Colors.coralRed : AppTheme.Colors.softBackground)
                    .frame(width: 28, height: 28)
                
                Text("\(rank)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(rank <= 3 ? .white : AppTheme.Colors.darkText)
            }
            
            // 餐厅图片
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.Colors.softBackground)
                    .frame(width: 56, height: 56)
                
                if let imageName = restaurant.coverPhotoFilename,
                   let uiImage = ImageManager.shared.loadImage(filename: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
            }
            
            // 餐厅信息
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(restaurant.logs.count)次打卡")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                    
                    if let lastVisit = restaurant.logs.sorted(by: { $0.date > $1.date }).first {
                        Text("· 最近\(lastVisit.date.chineseDateOnly)")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.lightText)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.softBackground.opacity(0.5))
        )
    }
}

// MARK: - Timeline Card
struct TimelineCardPreview: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("美食足迹")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
                .tracking(0.5)
            
            let recentLogs = viewModel.getRecentLogsWithRestaurant(limit: 1)
            if let latest = recentLogs.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(latest.restaurantName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .lineLimit(1)

                    Text(latest.log.date.chineseDateOnly)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            } else {
                Text("暂无记录")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }

            Spacer(minLength: 0)

            // 最近3天指示
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(i == 0 ? AppTheme.Colors.xhsRed : AppTheme.Colors.softBackground)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Timeline Card Detail with Staggered Animation
struct TimelineCardDetail: View {
    @Bindable var viewModel: ProfileViewModel
    
    @State private var localController = CardAnimationController()
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("最近打卡记录")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .staggeredAnimation(index: 0, controller: localController)
                
                Spacer()
                
                Button {
                    viewModel.showCheckInHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Text("查看全部")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(AppTheme.Colors.mediumGray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.softBackground)
                    )
                }
                .staggeredAnimation(index: 1, controller: localController)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            let recentLogs = viewModel.getRecentLogsWithRestaurant(limit: 5)
            VStack(spacing: 10) {
                ForEach(Array(recentLogs.enumerated()), id: \.offset) { index, item in
                    TimelineDetailItem(item: item, isFirst: index == 0)
                        .staggeredAnimation(index: 2 + index, controller: localController)
                }
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $viewModel.showCheckInHistory) {
            CheckInHistoryView()
                .presentationBackground(AppTheme.Colors.milkWhite)
        }
        .onAppear {
            localController.beginExpansion()
        }
    }
}

private struct TimelineDetailItem: View {
    let item: (log: VisitLog, restaurantName: String)
    let isFirst: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.log.date.chineseDateOnly)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                if let mood = item.log.mood,
                   let moodType = MoodType.allCases.first(where: { $0.rawValue == mood }) {
                    Text(moodType.rawValue)
                        .font(.system(size: 14))
                }
                
                Spacer()
                
                if Calendar.current.isDateInToday(item.log.date) {
                    Text("今日")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.accent.opacity(0.1))
                        )
                }
            }
            
            HStack {
                Text(item.restaurantName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                
                Spacer()
                
                Text("¥\(Int(item.log.expense))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .contentTransition(.numericText())
            }
            
            HStack(spacing: 12) {
                Label("\(item.log.peopleCount)人", systemImage: "person.2")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Label("人均¥\(Int(item.log.peopleCount > 0 ? item.log.expense / Double(item.log.peopleCount) : 0))", systemImage: "yensign.circle")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.softBackground.opacity(0.5))
        )
    }
}

// MARK: - Zodiac Card
struct ZodiacCardPreview: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧：图标
            if let zodiac = ZodiacUtil.loadZodiacSign() {
                Text(viewModel.zodiacSymbol(for: zodiac))
                    .font(.system(size: 36))
            } else {
                Image(systemName: "star")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .frame(width: 36, height: 36)
            }

            // 右侧：文字信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("味蕾星盘")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.lightText)

                    Spacer()
                }

                if let zodiac = ZodiacUtil.loadZodiacSign() {
                    Text(zodiac)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)

                    if let birthDate = ZodiacUtil.loadBirthDate() {
                        Text(viewModel.formatBirthDate(birthDate))
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                    }
                } else {
                    Text("未设置")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)

                    Text("点击设置生辰")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Zodiac Card Detail with Staggered Animation (图标与信息左右并列)
struct ZodiacCardDetail: View {
    @Bindable var viewModel: ProfileViewModel
    
    @State private var localController = CardAnimationController()
    
    var body: some View {
        VStack(spacing: 24) {
            // 星座图标与信息左右并列排布
            HStack(spacing: 20) {
                // 星座图标
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.coralRed.opacity(0.1))
                        .frame(width: 80, height: 80)

                    if let zodiac = ZodiacUtil.loadZodiacSign() {
                        Text(viewModel.zodiacSymbol(for: zodiac))
                            .font(.system(size: 40))
                    } else {
                        Image(systemName: "star.circle")
                            .font(.system(size: 36))
                            .foregroundColor(AppTheme.Colors.darkText)
                    }
                }
                .staggeredAnimation(index: 0, controller: localController)
                
                // 星座信息
                VStack(alignment: .leading, spacing: 6) {
                    if let zodiac = ZodiacUtil.loadZodiacSign() {
                        Text(zodiac)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                        
                        if let birthDate = ZodiacUtil.loadBirthDate() {
                            Text("生辰：\(viewModel.formatBirthDate(birthDate))")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                        }
                    } else {
                        Text("未设置生辰")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                    }
                }
                .staggeredAnimation(index: 1, controller: localController)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // 日期选择器 - 直接显示，无缩放动画
            DatePicker(
                "",
                selection: Binding(
                    get: { ZodiacUtil.loadBirthDate() ?? Date() },
                    set: { newDate in
                        ZodiacUtil.saveBirthDate(newDate)
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal, 20)
            // 不使用级联动画，直接显示
            
            // 说明文字
            Text("生辰仅用于解析每日食签，由 AI 结合星座与黄历算法驱动")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .staggeredAnimation(index: 3, controller: localController)
        }
        .onAppear {
            localController.beginExpansion()
        }
    }
}

// MARK: - Preview
#Preview {
    let viewModel = ProfileViewModel()
    
    return ScrollView {
        VStack(spacing: 20) {
            RestaurantsCardPreview(viewModel: viewModel)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 24)
            
            RestaurantsCardDetail(viewModel: viewModel)
                .frame(height: 450)
            
            TimelineCardPreview(viewModel: viewModel)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 24)
            
            ZodiacCardPreview(viewModel: viewModel)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 24)
        }
    }
    .background(Color.gray.opacity(0.1))
}
