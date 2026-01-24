import SwiftUI
import SwiftData
import MapKit

// MARK: - 1. 核心视图
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    
    // 状态管理
    @State private var showImportSheet = false
    @State private var showCityPicker = false
    @FocusState private var isSearchFocused: Bool // ✅ 专门监听搜索框是否被点中
    
    @StateObject private var locationManager = LocationManager.shared
    
    // 筛选和排序状态
    @State private var selectedCity: String
    @State private var selectedDistrict: String?
    @State private var selectedType: String?
    @State private var searchText = ""
    
    // 排序选项枚举
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
    
    @State private var sortOption: SortOption = .smart
    
    // 城市存储键
    private let kSavedCityKey = "UserSelectedCity"
    
    // 初始化方法
    init() {
        // 从UserDefaults加载保存的城市，默认使用"上海"
        if let savedCity = UserDefaults.standard.string(forKey: kSavedCityKey) {
            _selectedCity = State(initialValue: savedCity)
        } else {
            _selectedCity = State(initialValue: "上海")
        }
    }
    
    // MARK: - 生命周期
    var body: some View {
        NavigationStack {
            // ✅ 使用 topLeading，这是所有像素级对齐的基准
            ZStack(alignment: .topLeading) {
                // 背景层，用于捕获空白区域点击
                Color.clear
                    .onTapOutsideHideKeyboard()
                    
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    filterBarSection
                    listSection
                }
                .background(Color(hex: "#FBF9F7")) // 极淡的米白色背景，衬托纯白色卡片和半透明组件
            }
            .sheet(isPresented: $showImportSheet) { ImportDataView() }
            // 城市选择器
            .sheet(isPresented: $showCityPicker) {
                CitySelectionView(selectedCity: $selectedCity)
            }
            // 导航目标配置
            .navigationDestination(for: Restaurant.self) {
                RestaurantDetailView(restaurant: $0, locationManager: locationManager)
            }
            // 当城市变化时，保存到UserDefaults
            .onChange(of: selectedCity) {
                UserDefaults.standard.set($0, forKey: kSavedCityKey)
            }
        }
    }
    
    // MARK: - 顶部 Header (整合标题、搜索框和地图图标)
    private var headerSection: some View {
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
    
    // MARK: - 筛选按钮栏
    private var filterBarSection: some View {
        HStack(spacing: 12) {
            // 1. 地区筛选
            Menu {
                // 全区选项
                Button("全区") { selectedDistrict = nil }
                Divider()
                // 动态获取当前城市的区列表
                ForEach(RegionManager.shared.getDistricts(for: selectedCity), id: \.self) { district in
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
    private func calculateSmartScore(distance: Double, rating: Int, createdAt: Date) -> Double {
        var score: Double = 0.0
        
        // 因子 A：评分权重 (40%)
        let ratingScore = Double(rating) * 20.0
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
        // 1. 过滤餐厅
        var result = restaurants.filter { restaurant in
            // 🛑 核心修复：防止访问尚未就绪的对象
            guard restaurant.modelContext != nil else { return false }
            
            // 按城市过滤
            guard restaurant.city == selectedCity else {
                return false
            }
            
            // 按行政区过滤（可选）
            if let district = selectedDistrict {
                guard restaurant.district == district else {
                    return false
                }
            }
            
            // 按餐厅类型过滤（可选）
            if let type = selectedType {
                guard restaurant.type == type else {
                    return false
                }
            }
            
            // 按搜索文本过滤
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                return restaurant.name.lowercased().contains(searchLower) || 
                       restaurant.type.lowercased().contains(searchLower) ||
                       restaurant.tags.contains { $0.lowercased().contains(searchLower) }
            }
            
            return true
        }
        
        // 2. 排序餐厅
        // 确保所有打分在过滤之后、渲染之前一次性完成
        let userLocation = locationManager.userLocation
        result = result.sorted { restaurant1, restaurant2 in
            // 提前读取所有需要的属性，避免在排序过程中重复访问SwiftData
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
                // 智能排序得分计算
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
    
    // MARK: - 餐厅列表
    private var listSection: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.lg) {
                ForEach(filteredRestaurants) { restaurant in
                    // 使用 NavigationLink 包装卡片，value 传入餐厅对象
                    NavigationLink(value: restaurant) {
                        RestaurantCard(restaurant: restaurant, locationManager: locationManager)
                    }
                    .buttonStyle(.plain) // 💡 关键：防止原生按钮样式破坏卡片视觉
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg) // 左右各16pt内边距，与顶部Header对齐
            .padding(.bottom, 90)
        }
    }


}


