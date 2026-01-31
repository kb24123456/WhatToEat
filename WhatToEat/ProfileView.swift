import SwiftUI
import SwiftData
import Charts
import PhotosUI
import LocalAuthentication

// MARK: - Profile View
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Restaurant.createdAt, order: .reverse) private var restaurants: [Restaurant]
    
    @State private var showingEditProfile = false
    @State private var showingPrivacyLock = false
    @State private var isUnlocked = false
    @State private var userProfile = UserProfile.load()
    
    // 统计数据
    private var totalRestaurants: Int { restaurants.count }
    private var totalCheckIns: Int { restaurants.reduce(0) { $0 + $1.logs.count } }
    private var totalExpense: Double { restaurants.reduce(0) { $0 + $1.logs.reduce(0) { $0 + $1.expense } } }
    private var uniqueCities: Int { Set(restaurants.map { $0.city }).count }
    
    // 加入天数
    private var joinDays: Int {
        guard let firstRestaurant = restaurants.min(by: { $0.createdAt < $1.createdAt }) else { return 0 }
        return Calendar.current.dateComponents([.day], from: firstRestaurant.createdAt, to: Date()).day ?? 0
    }
    
    var body: some View {
        ZStack {
            // 背景
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // 隐私锁按钮（右上角）
                    privacyLockButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    
                    // 头部名片
                    profileHeaderCard
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    
                    // 等级/称号
                    levelSection
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    
                    // 全局仪表盘
                    statsDashboard
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    
                    // 年度回顾
                    yearlyReviewCard
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    
                    // 消费分析
                    consumptionAnalysis
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    
                    // 标签管理
                    tagsManagementSection
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    
                    // 历史记录
                    historySection
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    
                    // 系统工具
                    toolsSection
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    
                    Spacer().frame(height: 40)
                }
                .padding(.top, AppTheme.Spacing.md)
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(userProfile: $userProfile)
        }
        .sheet(isPresented: $showingPrivacyLock) {
            PrivacyLockView(isUnlocked: $isUnlocked)
        }
    }
    
    // MARK: - 隐私锁按钮
    private var privacyLockButton: some View {
        Button {
            showingPrivacyLock = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 12))
                Text(isUnlocked ? "已解锁" : "隐私锁")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isUnlocked ? AppTheme.Colors.success : AppTheme.Colors.mediumGray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.card)
                    .shadow(color: AppTheme.Colors.shadowColor, radius: 4, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - 头部名片（磨砂卡片）
    private var profileHeaderCard: some View {
        Button {
            showingEditProfile = true
        } label: {
            HStack(spacing: 16) {
                // 头像
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.babyBlue.opacity(0.2))
                        .frame(width: 72, height: 72)
                    
                    if let avatarData = userProfile.avatarData,
                       let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 68, height: 68)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.Colors.babyBlue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(userProfile.nickname)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                    
                    Text(userProfile.bio)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .lineLimit(1)
                    
                    // 加入天数 - 呼吸感动画
                    HStack(spacing: 4) {
                        Text("加入第")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.Colors.lightText)
                        
                        Text("\(joinDays)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.accent)
                            .contentTransition(.numericText())
                        
                        Text("天")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.Colors.lightText)
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.lighterGray)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .pressableButton(scale: 0.98)
    }
    
    // MARK: - 等级/称号
    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("我的等级")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Spacer()
                
                LevelBadge(level: calculateLevel(), checkIns: totalCheckIns)
            }
            
            // 趣味称号
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(unlockedTitles, id: \.self) { title in
                        TitleBadge(title: title)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                .fill(AppTheme.Colors.card)
                .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - 全局仪表盘
    private var statsDashboard: some View {
        HStack(spacing: 0) {
            ProfileStatItem(value: "\(totalRestaurants)", label: "餐厅", color: AppTheme.Colors.darkText)
            
            Divider()
                .frame(height: 40)
            
            ProfileStatItem(value: "\(totalCheckIns)", label: "打卡", color: AppTheme.Colors.darkText)
            
            Divider()
                .frame(height: 40)
            
            ProfileStatItem(value: formatCurrency(totalExpense), label: "总支出", color: AppTheme.Colors.babyBlue)
            
            Divider()
                .frame(height: 40)
            
            ProfileStatItem(value: "\(uniqueCities)", label: "城市", color: AppTheme.Colors.accent)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                .fill(AppTheme.Colors.card)
                .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - 年度回顾
    private var yearlyReviewCard: some View {
        Button {
            // 进入年度回顾
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2025 年度美食报告")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                        
                        Text("回顾你的美食足迹")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.lighterGray)
                }
                
                // 预览数据
                HStack(spacing: 16) {
                    MiniStat(icon: "fork.knife", value: "\(totalRestaurants)", label: "家餐厅")
                    MiniStat(icon: "creditcard", value: formatCurrency(totalExpense), label: "总消费")
                    MiniStat(icon: "crown.fill", value: "海底捞", label: "最常去")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.lightRed.opacity(0.3),
                                AppTheme.Colors.lightBlue.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .pressableButton(scale: 0.98)
    }
    
    // MARK: - 消费分析
    private var consumptionAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("消费分析")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            // 消费趋势图
            consumptionTrendChart
            
            Divider()
                .padding(.vertical, 8)
            
            // 餐饮类型占比
            cuisineTypeChart
            
            Divider()
                .padding(.vertical, 8)
            
            // 人均消费分布
            perPersonDistribution
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                .fill(AppTheme.Colors.card)
                .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - 消费趋势图
    private var consumptionTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("消费趋势（近6个月）")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            // 模拟数据
            let data = [
                (month: "8月", amount: 1200.0),
                (month: "9月", amount: 2800.0),
                (month: "10月", amount: 1900.0),
                (month: "11月", amount: 3500.0),
                (month: "12月", amount: 4200.0),
                (month: "1月", amount: 3100.0)
            ]
            
            Chart(data, id: \.month) { item in
                BarMark(
                    x: .value("月份", item.month),
                    y: .value("金额", item.amount)
                )
                .foregroundStyle(AppTheme.Colors.babyBlue.gradient)
                .cornerRadius(4)
            }
            .frame(height: 120)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }
    
    // MARK: - 餐饮类型占比
    private var cuisineTypeChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("餐饮类型占比")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            // 模拟数据
            let data = [
                (type: "火锅", count: 28, color: Color.red),
                (type: "日料", count: 15, color: Color.orange),
                (type: "烧烤", count: 12, color: Color.yellow),
                (type: "西餐", count: 8, color: Color.blue),
                (type: "其他", count: 20, color: Color.gray)
            ]
            
            HStack(spacing: 16) {
                // 环形图
                Chart(data, id: \.type) { item in
                    SectorMark(
                        angle: .value("数量", item.count),
                        innerRadius: .ratio(0.6)
                    )
                    .foregroundStyle(item.color)
                }
                .frame(width: 100, height: 100)
                
                // 图例
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(data.prefix(4), id: \.type) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.type)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                            Text("\(item.count)%")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.Colors.darkText)
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - 人均消费分布
    private var perPersonDistribution: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("人均消费分布")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            let ranges = [
                (range: "¥0-50", count: 20, percent: 0.2),
                (range: "¥50-100", count: 45, percent: 0.45),
                (range: "¥100-200", count: 28, percent: 0.28),
                (range: "¥200+", count: 7, percent: 0.07)
            ]
            
            VStack(spacing: 8) {
                ForEach(ranges, id: \.range) { item in
                    HStack(spacing: 8) {
                        Text(item.range)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                            .frame(width: 50, alignment: .leading)
                        
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.Colors.babyBlue)
                                .frame(width: geo.size.width * item.percent, height: 8)
                        }
                        .frame(height: 8)
                        
                        Text("\(Int(item.percent * 100))%")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
    }
    
    // MARK: - 标签管理
    private var tagsManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("我的标签")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Spacer()
                
                Button {
                    // 新建标签
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("新建")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.babyBlue)
                }
            }
            
            // 标签云
            let allTags = extractAllTags()
            FlowLayout(spacing: 8) {
                ForEach(0..<min(allTags.count, 15), id: \.self) { index in
                    let tag = allTags[index]
                    TagItem(name: tag.name, count: tag.count)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                .fill(AppTheme.Colors.card)
                .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - 历史记录
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("历史记录")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Spacer()
                
                Button {
                    // 查看全部
                } label: {
                    Text("查看全部")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                }
            }
            
            // 时间轴
            let recentLogs = getRecentLogs(limit: 5)
            VStack(spacing: 0) {
                ForEach(Array(recentLogs.enumerated()), id: \.element.id) { index, log in
                    TimelineItem(
                        log: log,
                        isLast: index == recentLogs.count - 1
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                .fill(AppTheme.Colors.card)
                .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - 系统工具
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统工具")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ToolItem(icon: "icloud.and.arrow.up", title: "iCloud 同步", subtitle: "上次同步：刚刚", color: .blue)
                ToolDivider()
                ToolItem(icon: "doc.text", title: "导出美食报告", subtitle: "PDF / 长图 / 数据", color: .green)
                ToolDivider()
                ToolItem(icon: "square.and.arrow.up", title: "分享美食地图", subtitle: "生成专属分享卡片", color: .orange)
                ToolDivider()
                ToolItem(icon: "externaldrive", title: "存储空间", subtitle: "已用 45MB / 100MB", color: .purple)
                ToolDivider()
                ToolItem(icon: "info.circle", title: "关于吃啥呢", subtitle: "版本 1.2.0", color: .gray)
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                    .fill(AppTheme.Colors.card)
                    .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 4)
            )
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - 辅助方法
    private func calculateLevel() -> Int {
        if totalCheckIns >= 500 { return 5 }
        if totalCheckIns >= 100 { return 4 }
        if totalCheckIns >= 50 { return 3 }
        if totalCheckIns >= 10 { return 2 }
        return 1
    }
    
    private var unlockedTitles: [String] {
        var titles: [String] = []
        let hotpotCount = restaurants.filter { $0.tags.contains("火锅") }.reduce(0) { $0 + $1.logs.count }
        let japaneseCount = restaurants.filter { $0.tags.contains("日料") || $0.tags.contains("日本料理") }.reduce(0) { $0 + $1.logs.count }
        let coffeeCount = restaurants.filter { $0.tags.contains("咖啡") || $0.tags.contains("咖啡厅") }.reduce(0) { $0 + $1.logs.count }

        if hotpotCount >= 20 { titles.append("火锅达人") }
        if japaneseCount >= 15 { titles.append("日料探索者") }
        if coffeeCount >= 30 { titles.append("咖啡续命") }
        if totalCheckIns >= 100 { titles.append("美食家") }

        return titles.isEmpty ? ["美食新手"] : titles
    }

    private func extractAllTags() -> [(name: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for restaurant in restaurants {
            for tag in restaurant.tags {
                tagCounts[tag, default: 0] += restaurant.logs.count
            }
        }
        return tagCounts.sorted { $0.value > $1.value }.map { (name: $0.key, count: $0.value) }
    }

    private func getRecentLogs(limit: Int) -> [VisitLog] {
        var allLogs: [VisitLog] = []
        for restaurant in restaurants {
            for log in restaurant.logs {
                allLogs.append(log)
            }
        }
        return allLogs.sorted { $0.date > $1.date }.prefix(limit).map { $0 }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "¥%.1fk", value / 1000)
        } else if value >= 1000 {
            return String(format: "¥%.0f", value)
        } else {
            return String(format: "¥%.0f", value)
        }
    }
}

// MARK: - 统计项组件
struct ProfileStatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.8)
            
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 迷你统计
struct MiniStat: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text(label)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(AppTheme.Colors.lightText)
            }
        }
    }
}

// MARK: - 等级徽章
struct LevelBadge: View {
    let level: Int
    let checkIns: Int
    
    var levelInfo: (name: String, color: Color) {
        switch level {
        case 5: return ("米其林猎手", Color.purple)
        case 4: return ("美食家", Color.orange)
        case 3: return ("资深吃货", Color.blue)
        case 2: return ("吃货练习生", Color.green)
        default: return ("美食新手", Color.gray)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Lv.\(level)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
            
            Text(levelInfo.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(levelInfo.color)
        )
    }
}

// MARK: - 称号徽章
struct TitleBadge: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.Colors.darkText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.lightBlue)
            )
    }
}

// MARK: - 标签项
struct TagItem: View {
    let name: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 12, design: .rounded))
            
            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
        }
        .foregroundColor(AppTheme.Colors.darkText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.warmGray)
        )
    }
}

// MARK: - 时间轴项目
struct TimelineItem: View {
    let log: VisitLog
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 时间线
            VStack(spacing: 0) {
                Circle()
                    .fill(AppTheme.Colors.babyBlue)
                    .frame(width: 8, height: 8)
                
                if !isLast {
                    Rectangle()
                        .fill(AppTheme.Colors.separatorGray)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 8)
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(log.date.chineseDateOnly)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.Colors.lightText)
                
                HStack {
                    Text("打卡消费")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                    
                    Spacer()
                    
                    Text(String(format: "¥%.0f", log.expense))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.accent)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(height: 60)
    }
}

// MARK: - 工具项
struct ToolItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        Button {
            // 执行操作
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                    
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.Colors.lightText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.lighterGray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 工具分割线
struct ToolDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.Colors.divider)
            .frame(height: 1)
            .padding(.leading, 60)
    }
}



// MARK: - 用户资料模型
struct UserProfile: Codable {
    var nickname: String
    var bio: String
    var avatarData: Data?
    
    static let `default` = UserProfile(nickname: "美食探险家", bio: "今天吃什么？", avatarData: nil)
    
    static func load() -> UserProfile {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        return .default
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }
}

// MARK: - 编辑资料视图
struct EditProfileView: View {
    @Binding var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    @State private var nickname: String = ""
    @State private var bio: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarData: Data?
    
    var body: some View {
        NavigationView {
            Form {
                Section("头像") {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.babyBlue.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                if let avatarData = avatarData,
                                   let uiImage = UIImage(data: avatarData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 96)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("基本信息") {
                    TextField("昵称", text: $nickname)
                    TextField("个性签名", text: $bio)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        userProfile.nickname = nickname
                        userProfile.bio = bio
                        userProfile.avatarData = avatarData
                        userProfile.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                nickname = userProfile.nickname
                bio = userProfile.bio
                avatarData = userProfile.avatarData
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
        }
    }
}

// MARK: - 隐私锁视图
struct PrivacyLockView: View {
    @Binding var isUnlocked: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 64))
                .foregroundColor(isUnlocked ? AppTheme.Colors.success : AppTheme.Colors.accent)
                .symbolEffect(.bounce, value: isUnlocked)
            
            Text(isUnlocked ? "已解锁" : "隐私保护")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            Text(isUnlocked ? "您可以访问个人信息" : "使用 Face ID 解锁")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.destructive)
                    .padding(.top, 8)
            }
            
            Spacer()
            
            if !isUnlocked {
                Button {
                    authenticate()
                } label: {
                    HStack {
                        Image(systemName: "faceid")
                        Text("Face ID 解锁")
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.Colors.accent)
                    )
                }
                .padding(.horizontal, 32)
            } else {
                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.Colors.success)
                        )
                }
                .padding(.horizontal, 32)
            }
            
            Spacer().frame(height: 40)
        }
        .onAppear {
            if !isUnlocked {
                authenticate()
            }
        }
    }
    
    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "解锁个人信息") { success, error in
                DispatchQueue.main.async {
                    isAuthenticating = false
                    if success {
                        isUnlocked = true
                    } else {
                        errorMessage = "验证失败，请重试"
                    }
                }
            }
        } else {
            isAuthenticating = false
            errorMessage = "设备不支持 Face ID"
        }
    }
}

#Preview {
    ProfileView()
}
