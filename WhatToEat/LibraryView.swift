import SwiftUI
import SwiftData
import MapKit

// MARK: - 通知名称扩展
extension Notification.Name {
    static let restaurantListShouldRefresh = Notification.Name("restaurantListShouldRefresh")
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
    
    // 动画命名空间（用于英雄动画）
    @Namespace private var animation
    
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
            _selectedCity = State(initialValue: "上海")
        }
    }
    
    private var currentDistricts: [String] {
        RegionManager.shared.getDistricts(for: selectedCity)
    }
    
    // MARK: - 生命周期
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "#FBF9F7")
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                HeaderView(
                    selectedCity: selectedCity,
                    showCityPicker: $showCityPicker,
                    searchText: $searchText,
                    isSearchFocused: _isSearchFocused
                )
                FilterBarView(
                    selectedCity: selectedCity,
                    selectedDistrict: $selectedDistrict,
                    selectedType: $selectedType,
                    sortOption: $sortOption,
                    restaurants: restaurants,
                    districts: currentDistricts
                )
                RestaurantListView(
                    filteredRestaurants: filteredRestaurants,
                    locationManager: locationManager,
                    animation: animation,
                    selectedRestaurant: $selectedRestaurant,
                    isDetailPresented: $isDetailPresented
                )
            }
        }
        .fullScreenCover(isPresented: $isDetailPresented) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    locationManager: locationManager,
                    isPresented: $isDetailPresented
                )
            }
        }
        .onChange(of: isDetailPresented) { _, newValue in
            if !newValue && !isAnimatingOut {
                isAnimatingOut = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.72)) {
                        selectedRestaurant = nil
                    }
                    isAnimatingOut = false
                }
            }
            isTabBarHidden = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .restoreTabBar)) { _ in
            isTabBarHidden = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .restaurantListShouldRefresh)) { _ in
            // 收到刷新通知时，强制刷新 @Query
            // SwiftData 的 @Query 会自动响应上下文变化，此处仅作日志
            print("RestaurantListRefresh: 收到刷新通知")
        }
        .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
        .sheet(isPresented: $showImportSheet) { ImportDataView() }
        .sheet(isPresented: $showCityPicker) {
            CitySelectionView(selectedCity: $selectedCity)
        }
        .onChange(of: selectedCity) {
            UserDefaults.standard.set($0, forKey: kSavedCityKey)
        }
    }
    
    // MARK: - 顶部 Header 子视图
private struct HeaderView: View {
    let selectedCity: String
    @Binding var showCityPicker: Bool
    @Binding var searchText: String
    @FocusState var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // 1. 标题"吃啥呢"
            Text("吃啥呢")
                .font(AppTheme.Fonts.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#443F3B")) // 比textPrimary稍浅的磨砂黑，增加呼吸感
                .tracking(2) // 增加字体间距
            
            // 2. 城市选择器
            Button {
                showCityPicker = true
            } label: {
                HStack {
                    Text(selectedCity)
                        .font(AppTheme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // 3. 搜索框（占据剩余空间）
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("搜索餐厅名称、菜系...", text: $searchText)
                    .font(AppTheme.Fonts.footnote)
                    .focused($isSearchFocused) // ✅ 绑定焦点状态
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            // 使用统一的输入框焦点效果修饰符
            .withFocusedInputEffects(isFocused: $isSearchFocused)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(Color(hex: "#FBF9F7")) // 与全局背景色保持一致
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

// MARK: - 筛选按钮栏子视图
private struct FilterBarView: View {
    let selectedCity: String
    @Binding var selectedDistrict: String?
    @Binding var selectedType: String?
    @Binding var sortOption: SortOption
    let restaurants: [Restaurant]
    let districts: [String]
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 地区筛选
            Menu {
                // 全区选项
                Button("全区") { selectedDistrict = nil }
                Divider()
                // 动态获取当前城市的区列表
                ForEach(districts, id: \.self) { district in
                    Button(district) { selectedDistrict = district }
                }
            } label: {
                HStack {
                    Text(selectedDistrict ?? "地区")
                        .font(AppTheme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .fill(AppTheme.Colors.card)
                        .shadow(
                            color: Color.black.opacity(0.05), 
                            radius: 5, 
                            x: 0, 
                            y: 2
                        )
                )
            }
            .buttonStyle(.plain)
            
            // 2. 分类筛选
            Menu {
                // 全部分类选项
                Button("全部分类") { selectedType = nil }
                Divider()
                // 动态获取所有餐厅类型
                ForEach(CategoryManager.shared.getAllCategories(from: restaurants), id: \.self) { type in
                    Button(type) { selectedType = type }
                }
            } label: {
                HStack {
                    Text(selectedType ?? "品类")
                        .font(AppTheme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .fill(AppTheme.Colors.card)
                        .shadow(
                            color: Color.black.opacity(0.05), 
                            radius: 5, 
                            x: 0, 
                            y: 2
                        )
                )
            }
            .buttonStyle(.plain)
            
            // 3. 排序切换
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(option.displayName) { sortOption = option }
                }
            } label: {
                HStack {
                    Text(sortOption.displayName)
                        .font(AppTheme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .fill(AppTheme.Colors.card)
                        .shadow(
                            color: Color.black.opacity(0.05), 
                            radius: 5, 
                            x: 0, 
                            y: 2
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.xs) // 与搜索框的最小间距
        .padding(.bottom, AppTheme.Spacing.md)
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
    
    // MARK: - 餐厅列表子视图
private struct RestaurantListView: View {
    let filteredRestaurants: [Restaurant]
    let locationManager: LocationManager
    let animation: Namespace.ID
    @Binding var selectedRestaurant: Restaurant?
    @Binding var isDetailPresented: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.lg) {
                ForEach(filteredRestaurants) { restaurant in
                    RestaurantCard(
                        restaurant: restaurant,
                        locationManager: locationManager,
                        animation: animation,
                        isExpanded: selectedRestaurant?.id == restaurant.id
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            if selectedRestaurant?.id == restaurant.id {
                                selectedRestaurant = nil
                                isDetailPresented = false
                            } else {
                                selectedRestaurant = restaurant
                                isDetailPresented = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, 90)
        }
    }
}


}


