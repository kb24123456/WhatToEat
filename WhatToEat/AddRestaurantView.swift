import SwiftUI
import SwiftData
import MapKit
import PhotosUI

struct AddRestaurantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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
    
    // 品类相关状态
    @State private var useCustomCategory = false
    @State private var customCategoryInput = ""
    
    // 预设品类列表
    private let presetCategories = ["火锅", "川菜", "粤菜", "家常菜", "东北菜", "西餐", "面馆", "烘焙", "早餐", "日料", "饮料", "甜品", "烧烤", "东南亚菜", "其他"]
    
    // 合并预设品类和从餐厅数据中提取的品类，去重排序后返回
    var categoryOptions: [String] {
        let restaurantCategories = allRestaurants.map { $0.type }
        let allCategories = presetCategories + restaurantCategories
        return Array(Set(allCategories)).sorted()
    }
    
    // 根据当前城市获取对应的预设地区列表
    var districtOptions: [String] {
        RegionManager.shared.getDistricts(for: city)
    }
    
    var body: some View {
        ZStack {
            // 背景色
            AppTheme.Colors.background.ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.md) {
                        // 封面图卡片
                        CardView {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(AppTheme.Radius.base)
                            } else {
                                Button(action: { showActionSheet = true }) {
                                    VStack(spacing: AppTheme.Spacing.sm) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                        Text("添加封面图")
                                            .font(AppTheme.Fonts.footnote)
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 200)
                                    .background(AppTheme.Colors.lightGray)
                                    .cornerRadius(AppTheme.Radius.base)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // 基本信息卡片
                        CardView {
                            // 餐厅名称
                            FormItemView(title: "餐厅名称") {
                                TextField("请输入餐厅名称", text: $name)
                                    .font(AppTheme.Fonts.body)
                                    .autocorrectionDisabled()
                            }
                            
                            Divider().background(AppTheme.Colors.divider)
                            
                            // 品类
                            FormItemView(title: "品类") {
                                if categoryOptions.isEmpty {
                                    TextField("请输入品类", text: $category)
                                        .font(AppTheme.Fonts.body)
                                        .autocorrectionDisabled()
                                } else {
                                    Menu {
                                        ForEach(categoryOptions, id: \.self) { option in
                                            Button { category = option }
                                            label: {
                                                Label(option, systemImage: category == option ? "checkmark" : "")
                                            }
                                        }
                                        Button { category = "__CUSTOM_CATEGORY__" }
                                        label: {
                                            Label("+ 自定义品类", systemImage: category == "__CUSTOM_CATEGORY__" ? "checkmark" : "")
                                        }
                                    } label: {
                                        HStack {
                                            Text(category == "__CUSTOM_CATEGORY__" ? "自定义" : (category.isEmpty ? "请选择品类" : category))
                                                .font(AppTheme.Fonts.body)
                                                .foregroundColor(category.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(AppTheme.Colors.textSecondary)
                                        }
                                    }
                                    
                                    if category == "__CUSTOM_CATEGORY__" {
                                        TextField("请输入自定义品类", text: $customCategoryInput)
                                            .font(AppTheme.Fonts.body)
                                            .autocorrectionDisabled()
                                            .onSubmit { if !customCategoryInput.isEmpty { category = customCategoryInput; customCategoryInput = "" } }
                                            .padding(.top, AppTheme.Spacing.sm)
                                    }
                                }
                            }
                            
                            Divider().background(AppTheme.Colors.divider)
                            
                            // 城市
                            FormItemView(title: "城市") {
                                Text(city.isEmpty ? "定位中..." : city)
                                    .font(AppTheme.Fonts.body)
                                    .foregroundColor(city.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                            }
                            
                            Divider().background(AppTheme.Colors.divider)
                            
                            // 地区
                            FormItemView(title: "地区") {
                                Menu {
                                    ForEach(districtOptions, id: \.self) { option in
                                        Button { self.district = option }
                                        label: {
                                            Label(option, systemImage: self.district == option ? "checkmark" : "")
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(district.isEmpty ? "请选择地区" : district)
                                            .font(AppTheme.Fonts.body)
                                            .foregroundColor(district.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                }
                            }
                            
                            Divider().background(AppTheme.Colors.divider)
                            
                            // 评分
                            FormItemView(title: "评分") {
                                HStack {
                                    Spacer()
                                    HStack(spacing: AppTheme.Spacing.sm) {
                                        ForEach(1...5, id: \.self) { index in
                                            Image(systemName: index <= rating ? "star.fill" : "star")
                                                .foregroundColor(index <= rating ? AppTheme.Colors.secondary : AppTheme.Colors.textSecondary)
                                                .font(.system(size: 24))
                                                .onTapGesture { rating = index }
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            
                            Divider().background(AppTheme.Colors.divider)
                            
                            // 地理位置
                            FormItemView(title: "地理位置") {
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                    if !address.isEmpty {
                                        Text(address)
                                            .font(AppTheme.Fonts.body)
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                            .lineLimit(2)
                                    }
                                    Button(action: { showLocationPicker = true }) {
                                        HStack {
                                            Image(systemName: "map")
                                                .foregroundColor(AppTheme.Colors.primary)
                                            Text(address.isEmpty ? "点击选择位置" : "重新选择位置")
                                                .font(AppTheme.Fonts.body)
                                                .foregroundColor(AppTheme.Colors.primary)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // 评价与标签卡片
                        CardView {
                            // 一句话评价
                            FormItemView(title: "一句话评价") {
                                TextField("请输入评价", text: $review, axis: .vertical)
                                    .font(AppTheme.Fonts.body)
                                    .lineLimit(3)
                                    .textFieldStyle(.plain)
                            }
                            
                            Divider().background(AppTheme.Colors.divider)
                            
                            // 标签
                            FormItemView(title: "标签 (用逗号分隔)") {
                                TextField("请输入标签", text: $tagsInput)
                                    .font(AppTheme.Fonts.body)
                                    .autocorrectionDisabled()
                            }
                        }
                        
                        // 底部间距
                        Spacer(minLength: 120)
                    }
                    .padding(AppTheme.Spacing.lg)
                }
                .navigationTitle("新餐厅录入")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
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
                .onAppear {
                    // 视图加载时，获取当前城市
                    if let currentCity = locationManager.currentCity {
                        self.city = currentCity
                    }
                }
                .onChange(of: locationManager.currentCity) {
                    // 当定位城市变化时，更新表单中的城市
                    if let currentCity = locationManager.currentCity {
                        self.city = currentCity
                    }
                }
            }
        }
    }
    
    // 核心逻辑：保存时处理图片文件和标签
    private func saveRestaurant() {
        // 1. 处理标签字符串转数组
        let tags = tagsInput.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 2. 处理品类：确保不保存占位符值，为空时使用默认值
        let finalCategory: String
        if category == "__CUSTOM_CATEGORY__" {
            // 如果选择了自定义品类但未输入，使用默认值
            finalCategory = !customCategoryInput.isEmpty ? customCategoryInput : "未分类"
        } else {
            // 如果直接选择的品类为空，使用默认值
            finalCategory = !category.isEmpty ? category : "未分类"
        }
        
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
        
        // 6. 存入 SwiftData
        modelContext.insert(newRestaurant)
        dismiss()
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