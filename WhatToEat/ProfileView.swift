import SwiftUI
import SwiftData
import Charts
import PhotosUI
import LocalAuthentication

// MARK: - Profile View (重构版)
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Restaurant.createdAt, order: .reverse) private var restaurants: [Restaurant]
    
    @State private var showingEditProfile = false
    @State private var userProfile = UserProfile.load()
    @State private var privacyEnabled = UserDefaults.standard.bool(forKey: "privacyEnabled")
    
    // MARK: - 打卡记录视图状态
    @State private var showCheckInHistory = false
    
    // MARK: - 餐厅详情状态
    @State private var selectedRestaurantForDetail: Restaurant? = nil
    
    // MARK: - 标签管理状态
    @State private var userTags: [String] = UserDefaults.standard.stringArray(forKey: "userCustomTags") ?? ["氛围感", "老字号", "二刷", "排队王", "性价比"]
    @State private var isEditingTags = false
    @State private var newTagInput = ""
    @FocusState private var tagInputIsFocused: Bool
    
    // MARK: - 统计数据
    private var totalRestaurants: Int { restaurants.count }
    private var totalCheckIns: Int { restaurants.reduce(0) { $0 + $1.logs.count } }
    private var totalExpense: Double { restaurants.reduce(0) { $0 + $1.logs.reduce(0) { $0 + $1.expense } } }
    private var uniqueCities: Int { Set(restaurants.map { $0.city }).count }
    
    private var joinDays: Int {
        guard let firstRestaurant = restaurants.min(by: { $0.createdAt < $1.createdAt }) else { return 0 }
        return Calendar.current.dateComponents([.day], from: firstRestaurant.createdAt, to: Date()).day ?? 0
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Phase 1: 身份识别与全局勋章
                glassProfileCard
                grandStatsDashboard
                
                // Phase 2: 数据可视化与偏好分析
                consumptionAnalysisCard
                tagsCloudSection
                top5RestaurantsSection
                
                // Phase 3: 打卡时间轴
                timelineSection
                
                // Phase 4: 工具箱、安全与隐私
                milkyToolList
                bottomInfo
                
                // 键盘避让：编辑标签时增加额外底部空间
                if isEditingTags {
                    Color.clear.frame(height: 300)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .useMilkyDiffuseBackground()
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(userProfile: $userProfile)
        }
        // 餐厅详情 Sheet
        .sheet(item: $selectedRestaurantForDetail) { restaurant in
            RestaurantDetailView(
                restaurant: restaurant,
                locationManager: LocationManager(),
                isPresented: Binding(
                    get: { selectedRestaurantForDetail != nil },
                    set: { if !$0 { selectedRestaurantForDetail = nil } }
                )
            )
        }
        // 键盘避让：点击空白处收起键盘
        .scrollDismissesKeyboard(.interactively)
        .animation(.easeInOut(duration: 0.25), value: isEditingTags)
    }
    
    // MARK: - Phase 1: Profile Card (白色透明名片，显示背景渐变)
    private var glassProfileCard: some View {
        Button {
            showingEditProfile = true
        } label: {
            HStack(spacing: 16) {
                // 头像
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.5))
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
                    // 昵称
                    Text(userProfile.nickname)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                    
                    // 个性签名
                    if !userProfile.bio.isEmpty {
                        Text(userProfile.bio)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                            .lineLimit(1)
                    }
                    
                    // 等级勋章 - Baby Blue 渐变边框
                    LevelBadgeView(level: calculateLevel(), checkIns: totalCheckIns)
                    
                    // 加入天数
                    HStack(spacing: 4) {
                        Text("加入第")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                        Text("\(joinDays)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.accent)
                            .contentTransition(.numericText())
                        Text("天")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGray)
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
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .pressableButton(scale: 0.98)
    }
    
    // MARK: - Phase 1: Grand Stats Dashboard (全局仪表盘)
    private var grandStatsDashboard: some View {
        HStack(spacing: 0) {
            StatCell(value: "\(totalRestaurants)", label: "餐厅", color: AppTheme.Colors.darkText)
            Divider().frame(height: 40)
            StatCell(value: "\(totalCheckIns)", label: "打卡", color: AppTheme.Colors.darkText)
            Divider().frame(height: 40)
            StatCell(value: formatCurrency(totalExpense), label: "总支出", color: AppTheme.Colors.darkText)
            Divider().frame(height: 40)
            StatCell(value: "\(uniqueCities)", label: "城市", color: AppTheme.Colors.darkText)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Phase 2: Consumption Analysis (消费分析)
    private var consumptionAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("消费洞察")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            // 月度消费趋势图
            consumptionTrendChart
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // 餐饮类型占比分段进度条
            cuisineTypeBars
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
    }
    
    // 月度消费趋势折线图
    private var consumptionTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("近6个月消费趋势")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            let data = getMonthlyExpenses()
            
            Chart(data, id: \.month) { item in
                LineMark(
                    x: .value("月份", item.month),
                    y: .value("金额", item.amount)
                )
                .foregroundStyle(AppTheme.Colors.babyBlue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("月份", item.month),
                    y: .value("金额", item.amount)
                )
                .foregroundStyle(AppTheme.Colors.babyBlue.opacity(0.1))
            }
            .frame(height: 100)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("¥\(intValue)")
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.Colors.lightText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let stringValue = value.as(String.self) {
                            Text(stringValue)
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.Colors.lightText)
                        }
                    }
                }
            }
        }
    }
    
    // 餐饮类型占比分段进度条
    private var cuisineTypeBars: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("餐饮偏好")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            let typeData = getCuisineTypeDistribution()
            
            VStack(spacing: 8) {
                ForEach(typeData.prefix(4), id: \.type) { item in
                    HStack(spacing: 8) {
                        Text(item.type)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                            .frame(width: 50, alignment: .leading)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppTheme.Colors.warmGray)
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(item.color)
                                    .frame(width: geo.size.width * item.percent, height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        Text("\(Int(item.percent * 100))%")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
    }
    
    // MARK: - Phase 2: Tags Cloud (我的标签)
    private var tagsCloudSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            tagsCloudHeader
            tagsCloudContent
                .padding(.bottom, isEditingTags ? 28 : 0) // 编辑模式下增加底部空间容纳按钮
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - 标签区域头部
    private var tagsCloudHeader: some View {
        HStack {
            Text("我的标签")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            Spacer()
            
            if !isEditingTags {
                Button {
                    withAnimation(AppTheme.Animations.editingSpring) {
                        isEditingTags = true
                    }
                } label: {
                    Text("管理")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                }
            }
        }
    }
    
    // MARK: - 标签区域内容
    private var tagsCloudContent: some View {
        ZStack(alignment: .bottomTrailing) {
            tagsCloudMainContent
            tagsCloudActionButtons
        }
        .onTapGesture {
            if !isEditingTags {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingTags = true
                }
            }
        }
    }
    
    // MARK: - 标签区域主内容
    private var tagsCloudMainContent: some View {
        VStack(spacing: 0) {
            tagsLayoutContainer
            
            if isEditingTags {
                presetTagsSection
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(AppTheme.Animations.standardSpring, value: isEditingTags)
    }
    
    // MARK: - 标签布局容器
    @ViewBuilder
    private var tagsLayoutContainer: some View {
        if isEditingTags {
            tagsEditingLayout
        } else {
            tagsDisplayLayout
        }
    }
    
    // MARK: - 编辑模式标签布局
    private var tagsEditingLayout: some View {
        FlowLayout(spacing: 10) {
            ForEach(userTags, id: \.self) { tag in
                profileTagSticker(tag)
            }
            newTagInputField
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
    }
    
    // MARK: - 新标签输入框
    private var newTagInputField: some View {
        TextField("新标签...", text: $newTagInput)
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(AppTheme.Colors.darkText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.5))
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.babyBlue.opacity(0.3), lineWidth: 1)
            )
            .focused($tagInputIsFocused)
            .frame(minWidth: 80)
            .onSubmit {
                addNewTag()
            }
            .onAppear {
                tagInputIsFocused = true
            }
    }
    
    // MARK: - 展示模式标签布局（最多2行）
    private var tagsDisplayLayout: some View {
        LimitedRowsFlowLayout(spacing: 10, maxRows: 2) {
            ForEach(userTags, id: \.self) { tag in
                profileTagSticker(tag)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
    }
    
    // MARK: - 标签区域操作按钮（勾叉）- 一半在容器内一半在容器外
    @ViewBuilder
    private var tagsCloudActionButtons: some View {
        if isEditingTags {
            HStack(spacing: 12) {
                cancelTagEditButton
                confirmTagEditButton
            }
            .padding(.trailing, 8)
            .padding(.bottom, 8)
            .offset(y: 26) // 向下偏移，使按钮一半在容器外
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: - 取消编辑按钮
    private var cancelTagEditButton: some View {
        Button {
            withAnimation(AppTheme.Animations.editingSpring) {
                isEditingTags = false
                newTagInput = ""
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(AppTheme.Colors.darkBackground)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
        }
    }
    
    // MARK: - 确认编辑按钮
    private var confirmTagEditButton: some View {
        Button {
            withAnimation(AppTheme.Animations.editingSpring) {
                saveTags()
                isEditingTags = false
                newTagInput = ""
            }
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(AppTheme.Colors.accent)
                        .shadow(color: AppTheme.Shadows.elevated.color, radius: 8, x: 0, y: 4)
                )
        }
    }
    
    // MARK: - 推荐标签区域
    private var presetTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐标签")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
            
            FlowLayout(spacing: 10) {
                let presetTags = ["氛围感", "老字号", "二刷", "排队王", "性价比", "网红店", "隐藏菜单", "约会圣地"]
                ForEach(presetTags.filter { !userTags.contains($0) }, id: \.self) { tag in
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                            userTags.append(tag)
                        }
                    } label: {
                        Text(tag)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.5))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.Colors.separatorGray.opacity(0.5), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - 个人资料页标签贴纸（带删除按钮）
    private func profileTagSticker(_ tag: String) -> some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            if isEditingTags {
                // 删除按钮
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        userTags.removeAll { $0 == tag }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Colors.lightText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppTheme.Colors.warmGray.opacity(0.6))
        )
    }
    
    // MARK: - 添加新标签
    private func addNewTag() {
        let trimmed = newTagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty && !userTags.contains(trimmed) else { return }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
            userTags.append(trimmed)
            newTagInput = ""
        }
    }
    
    // MARK: - 保存标签
    private func saveTags() {
        UserDefaults.standard.set(userTags, forKey: "userCustomTags")
    }
    
    // MARK: - Phase 2: TOP 5 Restaurants (年度回顾预热)
    private var top5RestaurantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最常去的餐厅 TOP 5")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Spacer()
                
                Button {
                    // 查看完整年度回顾
                } label: {
                    HStack(spacing: 4) {
                        Text("年度回顾")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(AppTheme.Colors.babyBlue)
                }
            }
            
            let topRestaurants = getTopRestaurants(limit: 5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<topRestaurants.count, id: \.self) { index in
                        let restaurant = topRestaurants[index]
                        TopRestaurantCard(
                            restaurant: restaurant,
                            rank: index + 1,
                            onTap: {
                                selectedRestaurantForDetail = restaurant
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Phase 3: Timeline (美食足迹时间轴)
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("美食足迹")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Spacer()
                
                Button {
                    showCheckInHistory = true
                } label: {
                    Text("查看全部")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                }
            }
            
            // 时间轴
            let recentLogs = getRecentLogsWithRestaurant(limit: 5)
            VStack(spacing: 0) {
                ForEach(0..<recentLogs.count, id: \.self) { index in
                    let item = recentLogs[index]
                    TimelineItemView(
                        log: item.log,
                        restaurantName: item.restaurantName,
                        isLast: index == recentLogs.count - 1,
                        isToday: Calendar.current.isDateInToday(item.log.date)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
        .sheet(isPresented: $showCheckInHistory) {
            CheckInHistoryView()
        }
    }
    
    // MARK: - Phase 4: Milky Tool List (奶脂风格工具列表)
    private var milkyToolList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 隐私锁开关
            PrivacyToggleView(privacyEnabled: $privacyEnabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
                .background(AppTheme.Colors.divider)
                .padding(.leading, 60)
            
            // iCloud 同步
            MilkyToolRow(
                icon: "icloud.and.arrow.up",
                title: "iCloud 同步",
                subtitle: "上次同步：刚刚",
                color: .blue
            )
            
            Divider()
                .background(AppTheme.Colors.divider)
                .padding(.leading, 60)
            
            // 导出 PDF 报告
            MilkyToolRow(
                icon: "doc.text",
                title: "导出美食报告",
                subtitle: "生成精美 PDF 长图",
                color: .green
            )
            
            Divider()
                .background(AppTheme.Colors.divider)
                .padding(.leading, 60)
            
            // 分享美食地图
            MilkyToolRow(
                icon: "square.and.arrow.up",
                title: "分享美食地图",
                subtitle: "生成专属分享卡片",
                color: .orange
            )
            
            Divider()
                .background(AppTheme.Colors.divider)
                .padding(.leading, 60)
            
            // 清理存储
            MilkyToolRow(
                icon: "externaldrive",
                title: "存储空间",
                subtitle: "已用 45MB / 100MB",
                color: .purple
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.Colors.separatorGray.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Phase 4: Bottom Info (底部信息)
    private var bottomInfo: some View {
        VStack(spacing: 4) {
            Text("让每一餐都值得被记录")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
            
            Text("版本 1.2.0")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(AppTheme.Colors.lighterGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
    
    // MARK: - Helper Methods
    private func calculateLevel() -> Int {
        if totalCheckIns >= 500 { return 5 }
        if totalCheckIns >= 100 { return 4 }
        if totalCheckIns >= 50 { return 3 }
        if totalCheckIns >= 10 { return 2 }
        return 1
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
    
    private func getMonthlyExpenses() -> [(month: String, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(month: String, amount: Double)] = []
        
        for i in (0..<6).reversed() {
            if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                let monthStr = String(format: "%d月", calendar.component(.month, from: date))
                let amount = Double.random(in: 800...4000) // 模拟数据
                result.append((month: monthStr, amount: amount))
            }
        }
        return result
    }
    
    private func getCuisineTypeDistribution() -> [(type: String, count: Int, percent: Double, color: Color)] {
        let colors: [Color] = [AppTheme.Colors.accent, AppTheme.Colors.babyBlue, AppTheme.Colors.mediumGray, AppTheme.Colors.secondary]
        let types = ["火锅", "日料", "烧烤", "西餐", "其他"]
        let counts = [28, 15, 12, 8, 20]
        let total = counts.reduce(0, +)
        
        return types.enumerated().map { index, type in
            let percent = Double(counts[index]) / Double(total)
            return (type: type, count: counts[index], percent: percent, color: colors[index % colors.count])
        }
    }
    
    private func getTopTags(limit: Int) -> [(name: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for restaurant in restaurants {
            for tag in restaurant.tags {
                tagCounts[tag, default: 0] += restaurant.logs.count
            }
        }
        return tagCounts.sorted { $0.value > $1.value }.prefix(limit).map { (name: $0.key, count: $0.value) }
    }
    
    private func getTopRestaurants(limit: Int) -> [Restaurant] {
        return restaurants
            .sorted { $0.logs.count > $1.logs.count }
            .prefix(limit)
            .map { $0 }
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
    
    private func getRecentLogsWithRestaurant(limit: Int) -> [(log: VisitLog, restaurantName: String)] {
        var allLogs: [(log: VisitLog, restaurantName: String)] = []
        for restaurant in restaurants {
            for log in restaurant.logs {
                allLogs.append((log: log, restaurantName: restaurant.name))
            }
        }
        return allLogs.sorted { $0.log.date > $1.log.date }.prefix(limit).map { $0 }
    }
}

// MARK: - Stat Cell (仪表盘单元)
struct StatCell: View {
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

// MARK: - Level Badge View (等级勋章)
struct LevelBadgeView: View {
    let level: Int
    let checkIns: Int
    
    var levelInfo: (name: String, color: Color, hasGoldRim: Bool) {
        switch level {
        case 5: return ("米其林猎手", Color.purple, true)
        case 4: return ("美食家", Color.orange, true)
        case 3: return ("资深吃货", Color.blue, false)
        case 2: return ("吃货练习生", Color.green, false)
        default: return ("美食新手", Color.gray, false)
        }
    }
    
    var body: some View {
        let info = levelInfo
        
        HStack(spacing: 4) {
            Text(info.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundColor(info.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(info.color.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(
                    info.hasGoldRim ? Color.yellow.opacity(0.6) : info.color.opacity(0.3),
                    lineWidth: info.hasGoldRim ? 1.5 : 1
                )
        )
    }
}

// MARK: - Tag Cloud Item (标签云项)
struct TagCloudItem: View {
    let name: String
    let count: Int
    let index: Int
    
    var colors: [Color] {
        [AppTheme.Colors.lightRed, AppTheme.Colors.lightBlue, AppTheme.Colors.lightGreen, AppTheme.Colors.warmGray]
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 13, weight: .medium, design: .rounded))
            
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGray)
        }
        .foregroundColor(AppTheme.Colors.darkText)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(colors[index % colors.count].opacity(0.5))
        )
    }
}

// MARK: - Top Restaurant Card (TOP 5 餐厅卡片)
struct TopRestaurantCard: View {
    let restaurant: Restaurant
    let rank: Int
    var onTap: () -> Void = {}
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 餐厅头像（左上角叠加排名徽章）
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.warmGray)
                        .frame(width: 60, height: 60)
                    
                    if let imageName = restaurant.coverPhotoFilename,
                       let uiImage = ImageManager.shared.loadImage(filename: imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.Colors.babyBlue)
                    }
                    
                    // 排名徽章 - 移至左上角，缩小20%（原32pt -> 25.6pt ≈ 26pt）
                    ZStack {
                        Circle()
                            .fill(rank <= 3 ? AppTheme.Colors.accent : AppTheme.Colors.warmGray)
                            .frame(width: 26, height: 26)
                        
                        Text("\(rank)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(rank <= 3 ? .white : AppTheme.Colors.mediumGray)
                    }
                    .offset(x: -4, y: -4) // 向左上偏移，使徽章一半在图片内
                }
                
                // 餐厅名
                Text(restaurant.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                    .frame(width: 70)
                
                // 打卡次数
                Text("\(restaurant.logs.count)次")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(AppTheme.Colors.lightText)
            }
            .frame(width: 80)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .pressableButton(scale: 0.95) // 添加缩放反馈
    }
}

// MARK: - Timeline Item View (时间轴项)
struct TimelineItemView: View {
    let log: VisitLog
    let restaurantName: String
    let isLast: Bool
    let isToday: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 时间线
            VStack(spacing: 0) {
                Circle()
                    .fill(isToday ? AppTheme.Colors.babyBlue : AppTheme.Colors.accent)
                    .frame(width: 8, height: 8)
                
                if !isLast {
                    Rectangle()
                        .fill(AppTheme.Colors.separatorGray.opacity(0.5))
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
                    Text(restaurantName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(String(format: "¥%.0f", log.expense))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.accent)
                }
            }
            .padding(.vertical, 10)
        }
        .frame(height: isLast ? 50 : 70)
    }
}

// MARK: - Privacy Toggle View (隐私锁开关)
struct PrivacyToggleView: View {
    @Binding var privacyEnabled: Bool
    @State private var showingAuthSheet = false
    
    var body: some View {
        Button {
            if !privacyEnabled {
                showingAuthSheet = true
            } else {
                privacyEnabled = false
                UserDefaults.standard.set(false, forKey: "privacyEnabled")
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: privacyEnabled ? "lock.fill" : "lock.open")
                    .font(.system(size: 20))
                    .foregroundColor(privacyEnabled ? AppTheme.Colors.accent : AppTheme.Colors.mediumGray)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((privacyEnabled ? AppTheme.Colors.accent : AppTheme.Colors.mediumGray).opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("隐私锁定")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                    
                    Text(privacyEnabled ? "已开启 Face ID 保护" : "开启后需要验证才能访问")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.Colors.lightText)
                }
                
                Spacer()
                
                Toggle("", isOn: $privacyEnabled)
                    .labelsHidden()
                    .disabled(true)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingAuthSheet) {
            PrivacyAuthSheet { success in
                if success {
                    privacyEnabled = true
                    UserDefaults.standard.set(true, forKey: "privacyEnabled")
                }
                showingAuthSheet = false
            }
        }
    }
}

// MARK: - Privacy Auth Sheet (隐私认证弹窗)
struct PrivacyAuthSheet: View {
    let onComplete: (Bool) -> Void
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // 毛玻璃遮罩效果
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "faceid")
                    .font(.system(size: 56))
                    .foregroundColor(AppTheme.Colors.accent)
            }
            
            VStack(spacing: 8) {
                Text("开启隐私保护")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text("使用 Face ID 保护您的个人数据")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.destructive)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    authenticate()
                } label: {
                    HStack {
                        Image(systemName: "faceid")
                        Text("验证 Face ID")
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
                
                Button {
                    onComplete(false)
                } label: {
                    Text("取消")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .padding()
                }
            }
            .padding(.horizontal, 32)
            
            Spacer().frame(height: 40)
        }
        .onAppear {
            authenticate()
        }
    }
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "开启隐私保护") { success, error in
                DispatchQueue.main.async {
                    if success {
                        onComplete(true)
                    } else if let error = error {
                        errorMessage = "验证失败: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            errorMessage = "设备不支持 Face ID"
        }
    }
}

// MARK: - Milky Tool Row (奶脂工具行)
struct MilkyToolRow: View {
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

// MARK: - User Profile Model
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

// MARK: - Edit Profile View
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

// MARK: - Limited Rows Flow Layout (限制行数的流式布局)
struct LimitedRowsFlowLayout: Layout {
    var spacing: CGFloat = 10
    var maxRows: Int = 2
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let result = calculateLayout(in: width, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(in: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                          y: bounds.minY + result.positions[index].y),
                             proposal: .unspecified)
            }
        }
    }
    
    private func calculateLayout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var currentRow = 1
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // 检查是否需要换行
            if x + size.width > width && x > 0 {
                if currentRow >= maxRows {
                    // 已达到最大行数，停止添加
                    break
                }
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
                currentRow += 1
            }
            
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        let totalHeight = y + rowHeight
        return (CGSize(width: width, height: totalHeight), positions)
    }
}

#Preview {
    ProfileView()
}
