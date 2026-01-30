import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - 餐厅地图视图 (食图页面)
struct RestaurantMapView: View {
    // 从外部传入的餐厅数据（不直接查询数据库）
    let restaurants: [Restaurant]
    
    @ObservedObject var locationManager: LocationManager = LocationManager()
    
    // 搜索与筛选状态
    @State private var searchText: String = ""
    @State private var selectedCity: String = "重庆"
    @State private var showCityPicker: Bool = false
    
    // 地图状态
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var clusteringDistance: CLLocationDistance = 50 // 聚合距离（米）
    
    // 选中的餐厅（用于详情抽屉）
    @State private var selectedRestaurant: Restaurant?
    
    // 筛选后的餐厅
    private var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty {
            return restaurants
        }
        return restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(searchText) ||
            restaurant.type.localizedCaseInsensitiveContains(searchText) ||
            restaurant.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // 聚合后的餐厅组
    private var clusteredRestaurants: [RestaurantCluster] {
        calculateClusters(from: filteredRestaurants)
    }
    
    var body: some View {
        ZStack {
            // MARK: - 地图层（使用 MapContentBuilder 优化）
            Map(position: $cameraPosition) {
                // 使用 MapContentBuilder 渲染聚合后的大头针
                ForEach(clusteredRestaurants) { cluster in
                    if cluster.isCluster {
                        // 聚合点
                        Annotation("", coordinate: cluster.coordinate) {
                            ClusterAnnotationView(count: cluster.restaurants.count)
                        }
                    } else if let restaurant = cluster.restaurants.first {
                        // 单个餐厅大头针
                        Annotation("", coordinate: cluster.coordinate) {
                            GourmetAnnotation(restaurant: restaurant) { selected in
                                selectedRestaurant = selected
                                // 任务1：将选中餐厅移动到视野上方居中位置（避免被卡片遮挡）
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    // 计算向上偏移的坐标（约屏幕高度的 1/4）
                                    let offsetLatitude = 0.008  // 向上偏移的纬度值
                                    cameraPosition = .region(MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(
                                            latitude: selected.latitude - offsetLatitude,
                                            longitude: selected.longitude
                                        ),
                                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                    ))
                                }
                            }
                        }
                    }
                }
                
                // 显示用户当前位置
                if let userLocation = locationManager.userLocation {
                    Annotation("", coordinate: userLocation.coordinate) {
                        UserLocationAnnotation()
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea()
            .onAppear {
                setupInitialCameraPosition()
            }
            .onChange(of: locationManager.userLocation) { _, newLocation in
                if let location = newLocation {
                    updateCameraToUserLocation(location)
                }
            }
            
            // MARK: - 顶部遮罩与控件
            topOverlay
            
            // MARK: - 底部遮罩
            bottomOverlay
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerView(selectedCity: $selectedCity)
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantDetailSheet(
                restaurant: restaurant,
                userLocation: locationManager.userLocation
            )
            .presentationDetents([.fraction(0.65), .large])  // 任务3：默认高度65%（参考图3，显示更多信息）
            .presentationBackground(.white)
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - 计算聚合点
    private func calculateClusters(from restaurants: [Restaurant]) -> [RestaurantCluster] {
        guard !restaurants.isEmpty else { return [] }
        
        var clusters: [RestaurantCluster] = []
        var processed = Set<UUID>()
        
        for restaurant in restaurants {
            guard !processed.contains(restaurant.id) else { continue }
            
            let coordinate = CLLocationCoordinate2D(
                latitude: restaurant.latitude,
                longitude: restaurant.longitude
            )
            
            // 找到附近的所有餐厅
            var nearbyRestaurants: [Restaurant] = [restaurant]
            processed.insert(restaurant.id)
            
            for other in restaurants {
                guard !processed.contains(other.id) else { continue }
                
                let otherCoordinate = CLLocationCoordinate2D(
                    latitude: other.latitude,
                    longitude: other.longitude
                )
                
                let distance = calculateDistance(from: coordinate, to: otherCoordinate)
                
                if distance < clusteringDistance {
                    nearbyRestaurants.append(other)
                    processed.insert(other.id)
                }
            }
            
            // 计算聚合中心点
            let avgLat = nearbyRestaurants.map(\.latitude).reduce(0, +) / Double(nearbyRestaurants.count)
            let avgLon = nearbyRestaurants.map(\.longitude).reduce(0, +) / Double(nearbyRestaurants.count)
            
            let cluster = RestaurantCluster(
                id: restaurant.id,
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                restaurants: nearbyRestaurants,
                isCluster: nearbyRestaurants.count > 1
            )
            clusters.append(cluster)
        }
        
        return clusters
    }
    
    // MARK: - 计算两点距离（米）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }
    
    // MARK: - 顶部遮罩与控件（参考图1：柔和渐变效果）
    private var topOverlay: some View {
        VStack(spacing: 0) {
            // 顶部渐变遮罩 - 参考图1的柔和过渡
            LinearGradient(
                stops: [
                    .init(color: Color.white, location: 0.0),
                    .init(color: Color.white.opacity(0.98), location: 0.15),
                    .init(color: Color.white.opacity(0.85), location: 0.35),
                    .init(color: Color.white.opacity(0.5), location: 0.6),
                    .init(color: Color.white.opacity(0.2), location: 0.8),
                    .init(color: Color.white.opacity(0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
            .ignoresSafeArea()
            
            Spacer()
        }
        .overlay(
            // 顶部控件
            VStack(spacing: 12) {
                // 第一行：城市选择器 + 搜索框
                HStack(spacing: 12) {
                    // 左侧城市选择器
                    Button {
                        showCityPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#89CFF0"))
                            Text(selectedCity)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.white)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                                )
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // 右侧搜索框
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        TextField("搜索餐厅", text: $searchText)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 130)
                    .background(
                        Capsule()
                            .fill(.white)
                            .overlay(
                                Capsule()
                                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                }
                
                // 天气信息
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#FFB800"))
                    
                    Text("24°C")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.darkText)
                    
                    Text("晴朗")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)  // 任务1：上移控件，更靠近顶部
            , alignment: .top
        )
    }
    
    // MARK: - 底部遮罩（导航栏上方的渐变过渡区域）
    private var bottomOverlay: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                
                // 渐变过渡区域：从地图到底部导航栏的白色
                // 这个区域位于导航栏上方，实现平滑过渡效果
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0), location: 0.0),       // 最上方完全透明（显示地图）
                        .init(color: Color.white.opacity(0.45), location: 0.2),   // 20%位置轻微白色
                        .init(color: Color.white.opacity(0.65), location: 0.4),    // 40%位置较明显
                        .init(color: Color.white.opacity(0.85), location: 0.65),   // 65%位置较强
                        .init(color: Color.white.opacity(0.95), location: 0.85),   // 85%位置接近白色
                        .init(color: Color.white, location: 1.0)                  // 最下方纯白色（与导航栏衔接）
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)  // 过渡区域高度180pt
                
                // 纯白色区域，与导航栏背景颜色一致
                Color.white
                    .frame(height: geometry.safeAreaInsets.bottom + 64)  // 安全区 + 导航栏高度
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - 设置初始相机位置
    private func setupInitialCameraPosition() {
        if let userLocation = locationManager.userLocation {
            updateCameraToUserLocation(userLocation)
        } else if let firstRestaurant = restaurants.first {
            let coordinate = CLLocationCoordinate2D(
                latitude: firstRestaurant.latitude,
                longitude: firstRestaurant.longitude
            )
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }
    
    // MARK: - 更新相机到用户位置
    private func updateCameraToUserLocation(_ location: CLLocation) {
        cameraPosition = .region(MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
}

// MARK: - 餐厅聚合模型
struct RestaurantCluster: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let restaurants: [Restaurant]
    let isCluster: Bool
}

// MARK: - 奶脂大头针组件 (GourmetAnnotation)
struct GourmetAnnotation: View {
    let restaurant: Restaurant
    @State private var isSelected: Bool = false
    var onSelect: (Restaurant) -> Void
    
    // 判断是否已打卡
    private var isCheckedIn: Bool {
        !restaurant.logs.isEmpty
    }
    
    // 边框颜色：已打卡用小红书红，未打卡用 milkyWhite
    private var borderColor: Color {
        isCheckedIn ? AppTheme.Colors.accent : AppTheme.Colors.milkyWhite
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 任务1：白色无边框气泡，显示一句话点评
            if !restaurant.review.isEmpty {
                Text(restaurant.review)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        // 任务1：气泡背景改为 BabyBlue 到白色的渐变色
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? 
                                AnyShapeStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#89CFF0").opacity(0.85),
                                            Color.white.opacity(0.9)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                ) : 
                                AnyShapeStyle(Color.white)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                    .offset(y: -10)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            
            // 头像层：40pt 圆形
            ZStack {
                // 外圈边框
                Circle()
                    .fill(borderColor)
                    .frame(width: 46, height: 46)
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                
                // 封面图 - 任务2：选中时轻微放大
                AsyncImageView(
                    filename: restaurant.coverPhotoFilename,
                    placeholder: AnyView(
                        ZStack {
                            Circle()
                                .fill(AppTheme.Colors.primary.opacity(0.1))
                            Image(systemName: "fork.knife")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    )
                )
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
            }
            
            // 小三角形指针
            Triangle()
                .fill(borderColor)
                .frame(width: 10, height: 6)
                .offset(y: -1)
            
            // 餐厅名称
            Text(restaurant.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.Colors.darkText)
                .lineLimit(1)
                .shadow(color: Color.white, radius: 2, x: 0, y: 0)
                .padding(.top, 2)
        }
        .onTapGesture {
            // 任务2：震动反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // 切换选中状态
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isSelected.toggle()
            }
            
            // 触发选中回调
            onSelect(restaurant)
        }
    }
}

// MARK: - 三角形指针
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 聚合点视图
struct ClusterAnnotationView: View {
    let count: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.milkyWhite)
                .frame(width: 44, height: 44)
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            
            Circle()
                .stroke(AppTheme.Colors.accent.opacity(0.3), lineWidth: 2)
                .frame(width: 44, height: 44)
            
            Text("+\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.Colors.darkText)
        }
    }
}

// MARK: - 用户位置标记
struct UserLocationAnnotation: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 24, height: 24)
            
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        }
    }
}

// MARK: - 城市选择器视图
struct CityPickerView: View {
    @Binding var selectedCity: String
    @Environment(\.dismiss) private var dismiss
    
    let cities = ["重庆", "北京", "上海", "广州", "深圳", "成都", "杭州", "武汉"]
    
    var body: some View {
        NavigationView {
            List(cities, id: \.self) { city in
                Button {
                    selectedCity = city
                    dismiss()
                } label: {
                    HStack {
                        Text(city)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        if city == selectedCity {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.accent)
                        }
                    }
                }
            }
            .navigationTitle("选择城市")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 餐厅详情抽屉
struct RestaurantDetailSheet: View {
    let restaurant: Restaurant
    let userLocation: CLLocation?
    @Environment(\.dismiss) private var dismiss
    @State private var showNavigationOptions = false
    @State private var showCheckInView = false
    @State private var isFavorite = false
    
    // 计算距离
    private var distance: String {
        guard let userLoc = userLocation else { return "--" }
        let restaurantLoc = CLLocation(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        let dist = userLoc.distance(from: restaurantLoc)
        if dist < 1000 {
            return String(format: "%.0f", dist)
        } else {
            return String(format: "%.1f", dist / 1000)
        }
    }
    
    // 计算预计驾车时长（分钟）
    private var drivingTime: String {
        guard let userLoc = userLocation else { return "--" }
        let restaurantLoc = CLLocation(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        let dist = userLoc.distance(from: restaurantLoc)
        // 假设平均车速 30km/h = 500m/min
        let minutes = Int(dist / 500)
        if minutes < 1 {
            return "<1"
        } else {
            return "\(minutes)"
        }
    }
    
    // 获取最新打卡评价
    private var latestLog: VisitLog? {
        restaurant.logs.sorted { $0.date > $1.date }.first
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 横向铺满的圆角大图
                    AsyncImageView(
                        filename: restaurant.coverPhotoFilename,
                        placeholder: AnyView(
                            ZStack {
                                Color.gray.opacity(0.2)
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        )
                    )
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // 头部：大字餐厅名 + 评分星级
                    HStack(alignment: .center, spacing: 12) {
                        Text(restaurant.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.Colors.darkText)
                        
                        Spacer()
                        
                        // 评分星级
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#FFB800"))
                            Text("\(Int(restaurant.rating))")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.darkText)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // 高亮行 (Baby Blue)：距离 + 预计驾车时长
                    HStack(spacing: 24) {
                        // 距离
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#89CFF0"))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(distance) km")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#89CFF0"))
                                Text("距离")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.gray)
                            }
                        }
                        
                        // 预计驾车时长
                        HStack(spacing: 6) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#89CFF0"))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(drivingTime) 分钟")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#89CFF0"))
                                Text("预计驾车")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.gray)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // 任务3：一句话点评（原地点介绍）
                    if !restaurant.review.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("一句话点评")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(restaurant.review)
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.Colors.darkText)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    // 任务4：统计信息（人均消费、累积打卡、总消费、标签）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 20) {
                            // 人均消费
                            StatItem(
                                icon: "person.fill",
                                value: restaurant.averagePrice > 0 ? "¥\(Int(restaurant.averagePrice))" : "--",
                                label: "人均消费"
                            )
                            
                            // 累积打卡次数
                            StatItem(
                                icon: "checkmark.circle.fill",
                                value: "\(restaurant.checkInCount)",
                                label: "累计打卡"
                            )
                            
                            // 总消费金额
                            StatItem(
                                icon: "creditcard.fill",
                                value: restaurant.totalExpense > 0 ? "¥\(Int(restaurant.totalExpense))" : "--",
                                label: "总消费"
                            )
                        }
                        
                        // 标签
                        if !restaurant.tags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(restaurant.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.darkText)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color(hex: "#89CFF0").opacity(0.15))
                                        )
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // 最新打卡评价
                    if let log = latestLog {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最新打卡")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 12) {
                                // 日期
                                Text(log.date, style: .date)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                
                                // 消费金额
                                if log.expense > 0 {
                                    Text("¥\(Int(log.expense))")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                                
                                Spacer()
                            }
                            
                            if !log.review.isEmpty {
                                Text(log.review)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.darkText)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    // 底部留白（为工具栏预留空间）
                    Spacer()
                        .frame(height: 80)
                }
            }
            .background(Color.white)
            .safeAreaInset(edge: .bottom) {
                // 任务5：底部工具栏（参考图3，删除收藏按钮）
                bottomToolbar
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .confirmationDialog("选择导航应用", isPresented: $showNavigationOptions, titleVisibility: .visible) {
                Button("苹果地图") {
                    openAppleMaps()
                }
                Button("高德地图") {
                    openAMap()
                }
                Button("百度地图") {
                    openBaiduMap()
                }
                Button("取消", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCheckInView) {
                CheckInView(restaurant: restaurant, onClose: {
                    showCheckInView = false
                })
            }
        }
    }
    
    // MARK: - 底部工具栏（自适应宽度、右对齐、阴影样式）
    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            Spacer() // 将按钮推到右侧
            
            // 打卡按钮（自适应宽度、加大字号、阴影样式）
            Button {
                showCheckInView = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                    Text("打卡")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
            
            // 导航按钮（自适应宽度、加大字号、阴影样式）
            Button {
                showNavigationOptions = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                    Text("导航")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // MARK: - 打开苹果地图
    private func openAppleMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: restaurant.latitude, longitude: restaurant.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // MARK: - 打开高德地图
    private func openAMap() {
        let urlString = "iosamap://path?sourceApplication=WhatToEat&dlat=\(restaurant.latitude)&dlon=\(restaurant.longitude)&dname=\(restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&dev=0&t=0"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 未安装高德地图，跳转到 App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/%E9%AB%98%E5%BE%B7%E5%9C%B0%E5%9B%BE/id461703208") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
    
    // MARK: - 打开百度地图
    private func openBaiduMap() {
        let urlString = "baidumap://map/direction?origin=latlng:\(userLocation?.coordinate.latitude ?? 0),\(userLocation?.coordinate.longitude ?? 0)|name:我的位置&destination=latlng:\(restaurant.latitude),\(restaurant.longitude)|name:\(restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&mode=driving"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 未安装百度地图，跳转到 App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/%E7%99%BE%E5%BA%A6%E5%9C%B0%E5%9B%BE/id452186370") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
}

// MARK: - 统计项组件
private struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#89CFF0"))
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.darkText)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - VisualEffectBlur 组件（用于磨砂效果）
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}


