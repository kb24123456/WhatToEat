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
    
    // 区域内搜索状态
    @State private var initialCenterCoordinate: CLLocationCoordinate2D?
    @State private var hasUserInteractedWithMap: Bool = false
    private let regionChangeThreshold: CLLocationDistance = 500 // 移动超过500米后重置
    
    // 地图缩放级别对应的聚类距离
    private var dynamicClusteringDistance: CLLocationDistance {
        // 根据地图缩放级别动态调整聚类距离
        guard let region = visibleRegion else { return 200 }
        // 缩放级别越小（地图越缩小），聚类距离越大
        let spanDelta = max(region.span.latitudeDelta, region.span.longitudeDelta)
        if spanDelta > 0.5 {
            return 2000 // 大范围视图：2000米聚类
        } else if spanDelta > 0.2 {
            return 1000 // 中等范围：1000米聚类
        } else if spanDelta > 0.05 {
            return 500 // 较小范围：500米聚类
        } else {
            return 200 // 小范围：200米聚类
        }
    }
    
    // 选中的餐厅（用于详情抽屉）
    @State private var selectedRestaurant: Restaurant?
    
    // MARK: - 导航状态与路线变量
    @State private var route: MKRoute?
    @State private var isNavigating: Bool = false
    @State private var navigationSheetHeight: PresentationDetent = .fraction(0.65)
    @State private var routeUpdateTimer: Timer?
    @State private var showExitNavigationButton: Bool = false
    @State private var navigatingRestaurant: Restaurant? // 导航中的餐厅（独立于selectedRestaurant）
    
    // 聚合后的餐厅组（仅在当前区域内显示）
    private var clusteredRestaurants: [RestaurantCluster] {
        let filtered = filterRestaurants()
        return calculateClusters(from: filtered)
    }
    
    // 筛选餐厅（搜索 + 区域 + 有效坐标）
    private func filterRestaurants() -> [Restaurant] {
        // 搜索筛选
        var result = restaurants
        if !searchText.isEmpty {
            result = result.filter { r in
                r.name.localizedCaseInsensitiveContains(searchText) ||
                r.type.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 区域筛选
        if hasUserInteractedWithMap, let region = visibleRegion {
            result = result.filter { r in
                self.isInRegion(lat: r.latitude, lon: r.longitude, region: region)
            }
        }
        
        // 过滤无效坐标（latitude == 0 表示尚未获取坐标）
        result = result.filter { r in
            r.latitude != 0 || r.longitude != 0
        }
        
        return result
    }
    
    // 检查坐标是否在区域内
    private func isInRegion(lat: Double, lon: Double, region: MKCoordinateRegion) -> Bool {
        let halfLat = region.span.latitudeDelta / 2.0
        let halfLon = region.span.longitudeDelta / 2.0
        
        let minLat = region.center.latitude - halfLat
        let maxLat = region.center.latitude + halfLat
        let minLon = region.center.longitude - halfLon
        let maxLon = region.center.longitude + halfLon
        
        return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
    }
    
    var body: some View {
        ZStack {
            // MARK: - 地图层
            mapLayer
            
            // MARK: - 顶部遮罩与控件
            topOverlay
            
            // MARK: - 底部遮罩
            bottomOverlay
            
            // MARK: - 导航信息卡片和退出按钮（悬浮在地图上）
            if isNavigating && navigatingRestaurant != nil {
                navigationInfoOverlay
            }
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerView(selectedCity: $selectedCity)
        }
        // 导航模式下不显示餐厅详情抽屉
        .sheet(item: Binding(
            get: { isNavigating ? nil : selectedRestaurant },
            set: { selectedRestaurant = $0 }
        )) { restaurant in
            RestaurantDetailSheet(
                restaurant: restaurant,
                userLocation: locationManager.userLocation,
                isNavigating: $isNavigating,
                route: $route,
                onStartNavigation: { destination in
                    startNavigation(to: destination)
                },
                onExitNavigation: {
                    exitNavigation()
                }
            )
            .presentationDetents([.fraction(0.65), .large])
            .presentationBackground(.white)
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - 地图层
    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            // 聚合后的大头针
            ForEach(clusteredRestaurants) { cluster in
                mapAnnotation(for: cluster)
            }
            
            // 用户当前位置
            if let userLocation = locationManager.userLocation {
                Annotation("", coordinate: userLocation.coordinate) {
                    UserLocationAnnotation()
                }
            }
            
            // 导航路线
            if let route = route, isNavigating {
                MapPolyline(route)
                    .stroke(Color(hex: "#4CAF50").opacity(0.4), lineWidth: 14)
                MapPolyline(route)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#4CAF50"), Color(hex: "#66BB6A")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 8
                    )
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .ignoresSafeArea()
        .onAppear { setupInitialCameraPosition() }
        .onMapCameraChange { context in handleMapCameraChange(context.region) }
        .onChange(of: locationManager.userLocation) { _, newLocation in
            if let location = newLocation, !isNavigating {
                updateCameraToUserLocation(location)
            }
        }
    }
    
    // MARK: - 地图标注
    @MapContentBuilder
    private func mapAnnotation(for cluster: RestaurantCluster) -> some MapContent {
        if cluster.isCluster {
            Annotation("", coordinate: cluster.coordinate) {
                ClusterAnnotationView(count: cluster.restaurants.count)
            }
        } else if let restaurant = cluster.restaurants.first {
            let isDest = isNavigating && selectedRestaurant?.id == restaurant.id
            Annotation("", coordinate: cluster.coordinate) {
                GourmetAnnotation(
                    restaurant: restaurant,
                    isNavigating: isNavigating,
                    isDestination: isDest,
                    onSelect: handleRestaurantSelection
                )
            }
        }
    }
    
    // MARK: - 导航信息悬浮卡片（包含退出按钮）
    private var navigationInfoOverlay: some View {
        VStack {
            Spacer()
            
            if let restaurant = navigatingRestaurant {
                ZStack(alignment: .topTrailing) {
                    // 导航信息卡片主体
                    VStack(spacing: 0) {
                        NavigationInfoCard(
                            distance: calculateDistanceToRestaurant(restaurant),
                            drivingTime: calculateDrivingTimeToRestaurant(restaurant),
                            route: route
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .background(
                        // 高级立体感背景
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.95),
                                        Color.white
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(
                                color: Color.black.opacity(0.12),
                                radius: 20,
                                x: 0,
                                y: 8
                            )
                            .shadow(
                                color: Color(hex: "#89CFF0").opacity(0.15),
                                radius: 30,
                                x: 0,
                                y: 4
                            )
                    )
                    
                    // 退出按钮 - 放在卡片右上边缘，叠放样式
                    Button {
                        exitNavigation()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("退出")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .offset(x: 8, y: -12) // 向右上偏移，形成叠放效果
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - 计算到餐厅的距离（用于导航信息卡片）
    private func calculateDistanceToRestaurant(_ restaurant: Restaurant) -> String {
        guard let userLoc = locationManager.userLocation else { return "--" }
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
    
    // MARK: - 计算到餐厅的驾车时长（用于导航信息卡片）
    private func calculateDrivingTimeToRestaurant(_ restaurant: Restaurant) -> String {
        if let route = route {
            let minutes = Int(route.expectedTravelTime / 60)
            return "\(minutes)"
        }
        
        guard let userLoc = locationManager.userLocation else { return "--" }
        let restaurantLoc = CLLocation(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        let dist = userLoc.distance(from: restaurantLoc)
        let minutes = Int(dist / 500)
        if minutes < 1 {
            return "<1"
        } else {
            return "\(minutes)"
        }
    }
    
    // MARK: - 开始导航
    private func startNavigation(to destination: CLLocationCoordinate2D) {
        // 保存当前餐厅到导航餐厅
        navigatingRestaurant = selectedRestaurant
        
        isNavigating = true
        showExitNavigationButton = true
        
        // 关闭抽屉
        selectedRestaurant = nil
        
        // 隐藏底部导航条
        NotificationCenter.default.post(name: .hideTabBar, object: nil)
        
        // 计算路线
        Task {
            await calculateRoute(to: destination)
        }
        
        // 调整视角以显示完整路线
        adjustCameraForNavigation()
        
        // 启动定时器，每30秒更新一次路线
        routeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await calculateRoute(to: destination)
            }
        }
    }
    
    // MARK: - 退出导航
    private func exitNavigation() {
        isNavigating = false
        route = nil
        showExitNavigationButton = false
        navigatingRestaurant = nil
        
        // 停止定时器
        routeUpdateTimer?.invalidate()
        routeUpdateTimer = nil
        
        // 恢复底部导航条
        NotificationCenter.default.post(name: .restoreTabBar, object: nil)
    }
    
    // MARK: - 计算路线
    private func calculateRoute(to destination: CLLocationCoordinate2D) async {
        guard let userLocation = locationManager.userLocation?.coordinate else { return }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            if let route = response.routes.first {
                await MainActor.run {
                    self.route = route
                }
            }
        } catch {
            print("计算路线失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 调整导航视角
    private func adjustCameraForNavigation() {
        guard let userLocation = locationManager.userLocation?.coordinate,
              let destination = navigatingRestaurant else { return }
        
        let destinationCoordinate = CLLocationCoordinate2D(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        
        // 计算包含起点和终点的区域
        let minLat = min(userLocation.latitude, destinationCoordinate.latitude)
        let maxLat = max(userLocation.latitude, destinationCoordinate.latitude)
        let minLon = min(userLocation.longitude, destinationCoordinate.longitude)
        let maxLon = max(userLocation.longitude, destinationCoordinate.longitude)
        
        // 添加边距，确保起点和终点都能在视野内
        let latPadding = (maxLat - minLat) * 0.3 + 0.01
        let lonPadding = (maxLon - minLon) * 0.3 + 0.01
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) + latPadding * 2, 0.02),
            longitudeDelta: max((maxLon - minLon) + lonPadding * 2, 0.02)
        )
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
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
                
                if distance < dynamicClusteringDistance {
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
                        .init(color: Color.white.opacity(0.0), location: 0.2),   // 20%位置轻微白色
                        .init(color: Color.white.opacity(0.85), location: 0.65),    // 65%位置较明显
                        .init(color: Color.white.opacity(0.98), location: 0.85),   // 85%位置开始几乎纯白
                        .init(color: Color.white, location: 1.0)                  // 最下方纯白色（与导航栏衔接）
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)  // 过渡区域高度120pt
                
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
    
    // MARK: - 处理地图相机变化
    private func handleMapCameraChange(_ newRegion: MKCoordinateRegion) {
        visibleRegion = newRegion
        
        let newCenter = newRegion.center
        
        if let initialCenter = initialCenterCoordinate {
            let distance = calculateDistance(from: initialCenter, to: newCenter)
            
            if distance > regionChangeThreshold {
                hasUserInteractedWithMap = true
                initialCenterCoordinate = newCenter
            }
        } else {
            initialCenterCoordinate = newCenter
        }
    }
    
    // MARK: - 处理餐厅选择
    private func handleRestaurantSelection(_ selected: Restaurant) {
        selectedRestaurant = selected
        // 将选中餐厅移动到视野上方居中位置（避免被卡片遮挡）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            let offsetLatitude = 0.008
            let center = CLLocationCoordinate2D(
                latitude: selected.latitude - offsetLatitude,
                longitude: selected.longitude
            )
            let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
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
    let isNavigating: Bool
    let isDestination: Bool
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
    
    // 截断评论，限制最大字数
    private var truncatedReview: String {
        let maxLength = 12
        if restaurant.review.count <= maxLength {
            return restaurant.review
        }
        return String(restaurant.review.prefix(maxLength)) + "..."
    }
    
    // 气泡背景颜色：选中蓝色，未选中白色
    private var bubbleBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(hex: "#89CFF0").opacity(0.85),
                        Color(hex: "#89CFF0").opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(Color.white)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 常驻评论气泡，限制最大字数与气泡长度
            if !restaurant.review.isEmpty {
                Text(truncatedReview)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                    .frame(maxWidth: 120)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(bubbleBackground)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .offset(y: -8)
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
                
                // MARK: - 导航模式下的终点波纹动画
                if isDestination && isNavigating {
                    RippleAnimation()
                }
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

// MARK: - 波纹动画组件
struct RippleAnimation: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color(hex: "#89CFF0").opacity(0.6), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(animate ? 1.5 : 0.8)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
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
            // 外圈光晕效果
            Circle()
                .fill(AppTheme.Colors.accent.opacity(0.15))
                .frame(width: 56, height: 56)
            
            // 主圆形背景
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.accent,
                            AppTheme.Colors.accent.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
            
            // 数量文字
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
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

// MARK: - 城市选择器视图（与 LibraryView 样式一致）
struct CityPickerView: View {
    @Binding var selectedCity: String
    @Environment(\.dismiss) private var dismiss
    
    // 搜索文本
    @State private var searchText = ""
    
    // 定位管理器
    @ObservedObject private var locationManager = LocationManager.shared
    
    // 筛选后的城市列表
    private var filteredCities: [String] {
        if searchText.isEmpty {
            return RegionManager.shared.allCities
        } else {
            return RegionManager.shared.allCities.filter { $0.contains(searchText) }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // 1. 自定义导航栏
                customNavigationBar
                
                // 2. 自定义搜索栏
                customSearchBar
                
                // 3. 当前定位卡片
                locationCard
                
                // 4. 城市列表标题
                cityListTitle
                
                // 5. 城市网格列表
                cityGrid
            }
        }
        .edgesIgnoringSafeArea(.all)
        .background(MilkyDiffuseBackground())
        .onAppear {
            // 确保位置管理器已启动
            locationManager.requestLocationPermission()
        }
    }
    
    // MARK: - 自定义导航栏
    private var customNavigationBar: some View {
        HStack {
            // 左侧：取消按钮
            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            Spacer()
            
            // 中间：标题
            Text("选择城市")
                .font(AppTheme.Fonts.title3)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            // 右侧：占位，保持标题居中
            Color.clear
                .frame(width: 44)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, 44)
        .padding(.bottom, AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
    }
    
    // MARK: - 自定义搜索栏
    private var customSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("搜索城市", text: $searchText)
                .font(AppTheme.Fonts.footnote)
        }
        .padding(AppTheme.Spacing.md)
        .background(Color(.systemGray6))
        .cornerRadius(AppTheme.Radius.base)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    // MARK: - 当前定位卡片
    private var locationCard: some View {
        Button {
            if let city = locationManager.currentCity {
                selectedCity = city
                dismiss()
            }
        } label: {
            HStack {
                // 定位图标
                Image(systemName: "location.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(locationManager.currentCity != nil ? AppTheme.Colors.accent : .gray)
                    .font(AppTheme.Fonts.headline)
                
                // 城市名或定位中
                if let city = locationManager.currentCity {
                    Text(city)
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                } else {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.gray)
                        Text("定位中...")
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // 右箭头
                if locationManager.currentCity != nil {
                    Image(systemName: "chevron.right")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .fill(AppTheme.Colors.card)
                    .shadow(
                        color: AppTheme.Shadows.light.color,
                        radius: AppTheme.Shadows.light.radius,
                        x: AppTheme.Shadows.light.x,
                        y: AppTheme.Shadows.light.y
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                            .stroke(AppTheme.Colors.divider, lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: UIScreen.main.bounds.width / 3)
        .buttonStyle(.plain)
        .disabled(locationManager.currentCity == nil)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - 城市列表标题
    private var cityListTitle: some View {
        HStack {
            Text("所有城市")
                .font(AppTheme.Fonts.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - 城市网格列表
    private var cityGrid: some View {
        // 定义自适应网格列
        let columns = [GridItem(.adaptive(minimum: 70, maximum: 120), spacing: AppTheme.Spacing.md)]
        
        return LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
            ForEach(filteredCities, id: \.self) { city in
                cityTag(city: city)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - 城市Tag
    private func cityTag(city: String) -> some View {
        Button {
            selectedCity = city
            dismiss()
        } label: {
            Text(city)
                .font(AppTheme.Fonts.footnote)
                .foregroundColor(city == selectedCity ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(city == selectedCity ? AppTheme.Colors.accent : AppTheme.Colors.lightGray)
                .cornerRadius(AppTheme.Radius.circle)
                .shadow(
                    color: city == selectedCity ? AppTheme.Shadows.elevated.color : AppTheme.Shadows.light.color,
                    radius: city == selectedCity ? AppTheme.Shadows.elevated.radius : AppTheme.Shadows.light.radius,
                    x: city == selectedCity ? AppTheme.Shadows.elevated.x : AppTheme.Shadows.light.x,
                    y: city == selectedCity ? AppTheme.Shadows.elevated.y : AppTheme.Shadows.light.y
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 餐厅详情抽屉
struct RestaurantDetailSheet: View {
    let restaurant: Restaurant
    let userLocation: CLLocation?
    @Binding var isNavigating: Bool
    @Binding var route: MKRoute?
    @Environment(\.dismiss) private var dismiss
    @State private var showCheckInView: Bool = false
    @State private var isFavorite: Bool = false
    
    var onStartNavigation: (CLLocationCoordinate2D) -> Void
    var onExitNavigation: () -> Void
    
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
        if let route = route, isNavigating {
            let minutes = Int(route.expectedTravelTime / 60)
            return "\(minutes)"
        }
        
        guard let userLoc = userLocation else { return "--" }
        let restaurantLoc = CLLocation(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        let dist = userLoc.distance(from: restaurantLoc)
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
                    
                    // 导航模式：显示实时导航信息
                    if isNavigating {
                        NavigationInfoCard(
                            distance: distance,
                            drivingTime: drivingTime,
                            route: route
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    } else {
                        // 普通模式：高亮行 (Baby Blue)：距离 + 预计驾车时长
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
                    }
                    
                    // 一句话点评（原地点介绍）
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
                    
                    // 统计信息（人均消费、累积打卡、总消费、标签）
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
                // 底部工具栏
                bottomToolbar
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCheckInView) {
                CheckInView(restaurant: restaurant, onClose: {
                    showCheckInView = false
                })
            }
        }
    }
    
    // MARK: - 底部工具栏
    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            Spacer() // 将按钮推到右侧
            
            if isNavigating {
                // 导航模式：显示退出导航按钮
                Button {
                    onExitNavigation()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                        Text("退出导航")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 40)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.8))
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                }
            } else {
                // 普通模式：打卡和导航按钮
                // 打卡按钮
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
                
                // 导航按钮（内置导航）
                Button {
                    let destination = CLLocationCoordinate2D(
                        latitude: restaurant.latitude,
                        longitude: restaurant.longitude
                    )
                    onStartNavigation(destination)
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }
}

// MARK: - 导航信息卡片
struct NavigationInfoCard: View {
    let distance: String
    let drivingTime: String
    let route: MKRoute?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                // 剩余距离 - 删除图标，使用黑色rounded字体
                VStack(spacing: 4) {
                    Text("\(distance)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text("km")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.black.opacity(0.6))
                    Text("剩余距离")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .frame(height: 50)
                
                // 预计到达时间 - 删除图标，使用黑色rounded字体
                VStack(spacing: 4) {
                    Text("\(drivingTime)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text("分钟")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.black.opacity(0.6))
                    Text("预计时间")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                if let route = route {
                    Divider()
                        .frame(height: 50)
                    
                    // 路线距离 - 删除图标，使用黑色rounded字体
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", route.distance / 1000))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        Text("km")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.black.opacity(0.6))
                        Text("路线长度")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
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


