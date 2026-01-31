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
    
    // 自动填充级联动画状态
    @State private var nameFieldOffset: CGFloat = 20
    @State private var districtFieldOffset: CGFloat = 20
    @State private var categoryFieldOffset: CGFloat = 20
    @State private var nameFieldOpacity: Double = 0
    @State private var districtFieldOpacity: Double = 0
    @State private var categoryFieldOpacity: Double = 0
    
    // MARK: - Focus States
    @FocusState private var reviewIsFocused: Bool
    @FocusState private var tagInputIsFocused: Bool
    
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
                    .safeAreaInset(edge: .bottom) {
                        // 保存按钮放入 safeAreaInset，ScrollView 会自动避开
                        saveButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                            .padding(.top, 10)
                    }
                
                // Confetti 特效
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
                
                // 关闭按钮（放在最上层确保可点击）
                closeButton
                    .padding(.top, 20)
                    .padding(.leading, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem)
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
            .presentationDetents([.fraction(0.66), .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            handleViewAppear()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAppeared = true
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        MilkyDiffuseBackground()
    }
    
    // MARK: - Close Button
    private var closeButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                closeAction()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .foregroundStyle(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
        }
    }
    
    // MARK: - Scroll Content
    private func scrollContent(geometry: GeometryProxy) -> some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: 24) {
                    Spacer().frame(height: 70)
                    
                    // 餐厅名片模块（封面图+基础信息并排）
                    restaurantCardSection
                    
                    // 地址信息行（一行式展示，未填时隐藏）
                    if !address.isEmpty {
                        addressSubline
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // 智能搜索入口（移动到评分组件上方）
                    smartSearchButton
                    
                    // 评分、评价、标签一体化容器
                    unifiedInputSection
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
                    
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .offset(y: isAppeared ? 0 : 50)
        .opacity(isAppeared ? 1 : 0)
    }
    
    // MARK: - 餐厅名片模块（Premium Soft UI）
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
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.Colors.lightGray)
            
            Group {
                if let firstImage = coverImages.first {
                    Image(uiImage: firstImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.lighterGray)
                        Text("添加照片")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.lightText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // 微弱边框
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
        }
        .onTapGesture {
            showActionSheet = true
        }
    }
    
    // MARK: - 右侧基础信息容器（重新设计排版）
    private var infoPodContainer: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 餐厅名称（大标题，无背景，允许换行显示完全）
            TextField("餐厅名称", text: $name)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
                .fixedSize(horizontal: false, vertical: true)
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
                
                // 品类
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
                            .font(.system(size: 12))
                        Text(category.isEmpty ? "选择品类" : category)
                            .font(.system(size: 14))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(category.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.mediumGray)
                }
                .offset(x: categoryFieldOffset)
                .opacity(categoryFieldOpacity)
                
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
                    .fill(AppTheme.Colors.cardBackground)
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
    
    // MARK: - 地址信息行（一行式展示）
    private var addressSubline: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#999999"))
            
            Text(address)
                .font(.caption)
                .foregroundColor(Color.secondary)
                .lineLimit(1)
            
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
                                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
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
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                    .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), Color.white.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 评分行（带立体质感星星）
    private var unifiedRatingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("评分")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.darkText)
            
            // 星星（带立体质感）
            HStack(spacing: 12) {
                ForEach(0..<5) { index in
                    Button {
                        withAnimation(AppTheme.Animations.quickSpring) {
                            rating = Double(index + 1)
                        }
                    } label: {
                        ZStack {
                            // 底层阴影（立体感）
                            if index < Int(rating) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(Color(hex: "#CC8A00"))
                                    .offset(x: 0, y: 2)
                                    .blur(radius: 1)
                            }
                            
                            // 主星星
                            Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(Color(hex: index < Int(rating) ? "#FFB800" : "#BDBDBD"))
                            
                            // 高光层（立体感）
                            if index < Int(rating) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .offset(x: 0, y: -1)
                                    .mask(
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 32, weight: .medium))
                                    )
                            }
                        }
                        .scaleEffect(index < Int(rating) ? 1.0 : 0.9)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - 评价行（保留编辑动效）
    private var unifiedReviewRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("评价")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.darkText)
            
            // 评价内容（可点击编辑）
            ZStack(alignment: .bottomTrailing) {
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
                                .onAppear {
                                    reviewIsFocused = true
                                }
                                .onDisappear {
                                    reviewIsFocused = false
                                }
                        }
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                    } else {
                        Text(review.isEmpty ? "点击添加点评..." : review)
                            .font(.body)
                            .foregroundColor(review.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.mediumGray)
                            .lineSpacing(4)
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .frame(minHeight: isEditingReview ? 150 : 60)
                .id(isEditingReview)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.Colors.softBackground.opacity(isEditingReview ? 0.5 : 0.3))
                )
                
                // 勾叉按钮（压在容器下边缘，一半在内一半在外）
                if isEditingReview {
                    HStack(spacing: 12) {
                        cancelBubble {
                            withAnimation(AppTheme.Animations.editingSpring) {
                                isEditingReview = false
                                editedReview = review
                            }
                        }
                        
                        saveBubble {
                            withAnimation(AppTheme.Animations.editingSpring) {
                                review = editedReview
                                isEditingReview = false
                            }
                        }
                    }
                    .padding(.trailing, 12)
                    .offset(y: 24)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(AppTheme.Animations.standardSpring, value: isEditingReview)
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
    
    // MARK: - 标签行（保留编辑动效）
    private var unifiedTagsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("标签")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.darkText)
            
            // 标签内容（可点击编辑）
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
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
                                        .fill(Color.white.opacity(0.35))
                                )
                                .focused($tagInputIsFocused)
                                .frame(minWidth: 80)
                                .onSubmit {
                                    addNewTag()
                                }
                                .onAppear {
                                    tagInputIsFocused = true
                                }
                        } else if selectedTags.isEmpty {
                            Text("点击添加标签...")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#BBBBBB"))
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Colors.softBackground.opacity(isEditingTags ? 0.5 : 0.3))
                    )
                    
                    // 编辑状态下的推荐标签
                    if isEditingTags {
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
                        .padding(20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(AppTheme.Animations.standardSpring, value: isEditingTags)
                
                // 勾叉按钮（压在容器下边缘，一半在内一半在外）
                if isEditingTags {
                    HStack(spacing: 12) {
                        cancelBubble {
                            withAnimation(AppTheme.Animations.editingSpring) {
                                isEditingTags = false
                                newTagInput = ""
                            }
                        }
                        
                        saveBubble {
                            withAnimation(AppTheme.Animations.editingSpring) {
                                isEditingTags = false
                                newTagInput = ""
                            }
                        }
                    }
                    .padding(.trailing, 12)
                    .offset(y: 24)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onTapGesture {
                if !isEditingTags {
                    withAnimation(AppTheme.Animations.editingSpring) {
                        isEditingTags = true
                    }
                }
            }
        }
        .animation(AppTheme.Animations.standardSpring, value: isEditingTags)
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
        HStack(spacing: 12) {
            cancelBubble {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingReview = false
                    editedReview = review
                }
            }

            saveBubble {
                withAnimation(AppTheme.Animations.editingSpring) {
                    review = editedReview
                    isEditingReview = false
                }
            }
        }
        .padding(.trailing, 16)
        .offset(y: 18)
        .transition(.scale.combined(with: .opacity))
        .animation(AppTheme.Animations.standardSpring, value: isEditingReview)
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
                    .onAppear {
                        reviewIsFocused = true
                    }
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
        HStack(spacing: 12) {
            cancelBubble {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingTags = false
                    newTagInput = ""
                }
            }

            saveBubble {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingTags = false
                    newTagInput = ""
                }
            }
        }
        .padding(.trailing, 16)
        .offset(y: 18)
        .transition(.scale.combined(with: .opacity))
        .animation(AppTheme.Animations.standardSpring, value: isEditingTags)
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
                            .fill(Color.white.opacity(0.35))
                    )
                    .focused($tagInputIsFocused)
                    .frame(minWidth: 80)
                    .onSubmit {
                        addNewTag()
                    }
                    .onAppear {
                        tagInputIsFocused = true
                    }
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
                .fill(AppTheme.Colors.warmGray)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
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
                        .fill(Color.white.opacity(0.35))
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
    
    // MARK: - Bubble Buttons
    private func cancelBubble(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(AppTheme.Colors.darkBackground)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
        }
    }
    
    private func saveBubble(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(AppTheme.Colors.accent)
                        .shadow(color: AppTheme.Shadows.elevated.color, radius: 8, x: 0, y: 4)
                )
        }
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
                    coverImages = [image]
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
        // 重置动画状态
        nameFieldOffset = 20
        districtFieldOffset = 20
        categoryFieldOffset = 20
        nameFieldOpacity = 0
        districtFieldOpacity = 0
        categoryFieldOpacity = 0
        
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
                categoryFieldOffset = 0
                categoryFieldOpacity = 1
                highlightDistrict = false
                highlightCategory = true
                
                // 设置品类匹配状态
                if category == "其他" {
                    categoryMatchStatus = .manuallyRequired
                } else {
                    categoryMatchStatus = .autoMatched(matchedCategory: category)
                    
                    // 2秒后自动消失
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            categoryMatchStatus = .none
                        }
                    }
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


