import SwiftUI
import SwiftData
import MapKit

// MARK: - 1. 核心视图
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    
    // 状态管理
    @State private var searchText = ""
    @State private var showImportSheet = false
    @State private var showCityPicker = false
    @FocusState private var isSearchFocused: Bool // ✅ 专门监听搜索框是否被点中
    
    @StateObject private var locationManager = LocationManager.shared
    
    // 筛选和排序状态
    @State private var selectedCity: String
    @State private var selectedDistrict: String?
    @State private var selectedType: String?
    @State private var sortOption: SortOption = .smart
    
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
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    filterBarSection
                    listSection
                }
                .background(AppTheme.Colors.background)
            }
            .sheet(isPresented: $showImportSheet) { ImportDataView() }
            // 城市选择器
            .sheet(isPresented: $showCityPicker) {
                CitySelectionView(selectedCity: $selectedCity)
            }
            // 当城市变化时，保存到UserDefaults
            .onChange(of: selectedCity) {
                UserDefaults.standard.set(selectedCity, forKey: kSavedCityKey)
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
                .foregroundColor(AppTheme.Colors.textPrimary)
            
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
            
            // 3. 搜索框（占据剩余空间）
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("搜索餐厅名称、菜系...", text: $searchText)
                    .font(AppTheme.Fonts.footnote)
                    .focused($isSearchFocused) // ✅ 绑定焦点状态
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.card)
            .cornerRadius(AppTheme.Radius.base)
            // 1. ✅ 动态边框：聚焦时显示“小红书红”，平时显示透明或极浅灰
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(isSearchFocused ? AppTheme.Colors.accent : Color.clear, lineWidth: 1.5)
            )
            // 2. ✅ 动态阴影：聚焦时变深变大，呈现“浮起”感
            .shadow(
                color: isSearchFocused ? AppTheme.Colors.accent.opacity(0.1) : Color.black.opacity(0.05),
                radius: isSearchFocused ? 15 : 5,
                x: 0,
                y: isSearchFocused ? 8 : 2
            )
            // 3. ✅ 动态缩放与动画：带一点点 Q 弹感
            .scaleEffect(isSearchFocused ? 1.02 : 1.0)
            // 使用 matchedGeometryEffect 替代传统动画，提高性能
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2), value: isSearchFocused)
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.background)
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
                ForEach(getAvailableTypes(), id: \.self) { type in
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
    
    // MARK: - 餐厅列表
    private var listSection: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.lg) {
                ForEach(filteredRestaurants) { restaurant in
                    RestaurantCard(restaurant: restaurant, locationManager: locationManager)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }
            }
            .padding(.bottom, 90)
        }
    }
    
    // MARK: - 辅助方法
    
    /// 从餐厅数据中提取所有去重的餐厅类型
    private func getAvailableTypes() -> [String] {
        // 使用CategoryManager获取所有可用品类
        return CategoryManager.shared.getAllCategories(from: restaurants)
    }
    
    /// 计算两个位置之间的直线距离
    private func calculateDistance(from: CLLocation?, to restaurant: Restaurant) -> Double {
        guard let fromLocation = from else {
            return 0
        }
        
        let toLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// 计算智能排序得分
    private func calculateSmartScore(restaurant: Restaurant, distance: Double) -> Double {
        var score: Double = 0.0
        
        // 因子 A：评分权重 (40%)
        let ratingScore = Double(restaurant.rating) * 20.0
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
        if restaurant.createdAt >= sevenDaysAgo {
            score += 20.0 // 最近7天内创建，加20分
        }
        
        return score
    }
    
    /// 过滤和排序后的餐厅列表
    private var filteredRestaurants: [Restaurant] {
        // 1. 过滤餐厅
        var result = restaurants.filter { restaurant in
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
        let userLocation = locationManager.userLocation
        result = result.sorted { restaurant1, restaurant2 in
            let distance1 = calculateDistance(from: userLocation, to: restaurant1)
            let distance2 = calculateDistance(from: userLocation, to: restaurant2)
            
            switch sortOption {
            case .smart:
                let score1 = calculateSmartScore(restaurant: restaurant1, distance: distance1)
                let score2 = calculateSmartScore(restaurant: restaurant2, distance: distance2)
                return score1 > score2
            case .distance:
                return distance1 < distance2
            case .rating:
                return restaurant1.rating > restaurant2.rating
            case .createdAt:
                return restaurant1.createdAt > restaurant2.createdAt
            }
        }
        
        return result
    }
}

// MARK: - 餐厅卡片组件 (自适应尺寸，完美适配所有设备)
struct RestaurantCard: View {
    @Environment(\.modelContext) private var modelContext
    let restaurant: Restaurant
    @ObservedObject var locationManager: LocationManager
    @State private var showDeleteAlert = false
    
    // 使用 AsyncImageView 替代手动图片加载，实现预解码和缓存
    
    // 计算距离文本
    private func distanceText(from: CLLocation, to restaurant: Restaurant) -> String {
        let distance = from.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    var body: some View {
        Group {
            // 守卫判断：只有对象上下文合法时才访问其属性
            if restaurant.modelContext != nil {
                NavigationLink(destination: RestaurantDetailView(restaurant: restaurant, locationManager: locationManager)) { 
                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        // 封面图：使用 AsyncImageView 实现异步加载和预解码
                        AsyncImageView(
                            filename: restaurant.coverPhotoFilename,
                            placeholder: AnyView(
                                ZStack {
                                    AppTheme.Colors.primary.opacity(0.1)
                                    Image(systemName: "fork.knife.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.primary.opacity(0.3)) 
                                }
                            )
                        )
                        .frame(width: AppTheme.Cards.restaurantCoverWidth, height: AppTheme.Cards.restaurantCoverHeight)
                        .cornerRadius(AppTheme.Radius.image) // 封面图圆角与卡片圆角一致：16pt
                        .clipped() // 确保内容不溢出容器
                        
                        // 信息区域：调整顶部对齐，使餐厅名称与封面图上边缘齐平
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(restaurant.name)
                                    .font(AppTheme.Fonts.headline)
                                    .bold()
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .onTapGesture { showDeleteAlert = true }
                            }
                            
                            // 评分和标签
                            HStack(spacing: AppTheme.Spacing.xs) {
                                // 评分星星
                                ForEach(1...5, id: \.self) {
                                    Image(systemName: $0 <= restaurant.rating ? "star.fill" : "star")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.secondary)
                                }
                                
                                Spacer()
                                
                                // 标签：只显示前两个
                                Text(restaurant.tags.prefix(2).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            // 距离和价格
                            HStack {
                                // 距离显示（如果有定位）
                                if let userLocation = locationManager.userLocation {
                                    Text(distanceText(from: userLocation, to: restaurant))
                                        .font(.footnote)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                } else {
                                    Text("未定位")
                                        .font(.footnote)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                
                                Spacer()
                                
                                // 平均消费显示：如果有平均价格，显示"¥XX"，否则显示"暂无消费数据"
                                if restaurant.averagePrice > 0 {
                                    Text("¥\(Int(restaurant.averagePrice))")
                                        .font(.footnote)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .bold()
                                } else {
                                    Text("暂无消费数据")
                                        .font(.footnote)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                            
                            // 地址和评价
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text(restaurant.address)
                                    .font(.footnote)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .lineLimit(1)
                                
                                if !restaurant.review.isEmpty {
                                    Text(restaurant.review)
                                        .font(AppTheme.Fonts.caption2)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.card)
                    .cornerRadius(AppTheme.Radius.base)
                    // ✅ 移除阴影效果
                    .shadow(color: Color.black.opacity(0.0), radius: 0, x: 0, y: 0)
                }
                .alert("确认删除", isPresented: $showDeleteAlert) {
                    Button("删除", role: .destructive) {
                        modelContext.delete(restaurant)
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("确定要删除餐厅 \(restaurant.name) 吗？")
                }
            } else {
                EmptyView()
            }
        }
    }
}