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
        .sheet(isPresented: $showEatConfirmation) {
            if let restaurant = selectedRestaurant {
                RestaurantSelectionDetailView(
                    restaurant: restaurant,
                    locationManager: locationManager,
                    onClose: {
                        showEatConfirmation = false
                    },
                    onContinue: {
                        showEatConfirmation = false
                    }
                )
            }
        }
    }
    
    // MARK: - 顶部筛选器 (与 LibraryView 完全一致)
    private var filterBar: some View {
        HStack(spacing: 12) {
            // 1. 地区筛选
            Menu {
                // 全区选项
                Button("全区") { selectedDistrict = "全部" }
                Divider()
                // 动态获取区列表
                ForEach(districts.filter { $0 != "全部" }, id: \.self) { district in
                    Button(district) { selectedDistrict = district }
                }
            } label: {
                HStack {
                    Text(selectedDistrict == "全部" ? "地区" : selectedDistrict)
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
                Button("全部分类") { selectedType = "全部" }
                Divider()
                // 动态获取所有餐厅类型
                ForEach(types.filter { $0 != "全部" }, id: \.self) { type in
                    Button(type) { selectedType = type }
                }
            } label: {
                HStack {
                    Text(selectedType == "全部" ? "品类" : selectedType)
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
    
    // MARK: - Misty Oreo: 去容器化游戏卡片
    private func matchCard(for restaurant: Restaurant, cardSize: CGSize, isTop: Bool) -> some View {
        ZStack(alignment: .bottom) {
            // Misty Oreo: 图片直接浮动，无白色背景容器
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    ZStack {
                        AppTheme.Colors.babyBlue.opacity(0.1)
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.3))
                    }
                )
            )
            .scaledToFill()
            .frame(width: cardSize.width, height: cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous)) // 3:4 比例，40pt 圆角
            // Misty Oreo: 内阴影 - 高级相框质感
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.12),
                                Color.clear,
                                Color.clear,
                                Color.black.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )

            // Misty Oreo: 底部磨砂遮罩 + 文字浮层
            VStack(alignment: .leading, spacing: 8) {
                // 店名 - 白色带微弱投影
                Text(restaurant.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .lineLimit(1)

                // 副标题 - Baby Blue
                HStack(spacing: 12) {
                    Text(restaurant.type)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.babyBlue)

                    if restaurant.averagePrice > 0 {
                        Text("¥\(Int(restaurant.averagePrice))/人")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.8))
                    }

                    if let userLocation = locationManager.userLocation {
                        let distance = userLocation.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
                        Text(distance < 1000 ? String(format: "%.0fm", distance) : String(format: "%.1fkm", distance / 1000))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.8))
                    }
                }

                // 点评预览
                if !restaurant.review.isEmpty {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(AppTheme.Colors.babyBlue)
                            .frame(width: 2, height: 14)

                        Text(restaurant.review)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(
                // Material Mask - 磨砂遮罩
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            )

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
    
    // MARK: - Misty Oreo: 交互按钮 - 去除多余修饰
    private var actionButtons: some View {
        HStack(spacing: 48) {
            // 不吃按钮 - 哑光黑
            Button {
                passAction()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.85)) // 哑光黑
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .oreoClickEffect(style: .medium)
            
            // 想吃按钮 - 小红书红
            Button {
                eatAction()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.xhsRed) // 小红书红
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .oreoClickEffect(style: .light)
        }
    }
    
    // MARK: - Oreo: 极致情感化空状态
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // 图标占据屏幕上方 1/3
            Image(systemName: "face.smiling")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(AppTheme.Colors.babyBlue)
                .padding(.top, 40)

            // 标题 17pt Bold 黑色
            Text("都品尝过了")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.Colors.darkText)
                .tracking(0.5)

            // 描述 14pt Italic 灰色
            Text("换个筛选条件，继续探索美食世界")
                .font(.system(size: 14, weight: .regular))
                .italic()
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                currentIndex = 0
            } label: {
                Text("再来一轮")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.babyBlue)
                    )
            }
            .oreoClickEffect(style: .light)
            .padding(.top, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - 预览
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    
    return GourmetMatchView()
        .modelContainer(container)
}
