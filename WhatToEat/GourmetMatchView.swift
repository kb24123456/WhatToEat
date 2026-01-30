import SwiftUI
import SwiftData
import CoreLocation

// MARK: - 心动匹配游戏视图 (奶脂实色规范)
struct GourmetMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @ObservedObject var locationManager: LocationManager = LocationManager()
    
    @State private var selectedDistrict: String = "全部"
    @State private var selectedType: String = "全部"
    
    // 卡片状态
    @State private var currentIndex: Int = 0
    @State private var offset: CGSize = .zero
    @State private var cardRotation: Double = 0
    @State private var isDragging: Bool = false
    @State private var nextCardOpacity: Double = 0.0
    
    // 状态反馈
    @State private var showEatConfirmation: Bool = false
    @State private var selectedRestaurant: Restaurant? = nil
    
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
    
    private var filteredRestaurants: [Restaurant] {
        restaurants.filter { restaurant in
            let districtMatch = selectedDistrict == "全部" || restaurant.district == selectedDistrict
            let typeMatch = selectedType == "全部" || restaurant.type == selectedType
            return districtMatch && typeMatch
        }
    }
    
    var body: some View {
        ZStack {
            // 背景由 ContentView 统一提供
            
            VStack(spacing: 0) {
                // 顶部筛选器
                filterBar
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                
                // 卡片堆叠区域
                cardStackArea
                    .padding(.horizontal, 20)
                
                // 交互按钮
                actionButtons
                    .padding(.top, 24)
            }
        }
        .padding(.bottom, 120)
        .alert("就是它了！", isPresented: $showEatConfirmation) {
            Button("去看看", role: .none) {}
            Button("继续匹配", role: .cancel) {}
        } message: {
            if let restaurant = selectedRestaurant {
                Text("\(restaurant.name) 已加入你的想吃清单")
            }
        }
    }
    
    // MARK: - 顶部筛选器 (与 LibraryView 一致)
    private var filterBar: some View {
        HStack(spacing: 12) {
            // 地区筛选器 - 使用 Button 触发 Menu
            Menu {
                ForEach(districts, id: \.self) { district in
                    Button {
                        selectedDistrict = district
                    } label: {
                        Text(district)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedDistrict)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            }
            
            // 品类筛选器 - 使用 Button 触发 Menu
            Menu {
                ForEach(types, id: \.self) { type in
                    Button {
                        selectedType = type
                    } label: {
                        Text(type)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedType)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 卡片堆叠区域 (3:4 比例)
    private var cardStackArea: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width - 40, 320.0)
            let cardHeight = cardWidth * (4.0 / 3.0)
            
            ZStack(alignment: .center) {
                if filteredRestaurants.isEmpty || currentIndex >= filteredRestaurants.count {
                    emptyStateView
                } else {
                    // 底层卡片 (藏起来)
                    if currentIndex + 1 < filteredRestaurants.count {
                        matchCard(
                            for: filteredRestaurants[currentIndex + 1],
                            cardSize: CGSize(width: cardWidth, height: cardHeight),
                            isTop: false
                        )
                        .scaleEffect(0.85)
                        .offset(y: 20)
                        .opacity(0.0)
                        .opacity(nextCardOpacity)
                    }
                    
                    // 顶层卡片 (可交互)
                    if currentIndex < filteredRestaurants.count {
                        matchCard(
                            for: filteredRestaurants[currentIndex],
                            cardSize: CGSize(width: cardWidth, height: cardHeight),
                            isTop: true
                        )
                        .offset(offset)
                        .rotationEffect(.degrees(cardRotation))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    isDragging = true
                                    offset = gesture.translation
                                    cardRotation = min(max(Double(gesture.translation.width / 20), -15), 15)
                                    
                                    if abs(gesture.translation.width) > 50 {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            nextCardOpacity = 0.3
                                        }
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            nextCardOpacity = 0.0
                                        }
                                    }
                                }
                                .onEnded { gesture in
                                    isDragging = false
                                    handleSwipeEnd(gesture)
                                    
                                    if gesture.translation.width <= 150 && gesture.translation.width >= -150 {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            nextCardOpacity = 0.0
                                        }
                                    }
                                }
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: offset)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxHeight: 480)
    }
    
    // MARK: - 核心卡片 (参考 RestaurantCard 样式)
    private func matchCard(for restaurant: Restaurant, cardSize: CGSize, isTop: Bool) -> some View {
        ZStack {
            // 卡片背景 (奶脂实色风格)
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                )
                .shadow(
                    color: AppTheme.Shadows.premium.ambient.color,
                    radius: AppTheme.Shadows.premium.ambient.radius,
                    x: AppTheme.Shadows.premium.ambient.x,
                    y: AppTheme.Shadows.premium.ambient.y
                )
                .shadow(
                    color: AppTheme.Shadows.premium.defining.color,
                    radius: AppTheme.Shadows.premium.defining.radius,
                    x: AppTheme.Shadows.premium.defining.x,
                    y: AppTheme.Shadows.premium.defining.y
                )
            
            VStack(spacing: 0) {
                // 图片区域 (无遮罩)
                AsyncImageView(
                    filename: restaurant.coverPhotoFilename,
                    placeholder: AnyView(
                        ZStack {
                            AppTheme.Colors.primary.opacity(0.1)
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.Colors.primary.opacity(0.3))
                        }
                    )
                )
                .scaledToFill()
                .frame(width: cardSize.width - 24, height: cardSize.height * 0.52)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.top, 12)
                
                // 信息区域 (参考 RestaurantCard.infoContent)
                VStack(alignment: .leading, spacing: 0) {
                    // 餐厅名称
                    Text(restaurant.name)
                        .font(AppTheme.Fonts.title3)
                        .bold()
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Color.clear.frame(height: 12)
                    
                    // metaInfo (价格 + 区域 + 距离)
                    HStack(spacing: AppTheme.Spacing.md) {
                        // 价格
                        Text(restaurant.averagePrice > 0 ? "¥\(Int(restaurant.averagePrice))/人" : "暂无消费数据")
                            .font(AppTheme.Fonts.subheadline)
                            .foregroundColor(AppTheme.Colors.price)
                        
                        // 区域
                        Text(restaurant.district)
                            .font(AppTheme.Fonts.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        // 距离
                        if let userLocation = locationManager.userLocation {
                            let distance = userLocation.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
                            if distance < 1000 {
                                Text(String(format: "%.0fm", distance))
                                    .font(AppTheme.Fonts.subheadline)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            } else {
                                Text(String(format: "%.1fkm", distance / 1000))
                                    .font(AppTheme.Fonts.subheadline)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        } else {
                            Text("未定位")
                                .font(AppTheme.Fonts.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.Colors.softBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                            )
                    )
                    
                    Color.clear.frame(height: 10)
                    
                    // tagsRow (评分 + 类型 + 标签)
                    HStack(spacing: AppTheme.Spacing.sm) {
                        // 评分
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.secondary)
                                .symbolRenderingMode(.hierarchical)
                            Text("\(Int(restaurant.rating))")
                                .font(AppTheme.Fonts.callout)
                                .foregroundColor(AppTheme.Colors.secondary)
                                .bold()
                        }
                        
                        // 类型
                        Text(restaurant.type)
                            .font(AppTheme.Fonts.callout)
                            .foregroundColor(Color(hex: "#89CFF0"))
                        
                        // 标签
                        ForEach(Array(restaurant.tags.prefix(2)), id: \.self) { tag in
                            Text(tag)
                                .font(AppTheme.Fonts.callout)
                                .foregroundColor(Color(hex: "#89CFF0"))
                                .padding(.horizontal, 8)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#89CFF0").opacity(0.1))
                                )
                        }
                    }
                    
                    Color.clear.frame(height: 10)
                    
                    // 评价 (如果有)
                    if !restaurant.review.isEmpty {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(AppTheme.Colors.accent)
                                .frame(width: 1.5)
                                .cornerRadius(1)
                                .shadow(color: AppTheme.Colors.accent.opacity(0.2), radius: 1.5, x: 0, y: 0)
                            
                            Text(restaurant.review)
                                .font(AppTheme.Fonts.callout)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .lineLimit(1)
                                .multilineTextAlignment(.leading)
                                .fontWeight(.medium)
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.lightGray.opacity(0.5))
                        .cornerRadius(AppTheme.Radius.base)
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
                
                Spacer()
            }
            
            // 拖拽状态覆盖层
            if isTop && offset.width != 0 {
                swipeOverlay
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }
    
    // MARK: - 拖拽状态覆盖层
    private var swipeOverlay: some View {
        ZStack {
            if offset.width > 0 {
                Color.red.opacity(min(Double(offset.width) / 300.0, 0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                    Text("想吃")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                    Spacer()
                }
                .opacity(min(Double(offset.width) / 150.0, 1.0))
            }
            
            if offset.width < 0 {
                Color.gray.opacity(min(Double(abs(offset.width)) / 300.0, 0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                
                VStack {
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                    Text("不吃")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                    Spacer()
                }
                .opacity(min(Double(abs(offset.width)) / 150.0, 1.0))
            }
        }
        .animation(.easeInOut(duration: 0.1), value: offset)
    }
    
    // MARK: - 处理滑动结束
    private func handleSwipeEnd(_ gesture: DragGesture.Value) {
        let threshold: CGFloat = 150
        
        if gesture.translation.width > threshold {
            eatAction()
        } else if gesture.translation.width < -threshold {
            passAction()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                offset = .zero
                cardRotation = 0
            }
        }
    }
    
    // MARK: - 想吃动作
    private func eatAction() {
        guard currentIndex < filteredRestaurants.count else { return }
        
        let restaurant = filteredRestaurants[currentIndex]
        selectedRestaurant = restaurant
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            offset = CGSize(width: 500, height: 0)
            cardRotation = 15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showEatConfirmation = true
            currentIndex += 1
            offset = .zero
            cardRotation = 0
            nextCardOpacity = 0.0
        }
    }
    
    // MARK: - 不吃动作
    private func passAction() {
        guard currentIndex < filteredRestaurants.count else { return }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            offset = CGSize(width: -500, height: 0)
            cardRotation = -15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentIndex += 1
            offset = .zero
            cardRotation = 0
            nextCardOpacity = 0.0
        }
    }
    
    // MARK: - 交互按钮
    private var actionButtons: some View {
        HStack(spacing: 48) {
            // 不吃按钮 - 黑色圆形背景 + 白色图标
            Button {
                passAction()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .pressableButton()
            
            // 想吃按钮 - 红色圆形背景 + 白色图标
            Button {
                eatAction()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accent)
                        .frame(width: 64, height: 64)
                        .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .pressableButton()
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling")
                .font(.system(size: 80))
                .foregroundColor(Color(hex: "#89CFF0"))
            
            Text("哎呀，都划完了")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("要不重新筛选一下？")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Button {
                currentIndex = 0
            } label: {
                Text("重新开始")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#89CFF0"))
                    )
            }
            .padding(.top, 10)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - 预览
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    
    return GourmetMatchView()
        .modelContainer(container)
}
