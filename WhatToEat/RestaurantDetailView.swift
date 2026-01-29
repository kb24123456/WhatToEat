import SwiftUI
import MapKit
import SwiftData
import UIKit
import PhotosUI

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
        VStack(alignment: .leading, spacing: 20) {
            statsSection
                .offset(y: isAnimated ? 0 : 40)
                .opacity(isAnimated ? 1 : 0)
                .animation(AppTheme.Animations.staggeredEntrance(index: 3), value: isAnimated)
            
            reviewSection
                .offset(y: isAnimated ? 0 : 40)
                .opacity(isAnimated ? 1 : 0)
                .animation(AppTheme.Animations.staggeredEntrance(index: 4), value: isAnimated)
            
            tagsSection
                .offset(y: isAnimated ? 0 : 40)
                .opacity(isAnimated ? 1 : 0)
                .animation(AppTheme.Animations.staggeredEntrance(index: 5), value: isAnimated)
            
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
                    restaurant.coverPhotoFilename = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(selectedImages: $newCoverImages)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem)
        .onChange(of: newCoverImages.first) { _, newValue in
            if let image = newValue { updateCover(image: image) }
        }
    }
    
    private var backgroundGradient: some View {
        AppTheme.Colors.softBackground
            .ignoresSafeArea()
    }
    
    // MARK: - Immersive Hero Card
        private var heroSection: some View {
            ZStack(alignment: .bottom) {
                // 1. 核心卡片内容
                heroCardContent
                
                // 2. 关闭按钮 (浮在卡片最顶层左上角)
                closeButton
                    .padding(.top, 16)
                    .padding(.leading, 36) // 20(外层) + 16 = 36，保持相对于卡片的位置
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 320)
            .offset(y: isAnimated ? 0 : 50)
            .opacity(isAnimated ? 1 : 0)
            .onAppear {
                withAnimation(AppTheme.Animations.standardSpring) {
                    isAnimated = true
                }
            }
        }

    // Hero Card Content (宽度与圆角边框匹配修复版)
    private var heroCardContent: some View {
        ZStack(alignment: .bottom) {
            // --- 底层：图片填充 ---
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    Rectangle()
                        .fill(AppTheme.Colors.lightGray)
                        .overlay(Image(systemName: "fork.knife").foregroundColor(.gray))
                )
            )
            .scaledToFill() // 1. 先进行比例填充
            .frame(height: 320) // 2. 固定高度
            .frame(maxWidth: .infinity) // 3. 强制横向撑满容器
            .clipped() // 4. 裁剪掉溢出部分
            
            // --- 顶层：奶脂柔焦容器 ---
            VStack(spacing: 0) {
                Spacer()
                
                heroCardInfo // 信息叠层直接放在这个容器里
                    .padding(.bottom, 24)
                    .padding(.top, 45) // 为渐变留出呼吸空间
                    .frame(maxWidth: .infinity) // 确保背景层横向铺满
                    .background(
                        ZStack {
                            // 1. 毛玻璃基底 (带平滑蒙版)
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: 0),
                                            .init(color: .black, location: 0.4)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            
                            // 2. 奶白色多点平滑渐变
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0), location: 0),
                                            .init(color: .white.opacity(0.4), location: 0.3),
                                            .init(color: .white.opacity(0.85), location: 0.6),
                                            .init(color: AppTheme.Colors.milkyWhite, location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
            }
            .frame(maxWidth: .infinity) // 确保叠层容器横向铺满
        }
        .frame(maxWidth: .infinity) // 外层 ZStack 自适应宽度
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(AppTheme.Colors.rimLight, lineWidth: 6) // 极致高光边 (Rim Light)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    // Hero Card Embedded Info (注意：背景变白了，文字要改回深色)
    private var heroCardInfo: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(restaurant.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary) // 改为深色
                
                HStack(spacing: 8) {
                    // 品类标签 (更通透的样式)
                    Text(restaurant.type)
                        .font(.caption2).bold()
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.black.opacity(0.05), in: Capsule())
                    
                    // 人均消费
                    if restaurant.averagePrice > 0 {
                        Text("¥\(Int(restaurant.averagePrice))/人")
                            .font(.caption2).bold()
                            .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            // 打卡按钮 (在白色背景上，黑色按钮最高级)
            heroCheckInButton
        }
        .padding(.horizontal, 20) // 统一水平内边距，与其他组件一致
    }

    // MARK: - Hero Check-in Button (纯黑胶囊样式)
    private var heroCheckInButton: some View {
        Button {
            AppTheme.Animations.mediumImpact.impactOccurred()
            showSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .black))
                Text("去打卡")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.darkText, in: Capsule()) // 纯黑按钮
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .pressableButton() // 果冻手感扩展
    }
    
    private var closeButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented = false
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
                                .stroke(AppTheme.Colors.glassBorder, lineWidth: 0.5)
                        )
                )
                .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 2)
                .shadow(color: AppTheme.Shadows.light.color, radius: 4, x: 0, y: 1)
        }
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statMiniCard(
                icon: "flame.fill",
                iconColor: AppTheme.Colors.iconOrange,
                title: "累计打卡",
                value: "\(restaurant.checkInCount) 次"
            )
            
            statMiniCard(
                icon: "creditcard.fill",
                iconColor: AppTheme.Colors.iconPurple,
                title: "总消费",
                value: restaurant.totalExpense > 0 ? "¥\(Int(restaurant.totalExpense))" : "暂无"
            )
        }
    }
    
    private func statMiniCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.mediumGray)

                // 金额使用等宽数字字体
                if value.contains("¥") {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                } else {
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.Colors.glassBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: AppTheme.Shadows.base.color, radius: 15, x: 0, y: 8)
        .shadow(color: AppTheme.Colors.shadowColor, radius: 6, x: 0, y: 2)
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("一句话点评")
                .font(.headline)
                .foregroundColor(Color(hex: "#1A1A1A"))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

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
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppTheme.Colors.glassBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: AppTheme.Shadows.base.color, radius: 15, x: 0, y: 10)
        .shadow(color: AppTheme.Colors.shadowColor, radius: 6, x: 0, y: 2)
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
        VStack(alignment: .leading, spacing: 0) {
            Text("标签")
                .font(.headline)
                .foregroundColor(Color(hex: "#1A1A1A"))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            ZStack(alignment: .bottomTrailing) {
                tagsCardContent
                    .shadow(color: AppTheme.Shadows.light.color, radius: 30, x: 0, y: 10)

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
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Colors.glassBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 2)
        .shadow(color: AppTheme.Shadows.light.color, radius: 4, x: 0, y: 1)
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
                    .fill(isAdded ? AnyShapeStyle(Color(hex: "#1A1A1A")) : AnyShapeStyle(.ultraThinMaterial))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
        }
        .frame(minHeight: 44)
    }

    private func tagSticker(tag: String, isEditing: Bool) -> some View {
        HStack(spacing: 6) {
            Text("#")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#525252"))

            Text(tag)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#1A1A1A"))

            if isEditing {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        restaurant.tags.removeAll { $0 == tag }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#525252"))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
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
                .foregroundColor(.black)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .foregroundStyle(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("打卡记录")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1A1A1A"))

                Text("(\(restaurant.logs.count))")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#525252"))

                Spacer()
            }

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
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                    )
            )
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func checkInLogCard(log: VisitLog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(log.date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#525252"))

                Spacer()

                let perPerson = log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0
                Text("人均 ¥\(Int(perPerson))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .foregroundStyle(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
            }

            if let firstFilename = log.photoFilenames.first {
                AsyncImageView(
                    filename: firstFilename,
                    placeholder: AnyView(EmptyView())
                )
                .scaledToFill() // 1. 先进行填充缩放
                    .frame(maxWidth: .infinity) // 2. 强制宽度撑满
                    .frame(height: 320) // 3. 固定高度
                    .clipped() // 4. 裁剪掉超出容器的部分
            }

            HStack(spacing: 16) {
                // 消费金额 - 使用等宽数字字体
                HStack(spacing: 4) {
                    Image(systemName: "creditcard")
                        .font(.subheadline)
                    Text("\(Int(log.expense))")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    Text("元")
                        .font(.subheadline)
                }
                .foregroundColor(Color(hex: "#525252"))

                Text("•")
                    .foregroundColor(Color(hex: "#7A7A7A"))

                Label("\(log.peopleCount) 人", systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#525252"))
            }

            if !log.goodDishes.isEmpty || !log.badDishes.isEmpty {
                HStack(spacing: 12) {
                    if !log.goodDishes.isEmpty {
                        Label(log.goodDishes, systemImage: "hand.thumbsup.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#1A1A1A"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .foregroundStyle(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                    }
                    if !log.badDishes.isEmpty {
                        Label(log.badDishes, systemImage: "hand.thumbsdown.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#525252"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .foregroundStyle(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                    }
                }
            }

            if !log.review.isEmpty {
                Text(log.review)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundStyle(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                            )
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
