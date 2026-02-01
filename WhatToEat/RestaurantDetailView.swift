import SwiftUI
import MapKit
import SwiftData
import UIKit
import PhotosUI

// MARK: - 中文日期格式化扩展
extension Date {
    var chineseFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: self)
    }
    
    var chineseShortTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    
    var chineseDateOnly: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: self)
    }
    
    var chineseDateTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: self)
    }
}

// MARK: - 辅助结构体和扩展 (文件作用域)

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Pressable Button Modifier (Micro-interaction)
struct PressableButtonModifier: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func pressableButton(scale: CGFloat = 0.96) -> some View {
        modifier(PressableButtonModifier(scale: scale))
    }
}

// MARK: - 自定义按钮样式
// MARK: - 主视图
struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Environment(\.modelContext) private var modelContext
    let locationManager: LocationManager
    @Binding var isPresented: Bool
    
    @State private var showSheet = false
    @State private var logToEdit: VisitLog? = nil
    
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var newCoverImages: [UIImage] = []
    
    @State private var isEditingReview = false
    @State private var editedReview = ""
    @FocusState private var reviewIsFocused: Bool
    
    @State private var isEditingTags = false
    @State private var newTagInput = ""
    @FocusState private var tagInputIsFocused: Bool
    
    // MARK: - Keyboard Animation Delay
    private let keyboardAnimationDelay: TimeInterval = 0.25  // 展开动画完成后再弹出键盘
    
    @State private var animateOffset: CGFloat = 500
    
    // MARK: - Animation States
    @State private var isAnimated = false
    @State private var cardScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                backgroundGradient
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            heroSection
                                .padding(.horizontal, 20)
                                .padding(.top, 20 + geometry.safeAreaInsets.top)
                                .padding(.bottom, 16)

                            // Bottom Lists with staggered slide-up animation
                            bottomContentSection
                                .padding(.horizontal, 20)
                                .padding(.bottom, isEditingTags ? 400 : 100)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    // 标签编辑时自动滚动到标签区域
                    .onChange(of: isEditingTags) { _, isEditing in
                        if isEditing {
                            // 延迟等待布局完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    proxy.scrollTo("tagsSection", anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            .offset(y: animateOffset)
            .animation(
                .interpolatingSpring(stiffness: 120, damping: 15)
                    .speed(1.2)
                    .delay(0.1),
                value: animateOffset
            )
        }
    }
    
    // MARK: - Bottom Content Section (Premium Staggered Animation)
    private var bottomContentSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            unifiedInfoSection
                .offset(y: animateOffset == 0 ? 0 : 40)
                .opacity(animateOffset == 0 ? 1 : 0)
                .animation(AppTheme.Animations.staggeredEntrance(index: 1), value: animateOffset)

            checkInHistorySection
                .offset(y: animateOffset == 0 ? 0 : 40)
                .opacity(animateOffset == 0 ? 1 : 0)
                .animation(AppTheme.Animations.staggeredEntrance(index: 2), value: animateOffset)
        }
        .onAppear {
            animateOffset = 0
            editedReview = restaurant.review
        }
        .sheet(isPresented: $showSheet) {
            CheckInView(restaurant: restaurant, editingLog: logToEdit, onClose: {
                showSheet = false
            })
        }
        .confirmationDialog("更换封面图", isPresented: $showActionSheet) {
            Button("📸 拍照") { showCamera = true }
            Button("🖼️ 从相册选择") { showPhotoPicker = true }
            if restaurant.coverPhotoFilename != nil {
                Button("🗑️ 删除封面", role: .destructive) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        restaurant.coverPhotoFilename = nil
                    }
                    // 同时清理临时图片数组
                    newCoverImages = []
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(selectedImages: $newCoverImages)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem)
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        updateCover(image: image)
                    }
                }
            }
        }
        .onChange(of: newCoverImages.first) { _, newValue in
            if let image = newValue { updateCover(image: image) }
        }
    }
    
    private var backgroundGradient: some View {
        MilkyDiffuseBackground()
    }
    
    // Hero Card Content (重构版：完美解决报错)
        private var heroCardContent: some View {
            ZStack(alignment: .bottom) {
                // --- 1. 底层：餐厅原始图片 ---
                GeometryReader { geo in
                    AsyncImageView(
                        filename: restaurant.coverPhotoFilename,
                        placeholder: AnyView(
                            Rectangle()
                                .fill(AppTheme.Colors.lightGray)
                                .overlay(
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.lighterGray)
                                )
                        )
                    )
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
                
                // --- 2. 中层：动态磨砂渐变层 ---
                // 这一层实现了从清晰到磨砂的平滑过渡
                Rectangle()
                    .fill(.thinMaterial) // 系统自带磨砂材质
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),      // 顶部完全清晰
                                .init(color: .black.opacity(0.55), location: 0.55), //开始逐渐模糊
                                .init(color: .black.opacity(0.75), location: 0.75), // 中间开始变模糊
                                .init(color: .black, location: 1.0)     // 底部完全模糊
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 220) // 磨砂区域的高度
                
                // --- 3. 顶层：信息叠层 ---
                heroCardInfo
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 320)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(AppTheme.Colors.rimLight, lineWidth: 1.5)
            )
            .cardStyle()
        }

    // Hero Card Embedded Info
        private var heroCardInfo: some View {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(restaurant.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                    
                    HStack(spacing: 8) {
                        Text(restaurant.type)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.white.opacity(0.35), in: Capsule())
                        
                        if restaurant.averagePrice > 0 {
                            Text("¥\(Int(restaurant.averagePrice))/人")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        }
                    }
                }
                
                Spacer()
                
                heroCheckInButton
            }
            .padding(.horizontal, 20)
        }



    // MARK: - 1. 动画包装层 (请确保只有一个)
        private var heroSection: some View {
            heroCardContent
                .frame(height: 320)
                // 与页面整体动画同步，使用相同的 animateOffset
                .opacity(animateOffset == 0 ? 1 : 0)
                .scaleEffect(animateOffset == 0 ? 1.0 : 0.95)
                .onTapGesture {
                    showActionSheet = true
                }
        }

        
    // MARK: - Hero Check-in Button (黑底白字+红勾样式)
    private var heroCheckInButton: some View {
        Button {
            AppTheme.Animations.mediumImpact.impactOccurred()
            showSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(AppTheme.Colors.accent) // 小红书红
                Text("去打卡")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white) // 白色字体
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black) // 黑色背景
            )
        }
        .pressableButton() // 果冻手感扩展
    }

    // MARK: - 一体化信息容器（统计+点评+标签）
    private var unifiedInfoSection: some View {
        VStack(spacing: 0) {
            // 1. 统计区域
            statsRow
                .padding(.vertical, 16)
            
            // 2. 点评区域（保留编辑动效）
            unifiedReviewRow
                .padding(.vertical, 16)
            
            // 3. 标签区域（保留编辑动效）
            unifiedTagsRow
                .padding(.vertical, 16)
                .id("tagsSection")
        }
        .cardStyle()
    }

    // MARK: - 统计行
    private var statsRow: some View {
        HStack(spacing: 0) {
            statMiniCard(
                icon: "flame.fill",
                iconColor: AppTheme.Colors.iconOrange,
                title: "累计打卡",
                value: "\(restaurant.checkInCount)"
            )
            
            Divider()
                .frame(height: 30)
                .opacity(0.1)
            
            statMiniCard(
                icon: "creditcard.fill",
                iconColor: AppTheme.Colors.iconPurple,
                title: "总消费",
                value: restaurant.totalExpense > 0 ? "\(Int(restaurant.totalExpense))" : "--"
            )
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - 点评行（深色胶囊背景）
    private var unifiedReviewRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("一句话点评")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.horizontal, 20)

            // 点评内容（可点击编辑）
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    if isEditingReview {
                        ZStack(alignment: .center) {
                            TextField(restaurant.review.isEmpty ? "添加你的点评..." : restaurant.review, text: $editedReview, axis: .vertical)
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
                        Text(restaurant.review.isEmpty ? "点击添加点评..." : restaurant.review)
                            .font(.body)
                            .foregroundColor(restaurant.review.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.mediumGray)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .frame(minHeight: isEditingReview ? 150 : 48)
                .id(isEditingReview)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.Colors.warmGray)
                )

                // 勾叉按钮（使用统一组件）
                if isEditingReview {
                    EditActionButtons(
                        onCancel: cancelReview,
                        onConfirm: saveReview
                    )
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 20)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isEditingReview)
            .onTapGesture {
                if !isEditingReview {
                    editedReview = restaurant.review
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        isEditingReview = true
                    }
                }
            }
        }
    }
    
    // MARK: - 标签区域（完全使用 ProfileView 的实现逻辑）
    private var unifiedTagsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("标签")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.horizontal, 20)

            // 标签内容（可点击编辑）
            ZStack(alignment: .bottomTrailing) {
                tagsCloudMainContent
                tagsCloudActionButtons
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 标签区域主内容（完全复制 ProfileView）
    private var tagsCloudMainContent: some View {
        VStack(spacing: 0) {
            tagsLayoutContainer

            if isEditingTags {
                presetTagsSection
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(AppTheme.Animations.standardSpring, value: isEditingTags)
        .onTapGesture {
            if !isEditingTags {
                withAnimation(AppTheme.Animations.editingSpring) {
                    isEditingTags = true
                }
            }
        }
    }

    // MARK: - 标签布局容器（完全复制 ProfileView）
    @ViewBuilder
    private var tagsLayoutContainer: some View {
        if isEditingTags {
            tagsEditingLayout
        } else {
            tagsDisplayLayout
        }
    }

    // MARK: - 编辑模式标签布局（完全复制 ProfileView）
    private var tagsEditingLayout: some View {
        FlowLayout(spacing: 10) {
            ForEach(restaurant.tags, id: \.self) { tag in
                restaurantTagSticker(tag)
            }
            restaurantNewTagInputField
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
    }

    // MARK: - 新标签输入框（完全复制 ProfileView）
    private var restaurantNewTagInputField: some View {
        TextField("新标签...", text: $newTagInput)
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(AppTheme.Colors.darkText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.5))
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.babyBlue.opacity(0.3), lineWidth: 1)
            )
            .focused($tagInputIsFocused)
            .frame(minWidth: 80)
            .onSubmit {
                addNewTag()
            }
    }

    // MARK: - 展示模式标签布局（完全复制 ProfileView）
    private var tagsDisplayLayout: some View {
        FlowLayout(spacing: 10) {
            ForEach(restaurant.tags, id: \.self) { tag in
                restaurantTagSticker(tag)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
    }

    // MARK: - 标签区域操作按钮（勾叉）- 使用统一组件
    @ViewBuilder
    private var tagsCloudActionButtons: some View {
        if isEditingTags {
            EditActionButtons(
                onCancel: {
                    withAnimation(AppTheme.Animations.editingSpring) {
                        cancelTags()
                        isEditingTags = false
                        newTagInput = ""
                    }
                },
                onConfirm: {
                    withAnimation(AppTheme.Animations.editingSpring) {
                        saveTags()
                        isEditingTags = false
                        newTagInput = ""
                    }
                }
            )
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }


    
    private var statsSection: some View {
        HStack(spacing: 0) {
            statMiniCard(
                icon: "flame.fill",
                iconColor: AppTheme.Colors.iconOrange,
                title: "累计打卡",
                value: "\(restaurant.checkInCount)"
            )
            
            statMiniCard(
                icon: "creditcard.fill",
                iconColor: AppTheme.Colors.iconPurple,
                title: "总消费",
                value: restaurant.totalExpense > 0 ? "\(Int(restaurant.totalExpense))" : "--"
            )
        }
        .padding(4)
        .cardStyle()
    }

    private func statMiniCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 22, height: 22)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.lightText)
                
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("一句话点评")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            ZStack(alignment: .bottomTrailing) {
                reviewCardContent

                // 勾叉按钮（使用统一组件）
                if isEditingReview {
                    EditActionButtons(
                        onCancel: cancelReview,
                        onConfirm: saveReview
                    )
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .onTapGesture {
            if !isEditingReview {
                editedReview = restaurant.review
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    isEditingReview = true
                }
            }
        }
    }

    private var reviewCardContent: some View {
        VStack(spacing: 0) {
            reviewContent
                .frame(minHeight: isEditingReview ? 150 : 60)
                .id(isEditingReview)
        }
        .cardStyle()
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isEditingReview)
    }

    @ViewBuilder
    private var reviewContent: some View {
        if isEditingReview {
            ZStack(alignment: .center) {
                TextField(restaurant.review.isEmpty ? "添加你的点评..." : restaurant.review, text: $editedReview, axis: .vertical)
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
            Text(restaurant.review.isEmpty ? "添加你的点评..." : restaurant.review)
                .font(.body)
                .foregroundColor(restaurant.review.isEmpty ? AppTheme.Colors.lighterGray : AppTheme.Colors.mediumGray)
                .lineSpacing(4)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }
    




    // MARK: - 常用标签区域（完全复制 ProfileView）
    private var presetTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用标签")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)

            FlowLayout(spacing: 10) {
                ForEach(presetTags.filter { !restaurant.tags.contains($0) }, id: \.self) { tag in
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                            restaurant.tags.append(tag)
                        }
                    } label: {
                        Text(tag)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.5))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.Colors.separatorGray.opacity(0.5), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - 餐厅标签贴纸（完全复制 ProfileView 的 profileTagSticker）
    private func restaurantTagSticker(_ tag: String) -> some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)

            if isEditingTags {
                // 删除按钮
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        restaurant.tags.removeAll { $0 == tag }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Colors.lightText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppTheme.Colors.warmGray.opacity(0.6))
        )
    }

    private func saveReview() {
        restaurant.review = editedReview
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isEditingReview = false
        }
        try? modelContext.save()
    }
    
    private func cancelReview() {
        editedReview = restaurant.review
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isEditingReview = false
        }
    }
    
    private func saveTags() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isEditingTags = false
        }
        try? modelContext.save()
    }
    
    private func cancelTags() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isEditingTags = false
        }
    }
    
    private func addNewTag() {
        let tag = newTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if !restaurant.tags.contains(tag) {
                restaurant.tags.append(tag)
            }
            newTagInput = ""
        }
    }
    
    private let presetTags = ["网红店", "性价比", "环境好", "服务好", "排队久", "踩雷", "常客", "回头客"]
    
    // MARK: - 显示打卡记录详情的状态
    @State private var showCheckInHistory = false
    
    private var checkInHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("打卡记录")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.darkText)

                Text("(\(restaurant.logs.count))")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.mediumGray)

                Spacer()
                
                // 查看更多按钮（当记录超过3条时显示）
                if restaurant.logs.count > 3 {
                    Button {
                        showCheckInHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("查看更多")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(AppTheme.Colors.babyBlue)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

            if restaurant.logs.isEmpty {
                emptyCheckInState
            } else {
                // 只显示最近3条打卡记录
                let recentLogs = restaurant.logs.sorted(by: { $0.date > $1.date }).prefix(3)
                ForEach(Array(recentLogs)) { log in
                    checkInLogCard(log: log)
                }
            }

            deleteRestaurantButton
        }
        .sheet(isPresented: $showCheckInHistory) {
            CheckInHistoryView(restaurant: restaurant)
        }
    }

    private var emptyCheckInState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.Colors.lightText)

            Text("暂无记录")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#525252"))

            Button {
                showSheet = true
            } label: {
                Text("立即打卡")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#1A1A1A"))
                    )
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    private var deleteRestaurantButton: some View {
        Button(role: .destructive) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            modelContext.delete(restaurant)
            isPresented = false
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("删除餐厅")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(Color(hex: "#1A1A1A"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .foregroundStyle(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                    )
            )
        }
        .cardStyle()
    }

    private func checkInLogCard(log: VisitLog) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 日期行
            Text(log.date.chineseDateTime)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            // 指标水平栏
            HStack(spacing: 0) {
                // 人均
                metricCell(
                    title: "人均",
                    value: Int(log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0),
                    unit: "¥",
                    valueColor: AppTheme.Colors.accent
                )
                
                // 分隔线
                Divider()
                    .frame(height: 20)
                    .opacity(0.1)
                
                // 总额
                metricCell(
                    title: "总额",
                    value: Int(log.expense),
                    unit: "¥"
                )
                
                // 分隔线
                Divider()
                    .frame(height: 20)
                    .opacity(0.1)
                
                // 人数
                metricCell(
                    title: "人数",
                    value: log.peopleCount,
                    unit: "人"
                )
            }
            .padding(.top, 12)
            
            if let firstFilename = log.photoFilenames.first {
                AsyncImageView(
                    filename: firstFilename,
                    placeholder: AnyView(EmptyView())
                )
                .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipped()
                    .padding(.top, 8)
            }

            if !log.goodDishes.isEmpty || !log.badDishes.isEmpty {
                HStack(spacing: 16) {
                    if !log.goodDishes.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.accent)
                            Text(log.goodDishes)
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.darkText)
                        }
                    }
                    if !log.badDishes.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.mediumGray)
                            Text(log.badDishes)
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.darkText)
                        }
                    }
                }
                .padding(.top, 12)
            }

            if !log.review.isEmpty {
                Text(log.review)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Colors.softBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                            )
                    )
            }
        }
        .padding(20)
        .cardStyle()
        .contextMenu {
            Button {
                logToEdit = log
                showSheet = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                modelContext.delete(log)
                restaurant.updateAveragePrice()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - 指标单元格
    private func metricCell(title: String, value: Int, unit: String, valueColor: Color = AppTheme.Colors.darkText) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if unit == "¥" {
                    Text("¥")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
                
                Text("\(value)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(valueColor)
                
                if unit == "人" {
                    Text("人")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
    
    private func updateCover(image: UIImage) {
        if let filename = ImageManager.shared.saveImage(image) {
            restaurant.coverPhotoFilename = filename
        }
    }
}

// MARK: - FlowLayout 自动换行布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
