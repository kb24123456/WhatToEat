import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - 智能搜索半屏浮层
struct SmartSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var locationManager = LocationManager.shared
    
    @Query private var allRestaurants: [Restaurant]
    
    @Binding var selectedName: String
    @Binding var selectedAddress: String
    @Binding var selectedDistrict: String
    @Binding var selectedCategory: String
    @Binding var selectedLatitude: Double
    @Binding var selectedLongitude: Double
    
    // 高亮回调
    var onAutoFill: (() -> Void)?
    
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var nearbyPlaces: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
    // 防抖计时器
    @State private var debounceTimer: Timer?
    
    // 预热后的品类词库
    @State private var existingCategories: [String] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [
                        Color(hex: "#F5F3F0"),
                        Color(hex: "#FBF9F7")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 搜索栏
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    // 结果列表
                    resultsList
                }
            }
            .navigationTitle("智能搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#1A1A1A"))
                }
            }
        }
        .onAppear {
            precomputeExistingCategories()
            loadNearbyPlaces()
        }
    }
    
    // MARK: - 预热品类词库
    private func precomputeExistingCategories() {
        let presetCategories = CategoryManager.shared.getPresetCategories()
        let existingTypes = Set(allRestaurants.compactMap { $0.type })
        existingCategories = Array(Set(presetCategories + existingTypes))
    }
    
    // MARK: - 语义映射词典（核心改进）
    private let semanticMappings: [(standard: String, keywords: [String])] = [
        ("面馆", ["面", "粉", "面庄", "拉面", "抄手", "米线", "河粉", "面条", "担担面", "宜宾燃面", "刀削面"]),
        ("烧烤", ["烤肉", "串", "烧烤", "烤鱼", "BBQ", "炙烤", "韩式烤肉"]),
        ("饮品", ["茶", "咖啡", "奶茶", "水吧", "果汁", "Coffee", "Tea", "茶饮", "瑞幸", "星巴克"]),
        ("火锅", ["锅", "串串", "打边炉", "麻辣烫", "冒菜", "钵钵鸡", "火锅", "海底捞"]),
        ("烘焙", ["面包", "蛋糕", "甜点", "点心", "烘焙", "糕点", "甜品", "裱花"]),
        ("日本料理", ["日料", "寿司", "居酒屋", "刺身", "天妇罗", "铁板烧", "日式"]),
        ("韩国料理", ["韩式", "韩餐", "部队锅", "石锅拌饭", "烤肉", "泡菜"]),
        ("西餐", ["牛排", "意面", "披萨", "西餐", "西餐厅", "Brunch", "法餐"]),
        ("小吃快餐", ["快餐", "小吃", "盖浇饭", "黄焖鸡", "卤肉饭", "蛋炒饭", "兰州拉面", "沙县"]),
        ("粤菜", ["粤菜", "茶餐厅", "点心", "烧腊", "白切鸡", "肠粉"]),
        ("川菜", ["川菜", "川味", "水煮", "酸菜鱼", "毛血旺", "辣子鸡"]),
        ("湘菜", ["湘菜", "剁椒", "小炒肉", "辣椒炒肉"]),
        ("海鲜", ["海鲜", "鱼", "虾", "蟹", "贝类", "水产"])
    ]
    
    // MARK: - 相似度词库（用于自动修正）
    private let similarCategories: [String: [String]] = [
        "面馆": ["面食", "面条", "面庄", "面粉"],
        "烧烤": ["烤肉", "烤串"],
        "火锅": ["串串", "麻辣烫"],
        "饮品": ["茶饮", "奶茶"],
        "烘焙": ["蛋糕", "甜点"],
        "日本料理": ["日料", "寿司"],
        "小吃快餐": ["快餐", "小吃"]
    ]
    
    // MARK: - 确定品类（语义级智能识别引擎）
    private func determineCategory(from mapItem: MKMapItem) -> (category: String, isAutoMatched: Bool) {
        let rawName = mapItem.name ?? ""
        let title = mapItem.placemark.title ?? ""
        let searchString = preprocessString(rawName + " " + title)
        
        // 第一步：数据库既有品类直配
        if let matched = findBestMatchFromExistingCategories(searchString: searchString) {
            return (matched, true)
        }
        
        // 第二步：模糊语义转换（核心改进）
        if let matched = findBestMatchFromSemanticMappings(searchString: searchString) {
            // 尝试自动修正为数据库已有的相近品类
            if let corrected = correctToExistingCategory(matched) {
                return (corrected, true)
            }
            return (matched, true)
        }
        
        // 第三步：系统 POI 类别映射
        let poiCategory = mapPOICategoryToOurCategory(mapItem.pointOfInterestCategory)
        if poiCategory != "其他" {
            return (poiCategory, true)
        }
        
        // 第四步：兜底
        return ("其他", false)
    }
    
    // MARK: - 字符串预处理
    private func preprocessString(_ input: String) -> String {
        input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }
    
    // MARK: - 第一步：从数据库品类中寻找最佳匹配
    private func findBestMatchFromExistingCategories(searchString: String) -> String? {
        // 精确匹配优先
        if let exactMatch = existingCategories.first(where: { category in
            searchString.contains(preprocessString(category))
        }) {
            return exactMatch
        }
        
        // 次之：店名包含数据库品类
        if let containsMatch = existingCategories.first(where: { category in
            let categoryClean = preprocessString(category)
            return searchString.contains(categoryClean)
        }) {
            return containsMatch
        }
        
        return nil
    }
    
    // MARK: - 第二步：从语义映射词典中寻找匹配
    private func findBestMatchFromSemanticMappings(searchString: String) -> String? {
        for mapping in semanticMappings {
            for keyword in mapping.keywords {
                if searchString.contains(preprocessString(keyword)) {
                    return mapping.standard
                }
            }
        }
        return nil
    }
    
    // MARK: - 自动修正为数据库已有的相近品类
    private func correctToExistingCategory(_ matched: String) -> String? {
        // 1. 如果数据库已有该品类，直接返回
        if existingCategories.contains(matched) {
            return matched
        }
        
        // 2. 查找相似词库中是否有数据库已有的品类
        if let similarWords = similarCategories[matched] {
            if let existingSimilar = existingCategories.first(where: { dbCategory in
                similarWords.contains { $0 == dbCategory }
            }) {
                return existingSimilar
            }
        }
        
        // 3. 模糊匹配：检查数据库品类是否包含匹配词
        if let dbMatch = existingCategories.first(where: { dbCategory in
            let dbClean = preprocessString(dbCategory)
            let matchedClean = preprocessString(matched)
            // 检查是否有交集字符
            return Set(dbClean).intersection(Set(matchedClean)).count >= min(dbClean.count, matchedClean.count) / 2
        }) {
            return dbMatch
        }
        
        // 4. 检查是否可以通过部分字符匹配
        if let partialMatch = existingCategories.first(where: { dbCategory in
            let dbClean = preprocessString(dbCategory)
            let matchedClean = preprocessString(matched)
            // 一个包含另一个的部分字符
            return dbClean.contains(matchedClean) || matchedClean.contains(dbClean)
        }) {
            return partialMatch
        }
        
        return nil
    }
    
    // MARK: - POI 类别映射（保持不变）
    private func mapPOICategoryToOurCategory(_ category: MKPointOfInterestCategory?) -> String {
        guard let category = category else { return "其他" }
        
        let categoryString = String(describing: category)
        
        if categoryString.contains("restaurant") {
            return "火锅/餐饮"
        } else if categoryString.contains("bakery") {
            return "面包甜点"
        } else if categoryString.contains("cafe") {
            return "咖啡茶饮"
        } else if categoryString.contains("food") {
            return "美食广场"
        } else {
            return "其他"
        }
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "#999999"))
            
            TextField("输入店名，智能填充所有信息...", text: $searchQuery)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#1A1A1A"))
                .onChange(of: searchQuery) { _, newValue in
                    handleSearchInput(newValue)
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }
    
    // MARK: - 结果列表
    private var resultsList: some View {
        List {
            if searchQuery.isEmpty {
                // 默认显示附近推荐
                Section {
                    if nearbyPlaces.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("正在获取附近推荐...")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#999999"))
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(Array(nearbyPlaces.enumerated()), id: \.element) { index, item in
                            searchResultRow(item: item, index: index)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#FF6B6B"))
                        Text("附近推荐")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#666666"))
                        Spacer()
                    }
                    .textCase(nil)
                    .padding(.bottom, 8)
                }
            } else {
                // 搜索结果
                Section {
                    if isSearching {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("搜索中...")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#999999"))
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else if searchResults.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(hex: "#CCCCCC"))
                                Text("未找到相关结果")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#999999"))
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(Array(searchResults.enumerated()), id: \.element) { index, item in
                            searchResultRow(item: item, index: index)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - 搜索结果行
    private func searchResultRow(item: MKMapItem, index: Int) -> some View {
        SearchResultButton(item: item) {
            selectPlace(item)
        }
    }
    
    // MARK: - 搜索输入处理（防抖）
    private func handleSearchInput(_ query: String) {
        debounceTimer?.invalidate()
        
        if query.isEmpty {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            performSearch(query: query)
        }
    }
    
    // MARK: - 执行搜索
    private func performSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        // 使用当前位置或默认区域
        if let location = locationManager.userLocation {
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            // 默认使用重庆区域
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 29.5630, longitude: 106.5516),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let items = response?.mapItems {
                    searchResults = items
                } else {
                    searchResults = []
                }
            }
        }
    }
    
    // MARK: - 加载附近推荐
    private func loadNearbyPlaces() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "餐厅 美食 咖啡 面包"
        
        if let location = locationManager.userLocation {
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        } else {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 29.5630, longitude: 106.5516),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                if let items = response?.mapItems {
                    nearbyPlaces = Array(items.prefix(6))
                }
            }
        }
    }
    
    // MARK: - 选择地点
    private func selectPlace(_ item: MKMapItem) {
        // 填充数据
        selectedName = item.name ?? ""
        selectedAddress = formatFullAddress(from: item.placemark)
        selectedDistrict = extractDistrict(from: item.placemark)
        // 注意：城市字段不再由 SmartSearchSheet 设置，统一使用 LibraryView 中选择的城市
        
        // 使用双重匹配逻辑确定品类
        let categoryResult = determineCategory(from: item)
        selectedCategory = categoryResult.category
        selectedLatitude = item.placemark.coordinate.latitude
        selectedLongitude = item.placemark.coordinate.longitude
        
        // 触发高亮效果（传入匹配状态）
        onAutoFill?()
        
        // 关闭浮层
        dismiss()
    }
    
    // MARK: - 辅助方法
    private func calculateDistance(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let userLocation = locationManager.userLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = userLocation.distance(from: targetLocation)
        
        if distance < 1000 {
            return String(format: "%.0f米", distance)
        } else {
            return String(format: "%.1f公里", distance / 1000)
        }
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        if let subLocality = placemark.subLocality {
            components.append(subLocality)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        return components.joined(separator: " ")
    }
    
    private func formatFullAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        if let subLocality = placemark.subLocality {
            components.append(subLocality)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        return components.joined(separator: "")
    }
    
    private func extractDistrict(from placemark: CLPlacemark) -> String {
        // 尝试从地址中提取行政区
        if let subLocality = placemark.subLocality {
            return subLocality
        }
        if let locality = placemark.locality {
            return locality
        }
        return ""
    }
    
    private func categoryIcon(for category: MKPointOfInterestCategory?) -> String {
        guard let category = category else { return "mappin" }
        
        let categoryString = String(describing: category)
        
        if categoryString.contains("restaurant") {
            return "fork.knife"
        } else if categoryString.contains("bakery") {
            return "birthday.cake"
        } else if categoryString.contains("cafe") {
            return "cup.and.saucer"
        } else if categoryString.contains("food") {
            return "basket"
        } else {
            return "mappin"
        }
    }
    
    private func categoryColor(for category: MKPointOfInterestCategory?) -> Color {
        guard let category = category else { return Color(hex: "#999999") }
        
        let categoryString = String(describing: category)
        
        if categoryString.contains("restaurant") {
            return Color(hex: "#FF6B6B")
        } else if categoryString.contains("bakery") {
            return Color(hex: "#FFB347")
        } else if categoryString.contains("cafe") {
            return Color(hex: "#8B4513")
        } else if categoryString.contains("food") {
            return Color(hex: "#27AE60")
        } else {
            return Color(hex: "#3498DB")
        }
    }
}

// MARK: - 搜索结果按钮（独立结构体避免类型检查问题）
struct SearchResultButton: View {
    let item: MKMapItem
    let action: () -> Void
    
    @ObservedObject private var locationManager = LocationManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 18))
                        .foregroundColor(categoryColor)
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name ?? "未知地点")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        // 距离
                        if let distance = calculateDistance() {
                            Text(distance)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#FF6B6B").opacity(0.1))
                                )
                        }
                        
                        // 地址
                        Text(formatAddress())
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#888888"))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#CCCCCC"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var categoryIcon: String {
        guard let category = item.pointOfInterestCategory else { return "mappin" }
        let categoryString = String(describing: category)
        
        if categoryString.contains("restaurant") {
            return "fork.knife"
        } else if categoryString.contains("bakery") {
            return "birthday.cake"
        } else if categoryString.contains("cafe") {
            return "cup.and.saucer"
        } else if categoryString.contains("food") {
            return "basket"
        } else {
            return "mappin"
        }
    }
    
    private var categoryColor: Color {
        guard let category = item.pointOfInterestCategory else { return Color(hex: "#999999") }
        let categoryString = String(describing: category)
        
        if categoryString.contains("restaurant") {
            return Color(hex: "#FF6B6B")
        } else if categoryString.contains("bakery") {
            return Color(hex: "#FFB347")
        } else if categoryString.contains("cafe") {
            return Color(hex: "#8B4513")
        } else if categoryString.contains("food") {
            return Color(hex: "#27AE60")
        } else {
            return Color(hex: "#3498DB")
        }
    }
    
    private func calculateDistance() -> String? {
        guard let userLocation = locationManager.userLocation else { return nil }
        let coordinate = item.placemark.coordinate
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = userLocation.distance(from: targetLocation)
        
        if distance < 1000 {
            return String(format: "%.0f米", distance)
        } else {
            return String(format: "%.1f公里", distance / 1000)
        }
    }
    
    private func formatAddress() -> String {
        let placemark = item.placemark
        var components: [String] = []
        if let subLocality = placemark.subLocality {
            components.append(subLocality)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        return components.joined(separator: " ")
    }
}
