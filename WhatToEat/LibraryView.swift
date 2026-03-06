import SwiftUI
import SwiftData
import MapKit
import Combine

// MARK: - 通知名称扩展
extension Notification.Name {
    static let restaurantListShouldRefresh = Notification.Name("restaurantListShouldRefresh")
    static let hideTabBar = Notification.Name("hideTabBar")
    static let restoreTabBar = Notification.Name("restoreTabBar")
}

// MARK: - 1. 核心视图
struct LibraryView: View {
    @Environment(\.colorScheme) private var colorScheme
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
    private let kSavedCityKey = AppSettingsKeys.userSelectedCity
    private let kSavedSortOptionKey = AppSettingsKeys.libraryDefaultSortOption
    

    
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

        if let savedSortRaw = UserDefaults.standard.string(forKey: kSavedSortOptionKey),
           let savedSort = SortOption(rawValue: savedSortRaw) {
            _sortOption = State(initialValue: savedSort)
        } else {
            _sortOption = State(initialValue: .smart)
        }
    }
    
    private var currentDistricts: [String] {
        RegionManager.shared.getDistricts(for: selectedCity)
    }
    
    // MARK: - Navigation路径
    @State private var navigationPath = NavigationPath()
    
    // MARK: - 生命周期
    @State private var scrollOffset: CGFloat = 0
    @State private var filteredRestaurantsCache: [Restaurant] = []
    @State private var selectableCategories: [String] = []
    @State private var activeFilterDropdown: FilterDropdownType?
    @State private var filterButtonFrames: [FilterDropdownType: CGRect] = [:]
    @State private var libraryRootGlobalFrame: CGRect = .zero
    @State private var isRepairingCityAssignments = false

    private let dropdownSpring = Animation.spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.08)
    private let listRefreshSpring = Animation.spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.12)
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topLeading) {
                // 最底层：复用 Profile 的弥散底色
                DiffuseGradientBackground()
                    .ignoresSafeArea()
                
                // 顶部增强层：仅保留轻量层级，避免与全局弥散冲突
                LiquidDarkHeaderBackground()
                    .opacity(colorScheme == .dark ? 0.24 : 1.0)
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
                        categories: selectableCategories,
                        districts: currentDistricts,
                        activeDropdown: activeFilterDropdown,
                        onToggleDropdown: { dropdown in
                            let generator = UIImpactFeedbackGenerator(style: .soft)
                            generator.impactOccurred()
                            withAnimation(dropdownSpring) {
                                activeFilterDropdown = activeFilterDropdown == dropdown ? nil : dropdown
                            }
                        },
                        onButtonFrameChange: { dropdown, frame in
                            filterButtonFrames[dropdown] = frame
                        }
                    )
                    .zIndex(120)
                    
                    StackedRestaurantListView(
                        filteredRestaurants: filteredRestaurantsCache,
                        locationManager: locationManager,
                        navigationPath: $navigationPath,
                        scrollOffset: $scrollOffset,
                        refreshAnimation: listRefreshSpring
                    )
                }

                if let dropdown = activeFilterDropdown {
                    filterDropdownOverlay(for: dropdown)
                        .zIndex(260)
                        .transition(
                            .asymmetric(
                                insertion: .offset(y: -8).combined(with: .opacity).combined(with: .scale(scale: 0.94, anchor: .topLeading)),
                                removal: .offset(y: -4).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .topLeading))
                            )
                        )
                }
            }
            .animation(dropdownSpring, value: activeFilterDropdown)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            libraryRootGlobalFrame = proxy.frame(in: .global)
                        }
                        .onChange(of: proxy.frame(in: .global)) { _, newValue in
                            libraryRootGlobalFrame = newValue
                        }
                }
            )
            .navigationDestination(for: Restaurant.self) { restaurant in
                RestaurantDetailView(
                    restaurant: restaurant,
                    locationManager: locationManager,
                    navigationPath: $navigationPath
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .restaurantListShouldRefresh)) { _ in
                if let savedCity = UserDefaults.standard.string(forKey: kSavedCityKey) {
                    selectedCity = savedCity
                }
            }
            .onAppear {
                repairRestaurantCityAssignmentsIfNeeded()
            }
            .toolbar(.visible, for: .tabBar)
            .sheet(isPresented: $showImportSheet) { ImportDataView() }
            .sheet(isPresented: $showCityPicker) {
                CitySelectionView(selectedCity: $selectedCity)
            }
            .onChange(of: selectedCity) { _, newCity in
                UserDefaults.standard.set(newCity, forKey: kSavedCityKey)
                refreshFilteredRestaurants(animated: true)
            }
            .onChange(of: restaurants, initial: true) { _, _ in
                // 启动首帧直接完成筛选与排序，避免首屏列表短暂出现错误顺序
                repairRestaurantCityAssignmentsIfNeeded()
                refreshDerivedData(animated: false)
            }
            .onChange(of: selectedDistrict) { _, _ in
                activeFilterDropdown = nil
                refreshFilteredRestaurants(animated: true)
            }
            .onChange(of: selectedType) { _, _ in
                activeFilterDropdown = nil
                refreshFilteredRestaurants(animated: true)
            }
            .onChange(of: searchText) { _, _ in
                refreshFilteredRestaurants(animated: true)
            }
            .onChange(of: sortOption) { _, _ in
                activeFilterDropdown = nil
                UserDefaults.standard.set(sortOption.rawValue, forKey: kSavedSortOptionKey)
                refreshFilteredRestaurants(animated: true)
            }
            .onReceive(
                locationManager.$userLocation
                    .removeDuplicates(by: { lhs, rhs in
                        switch (lhs, rhs) {
                        case (nil, nil):
                            return true
                        case let (left?, right?):
                            return left.distance(from: right) < 25
                        default:
                            return false
                        }
                    })
                    .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            ) { _ in
                if sortOption == .smart || sortOption == .distance {
                    refreshFilteredRestaurants(animated: false)
                }
            }
            // 状态栏适配由全局主题控制（system/light/dark）
        }
    }

    private func repairRestaurantCityAssignmentsIfNeeded() {
        guard !isRepairingCityAssignments else { return }
        guard !restaurants.isEmpty else { return }

        isRepairingCityAssignments = true
        defer { isRepairingCityAssignments = false }

        var changed = false

        for restaurant in restaurants {
            guard restaurant.modelContext != nil else { continue }

            let normalized = RestaurantCityNormalizer.normalize(
                address: restaurant.address,
                district: restaurant.district,
                fallbackCity: restaurant.city
            )

            if restaurant.city != normalized.city {
                restaurant.city = normalized.city
                changed = true
            }

            if !normalized.district.isEmpty, restaurant.district != normalized.district {
                restaurant.district = normalized.district
                changed = true
            }
        }

        guard changed else { return }

        do {
            try modelContext.save()
        } catch {
            print("修复城市归属失败: \(error.localizedDescription)")
        }
    }

    private struct FilterDropdownRow: Identifiable {
        let id: String
        let title: String
        let isSelected: Bool
        let isDestructive: Bool
        let action: () -> Void
    }

    @ViewBuilder
    private func filterDropdownOverlay(for dropdown: FilterDropdownType) -> some View {
        GeometryReader { proxy in
            let panelWidth = min(max(proxy.size.width * 0.48, 190), 280)
            let panelMaxHeight = min(max(proxy.size.height * 0.34, 180), 340)
            let baseFrame = filterButtonFrames[dropdown] ?? .zero
            let rawX = baseFrame.midX - libraryRootGlobalFrame.minX - panelWidth / 2
            let panelX = min(max(rawX, 24), max(24, proxy.size.width - panelWidth - 24))
            let panelY = max(0, baseFrame.maxY - libraryRootGlobalFrame.minY + 8)

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(dropdownSpring) {
                            activeFilterDropdown = nil
                        }
                    }

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 2) {
                            ForEach(filterDropdownRows(for: dropdown)) { row in
                                Button {
                                    row.action()
                                    withAnimation(dropdownSpring) {
                                        activeFilterDropdown = nil
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(row.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(row.isDestructive ? AppTheme.Colors.destructive : AppTheme.Colors.darkText)
                                            .lineLimit(1)
                                        Spacer(minLength: 4)
                                        if row.isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(AppTheme.Colors.babyBlue)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(row.isSelected ? AppTheme.Colors.babyBlue.opacity(colorScheme == .dark ? 0.14 : 0.09) : .clear)
                                )
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: panelMaxHeight)
                }
                .frame(width: panelWidth)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.Colors.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppTheme.Colors.rimLight.opacity(colorScheme == .dark ? 0.12 : 0.2), lineWidth: 0.6)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.Colors.headerPillBorder.opacity(colorScheme == .dark ? 0.7 : 0.85), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 20, x: 0, y: 12)
                .offset(x: panelX, y: panelY)
            }
        }
    }

    private func filterDropdownRows(for dropdown: FilterDropdownType) -> [FilterDropdownRow] {
        switch dropdown {
        case .district:
            let allRow = FilterDropdownRow(
                id: "district_all",
                title: "全区",
                isSelected: selectedDistrict == nil,
                isDestructive: false
            ) {
                selectedDistrict = nil
            }
            let districtRows = currentDistricts.map { district in
                FilterDropdownRow(
                    id: "district_\(district)",
                    title: district,
                    isSelected: selectedDistrict == district,
                    isDestructive: false
                ) {
                    selectedDistrict = district
                }
            }
            return [allRow] + districtRows
        case .category:
            let allRow = FilterDropdownRow(
                id: "type_all",
                title: "全部分类",
                isSelected: selectedType == nil,
                isDestructive: false
            ) {
                selectedType = nil
            }
            let categoryRows = selectableCategories.map { type in
                FilterDropdownRow(
                    id: "type_\(type)",
                    title: type,
                    isSelected: selectedType == type,
                    isDestructive: false
                ) {
                    selectedType = type
                }
            }
            return [allRow] + categoryRows
        case .sort:
            return SortOption.allCases.map { option in
                FilterDropdownRow(
                    id: "sort_\(option.rawValue)",
                    title: option.displayName,
                    isSelected: sortOption == option,
                    isDestructive: false
                ) {
                    sortOption = option
                }
            }
        }
    }

    // MARK: - 动态毛玻璃导航条 (适配深色流体背景)
    private struct DynamicHeaderView: View {
        @Environment(\.colorScheme) private var colorScheme
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
                            .foregroundColor(AppTheme.Colors.mediumGray)
                        
                        // "ToEat" - 纯白高亮
                        Text("ToEat")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? AppTheme.Colors.darkText : AppTheme.Colors.textPrimary)
                        
                        // 红色圆点符号（赛博感）
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(y: 8)
                    }

                    // 2. 城市选择器 + 搜索框（参考图样式：圆角胶囊组合）
                    HStack(spacing: 0) {
                        // 城市选择按钮
                        Button {
                            showCityPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedCity)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.darkText)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.Colors.babyBlue)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        
                        // 垂直分隔线
                        Rectangle()
                            .fill(AppTheme.Colors.headerPillBorder)
                            .frame(width: 1, height: 20)
                        
                        // 搜索框
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.babyBlue)
                            
                            TextField("", text: $searchText, prompt: Text("搜索餐厅...").foregroundColor(AppTheme.Colors.lightText))
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.darkText)
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .background(
                        // 深色背景 + 高亮边框（参考图样式）
                        Capsule()
                            .fill(AppTheme.Colors.headerPillBackground)
                    )
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.Colors.headerPillBorder, lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.1),
                        radius: 8,
                        x: 0,
                        y: 2
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
        let refreshAnimation: Animation
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
                        .transition(
                            .asymmetric(
                                insertion: .offset(y: 14).combined(with: .opacity).combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 0.97))
                            )
                        )
                    }
                }
                .animation(refreshAnimation, value: filteredRestaurants.map(\.id))
                // 底部内边距：为导航条留出空间（减少间距让卡片更靠近导航栏）
                .padding(.bottom, 20)
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
    struct CardStackState: Equatable {
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

        @State private var lastFrameMinY: CGFloat = .nan
        @State private var hasInitializedStackState = false
        // 延迟初始化标志，避免首次加载时的跳动
        @State private var shouldApplyStackEffect = false

        private var stackState: CardStackState {
            cardStates[restaurant.id] ?? CardStackState()
        }

        var body: some View {
            GeometryReader { geo in
                StackedRestaurantCard(
                    restaurant: restaurant,
                    locationManager: locationManager,
                    index: index,
                    stackScale: shouldApplyStackEffect ? stackState.scale : 1.0,
                    isStacked: shouldApplyStackEffect ? stackState.isStacked : false,
                    onCheckInTap: onCheckInTap,
                    onNavigate: onNavigate
                )
                .scaleEffect(shouldApplyStackEffect ? stackState.scale : 1.0, anchor: .bottom)
                .offset(y: shouldApplyStackEffect ? stackState.offsetY : 0)
                .opacity(shouldApplyStackEffect ? stackState.opacity : 1.0)
                .animation(
                    shouldApplyStackEffect
                        ? .interactiveSpring(response: 0.3, dampingFraction: 0.8)
                        : nil,
                    value: stackState
                )
                .onChange(of: geo.frame(in: .global)) { oldFrame, newFrame in
                    // 降低高频几何回调带来的状态写入和重排压力
                    guard lastFrameMinY.isNaN || abs(newFrame.minY - lastFrameMinY) > 0.8 else { return }
                    lastFrameMinY = newFrame.minY
                    updateStackState(frame: newFrame)
                }
                .onAppear {
                    lastFrameMinY = geo.frame(in: .global).minY
                    // 延迟启用堆叠效果，避免初始跳动
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shouldApplyStackEffect = true
                        updateStackState(frame: geo.frame(in: .global))
                    }
                }
            }
            .frame(height: 140) // 固定卡片高度
        }

        @State private var lastStackState: Bool = false
        
        private func updateStackState(frame: CGRect) {
            let screenHeight = ScreenMetrics.bounds.height
            // 设定一个"堆叠基准线"，距离底部 80pt 的位置（更靠近导航栏）
            let stackBaseLine = screenHeight - 80
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
            
            // 震动反馈：当卡片进入或退出堆叠状态时触发
            if newState.isStacked != lastStackState {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
                lastStackState = newState.isStacked
            }

            // 首次布局阶段禁用动画，避免初始“跳动一下”
            if !hasInitializedStackState {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    cardStates[restaurant.id] = newState
                }
                hasInitializedStackState = true
                return
            }

            if isApproximatelyEqual(stackState, newState) {
                return
            }

            cardStates[restaurant.id] = newState
        }

        private func isApproximatelyEqual(_ lhs: CardStackState, _ rhs: CardStackState) -> Bool {
            abs(lhs.scale - rhs.scale) < 0.001 &&
            abs(lhs.offsetY - rhs.offsetY) < 0.5 &&
            abs(lhs.opacity - rhs.opacity) < 0.01 &&
            lhs.isStacked == rhs.isStacked
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
                                .foregroundColor(AppTheme.Colors.mediumGray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .frame(height: 20)
                        .background(AppTheme.Colors.headerPillBorder.opacity(0.6))

                    // 搜索框
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.mediumGray)
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
                        .fill(AppTheme.Colors.surfaceSecondary)
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

private enum FilterDropdownType: Hashable {
    case district
    case category
    case sort
}

private struct FilterButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: [FilterDropdownType: CGRect] = [:]

    static func reduce(value: inout [FilterDropdownType: CGRect], nextValue: () -> [FilterDropdownType: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - 筛选按钮栏子视图 (奥利奥黑白平衡)
private struct FilterBarView: View {
    let selectedCity: String
    @Binding var selectedDistrict: String?
    @Binding var selectedType: String?
    @Binding var sortOption: SortOption
    let categories: [String]
    let districts: [String]
    let activeDropdown: FilterDropdownType?
    let onToggleDropdown: (FilterDropdownType) -> Void
    let onButtonFrameChange: (FilterDropdownType, CGRect) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 1. 地区筛选胶囊
            Button {
                onToggleDropdown(.district)
            } label: {
                filterCapsuleLabel(
                    title: selectedDistrict ?? "地区",
                    isSelected: selectedDistrict != nil,
                    isExpanded: activeDropdown == .district
                )
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FilterButtonFramePreferenceKey.self,
                        value: [.district: proxy.frame(in: .global)]
                    )
                }
            )

            // 2. 品类筛选胶囊（使用统一的品类管理，包含用户自定义品类）
            Button {
                onToggleDropdown(.category)
            } label: {
                filterCapsuleLabel(
                    title: selectedType ?? "品类",
                    isSelected: selectedType != nil,
                    isExpanded: activeDropdown == .category
                )
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FilterButtonFramePreferenceKey.self,
                        value: [.category: proxy.frame(in: .global)]
                    )
                }
            )

            // 3. 排序筛选胶囊
            Button {
                onToggleDropdown(.sort)
            } label: {
                filterCapsuleLabel(
                    title: sortOption.displayName,
                    isSelected: false,
                    isExpanded: activeDropdown == .sort
                )
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FilterButtonFramePreferenceKey.self,
                        value: [.sort: proxy.frame(in: .global)]
                    )
                }
            )

            // 4. 清除筛选按钮（有筛选条件时显示）
            if selectedDistrict != nil || selectedType != nil {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()

                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDistrict = nil
                        selectedType = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.Colors.surfacePrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.Colors.headerPillBorder.opacity(0.85), lineWidth: 0.8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.Colors.rimLight.opacity(0.12), lineWidth: 0.6)
                                )
                        )
                }
                .buttonStyle(LiquidFusionButtonStyle())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .scale(scale: 0.5).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedDistrict)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedType)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .onPreferenceChange(FilterButtonFramePreferenceKey.self) { newValue in
            for (key, frame) in newValue {
                onButtonFrameChange(key, frame)
            }
        }
    }

    // MARK: - 筛选胶囊标签（与餐厅卡片样式一致）
    private func filterCapsuleLabel(title: String, isSelected: Bool, isExpanded: Bool) -> some View {
        // 截断文本：超过4个字显示省略号
        let displayTitle = title.count > 4 ? String(title.prefix(3)) + "…" : title

        return HStack(spacing: 4) {
            Text(displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Colors.darkText)
                .frame(width: 52, height: 18, alignment: .center)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .foregroundColor(isSelected ? AppTheme.Colors.babyBlue : AppTheme.Colors.mediumGray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // 与餐厅卡片一致的背景
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.surfacePrimary)
        )
        // 与餐厅卡片一致的双层描边
        .overlay(
            ZStack {
                // 内层：白色高光描边
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.rimLight.opacity(0.16), lineWidth: 0.5)
                // 外层：极淡黑色物理边框
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
            }
        )
        // 与餐厅卡片一致的阴影
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
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
    
    private func refreshDerivedData(animated: Bool = true) {
        refreshSelectableCategories()
        refreshFilteredRestaurants(animated: animated)
    }

    private func refreshSelectableCategories() {
        selectableCategories = CategoryManager.shared.getSelectableCategories(
            context: modelContext,
            restaurants: restaurants
        )
    }

    private func refreshFilteredRestaurants(animated: Bool = true) {
        let newValue = computeFilteredRestaurants(from: restaurants)
        let oldIDs = filteredRestaurantsCache.map(\.id)
        let newIDs = newValue.map(\.id)

        guard oldIDs != newIDs else {
            filteredRestaurantsCache = newValue
            return
        }

        if animated {
            withAnimation(listRefreshSpring) {
                filteredRestaurantsCache = newValue
            }
        } else {
            filteredRestaurantsCache = newValue
        }
    }

    /// 过滤和排序后的餐厅列表
    private func computeFilteredRestaurants(from source: [Restaurant]) -> [Restaurant] {
        var result = source.filter { restaurant in
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
                if abs(score1 - score2) > 0.001 {
                    return score1 > score2
                }
                if abs(distance1 - distance2) > 1 {
                    return distance1 < distance2
                }
                if abs(rating1 - rating2) > 0.001 {
                    return rating1 > rating2
                }
                if createdAt1 != createdAt2 {
                    return createdAt1 > createdAt2
                }
                return restaurant1.id.uuidString < restaurant2.id.uuidString
            case .distance:
                if abs(distance1 - distance2) > 1 {
                    return distance1 < distance2
                }
                if abs(rating1 - rating2) > 0.001 {
                    return rating1 > rating2
                }
                if createdAt1 != createdAt2 {
                    return createdAt1 > createdAt2
                }
                return restaurant1.id.uuidString < restaurant2.id.uuidString
            case .rating:
                if abs(rating1 - rating2) > 0.001 {
                    return rating1 > rating2
                }
                if createdAt1 != createdAt2 {
                    return createdAt1 > createdAt2
                }
                return restaurant1.id.uuidString < restaurant2.id.uuidString
            case .createdAt:
                if createdAt1 != createdAt2 {
                    return createdAt1 > createdAt2
                }
                if abs(rating1 - rating2) > 0.001 {
                    return rating1 > rating2
                }
                return restaurant1.id.uuidString < restaurant2.id.uuidString
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
                        .padding(.horizontal, 16)  // 卡片与屏幕边缘间距
                        .padding(.vertical, 6)     // 卡片之间间距，营造呼吸感
                    }
                }
            }
            // 底部内边距：为导航条留出空间（减少间距让卡片更靠近导航栏）
            .padding(.bottom, 20)
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
