import SwiftUI
import SwiftData
import MapKit

// MARK: - 通知名称扩展
extension Notification.Name {
    static let restaurantListShouldRefresh = Notification.Name("restaurantListShouldRefresh")
    static let hideTabBar = Notification.Name("hideTabBar")
    static let restoreTabBar = Notification.Name("restoreTabBar")
}

// MARK: - 1. 核心视图
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    
    // 状态管理
    @State private var showImportSheet = false
    @State private var showCityPicker = false
    @FocusState private var isSearchFocused: Bool
    
    @StateObject private var locationManager = LocationManager.shared
    
    // 筛选和排序状态
    @State private var selectedCity: String
    @State private var selectedDistrict: String?
    @State private var selectedType: String?
    @State private var searchText = ""
    
    @State private var sortOption: SortOption = .smart
    
    // 城市存储键
    private let kSavedCityKey = "UserSelectedCity"
    

    
    // 选中餐厅（用于详情页展开）
    @State private var selectedRestaurant: Restaurant?
    @State private var isDetailPresented = false
    @State private var isTabBarHidden = false
    @State private var isAnimatingOut = false
    
    // 用于调试
    @State private var debugMessage: String = ""
    
    // 初始化方法
    init() {
        if let savedCity = UserDefaults.standard.string(forKey: kSavedCityKey) {
            _selectedCity = State(initialValue: savedCity)
        } else {
            _selectedCity = State(initialValue: "重庆")
        }
    }
    
    private var currentDistricts: [String] {
        let districts = RegionManager.shared.getDistricts(for: selectedCity)
        print("currentDistricts: city=\(selectedCity), count=\(districts.count), districts=\(districts.prefix(5))...")
        print("RegionManager allCities: \(RegionManager.shared.allCities.prefix(5))... (total: \(RegionManager.shared.allCities.count))")
        return districts
    }
    
    // MARK: - Navigation路径
    @State private var navigationPath = NavigationPath()
    
    // MARK: - 生命周期
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topLeading) {
                // 最底层：奶白背景
                Color(hex: "#fdf9f3")
                    .ignoresSafeArea()
                
                // 中间层：流体黑色弥散背景（置顶）
                LiquidDarkHeaderBackground()
                    .zIndex(0)

                // 顶层：HeaderView + FilterBarView（内容层）
                DynamicHeaderView(
                    selectedCity: selectedCity,
                    showCityPicker: $showCityPicker,
                    searchText: $searchText,
                    isSearchFocused: _isSearchFocused,
                    scrollOffset: scrollOffset
                )
                .zIndex(100)
                
                VStack(alignment: .leading, spacing: 0) {
                    // 占位空间，避免内容被固定头部遮挡（与头部高度匹配）
                    Color.clear.frame(height: 72)
                    
                    FilterBarView(
                        selectedCity: selectedCity,
                        selectedDistrict: $selectedDistrict,
                        selectedType: $selectedType,
                        sortOption: $sortOption,
                        restaurants: restaurants,
                        districts: currentDistricts
                    )
                    // 筛选栏底部横线：硬核视觉切分点
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 0.5)
                            .offset(y: 8), // 位于筛选栏下方
                        alignment: .bottom
                    )
                    
                    StackedRestaurantListView(
                        filteredRestaurants: filteredRestaurants,
                        locationManager: locationManager,
                        navigationPath: $navigationPath,
                        scrollOffset: $scrollOffset
                    )
                }
            }
            .navigationDestination(for: Restaurant.self) { restaurant in
                RestaurantDetailView(
                    restaurant: restaurant,
                    locationManager: locationManager,
                    navigationPath: $navigationPath
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .restaurantListShouldRefresh)) { _ in
                if let savedCity = UserDefaults.standard.string(forKey: "UserSelectedCity") {
                    selectedCity = savedCity
                }
                print("RestaurantListRefresh: 收到刷新通知, selectedCity=\(selectedCity)")
            }
            .toolbar(.visible, for: .tabBar)
            .sheet(isPresented: $showImportSheet) { ImportDataView() }
            .sheet(isPresented: $showCityPicker) {
                CitySelectionView(selectedCity: $selectedCity)
            }
            .onChange(of: selectedCity) {
                UserDefaults.standard.set($0, forKey: kSavedCityKey)
            }
            // 状态栏适配：强制白色文字
            .preferredColorScheme(.light)
        }
    }

    // MARK: - 动态毛玻璃导航条 (适配深色流体背景)
    private struct DynamicHeaderView: View {
        let selectedCity: String
        @Binding var showCityPicker: Bool
        @Binding var searchText: String
        @FocusState var isSearchFocused: Bool
        let scrollOffset: CGFloat

        // 滚动超过 20pt 时触发毛玻璃效果
        private var isScrolled: Bool {
            scrollOffset > 20
        }

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // 1. 标题"WhatToEat" + 红色圆点（Inverse Branding）
                    HStack(spacing: 2) {
                        // "What" - 60%白色
                        Text("What")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.6))
                        
                        // "ToEat" - 纯白高亮
                        Text("ToEat")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        // 红色圆点符号（赛博感）
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(y: 8)
                    }

                    // 2. 城市选择器 + 搜索框（黑夜中的微光）
                    HStack(spacing: 0) {
                        // 城市选择按钮
                        Button {
                            showCityPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedCity)
                                    .font(AppTheme.Fonts.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)  // 纯白文字
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.Colors.babyBlue)  // Baby Blue图标
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .frame(height: 20)
                            .background(Color.white.opacity(0.2))

                        // 搜索框
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.babyBlue)  // Baby Blue图标
                            TextField("", text: $searchText, prompt: Text("搜索餐厅...").foregroundColor(Color.white.opacity(0.5)))
                                .font(AppTheme.Fonts.footnote)
                                .foregroundColor(.white)  // 输入文字纯白
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .background(
                        // 使用纯色替代毛玻璃，避免灰色矩形问题
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.12))
                    )
                    // 发光描边
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    )
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: 10,
                        x: 0,
                        y: 3
                    )
                    .withFocusedInputEffects(isFocused: $isSearchFocused)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, AppTheme.Spacing.sm)
            }
            // Header 全透明背景
            .background(Color.clear)
        }
    }
    
    // MARK: - iOS 锁屏通知风格堆叠列表视图
    private struct StackedRestaurantListView: View {
        let filteredRestaurants: [Restaurant]
        let locationManager: LocationManager
        @Binding var navigationPath: NavigationPath
        @Binding var scrollOffset: CGFloat
        @State private var checkInRestaurant: Restaurant? = nil
        @State private var showCheckInSheet = false
        @State private var cardStates: [UUID: CardStackState] = [:]

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 8) { // 通知中心间距 8pt
                    ForEach(Array(filteredRestaurants.enumerated()), id: \.element.id) { index, restaurant in
                        StackedCardWrapper(
                            restaurant: restaurant,
                            locationManager: locationManager,
                            index: index,
                            cardStates: $cardStates,
                            onCheckInTap: {
                                checkInRestaurant = restaurant
                                showCheckInSheet = true
                            },
                            onNavigate: {
                                navigationPath.append(restaurant)
                            }
                        )
                        // 关键：越往后的卡片 ZIndex 越低，这样滚动时上方的卡片会压在下方的卡片之上
                        // 产生"钻入"感
                        .zIndex(Double(filteredRestaurants.count - index))
                        // scrollTransition: 向上滑出时平滑消融
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                        }
                    }
                }
                .padding(.bottom, 90)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                    }
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = -value
                }
            }
            .coordinateSpace(name: "scroll")
            .sheet(item: $checkInRestaurant) { restaurant in
                CheckInView(
                    restaurant: restaurant,
                    onClose: {
                        showCheckInSheet = false
                        checkInRestaurant = nil
                    }
                )
            }
        }
    }

    // MARK: - 卡片堆叠状态
    struct CardStackState {
        var scale: CGFloat = 1.0
        var offsetY: CGFloat = 0
        var opacity: CGFloat = 1.0
        var isStacked: Bool = false
    }

    // MARK: - 堆叠卡片包装器
    private struct StackedCardWrapper: View {
        let restaurant: Restaurant
        let locationManager: LocationManager
        let index: Int
        @Binding var cardStates: [UUID: CardStackState]
        let onCheckInTap: () -> Void
        let onNavigate: () -> Void

        @State private var cardGeometry: CGRect = .zero
        @State private var hasTriggeredHaptic = false

        private var stackState: CardStackState {
            cardStates[restaurant.id] ?? CardStackState()
        }

        var body: some View {
            GeometryReader { geo in
                StackedRestaurantCard(
                    restaurant: restaurant,
                    locationManager: locationManager,
                    index: index,
                    stackScale: stackState.scale,
                    isStacked: stackState.isStacked,
                    onCheckInTap: onCheckInTap,
                    onNavigate: onNavigate
                )
                .scaleEffect(stackState.scale, anchor: .bottom) // 向底部收缩，增加挤压感
                .offset(y: stackState.offsetY)
                .opacity(stackState.opacity)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: stackState.scale)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: stackState.offsetY)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: stackState.opacity)
                .onChange(of: geo.frame(in: .global)) { oldFrame, newFrame in
                    updateStackState(frame: newFrame)
                }
                .onAppear {
                    updateStackState(frame: geo.frame(in: .global))
                }
            }
            .frame(height: 140) // 固定卡片高度
        }

        private func updateStackState(frame: CGRect) {
            let screenHeight = UIScreen.main.bounds.height
            // 设定一个"堆叠基准线"，距离底部 120pt 的位置
            let stackBaseLine = screenHeight - 120
            let cardBottom = frame.maxY
            
            // 计算卡片底部超过基准线多少
            let distancePastBottom = cardBottom - stackBaseLine

            var newState = CardStackState()

            if distancePastBottom > 0 {
                // MARK: - 双阶段阈值逻辑
                
                // 1. 计算堆叠进度 (用于缩放和位移)
                // 0.0 -> 1.0 (在 0 到 80pt 之间完成)
                let stackProgress = min(distancePastBottom / 80, 1.0)
                
                // 2. 计算消失进度 (用于透明度)
                // 只有当距离超过 80pt 时才开始从 0 增长，到 130pt 时达到 1.0
                let fadeProgress = min(max(distancePastBottom - 80, 0) / 50, 1.0)
                
                // 应用参数
                newState.scale = 1.0 - (stackProgress * 0.1) // 缩放至 0.9
                newState.offsetY = -distancePastBottom * 0.95 // 强力粘滞位移
                newState.opacity = 1.0 - fadeProgress // 仅在消失期淡出
                
                newState.isStacked = stackProgress > 0.05
            } else {
                newState = CardStackState()
            }

            // 触感反馈：状态变化时触发
            if newState.isStacked != stackState.isStacked {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            
            cardStates[restaurant.id] = newState
        }
    }

    // MARK: - 滚动偏移 PreferenceKey
    struct ScrollOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
    
    // MARK: - 顶部 Header 子视图 (The Masthead) - 保留原实现供参考
    private struct HeaderView: View {
        let selectedCity: String
        @Binding var showCityPicker: Bool
        @Binding var searchText: String
        @FocusState var isSearchFocused: Bool

        var body: some View {
            HStack(spacing: 12) {
                // 1. 标题"吃啥呢"
                Text("吃啥呢")
                    .font(AppTheme.Fonts.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .tracking(2)

                // 2. 城市选择器 + 搜索框合并一行
                HStack(spacing: 0) {
                    // 城市选择按钮
                    Button {
                        showCityPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedCity)
                                .font(AppTheme.Fonts.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .frame(height: 20)
                        .background(Color.gray.opacity(0.2))

                    // 搜索框
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("搜索餐厅名称、菜系...", text: $searchText)
                            .font(AppTheme.Fonts.footnote)
                            .focused($isSearchFocused)
                            .submitLabel(.search)  // 键盘右下角显示"搜索"
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12) // 固定圆角 12
                        .fill(Color.black.opacity(0.03)) // 背景改为 Color.black.opacity(0.03)
                )
                .withFocusedInputEffects(isFocused: $isSearchFocused)
            }
            .padding(.horizontal, 24) // 与下方照片的最外侧对齐线保持一致
            .padding(.vertical, AppTheme.Spacing.sm)
        }
    }
    
    // MARK: - 排序选项枚举
enum SortOption: String, CaseIterable {
    case smart = "智能排序"
    case distance = "距离最近"
    case rating = "评分最高"
    case createdAt = "最近添加"
    
    /// 枚举值的显示名称
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - 筛选按钮栏子视图 (奥利奥黑白平衡)
private struct FilterBarView: View {
    let selectedCity: String
    @Binding var selectedDistrict: String?
    @Binding var selectedType: String?
    @Binding var sortOption: SortOption
    let restaurants: [Restaurant]
    let districts: [String]

    var body: some View {
        HStack(spacing: 12) {
            // 1. 地区筛选胶囊
            Menu {
                Button("全区") { selectedDistrict = nil }
                Divider()
                ForEach(districts, id: \.self) { district in
                    Button(district) { selectedDistrict = district }
                }
            } label: {
                filterCapsuleLabel(
                    title: selectedDistrict ?? "地区",
                    isSelected: selectedDistrict != nil
                )
            }

            // 2. 品类筛选胶囊
            Menu {
                Button("全部分类") { selectedType = nil }
                Divider()
                ForEach(CategoryManager.shared.getAllCategories(from: restaurants), id: \.self) { type in
                    Button(type) { selectedType = type }
                }
            } label: {
                filterCapsuleLabel(
                    title: selectedType ?? "品类",
                    isSelected: selectedType != nil
                )
            }

            // 3. 排序筛选胶囊
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(option.displayName) { sortOption = option }
                }
            } label: {
                filterCapsuleLabel(
                    title: sortOption.displayName,
                    isSelected: false
                )
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    // MARK: - 筛选胶囊标签（方案A：反转高亮 - 黑底白字）
    private func filterCapsuleLabel(title: String, isSelected: Bool) -> some View {
        // 截断文本：超过4个字显示省略号
        let displayTitle = title.count > 4 ? String(title.prefix(3)) + "…" : title
        
        return HStack(spacing: 4) {
            Text(displayTitle)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                // 未选中：深黑文字 | 选中：白色文字
                .foregroundColor(isSelected ? .white : Color(hex: "#1A1A1A"))
                // 固定宽度和高度，不随内容变化
                .frame(width: 52, height: 18, alignment: .center)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
                // 未选中：Baby Blue | 选中：白色
                .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.Colors.babyBlue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                // 未选中：纯白实色 | 选中：纯黑实色
                .fill(isSelected ? Color.black : Color.white)
        )
        // 轻微阴影增加悬浮感
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 6,
            x: 0,
            y: 3
        )
    }
}
    
    // MARK: - 辅助方法
    
    /// 计算两个位置之间的直线距离
    private func calculateDistance(from: CLLocation?, to restaurant: Restaurant) -> Double {
        guard let fromLocation = from else {
            return 0
        }
        
        let toLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// 计算智能排序得分
    /// - Parameters:
    ///   - distance: 距离（米）
    ///   - rating: 评分
    ///   - createdAt: 创建时间
    /// - Returns: 智能排序得分
    private func calculateSmartScore(distance: Double, rating: Double, createdAt: Date) -> Double {
        var score: Double = 0.0
        
        // 因子 A：评分权重 (40%)
        let ratingScore = rating * 20.0
        score += ratingScore * 0.4
        
        // 因子 B：距离权重 (40%)
        // 检查是否有定位权限且userLocation不为空
        if locationManager.userLocation != nil {
            let distanceInKilometers = distance / 1000 // 转换为公里
            let distanceScore = max(0.0, 100.0 - (distanceInKilometers * 10))
            score += distanceScore * 0.4
        }
        
        // 因子 C：新鲜度权重 (20%)
        // 检查是否是最近7天内创建的记录
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        if createdAt >= sevenDaysAgo {
            score += 20.0 // 最近7天内创建，加20分
        }
        
        return score
    }
    
    /// 过滤和排序后的餐厅列表
    private var filteredRestaurants: [Restaurant] {
        var result = restaurants.filter { restaurant in
            guard restaurant.modelContext != nil else {
                return false
            }
            
            guard restaurant.city == selectedCity else {
                return false
            }
            
            if let district = selectedDistrict {
                guard restaurant.district == district else {
                    return false
                }
            }
            
            if let type = selectedType {
                guard restaurant.type == type else {
                    return false
                }
            }
            
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                return restaurant.name.lowercased().contains(searchLower) ||
                       restaurant.type.lowercased().contains(searchLower) ||
                       restaurant.tags.contains { $0.lowercased().contains(searchLower) }
            }
            
            return true
        }
        
        let userLocation = locationManager.userLocation
        result = result.sorted { restaurant1, restaurant2 in
            let (distance1, rating1, createdAt1) = (
                calculateDistance(from: userLocation, to: restaurant1),
                restaurant1.rating,
                restaurant1.createdAt
            )
            let (distance2, rating2, createdAt2) = (
                calculateDistance(from: userLocation, to: restaurant2),
                restaurant2.rating,
                restaurant2.createdAt
            )
            
            switch sortOption {
            case .smart:
                let score1 = calculateSmartScore(distance: distance1, rating: rating1, createdAt: createdAt1)
                let score2 = calculateSmartScore(distance: distance2, rating: rating2, createdAt: createdAt2)
                return score1 > score2
            case .distance:
                return distance1 < distance2
            case .rating:
                return rating1 > rating2
            case .createdAt:
                return createdAt1 > createdAt2
            }
        }
        
        return result
    }
    
    // MARK: - 餐厅列表子视图（Navigation版）
private struct RestaurantListView: View {
    let filteredRestaurants: [Restaurant]
    let locationManager: LocationManager
    @Binding var navigationPath: NavigationPath
    @State private var checkInRestaurant: Restaurant? = nil
    @State private var showCheckInSheet = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) { // 去边界化：使用 0 间距，由卡片内部控制留白
                if filteredRestaurants.isEmpty {
                    // Oreo: 情感化空状态
                    EmptyStateView(
                        icon: "fork.knife.circle",
                        message: "还没留下你的美食足迹",
                        submessage: "点击右下角 + 号，记录第一家餐厅"
                    )
                    .padding(.top, 100)
                } else {
                    ForEach(Array(filteredRestaurants.enumerated()), id: \.element.id) { index, restaurant in
                        // 使用 ZStack 叠加 NavigationLink 和打卡按钮
                        ZStack {
                            // 底层：导航到详情页
                            NavigationLink(value: restaurant) {
                                RestaurantCard(
                                    restaurant: restaurant,
                                    locationManager: locationManager,
                                    isExpanded: false,
                                    index: index,
                                    onCheckInTap: {
                                        // 打卡快捷入口：弹出 CheckInView
                                        checkInRestaurant = restaurant
                                        showCheckInSheet = true
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.bottom, 90)
        }
        // 打卡弹窗
        .sheet(item: $checkInRestaurant) { restaurant in
            CheckInView(
                restaurant: restaurant,
                onClose: {
                    showCheckInSheet = false
                    checkInRestaurant = nil
                }
            )
        }
    }
}

// MARK: - Oreo: 情感化空状态组件
struct EmptyStateView: View {
    let icon: String
    let message: String
    let submessage: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppTheme.Colors.babyBlue)
            
            Text(message)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .tracking(0.5)
            
            Text(submessage)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}


}

