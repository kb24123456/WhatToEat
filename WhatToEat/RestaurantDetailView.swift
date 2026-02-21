import SwiftUI
import MapKit
import SwiftData
import UIKit
import PhotosUI

// MARK: - 修复：在使用自定义返回按钮时恢复侧滑返回手势
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

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
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm"
            return "今日 \(formatter.string(from: self))"
        }

        if calendar.isDateInYesterday(self) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm"
            return "昨日 \(formatter.string(from: self))"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: self)
    }

    var journalTime: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return "就在刚刚"
        }

        if calendar.isDateInYesterday(self) {
            return "昨日"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: self)
    }
}

// MARK: - 辅助结构体和扩展
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

// MARK: - 主视图
struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let locationManager: LocationManager
    @Binding var navigationPath: NavigationPath
    
    @State private var showSheet = false
    @State private var logToEdit: VisitLog? = nil
    
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var newCoverImages: [UIImage] = []
    
    // MARK: - 评论编辑状态
    @State private var isEditingReview = false
    @State private var editedReview = ""
    @FocusState private var reviewIsFocused: Bool
    
    // MARK: - 标签编辑状态
    @State private var isEditingTags = false
    @State private var newTagInput = ""
    @FocusState private var tagInputIsFocused: Bool
    
    // MARK: - 驾车信息
    @State private var drivingDistance: String = ""
    @State private var drivingTime: String = ""
    @State private var hasCalculatedDrivingInfo = false
    @State private var showNavigationMenu = false
    
    // MARK: - 评论输入模糊效果
    @State private var isCommentEditing = false
    
    // MARK: - 动画状态
    @State private var isAppearing = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // 背景色 - 与吃啥页面一致
                Color(hex: "#F9F9F7")
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // 顶部按钮栏
                            topButtonBar
                                .padding(.horizontal, 20)
                                .padding(.top, 12 + geometry.safeAreaInsets.top)
                                .padding(.bottom, 8)
                            
                            // 餐厅图片 - 4:3 比例
                            restaurantImageSection
                                .padding(.horizontal, 64)
                                .padding(.top, 20)
                                .opacity(isAppearing ? 1 : 0)
                                .offset(y: isAppearing ? 0 : 30)
                                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isAppearing)
                            
                            // 餐厅名称
                            restaurantNameSection
                                .padding(.top, 28)
                                .opacity(isAppearing ? 1 : 0)
                                .offset(y: isAppearing ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1), value: isAppearing)
                            
                            // MARK: - 数据行组（导航+消费+评分）- 16pt 组内紧凑
                            Group {
                                // 第一行：距离/时间/区域 + 右侧去这里按钮
                                navigationDataRow
                                    .padding(.top, 24)
                                    .padding(.horizontal, 40)
                                    .opacity(isAppearing ? 1 : 0)
                                    .offset(y: isAppearing ? 0 : 20)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.2), value: isAppearing)
                                
                                // 第二行：总消费/人均/打卡次数 + 右侧打卡按钮
                                consumptionDataRow
                                    .padding(.top, 16)
                                    .padding(.horizontal, 40)
                                    .opacity(isAppearing ? 1 : 0)
                                    .offset(y: isAppearing ? 0 : 20)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25), value: isAppearing)
                                
                                // 第三行：评分/品类（可编辑）
                                editableDataRow
                                    .padding(.top, 16)
                                    .padding(.horizontal, 40)
                                    .opacity(isAppearing ? 1 : 0)
                                    .offset(y: isAppearing ? 0 : 20)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.3), value: isAppearing)
                            }
                            
                            // MARK: - 评论和标签合并区域 - 24pt 组间宽松
                            reviewAndTagsSection
                                .padding(.top, 24)
                                .padding(.horizontal, 40)
                                .opacity(isAppearing ? 1 : 0)
                                .offset(y: isAppearing ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.35), value: isAppearing)
                            
                            // MARK: - 打卡记录 - 32pt 大区块分隔
                            // 任务4：左右间距改为40pt与其他卡片保持一致
                            checkInHistorySection
                                .padding(.top, 32)
                                .padding(.horizontal, 40)
                                .opacity(isAppearing ? 1 : 0)
                                .offset(y: isAppearing ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.4), value: isAppearing)
                            
                            // 删除按钮
                            deleteRestaurantButton
                                .padding(.top, 28)
                                .padding(.horizontal, 40)
                                .opacity(isAppearing ? 1 : 0)
                                .offset(y: isAppearing ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.45), value: isAppearing)
                            
                            Spacer().frame(height: 50)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                }
                
                // 评论输入时的高斯模糊效果
                if isCommentEditing {
                    Color.black.opacity(0.01)
                        .ignoresSafeArea()
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .opacity(isCommentEditing ? 1 : 0)
                        .animation(.linear(duration: 0.8), value: isCommentEditing)
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            editedReview = restaurant.review
            if !hasCalculatedDrivingInfo {
                calculateDrivingInfo()
            }
            // 触发动画
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isAppearing = true
            }
        }
        .sheet(isPresented: $showSheet) {
            CheckInView(restaurant: restaurant, editingLog: logToEdit, onClose: {
                showSheet = false
            })
        }
        // MARK: - 更换封面菜单（无图标）
        .confirmationDialog("更换封面图", isPresented: $showActionSheet) {
            Button("拍照") { showCamera = true }
            Button("从相册选择") { showPhotoPicker = true }
            if restaurant.coverPhotoFilename != nil {
                Button("删除封面", role: .destructive) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        restaurant.coverPhotoFilename = nil
                    }
                    newCoverImages = []
                }
            }
            Button("取消", role: .cancel) { }
        }
        .confirmationDialog("选择导航应用", isPresented: $showNavigationMenu, titleVisibility: .visible) {
            Button("高德地图") {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                NavigationManager.shared.openMap(type: .amap, restaurant: restaurant)
            }
            Button("百度地图") {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                NavigationManager.shared.openMap(type: .baidu, restaurant: restaurant)
            }
            Button("苹果地图") {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                NavigationManager.shared.openMap(type: .apple, restaurant: restaurant)
            }
            Button("取消", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(selectedImages: $newCoverImages)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        newCoverImages = [image]
                    }
                }
            }
        }
        .onChange(of: newCoverImages.first) { _, newValue in
            if let image = newValue { updateCover(image: image) }
        }
    }
    
    // MARK: - 顶部按钮栏
    private var topButtonBar: some View {
        HStack {
            // 返回按钮 - iOS 26 液态玻璃样式
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                navigationPath.removeLast()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .controlSize(.mini)
            .clipShape(Circle())
            
            Spacer()
            
            // 更换封面按钮 - iOS 26 液态玻璃样式
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showActionSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 12, weight: .semibold))
                    Text("更换封面")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
    }
    
    // MARK: - 餐厅图片区域 - 4:3 比例
    private var restaurantImageSection: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * 0.75 // 4:3 比例
            
            ZStack {
                if let filename = restaurant.coverPhotoFilename {
                    AsyncImageView(
                        filename: filename,
                        placeholder: AnyView(
                            Rectangle()
                                .fill(AppTheme.Colors.cardBackground)
                        )
                    )
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    // 脉冲动画占位符
                    PulsePlaceholder()
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
    }
    
    // MARK: - 脉冲动画占位符
    struct PulsePlaceholder: View {
        @State private var isPulsing = false
        
        var body: some View {
            ZStack {
                AppTheme.Colors.cardBackground
                
                Image(systemName: "fork.knife")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.Colors.lighterGray)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
                    .opacity(isPulsing ? 0.7 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
            }
            .onAppear {
                isPulsing = true
            }
        }
    }
    
    // MARK: - 餐厅名称区域
    private var restaurantNameSection: some View {
        Text(restaurant.name)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 40)
    }
    
    // MARK: - 第一行：导航信息大胶囊（距离/时间/区域 + 去这里按钮）
    private var navigationDataRow: some View {
        HStack(spacing: 0) {
            // 左侧数据区域（无图标，无分割线）
            HStack(spacing: 0) {
                // 距离
                SimpleDataItem(
                    value: formatDistanceValue(),
                    label: "距离"
                )
                
                // 驾车时间
                SimpleDataItem(
                    value: drivingTime.isEmpty ? "--" : drivingTime,
                    label: "驾车"
                )
                
                // 区域
                SimpleDataItem(
                    value: restaurant.district.isEmpty ? "未知" : restaurant.district,
                    label: "区域"
                )
            }
            .frame(maxWidth: .infinity)
            
            // 右侧圆形图标按钮（仅图标，无文字）- 48pt 直径，4pt 边距
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showNavigationMenu = true
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.darkText)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.trailing, 4)
        }
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - 第二行：消费数据大胶囊（总消费/人均/打卡次数 + 打卡按钮）
    private var consumptionDataRow: some View {
        HStack(spacing: 0) {
            // 左侧数据区域（无图标，无分割线）
            HStack(spacing: 0) {
                // 总消费
                SimpleDataItem(
                    value: "¥\(Int(restaurant.logs.reduce(0) { $0 + $1.expense }))",
                    label: "总消费"
                )
                
                // 人均
                SimpleDataItem(
                    value: "¥\(Int(restaurant.averagePrice))",
                    label: "人均"
                )
                
                // 打卡次数
                SimpleDataItem(
                    value: "\(restaurant.checkInCount)次",
                    label: "打卡"
                )
            }
            .frame(maxWidth: .infinity)
            
            // 右侧圆形图标按钮（仅图标，无文字）- 48pt 直径，4pt 边距
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showSheet = true
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.darkText)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.trailing, 4)
        }
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - 第三行：可编辑数据（评分/品类）
    // 胶囊高度与导航胶囊一致(56pt)，宽度填满可用空间
    // 评分展开时品类按钮隐藏，评分选择器填满整个宽度
    @State private var isRatingExpanded = false
    
    private var editableDataRow: some View {
        HStack(spacing: 12) {
            // 评分 - 可编辑（AddRestaurantView同款展开组件）
            ExpandableRatingView(
                currentRating: restaurant.rating,
                onRatingSelected: { newRating in
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.3)) {
                        restaurant.rating = newRating
                    }
                },
                onExpandStateChanged: { isExpanded in
                    withAnimation(.spring(response: 0.3)) {
                        isRatingExpanded = isExpanded
                    }
                }
            )
            .frame(maxWidth: isRatingExpanded ? .infinity : nil)
            
            // 品类 - 可编辑（液态玻璃菜单）
            // 评分展开时隐藏
            if !isRatingExpanded {
                Menu {
                    let categories = ["火锅", "烧烤", "日料", "西餐", "中餐", "快餐", "甜品", "咖啡", "其他"]
                    ForEach(categories, id: \.self) { category in
                        Button(category) {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.3)) {
                                restaurant.type = category
                            }
                        }
                    }
                } label: {
                    // 任务1&2：取消彩色边框，品类图标采用babyblue
                    EditableDataCardNoBorder(
                        icon: "fork.knife",
                        value: restaurant.type.isEmpty ? "未分类" : restaurant.type,
                        label: "品类",
                        color: AppTheme.Colors.babyBlue
                    )
                }
                .frame(maxWidth: .infinity)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
    
    // MARK: - 评论和标签合并区域（圆角卡片样式，参考其他数据卡片）
    private var reviewAndTagsSection: some View {
        VStack(alignment: .leading, spacing: 40) {
            // 评论区域 - 参考LibraryView卡片样式
            reviewSection
            
            // 标签区域 - 参考ProfileView样式
            tagsSection
        }
        .padding(16)
        .background(
            // 任务3：圆角改为28pt
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - 评论区域 - 参考LibraryView卡片样式
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                Text("评价")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Spacer()
                
                // 编辑按钮 - 液态玻璃 + 触觉反馈 + darkText颜色
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    isEditingReview.toggle()
                    if isEditingReview {
                        reviewIsFocused = true
                    }
                } label: {
                    Image(systemName: isEditingReview ? "checkmark" : "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .controlSize(.mini)
                .clipShape(Circle())
            }
            
            // 评论内容 - 参考LibraryView卡片样式（带指示条）
            if isEditingReview {
                // 编辑模式
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(AppTheme.Colors.babyBlue)
                        .frame(width: 3, height: 14)
                    
                    TextEditor(text: $editedReview)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .frame(minHeight: 60)
                        .focused($reviewIsFocused)
                        .onChange(of: reviewIsFocused) { _, isFocused in
                            if !isFocused && isEditingReview {
                                // 失去焦点时保存
                                withAnimation {
                                    restaurant.review = editedReview
                                    isEditingReview = false
                                }
                            }
                        }
                }
            } else {
                // 展示模式 - 参考LibraryView卡片样式
                if restaurant.review.isEmpty {
                    Button {
                        isEditingReview = true
                        reviewIsFocused = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text("添加评价")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.babyBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.babyBlue.opacity(0.1))
                        )
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(AppTheme.Colors.babyBlue)
                            .frame(width: 3, height: 14)
                        
                        Text(restaurant.review)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.darkText)
                            .lineSpacing(2)
                    }
                }
            }
        }
    }
    
    // MARK: - 标签区域 - 参考ProfileView样式
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text("标签")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Spacer()
                
                // 任务1&4：管理按钮改为slider.horizontal.3图标，编辑模式切换为checkmark
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isEditingTags.toggle()
                    }
                } label: {
                    Image(systemName: isEditingTags ? "checkmark" : "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .controlSize(.mini)
                .clipShape(Circle())
            }
            
            // 标签布局 - 参考ProfileView
            FlowLayout(spacing: 10) {
                ForEach(restaurant.tags, id: \.self) { tag in
                    tagSticker(tag)
                }
                
                // 添加新标签按钮
                if isEditingTags {
                    newTagInputField
                } else if restaurant.tags.count < 10 {
                    newTagButton
                }
            }
            
            // 编辑模式下显示预设标签
            if isEditingTags {
                presetTagsSection
            }
        }
    }
    
    // MARK: - 预设标签区域（参考AddRestaurantView）
    private var presetTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐标签")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
                .padding(.top, 8)
            
            FlowLayout(spacing: 10) {
                let presetTags = ["氛围感", "老字号", "二刷", "排队王", "性价比", "网红店", "环境好", "服务好", "踩雷", "常客"]
                ForEach(presetTags.filter { !restaurant.tags.contains($0) }, id: \.self) { tag in
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
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
                                    .fill(AppTheme.Colors.softBackground)
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
    
    // MARK: - 标签贴纸 - 参考ProfileView
    private func tagSticker(_ tag: String) -> some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            if isEditingTags {
                // 删除按钮
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
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
                .fill(AppTheme.Colors.softBackground)
        )
        // 任务5：标签添加细微阴影
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - 新标签输入框
    private var newTagInputField: some View {
        TextField("新标签...", text: $newTagInput)
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(AppTheme.Colors.darkText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.softBackground)
            )
            // 任务3：激活状态边框由蓝色改为darktext
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.darkText.opacity(0.3), lineWidth: 1)
            )
            .focused($tagInputIsFocused)
            .frame(minWidth: 80)
            .submitLabel(.done)
            .onSubmit {
                addNewTag()
            }
            .onAppear {
                // 延迟聚焦，避免键盘弹出动画冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    tagInputIsFocused = true
                }
            }
    }
    
    // MARK: - 新标签按钮
    private var newTagButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isEditingTags = true
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
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.clear)
            )
            // 任务5：新标签改为虚线边框
            .overlay(
                Capsule()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(AppTheme.Colors.separatorGray)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 添加新标签
    private func addNewTag() {
        let trimmed = newTagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty && !restaurant.tags.contains(trimmed) else { 
            newTagInput = ""
            return 
        }
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
            restaurant.tags.append(trimmed)
            newTagInput = ""
        }
        
        // 如果标签数量达到上限，退出编辑模式
        if restaurant.tags.count >= 10 {
            withAnimation {
                isEditingTags = false
            }
        }
    }
    
    // MARK: - 打卡记录区域（参考CheckInView样式）
    private var checkInHistorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 任务4：标题样式与其他卡片保持一致
            HStack {
                Text("打卡记录")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Text("(\(restaurant.logs.count))")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.lightText)
                
                Spacer()
            }
            .padding(.bottom, 12)
            
            // 记录列表
            if restaurant.logs.isEmpty {
                emptyCheckInState
            } else {
                let sortedLogs = restaurant.logs.sorted(by: { $0.date > $1.date })
                ForEach(Array(sortedLogs.enumerated()), id: \.element.id) { index, log in
                    checkInLogCard(log: log, index: index)
                }
            }
        }
    }
    
    // MARK: - 空状态
    private var emptyCheckInState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppTheme.Colors.babyBlue)
            
            Text("还没有打卡记录")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.Colors.darkText)
            
            Text("第一次的相遇总是最难忘的，去记录这份美味吧")
                .font(.system(size: 14, weight: .regular))
                .italic()
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showSheet = true
            } label: {
                Text("去打卡")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
    }
    
    // MARK: - 打卡记录卡片（任务5：采用CheckInView样式）
    private func checkInLogCard(log: VisitLog, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部：日期 + 心情（参考CheckInView timeHeaderView）
            HStack(spacing: 6) {
                Text(log.date.chineseDateOnly)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                if let mood = log.mood, let moodType = MoodType.allCases.first(where: { $0.rawValue == mood }) {
                    Text(moodType.rawValue)
                        .font(.system(size: 14))
                    Text(moodType.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
                
                Spacer()
            }
            .padding(.bottom, 12)
            
            // 任务5：消费信息行（参考CheckInView receiptSection样式）
            HStack(spacing: 16) {
                // 消费（带底部横线）
                VStack(alignment: .leading, spacing: 8) {
                    Text("消费")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                    
                    HStack(spacing: 2) {
                        Text("¥")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.Colors.darkText)
                        Text("\(Int(log.expense))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Rectangle()
                        .fill(AppTheme.Colors.softBackground)
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity)
                
                // 人数（带底部横线）
                VStack(alignment: .leading, spacing: 8) {
                    Text("人数")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                    
                    HStack(spacing: 2) {
                        Text("\(log.peopleCount)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                        Text("人")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Rectangle()
                        .fill(AppTheme.Colors.softBackground)
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity)
                
                // 人均（无底部横线）
                VStack(alignment: .leading, spacing: 8) {
                    Text("人均")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                    
                    HStack(spacing: 2) {
                        Text("¥")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                        Text("\(Int(log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 12)
            
            // 任务5：菜品标签（参考CheckInView stickyNoteView样式）
            if !log.goodDishes.isEmpty || !log.badDishes.isEmpty {
                HStack(spacing: 12) {
                    if !log.goodDishes.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.accent)
                            
                            Text(log.goodDishes)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.darkText)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.accent.opacity(0.1))
                        )
                    }
                    
                    if !log.badDishes.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                            
                            Text(log.badDishes)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.darkText)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.softBackground)
                        )
                    }
                }
            }
            
            // 备注
            if !log.review.isEmpty {
                Text(log.review)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineSpacing(3)
                    .padding(.top, 12)
                    .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
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
    
    // MARK: - 删除按钮
    private var deleteRestaurantButton: some View {
        Button(role: .destructive) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            modelContext.delete(restaurant)
            navigationPath.removeLast()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("删除餐厅")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(AppTheme.Colors.mediumGray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
            )
        }
    }
    
    // MARK: - 辅助方法
    private func formatDistanceValue() -> String {
        guard let userLocation = locationManager.userLocation else { return "--" }
        let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
        let distance = userLocation.distance(from: restaurantLocation)
        
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    private func calculateDrivingInfo() {
        guard let userLocation = locationManager.userLocation else { return }
        let restaurantLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
        let distance = userLocation.distance(from: restaurantLocation)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let speedKmH: Double = 30
            let timeHours = (distance / 1000) / speedKmH
            let timeMinutes = Int(timeHours * 60)
            
            let timeStr: String
            if timeMinutes < 1 {
                timeStr = "<1分钟"
            } else if timeMinutes < 60 {
                timeStr = "\(timeMinutes)分钟"
            } else {
                let hours = timeMinutes / 60
                let mins = timeMinutes % 60
                timeStr = "\(hours)小时\(mins)分钟"
            }
            
            DispatchQueue.main.async {
                self.drivingTime = timeStr
                self.hasCalculatedDrivingInfo = true
            }
        }
    }
    
    private func updateCover(image: UIImage) {
        if let filename = ImageManager.shared.saveImage(image) {
            restaurant.coverPhotoFilename = filename
        }
    }
}

// MARK: - 简洁数据项组件（无图标，用于大胶囊内部）
struct SimpleDataItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.Colors.mediumGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 可编辑数据卡片组件（胶囊样式）
// 高度与导航胶囊一致(56pt)
struct EditableDataCardNoBorder: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.mediumGray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
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

// MARK: - 评分展开组件（AddRestaurantView同款Dock风格）
struct ExpandableRatingView: View {
    let currentRating: Double
    let onRatingSelected: (Double) -> Void
    let onExpandStateChanged: ((Bool) -> Void)?
    
    @State private var isExpanded = false {
        didSet {
            onExpandStateChanged?(isExpanded)
        }
    }
    
    // 评分项数据（与AddRestaurantView一致）
    private let ratingItems: [RatingItemData] = [
        RatingItemData(score: 1.0, emoji: "🤮", slang: "拉完了"),
        RatingItemData(score: 2.0, emoji: "🤔", slang: "NPC"),
        RatingItemData(score: 3.0, emoji: "😋", slang: "人上人"),
        RatingItemData(score: 4.0, emoji: "😍", slang: "顶级"),
        RatingItemData(score: 5.0, emoji: "🤩", slang: "夯！")
    ]
    
    var body: some View {
        ZStack {
            // 展开后的横向矩形
            if isExpanded {
                expandedContainer
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .center).combined(with: .opacity)
                    ))
            } else {
                // 收起状态的胶囊按钮
                collapsedButton
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
    
    // MARK: - 收起状态：胶囊按钮
    private var collapsedButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                
                Text(String(format: "%.1f", currentRating))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .lineLimit(1)
                
                Text("评分")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - 展开状态：横向矩形
    // 宽度填满可用空间，高度为112pt（56pt的两倍）
    private var expandedContainer: some View {
        HStack(spacing: 0) {
            ForEach(ratingItems, id: \.score) { item in
                RatingOptionView(
                    item: item,
                    isSelected: currentRating == item.score,
                    isExpanded: true,
                    onTap: { selectRating(item.score) }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 112)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - 选择评分
    private func selectRating(_ score: Double) {
        onRatingSelected(score)
        triggerHaptic(for: score)
        
        // 延迟收起
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded = false
            }
        }
    }
    
    // MARK: - 触感反馈
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
struct RatingItemData {
    let score: Double
    let emoji: String
    let slang: String
}

// MARK: - 评分选项视图
struct RatingOptionView: View {
    let item: RatingItemData
    let isSelected: Bool
    var isExpanded: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: isExpanded ? 10 : 4) {
                ZStack {
                    // 选中态光晕效果
                    if isSelected {
                        Circle()
                            .fill(glowColor.opacity(0.25))
                            .blur(radius: isExpanded ? 20 : 16)
                            .frame(width: isExpanded ? 60 : 50, height: isExpanded ? 60 : 50)
                        
                        Circle()
                            .fill(glowColor.opacity(0.4))
                            .blur(radius: isExpanded ? 10 : 8)
                            .frame(width: isExpanded ? 45 : 38, height: isExpanded ? 45 : 38)
                    }
                    
                    // Emoji
                    Text(item.emoji)
                        .font(.system(size: isExpanded ? 34 : 28))
                        .scaleEffect(isSelected ? 1.15 : 0.9)
                        .opacity(isSelected ? 1.0 : 0.5)
                        .grayscale(isSelected ? 0.0 : 0.5)
                        .offset(y: isSelected ? (isExpanded ? -3 : -3) : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
                .frame(height: isExpanded ? 48 : 40)
                
                // 俚语文字
                Text(item.slang)
                    .font(.system(size: isExpanded ? 13 : 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? AppTheme.Colors.darkText : AppTheme.Colors.lightText)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // 光晕颜色
    private var glowColor: Color {
        switch item.score {
        case 1.0:
            return Color(hex: "#4A4A4A") // 深灰色
        case 2.0:
            return Color.gray // 灰色
        case 3.0:
            return Color(hex: "#E8E8E8") // 灰白色
        case 4.0:
            return AppTheme.Colors.accent // 小红书红
        case 5.0:
            return Color(hex: "#FFD700") // 金色
        default:
            return Color.gray
        }
    }
}
