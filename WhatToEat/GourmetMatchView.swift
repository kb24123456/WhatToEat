import SwiftUI
import SwiftData
import CoreLocation

// MARK: - 心动匹配游戏视图 (Cover Flow + 底部卡片详情)
struct GourmetMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @ObservedObject var locationManager: LocationManager = LocationManager.shared
    
    // 命名空间用于 Hero 动画
    @Namespace private var animation
    
    // 筛选状态
    @State private var selectedDistrict: String = "全部"
    @State private var selectedType: String = "全部"
    
    // 视图状态 - 使用单一状态控制 Hero Animation
    @State private var selectedRestaurant: Restaurant? = nil
    
    // 震动反馈状态
    @State private var lastCenterIndex: Int = -1
    
    // 筛选器数据
    private var districts: [String] {
        var districts = Array(Set(restaurants.map { $0.district })).sorted()
        districts.insert("全部", at: 0)
        return districts
    }
    
    private var types: [String] {
        var types = Array(Set(restaurants.map { $0.type })).sorted()
        types.insert("全部", at: 0)
        return types
    }
    
    // 筛选后的餐厅列表 - 计算属性
    private var filteredRestaurants: [Restaurant] {
        restaurants.filter { restaurant in
            let districtMatch = selectedDistrict == "全部" || restaurant.district == selectedDistrict
            let typeMatch = selectedType == "全部" || restaurant.type == selectedType
            return districtMatch && typeMatch
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            // 计算卡片尺寸和位置
            // 优化1：宽高等比例放大
            // - 上边缘位于屏幕垂直方向中线处
            // - 下边缘保持位于底部导航条上方 16pt
            let screenHeight = geometry.size.height
            let screenMidY = screenHeight / 2
            let tabBarHeight: CGFloat = 83  // 底部导航条高度（包含安全区域）
            let bottomPadding: CGFloat = 16  // 导航条上方间距
            
            let cardTopY = screenMidY  // 卡片上边缘位置：屏幕中线
            let cardBottomY = screenHeight - tabBarHeight - bottomPadding  // 卡片下边缘位置：导航条上方 16pt
            let cardHeight = cardBottomY - cardTopY
            let cardWidth = cardHeight * 0.75  // 3:4 比例
            
            ZStack {
                // 背景
                AppTheme.Colors.pageBackground
                    .ignoresSafeArea()
                
                // MARK: 顶部筛选器
                VStack {
                    filterBar
                        .padding(.top, 60)
                        .padding(.horizontal, 20)
                    
                    Spacer()
                }
                
                // MARK: 空白区域引导文案
                // 位于筛选器和卡片之间的空白区域
                VStack(spacing: 0) {
                    // 装饰分隔线
                    Rectangle()
                        .fill(Color(hex: "E5E5E5"))
                        .frame(width: 40, height: 2)
                        .padding(.bottom, 40)
                    
                    // 主标题：选择困难症？不存在的
                    VStack(spacing: 4) {
                        Text("选择困难症？")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                        
                        Text("不存在的")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                    }
                    .padding(.bottom, 16)
                    
                    // 副标题：左右滑动一下，让美食自己找上门
                    VStack(spacing: 2) {
                        Text("左右滑动一下，")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(hex: "666666"))
                        
                        Text("让美食自己找上门")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(hex: "666666"))
                    }
                    .padding(.bottom, 32)
                    
                    // 引导箭头（动态效果）
                    Image(systemName: "chevron.down")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "999999"))
                        .opacity(0.6)
                }
                .position(
                    x: geometry.size.width / 2,
                    y: (60 + 44 + 32 + screenMidY) / 2  // 筛选器底部和卡片顶部之间的中间位置
                )
                
                // MARK: Cover Flow 卡片轮播
                // 使用 frame 精确定位卡片位置和大小
                carouselArea(
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    containerWidth: geometry.size.width
                )
                .frame(
                    width: geometry.size.width,
                    height: cardHeight
                )
                .position(
                    x: geometry.size.width / 2,
                    y: cardTopY + cardHeight / 2
                )
                
                // MARK: 底部详情卡片（非全屏）
                if let selectedRestaurant {
                    GourmetMatchDetailCard(
                        restaurant: selectedRestaurant,
                        namespace: animation,
                        locationManager: locationManager,
                        onClose: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                self.selectedRestaurant = nil
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
        }
    }
    
    // MARK: - 顶部筛选器 (与 LibraryView 同步)
    private var filterBar: some View {
        HStack(spacing: 12) {
            // 1. 地区筛选
            Menu {
                Button("全区") { selectedDistrict = "全部" }
                Divider()
                ForEach(districts.filter { $0 != "全部" }, id: \.self) { district in
                    Button(district) { selectedDistrict = district }
                }
            } label: {
                filterCapsuleLabel(
                    title: selectedDistrict == "全部" ? "地区" : selectedDistrict,
                    isSelected: selectedDistrict != "全部"
                )
            }
            
            // 2. 分类筛选
            Menu {
                Button("全部分类") { selectedType = "全部" }
                Divider()
                ForEach(types.filter { $0 != "全部" }, id: \.self) { type in
                    Button(type) { selectedType = type }
                }
            } label: {
                filterCapsuleLabel(
                    title: selectedType == "全部" ? "品类" : selectedType,
                    isSelected: selectedType != "全部"
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: - 筛选胶囊标签（与 LibraryView 同步）
    private func filterCapsuleLabel(title: String, isSelected: Bool) -> some View {
        let displayTitle = title.count > 4 ? String(title.prefix(3)) + "…" : title
        
        return HStack(spacing: 4) {
            Text(displayTitle)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color(hex: "#1A1A1A"))
                .frame(width: 52, height: 18, alignment: .center)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
                .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.Colors.babyBlue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? Color.black : Color.white)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Cover Flow 卡片轮播区域
    private func carouselArea(cardWidth: CGFloat, cardHeight: CGFloat, containerWidth: CGFloat) -> some View {
        Group {
            if filteredRestaurants.isEmpty {
                emptyStateView
            } else {
                let cardSpacing: CGFloat = 0
                let totalCardWidth = cardWidth + cardSpacing
                // 内容边距：使第一个卡片居中
                let contentMargin = (containerWidth - cardWidth) / 2
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        ForEach(Array(filteredRestaurants.enumerated()), id: \.element.id) { index, restaurant in
                            // 关键：使用单一状态控制 Hero Animation
                            // 未选中时 isSource = true（作为源）
                            // 选中时 isSource = false（作为目标）
                            GourmetMatchCard(
                                restaurant: restaurant,
                                locationManager: locationManager,
                                cardWidth: cardWidth,
                                cardHeight: cardHeight
                            )
                            .matchedGeometryEffect(
                                id: restaurant.id,
                                in: animation,
                                isSource: selectedRestaurant?.id != restaurant.id
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            .visualEffect { content, proxy in
                                // 获取卡片在全局坐标系中的位置（相对于屏幕）
                                let frame = proxy.frame(in: .global)
                                // 卡片中心在屏幕上的 X 坐标
                                let cardCenterX = frame.midX
                                // 屏幕中心 X 坐标
                                let screenCenterX = containerWidth / 2
                                // 计算距离（有符号，用于旋转方向）
                                let distance = cardCenterX - screenCenterX
                                
                                return content
                                    .scaleEffect(scale(forDistance: abs(distance), containerWidth: containerWidth))
                                    .opacity(opacity(forDistance: abs(distance), containerWidth: containerWidth))
                                    .rotation3DEffect(
                                        .degrees(rotationAngle(forDistance: distance)),
                                        axis: (x: 0, y: 1, z: 0)
                                    )
                            }
                            .onTapGesture {
                                // 关键：只有当没有选中卡片时才允许点击
                                // 使用单一状态 selectedRestaurant 控制
                                guard selectedRestaurant == nil else { return }
                                
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    selectedRestaurant = restaurant
                                }
                            }
                            // 检测是否滑动到中心，触发震动反馈
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { frame in
                                let cardCenterX = frame.midX
                                let screenCenterX = containerWidth / 2
                                let distance = abs(screenCenterX - cardCenterX)
                                
                                // 如果距离中心小于阈值，认为是中心卡片
                                if distance < 10 && lastCenterIndex != index {
                                    lastCenterIndex = index
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                // 计算边距使第一个卡片居中
                .contentMargins(.horizontal, contentMargin, for: .scrollContent)
            }
        }
    }
    
    // MARK: - 视觉计算逻辑 (Visual Math)
    // 基于距离屏幕中心的距离计算缩放比例
    private func scale(forDistance distance: CGFloat, containerWidth: CGFloat) -> CGFloat {
        // distance: 卡片中心距离屏幕中心的距离
        // 距离为 0 时，scale = 1.0（100% 大小）
        // 距离越大，scale 越小
        let scale = 1.0 - (distance / containerWidth) * 0.25
        return max(scale, 0.75)
    }
    
    // 基于距离屏幕中心的距离计算透明度
    private func opacity(forDistance distance: CGFloat, containerWidth: CGFloat) -> Double {
        // distance: 卡片中心距离屏幕中心的距离
        // 距离为 0 时，opacity = 1.0（完全不透明）
        return Double(1.0 - (distance / 800))
    }
    
    // 基于距离屏幕中心的距离计算旋转角度
    private func rotationAngle(forDistance distance: CGFloat) -> Double {
        // distance: 卡片中心距离屏幕中心的有向距离
        // 距离为 0 时，rotation = 0°（无旋转）
        // 距离 > 0（卡片在右侧），rotation > 0（向右旋转）
        // 距离 < 0（卡片在左侧），rotation < 0（向左旋转）
        return Double(distance / 25)
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "face.smiling")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(AppTheme.Colors.babyBlue)
                .padding(.top, 40)
            
            Text("都品尝过了")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.Colors.darkText)
                .tracking(0.5)
            
            Text("换个筛选条件，继续探索美食世界")
                .font(.system(size: 14, weight: .regular))
                .italic()
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - 餐厅卡片组件
struct GourmetMatchCard: View {
    let restaurant: Restaurant
    let locationManager: LocationManager
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    init(restaurant: Restaurant, locationManager: LocationManager, cardWidth: CGFloat = 300, cardHeight: CGFloat = 400) {
        self.restaurant = restaurant
        self.locationManager = locationManager
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 图片区域
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    ZStack {
                        AppTheme.Colors.babyBlue.opacity(0.1)
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: cardWidth * 0.2))
                            .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.3))
                    }
                )
            )
            .scaledToFill()
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.1),
                                Color.clear,
                                Color.clear,
                                Color.black.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            
            // 底部信息浮层
            VStack(alignment: .leading, spacing: 8) {
                Text(restaurant.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Text(restaurant.type)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                    
                    if restaurant.averagePrice > 0 {
                        Text("¥\(Int(restaurant.averagePrice))/人")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.8))
                    }
                    
                    if let userLocation = locationManager.userLocation {
                        let distance = userLocation.distance(from: CLLocation(
                            latitude: restaurant.latitude,
                            longitude: restaurant.longitude
                        ))
                        Text(distance < 1000 ? String(format: "%.0fm", distance) : String(format: "%.1fkm", distance / 1000))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.8))
                    }
                }
                
                if !restaurant.review.isEmpty {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(AppTheme.Colors.babyBlue)
                            .frame(width: 2, height: 12)
                        
                        Text(restaurant.review)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            )
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: Color.black.opacity(0.15), radius: cardWidth * 0.067, x: 0, y: cardWidth * 0.033)
    }
}

// MARK: - 底部详情卡片（非全屏，参考图2/3样式）
struct GourmetMatchDetailCard: View {
    let restaurant: Restaurant
    var namespace: Namespace.ID
    let locationManager: LocationManager
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 拖动指示条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 图片区域（与卡片共用 Hero 动画）
                    // 关键：isSource = true，作为动画的目标
                    AsyncImageView(
                        filename: restaurant.coverPhotoFilename,
                        placeholder: AnyView(
                            ZStack {
                                AppTheme.Colors.babyBlue.opacity(0.1)
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.3))
                            }
                        )
                    )
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .matchedGeometryEffect(id: restaurant.id, in: namespace, isSource: true)
                    
                    // 内容区域（参考图3样式）
                    VStack(alignment: .leading, spacing: 16) {
                        // 标题行
                        HStack {
                            Text(restaurant.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppTheme.Colors.darkText)
                            
                            Spacer()
                            
                            // 评分
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                                Text("\(restaurant.rating, specifier: "%.0f")")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.darkText)
                            }
                        }
                        
                        // 距离和预计时间（参考图3的蓝色样式）
                        HStack(spacing: 24) {
                            if let userLocation = locationManager.userLocation {
                                let distance = userLocation.distance(from: CLLocation(
                                    latitude: restaurant.latitude,
                                    longitude: restaurant.longitude
                                ))
                                let distanceText = distance < 1000 ? String(format: "%.1f", distance) : String(format: "%.1f", distance / 1000)
                                let unit = distance < 1000 ? "m" : "km"
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 12))
                                        Text("\(distanceText) \(unit)")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(AppTheme.Colors.babyBlue)
                                    
                                    Text("距离")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.Colors.lightText)
                                }
                                
                                // 预计驾车时间（估算）
                                let drivingMinutes = Int(distance / 500)
                                if drivingMinutes > 0 {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "car.fill")
                                                .font(.system(size: 12))
                                            Text("\(drivingMinutes) 分钟")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                        
                                        Text("预计驾车")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.Colors.lightText)
                                    }
                                }
                            }
                        }
                        
                        // 一句话点评
                        if !restaurant.review.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("一句话点评")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.lightText)
                                
                                Text(restaurant.review)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.darkText)
                            }
                        }
                        
                        // 统计信息（参考图3的图标+数字样式）
                        HStack(spacing: 24) {
                            if restaurant.averagePrice > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Colors.babyBlue)
                                        Text("¥\(Int(restaurant.averagePrice))")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppTheme.Colors.darkText)
                                    }
                                    Text("人均消费")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.Colors.lightText)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                    Text("\(restaurant.checkInCount)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.darkText)
                                }
                                Text("已造访")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Colors.lightText)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                    Text("¥\(Int(restaurant.totalExpense))")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.darkText)
                                }
                                Text("总消费")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Colors.lightText)
                            }
                        }
                        
                        // 标签
                        if !restaurant.tags.isEmpty {
                            GourmetMatchFlowLayout(spacing: 8) {
                                ForEach(restaurant.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.mediumGray)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(AppTheme.Colors.softBackground)
                                        )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            
            // 底部操作按钮（参考图3样式）
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    // 打卡按钮
                    Button {
                        // 打卡逻辑
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16))
                            Text("打卡")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.darkText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.softBackground)
                        )
                    }
                    
                    // 导航按钮
                    Button {
                        // 导航逻辑
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 16))
                            Text("导航")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.darkText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.softBackground)
                        )
                    }
                    
                    Spacer()
                    
                    // 关闭按钮
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.Colors.lightText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: -10)
        .frame(maxHeight: 600)
        .padding(.horizontal, 16)
        .padding(.bottom, 90)
    }
}

// MARK: - FlowLayout 辅助视图 (GourmetMatch 专用)
struct GourmetMatchFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - 预览
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    
    return GourmetMatchView()
        .modelContainer(container)
}
