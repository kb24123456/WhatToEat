import SwiftUI
import SwiftData
import MapKit
import PhotosUI

struct AddRestaurantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // --- 1. 表单基础数据 ---
    @State private var name = ""
    @State private var cuisine = "火锅" // 对应模型里的 type
    @State private var district = "江北"
    @State private var rating = 5
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
    
    // 选项配置
    private let cuisineOptions = ["火锅", "烧烤", "西餐", "快餐", "日料", "其它"]
    private let districtOptions = ["江北", "渝北", "渝中", "南岸", "沙坪坝", "其它"]
    
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
                    
                    Picker("菜系", selection: $cuisine) {
                        ForEach(cuisineOptions, id: \.self) { Text($0) }
                    }
                    
                    Picker("地区", selection: $district) {
                        ForEach(districtOptions, id: \.self) { Text($0) }
                    }
                    
                    // 漂亮的星级评分交互
                    HStack {
                        Text("推荐指数")
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

                // ✅ 模块四：评价与标签 (自动换行)
                Section("心得与标签") {
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
                        .disabled(name.isEmpty || address.isEmpty)
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
        }
    }
    
    // ✅ 核心逻辑：保存时处理图片文件和标签
    private func saveRestaurant() {
        // 1. 处理标签字符串转数组
        let tags = tagsInput.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 2. 将图片保存到磁盘并获取文件名
        let filename = selectedImage.flatMap { ImageManager.shared.saveImage($0) }
        
        // 3. 创建餐厅对象
        let newRestaurant = Restaurant(
            name: name,
            type: cuisine,
            district: district,
            rating: rating,
            address: address,
            latitude: latitude,
            longitude: longitude,
            coverPhotoFilename: filename,
            review: review,
            tags: tags,
            averagePrice: 0.0
        )
        
        // 4. 存入 SwiftData
        modelContext.insert(newRestaurant)
        dismiss()
    }
}
