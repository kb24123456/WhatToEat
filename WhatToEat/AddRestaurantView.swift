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
    
    // MARK: - Focus States
    @FocusState private var reviewIsFocused: Bool
    @FocusState private var tagInputIsFocused: Bool
    
    // MARK: - Keyboard Performance Optimization
    @State private var anyFieldFocused = false  // 追踪是否有输入框聚焦
    
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
        // 监听焦点状态变化，优化背景渲染
        .onChange(of: reviewIsFocused) { _, newValue in
            anyFieldFocused = newValue || tagInputIsFocused
        }
        .onChange(of: tagInputIsFocused) { _, newValue in
            anyFieldFocused = newValue || reviewIsFocused
        }
    }
    
    // MARK: - Background（键盘开启时使用纯色优化性能）
    private var backgroundGradient: some View {
        AppTheme.Colors.milkWhite
            .ignoresSafeArea()
    }
    
    // MARK: - Scroll Content（无父容器，组件直接显示）
    private func scrollContent(geometry: GeometryProxy) -> some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: 20) {
                    Spacer().frame(height: 60)

                    // 基础信息（照片 + 名称/区域/品类）
                    HStack(spacing: 12) {
                        thumbnailImageView
                            .frame(width: 120, height: 120)

                        infoPodContainer
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, AppTheme.Layout.pagePadding)

                    // 智能搜索入口
                    smartSearchButton
                        .padding(.horizontal, AppTheme.Layout.pagePadding)

                    // 地址信息行
                    if !address.isEmpty {
                        addressSubline
                            .padding(.horizontal, AppTheme.Layout.pagePadding)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 评分
                    unifiedRatingRow
                        .padding(.horizontal, AppTheme.Layout.pagePadding)

                    // 评价
                    unifiedReviewRow
                        .padding(.horizontal, AppTheme.Layout.pagePadding)

                    // 标签
                    unifiedTagsRow
                        .id("TagModule")
                        .padding(.horizontal, AppTheme.Layout.pagePadding)
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
                        .padding(.horizontal, AppTheme.Layout.pagePadding)
                        .padding(.top, 16)
                        .padding(.bottom, 32)

                    Spacer().frame(height: 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .offset(y: isAppeared ? 0 : 50)
        .opacity(isAppeared ? 1 : 0)
    }

    // MARK: - 左侧缩略封面图（Premium Photo Picker）
    private var thumbnailImageView: some View {
        ZStack {
            // 温润凹槽背景：softBackground + 内阴影
            RoundedRectangle(cornerRadius: 24)
                .fill(AppTheme.Colors.softBackground)
                .overlay(
                    // 内阴影效果
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.black.opacity(0.03), lineWidth: 1)
                )
                .overlay(
                    // 顶部高光
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(1)
                )

            if let firstImage = coverImages.first {
                Image(uiImage: firstImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                        .foregroundColor(AppTheme.Colors.babyBlue) // Baby Blue 图标
                    Text("添加照片")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.mediumGray) // mediumGray 文字
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
                        .fill(Color.white.opacity(0.9))  // 纯色替代高斯模糊
                        .overlay(
                            Circle()
                                .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
    }
    
    // MARK: - Smart Search Button（高级化智能搜索入口）
    private var smartSearchButton: some View {
        Button {
            showSmartSearch = true
        } label: {
            HStack(spacing: 12) {
                // 语义化图标：红色点缀
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)

                // 渐变文字效果
                Text("智能搜索...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.lightText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(ScaleButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.Colors.babyBlue.opacity(0.3), lineWidth: 0.5)
                )
        )
        // 微弱发光效果
        .shadow(color: AppTheme.Colors.babyBlue.opacity(0.1), radius: 8, x: 0, y: 2)
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
                .foregroundColor(AppTheme.Colors.mediumGray)
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
                    .foregroundColor(AppTheme.Colors.mediumGray)
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
                    .foregroundColor(AppTheme.Colors.mediumGray)
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
    
    // MARK: - 新标签输入按钮（点击后进入编辑模式，不自动聚焦）
    private var newTagInputButton: some View {
        Button {
            withAnimation(AppTheme.Animations.editingSpring) {
                isEditingTags = true
                // 注意：不自动聚焦输入框，用户需手动点击输入
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
    // MARK: - Save Button（终点仪式感）
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
                Text("保存餐厅")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56) // 固定高度 56pt
        }
        .oreoClickEffect(style: .medium) // Oreo: 黑色按钮用 medium 震动
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black) // 纯黑色背景
        )
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
        // 奶脂 Dock 容器
        HStack(spacing: 0) {
            ForEach(ratingItems, id: \.score) { item in
                DockItemView(
                    item: item,
                    isSelected: rating == item.score,
                    onTap: { selectRating(item.score) }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.85))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
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

// MARK: - Dock 单项视图
struct DockItemView: View {
    let item: RatingItem
    let isSelected: Bool
    let onTap: () -> Void
    
    // 动画状态
    @State private var isPressed = false
    // 视图可见性状态
    @State private var isVisible = false
    
    // 计算最终缩放：选中态 1.2x，点按态 0.92x
    private var finalScale: CGFloat {
        let baseScale = isSelected ? 1.2 : 1.0
        let pressScale = isPressed ? 0.92 : 1.0
        let visibilityScale = isVisible ? 1.0 : 0.8
        return baseScale * pressScale * visibilityScale
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Emoji - 使用纯色背景替代模糊光晕
            ZStack {
                // 选中态背景圆（无模糊）
                if isSelected {
                    Circle()
                        .fill(glowColor)
                        .frame(width: 44, height: 44)
                }
                
                Text(item.emoji)
                    .font(.system(size: 26))
                    .grayscale(isSelected ? 0 : 0.2)
            }
            .scaleEffect(finalScale)
            .offset(y: isSelected && isVisible ? -3 : 0)
            
            // 俚语文字
            Text(item.slang)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 58, height: 60)
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) {
                onTap()
            }
        }
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.06)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.06)) {
                isPressed = false
            }
        }
    }
    
    // 选中态背景色：3-5分使用小红书红
    private var glowColor: Color {
        item.score <= 2 ? Color.gray.opacity(0.12) : AppTheme.Colors.xhsRed.opacity(0.15)
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
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            // 哑光黑背景 1A1A1A
            Capsule()
                .fill(Color(hex: "#1A1A1A"))
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}


