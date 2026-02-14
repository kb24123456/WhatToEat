import SwiftUI
import SwiftData
import MapKit

// MARK: - 餐厅卡片流主视图
// 架构：列表态卡片+文本整体滑动 + 展开态Hero动画
struct RestaurantFlowView: View {
    @Query(sort: \Restaurant.createdAt, order: .reverse) var restaurants: [Restaurant]
    @State private var viewModel = RestaurantFlowViewModel()
    @Namespace private var animationNamespace
    
    // 动画状态
    @State private var listViewOffset: CGFloat = 0
    @State private var expandedViewOffset: CGFloat = UIScreen.main.bounds.height
    @State private var sideCardsOpacity: Double = 1.0
    
    // 展开态元素动画状态
    @State private var nameOffset: CGFloat = 100
    @State private var reviewOffset: CGFloat = 100
    @State private var distanceTimeOffset: CGFloat = 100
    @State private var districtTypeOffset: CGFloat = 100
    @State private var tagsOffset: CGFloat = 100
    @State private var buttonOffset: CGFloat = 100
    
    var body: some View {
        ZStack {
            Color(hex: "#F9F9F7").ignoresSafeArea()
            
            // 调试：显示餐厅数量
            #if DEBUG
            let _ = print("RestaurantFlowView: restaurants count = \(restaurants.count)")
            #endif
            
            // 空数据提示
            if restaurants.isEmpty {
                emptyStateView
            } else {
                // 列表态（始终存在）
                listView
                    .opacity(viewModel.isExpanded ? 0 : 1)
                    .offset(y: listViewOffset)
                
                // 展开态（始终存在）
                if let selected = viewModel.selectedRestaurant {
                    expandedView(restaurant: selected)
                        .opacity(viewModel.isExpanded ? 1 : 0)
                        .offset(y: expandedViewOffset)
                }
            }
        }
    }
    
    // 当前要展开的餐厅，用于延迟展开
    @State private var pendingExpandRestaurant: Restaurant?
    
    // MARK: - 处理动画切换
    private func handleExpandAnimation(for restaurant: Restaurant) {
        // 保存待展开的餐厅
        pendingExpandRestaurant = restaurant
        
        // 第1步：两侧卡片迅速淡出（150ms）
        withAnimation(.easeOut(duration: 0.15)) {
            sideCardsOpacity = 0
        }
        
        // 第2步：执行展开动画（延迟250ms，淡出150ms + 等待100ms）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // 先设置展开状态（这会触发 listView 整体淡出，但中心卡片已经准备好飞出了）
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewModel.expand(restaurant: restaurant)
            }
            
            // 列表态向上飞出，展开态从下方进入
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                self.listViewOffset = -UIScreen.main.bounds.height
                self.expandedViewOffset = 0
            }
            
            // 级联动画：展开态元素从下方飞入
            self.resetOffsets()
            
            // 名称（0ms）
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.0)) {
                self.nameOffset = 0
            }
            
            // 评论（50ms）
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05)) {
                self.reviewOffset = 0
            }
            
            // 距离/时间（100ms）
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
                self.distanceTimeOffset = 0
            }
            
            // 区域/品类（150ms）
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15)) {
                self.districtTypeOffset = 0
            }
            
            // 标签（200ms）
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.2)) {
                self.tagsOffset = 0
            }
            
            // 按钮（250ms）
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25)) {
                self.buttonOffset = 0
            }
        }
    }
    
    private func handleCollapseAnimation() {
        // 第1步：执行收回动画
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            self.listViewOffset = 0
            self.expandedViewOffset = UIScreen.main.bounds.height
        }
        
        // 级联动画：展开态元素向下飞出
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.resetOffsets()
        }
        
        // 第2步：两侧卡片迅速淡入（延迟400ms，等收回动画完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.15)) {
                self.sideCardsOpacity = 1
            }
        }
    }
    
    private func resetOffsets() {
        nameOffset = 100
        reviewOffset = 100
        distanceTimeOffset = 100
        districtTypeOffset = 100
        tagsOffset = 100
        buttonOffset = 100
    }
    
    // MARK: - 空数据状态
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("还没有餐厅")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.gray)
            
            Text("点击下方 + 号添加第一家餐厅")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
    }
    
    // MARK: - 列表态：卡片+文本整体
    private var listView: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            // 调整卡片尺寸
            let cardWidth: CGFloat = 240
            let cardHeight: CGFloat = 336
            let spacing: CGFloat = 20
            let sidePadding = (screenWidth - cardWidth) / 2
            let topPadding: CGFloat = screenHeight * 0.12 // 使用屏幕高度的12%作为顶部间距
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(Array(restaurants.enumerated()), id: \.element.id) { index, restaurant in
                        // 判断是否是中心卡片：如果 centeredRestaurantID 为 nil，则第一个卡片为中心
                        let isCenterCard = viewModel.centeredRestaurantID == restaurant.id || 
                                          (viewModel.centeredRestaurantID == nil && index == 0)
                        
                        // 卡片+文本整体单元
                        VStack(spacing: 0) {
                            // 卡片图片
                            cardImage(restaurant: restaurant, width: cardWidth, height: cardHeight)
                            
                            // 文本区域 - 在下方空白处居中
                            textSection(restaurant: restaurant)
                                .frame(height: max(0, screenHeight - cardHeight - topPadding - 140))
                        }
                        .frame(width: cardWidth)
                        .id(restaurant.id)
                        .contentShape(Rectangle())
                        // 只有非中心卡片（两侧卡片）受 sideCardsOpacity 控制，中心卡片始终显示
                        .opacity(isCenterCard ? 1.0 : sideCardsOpacity)
                        .onTapGesture {
                            if isCenterCard {
                                handleExpandAnimation(for: restaurant)
                            }
                        }
                    }
                }
                .padding(.horizontal, sidePadding)
                .padding(.top, topPadding) // 增加顶部间距
            }
            .scrollTargetBehavior(.viewAligned) // 中心吸附
            .scrollPosition(id: $viewModel.centeredRestaurantID, anchor: .center)
        }
    }
    
    // MARK: - 列表态卡片图片
    private func cardImage(restaurant: Restaurant, width: CGFloat, height: CGFloat) -> some View {
        AsyncImageView(
            filename: restaurant.coverPhotoFilename,
            placeholder: AnyView(
                ZStack {
                    Color(hex: "#F0F0F0")
                    Image(systemName: "fork.knife")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            ),
            contentMode: .fill
        )
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        // 移除 matchedGeometryEffect，使用纯透明度动画
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - 列表态文本区域
    private func textSection(restaurant: Restaurant) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 使用固定高度的容器包裹名称，确保首行对齐
            VStack(spacing: 12) {
                Text(restaurant.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2) // 限制最多2行
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(minHeight: 24) // 最小高度确保单行时也能对齐
                    .fixedSize(horizontal: false, vertical: true)
                
                if !restaurant.review.isEmpty {
                    Text(restaurant.review)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - 展开态
    private func expandedView(restaurant: Restaurant) -> some View {
        VStack(spacing: 0) {
            // 顶部返回按钮栏
            HStack {
                Button(action: {
                    handleCollapseAnimation()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.collapse()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // 可滚动内容
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 横向大图 - 统一左右间距
                    expandedImage(restaurant: restaurant)
                        .padding(.horizontal, 32) // 统一左右间距
                    
                    // 餐厅名称 - 从下方飞入
                    Text(restaurant.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 24)
                        .offset(y: nameOffset)
                    
                    // 评论 - 从下方飞入
                    if !restaurant.review.isEmpty {
                        Text(restaurant.review)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                            .italic()
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 12)
                            .offset(y: reviewOffset)
                    }
                    
                    // 距离/时间 - 从下方飞入（第一行）
                    distanceTimeRow(restaurant: restaurant)
                        .padding(.top, 24)
                        .padding(.horizontal, 40)
                        .offset(y: distanceTimeOffset)
                    
                    // 区域/品类 - 从下方飞入（第二行）
                    districtTypeRow(restaurant: restaurant)
                        .padding(.top, 12)
                        .padding(.horizontal, 40)
                        .offset(y: districtTypeOffset)
                    
                    // 标签 - 从下方飞入
                    tagsSection(restaurant: restaurant)
                        .padding(.top, 20)
                        .padding(.horizontal, 40)
                        .offset(y: tagsOffset)
                    
                    // 去这里按钮 - 从下方飞入
                    navigationButton(restaurant: restaurant)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                        .padding(.horizontal, 40)
                        .offset(y: buttonOffset)
                }
            }
        }
        .background(Color(hex: "#F9F9F7"))
    }
    
    // MARK: - 展开态图片 - 统一左右间距
    private func expandedImage(restaurant: Restaurant) -> some View {
        GeometryReader { geometry in
            // 可用宽度减去左右边距
            let availableWidth = geometry.size.width
            // 使用统一的比例
            let width = availableWidth
            let height = width * 0.6 // 1.6:1 横纵比
            
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    ZStack {
                        Color(hex: "#F0F0F0")
                        Image(systemName: "fork.knife")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }
                ),
                contentMode: .fill
            )
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            // 移除 matchedGeometryEffect，使用纯透明度动画
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        }
        // 计算高度
        .frame(height: UIScreen.main.bounds.width * 0.6)
    }
    
    // MARK: - 距离/时间行
    private func distanceTimeRow(restaurant: Restaurant) -> some View {
        HStack(spacing: 12) {
            InfoCard(
                icon: "location.fill",
                title: "距离",
                value: distanceText(for: restaurant),
                color: AppTheme.Colors.babyBlue
            )
            
            InfoCard(
                icon: "car.fill",
                title: "驾车约",
                value: driveTimeText(for: restaurant),
                color: AppTheme.Colors.secondary
            )
        }
    }
    
    // MARK: - 区域/品类行
    private func districtTypeRow(restaurant: Restaurant) -> some View {
        HStack(spacing: 12) {
            InfoCard(
                icon: "mappin.and.ellipse",
                title: "区域",
                value: restaurant.district.isEmpty ? "未知" : restaurant.district,
                color: AppTheme.Colors.accent
            )
            
            InfoCard(
                icon: "fork.knife",
                title: "品类",
                value: restaurant.type.isEmpty ? "未分类" : restaurant.type,
                color: Color.orange
            )
        }
    }
    
    // MARK: - 标签区域 - 增大尺寸
    private func tagsSection(restaurant: Restaurant) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(restaurant.tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 13, weight: .medium)) // 从11增大到13
                    .foregroundColor(AppTheme.Colors.babyBlue)
                    .padding(.horizontal, 14) // 从10增大到14
                    .padding(.vertical, 7) // 从5增大到7
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.babyBlue.opacity(0.12))
                    )
            }
        }
    }
    
    // MARK: - 导航按钮
    private func navigationButton(restaurant: Restaurant) -> some View {
        Button(action: {
            openNavigation(for: restaurant)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 16))
                Text("去这里")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 辅助方法
    private func distanceText(for restaurant: Restaurant) -> String {
        guard let userLocation = LocationManager.shared.userLocation else { return "--" }
        let distance = userLocation.distance(from: CLLocation(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        ))
        return distance < 1000 ? String(format: "%.0fm", distance) : String(format: "%.1fkm", distance / 1000)
    }
    
    private func driveTimeText(for restaurant: Restaurant) -> String {
        guard let userLocation = LocationManager.shared.userLocation else { return "--" }
        let distance = userLocation.distance(from: CLLocation(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        ))
        let timeInMinutes = Int((distance / 1000) / 30 * 60)
        if timeInMinutes < 1 { return "<1分钟" }
        else if timeInMinutes < 60 { return "\(timeInMinutes)分钟" }
        else {
            let hours = timeInMinutes / 60
            let mins = timeInMinutes % 60
            return mins > 0 ? "\(hours)小时\(mins)分" : "\(hours)小时"
        }
    }
    
    private func openNavigation(for restaurant: Restaurant) {
        let coordinate = CLLocationCoordinate2D(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - 信息卡片
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }
}
