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
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

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
    
    @State private var animateOffset: CGFloat = 500
    
    // MARK: - Animation States
    @State private var isAnimated = false
    @State private var cardScale: CGFloat = 1.0
    
    // MARK: - Drag to Dismiss States
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroSection
                            .padding(.horizontal, 20)
                            .padding(.top, 8 + geometry.safeAreaInsets.top)
                            .padding(.bottom, 16)
                        
                        // Bottom Lists with staggered slide-up animation
                        bottomContentSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .offset(y: animateOffset)
            .offset(y: dragOffset.height)
            .animation(
                .interpolatingSpring(stiffness: 120, damping: 15)
                    .speed(1.2)
                    .delay(0.1),
                value: animateOffset
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // 只允许向下拖动
                        if value.translation.height > 0 {
                            dragOffset = value.translation
                            isDragging = true
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        // 如果拖动距离超过 100pt 或速度超过阈值，则关闭
                        if value.translation.height > 100 || value.velocity.height > 500 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        } else {
                            // 否则回弹到原位
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
        }
        .interactiveDismissDisabled(true)
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Bottom Content Section (Premium Staggered Animation)
    private var bottomContentSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            unifiedInfoSection
                .offset(y: isAnimated ? 0 : 40)
                .opacity(isAnimated ? 1 : 0)
                .animation(AppTheme.Animations.staggeredEntrance(index: 3), value: isAnimated)
            
            checkInHistorySection
                .offset(y: isAnimated ? 0 : 40)
                .opacity(isAnimated ? 1 : 0)
                .animation(AppTheme.Animations.staggeredEntrance(index: 6), value: isAnimated)
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
            .shadow(color: Color.black.opacity(0.02), radius: 20, x: 0, y: 10)
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
                            .foregroundColor(AppTheme.Colors.mediumGray)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.white.opacity(0.35), in: Capsule())
                        
                        if restaurant.averagePrice > 0 {
                            Text("¥\(Int(restaurant.averagePrice))/人")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.Colors.mediumGray)
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
                .offset(y: isAnimated ? 0 : 50)
                .opacity(isAnimated ? 1 : 0)
                .onAppear {
                    withAnimation(AppTheme.Animations.standardSpring) {
                        isAnimated = true
                    }
                }
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
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
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
    
    // MARK: - 点评行（保留编辑动效）
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
                                 .onAppear {
                                     reviewIsFocused = true
                                 }
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
                bubbleButtons(
                    isEditing: isEditingReview,
                    onSave: saveReview,
                    onCancel: cancelReview
                )
                .padding(.trailing, 12)
                .offset(y: 24) // 向下偏移24pt，一半在容器内，一半在容器外
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
    
    // MARK: - 标签行（保留编辑动效）
    private var unifiedTagsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("标签")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.horizontal, 20)
            
            // 标签内容（可点击编辑）
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 12) {
                    FlowLayout(spacing: 10) {
                        ForEach(restaurant.tags, id: \.self) { tag in
                            tagSticker(tag: tag, isEditing: isEditingTags)
                        }
                        
                        if isEditingTags {
                            newTagInputField
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Colors.softBackground.opacity(isEditingTags ? 0.5 : 0.3))
                    )
                    
                    // 编辑状态下的常用标签
                    if isEditingTags {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("常用标签")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.mediumGray)
                                .padding(.horizontal, 4)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(presetTags.filter { !restaurant.tags.contains($0) }, id: \.self) { tag in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            restaurant.tags.append(tag)
                                        }
                                    } label: {
                                        Text(tag)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppTheme.Colors.mediumGray)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(AppTheme.Colors.softBackground)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditingTags)
                .onTapGesture {
                    if !isEditingTags {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditingTags = true
                        }
                    }
                }
                
                // 勾叉按钮（压在容器下边缘，一半在内一半在外）
                bubbleButtons(
                    isEditing: isEditingTags,
                    onSave: saveTags,
                    onCancel: cancelTags
                )
                .padding(.trailing, 12)
                .offset(y: 24) // 向下偏移24pt，一半在容器内，一半在容器外
            }
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
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.02), radius: 20, x: 0, y: 4)
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

                bubbleButtons(
                    isEditing: isEditingReview,
                    onSave: saveReview,
                    onCancel: cancelReview
                )
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
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.02), radius: 20, x: 0, y: 10)
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
                    .onAppear {
                        reviewIsFocused = true
                    }
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
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("标签")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            ZStack(alignment: .bottomTrailing) {
                tagsCardContent
                    .shadow(color: Color.black.opacity(0.02), radius: 20, x: 0, y: 10)

                bubbleButtons(
                    isEditing: isEditingTags,
                    onSave: saveTags,
                    onCancel: cancelTags
                )
            }
        }
        .onTapGesture {
            if !isEditingTags {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isEditingTags = true
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditingTags)
    }

    private var tagsCardContent: some View {
        VStack(spacing: 0) {
            tagsFlowContent
                .padding(20)

            if isEditingTags {
                Divider()
                    .background(AppTheme.Colors.glassWhite)
                    .padding(.horizontal, 20)

                presetTagsSection
                    .padding(20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.02), radius: 20, x: 0, y: 10)
    }

    private var tagsFlowContent: some View {
        FlowLayout(spacing: 10) {
            ForEach(restaurant.tags, id: \.self) { tag in
                tagSticker(tag: tag, isEditing: isEditingTags)
            }

            if isEditingTags {
                newTagInputField
            }
        }
    }

    private var newTagInputField: some View {
        HStack(spacing: 6) {
            TextField("新标签", text: $newTagInput)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#1A1A1A"))
                .frame(width: 60)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($tagInputIsFocused)
                .onSubmit {
                    addNewTag()
                }

            Button {
                addNewTag()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#525252"))
            }
            .disabled(newTagInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppTheme.Colors.softBackground)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                )
        )
    }

    private var presetTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用标签")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.mediumGray)
                .padding(.horizontal, 4)

            FlowLayout(spacing: 10) {
                ForEach(presetTags, id: \.self) { presetTag in
                    presetTagButton(presetTag: presetTag)
                }
            }
        }
    }

    private func presetTagButton(presetTag: String) -> some View {
        let isAdded = restaurant.tags.contains(presetTag)
        return Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                if isAdded {
                    restaurant.tags.removeAll { $0 == presetTag }
                } else {
                    restaurant.tags.append(presetTag)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 12))
                Text(presetTag)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isAdded ? .white : Color(hex: "#1A1A1A"))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isAdded ? AnyShapeStyle(Color(hex: "#1A1A1A")) : AnyShapeStyle(AppTheme.Colors.softBackground))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                    )
            )
        }
        .frame(minHeight: 44)
    }

    private func tagSticker(tag: String, isEditing: Bool) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#1A1A1A"))

            if isEditing {
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

    @State private var wiggleRotation: Double = 0
    @State private var isWiggling: Bool = false
    
    private func bubbleButtons(isEditing: Bool, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack {
            Spacer()
                .frame(height: 36)
            
            if isEditing {
                HStack(spacing: 16) {
                    cancelBubble(onCancel: onCancel)
                        .offset(y: 12)
                    
                    saveBubble(onSave: onSave)
                        .offset(y: 12)
                }
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    triggerWiggleAnimation()
                }
            }
        }
        .animation(
            .spring(response: 0.4, dampingFraction: 0.6),
            value: isEditing
        )
    }
    
    private func cancelBubble(onCancel: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            onCancel()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.black)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .contentShape(Circle())
        .frame(width: 48, height: 48)
        .rotationEffect(Angle.degrees(wiggleRotation))
    }
    
    private func saveBubble(onSave: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            onSave()
        }) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(AppTheme.Colors.accent)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.red.opacity(0.2), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .contentShape(Circle())
        .frame(width: 48, height: 48)
        .rotationEffect(Angle.degrees(-wiggleRotation))
    }
    
    private func triggerWiggleAnimation() {
        isWiggling = true
        withAnimation(
            Animation.linear(duration: 0.05)
                .repeatCount(6, autoreverses: true)
        ) {
            wiggleRotation = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                wiggleRotation = 0
                isWiggling = false
            }
        }
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

            if restaurant.logs.isEmpty {
                emptyCheckInState
            } else {
                ForEach(restaurant.logs.sorted(by: { $0.date > $1.date })) { log in
                    checkInLogCard(log: log)
                }
            }

            deleteRestaurantButton
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
        .shadow(color: Color.black.opacity(0.02), radius: 20, x: 0, y: 8)
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
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.02), radius: 20, x: 0, y: 10)
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
