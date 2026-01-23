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
    
    // --- 动态选项生成 ---
    // 从所有餐厅中提取唯一品类列表，排序后返回
    var categoryOptions: [String] {
        Array(Set(allRestaurants.map { $0.type })).sorted()
    }
    
    // 根据当前城市获取对应的预设地区列表
    var districtOptions: [String] {
        RegionManager.shared.getDistricts(for: city)
    }
    
    // 品类相关状态
    @State private var useCustomCategory = false
    @State private var customCategoryInput = ""
    
    // 自定义标签组件
    private func LabeledField(title: String, value: String, valueColor: Color = AppTheme.Colors.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(AppTheme.Fonts.caption2)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text(value)
                .font(AppTheme.Fonts.body)
                .foregroundColor(valueColor)
                .lineLimit(1)
        }
    }
    
    // 自定义卡片容器
    private func Card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(AppTheme.Colors.card)
            .cornerRadius(AppTheme.Radius.base)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
            )
            .shadow(
                color: AppTheme.Shadows.light.color,
                radius: AppTheme.Shadows.light.radius,
                x: AppTheme.Shadows.light.x,
                y: AppTheme.Shadows.light.y
            )
            .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    var body: some View {
        ZStack {
            // 底层背景
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            // 主内容区域
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // ✅ 模块一：餐厅封面
                    Card {
                        if let image = selectedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipped()
                                    .cornerRadius(AppTheme.Radius.image)
                                
                                Button { selectedImage = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.red)
                                }
                                .padding(8)
                            }
                        } else {
                            Button { showActionSheet = true } label: {
                                VStack(spacing: AppTheme.Spacing.sm) {
                                    Image(systemName: "camera.fill")
                                        .font(.largeTitle)
                                    Text("添加封面图")
                                        .font(AppTheme.Fonts.footnote)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .background(AppTheme.Colors.lightGray)
                                .cornerRadius(AppTheme.Radius.image)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // ✅ 模块二：基本信息卡片
                    Card {
                        VStack(spacing: AppTheme.Spacing.md) {
                            // 餐厅名称
                            TextField("餐厅名称", text: $name)
                                .font(AppTheme.Fonts.title3)
                                .padding(.bottom, AppTheme.Spacing.xs)
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(AppTheme.Colors.divider)
                                        .alignmentGuide(.bottom) { $0[.bottom] }
                                )
                            
                            // 字段合并：品类、城市、地区
                            HStack(spacing: AppTheme.Spacing.md) {
                                // 品类
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                    Text("品类")
                                        .font(AppTheme.Fonts.caption2)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    if categoryOptions.isEmpty {
                                        // 无现有品类时，直接文本输入
                                        TextField("输入品类", text: $category)
                                            .font(AppTheme.Fonts.body)
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                            .autocorrectionDisabled()
                                    } else {
                                        // 有现有品类时，提供选择器 + 自定义选项
                                        Menu {
                                            ForEach(categoryOptions, id: \.self) { option in
                                                Button {
                                                    category = option
                                                } label: {
                                                    Label(option, systemImage: category == option ? "checkmark" : "")
                                                }
                                            }
                                            Button {
                                                category = "__CUSTOM_CATEGORY__"
                                            } label: {
                                                Label("+ 自定义品类", systemImage: category == "__CUSTOM_CATEGORY__" ? "checkmark" : "")
                                            }
                                        } label: {
                                            HStack {
                                                Text(category == "__CUSTOM_CATEGORY__" ? "自定义" : (category.isEmpty ? "选择品类" : category))
                                                    .font(AppTheme.Fonts.body)
                                                    .foregroundColor(category.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                                                    .lineLimit(1)
                                                Spacer()
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.caption)
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                            }
                                        }
                                        
                                        // 显示自定义输入框
                                        if category == "__CUSTOM_CATEGORY__" {
                                            TextField("输入新品类", text: $customCategoryInput)
                                                .font(AppTheme.Fonts.body)
                                                .foregroundColor(AppTheme.Colors.textPrimary)
                                                .autocorrectionDisabled()
                                                .padding(.top, AppTheme.Spacing.xs)
                                                .overlay(
                                                    Rectangle()
                                                        .frame(height: 1)
                                                        .foregroundColor(AppTheme.Colors.divider)
                                                        .alignmentGuide(.bottom) { $0[.bottom] }
                                                )
                                                .onSubmit {
                                                    if !customCategoryInput.isEmpty {
                                                        category = customCategoryInput
                                                        customCategoryInput = ""
                                                    }
                                                }
                                        }
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width * 0.4 - AppTheme.Spacing.lg * 2 - AppTheme.Spacing.md)
                                
                                // 城市
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                    Text("城市")
                                        .font(AppTheme.Fonts.caption2)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    Text(city.isEmpty ? "定位中..." : city)
                                        .font(AppTheme.Fonts.body)
                                        .foregroundColor(city.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(width: UIScreen.main.bounds.width * 0.25 - AppTheme.Spacing.md / 2)
                                
                                // 地区
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                    Text("地区")
                                        .font(AppTheme.Fonts.caption2)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    // 地区选择：使用Menu组件，基于当前城市的预设地区
                                    Menu {
                                        ForEach(districtOptions, id: \.self) { option in
                                            Button {
                                                self.district = option
                                            } label: {
                                                Label(option, systemImage: self.district == option ? "checkmark" : "")
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(district.isEmpty ? "选择地区" : district)
                                                .font(AppTheme.Fonts.body)
                                                .foregroundColor(district.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.Colors.textSecondary)
                                        }
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width * 0.35 - AppTheme.Spacing.lg * 2 - AppTheme.Spacing.md)
                            }
                        }
                        .padding(AppTheme.Spacing.lg)
                    }
                    
                    // ✅ 模块三：评分卡片
                    Card {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Text("评分")
                                .font(AppTheme.Fonts.subheadline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Spacer()
                            HStack(spacing: AppTheme.Spacing.xs) {
                                ForEach(1...5, id: \.self) { index in
                                    Image(systemName: index <= rating ? "star.fill" : "star")
                                        .foregroundColor(index <= rating ? AppTheme.Colors.secondary : AppTheme.Colors.textSecondary)
                                        .font(AppTheme.Fonts.headline)
                                        .onTapGesture { rating = index }
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.lg)
                    }
                    
                    // ✅ 模块四：位置信息卡片
                    Card {
                        VStack(spacing: AppTheme.Spacing.md) {
                            Text("地理位置")
                                .font(AppTheme.Fonts.subheadline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            if !address.isEmpty {
                                Text(address)
                                    .font(AppTheme.Fonts.body)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .padding(.bottom, AppTheme.Spacing.xs)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // 定位按钮
                            Button { showLocationPicker = true } label: {
                                HStack(spacing: AppTheme.Spacing.md) {
                                    Image(systemName: "map")
                                        .foregroundColor(AppTheme.Colors.primary)
                                    Text(address.isEmpty ? "点击选择位置" : "重新选择位置")
                                        .font(AppTheme.Fonts.body)
                                        .foregroundColor(AppTheme.Colors.primary)
                                    Spacer()
                                }
                                .padding(AppTheme.Spacing.md)
                                .background(AppTheme.Colors.lightBlue)
                                .cornerRadius(AppTheme.Radius.base)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(AppTheme.Spacing.lg)
                    }
                    
                    // ✅ 模块五：印象卡片
                    Card {
                        VStack(spacing: AppTheme.Spacing.md) {
                            // 一句话评价
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text("一句话评价")
                                    .font(AppTheme.Fonts.caption2)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                TextField("请输入你的评价", text: $review, axis: .vertical)
                                    .font(AppTheme.Fonts.body)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .lineLimit(3...5)
                                    .padding(.bottom, AppTheme.Spacing.xs)
                                    .overlay(
                                        Rectangle()
                                            .frame(height: 1)
                                            .foregroundColor(AppTheme.Colors.divider)
                                            .alignmentGuide(.bottom) { $0[.bottom] }
                                    )
                            }
                            
                            // 标签输入
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text("标签")
                                    .font(AppTheme.Fonts.caption2)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                TextField("输入标签 (用逗号分隔)", text: $tagsInput)
                                    .font(AppTheme.Fonts.body)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .padding(.bottom, AppTheme.Spacing.xs)
                                    .overlay(
                                        Rectangle()
                                            .frame(height: 1)
                                            .foregroundColor(AppTheme.Colors.divider)
                                            .alignmentGuide(.bottom) { $0[.bottom] }
                                    )
                            }
                        }
                        .padding(AppTheme.Spacing.lg)
                    }
                    
                    // 底部间距，避免被底部按钮遮挡
                    Spacer(minLength: 80)
                }
            }
            .padding(.top, AppTheme.Spacing.lg)
            
            // 顶部导航栏
            VStack {
                HStack {
                    // 左侧：取消按钮
                    Button { dismiss() } label: {
                        Text("取消")
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    // 中间：标题
                    Text("新餐厅录入")
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
                
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            
            // 底部固定保存按钮
            VStack {
                Spacer()
                Button { saveRestaurant() } label: {
                    Text("保存")
                        .font(AppTheme.Fonts.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.Colors.accent)
                        .cornerRadius(AppTheme.Radius.circle)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.bottom, AppTheme.Spacing.lg)
                }
                .disabled(name.isEmpty || address.isEmpty || district.isEmpty || city.isEmpty)
                .withHapticFeedback()
            }
        }
        // --- 弹窗逻辑集锦 ---
        .confirmationDialog("上传封面图", isPresented: $showActionSheet) {
            Button("📸 拍照") { showCamera = true }
            Button("🖼️ 从相册选择") { showPhotoPicker = true }
            Button("取消", role: .cancel) { }
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
    
    // ✅ 核心逻辑：保存时处理图片文件和标签
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
}
