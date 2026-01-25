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
    
    // --- 6. UI状态 ---
    @State private var isAutoFilled = false
    
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
            // 极微弱线性渐变背景，模拟高级艺术纸张质感
            LinearGradient(gradient: Gradient(colors: [Color.white, Color(hex: "#F9F7F5")]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .overlay {
                    // 使用ZStack实现悬浮效果
                    ZStack {
                        // 内容卡片容器 - 精确控制间距
                        VStack(spacing: 0) {
                            // 1. 页面标题 - 艺术化设计，对标LibraryView顶部标题
                            Text("新餐厅")
                                .font(AppTheme.Fonts.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#443F3B"))
                                .tracking(2)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, AppTheme.Spacing.sm)
                                
                            // 增加标题下方间距，确保与封面图之间有充足的呼吸感
                            Color.clear.frame(height: 24)
                            
                            // 2. 添加封面
                            CoverImageView(selectedImage: $selectedImage, showActionSheet: $showActionSheet)
                            
                            // 增大封面图与搜索框之间的垂直距离，从8pt增加到16pt
                            Color.clear.frame(height: 16)
                            
                            // 3. 位置搜索框
                            SearchBar(poiQuery: $poiQuery, searchResults: $searchResults, isSearching: $isSearching, searchPOI: searchPOI, fillInfoFromMapItem: fillInfoFromMapItem)
                            
                            // 微信式搜索结果列表 - 位于搜索框下方，与搜索框视觉过渡自然
                            if !isSearching && !searchResults.isEmpty {
                                // 搜索结果容器 - 微信式设计，与搜索框形成整体感
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(searchResults, id: \.self) { mapItem in
                                            Button(action: { 
                                                fillInfoFromMapItem(mapItem)
                                                // 点击后收起搜索列表
                                                searchResults = []
                                            }) {
                                                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                                    // 添加小图标
                                                    Image(systemName: "mappin.circle.fill")
                                                        .foregroundColor(AppTheme.Colors.primary)
                                                        .font(.system(size: 20))
                                                        .padding(.top, 2)
                                                    
                                                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                                        // 标题：餐厅名
                                                        Text(mapItem.name ?? "未知")
                                                            .font(AppTheme.Fonts.headline)
                                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                                        
                                                        // 副标题：距离 | 详细地址
                                                        HStack(spacing: 8) {
                                                            // 计算并显示距离
                                                            if let userLocation = locationManager.userLocation {
                                                                let mapItemLocation = CLLocation(latitude: mapItem.placemark.coordinate.latitude, longitude: mapItem.placemark.coordinate.longitude)
                                                                let distance = userLocation.distance(from: mapItemLocation)
                                                                Text(String(format: "%.1fkm", distance / 1000))
                                                                    .font(AppTheme.Fonts.caption)
                                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                                                
                                                                // 分隔符
                                                                Text("|")
                                                                    .font(AppTheme.Fonts.caption)
                                                                    .foregroundColor(AppTheme.Colors.divider)
                                                            }
                                                            
                                                            // 详细地址
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
                                            
                                            // 分割线
                                            Divider()
                                        }
                                    }
                                }
                                // 微信式高度约束：默认显示5行，支持滚动
                                .frame(height: min(CGFloat(searchResults.count) * 60, 300)) // 每行约60pt，最大300pt
                                .background(AppTheme.Colors.card)
                                // 与搜索框相同的圆角，保持视觉一致性
                                .cornerRadius(AppTheme.Radius.base)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                                )
                                // 与搜索框相似的阴影效果，增强整体感
                                .shadow(color: AppTheme.Colors.accent.opacity(0.1), radius: 8, x: 0, y: 2)
                            }
                            
                            // 搜索框与餐厅名称间距
                            Color.clear.frame(height: 6)
                            
                            // 4. 餐厅名称
                            NameTextField(name: $name, isAutoFilled: isAutoFilled)
                            
                            // 餐厅名称与城市地区间距
                            Color.clear.frame(height: 6)
                            
                            // 5. 城市与地区
                            CityDistrictView(city: $city, district: $district, districtOptions: districtOptions)
                            
                            // 城市地区与品类评分间距
                            Color.clear.frame(height: 6)
                            
                            // 6. 品类与评分
                            CategoryRatingView(category: $category, rating: $rating, categoryOptions: categoryOptions)
                            
                            // 品类评分与标签评价间距
                            Color.clear.frame(height: 6)
                            
                            // 7. 标签与评价
                            TagsReviewView(tagsInput: $tagsInput, review: $review, isAutoFilled: isAutoFilled)
                            
                            // 标签评价与底部操作行间距
                            Color.clear.frame(height: AppTheme.Spacing.md)
                            
                            // 8. 底部操作行 - 质感级重构，符合用户输入动线
                            HStack(spacing: 16) {
                                // 取消按钮 - 圆角矩形按钮，占据约30%宽度
                                Button("取消") { 
                                    if let onClose = onClose {
                                        onClose()
                                    } else {
                                        dismiss()
                                    }
                                }
                                .font(AppTheme.Fonts.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.vertical, AppTheme.Spacing.sm)
                                .background(AppTheme.Colors.lightGray)
                                .cornerRadius(AppTheme.Radius.base)
                                .withHapticFeedback()
                                // 精确控制宽度比例
                                .frame(width: UIScreen.main.bounds.width * 0.25) // 约30%宽度
                                
                                // 保存按钮 - 哑光微立体设计，占据约70%宽度
                                Button("保存") { saveRestaurant() }
                                    .font(AppTheme.Fonts.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppTheme.Spacing.lg)
                                    .padding(.vertical, AppTheme.Spacing.sm)
                                    .background(AppTheme.Colors.accent)
                                    .cornerRadius(AppTheme.Radius.base)
                                    // 红色系深度投影，增强哑光微立体效果
                                    .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                                    .disabled(name.isEmpty || address.isEmpty || district.isEmpty || city.isEmpty)
                                    .withHapticFeedback()
                                    // 占据剩余空间，约70%宽度
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                        .padding(.bottom, keyboardHeight)
                    }
                }
        }
    

    
    var body: some View {
        NavigationStack {
            mainContent
                // 隐藏默认导航栏
                .navigationBarHidden(true)
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
    
    // 子视图：封面图 - 拍立得效果
    private struct CoverImageView: View {
        @Binding var selectedImage: UIImage?
        @Binding var showActionSheet: Bool
        
        var body: some View {
            ZStack {
                if let image = selectedImage {
                    // 拍立得照片效果 - 水平对齐
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(AppTheme.Radius.base)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 2, y: 5)
                        .overlay(
                            Group {
                                // 和纸胶带装饰块 - 水平对齐
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(height: 15)
                                    .padding(.horizontal, 30)
                                    .offset(y: -75)
                                
                                // 边框效果
                                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
                            }
                        )
                } else {
                    // 空状态拍立得效果 - 水平对齐
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
                        .background(AppTheme.Colors.lightGray)
                        .cornerRadius(AppTheme.Radius.base)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 2, y: 5)
                        .overlay(
                            Group {
                                // 和纸胶带装饰块 - 水平对齐
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(height: 15)
                                    .padding(.horizontal, 30)
                                    .offset(y: -75)
                                
                                // 边框效果 - 保持2.0pt白色描边
                                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
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
        
        // 添加焦点状态，用于检测用户点击搜索框的动作
        @FocusState private var isFocused: Bool
        
        var body: some View {
            VStack(spacing: 0) {
                // 搜索条 - 内凹压印效果，与下方列表过渡自然
                HStack {
                    // 突出智能搜索功能的图标
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.Colors.accent)
                        .font(.system(size: 16))
                        .symbolRenderingMode(.hierarchical)
                    
                    TextField("", text: $poiQuery, onCommit: { 
                        searchPOI()
                        // 提交搜索后保持焦点
                        isFocused = true
                    })
                        .font(AppTheme.Fonts.body)
                        .autocorrectionDisabled()
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .placeholder("输入店名智能填充信息...", 
                                   color: AppTheme.Colors.textSecondary.opacity(0.8), 
                                   isEmpty: poiQuery.isEmpty)
                        .focused($isFocused)
                        // 确保键盘显示搜索按钮
                        .keyboardType(.default)
                        .submitLabel(.search)
                        // 当搜索框获得焦点时，自动加载附近POI
                        .onChange(of: isFocused) {
                            oldValue, newValue in
                            if newValue {
                                // 获得焦点时搜索
                                if poiQuery.isEmpty {
                                    searchPOI()
                                }
                            } else {
                                // 失去焦点时，延迟关闭搜索结果，以便用户可以点击结果
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    searchResults = []
                                }
                            }
                        }
                        // 实时搜索：当输入内容变化时，更新搜索结果
                        .onChange(of: poiQuery) {
                            _, _ in
                            searchPOI()
                        }
                    
                    if !poiQuery.isEmpty {
                        Button(action: { 
                            poiQuery = ""
                            // 清空搜索框时，重新加载附近餐厅
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
                .frame(height: 40)
                .padding(.horizontal, AppTheme.Spacing.md)
                // Hero级搜索框设计 - 发光效果，引导用户优先点击
                .background(AppTheme.Colors.lightGray.opacity(0.3)) // 极浅灰色背景，突出红色发光效果
                .overlay(
                    // 顶部圆角边框，与下方列表过渡自然
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .stroke(AppTheme.Colors.accent.opacity(0.4), lineWidth: 1.5) // 强化红色边框
                )
                // 使用标准圆角，与下方列表形成自然过渡
                .cornerRadius(AppTheme.Radius.base)
                // 呼吸感的红色外发光效果
                .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 0)
                
                // 搜索中状态指示器
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(AppTheme.Spacing.md)
                        Spacer()
                    }
                    .background(AppTheme.Colors.card)
                    // 使用标准圆角，与搜索框和下方列表过渡自然
                    .cornerRadius(AppTheme.Radius.base)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                            .stroke(AppTheme.Colors.divider, lineWidth: 1)
                    )
                    .shadow(color: AppTheme.Shadows.base.color, radius: AppTheme.Shadows.base.radius, x: AppTheme.Shadows.base.x, y: AppTheme.Shadows.base.y)
                    // 与搜索框紧密连接，没有偏移
                    .offset(y: 4)
                }
            }
        }
    }
    
    // 子视图：餐厅名称
    private struct NameTextField: View {
        @Binding var name: String
        var isAutoFilled: Bool
        
        var body: some View {
            HStack {
                TextField("餐厅名称", text: $name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .foregroundColor(isAutoFilled ? AppTheme.Colors.primary : .primary)
            }
            .frame(height: 44)
            // 内凹压印效果 + 自动填充高亮
            .background(
                Group {
                    AppTheme.Colors.lightGray.opacity(0.5)
                    // 极其微弱的蓝色呼吸灯效果
                    if isAutoFilled {
                        AppTheme.Colors.lightBlue.opacity(0.15)
                            .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAutoFilled)
                    }
                }
            )
            .overlay(name.isEmpty ? nil : AppTheme.Colors.lightBlue.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(AppTheme.Colors.divider.opacity(0.5), lineWidth: 0.5)
            )
            .cornerRadius(AppTheme.Radius.base)
            // 极轻的背景投影，增强层级感
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
    
    // 子视图：城市与地区
    private struct CityDistrictView: View {
        @Binding var city: String
        @Binding var district: String
        var districtOptions: [String]
        
        var body: some View {
            HStack(spacing: 12) {
                // 城市名
                Text(city.isEmpty ? "定位中..." : city)
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(city.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                
                // 垂直分隔线
                Rectangle()
                    .fill(AppTheme.Colors.divider)
                    .frame(width: 0.5, height: 18)
                
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
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                
                Spacer()
            }
            .frame(height: 40)
            .padding(.horizontal, AppTheme.Spacing.md)
            // 内凹压印效果：深色描边 + 浅色背景
            .background(AppTheme.Colors.lightGray.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(AppTheme.Colors.divider.opacity(0.5), lineWidth: 0.5)
            )
            .cornerRadius(AppTheme.Radius.base)
            // 极轻的背景投影，增强层级感
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            // 极轻的背景投影，增强层级感
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
    
    // 子视图：品类与评分
    private struct CategoryRatingView: View {
        @Binding var category: String
        @Binding var rating: Int
        var categoryOptions: [String]
        
        var body: some View {
            HStack(spacing: AppTheme.Spacing.md) {
                // 左侧品类 Menu - 平分空间
                Menu {
                    ForEach(categoryOptions, id: \.self) { option in
                        Button { category = option }
                        label: {
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
                    .frame(maxWidth: .infinity)
                }
                
                // 右侧五星评分 - 平分空间，星号大小18pt
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= rating ? "star.fill" : "star")
                            .foregroundColor(index <= rating ? AppTheme.Colors.secondary : AppTheme.Colors.textSecondary)
                            .font(.system(size: 18)) // 星号大小调整为18pt
                            .symbolRenderingMode(.hierarchical)
                            .onTapGesture { rating = index }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 40)
            // 内凹压印效果：深色描边 + 浅色背景
            .background(AppTheme.Colors.lightGray.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(AppTheme.Colors.divider.opacity(0.5), lineWidth: 0.5)
            )
            .cornerRadius(AppTheme.Radius.base)
        }
    }
    
    // 子视图：标签与评价
    private struct TagsReviewView: View {
        @Binding var tagsInput: String
        @Binding var review: String
        var isAutoFilled: Bool
        
        var body: some View {
            VStack(spacing: 8) {
                // 标签行：内凹压印效果
                HStack {
                    TextField("标签 (用逗号分隔)", text: $tagsInput)
                        .font(AppTheme.Fonts.body)
                        .autocorrectionDisabled()
                        .padding(.vertical, 6)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .foregroundColor(isAutoFilled ? AppTheme.Colors.primary : .primary)
                }
                // 内凹压印效果：深色描边 + 浅色背景 + 自动填充高亮
                .background(
                    Group {
                        AppTheme.Colors.lightGray.opacity(0.5)
                        if isAutoFilled {
                            AppTheme.Colors.lightBlue.opacity(0.15)
                                .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAutoFilled)
                        }
                    }
                )
                .overlay(tagsInput.isEmpty ? nil : AppTheme.Colors.lightBlue.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                        .stroke(AppTheme.Colors.divider.opacity(0.5), lineWidth: 0.5)
                )
                .cornerRadius(AppTheme.Radius.base)
                // 极轻的背景投影，增强层级感，与自动填充高亮效果完美融合
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                
                // 一句话评价 - 重构设计，移除装饰线条
                TextField("一句话评价", text: $review, axis: .vertical)
                    .font(AppTheme.Fonts.body)
                    .lineLimit(2)
                    .textFieldStyle(.plain)
                    // 增加垂直内边距，让文字在框内更居中舒展
                    .padding(.vertical, 12)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    // 极浅的奶油色背景，像一张平整的便签
                    .background(Color(hex: "#FFF9E6"))
                    .cornerRadius(AppTheme.Radius.base)
            }
            // 调整整体高度，确保评价框高度适合固定两行文本
            .frame(height: 130)
        }
    }
    

    
    // 核心逻辑：地图智能搜索 - 支持附近POI检索和距离排序
    private func searchPOI() {
        isSearching = true
        
        let request = MKLocalSearch.Request()
        
        // 1. 设置搜索参数
        if !poiQuery.isEmpty {
            // 有输入时，使用自然语言查询
            request.naturalLanguageQuery = poiQuery
        } else {
            // 无输入时，搜索附近的餐厅
            request.naturalLanguageQuery = "餐厅"
        }
        
        // 只搜索兴趣点，优先显示餐厅
        request.resultTypes = .pointOfInterest
        
        // 2. 设置搜索区域（如果有定位）
        if let userLocation = locationManager.userLocation {
            // 以当前位置为中心，设置搜索半径
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
                    // 3. 过滤出餐厅/餐饮类POI
                    var filteredResults = response.mapItems.filter { mapItem in
                        guard let categories = mapItem.pointOfInterestCategory else { return false }
                        let isRestaurant = categories == .restaurant || categories == .cafe || categories == .foodMarket
                        
                        // 如果有搜索输入，还要确保名称包含搜索内容
                        if self.poiQuery.isEmpty {
                            return isRestaurant
                        } else {
                            // 模糊搜索：名称包含搜索内容
                            let name = mapItem.name?.lowercased() ?? ""
                            let query = self.poiQuery.lowercased()
                            return isRestaurant && name.contains(query)
                        }
                    }
                    
                    // 4. 按距离排序（如果有定位）
                    if let userLocation = self.locationManager.userLocation {
                        filteredResults.sort { mapItem1, mapItem2 in
                            // 将CLLocationCoordinate2D转换为CLLocation对象，使用distance(from:)方法计算距离
                            let location1 = CLLocation(latitude: mapItem1.placemark.coordinate.latitude, longitude: mapItem1.placemark.coordinate.longitude)
                            let location2 = CLLocation(latitude: mapItem2.placemark.coordinate.latitude, longitude: mapItem2.placemark.coordinate.longitude)
                            let distance1 = location1.distance(from: userLocation)
                            let distance2 = location2.distance(from: userLocation)
                            return distance1 < distance2
                        }
                    }
                    
                    // 5. 默认显示5行附近位置结果
                    self.searchResults = Array(filteredResults.prefix(5))
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
        
        // 设置自动填充标识，用于高亮效果
        isAutoFilled = true
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
        // 1. 处理标签字符串转数组 - 支持英文逗号(,)、中文逗号(，)、空格()作为分隔符
        let tags = tagsInput.components(
            separatedBy: CharacterSet(charactersIn: ",， ")
        )
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
                // 保存成功后，必须调用 onClose?() 闭包，触发加号缩回动画
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