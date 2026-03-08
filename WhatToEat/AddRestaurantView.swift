import SwiftUI
import SwiftData
import MapKit
import PhotosUI

// MARK: - 添加餐厅页面（全新重构版）
struct AddRestaurantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var onClose: (() -> Void)?
    
    @Query private var allRestaurants: [Restaurant]
    @ObservedObject private var locationManager = LocationManager.shared
    
    // MARK: - Form Data
    @State private var name = ""
    @State private var category = ""
    @State private var district = ""
    @State private var city = ""
    @State private var rating = 0.0
    @State private var review = ""
    @State private var address = ""
    @State private var latitude = 0.0
    @State private var longitude = 0.0
    @State private var coverImages: [UIImage] = []
    @State private var selectedTags: [String] = []
    @State private var imageOpacity: Double = 0.0
    
    // MARK: - UI States
    @State private var showSmartSearch = false
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showLocationPicker = false
    @State private var showConfetti = false
    @State private var showSuccessToast = false
    @State private var showCommentInput = false

    // MARK: - Editing States
    @State private var isEditingReview = false
    @State private var editedReview = ""
    @State private var isEditingTags = false
    @State private var newTagInput = ""
    
    // MARK: - 评论输入模糊效果
    @State private var isCommentEditing = false
    
    // MARK: - Animation States
    @State private var isAppeared = false
    @State private var highlightName = false
    @State private var highlightDistrict = false
    @State private var highlightCategory = false
    @State private var highlightAddress = false
    @State private var categoryTextPulse: Double = 1.0
    @State private var isCategoryHighlighted: Bool = false
    @State private var isCategoryBreathing: Bool = false
    
    // 自动填充级联动画状态
    @State private var nameFieldOffset: CGFloat = 20
    @State private var districtFieldOffset: CGFloat = 20
    @State private var nameFieldOpacity: Double = 0
    @State private var districtFieldOpacity: Double = 0
    
    // MARK: - Keyboard Performance Optimization
    @State private var anyFieldFocused = false  // 追踪是否有输入框聚焦
    
    // MARK: - Category Match Status
    enum MatchStatus: Equatable {
        case none
        case autoMatched(matchedCategory: String)
        case manuallyRequired
    }
    
    @State private var categoryMatchStatus: MatchStatus = .none
    @State private var categoryMatchMessage: String = ""
    
    // MARK: - 创建新品类相关状态
    @State private var showCreateCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var showDuplicateCategoryAlert = false
    @State private var duplicateCategoryName = ""
    
    let presetTags = ["氛围感", "老字号", "二刷", "排队王", "性价比"]
    
    var categoryOptions: [String] {
        CategoryManager.shared.getSelectableCategories(context: modelContext)
    }
    
    var districtOptions: [String] {
        RegionManager.shared.getDistricts(for: city)
    }
    
    private var closeAction: () -> Void {
        return onClose ?? { dismiss() }
    }

    private var addPrimaryText: Color {
        colorScheme == .dark ? Color.fixedHex("#DCE6F6") : AppTheme.Colors.darkText
    }

    private var addSecondaryText: Color {
        colorScheme == .dark ? Color.fixedHex("#AAB8CD") : AppTheme.Colors.mediumGray
    }

    private var addHintText: Color {
        colorScheme == .dark ? Color.fixedHex("#8393AC") : AppTheme.Colors.lightText
    }

    private var addPanelBackground: Color {
        colorScheme == .dark ? Color.fixedHex("#1E2C40").opacity(0.82) : Color.white.opacity(0.95)
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
                
                scrollContent(geometry: geometry)
                
                // Confetti 特效
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }

                // Oreo: 成功仪式弹窗
                if showSuccessToast {
                    SuccessToastView()
                        .transition(.scale.combined(with: .opacity))
                }
                
                // 评论输入时的页面变暗效果（替代高斯模糊，零GPU开销）
                if isCommentEditing {
                    Color.black.opacity(0.15)  // 15%黑色遮罩，视觉聚焦
                        .ignoresSafeArea()
                        .opacity(isCommentEditing ? 1 : 0)  // 平滑透明度过渡
                        .animation(.easeInOut(duration: 0.25), value: isCommentEditing)  // 0.25秒动画，更轻快
                        .onTapGesture {
                            // 点击遮罩区域退出键盘
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                }
                
            }
            // 添加下滑返回手势
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height > 100 {
                            closeAction()
                        }
                    }
            )
        }
        .confirmationDialog("选择封面图来源", isPresented: $showActionSheet) {
            Button("拍照") { showCamera = true }
            Button("从相册选择") { showPhotoPicker = true }
            Button("取消", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(selectedImages: $coverImages)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            handlePhotoPickerChange(newItem)
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPicker { item in
                handleLocationSelect(item)
            }
        }
        .sheet(isPresented: $showSmartSearch) {
            SmartSearchSheet(
                selectedName: $name,
                selectedAddress: $address,
                selectedDistrict: $district,
                selectedCategory: $category,
                selectedLatitude: $latitude,
                selectedLongitude: $longitude,
                onAutoFill: handleAutoFill
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            handleViewAppear()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAppeared = true
            }
        }
        .onDisappear {
            // 视图消失时停止呼吸动画，防止后台继续震动
            stopCategoryBreathingAnimation()
        }
    }
    
    // MARK: - Background（弥散渐变背景）
    private var backgroundGradient: some View {
        DiffuseGradientBackground(
            blurRadius: colorScheme == .dark ? 86 : 72,
            colorOpacity: colorScheme == .dark ? 0.44 : 0.5
        )
    }
    
    // MARK: - Scroll Content（无父容器，组件直接显示 - 参考 CheckInView）
    private func scrollContent(geometry: GeometryProxy) -> some View {
        ScrollView(showsIndicators: false) {
            // 禁用键盘避让机制，使用代理输入模式
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // 顶部标题栏（带关闭按钮）- 与 CheckInView 同款
                    ZStack {
                        // 中间标题
                        Text("新发现！")
                            .font(.headline)
                            .foregroundColor(addPrimaryText)
                        
                        // 右侧关闭按钮
                        HStack {
                            Spacer()
                            Button {
                                closeAction()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(addSecondaryText)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(addPanelBackground.opacity(0.72))
                                    )
                            }
                        }
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)

                    // 照片容器（初始居中，选择餐厅后移动到左边）
                    photoContainer
                        .padding(.horizontal, 50)
                        .padding(.bottom, 16)
                    
                    // 智能搜索入口
                    smartSearchButton
                        .padding(.horizontal, 50)
                        .padding(.bottom, 16)
                    
                    // 地址信息行（如果有）
                    if !address.isEmpty {
                        addressSubline
                            .padding(.horizontal, 50)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // 评分
                    unifiedRatingRow
                        .padding(.vertical, 16)
                        .padding(.horizontal, 50)
                    
                    // 评价
                    unifiedReviewRow
                        .padding(.vertical, 16)
                        .padding(.horizontal, 50)
                    
                    // 标签
                    unifiedTagsRow
                        .id("TagModule")
                        .padding(.top, 16)
                        .padding(.horizontal, 50)
                        .onChange(of: isEditingTags) { _, newValue in
                            if newValue {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        proxy.scrollTo("TagModule", anchor: .bottom)
                                    }
                                }
                            }
                        }

                    // 保存按钮
                    saveButton
                        .padding(.top, 24)
                        .padding(.horizontal, 50)
                        .padding(.bottom, 40)

                    Spacer().frame(height: 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .offset(y: isAppeared ? 0 : 50)
        .opacity(isAppeared ? 1 : 0)
        // 禁用键盘避让机制，使用代理输入模式（InlineTagInput/InlineCommentInput）
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - 左侧缩略封面图（虚线引导框）
    private var thumbnailImageView: some View {
        ZStack {
            if let firstImage = coverImages.first {
                // 有图片时显示图片
                Image(uiImage: firstImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(imageOpacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.4)) {
                            imageOpacity = 1.0
                        }
                    }
            } else {
                // 无图片时显示虚线引导框
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(
                            lineWidth: 1.5,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [6, 4]
                        )
                    )
                    .foregroundColor(addHintText.opacity(0.5))
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(addPanelBackground.opacity(0.62))
                    )
                
                VStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(addHintText)
                    Text("添加照片")
                        .font(.system(size: 11))
                        .foregroundColor(addHintText)
                }
            }
        }
        .frame(width: 100, height: 100)
        .onTapGesture {
            showActionSheet = true
        }
    }
    
    // MARK: - 照片容器（初始居中，选择餐厅后左移显示信息）
    // 计算属性：避免在 body 中重复计算
    private var hasRestaurantInfo: Bool {
        !name.isEmpty || !district.isEmpty || !category.isEmpty
    }
    
    private var photoContainer: some View {
        HStack(spacing: 16) {
            // 照片视图
            thumbnailImageView
                .frame(width: 100, height: 100)
            
            // 信息区域（有内容时显示）
            if hasRestaurantInfo {
                infoPodContainer
                    .frame(maxWidth: .infinity, maxHeight: 100, alignment: .leading)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity, alignment: hasRestaurantInfo ? .leading : .center)
        .animation(AppTheme.Animations.standardSpring, value: hasRestaurantInfo)
    }
    
    // MARK: - 右侧基础信息容器（有信息时显示）
    private var infoPodContainer: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 餐厅名称（大标题，参考人均消费数字动效）
            Text(name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(addPrimaryText)
                .lineLimit(2)
                .contentTransition(.numericText())
                .animation(AppTheme.Animations.standardSpring, value: name)
            
            // 区域和品类放在同一行
            HStack(spacing: 12) {
                // 区域
                if !district.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                        Text(district)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(addSecondaryText)
                    .contentTransition(.numericText())
                    .animation(AppTheme.Animations.standardSpring, value: district)
                }
                
                // 分隔点
                if !district.isEmpty && !category.isEmpty {
                    Text("·")
                        .font(.system(size: 13))
                        .foregroundColor(addHintText)
                }
                
                // 品类（可点击重新选择）
                if !category.isEmpty {
                    Menu {
                        ForEach(categoryOptions, id: \.self) { option in
                            Button(option) {
                                withAnimation(AppTheme.Animations.standardSpring) {
                                    category = option
                                }
                            }
                        }
                        Divider()
                        Button {
                            showCreateCategoryAlert = true
                        } label: {
                            Label("创建新品类", systemImage: "plus")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 12))
                                .foregroundColor(addSecondaryText)
                            Text(category)
                                .font(.system(size: 13))
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(addSecondaryText)
                        }
                    }
                    .contentTransition(.numericText())
                    .animation(AppTheme.Animations.standardSpring, value: category)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .alert("创建新品类", isPresented: $showCreateCategoryAlert) {
            TextField("输入品类名称", text: $newCategoryName)
            Button("取消", role: .cancel) {
                newCategoryName = ""
            }
            Button("创建") {
                createNewCategory()
            }
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("请输入新的餐厅品类名称")
        }
        .alert("品类已存在", isPresented: $showDuplicateCategoryAlert) {
            Button("取消", role: .cancel) {
                duplicateCategoryName = ""
            }
            Button("直接选用") {
                selectExistingCategory(duplicateCategoryName)
            }
        } message: {
            Text("「\(duplicateCategoryName)」已存在，是否为你直接选用？")
        }
    }

    // 保留旧实现供参考（已合并到infoPodContainer中）
    private var nameTextField: some View {
        TextField("餐厅名称", text: $name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(addPrimaryText)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(addPanelBackground)
            )
    }
    
    // MARK: - 筛选胶囊标签（与 LibraryView 同步 - 奥利奥黑白平衡）
    private func filterCapsuleLabel(title: String, isSelected: Bool) -> some View {
        // 截断文本：超过4个字显示省略号
        let displayTitle = title.count > 4 ? String(title.prefix(3)) + "…" : title
        
        return HStack(spacing: 4) {
            Text(displayTitle)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                // 未选中：深黑文字 | 选中：白色文字
                .foregroundColor(isSelected ? AppTheme.Colors.primaryButtonText : addPrimaryText)
                // 固定宽度和高度，不随内容变化
                .frame(width: 52, height: 18, alignment: .center)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
                // 未选中：Baby Blue | 选中：白色
                .foregroundColor(isSelected ? AppTheme.Colors.primaryButtonText.opacity(0.8) : AppTheme.Colors.babyBlue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                // 未选中：纯白实色 | 选中：纯黑实色
                .fill(isSelected ? AppTheme.Colors.primaryButtonBackground : AppTheme.Colors.secondaryButtonBackground)
        )
        // 轻微阴影增加悬浮感
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 6,
            x: 0,
            y: 3
        )
    }
    
    private var districtCapsule: some View {
        Menu {
            Button("选择区域") { district = "" }
            Divider()
            ForEach(districtOptions, id: \.self) { option in
                Button(option) { district = option }
            }
        } label: {
            filterCapsuleLabel(
                title: district.isEmpty ? "地区" : district,
                isSelected: !district.isEmpty
            )
        }
    }
    
    private var categoryCapsule: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("选择品类") {
                    category = ""
                    categoryMatchStatus = .none
                }
                Divider()
                ForEach(categoryOptions, id: \.self) { option in
                    Button(option) {
                        category = option
                        categoryMatchStatus = .none
                    }
                }
                Divider()
                Button {
                    showCreateCategoryAlert = true
                } label: {
                    Label("创建新品类", systemImage: "plus")
                }
            } label: {
                filterCapsuleLabel(
                    title: category.isEmpty ? "品类" : category,
                    isSelected: !category.isEmpty
                )
            }

            // 品类匹配提示
            if categoryMatchStatus == .manuallyRequired {
                Text("💡 未能识别，请手动选择")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.Colors.iconAmber)
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
        .alert("创建新品类", isPresented: $showCreateCategoryAlert) {
            TextField("输入品类名称", text: $newCategoryName)
            Button("取消", role: .cancel) {
                newCategoryName = ""
            }
            Button("创建") {
                createNewCategory()
            }
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("请输入新的餐厅品类名称")
        }
        .alert("品类已存在", isPresented: $showDuplicateCategoryAlert) {
            Button("取消", role: .cancel) {
                duplicateCategoryName = ""
            }
            Button("直接选用") {
                selectExistingCategory(duplicateCategoryName)
            }
        } message: {
            Text("「\(duplicateCategoryName)」已存在，是否为你直接选用？")
        }
    }

    // MARK: - 创建新品类
    private func createNewCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        do {
            let newCategory = try CategoryManager.shared.createCategory(
                name: trimmedName,
                context: modelContext
            )

            // 成功触感反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // 自动选中新创建的品类
            withAnimation(AppTheme.Animations.standardSpring) {
                category = newCategory.name
                categoryMatchStatus = .none
            }

            // 重置状态
            newCategoryName = ""

        } catch let error as CategoryError {
            switch error {
            case .duplicateName:
                // 品类已存在，弹出确认框
                duplicateCategoryName = trimmedName
                showDuplicateCategoryAlert = true
                
            case .emptyName, .saveFailed:
                // 其他错误，触感反馈
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                AppLogger.error("创建品类失败: \(error.localizedDescription)", category: .storage)
            }
            
        } catch {
            // 未知错误
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            AppLogger.error("创建品类失败: \(error.localizedDescription)", category: .storage)
        }
    }
    
    // MARK: - 选用已存在的品类
    private func selectExistingCategory(_ categoryName: String) {
        withAnimation(AppTheme.Animations.standardSpring) {
            category = categoryName
            categoryMatchStatus = .none
        }
        
        // 成功触感反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // 重置状态
        newCategoryName = ""
        duplicateCategoryName = ""
    }
    
    // MARK: - 地址信息行（最多2行显示）
    private var addressSubline: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12))
                .foregroundColor(addHintText)
                .padding(.top, 2)
            
            Text(address)
                .font(.caption)
                .foregroundColor(addSecondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button {
                showLocationPicker = true
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "map")
                        .font(.system(size: 10))
                    Text("地图")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(AppTheme.Colors.iconBlue)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
    }
    
    private var photoPickerButton: some View {
        Button {
            showActionSheet = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 14))
                .foregroundColor(addPrimaryText)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(addPanelBackground.opacity(0.9))
                        .overlay(
                            Circle()
                                .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
    }
    
    // MARK: - Smart Search Button Content（用于 Bento Card）
    private var smartSearchButtonContent: some View {
        Button {
            showSmartSearch = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)

                Text("智能搜索...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(addSecondaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(addHintText)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Address Subline Content（用于 Bento Card）
    private var addressSublineContent: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12))
                .foregroundColor(addHintText)
                .padding(.top, 2)
            
            Text(address)
                .font(.caption)
                .foregroundColor(addSecondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button {
                showLocationPicker = true
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "map")
                        .font(.system(size: 10))
                    Text("地图")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(AppTheme.Colors.iconBlue)
            }
            .padding(.top, 2)
        }
    }
    
    // MARK: - Smart Search Button（全区域响应点击）
    private var smartSearchButton: some View {
        Button {
            showSmartSearch = true
        } label: {
            HStack(spacing: 12) {
                // 图标改为 darkText
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(addPrimaryText)

                // 修改后的文本
                Text("只需店名，其余交给我！")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(addSecondaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(addHintText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // 关键修复：确保整个区域可点击
        }
        .buttonStyle(ScaleButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(addPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.Colors.headerPillBorder, lineWidth: 0.6)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 评分、评价、标签一体化容器
    private var unifiedInputSection: some View {
        VStack(spacing: 0) {
            // 1. 评分区域
            unifiedRatingRow
                .padding(.vertical, 20)
            
            // 2. 评价区域（保留编辑动效）
            unifiedReviewRow
                .padding(.vertical, 20)
            
            // 3. 标签区域（保留编辑动效）
            unifiedTagsRow
                .padding(.vertical, 20)
        }
        .cardStyle()
    }

    // MARK: - 评分行（奶脂风格颗粒条）
    private var unifiedRatingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("评分")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(addPrimaryText)
                .tracking(1.5)

            // Dock 栏评分系统
            DockRatingView(rating: $rating)
        }
    }

    // MARK: - 评价行（内联输入框，点击直接弹出键盘）
    private var unifiedReviewRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack(alignment: .center, spacing: 0) {
                Text("一句话点评")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(addPrimaryText)
                    .tracking(1.5)

                Spacer()
            }

            // 内联评论输入框（点击直接弹出带 inputAccessoryView 的键盘）
            InlineCommentInputView(
                text: $review,
                placeholder: "点击添加点评...",
                onEditingChanged: { isEditing in
                    isCommentEditing = isEditing
                }
            )
        }
    }

    // MARK: - 标签行（Clean Input 风格）
    private var unifiedTagsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack(alignment: .center, spacing: 0) {
                Text("标签")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(addPrimaryText)
                    .tracking(1.5)

                Spacer()

                // 编辑状态下的取消/完成按钮
                if isEditingTags {
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(AppTheme.Animations.editingSpring) {
                                isEditingTags = false
                                newTagInput = ""
                            }
                        } label: {
                            Text("取消")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(addSecondaryText)
                        }

                        Button {
                            withAnimation(AppTheme.Animations.editingSpring) {
                                isEditingTags = false
                                newTagInput = ""
                            }
                        } label: {
                            Text("完成")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.Colors.accent)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            // 标签内容
            VStack(spacing: 0) {
                tagsLayoutContainer

                // 编辑状态下的推荐标签
                if isEditingTags {
                    presetTagsSection
                        .padding(.top, 16)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isEditingTags)
            .onTapGesture {
                if !isEditingTags {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isEditingTags = true
                    }
                }
            }
        }
    }
    
    // MARK: - 标签布局容器
    @ViewBuilder
    private var tagsLayoutContainer: some View {
        if isEditingTags {
            tagsEditingLayout
        } else {
            tagsDisplayLayout
        }
    }
    
    // MARK: - 编辑模式标签布局（无卡片背景）
    private var tagsEditingLayout: some View {
        FlowLayout(spacing: 10) {
            ForEach(selectedTags, id: \.self) { tag in
                tagSticker(tag)
            }
            newTagInputField
        }
    }
    
    // MARK: - 展示模式标签布局（无卡片背景，包含新标签输入胶囊）
    private var tagsDisplayLayout: some View {
        FlowLayout(spacing: 10) {
            ForEach(selectedTags, id: \.self) { tag in
                tagSticker(tag)
            }
            // 新标签输入胶囊（与 RestaurantDetailView 和 ProfileView 同款）
            newTagInputButton
        }
    }
    
    // MARK: - 新标签输入按钮（胶囊形式，虚线边框）
    private var newTagInputButton: some View {
        Button {
            withAnimation(AppTheme.Animations.editingSpring) {
                isEditingTags = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("新标签")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(addSecondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .strokeBorder(
                        style: StrokeStyle(
                            lineWidth: 1.2,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [5, 3]
                        )
                    )
                    .foregroundColor(addHintText.opacity(0.4))
                    .background(
                        Capsule()
                            .fill(addPanelBackground.opacity(0.62))
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - 推荐标签区域
    private var presetTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐标签")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(addHintText)

            FlowLayout(spacing: 8) {
                ForEach(presetTags.filter { !selectedTags.contains($0) }, id: \.self) { tag in
                    presetTagButton(tag)
                }
            }
        }
    }

    // MARK: - 新标签输入框（使用 InlineTagInput，与评论输入同款）
    private var newTagInputField: some View {
        InlineTagInputView(
            text: $newTagInput,
            placeholder: "新标签...",
            onSubmit: addNewTag,
            onEditingChanged: { isEditing in
                // 可以在这里处理编辑状态变化
            }
        )
    }

    // MARK: - Rating Section（Premium Soft UI）
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("评分")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            // 星星
            HStack(spacing: 12) {
                ForEach(0..<5) { index in
                    Button {
                        withAnimation(AppTheme.Animations.quickSpring) {
                            rating = Double(index + 1)
                        }
                    } label: {
                        Image(systemName: index < Int(rating) ? "star.fill" : "star")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(Color(hex: index < Int(rating) ? "#FFB800" : "#BDBDBD"))
                            .scaleEffect(index < Int(rating) ? 1.0 : 0.9)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
        .padding(20)
        .premiumCard()
    }
    
    // MARK: - Review Section（使用 inputAccessoryView）
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("评价")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            // 内联评论输入框（点击直接弹出带 inputAccessoryView 的键盘）
            InlineCommentInputView(
                text: $review,
                placeholder: "添加你的点评...",
                onEditingChanged: { isEditing in
                    isCommentEditing = isEditing
                }
            )
            .glassmorphism(tint: .white)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppTheme.Colors.glassBorder, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Tags Section（详情页同款）
    // MARK: - Tags Section（Premium Soft UI）
    private func tagSticker(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(addPrimaryText)
            
            if isEditingTags {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        selectedTags.removeAll { $0 == tag }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(addHintText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(addPanelBackground)
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
                )
        )
    }
    
    private func presetTagButton(_ tag: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                selectedTags.append(tag)
            }
        } label: {
            Text(tag)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.moodTerrible)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(addPanelBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Colors.separatorGray, lineWidth: 0.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Save Button（超大胶囊按钮+红色弥散阴影）
    // MARK: - Save Button（与 CheckInView 同款：黑色背景红色打钩）
    private var saveButton: some View {
        Button {
            // 触发 Confetti 动效
            withAnimation(.spring(response: 0.3)) {
                showConfetti = true
            }
            // 延迟保存，让动效先展示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                saveRestaurant()
            }
            // 1.5秒后关闭 Confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showConfetti = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.accent) // 小红书红

                Text("保存餐厅")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primaryButtonText)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.primaryButtonBackground)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(name.isEmpty)
        .opacity(name.isEmpty ? 0.4 : 1.0)
    }
    
    // MARK: - Helper Methods
    private func addNewTag() {
        let trimmed = newTagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty && !selectedTags.contains(trimmed) else { return }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
            selectedTags.append(trimmed)
            newTagInput = ""
        }
    }
    
    private func handleLocationSelect(_ item: MKMapItem) {
        let coordinate = item.compatibleCoordinate
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        address = item.compatibleAddress.isEmpty ? (item.name ?? "") : item.compatibleAddress
    }
    
    private func handlePhotoPickerChange(_ newValue: PhotosPickerItem?) {
        guard let item = newValue else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    imageOpacity = 0.0  // 重置透明度，准备淡入动画
                    coverImages = [image]
                    // 触发淡入动画
                    withAnimation(.easeIn(duration: 0.4)) {
                        imageOpacity = 1.0
                    }
                }
            }
        }
    }
    
    private func handleViewAppear() {
        if let firstRestaurant = allRestaurants.first {
            city = firstRestaurant.city
        }
    }
    
    // MARK: - Auto Fill Handler（呼吸灯高亮效果）
    private func handleAutoFill() {
        // 先停止之前的呼吸动画（如果正在运行）
        stopCategoryBreathingAnimation()
        
        // 重置动画状态
        nameFieldOffset = 20
        districtFieldOffset = 20
        nameFieldOpacity = 0
        districtFieldOpacity = 0
        
        // 级联进入动画：名称字段先跳入
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            nameFieldOffset = 0
            nameFieldOpacity = 1
            highlightName = true
        }
        
        // 区域字段第二个跳入（延迟 0.15s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                districtFieldOffset = 0
                districtFieldOpacity = 1
                highlightName = false
                highlightDistrict = true
            }
        }
        
        // 品类字段第三个跳入（延迟 0.3s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                highlightDistrict = false
                highlightCategory = true
                
                // 设置品类匹配状态
                if category == "其他" {
                    categoryMatchStatus = .manuallyRequired
                    // 启动品类文本呼吸动画 - 仅在未能识别时触发
                    startCategoryTextPulseAnimation()
                } else {
                    categoryMatchStatus = .autoMatched(matchedCategory: category)
                    // 成功识别时，不触发呼吸动画，不放大加粗，保持与地区文本一致
                    isCategoryHighlighted = false
                    categoryTextPulse = 1.0
                }
            }
        }
        
        // 地址高亮（延迟 0.45s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeInOut(duration: 0.3)) {
                highlightCategory = false
                highlightAddress = true
            }
        }
        
        // 完成动画（延迟 0.75s）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeInOut(duration: 0.3)) {
                highlightAddress = false
            }
            
            // 触感反馈：告知用户自动填充已完成
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
    
    // MARK: - 品类文本呼吸动画（识别成功时使用）
    private func startCategoryTextPulseAnimation() {
        // 1. 形态切换：先显示普通状态
        isCategoryHighlighted = false
        categoryTextPulse = 1.0
        isCategoryBreathing = true
        
        // 2. 延迟一帧后启动动画（确保视图已出现）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // 先变为高亮状态（变大加粗）
            withAnimation(.easeOut(duration: 0.3)) {
                self.isCategoryHighlighted = true
            }
            
            // 3. 启动持续呼吸动画
            self.performContinuousBreathing()
        }
    }
    
    // MARK: - 停止品类呼吸动画
    private func stopCategoryBreathingAnimation() {
        isCategoryBreathing = false
        withAnimation(.easeOut(duration: 0.3)) {
            categoryTextPulse = 1.0
            isCategoryHighlighted = false
        }
    }
    
    private func performContinuousBreathing() {
        // 检查是否应该停止
        guard isCategoryBreathing else {
            withAnimation(.easeOut(duration: 0.3)) {
                categoryTextPulse = 1.0
            }
            return
        }
        
        // 吸气：放大到 1.08
        withAnimation(.easeInOut(duration: 0.4)) {
            categoryTextPulse = 1.08
        }
        
        // 波峰触感
        let hapticGenerator = UIImpactFeedbackGenerator(style: .soft)
        hapticGenerator.prepare()
        hapticGenerator.impactOccurred()
        
        // 呼气：回到 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard self.isCategoryBreathing else {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.categoryTextPulse = 1.0
                }
                return
            }
            
            withAnimation(.easeInOut(duration: 0.4)) {
                self.categoryTextPulse = 1.0
            }
            
            // 继续下一个呼吸周期
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.performContinuousBreathing()
            }
        }
    }
    
    private func saveRestaurant() {
        // 触发 Confetti 特效
        withAnimation {
            showConfetti = true
        }

        // Oreo: 显示成功仪式弹窗
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSuccessToast = true
        }

        // 保存封面图片（如果有）
        var coverFilename: String? = nil
        if let coverImage = coverImages.first {
            coverFilename = ImageManager.shared.saveImage(coverImage)
        }

        // 统一使用 LibraryView 中选择的城市（不再使用智能搜索返回的城市）
        let savedCity = UserDefaults.standard.string(forKey: "UserSelectedCity") ?? "重庆"

        // 保存数据
        let newRestaurant = Restaurant(
            name: name,
            type: category,
            district: district,
            city: savedCity,
            rating: rating,
            address: address,
            latitude: latitude,
            longitude: longitude,
            coverPhotoFilename: coverFilename,
            review: review,
            tags: selectedTags,
            averagePrice: 0
        )

        modelContext.insert(newRestaurant)
        do {
            try modelContext.save()
        } catch {
            AppLogger.error("保存餐厅失败: \(error.localizedDescription)", category: .storage)
        }

        // Oreo: 1.2s 后关闭弹窗并退出
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSuccessToast = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            closeAction()
        }
    }
}

// MARK: - Dock 栏评分系统（macOS Dock 风格）
struct DockRatingView: View {
    @Binding var rating: Double
    
    // 评价映射体系
    private let ratingItems: [RatingItem] = [
        RatingItem(score: 1.0, emoji: "🤮", slang: "拉完了"),
        RatingItem(score: 2.0, emoji: "🤔", slang: "NPC"),
        RatingItem(score: 3.0, emoji: "😋", slang: "人上人"),
        RatingItem(score: 4.0, emoji: "😍", slang: "顶级"),
        RatingItem(score: 5.0, emoji: "🤩", slang: "夯！")
    ]
    
    var body: some View {
        // 评分项横向排列（无容器背景，直接显示在 Bento Card 中）
        HStack(spacing: 0) {
            ForEach(ratingItems, id: \.score) { item in
                DockItemView(
                    item: item,
                    isSelected: rating == item.score,
                    onTap: { selectRating(item.score) }
                )
            }
        }
    }
    
    // 选择评分
    private func selectRating(_ score: Double) {
        rating = score
        triggerHaptic(for: score)
    }
    
    // 触感反馈
    private func triggerHaptic(for score: Double) {
        let generator = UIImpactFeedbackGenerator(style: score >= 3 ? .medium : .light)
        
        switch score {
        case 1...2:
            generator.impactOccurred()
        case 3...4:
            generator.impactOccurred()
        case 5:
            // 5分：连续两次震动
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generator.impactOccurred()
            }
        default:
            break
        }
    }
}

// MARK: - 评分项数据
struct RatingItem {
    let score: Double
    let emoji: String
    let slang: String
}

// MARK: - 按压事件修饰符
struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Dock 单项视图（参考 CheckInView moodButton 动效）
struct DockItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: RatingItem
    let isSelected: Bool
    let onTap: () -> Void
    
    // 动画状态
    @State private var isPressed = false

    private var primaryText: Color {
        colorScheme == .dark ? Color.fixedHex("#DCE6F6") : AppTheme.Colors.darkText
    }

    private var hintText: Color {
        colorScheme == .dark ? Color.fixedHex("#8393AC") : AppTheme.Colors.lightText
    }
    
    var body: some View {
        Button {
            triggerHaptic()
            withAnimation(AppTheme.Animations.standardSpring) {
                onTap()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // 选中态光晕效果 - 参照 CheckInView moodButton 实现
                    if isSelected {
                        // 外层光晕 - 大范围柔和发光
                        Circle()
                            .fill(glowColor.opacity(0.25))
                            .blur(radius: 20)
                            .frame(width: 70, height: 70)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .animation(AppTheme.Animations.standardSpring, value: isSelected)
                        
                        // 中层光晕
                        Circle()
                            .fill(glowColor.opacity(0.4))
                            .blur(radius: 12)
                            .frame(width: 55, height: 55)
                            .scaleEffect(isSelected ? 1.0 : 0.85)
                            .animation(AppTheme.Animations.standardSpring, value: isSelected)
                        
                        // 内层高光 - 核心发光区
                        Circle()
                            .fill(glowColor.opacity(0.6))
                            .blur(radius: 6)
                            .frame(width: 45, height: 45)
                    }
                    
                    // Emoji
                    Text(item.emoji)
                        .font(.system(size: 32))
                        .scaleEffect(isSelected ? 1.25 : 0.9)
                        .opacity(isSelected ? 1.0 : 0.5)
                        .grayscale(isSelected ? 0.0 : 0.5)
                        .offset(y: isSelected ? -8 : 0)
                        .rotationEffect(.degrees(isSelected ? Double.random(in: -5...5) : 0))
                        .animation(AppTheme.Animations.standardSpring, value: isSelected)
                }
                .frame(height: 70)
                
                // 俚语文字
                Text(item.slang)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? primaryText : hintText)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(AppTheme.Animations.standardSpring, value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // 选中态光晕颜色：根据评分显示不同颜色
    // 1分-拉完了：深灰色，2分-NPC：灰色，3分-人上人：灰白色，4分-顶级：小红书红，5分-夯！：金色
    private var glowColor: Color {
        switch item.score {
        case 1.0:
            return Color(hex: "#4A4A4A") // 深灰色
        case 2.0:
            return Color.gray // 灰色
        case 3.0:
            return Color(hex: "#E8E8E8") // 灰白色
        case 4.0:
            return AppTheme.Colors.xhsRed // 小红书红
        case 5.0:
            return Color(hex: "#FFD700") // 金色
        default:
            return Color.gray
        }
    }
    
    // 触感反馈
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: item.score >= 3 ? .medium : .light)
        generator.impactOccurred()
    }
}

// MARK: - Oreo: 成功仪式弹窗
struct SuccessToastView: View {
    var body: some View {
        VStack(spacing: 12) {
            // 小红书红对勾
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.xhsRed)

            Text("已保存")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primaryButtonText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            // 哑光黑背景 1A1A1A
            Capsule()
                .fill(AppTheme.Colors.primaryButtonBackground)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}
