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
    
    var body: some View {
        NavigationStack {
            Form {
                // ✅ 模块一：餐厅封面 (找回拍照功能)
                Section("餐厅封面") {
                    if let image = selectedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipped()
                                .cornerRadius(12)
                            
                            Button { selectedImage = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                            }
                            .padding(8)
                        }
                    } else {
                        Button { showActionSheet = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.largeTitle)
                                Text("添加封面图")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .foregroundColor(.gray)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // ✅ 模块二：基本信息 (找回星级评价)
                Section("基本信息") {
                    TextField("餐厅名称", text: $name)
                    
                    // 品类选择：动态混合录入
                    if categoryOptions.isEmpty {
                        // 无现有品类时，直接文本输入
                        TextField("输入品类", text: $category)
                            .autocorrectionDisabled()
                    } else {
                        // 有现有品类时，提供选择器 + 自定义选项
                        Picker("品类", selection: $category) {
                            ForEach(categoryOptions, id: \.self) { Text($0) }
                            Text("+ 自定义品类")
                                .tag("__CUSTOM_CATEGORY__")
                        }
                        
                        // 显示自定义输入框
                        if category == "__CUSTOM_CATEGORY__" {
                            TextField("输入新品类", text: $customCategoryInput)
                                .autocorrectionDisabled()
                                .onSubmit {
                                    if !customCategoryInput.isEmpty {
                                        category = customCategoryInput
                                        customCategoryInput = ""
                                    }
                                }
                        }
                    }
                    
                    // 城市显示
                    HStack {
                        Text("城市")
                        Spacer()
                        Text(city.isEmpty ? "定位中..." : city)
                            .font(.body)
                            .foregroundColor(city.isEmpty ? .secondary : .primary)
                    }
                    
                    // 地区选择：使用Menu组件，基于当前城市的预设地区
                    Menu {
                        ForEach(districtOptions, id: \.self) { district in
                            Button {
                                self.district = district
                            } label: {
                                Label(district, systemImage: self.district == district ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack {
                            Text("地区")
                            Spacer()
                            Text(district.isEmpty ? "选择地区" : district)
                                .foregroundColor(district.isEmpty ? .secondary : .primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 漂亮的星级评分交互
                    HStack {
                        Text("评分")
                        Spacer()
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= rating ? "star.fill" : "star")
                                .foregroundColor(index <= rating ? .orange : .gray)
                                .onTapGesture { rating = index }
                        }
                    }
                }

                // ✅ 模块三：位置信息 (集成选点器)
                Section("地理位置") {
                    if !address.isEmpty {
                        Text(address)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Button { showLocationPicker = true } label: {
                        Label(address.isEmpty ? "点击选择位置" : "重新选择位置", systemImage: "map")
                    }
                }

                // ✅ 模块四：印象 (自动换行)
                Section("印象") {
                    TextField("一句话评价", text: $review, axis: .vertical)
                        .lineLimit(3...5)
                    
                    TextField("输入标签 (用逗号分隔)", text: $tagsInput)
                        .font(.subheadline)
                }
            }
            .navigationTitle("新餐厅录入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveRestaurant() }
                        .disabled(name.isEmpty || address.isEmpty || district.isEmpty || city.isEmpty)
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
