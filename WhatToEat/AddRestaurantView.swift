import SwiftUI
import SwiftData
import MapKit
import PhotosUI

// MARK: - 添加餐厅页面（全新重构版）
struct AddRestaurantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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
    
    // MARK: - Editing States
    @State private var isEditingReview = false
    @State private var editedReview = ""
    @State private var isEditingTags = false
    @State private var newTagInput = ""
    
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
    
    // MARK: - Focus States
    @FocusState private var reviewIsFocused: Bool
    @FocusState private var tagInputIsFocused: Bool
    
    // MARK: - Keyboard Animation Delay
    private let keyboardAnimationDelay: TimeInterval = 0.25  // 展开动画完成后再弹出键盘
    
    // MARK: - Category Match Status
    enum MatchStatus: Equatable {
        case none
        case autoMatched(matchedCategory: String)
        case manuallyRequired
    }
    
    @State private var categoryMatchStatus: MatchStatus = .none
    @State private var categoryMatchMessage: String = ""
    
    let presetTags = ["氛围感", "老字号", "二刷", "排队王", "性价比"]
    
    var categoryOptions: [String] {
        CategoryManager.shared.getPresetCategories()
    }
    
    var districtOptions: [String] {
        RegionManager.shared.getDistricts(for: city)
    }
    
    private var closeAction: () -> Void {
        return onClose ?? { dismiss() }
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
    
    // MARK: - Background
    private var backgroundGradient: some View {
        MilkyDiffuseBackground()
    }
    
    // MARK: - Scroll Content
    private func scrollContent(geometry: GeometryProxy) -> some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: 24) {
                    Spacer().frame(height: 70)
                    
                    // 完整餐厅卡片（包含所有信息）
                    completeRestaurantCard
                        .id("TagModule")
                        .onChange(of: isEditingTags) { _, newValue in
                            if newValue {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        proxy.scrollTo("TagModule", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    
                    // 保存按钮放在标签栏下方
                    saveButton
                        .padding(.top, 20)
                        .padding(.bottom, 40)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .offset(y: isAppeared ? 0 : 50)
        .opacity(isAppeared ? 1 : 0)
    }

    // MARK: - 完整餐厅卡片（包含所有信息）
    private var completeRestaurantCard: some View {
        VStack(spacing: 0) {
            // 第一部分：基础信息（照片 + 名称/区域/品类）
            HStack(spacing: 12) {
                // 左侧：缩略封面图
                thumbnailImageView
                    .frame(width: 120, height: 120)
                
                // 右侧：基础信息
                infoPodContainer
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // 智能搜索入口
            smartSearchButton
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            
            // 地址信息行（放在智能搜索之下）
            if !address.isEmpty {
                addressSubline
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // 第二部分：评分
            unifiedRatingRow
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            
            // 第三部分：评价
            unifiedReviewRow
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            
            // 第四部分：标签
            unifiedTagsRow
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                .stroke(highlightName ? AppTheme.Colors.success.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .animation(AppTheme.Animations.quickSpring, value: highlightName)
    }
    
    // MARK: - 餐厅名片模块（Premium Soft UI）- 已合并到 completeRestaurantCard
    private var restaurantCardSection: some View {
        HStack(spacing: 12) {
            // 左侧：缩略封面图（1:1正方形）
            thumbnailImageView
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            
            // 右侧：基础信息容器
            infoPodContainer
                .frame(maxWidth: .infinity)
        }
        .frame(height: 160)
        .padding(16)
        .premiumCard()
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(highlightName ? AppTheme.Colors.success.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .animation(AppTheme.Animations.quickSpring, value: highlightName)
    }
    
    // MARK: - 左侧缩略封面图
    private var thumbnailImageView: some View {
        ZStack {
            // 虚线边框背景
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            style: StrokeStyle(
                                lineWidth: 1.5,
                                dash: [6, 4]
                            )
                        )
                        .foregroundColor(AppTheme.Colors.lighterGray)
                )
            
            if let firstImage = coverImages.first {
                Image(uiImage: firstImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .opacity(imageOpacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.4)) {
                            imageOpacity = 1.0
                        }
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Colors.lighterGray)
                    Text("添加照片")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.lightText)
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 120, height: 120)
        .onTapGesture {
            showActionSheet = true
        }
    }
    
    // MARK: - 右侧基础信息容器（重新设计排版）
    private var infoPodContainer: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 餐厅名称（大标题，无背景，允许换行显示完全，最多2行）
            TextField("餐厅名称", text: $name, axis: .vertical)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
                .lineLimit(2)
                .offset(x: nameFieldOffset)
                .opacity(nameFieldOpacity)
            
            // 区域和品类放在同一行，禁止换行
            HStack(spacing: 12) {
                // 区域
                Menu {
                    ForEach(districtOptions, id: \.self) { option in
                        Button(option) { district = option }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                        Text(district.isEmpty ? "选择区域" : district)
                            .font(.system(size: 14))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(district.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.mediumGray)
                }
                .offset(x: districtFieldOffset)
                .opacity(districtFieldOpacity)
                
                // 分隔点
                if !district.isEmpty && !category.isEmpty {
                    Text("·")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.lightText)
                }
                
                // 品类（仅在识别后显示）
                if !category.isEmpty {
                    Menu {
                        ForEach(categoryOptions, id: \.self) { option in
                            Button(option) {
                                category = option
                                categoryMatchStatus = .none
                                // 用户点击后停止呼吸动画
                                stopCategoryBreathingAnimation()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                            // Typographic Motion：纯文字动效
                            Text(category)
                                .font(.system(size: isCategoryHighlighted ? 16 : 14))
                                .fontWeight(isCategoryHighlighted ? .bold : .medium)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(AppTheme.Colors.mediumGray)
                                .scaleEffect(categoryTextPulse)
                        }
                    }
                }
                
                Spacer()
            }
            
            // 品类匹配提示
            if categoryMatchStatus == .manuallyRequired {
                Text("💡 未能识别，请手动选择")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.iconAmber)
                    .transition(.opacity)
            }
        }
    }
    
    // 保留旧实现供参考（已合并到infoPodContainer中）
    private var nameTextField: some View {
        TextField("餐厅名称", text: $name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(AppTheme.Colors.darkText)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.softBackground)
            )
    }
    
    private var districtCapsule: some View {
        Menu {
            ForEach(districtOptions, id: \.self) { option in
                Button(option) { district = option }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.system(size: 10))
                    .foregroundColor(district.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.darkText)
                Text(district.isEmpty ? "选择区域" : district)
                    .font(.system(size: 13))
                    .foregroundColor(district.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.darkText)
            }
        }
    }
    
    private var categoryCapsule: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                ForEach(categoryOptions, id: \.self) { option in
                    Button(option) {
                        category = option
                        categoryMatchStatus = .none
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 10))
                        .foregroundColor(category.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.darkText)
                    Text(category.isEmpty ? "选择品类" : category)
                        .font(.system(size: 13))
                        .foregroundColor(category.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.darkText)
                }
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
    }
    
    // MARK: - 地址信息行（最多2行显示）
    private var addressSubline: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#999999"))
                .padding(.top, 2)
            
            Text(address)
                .font(.caption)
                .foregroundColor(Color.secondary)
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
                .foregroundColor(Color(hex: "#1A1A1A"))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
    }
    
    // MARK: - Smart Search Button（智能搜索入口）
    private var smartSearchButton: some View {
        Button {
            showSmartSearch = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)

                Text("智能搜索：输入店名，一键填充所有信息")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.moodTerrible)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.ultraLightGray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(ScaleButtonStyle())
        .cardStyle()
        // 呼吸感高亮指示 - 引导用户输入
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                .stroke(
                    AppTheme.Colors.accent.opacity(breathingOpacity),
                    lineWidth: 2
                )
        )
        .onAppear {
            // 启动呼吸动画
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathingOpacity = 0.3
            }
        }
    }

    // 呼吸动画状态
    @State private var breathingOpacity: Double = 0.1
    
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
        VStack(alignment: .leading, spacing: 0) {
            Text("评分")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.horizontal, 20)
            
            // 奶脂风格评分条
            MilkyRatingView(rating: $rating)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
        }
    }
    
    // MARK: - 评价行（与 RestaurantDetailView 保持一致）
    private var unifiedReviewRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏：包含标题和取消/完成按钮
            HStack(alignment: .center, spacing: 0) {
                Text("一句话点评")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isEditingReview ? AppTheme.Colors.textSecondary : AppTheme.Colors.darkText)
                
                Spacer()
                
                // 编辑状态下的取消/完成按钮
                if isEditingReview {
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(AppTheme.Animations.editingSpring) {
                                isEditingReview = false
                                editedReview = review
                            }
                        } label: {
                            Text("取消")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                        }
                        
                        Button {
                            withAnimation(AppTheme.Animations.editingSpring) {
                                review = editedReview
                                isEditingReview = false
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
            .padding(.horizontal, 20)
            
            // 评价内容（可点击编辑）- 使用纯色圆角背景，无阴影
            VStack(spacing: 0) {
                if isEditingReview {
                    ZStack(alignment: .center) {
                        TextField(review.isEmpty ? "添加你的点评..." : review, text: $editedReview, axis: .vertical)
                            .font(.body)
                            .foregroundColor(AppTheme.Colors.brownText)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                            .focused($reviewIsFocused)
                            .scrollContentBackground(.hidden)
                            .padding(20)
                            .padding(.bottom, 10)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            // 移除自动聚焦，避免键盘自动弹出
                            .onDisappear {
                                reviewIsFocused = false
                            }
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                } else {
                    Text(review.isEmpty ? "添加你的点评..." : review)
                        .font(.body)
                        .foregroundColor(review.isEmpty ? AppTheme.Colors.lighterGray : AppTheme.Colors.mediumGray)
                        .lineSpacing(4)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .frame(minHeight: isEditingReview ? 150 : 60)
            .id(isEditingReview)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.card)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, 20)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isEditingReview)
            .onTapGesture {
                if !isEditingReview {
                    withAnimation(AppTheme.Animations.editingSpring) {
                        isEditingReview = true
                        editedReview = review
                    }
                }
            }
        }
    }
    
    // MARK: - 标签行（与 RestaurantDetailView 保持一致）
    private var unifiedTagsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏：包含标题和取消/完成按钮
            HStack(alignment: .center, spacing: 0) {
                Text("标签")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isEditingTags ? AppTheme.Colors.textSecondary : AppTheme.Colors.darkText)
                
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
                                .foregroundColor(AppTheme.Colors.mediumGray)
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
            .padding(.horizontal, 20)
            
            // 标签内容（可点击编辑）- 无卡片背景，与 RestaurantDetailView 一致
            VStack(spacing: 0) {
                tagsLayoutContainer
                
                // 编辑状态下的推荐标签
                if isEditingTags {
                    presetTagsSection
                        .padding(.top, 16)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
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
    
    // MARK: - 新标签输入按钮（点击后进入编辑模式）
    private var newTagInputButton: some View {
        Button {
            withAnimation(AppTheme.Animations.editingSpring) {
                isEditingTags = true
                // 延迟聚焦，等待布局完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    tagInputIsFocused = true
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text("新标签")
                    .font(.system(size: 14, design: .rounded))
            }
            .foregroundColor(AppTheme.Colors.lightText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.softBackground)
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.separatorGray.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 新标签输入框
    private var newTagInputField: some View {
        TextField("新标签...", text: $newTagInput)
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(AppTheme.Colors.darkText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.softBackground)
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.babyBlue.opacity(0.3), lineWidth: 1)
            )
            .focused($tagInputIsFocused)
            .frame(minWidth: 80)
            .submitLabel(.done)  // 键盘显示"完成"按钮
            .onSubmit {
                addNewTag()
            }
            // 移除自动聚焦，避免键盘自动弹出
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
    
    // MARK: - Review Section（Premium Soft UI）
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("评价")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            
            reviewCardContent
                .overlay(alignment: .bottomTrailing) {
                    if isEditingReview {
                        reviewBubbleButtons
                    }
                }
        }
        .onTapGesture {
            if !isEditingReview {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingReview = true
                    editedReview = review
                }
            }
        }
        .animation(AppTheme.Animations.standardSpring, value: isEditingReview)
    }

    private var reviewCardContent: some View {
        VStack(spacing: 0) {
            reviewContent
                .frame(minHeight: isEditingReview ? 150 : 80)
                .id(isEditingReview)
        }
        .glassmorphism(tint: .white)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppTheme.Colors.glassBorder, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .animation(AppTheme.Animations.standardSpring, value: isEditingReview)
    }

    private var reviewBubbleButtons: some View {
        EditActionButtons(
            onCancel: {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingReview = false
                    editedReview = review
                }
            },
            onConfirm: {
                withAnimation(AppTheme.Animations.editingSpring) {
                    review = editedReview
                    isEditingReview = false
                }
            }
        )
        .padding(.trailing, 12)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var reviewContent: some View {
        if isEditingReview {
            ZStack(alignment: .center) {
                TextField(review.isEmpty ? "添加你的点评..." : review, text: $editedReview, axis: .vertical)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.brownText)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .focused($reviewIsFocused)
                    .scrollContentBackground(.hidden)
                    .padding(20)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    // 移除自动聚焦，避免键盘自动弹出
                    .onDisappear {
                        reviewIsFocused = false
                    }
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
        } else {
            Text(review.isEmpty ? "添加你的点评..." : review)
                .font(.body)
                .foregroundColor(review.isEmpty ? AppTheme.Colors.lighterGray : AppTheme.Colors.mediumGray)
                .lineSpacing(4)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }
    
    // MARK: - Tags Section（详情页同款）
    // MARK: - Tags Section（Premium Soft UI）
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("标签")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            tagsCardContent
                .overlay(alignment: .bottomTrailing) {
                    if isEditingTags {
                        tagsBubbleButtons
                    }
                }
        }
        .onTapGesture {
            if !isEditingTags {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingTags = true
                }
            }
        }
        .animation(AppTheme.Animations.standardSpring, value: isEditingTags)
    }

    private var tagsBubbleButtons: some View {
        EditActionButtons(
            onCancel: {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingTags = false
                    newTagInput = ""
                }
            },
            onConfirm: {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingTags = false
                    newTagInput = ""
                }
            }
        )
        .padding(.trailing, 12)
        .padding(.bottom, 12)
    }

    private var tagsCardContent: some View {
        VStack(spacing: 0) {
            tagsFlowContent
                .padding(20)

            if isEditingTags {
                presetTagsSection
                    .padding(20)
            }
        }
        .glassmorphism(tint: .white)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppTheme.Colors.glassBorder, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    private var tagsFlowContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(selectedTags, id: \.self) { tag in
                tagSticker(tag)
            }
            
            if isEditingTags {
                TextField("新标签...", text: $newTagInput)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.softBackground)
                    )
                    .focused($tagInputIsFocused)
                    .frame(minWidth: 80)
                    .submitLabel(.done)  // 键盘显示"完成"按钮
                    .onSubmit {
                        addNewTag()
                    }
                    // 移除自动聚焦，避免键盘自动弹出
            } else if selectedTags.isEmpty {
                Text("点击添加标签...")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#BBBBBB"))
                    .padding(.vertical, 8)
            }
        }
    }

    private var presetTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐标签")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.lightText)
            
            FlowLayout(spacing: 8) {
                ForEach(presetTags.filter { !selectedTags.contains($0) }, id: \.self) { tag in
                    presetTagButton(tag)
                }
            }
        }
    }
    
    private func tagSticker(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#1A1A1A"))
            
            if isEditingTags {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        selectedTags.removeAll { $0 == tag }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Colors.lightText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.Colors.softBackground)
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
                        .fill(AppTheme.Colors.softBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Colors.separatorGray, lineWidth: 0.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Save Button（超大胶囊按钮+红色弥散阴影）
    // MARK: - Save Button（Premium Floating Action）
    private var saveButton: some View {
        Button {
            saveRestaurant()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.accent)
                Text("保存餐厅")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(Color.black)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(name.isEmpty)
        .opacity(name.isEmpty ? 0.6 : 1.0)
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
        address = "\(item.placemark.subLocality ?? "")\(item.placemark.thoroughfare ?? "")\(item.placemark.subThoroughfare ?? "")"
        latitude = item.placemark.coordinate.latitude
        longitude = item.placemark.coordinate.longitude
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
        
        // 延迟关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            closeAction()
        }
    }
}


