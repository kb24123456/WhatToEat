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
                // 全屏点击手势，点击任意空白处取消搜索框焦点
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFocused = false
                    }
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
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.background)
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击背景时取消搜索框焦点
            isSearchFocused = false
        }
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

// MARK: - 餐厅卡片组件 (自适应尺寸，完美适配所有设备)
struct RestaurantCard: View {
    @Environment(\.modelContext) private var modelContext
    let restaurant: Restaurant
    @ObservedObject var locationManager: LocationManager
    @State private var showDeleteAlert = false
    
    // 计算距离文本
    private func distanceText(from: CLLocation, to restaurant: Restaurant) -> String {
        let distance = from.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    // 获取消费数据文本
    private var priceText: String {
        if restaurant.averagePrice > 0 {
            return "¥\(Int(restaurant.averagePrice))/人"
        } else {
            return "暂无消费数据"
        }
    }
    
    // 获取星级文本
    private var ratingText: String {
        return "⭐️\(restaurant.rating)"
    }
    
    var body: some View {
        Group {
            // 守卫判断：只有对象上下文合法时才访问其属性
            if restaurant.modelContext != nil {

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
                        .cornerRadius(AppTheme.Radius.image) // 封面图圆角与卡片基座圆角一致
                        .clipped() // 确保内容不溢出容器
                        
                        // 右侧内容列：高度与封面图一致，添加右侧内边距
                        VStack(alignment: .leading, spacing: 0) {
                            // MARK: 顶部组 - 包含餐厅名称、价格/地区/距离、星级/品类/标签
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                // 第一行 - 餐厅名称和更多按钮
                                HStack {
                                    Text(restaurant.name)
                                        .font(AppTheme.Fonts.headline)
                                        .bold()
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .onTapGesture { showDeleteAlert = true }
                                }
                                
                                // 第二行 - 元信息：人均消费、地区、距离
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    Text(priceText)
                                        .font(AppTheme.Fonts.footnote)
                                        .foregroundColor(AppTheme.Colors.accent)
                                    
                                    // 小圆点分隔符
                                    Circle()
                                        .frame(width: 3, height: 3)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    Text(restaurant.district)
                                        .font(AppTheme.Fonts.footnote)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    // 小圆点分隔符
                                    Circle()
                                        .frame(width: 3, height: 3)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    // 距离显示（如果有定位）
                                    if let userLocation = locationManager.userLocation {
                                        Text(distanceText(from: userLocation, to: restaurant))
                                            .font(AppTheme.Fonts.footnote)
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    } else {
                                        Text("未定位")
                                        .font(AppTheme.Fonts.footnote)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                }
                                
                                // 第三行 - 属性：星级、品类、标签
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    // 星级
                                    Text(ratingText)
                                        .font(AppTheme.Fonts.subheadline)
                                        .foregroundColor(AppTheme.Colors.secondary)
                                        .bold()
                                    
                                    // 品类
                                    Text(restaurant.type)
                                        .font(AppTheme.Fonts.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    // 标签：只显示前两个，使用小胶囊样式
                                    ForEach(restaurant.tags.prefix(2), id: \.self) {
                                        Text($0)
                                            .font(AppTheme.Fonts.caption)
                                            .foregroundColor(AppTheme.Colors.primary)
                                            .padding(.horizontal, AppTheme.Spacing.xs)
                                            .padding(.vertical, 2)
                                            .background(AppTheme.Colors.primary.opacity(0.1))
                                            .cornerRadius(AppTheme.Radius.circle)
                                    }
                                }
                            }
                            
                            // 弹性占位符：将评论区域推到容器底部
                            Spacer(minLength: 0)
                            
                            // MARK: 底部组 - 评论容器
                            if !restaurant.review.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\"\(restaurant.review)\"")
                                        .font(AppTheme.Fonts.footnote)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal, AppTheme.Spacing.md)
                                        .padding(.vertical, AppTheme.Spacing.sm)
                                        .background(AppTheme.Colors.lightGray)
                                        .cornerRadius(AppTheme.Radius.base)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(height: AppTheme.Cards.restaurantCoverHeight) // 确保右侧高度与左侧封面图一致
                    }
                    .contentShape(Rectangle()) // 👈 确保全卡片可点
                    .background(AppTheme.Colors.card)
                .cornerRadius(AppTheme.Radius.base) // 卡片基座圆角
                .clipped() // 确保内容不溢出容器，保持圆角效果
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
