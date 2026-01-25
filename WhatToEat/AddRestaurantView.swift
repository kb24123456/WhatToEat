import SwiftUI
import SwiftData
import MapKit
import PhotosUI

// MARK: - TextField占位符扩展
struct PlaceholderModifier: ViewModifier {
    var text: String
    var color: Color
    var isEmpty: Bool
    
    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            if isEmpty {
                Text(text)
                    .foregroundColor(color)
                    .font(AppTheme.Fonts.body)
                    .padding(.leading, AppTheme.Spacing.md)
            }
            content
        }
    }
}

extension View {
    func placeholder(_ text: String, color: Color = .gray, isEmpty: Bool) -> some View {
        modifier(PlaceholderModifier(text: text, color: color, isEmpty: isEmpty))
    }
}

struct AddRestaurantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 回调闭包，用于关闭页面
    var onClose: (() -> Void)? = nil
    
    // 获取所有餐厅数据，用于动态生成品类选项
    @Query private var allRestaurants: [Restaurant]
    
    // 定位管理器
    @ObservedObject private var locationManager = LocationManager.shared
    
    // --- 1. 表单基础数据 ---
    @State private var name = ""
    @State private var category = ""
    @State private var district = ""
    @State private var city = ""
    @State private var rating = 0
    @State private var review = ""
    @State private var tagsInput = ""
    
    // --- 2. 位置相关 ---
    @State private var address = ""
    @State private var latitude = 0.0
    @State private var longitude = 0.0
    @State private var showLocationPicker = false
    
    // --- 3. 封面图相关 ---
    @State private var selectedImage: UIImage?
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    
    // --- 4. 地图智能搜索相关 ---
    @State private var poiQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    
    // --- 5. 键盘高度监听 ---
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardVisible = false
    
    // --- 6. UI状态 ---
    @State private var isAutoFilled = false
    // 标签系统：已选标签数组
    @State private var selectedTags: [String] = []
    
    // 预设灵感标签池
    let presetTags = ["氛围感", "老字号", "二刷", "排队王", "性价比"]
    
    // 从CategoryManager获取预设品类列表
    var categoryOptions: [String] {
        CategoryManager.shared.getPresetCategories()
    }
    
    // 根据当前城市获取对应的预设地区列表
    var districtOptions: [String] {
        RegionManager.shared.getDistricts(for: city)
    }
    
    // MARK: - 主表单内容
    private var formContent: some View {
        VStack(spacing: 0) {
            CoverImageView(selectedImage: $selectedImage, showActionSheet: $showActionSheet)
            
            Color.clear.frame(height: 12)
            
            SearchBar(poiQuery: $poiQuery, searchResults: $searchResults, isSearching: $isSearching, searchPOI: searchPOI, fillInfoFromMapItem: fillInfoFromMapItem)
            
            Color.clear.frame(height: 8)
            
            NameTextField(name: $name, isAutoFilled: isAutoFilled)
            
            Color.clear.frame(height: 8)
            
            DistrictCategoryRow(district: $district, category: $category, districtOptions: districtOptions, categoryOptions: categoryOptions)
            
            Color.clear.frame(height: 8)
            
            RatingRow(rating: $rating)
            
            Color.clear.frame(height: 8)
            
            ReviewSection(review: $review)
            
            Color.clear.frame(height: 8)
            
            TagSystemSection(
                tagsInput: $tagsInput,
                selectedTags: $selectedTags,
                presetTags: presetTags
            )
            
            Color.clear.frame(height: 24)
            
            ActionButtonsRow(
                onClose: onClose,
                dismissAction: { dismiss() },
                saveAction: saveRestaurant,
                isValid: !name.isEmpty && !address.isEmpty && !district.isEmpty
            )
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, 40)
    }
    
    // MARK: - 表单背景
    private var formBackground: some View {
        Color.white
    }
    
    var body: some View {
        NavigationStack {
            formContent
                .background(formBackground)
                .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .confirmationDialog("选择封面图来源", isPresented: $showActionSheet) {
            Button("拍照") { showCamera = true }
            Button("从相册选择") { showPhotoPicker = true }
            Button("取消", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(selectedImage: $selectedImage)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem)
        .onChange(of: photoPickerItem) { _, newValue in
            handlePhotoPickerChange(newValue)
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPicker { item in
                handleLocationSelect(item)
            }
        }
        .onAppear {
            handleViewAppear()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .onChange(of: locationManager.currentCity) { _, newValue in
            handleCityChange(newValue)
        }
    }
    
    // MARK: - 事件处理方法
    private func handlePhotoPickerChange(_ newValue: PhotosPickerItem?) {
        Task {
            if let data = try? await newValue?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run { self.selectedImage = uiImage }
            }
        }
    }
    
    private func handleLocationSelect(_ item: MKMapItem) {
        self.name = item.name ?? self.name
        self.address = item.placemark.title ?? ""
        self.latitude = item.placemark.coordinate.latitude
        self.longitude = item.placemark.coordinate.longitude
    }
    
    private func handleViewAppear() {
        if let currentCity = locationManager.currentCity {
            self.city = currentCity
        }
        setupKeyboardObservers()
    }
    
    private func handleCityChange(_ newCity: String?) {
        if let currentCity = newCity {
            self.city = currentCity
        }
    }
    
    // MARK: - 键盘事件监听
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.keyboardVisible = true
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.keyboardVisible = false
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: - POI 搜索
    private func searchPOI() {
        isSearching = true
        
        let request = MKLocalSearch.Request()
        
        if !poiQuery.isEmpty {
            request.naturalLanguageQuery = poiQuery
        } else {
            request.naturalLanguageQuery = "餐厅"
        }
        
        request.resultTypes = .pointOfInterest
        
        if let userLocation = locationManager.userLocation {
            let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
            request.region = region
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    print("搜索失败: \(error.localizedDescription)")
                    self.searchResults = []
                    return
                }
                
                if let response = response {
                    var filteredResults = response.mapItems.filter { mapItem in
                        guard let categories = mapItem.pointOfInterestCategory else { return false }
                        let isRestaurant = categories == .restaurant || categories == .cafe || categories == .foodMarket
                        
                        if self.poiQuery.isEmpty {
                            return isRestaurant
                        } else {
                            let name = mapItem.name?.lowercased() ?? ""
                            let query = self.poiQuery.lowercased()
                            return isRestaurant && name.contains(query)
                        }
                    }
                    
                    if let userLocation = self.locationManager.userLocation {
                        filteredResults.sort { mapItem1, mapItem2 in
                            let location1 = CLLocation(latitude: mapItem1.placemark.coordinate.latitude, longitude: mapItem1.placemark.coordinate.longitude)
                            let location2 = CLLocation(latitude: mapItem2.placemark.coordinate.latitude, longitude: mapItem2.placemark.coordinate.longitude)
                            let distance1 = location1.distance(from: userLocation)
                            let distance2 = location2.distance(from: userLocation)
                            return distance1 < distance2
                        }
                    }
                    
                    self.searchResults = Array(filteredResults.prefix(5))
                } else {
                    self.searchResults = []
                }
            }
        }
    }
    
    // MARK: - 品类自动映射 (已修复：未匹配到预设品类时返回空字符串)
    private func mapPOICategoryToOurCategory(_ poiCategory: MKPointOfInterestCategory?) -> String {
        guard let poiCategory = poiCategory else { return "" }
        
        switch poiCategory {
        case .restaurant, .cafe:
            return "美食"
        case .hotel:
            return "酒店"
        case .museum, .movieTheater:
            return "娱乐"
        default:
            return ""
        }
    }
    
    // MARK: - 一键填充信息
    private func fillInfoFromMapItem(_ mapItem: MKMapItem) {
        name = mapItem.name ?? ""
        
        let placemark = mapItem.placemark
        address = placemark.title ?? ""
        latitude = placemark.coordinate.latitude
        longitude = placemark.coordinate.longitude
        
        if let cityName = placemark.locality {
            self.city = cityName
        }
        if let districtName = placemark.subLocality {
            self.district = districtName
        } else if let administrativeArea = placemark.administrativeArea {
            self.district = administrativeArea
        }
        
        category = determineCategory(from: mapItem)
        
        searchResults = []
        isAutoFilled = true
    }
    
    // MARK: - 通过多种方式确定品类 (已修复：禁止自动填入"美食")
    private func determineCategory(from mapItem: MKMapItem) -> String {
        let presetCategories = CategoryManager.shared.getPresetCategories()
        let nameToCheck = mapItem.name ?? ""
        let titleToCheck = mapItem.placemark.title ?? ""
        let textToCheck = (nameToCheck + titleToCheck).lowercased()
        
        let keywordMap: [String: String] = [
            "火锅": "火锅",
            "面": "面馆",
            "粉": "面馆",
            "咖啡": "咖啡",
            "奶茶": "饮品",
            "茶": "饮品",
            "汉堡": "快餐",
            "披萨": "西餐",
            "日料": "日本料理",
            "寿司": "日本料理",
            "韩料": "韩国料理",
            "烧烤": "烧烤",
            "烤肉": "烧烤",
            "川菜": "川菜",
            "粤菜": "粤菜",
            "湘菜": "湘菜",
            "鲁菜": "鲁菜",
            "淮扬菜": "淮扬菜",
            "东北菜": "东北菜",
            "西餐": "西餐",
            "东南亚": "东南亚菜",
            "泰餐": "东南亚菜",
            "越南菜": "东南亚菜",
            "印度菜": "东南亚菜",
            "甜品": "甜品",
            "蛋糕": "甜品",
            "冰淇淋": "甜品",
            "酒吧": "酒吧",
            "酒馆": "酒吧",
            "清吧": "酒吧"
        ]
        
        for (keyword, categoryName) in keywordMap {
            if textToCheck.contains(keyword.lowercased()) {
                if presetCategories.contains(categoryName) {
                    return categoryName
                }
                return categoryName
            }
        }
        
        if let poiCategory = mapItem.pointOfInterestCategory {
            let mappedCategory = mapPOICategoryToOurCategory(poiCategory)
            if !mappedCategory.isEmpty && presetCategories.contains(mappedCategory) {
                return mappedCategory
            }
        }
        
        // 修复：未匹配到预设品类时，返回空字符串，禁止自动填入"美食"
        return ""
    }
    
    // MARK: - 保存餐厅
    private func saveRestaurant() {
        Task { @MainActor in
            // 合并已选标签和输入的标签
            var allTags = selectedTags
            let inputTags = tagsInput.components(
                separatedBy: CharacterSet(charactersIn: ",， ")
            )
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            allTags.append(contentsOf: inputTags)
            let finalTags = Array(Set(allTags))
            
            let finalCategory = !category.isEmpty ? category : "未分类"
            let finalRating = rating > 0 ? rating : 3
            
            // 城市兜底逻辑：确保城市信息被记录后再创建 Restaurant 对象
            var finalCity = city
            if finalCity.isEmpty {
                // 优先使用 UserDefaults 中保存的城市
                if let savedCity = UserDefaults.standard.string(forKey: "UserSelectedCity") {
                    finalCity = savedCity
                } else if let currentCity = locationManager.currentCity {
                    // 其次使用定位获取的当前城市
                    finalCity = currentCity
                } else {
                    // 默认使用重庆
                    finalCity = "重庆"
                }
            }
            
            // 保存城市到 UserDefaults，确保列表筛选能够正确匹配
            UserDefaults.standard.set(finalCity, forKey: "UserSelectedCity")
            
            // 地理坐标处理：如果经纬度为 0，从地址进行逆地理编码获取
            var finalLatitude = latitude
            var finalLongitude = longitude
            if finalLatitude == 0.0 && finalLongitude == 0.0 && !address.isEmpty {
                // 使用地址进行逆地理编码（异步）
                let geocoder = CLGeocoder()
                do {
                    let placemarks = try await geocoder.geocodeAddressString(address)
                    if let placemark = placemarks.first, let location = placemark.location {
                        finalLatitude = location.coordinate.latitude
                        finalLongitude = location.coordinate.longitude
                    }
                } catch {
                    print("逆地理编码失败: \(error.localizedDescription)")
                }
            }
            
            let filename = selectedImage.flatMap { ImageManager.shared.saveImage($0) }
            
            let newRestaurant = Restaurant(
                name: name,
                type: finalCategory,
                district: district,
                city: finalCity,
                rating: finalRating,
                address: address,
                latitude: finalLatitude,
                longitude: finalLongitude,
                coverPhotoFilename: filename,
                review: review,
                tags: finalTags,
                averagePrice: 0.0
            )
            
            modelContext.insert(newRestaurant)
            do {
                try modelContext.save()
                // 延迟确保 SwiftData 刷新
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                if let onClose = onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } catch {
                print("保存餐厅失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 子视图：封面图 (160pt)
struct CoverImageView: View {
    @Binding var selectedImage: UIImage?
    @Binding var showActionSheet: Bool
    
    var body: some View {
        ZStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(AppTheme.Radius.base)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 2, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                            .stroke(Color.white, lineWidth: 2.0)
                    )
            } else {
                Button(action: { showActionSheet = true }) {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("添加封面图")
                            .font(AppTheme.Fonts.footnote)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(AppTheme.Colors.lightGray.opacity(0.8))
                    .cornerRadius(AppTheme.Radius.base)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 2, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 子视图：POI 智能搜索条 (高亮发光效果)
struct SearchBar: View {
    @Binding var poiQuery: String
    @Binding var searchResults: [MKMapItem]
    @Binding var isSearching: Bool
    var searchPOI: () -> Void
    var fillInfoFromMapItem: (MKMapItem) -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.Colors.accent)
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                
                TextField("", text: $poiQuery, onCommit: { 
                    searchPOI()
                    isFocused = true
                })
                    .font(AppTheme.Fonts.body)
                    .autocorrectionDisabled()
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .placeholder("输入店名智能填充信息...", 
                               color: AppTheme.Colors.textSecondary.opacity(0.8), 
                               isEmpty: poiQuery.isEmpty)
                    .focused($isFocused)
                    .keyboardType(.default)
                    .submitLabel(.search)
                    .onChange(of: isFocused) { _, newValue in
                        if newValue && poiQuery.isEmpty {
                            searchPOI()
                        } else if !newValue {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                searchResults = []
                            }
                        }
                    }
                    .onChange(of: poiQuery) { _, _ in
                        searchPOI()
                    }
                
                if !poiQuery.isEmpty {
                    Button(action: { 
                        poiQuery = ""
                        searchPOI()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .font(.system(size: 16))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                }
            }
            .frame(height: 44)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(AppTheme.Colors.accent.opacity(0.6), lineWidth: 1.5)
            )
            .cornerRadius(AppTheme.Radius.base)
            // 高亮发光效果
            .shadow(color: AppTheme.Colors.accent.opacity(0.15), radius: 12, x: 0, y: 0)
            
            // 搜索结果列表
            if !isSearching && !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(searchResults, id: \.self) { mapItem in
                            Button(action: { 
                                fillInfoFromMapItem(mapItem)
                                searchResults = []
                            }) {
                                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .font(.system(size: 20))
                                        .padding(.top, 2)
                                    
                                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                        Text(mapItem.name ?? "未知")
                                            .font(AppTheme.Fonts.headline)
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        
                                        HStack(spacing: 8) {
                                            if let userLocation = LocationManager.shared.userLocation {
                                                let mapItemLocation = CLLocation(latitude: mapItem.placemark.coordinate.latitude, longitude: mapItem.placemark.coordinate.longitude)
                                                let distance = userLocation.distance(from: mapItemLocation)
                                                Text(String(format: "%.1fkm", distance / 1000))
                                                    .font(AppTheme.Fonts.caption)
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                                
                                                Text("|")
                                                    .font(AppTheme.Fonts.caption)
                                                    .foregroundColor(AppTheme.Colors.divider)
                                            }
                                            
                                            if let address = mapItem.placemark.title {
                                                Text(address)
                                                    .font(AppTheme.Fonts.caption)
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(AppTheme.Spacing.md)
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                        }
                    }
                }
                .frame(height: min(CGFloat(searchResults.count) * 60, 300))
                .background(AppTheme.Colors.card)
                .cornerRadius(AppTheme.Radius.base)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
                .shadow(color: AppTheme.Colors.accent.opacity(0.1), radius: 8, x: 0, y: 2)
                .offset(y: 4)
            }
            
            // 搜索中状态
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(AppTheme.Spacing.md)
                    Spacer()
                }
                .frame(height: 60)
                .background(AppTheme.Colors.card)
                .cornerRadius(AppTheme.Radius.base)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
                .offset(y: 4)
            }
        }
    }
}

// MARK: - 子视图：餐厅名称 (title3, 加粗)
struct NameTextField: View {
    @Binding var name: String
    var isAutoFilled: Bool
    
    var body: some View {
        TextField("餐厅名称", text: $name)
            .font(.title3)
            .fontWeight(.bold)
            .autocorrectionDisabled()
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 12)
            .foregroundColor(isAutoFilled ? AppTheme.Colors.primary : .primary)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
            )
            .cornerRadius(AppTheme.Radius.base)
            .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
    }
}

// MARK: - 子视图：合并行 HStack (左侧地区，右侧品类，0.5pt细线分割)
struct DistrictCategoryRow: View {
    @Binding var district: String
    @Binding var category: String
    var districtOptions: [String]
    var categoryOptions: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧地区选择
            Menu {
                ForEach(districtOptions, id: \.self) { option in
                    Button { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            district = option
                        }
                    } label: {
                        Label(option, systemImage: district == option ? "checkmark" : "")
                    }
                }
            } label: {
                HStack {
                    Text(district.isEmpty ? "请选择地区" : district)
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(district.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .font(.system(size: 12))
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .frame(maxWidth: .infinity)
            
            // 中间细线分割 (0.5pt)
            Rectangle()
                .fill(AppTheme.Colors.divider)
                .frame(width: 0.5)
            
            // 右侧品类选择
            Menu {
                ForEach(categoryOptions, id: \.self) { option in
                    Button { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            category = option
                        }
                    } label: {
                        Label(option, systemImage: category == option ? "checkmark" : "")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            } label: {
                HStack {
                    Text(category.isEmpty ? "请选择品类" : category)
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(category.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .font(.system(size: 12))
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 44)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
        )
        // 微立体感
        .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
    }
}

// MARK: - 子视图：巨幕评分行 (28pt星号，12pt间距)
struct RatingRow: View {
    @Binding var rating: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundColor(index <= rating ? AppTheme.Colors.secondary : AppTheme.Colors.textSecondary)
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            rating = index
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        // 微立体感
        .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
    }
}

// MARK: - 子视图：一句话评价 (奶油色底，不带红线)
struct ReviewSection: View {
    @Binding var review: String
    
    var body: some View {
        TextField("一句话评价", text: $review, axis: .vertical)
            .font(AppTheme.Fonts.body)
            .lineLimit(2)
            .textFieldStyle(.plain)
            .padding(.vertical, 12)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(Color(hex: "#FFF9E6"))
            .cornerRadius(AppTheme.Radius.base)
            .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
    }
}

// MARK: - 子视图：沉浸式标签系统
struct TagSystemSection: View {
    @Binding var tagsInput: String
    @Binding var selectedTags: [String]
    let presetTags: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 已选标签区：输入框上方显示已添加的标签胶囊
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTags.indices, id: \.self) { index in
                            HStack(spacing: 4) {
                                Text(selectedTags[index])
                                    .font(AppTheme.Fonts.footnote)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedTags.remove(atOffsets: [index])
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#EBF3FF"))
                            .opacity(0.6)
                            .cornerRadius(16)
                        }
                    }
                }
                .frame(height: 32)
            }
            
            // 输入框：极简线条风格 TextField
            TextField("添加标签...", text: $tagsInput)
                .font(AppTheme.Fonts.body)
                .autocorrectionDisabled()
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, 10)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
                )
                .cornerRadius(AppTheme.Radius.base)
            
            // 灵感标签池：使用 | 字符分割
            if !presetTags.isEmpty {
                HStack(spacing: 0) {
                    ForEach(presetTags.indices, id: \.self) { index in
                        Button(action: {
                            if !selectedTags.contains(presetTags[index]) && !tagsInput.contains(presetTags[index]) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTags.append(presetTags[index])
                                }
                            }
                        }) {
                            Text(presetTags[index])
                                .font(AppTheme.Fonts.footnote)
                                .foregroundColor(AppTheme.Colors.primary)
                                .padding(.vertical, 6)
                        }
                        
                        if index < presetTags.count - 1 {
                            Text("|")
                                .font(AppTheme.Fonts.footnote)
                                .foregroundColor(AppTheme.Colors.divider)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
    }
}

// MARK: - 子视图：底部操作行
struct ActionButtonsRow: View {
    var onClose: (() -> Void)?
    var dismissAction: () -> Void
    var saveAction: () -> Void
    var isValid: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Button("取消") { 
                if let onClose = onClose {
                    onClose()
                } else {
                    dismissAction()
                }
            }
            .font(AppTheme.Fonts.headline)
            .foregroundColor(AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.Colors.lightGray)
            .cornerRadius(AppTheme.Radius.base)
            .frame(width: UIScreen.main.bounds.width * 0.25)
            .withHapticFeedback()
            
            Button("保存") { saveAction() }
                .font(AppTheme.Fonts.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(isValid ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
                .cornerRadius(AppTheme.Radius.base)
                .shadow(color: isValid ? AppTheme.Colors.accent.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                .disabled(!isValid)
                .withHapticFeedback()
                .frame(maxWidth: .infinity)
        }
    }
}
