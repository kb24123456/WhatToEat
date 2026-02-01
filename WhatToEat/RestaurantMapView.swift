import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - 任务队列（用于串行化后台计算）
private actor TaskQueue {
    private var currentTask: Task<Void, Never>?
    
    func enqueue(_ operation: @escaping () async -> Void) {
        // 取消之前的任务
        currentTask?.cancel()
        
        // 创建新任务
        currentTask = Task {
            await operation()
        }
    }
    
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}

// MARK: - 空间索引节点
private class SpatialIndexNode {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    var restaurants: [Restaurant] = []
    var children: [SpatialIndexNode]?
    
    init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.minLat = minLat
        self.maxLat = maxLat
        self.minLon = minLon
        self.maxLon = maxLon
    }
    
    var isLeaf: Bool { children == nil }
    func contains(lat: Double, lon: Double) -> Bool {
        return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
    }
    
    func intersects(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) -> Bool {
        return !(maxLat < self.minLat || minLat > self.maxLat || maxLon < self.minLon || minLon > self.maxLon)
    }
}

// MARK: - 餐厅空间索引
private class RestaurantSpatialIndex {
    private let root: SpatialIndexNode
    private let maxDepth = 8
    private let maxItemsPerNode = 10
    
    init(restaurants: [Restaurant]) {
        // 计算边界
        let lats = restaurants.map { $0.latitude }
        let lons = restaurants.map { $0.longitude }
        let minLat = lats.min() ?? -90
        let maxLat = lats.max() ?? 90
        let minLon = lons.min() ?? -180
        let maxLon = lons.max() ?? 180
        
        root = SpatialIndexNode(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
        
        // 构建索引
        for restaurant in restaurants {
            insert(restaurant, into: root, depth: 0)
        }
    }
    
    private func insert(_ restaurant: Restaurant, into node: SpatialIndexNode, depth: Int) {
        // 如果节点不包含该餐厅，返回
        if !node.contains(lat: restaurant.latitude, lon: restaurant.longitude) {
            return
        }
        
        // 如果是叶子节点
        if node.isLeaf {
            node.restaurants.append(restaurant)
            
            // 如果超过容量且未达到最大深度，分裂节点
            if node.restaurants.count > maxItemsPerNode && depth < maxDepth {
                subdivide(node, depth: depth)
            }
        } else {
            // 插入到子节点
            for child in node.children! {
                if child.contains(lat: restaurant.latitude, lon: restaurant.longitude) {
                    insert(restaurant, into: child, depth: depth + 1)
                    break
                }
            }
        }
    }
    
    private func subdivide(_ node: SpatialIndexNode, depth: Int) {
        let midLat = (node.minLat + node.maxLat) / 2
        let midLon = (node.minLon + node.maxLon) / 2
        
        // 创建四个子象限
        node.children = [
            SpatialIndexNode(minLat: node.minLat, maxLat: midLat, minLon: node.minLon, maxLon: midLon),
            SpatialIndexNode(minLat: node.minLat, maxLat: midLat, minLon: midLon, maxLon: node.maxLon),
            SpatialIndexNode(minLat: midLat, maxLat: node.maxLat, minLon: node.minLon, maxLon: midLon),
            SpatialIndexNode(minLat: midLat, maxLat: node.maxLat, minLon: midLon, maxLon: node.maxLon)
        ]
        
        // 重新分配餐厅到子节点
        for restaurant in node.restaurants {
            for child in node.children! {
                if child.contains(lat: restaurant.latitude, lon: restaurant.longitude) {
                    child.restaurants.append(restaurant)
                    break
                }
            }
        }
        
        // 清空当前节点的餐厅列表（只保留在子节点中）
        node.restaurants = []
    }
    
    // 查询区域内的餐厅
    func query(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) -> [Restaurant] {
        var result: [Restaurant] = []
        query(node: root, minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon, result: &result)
        return result
    }
    
    private func query(node: SpatialIndexNode, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, result: inout [Restaurant]) {
        // 如果节点与查询区域不相交，返回
        if !node.intersects(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon) {
            return
        }
        
        // 如果是叶子节点，检查每个餐厅
        if node.isLeaf {
            for restaurant in node.restaurants {
                if restaurant.latitude >= minLat && restaurant.latitude <= maxLat &&
                   restaurant.longitude >= minLon && restaurant.longitude <= maxLon {
                    result.append(restaurant)
                }
            }
        } else {
            // 递归查询子节点
            for child in node.children! {
                query(node: child, minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon, result: &result)
            }
        }
    }
}

// MARK: - 聚类缓存键
private struct ClusterCacheKey: Hashable {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    let zoomLevel: MapZoomLevel
    
    init(region: MKCoordinateRegion, zoomLevel: MapZoomLevel) {
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        self.minLat = region.center.latitude - halfLat
        self.maxLat = region.center.latitude + halfLat
        self.minLon = region.center.longitude - halfLon
        self.maxLon = region.center.longitude + halfLon
        self.zoomLevel = zoomLevel
    }
}

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
    
    // MARK: - 性能优化：空间索引与缓存
    @State private var spatialIndex: RestaurantSpatialIndex?
    @State private var clusterCache: [ClusterCacheKey: [RestaurantCluster]] = [:]
    @State private var cachedClusters: [RestaurantCluster] = []
    @State private var lastClusteringRegion: MKCoordinateRegion?
    @State private var clusteringThrottleTimer: Timer?
    @State private var isClusteringPending: Bool = false
    
    // MARK: - 滑动检测与延迟计算
    @State private var isMapDragging: Bool = false
    @State private var dragEndTimer: Timer?
    @State private var settleTimer: Timer?
    private let dragEndDelay: TimeInterval = 0.75  // 滑动停止后等待0.75秒再计算
    
    // MARK: - 后台计算任务管理
    @State private var currentClusteringTask: Task<Void, Never>?
    @State private var calculationQueue = TaskQueue()
    
    // 最大显示餐厅数量
    private let maxVisibleRestaurants = 10
    
    // 可视区域边距比例（上下渐变区域不显示餐厅）
    private let visibleAreaInsetRatio: CGFloat = 0.25
    
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
    
    // 当前地图缩放级别
    private var currentZoomLevel: MapZoomLevel {
        guard let region = visibleRegion else { return .medium }
        let spanDelta = max(region.span.latitudeDelta, region.span.longitudeDelta)
        if spanDelta > 0.5 {
            return .far
        } else if spanDelta > 0.1 {
            return .medium
        } else {
            return .close
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
    
    // 聚合后的餐厅组（使用缓存）
    private var clusteredRestaurants: [RestaurantCluster] {
        // 如果缓存为空或区域变化较大，返回空数组（等待节流更新）
        if cachedClusters.isEmpty || shouldRecalculateClusters() {
            // 触发后台计算
            if !isClusteringPending {
                scheduleClusteringUpdate()
            }
            // 返回缓存或空数组
            return cachedClusters
        }
        return cachedClusters
    }
    
    // 筛选餐厅（搜索 + 可视区域 + 有效坐标）- 使用空间索引优化
    private func filterRestaurants() -> [Restaurant] {
        // 过滤无效坐标（latitude == 0 表示尚未获取坐标）
        let validRestaurants = restaurants.filter { $0.latitude != 0 || $0.longitude != 0 }
        
        // 搜索筛选（如果有搜索文本，不使用空间索引）
        if !searchText.isEmpty {
            return validRestaurants.filter { r in
                r.name.localizedCaseInsensitiveContains(searchText) ||
                r.type.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 区域筛选 - 使用空间索引加速
        if let region = visibleRegion {
            let halfLat = region.span.latitudeDelta / 2.0
            let halfLon = region.span.longitudeDelta / 2.0
            
            // 计算中间可视区域的边界（排除上下 25% 的渐变区域）
            let visibleHalfLat = halfLat * (1.0 - visibleAreaInsetRatio * 2)
            let minLat = region.center.latitude - visibleHalfLat
            let maxLat = region.center.latitude + visibleHalfLat
            let minLon = region.center.longitude - halfLon
            let maxLon = region.center.longitude + halfLon
            
            // 使用空间索引查询
            if let index = spatialIndex {
                return index.query(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
            } else {
                // 回退到普通筛选
                return validRestaurants.filter { r in
                    r.latitude >= minLat && r.latitude <= maxLat &&
                    r.longitude >= minLon && r.longitude <= maxLon
                }
            }
        }
        
        return validRestaurants
    }
    
    // 检查坐标是否在中间可视区域（排除上下渐变区域）
    private func isInVisibleCenterArea(lat: Double, lon: Double, region: MKCoordinateRegion) -> Bool {
        let halfLat = region.span.latitudeDelta / 2.0
        let halfLon = region.span.longitudeDelta / 2.0
        
        // 计算中间可视区域的边界（排除上下 25% 的渐变区域）
        let visibleHalfLat = halfLat * (1.0 - visibleAreaInsetRatio * 2)
        let minLat = region.center.latitude - visibleHalfLat
        let maxLat = region.center.latitude + visibleHalfLat
        let minLon = region.center.longitude - halfLon
        let maxLon = region.center.longitude + halfLon
        
        return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
    }
    
    // 检查坐标是否在区域内（保留原方法用于其他用途）
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
            // 导航模式下只显示目的地餐厅
            if isNavigating, let destination = navigatingRestaurant {
                // 只显示目的地餐厅
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)) {
                    GourmetAnnotation(
                        restaurant: destination,
                        isNavigating: true,
                        isDestination: true,
                        simplified: false,
                        showBubble: true,
                        onSelect: { _ in }
                    )
                }
            } else {
                // 分层渲染策略：根据缩放级别决定显示内容
                let zoomLevel = currentZoomLevel
                let clusters = clusteredRestaurants
                
                switch zoomLevel {
                case .far:
                    // 大范围：只显示城市级聚合点（最多5个）
                    ForEach(Array(clusters.prefix(5))) { cluster in
                        mapAnnotation(for: cluster, simplified: true, showBubble: false)
                    }
                    
                case .medium:
                    // 中等范围：显示简化的大头针（不显示气泡）
                    ForEach(clusters) { cluster in
                        mapAnnotation(for: cluster, simplified: true, showBubble: false)
                    }
                    
                case .close:
                    // 小范围：显示完整大头针（显示气泡）
                    ForEach(clusters) { cluster in
                        mapAnnotation(for: cluster, simplified: false, showBubble: true)
                    }
                }
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
        // 检测地图滑动手势
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { _ in
                    handleMapDragStart()
                }
                .onEnded { _ in
                    handleMapDragEnd()
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { _ in
                    handleMapDragStart()
                }
                .onEnded { _ in
                    handleMapDragEnd()
                }
        )
    }
    
    // MARK: - 地图标注
    @MapContentBuilder
    private func mapAnnotation(for cluster: RestaurantCluster, simplified: Bool = false, showBubble: Bool = true) -> some MapContent {
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
                    simplified: simplified,
                    showBubble: showBubble,
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
    
    // MARK: - 退出导航（带流畅动画）
    private func exitNavigation() {
        // 动画退出导航状态
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isNavigating = false
            route = nil
            showExitNavigationButton = false
        }
        
        // 延迟清除导航餐厅，让动画更流畅
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigatingRestaurant = nil
        }
        
        // 停止定时器
        routeUpdateTimer?.invalidate()
        routeUpdateTimer = nil
        
        // 恢复底部导航条（带延迟动画）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .restoreTabBar, object: nil)
        }
        
        // 恢复相机位置到用户当前位置
        if let userLocation = locationManager.userLocation {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
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
    
    // MARK: - 计算聚合点（简化版：每个聚类只显示一家代表餐厅）
    private func calculateClusters(from restaurants: [Restaurant]) -> [RestaurantCluster] {
        guard !restaurants.isEmpty else { return [] }
        
        var clusters: [RestaurantCluster] = []
        var processed = Set<UUID>()
        
        // 使用坐标差值近似计算距离，避免频繁的 CLLocation 计算
        let clusteringDelta = dynamicClusteringDistance / 111000.0 // 粗略转换为度数（1度≈111km）
        
        for restaurant in restaurants {
            guard !processed.contains(restaurant.id) else { continue }
            
            // 找到附近的所有餐厅（使用简单的坐标差值比较）
            var nearbyRestaurants: [Restaurant] = [restaurant]
            processed.insert(restaurant.id)
            
            for other in restaurants {
                guard !processed.contains(other.id) else { continue }
                
                // 简化的距离判断：使用坐标差值近似
                let latDiff = abs(restaurant.latitude - other.latitude)
                let lonDiff = abs(restaurant.longitude - other.longitude)
                
                // 如果在聚类范围内（使用简单的矩形判断代替精确距离）
                if latDiff < clusteringDelta && lonDiff < clusteringDelta {
                    nearbyRestaurants.append(other)
                    processed.insert(other.id)
                }
            }
            
            // 简化：每个聚类只显示第一家餐厅，不显示聚类数量
            // 用户放大后自然能看到其他餐厅
            let representativeRestaurant = nearbyRestaurants.first!
            
            let cluster = RestaurantCluster(
                id: representativeRestaurant.id,
                coordinate: CLLocationCoordinate2D(
                    latitude: representativeRestaurant.latitude,
                    longitude: representativeRestaurant.longitude
                ),
                restaurants: [representativeRestaurant], // 只包含代表餐厅
                isCluster: false // 标记为非聚类，使用普通大头针显示
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
            // 修复：允许触摸事件穿透到地图
            .allowsHitTesting(false)
            
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
                .frame(height: 120)  // 过渡区域高度120pt
                
                // 纯白色区域，与导航栏背景颜色一致
                Color.white
                    .frame(height: geometry.safeAreaInsets.bottom + 64)  // 安全区 + 导航栏高度
            }
        }
        .ignoresSafeArea()
        // 修复：允许触摸事件穿透到地图
        .allowsHitTesting(false)
    }
    
    // MARK: - 设置初始相机位置
    private func setupInitialCameraPosition() {
        // 构建空间索引
        buildSpatialIndex()
        
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
        
        // 如果正在滑动，不立即计算，等待滑动停止
        if isMapDragging {
            return
        }
    }
    
    // MARK: - 滑动检测处理
    private func handleMapDragStart() {
        isMapDragging = true
        
        // 取消之前的计时器
        dragEndTimer?.invalidate()
        settleTimer?.invalidate()
    }
    
    private func handleMapDragEnd() {
        // 延迟标记滑动结束（防止惯性滑动），等待0.75秒后重新开始计算
        dragEndTimer?.invalidate()
        dragEndTimer = Timer.scheduledTimer(withTimeInterval: dragEndDelay, repeats: false) { _ in
            Task { @MainActor in
                self.isMapDragging = false
                // 直接触发聚类计算
                self.scheduleClusteringUpdate()
            }
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
    
    // MARK: - 性能优化：聚类计算节流
    private func shouldRecalculateClusters() -> Bool {
        // 滑动期间不重新计算
        if isMapDragging {
            return false
        }
        
        guard let currentRegion = visibleRegion,
              let lastRegion = lastClusteringRegion else {
            return true
        }
        
        // 计算区域变化距离
        let centerDistance = calculateDistance(
            from: lastRegion.center,
            to: currentRegion.center
        )
        
        // 如果移动超过阈值，需要重新计算
        let threshold = dynamicClusteringDistance * 0.5
        return centerDistance > threshold
    }
    
    private func scheduleClusteringUpdate() {
        // 如果正在滑动，不执行计算
        if isMapDragging {
            return
        }
        
        isClusteringPending = true
        
        // 取消之前的定时器
        clusteringThrottleTimer?.invalidate()
        
        // 延迟 0.3 秒后执行聚类计算
        clusteringThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            Task { @MainActor in
                await self.performClusteringAsync()
            }
        }
    }
    
    // 异步执行聚类计算，避免阻塞主线程
    private func performClusteringAsync() async {
        guard let region = visibleRegion else {
            isClusteringPending = false
            return
        }
        
        let zoomLevel = currentZoomLevel
        let cacheKey = ClusterCacheKey(region: region, zoomLevel: zoomLevel)
        
        // 检查缓存
        if let cached = clusterCache[cacheKey] {
            await MainActor.run {
                self.cachedClusters = cached
                self.lastClusteringRegion = region
                self.isClusteringPending = false
            }
            return
        }
        
        // 在后台线程执行计算
        let clusters = await Task.detached(priority: .userInitiated) { () -> [RestaurantCluster] in
            let filtered = self.filterRestaurants()
            let limitedRestaurants = Array(filtered.prefix(self.maxVisibleRestaurants))
            return self.calculateClusters(from: limitedRestaurants)
        }.value
        
        // 更新 UI
        await MainActor.run {
            self.cachedClusters = clusters
            self.lastClusteringRegion = region
            self.clusterCache[cacheKey] = clusters
            self.isClusteringPending = false
            
            // 限制缓存大小，避免内存溢出
            if self.clusterCache.count > 50 {
                self.clusterCache.removeAll(keepingCapacity: true)
            }
        }
    }
    
    // 初始化空间索引
    private func buildSpatialIndex() {
        Task.detached(priority: .background) {
            let index = RestaurantSpatialIndex(restaurants: self.restaurants)
            await MainActor.run {
                self.spatialIndex = index
            }
        }
    }
}

// MARK: - 地图缩放级别
enum MapZoomLevel {
    case far      // 大范围
    case medium   // 中等范围
    case close    // 小范围
}

// MARK: - 餐厅聚合模型
struct RestaurantCluster: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let restaurants: [Restaurant]
    let isCluster: Bool
}

// MARK: - 奶脂大头针组件 (GourmetAnnotation)
struct GourmetAnnotation: View, Equatable {
    static func == (lhs: GourmetAnnotation, rhs: GourmetAnnotation) -> Bool {
        lhs.restaurant.id == rhs.restaurant.id &&
        lhs.isNavigating == rhs.isNavigating &&
        lhs.isDestination == rhs.isDestination &&
        lhs.simplified == rhs.simplified &&
        lhs.showBubble == rhs.showBubble
    }

    let restaurant: Restaurant
    let isNavigating: Bool
    let isDestination: Bool
    let simplified: Bool  // 简化模式：不显示气泡和名称
    let showBubble: Bool  // 是否显示气泡
    @State private var appearScale: CGFloat = 0.0
    @State private var appearOffset: CGFloat = 20
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
    

    
    var body: some View {
        VStack(spacing: 0) {
            // 所有餐厅都显示评论气泡（白色背景）
            if showBubble && !simplified && !restaurant.review.isEmpty {
                Text(truncatedReview)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                    .frame(maxWidth: 120)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .offset(y: -8 + appearOffset * 0.3)
                    .scaleEffect(appearScale)
                    .opacity(appearScale)
            }

            // 头像层：简化模式下缩小尺寸
            ZStack {
                // 外圈边框
                Circle()
                    .fill(borderColor)
                    .frame(width: simplified ? 36 : 46, height: simplified ? 36 : 46)
                    .shadow(color: Color.black.opacity(0.15), radius: simplified ? 4 : 6, x: 0, y: simplified ? 2 : 3)

                // 封面图 - 简化模式下不加载图片，使用占位符
                if simplified {
                    // 简化模式：纯色背景 + 图标
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.1))
                        Image(systemName: "fork.knife")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                } else {
                    // 完整模式：加载真实图片
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
                }

                // MARK: - 导航模式下的终点波纹动画
                if isDestination && isNavigating {
                    RippleAnimation()
                }
            }
            .scaleEffect(appearScale)
            .offset(y: appearOffset)

            // 小三角形指针（简化模式下缩小）
            Triangle()
                .fill(borderColor)
                .frame(width: simplified ? 8 : 10, height: simplified ? 5 : 6)
                .offset(y: -1 + appearOffset * 0.5)
                .scaleEffect(appearScale)
                .opacity(appearScale)

            // 餐厅名称（简化模式下不显示）
            if !simplified {
                Text(restaurant.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                    .shadow(color: Color.white, radius: 2, x: 0, y: 0)
                    .padding(.top, 2)
                    .offset(y: appearOffset * 0.2)
                    .opacity(appearScale)
            }
        }
        .onAppear {
            // 生长动画：从地图"生长"出来的效果
            // 初始状态：缩小、向下偏移
            appearScale = 0.0
            appearOffset = 20

            // 延迟执行动画，产生错落感
            let delay = Double.random(in: 0.0...0.3)

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                appearScale = 1.0
                appearOffset = 0
            }
        }
        .onTapGesture {
            // 震动反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

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


