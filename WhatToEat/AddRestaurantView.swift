import SwiftUI
import SwiftData
import MapKit
import PhotosUI

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
    @State private var category = "" // 对应模型里的 type，已从"菜系"改为"品类"，初始为空
    @State private var district = "" // 初始为空
    @State private var city = "" // 初始为空
    @State private var rating = 0 // 初始为0，无星星选中
    @State private var review = ""
    @State private var tagsInput = "" // 使用逗号分隔录入，更简洁
    
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
    
    // 从CategoryManager获取预设品类列表
    var categoryOptions: [String] {
        CategoryManager.shared.getPresetCategories()
    }
    
    // 根据当前城市获取对应的预设地区列表
    var districtOptions: [String] {
        RegionManager.shared.getDistricts(for: city)
    }
    
    // 主内容视图
    private var mainContent: some View {
        VStack(spacing: 4) {
            // 1. 添加封面
            CoverImageView(selectedImage: $selectedImage, showActionSheet: $showActionSheet)
            
            // 2. 位置搜索框
            SearchBar(poiQuery: $poiQuery, searchResults: $searchResults, isSearching: $isSearching, searchPOI: searchPOI, fillInfoFromMapItem: fillInfoFromMapItem)
            
            // 3. 餐厅名称
            NameTextField(name: $name)
            
            // 4. 城市与地区
            CityDistrictView(city: $city, district: $district, districtOptions: districtOptions)
            
            // 5. 品类与评分
            CategoryRatingView(category: $category, rating: $rating, categoryOptions: categoryOptions)
            
            // 6. 标签与评价
            TagsReviewView(tagsInput: $tagsInput, review: $review)
            
            // 底部间距
            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .padding(.bottom, keyboardHeight)
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }
    

    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("新餐厅录入")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        CancelButton(onClose: onClose, dismiss: dismiss)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        SaveButton(name: $name, address: $address, district: $district, city: $city, saveRestaurant: saveRestaurant)
                    }
                }
                // 弹窗逻辑
                .confirmationDialog("选择封面图来源", isPresented: $showActionSheet) {
                    Button("拍照") { showCamera = true }
                    Button("从相册选择") { showPhotoPicker = true }
                    Button("取消", role: .cancel) {}
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraPicker(selectedImage: $selectedImage)
                }
                .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem)
                .onChange(of: photoPickerItem) { oldValue, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run { self.selectedImage = uiImage }
                        }
                    }
                }
                .sheet(isPresented: $showLocationPicker) {
                    LocationPicker { item in
                        self.name = item.name ?? self.name
                        self.address = item.placemark.title ?? ""
                        self.latitude = item.placemark.coordinate.latitude
                        self.longitude = item.placemark.coordinate.longitude
                    }
                }
                // 生命周期逻辑
                .onAppear {
                    // 视图加载时，获取当前城市
                    if let currentCity = locationManager.currentCity {
                        self.city = currentCity
                    }
                    // 监听键盘事件
                    setupKeyboardObservers()
                }
                .onDisappear {
                    // 移除键盘事件监听
                    removeKeyboardObservers()
                }
                .onChange(of: locationManager.currentCity) {
                    // 当定位城市变化时，更新表单中的城市
                    if let currentCity = locationManager.currentCity {
                        self.city = currentCity
                    }
                }
        }
    }
    
    // 键盘事件监听相关方法
    private func setupKeyboardObservers() {
        // 监听键盘显示事件
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        
        // 监听键盘隐藏事件
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation {
                keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardObservers() {
        // 移除所有键盘事件监听
        NotificationCenter.default.removeObserver(self,
                                                 name: UIResponder.keyboardWillShowNotification,
                                                 object: nil)
        NotificationCenter.default.removeObserver(self,
                                                 name: UIResponder.keyboardWillHideNotification,
                                                 object: nil)
    }
    
    // 子视图：封面图
    private struct CoverImageView: View {
        @Binding var selectedImage: UIImage?
        @Binding var showActionSheet: Bool
        
        var body: some View {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipped()
                    .cornerRadius(AppTheme.Radius.image)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.image)
                            .stroke(AppTheme.Colors.divider, lineWidth: 1)
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
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(AppTheme.Colors.lightGray)
                    .cornerRadius(AppTheme.Radius.image)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.image)
                            .stroke(AppTheme.Colors.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // 子视图：搜索框
    private struct SearchBar: View {
        @Binding var poiQuery: String
        @Binding var searchResults: [MKMapItem]
        @Binding var isSearching: Bool
        var searchPOI: () -> Void
        var fillInfoFromMapItem: (MKMapItem) -> Void
        
        var body: some View {
            VStack(spacing: 4) {
                // 搜索条 - 极简样式，高度32pt
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    TextField("输入店名自动填充信息...", text: $poiQuery, onCommit: { searchPOI() })
                        .font(AppTheme.Fonts.body)
                        .autocorrectionDisabled()
                    if !poiQuery.isEmpty {
                        Button(action: { poiQuery = ""; searchResults = [] }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                    }
                }
                .frame(height: 32)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .overlay(
                    Divider()
                        .offset(y: 16)
                        .foregroundColor(AppTheme.Colors.divider)
                )
                
                // 搜索结果列表（悬浮层样式）
                ZStack(alignment: .top) {
                    // 占位符，保持布局稳定
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 0)
                    
                    // 搜索结果悬浮层
                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(AppTheme.Spacing.md)
                            Spacer()
                        }
                        .background(AppTheme.Colors.card)
                        .cornerRadius(AppTheme.Radius.base)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                                .stroke(AppTheme.Colors.divider, lineWidth: 1)
                        )
                        .shadow(color: AppTheme.Shadows.base.color, radius: AppTheme.Shadows.base.radius, x: AppTheme.Shadows.base.x, y: AppTheme.Shadows.base.y)
                    } else if !searchResults.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { mapItem in
                                Button(action: { fillInfoFromMapItem(mapItem) }) {
                                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                        // 添加小图标
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(AppTheme.Colors.primary)
                                            .font(.system(size: 20))
                                            .padding(.top, 2)
                                        
                                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                            Text(mapItem.name ?? "未知")
                                                .font(AppTheme.Fonts.body)
                                                .foregroundColor(AppTheme.Colors.textPrimary)
                                            let placemark = mapItem.placemark
                                            if let address = placemark.title {
                                                Text(address)
                                                    .font(AppTheme.Fonts.footnote)
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(AppTheme.Spacing.md)
                                }
                                .buttonStyle(.plain)
                                .background(Rectangle().fill(AppTheme.Colors.lightGray.opacity(0.3)).frame(height: 1))
                            }
                        }
                        .background(AppTheme.Colors.card)
                        .cornerRadius(AppTheme.Radius.base)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                                .stroke(AppTheme.Colors.divider, lineWidth: 1)
                        )
                        .shadow(color: AppTheme.Shadows.base.color, radius: AppTheme.Shadows.base.radius, x: AppTheme.Shadows.base.x, y: AppTheme.Shadows.base.y)
                    }
                }
            }
        }
    }
    
    // 子视图：餐厅名称
    private struct NameTextField: View {
        @Binding var name: String
        
        var body: some View {
            HStack {
                TextField("餐厅名称", text: $name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
            .frame(height: 36)
            .background(AppTheme.Colors.card.opacity(name.isEmpty ? 1.0 : 0.8))
            .overlay(name.isEmpty ? nil : AppTheme.Colors.lightBlue.opacity(0.3))
            .cornerRadius(AppTheme.Radius.base)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
            )
        }
    }
    
    // 子视图：城市与地区
    private struct CityDistrictView: View {
        @Binding var city: String
        @Binding var district: String
        var districtOptions: [String]
        
        var body: some View {
            HStack(spacing: 8) {
                // 左侧位置图标
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .font(.system(size: 16))
                
                // 城市名
                Text(city.isEmpty ? "定位中..." : city)
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(city.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                
                // 分隔符
                Text("|")
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                // 地区选择 Menu
                Menu {
                    ForEach(districtOptions, id: \.self) { option in
                        Button { district = option }
                        label: {
                            Label(option, systemImage: district == option ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(district.isEmpty ? "请选择地区" : district)
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(district.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .font(.system(size: 12))
                    }
                }
                
                Spacer()
            }
            .frame(height: 36)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(AppTheme.Colors.lightGray.opacity(0.3))
            .cornerRadius(AppTheme.Radius.base)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
            )
        }
    }
    
    // 子视图：品类与评分
    private struct CategoryRatingView: View {
        @Binding var category: String
        @Binding var rating: Int
        var categoryOptions: [String]
        
        var body: some View {
            HStack(spacing: AppTheme.Spacing.sm) {
                // 左侧品类 Menu
                Menu {
                    ForEach(categoryOptions, id: \.self) { option in
                        Button { category = option }
                        label: {
                            Label(option, systemImage: category == option ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack {
                        Text(category.isEmpty ? "请选择品类" : category)
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(category.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 右侧五星评分，星号大小16pt
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= rating ? "star.fill" : "star")
                            .foregroundColor(index <= rating ? AppTheme.Colors.secondary : AppTheme.Colors.textSecondary)
                            .font(.system(size: 16)) // 星号缩小至 16pt
                            .symbolRenderingMode(.hierarchical)
                            .onTapGesture { rating = index }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .frame(height: 36)
            .background(AppTheme.Colors.lightGray.opacity(0.3))
            .cornerRadius(AppTheme.Radius.base)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
            )
        }
    }
    
    // 子视图：标签与评价
    private struct TagsReviewView: View {
        @Binding var tagsInput: String
        @Binding var review: String
        
        var body: some View {
            VStack(spacing: 4) {
                // 标签行：一行超薄 TextField
                HStack {
                    TextField("标签 (用逗号分隔)", text: $tagsInput)
                        .font(AppTheme.Fonts.body)
                        .autocorrectionDisabled()
                        .padding(.vertical, 2)
                        .padding(.horizontal, AppTheme.Spacing.md)
                }
                .background(AppTheme.Colors.card.opacity(tagsInput.isEmpty ? 1.0 : 0.8))
                .overlay(tagsInput.isEmpty ? nil : AppTheme.Colors.lightBlue.opacity(0.3))
                .cornerRadius(AppTheme.Radius.base)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
                
                // 评价框：使用 TextField(..., axis: .vertical)，最多显示 2 行，极浅底色
                HStack {
                    TextField("一句话评价", text: $review, axis: .vertical)
                        .font(AppTheme.Fonts.body)
                        .lineLimit(2)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 8)
                        .padding(.horizontal, AppTheme.Spacing.md)
                }
                .background(Color(hex: "#FFF9E6")) // 极浅的黄色底色
                .cornerRadius(AppTheme.Radius.base)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
            }
            .frame(height: 100)
        }
    }
    
    // 子视图：取消按钮
    private struct CancelButton: View {
        var onClose: (() -> Void)?
        var dismiss: DismissAction
        
        var body: some View {
            Button("取消") { 
                if let onClose = onClose {
                    onClose()
                } else {
                    dismiss()
                }
            }
            .font(AppTheme.Fonts.body)
            .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
    
    // 子视图：保存按钮
    private struct SaveButton: View {
        @Binding var name: String
        @Binding var address: String
        @Binding var district: String
        @Binding var city: String
        var saveRestaurant: () -> Void
        
        var body: some View {
            Button("保存") { saveRestaurant() }
            .font(AppTheme.Fonts.body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.Colors.accent)
            .cornerRadius(AppTheme.Radius.circle)
            .disabled(name.isEmpty || address.isEmpty || district.isEmpty || city.isEmpty)
            .withHapticFeedback()
        }
    }
    
    // 核心逻辑：地图智能搜索
    private func searchPOI() {
        guard !poiQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = poiQuery
        request.resultTypes = .pointOfInterest
        
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
                    self.searchResults = response.mapItems
                } else {
                    self.searchResults = []
                }
            }
        }
    }
    
    // 核心逻辑：品类自动映射
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
    
    // 核心逻辑：一键填充信息
    private func fillInfoFromMapItem(_ mapItem: MKMapItem) {
        // 填充基本信息
        name = mapItem.name ?? ""
        
        // 填充地址信息
        let placemark = mapItem.placemark
        address = placemark.title ?? ""
        latitude = placemark.coordinate.latitude
        longitude = placemark.coordinate.longitude
        
        // 尝试从地址中提取城市和地区
        if let city = placemark.locality {
            self.city = city
        }
        if let district = placemark.subLocality {
            self.district = district
        } else if let administrativeArea = placemark.administrativeArea {
            self.district = administrativeArea
        }
        
        // 自动映射品类：优先通过关键词匹配
        category = determineCategory(from: mapItem)
        
        // 清空搜索结果
        searchResults = []
    }
    
    // 核心逻辑：通过多种方式确定品类
    private func determineCategory(from mapItem: MKMapItem) -> String {
        let presetCategories = CategoryManager.shared.getPresetCategories()
        
        // 1. 首先通过关键词匹配店名
        let nameToCheck = mapItem.name ?? ""
        let titleToCheck = mapItem.placemark.title ?? ""
        let textToCheck = (nameToCheck + titleToCheck).lowercased()
        
        // 关键词映射表
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
        
        // 遍历关键词映射表，寻找匹配
        for (keyword, categoryName) in keywordMap {
            if textToCheck.contains(keyword.lowercased()) {
                // 检查是否在预设品类中
                if presetCategories.contains(categoryName) {
                    return categoryName
                }
                return categoryName
            }
        }
        
        // 2. 如果关键词匹配失败，使用 POI 品类映射
        if let poiCategory = mapItem.pointOfInterestCategory {
            let mappedCategory = mapPOICategoryToOurCategory(poiCategory)
            if !mappedCategory.isEmpty {
                // 检查是否在预设品类中
                if presetCategories.contains(mappedCategory) {
                    return mappedCategory
                }
                return mappedCategory
            }
        }
        
        // 3. 如果都失败了，返回空字符串
        return ""
    }
    
    // 核心逻辑：保存时处理图片文件和标签
    private func saveRestaurant() {
        // 1. 处理标签字符串转数组
        let tags = tagsInput.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 2. 处理品类：如果未选择，使用默认值
        let finalCategory = !category.isEmpty ? category : "未分类"
        
        // 3. 处理评分：如果未选择（为0），使用默认值3
        let finalRating = rating > 0 ? rating : 3
        
        // 4. 将图片保存到磁盘并获取文件名
        let filename = selectedImage.flatMap { ImageManager.shared.saveImage($0) }
        
        // 5. 创建餐厅对象
        let newRestaurant = Restaurant(
            name: name,
            type: finalCategory,
            district: district,
            city: city,
            rating: finalRating,
            address: address,
            latitude: latitude,
            longitude: longitude,
            coverPhotoFilename: filename,
            review: review,
            tags: tags,
            averagePrice: 0.0
        )
        
        // 6. 在主线程中执行数据库操作
        Task {
            @MainActor in
            // 存入 SwiftData
            modelContext.insert(newRestaurant)
            // 显式保存上下文，确保保存成功后再关闭页面
            do {
                try modelContext.save()
                // 保存成功后才关闭页面
                if let onClose = onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } catch {
                // 保存失败，记录错误但不关闭页面
                print("保存餐厅失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 自定义卡片组件
    private struct CardView<Content: View>: View {
        let content: () -> Content
        
        init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }
        
        var body: some View {
            VStack {
                content()
            }
            .background(AppTheme.Colors.card)
            .cornerRadius(AppTheme.Radius.base)
            .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
        }
    }
    
    // 自定义表单项组件
    private struct FormItemView<Content: View>: View {
        let title: String
        let content: () -> Content
        
        init(title: String, @ViewBuilder content: @escaping () -> Content) {
            self.title = title
            self.content = content
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Fonts.caption2)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.bottom, AppTheme.Spacing.xs)
                content()
            }
            .padding(AppTheme.Spacing.lg)
        }
    }
}