import SwiftUI
import MapKit
import SwiftData
import UIKit
import PhotosUI

// MARK: - 修复：在使用自定义返回按钮时恢复侧滑返回手势
// 这段代码启用原生的 iMessage 风格交互式返回效果
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 只有在导航栈中有多个视图控制器时才启用手势
        return viewControllers.count > 1
    }
}

// MARK: - Oreo: 中文日期格式化扩展（情感化时间）
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

    // Oreo: 情感化时间显示
    var chineseDateTime: String {
        let calendar = Calendar.current
        let now = Date()

        // 判断是否是今天
        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm"
            return "今日 \(formatter.string(from: self))"
        }

        // 判断是否是昨天
        if calendar.isDateInYesterday(self) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm"
            return "昨日 \(formatter.string(from: self))"
        }

        // 其他日期
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: self)
    }

    // Oreo: 手账感时间
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
// 优化：不拦截从屏幕边缘开始的滑动，避免与右滑返回手势冲突
struct PressableButtonModifier: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        // 忽略从边缘开始的拖动（避免与右滑返回冲突）
                        let startX = value.startLocation.x
                        guard startX > 40 else { return }
                        
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
    
    @State private var isEditingReview = false
    @State private var editedReview = ""
    @FocusState private var reviewIsFocused: Bool
    
    @State private var isEditingTags = false
    @State private var newTagInput = ""
    @FocusState private var tagInputIsFocused: Bool
    
    // MARK: - 驾车信息（懒加载计算）
    @State private var drivingDistance: String = ""
    @State private var drivingTime: String = ""
    @State private var hasCalculatedDrivingInfo = false
    @State private var showNavigationMenu = false
    
    // MARK: - Keyboard Animation Delay
    private let keyboardAnimationDelay: TimeInterval = 0.25  // 展开动画完成后再弹出键盘

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // 背景渐变层
                backgroundGradient
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.Card.spacingSmall) { // Misty Oreo: 32pt 间距
                            heroSection
                                .padding(.horizontal, 24)
                                .padding(.top, 12 + geometry.safeAreaInsets.top)
                                .padding(.bottom, 0)
                            
                            // 统计卡片
                            statsRow
                                .padding(.horizontal, 24)

                            // Bottom Lists
                            bottomContentSection
                                .padding(.horizontal, 24)
                        }
                        .padding(.bottom, AppTheme.Card.spacingLarge) // 48pt 底部留白
                    }
                    .ignoresSafeArea(edges: .top)
                    // 标签编辑时自动滚动，确保常用标签显示在底部导航条上方
                    .onChange(of: isEditingTags) { _, isEditing in
                        if isEditing {
                            // 延迟等待布局完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    // 滚动到常用标签区域，使用 .center 确保整个区域（包括所有标签）都能显示
                                    proxy.scrollTo("presetTagsSection", anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            // 视图合成优化
            .compositingGroup()
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - Bottom Content Section (清理动画版)
    private var bottomContentSection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            unifiedInfoSection

            // 打卡记录标题 - 作为外部二级标题
            checkInHistoryHeader
                .padding(.top, 32) // 距离上方卡片 32pt
                .padding(.bottom, 12) // 距离下方记录 12pt

            // 打卡记录列表
            checkInHistoryList

            // 底部删除按钮
            deleteRestaurantButton
                .padding(.top, 28)

            // 底部留白
            Spacer().frame(height: 50)
        }
        .onAppear {
            editedReview = restaurant.review
            
            // 懒加载计算驾车信息（只在首次进入页面时计算）
            if !hasCalculatedDrivingInfo {
                calculateDrivingInfo()
            }
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
        .confirmationDialog("选择导航应用", isPresented: $showNavigationMenu, titleVisibility: .visible) {
            Button("高德地图") {
                // 触感反馈 + NavigationManager 导航
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                NavigationManager.shared.openMap(type: .amap, restaurant: restaurant)
            }
            Button("百度地图") {
                // 触感反馈 + NavigationManager 导航
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                NavigationManager.shared.openMap(type: .baidu, restaurant: restaurant)
            }
            Button("苹果地图") {
                // 触感反馈 + NavigationManager 导航
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
                        newCoverImages = [image]  // 单选替换逻辑
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
    
    // Hero Card Content (Apple Music 风格渐变模糊)
    private var heroCardContent: some View {
        ZStack(alignment: .bottom) {
            // --- 1. 底层：餐厅原始图片 ---
            GeometryReader { geo in
                AsyncImageView(
                    filename: restaurant.coverPhotoFilename,
                    placeholder: AnyView(
                        Rectangle()
                            .fill(AppTheme.Colors.cardBackground)
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

            // --- 2. 中层：渐变磨砂材质层 (Apple Music 风格) ---
            Rectangle()
                .fill(.ultraThinMaterial) // 系统磨砂材质
                .background(Color.white.opacity(0.1)) // 极淡白色叠加，增强文字可读性
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),           // 顶部 0% 完全透明
                            .init(color: .clear, location: 0.2),           // 顶部 20% 保持清晰
                            .init(color: .black.opacity(0.5), location: 0.45), // 45% 开始轻微磨砂
                            .init(color: .black, location: 0.7)            // 70% 达到完全磨砂
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 240) // 增加模糊区域高度

            // --- 3. 顶层：信息内容 ---
            VStack(spacing: 4) {
                Spacer()
                heroCardInfo
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // --- 4. 返回按钮（嵌入封面图左上角）---
            VStack(spacing: 0) {
                HStack {
                    backButton
                        .padding(.leading, 16)
                        .padding(.top, 12)
                    Spacer()
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 260) // 降低整体高度
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        // 扁平风格：细微边框替代阴影（放在底层，不遮挡按钮）
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        // Oreo: 内阴影效果 - 高级相框质感（放在底层，不遮挡按钮）
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.15),
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }
        
        // MARK: - 返回按钮
        private var backButton: some View {
            Button {
                navigationPath.removeLast()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
                    )
            }
            .pressableButton(scale: 0.9)
        }

    // Hero Card Embedded Info (扁平风格字体层级)
    private var heroCardInfo: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(restaurant.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)

                // 品类 + 地区 + 价格
                HStack(spacing: 8) {
                    Text(restaurant.type)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.darkText.opacity(0.7))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.softBackground)
                        )

                    // 地区
                    if !restaurant.district.isEmpty {
                        Text(restaurant.district)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.darkText.opacity(0.5))
                    }

                    if restaurant.averagePrice > 0 {
                        Text("¥\(Int(restaurant.averagePrice))/人")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText.opacity(0.7))
                    }
                }
            }

            Spacer()

            heroCheckInButton
        }
        .padding(.horizontal, 24)
    }

        // MARK: - 格式化距离
        private func formatDistance(_ distance: CLLocationDistance) -> String {
            if distance < 1000 {
                return String(format: "%.0fm", distance)
            } else {
                return String(format: "%.1fkm", distance / 1000)
            }
        }
        
        // MARK: - 估算驾车时间
        private func estimateDrivingTime(distance: CLLocationDistance) -> String {
            // 假设平均车速 30km/h（城市道路）
            let speedKmH: Double = 30
            let timeHours = (distance / 1000) / speedKmH
            let timeMinutes = Int(timeHours * 60)
            
            if timeMinutes < 1 {
                return "<1分钟"
            } else if timeMinutes < 60 {
                return "\(timeMinutes)分钟"
            } else {
                let hours = timeMinutes / 60
                let mins = timeMinutes % 60
                return "\(hours)小时\(mins)分钟"
            }
        }
        
        // MARK: - 打开导航菜单
        private func openNavigation() {
            showNavigationMenu = true
        }
        
        // MARK: - 计算驾车信息（性能优化：只在页面打开时计算一次）
        private func calculateDrivingInfo() {
            guard let userLocation = locationManager.userLocation else { return }
            
            let restaurantLocation = CLLocation(
                latitude: restaurant.latitude,
                longitude: restaurant.longitude
            )
            
            let distance = userLocation.distance(from: restaurantLocation)
            
            // 在后台线程计算
            DispatchQueue.global(qos: .userInitiated).async {
                let distanceStr = self.formatDistance(distance)
                let timeStr = self.estimateDrivingTime(distance: distance)
                
                // 回到主线程更新 UI
                DispatchQueue.main.async {
                    self.drivingDistance = distanceStr
                    self.drivingTime = timeStr
                    self.hasCalculatedDrivingInfo = true
                }
            }
        }



    // MARK: - Hero Section (清理动画版)
        private var heroSection: some View {
            heroCardContent
                .frame(height: 320)
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
        .oreoClickEffect(style: .medium) // Oreo: 黑色按钮用 medium 震动
    }

    // MARK: - 一体化信息容器（点评+标签）
    private var unifiedInfoSection: some View {
        VStack(spacing: 0) {
            // 1. 点评区域（保留编辑动效）
            unifiedReviewRow
                .padding(.vertical, AppTheme.Card.paddingVertical)
            
            // 分割线
            Divider()
                .opacity(0.05)
                .padding(.horizontal, AppTheme.Card.paddingHorizontal)
            
            // 2. 标签区域（保留编辑动效）
            unifiedTagsRow
                .padding(.vertical, AppTheme.Card.paddingVertical)
                .id("tagsSection")
        }
        .cardStyle() // 使用统一的 Crystal Container 样式
    }

    // MARK: - 统计卡片（1x2 网格布局 - 两个正方形）
    private var statsRow: some View {
        let horizontalPadding: CGFloat = 24 // 左右边距
        let spacing: CGFloat = 8 // 卡片之间的窄间距
        let cardSize: CGFloat = (UIScreen.main.bounds.width - horizontalPadding * 2 - spacing) / 2 // 减去左右边距和中间间距
        
        return HStack(spacing: spacing) {
            // 左卡片：累计打卡 + 总消费
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .frame(width: cardSize, height: cardSize)
                
                VStack(alignment: .leading, spacing: 16) {
                    // 上半部分：累计打卡
                    HStack(spacing: 12) {
                        // 图标 - 小红书红（更浅的背景）
                        ZStack {
                            Circle()
                                .fill(AppTheme.Colors.accent.opacity(0.06))
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.accent)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("已造访")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            // Oreo: 单位降权 - 数字 Bold，单位小 2pt Regular
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(restaurant.checkInCount)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.babyBlue)
                                Text("次")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.7))
                            }
                        }
                    }
                    
                    // 分割线
                    Rectangle()
                        .fill(AppTheme.Colors.lighterGray)
                        .frame(height: 1)
                        .opacity(0.3)
                    
                    // 下半部分：总消费
                    HStack(spacing: 12) {
                        // 图标
                        ZStack {
                            Circle()
                                .fill(AppTheme.Colors.iconPurple.opacity(0.1))
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.iconPurple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("总消费")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            // Oreo: 单位降权 - 数字 Bold，单位小 2pt Regular
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(restaurant.totalExpense > 0 ? "\(Int(restaurant.totalExpense))" : "--")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.babyBlue)
                                Text("元")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.vertical, 20)
            }
            .frame(width: cardSize, height: cardSize)
            
            // 右卡片：驾车信息 + 导航（可点击）
            Button {
                openNavigation()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                        .frame(width: cardSize, height: cardSize)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // 上半部分：驾车距离
                        HStack(spacing: 12) {
                            // 图标
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.babyBlue.opacity(0.1))
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: "car.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.babyBlue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("驾车距离")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                // Oreo: 单位降权 - 数字 Bold，单位小 2pt Regular
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(drivingDistance.isEmpty ? "--" : String(drivingDistance.dropLast(2)))
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                    Text(drivingDistance.isEmpty ? "" : "km")
                                        .font(.system(size: 18))
                                        .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.7))
                                }
                            }
                        }
                        
                        // 分割线
                        Rectangle()
                            .fill(AppTheme.Colors.lighterGray)
                            .frame(height: 1)
                            .opacity(0.3)
                        
                        // 下半部分：导航
                        HStack(spacing: 12) {
                            // 图标
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.babyBlue.opacity(0.1))
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.babyBlue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("导航")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                Text("去这里")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.xhsRed) // Misty Oreo: 感性动作用 xhsRed
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
                }
                .frame(width: cardSize, height: cardSize)
            }
            .buttonStyle(PlainButtonStyle())
            .oreoClickEffect(style: .light) // Oreo: Baby Blue 按钮用 light 震动
        }
    }

    // MARK: - 点评行（画报化版）
    private var unifiedReviewRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏：包含标题和取消/完成按钮
            HStack(alignment: .center, spacing: 0) {
                Text("一句话点评")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.darkText.opacity(0.4))
                    .tracking(0.5)
                
                Spacer()
                
                // 编辑状态下的取消/完成按钮
                if isEditingReview {
                    HStack(spacing: 16) {
                        Button {
                            cancelReview()
                        } label: {
                            Text("取消")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .oreoClickEffect(style: .light)

                        Button {
                            saveReview()
                        } label: {
                            Text("完成")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.Colors.xhsRed)
                        }
                        .oreoClickEffect(style: .light) // Oreo: 小红书红用 light 震动
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, AppTheme.Card.paddingHorizontal)

            // 点评内容（画报化样式）
            if isEditingReview {
                ZStack(alignment: .center) {
                    TextField(restaurant.review.isEmpty ? "添加你的点评..." : restaurant.review, text: $editedReview, axis: .vertical)
                        .font(.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineSpacing(6) // 增加行间距
                        .multilineTextAlignment(.center)
                        .focused($reviewIsFocused)
                        .scrollContentBackground(.hidden)
                        .submitLabel(.done)  // 键盘右下角显示"完成"
                        .padding(AppTheme.Card.paddingHorizontal)
                        .padding(.vertical, 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .onDisappear {
                            reviewIsFocused = false
                        }
                }
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.Colors.softBackground)
                )
                .padding(.horizontal, AppTheme.Card.paddingHorizontal)
            } else {
                // 画报化展示：左侧高亮条 + 斜体文字（与餐厅卡片同款样式）
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    // 指示条 - 与 RestaurantCard 同款样式，与文字第一行基线对齐
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(AppTheme.Colors.babyBlue)
                        .frame(width: 3, height: 12)
                    
                    Text(restaurant.review.isEmpty ? "点击添加点评..." : restaurant.review)
                        .font(.body)
                        .italic() // 斜体
                        .foregroundColor(restaurant.review.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                        .lineSpacing(5) // Oreo: 统一行间距 5pt
                        .padding(.vertical, 14)
                    
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Card.paddingHorizontal)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
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
    
    // MARK: - 标签区域（画报化版）
    private var unifiedTagsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏：包含标题和取消/完成按钮
            HStack(alignment: .center, spacing: 0) {
                Text("标签")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray) // 统一使用 mediumGray
                    .tracking(1.5) // 增加字间距
                
                Spacer()
                
                // 编辑状态下的取消/完成按钮
                if isEditingTags {
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(AppTheme.Animations.editingSpring) {
                                cancelTags()
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
                                saveTags()
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
            .padding(.horizontal, AppTheme.Card.paddingHorizontal)

            // 标签内容（可点击编辑）
            tagsCloudMainContent
                .padding(.horizontal, AppTheme.Card.paddingHorizontal)
        }
    }

    // MARK: - 标签区域主内容（优化动画）
    private var tagsCloudMainContent: some View {
        VStack(spacing: 0) {
            tagsLayoutContainer

            // 常用标签区域 - 使用 opacity 过渡避免上移
            if isEditingTags {
                presetTagsSection
                    .padding(.top, 16)
                    .transition(.opacity)
            }
        }
        // 使用更流畅的动画曲线
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isEditingTags)
        .onTapGesture {
            if !isEditingTags {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isEditingTags = true
                }
            }
        }
    }

    // MARK: - 标签布局容器（使用 @ViewBuilder 切换，与 ProfileView 一致）
    @ViewBuilder
    private var tagsLayoutContainer: some View {
        if isEditingTags {
            tagsEditingLayout
        } else {
            tagsDisplayLayout
        }
    }
    
    // MARK: - 编辑模式标签布局（无卡片背景，与常用标签一致）
    private var tagsEditingLayout: some View {
        FlowLayout(spacing: 10) {
            ForEach(Array(restaurant.tags.enumerated()), id: \.element) { index, tag in
                restaurantTagSticker(tag, index: index)
            }
            restaurantNewTagInputField
        }
    }

    // MARK: - 展示模式标签布局（无卡片背景，与常用标签一致）
    private var tagsDisplayLayout: some View {
        FlowLayout(spacing: 10) {
            ForEach(Array(restaurant.tags.enumerated()), id: \.element) { index, tag in
                restaurantTagSticker(tag, index: index)
            }
            // 新标签输入按钮（点击后进入编辑模式）
            newTagInputButton
        }
    }

    // MARK: - 新标签输入按钮（点击后进入编辑模式）
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
        }
    }

    // MARK: - 新标签输入框
    private var restaurantNewTagInputField: some View {
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
    }

    private var statsSection: some View {
        HStack(spacing: 0) {
            statMiniCard(
                icon: "flame.fill",
                iconColor: AppTheme.Colors.iconOrange,
                title: "已造访",
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
                    .opacity(0.6) // 图标降噪：透明度 0.6
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.lightText)
                
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.babyBlue) // 数字强调：Baby Blue
            }
            
            Spacer()
        }
        .padding(.horizontal, AppTheme.Card.paddingHorizontal)
        .padding(.vertical, 14)
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏：包含标题和取消/完成按钮
            HStack(alignment: .center, spacing: 0) {
                Text("一句话点评")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isEditingReview ? AppTheme.Colors.textSecondary : AppTheme.Colors.darkText)
                
                Spacer()
                
                // 编辑状态下的取消/完成按钮
                if isEditingReview {
                    HStack(spacing: 16) {
                        Button {
                            cancelReview()
                        } label: {
                            Text("取消")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                        }
                        
                        Button {
                            saveReview()
                        } label: {
                            Text("完成")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.Colors.accent)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, 24)

            reviewCardContent
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
                    .submitLabel(.done)  // 键盘右下角显示"完成"
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
        .id("presetTagsSection")
    }

    // MARK: - 餐厅标签贴纸（交替配色版）
    private func restaurantTagSticker(_ tag: String, index: Int) -> some View {
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
                .fill(index % 2 == 0 
                    ? AppTheme.Colors.babyBlue.opacity(0.08) 
                    : AppTheme.Colors.accent.opacity(0.08)) // 交替配色
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

    // MARK: - 打卡记录标题（外部二级标题）
    private var checkInHistoryHeader: some View {
        HStack {
            Text("打卡记录")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.mediumGray)
                .tracking(1.5)

            Text("(\(restaurant.logs.count))")
                .font(.system(size: 13))
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
        .padding(.horizontal, 24)
        .sheet(isPresented: $showCheckInHistory) {
            CheckInHistoryView(restaurant: restaurant)
        }
    }

    // MARK: - 打卡记录列表
    private var checkInHistoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if restaurant.logs.isEmpty {
                emptyCheckInState
            } else {
                // 只显示最近3条打卡记录
                let recentLogs = restaurant.logs.sorted(by: { $0.date > $1.date }).prefix(3)
                ForEach(Array(recentLogs)) { log in
                    checkInLogCard(log: log)
                }
            }
        }
    }

    // MARK: - Oreo: 极致情感化空状态
    private var emptyCheckInState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppTheme.Colors.babyBlue)

            // 标题 17pt Bold
            Text("还没有打卡记录")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.Colors.darkText)
                .tracking(0.5)

            // 描述 14pt Italic
            Text("第一次的相遇总是最难忘的，去记录这份美味吧")
                .font(.system(size: 14, weight: .regular))
                .italic()
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
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
            .oreoClickEffect(style: .medium)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
    }

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
                RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                            .stroke(AppTheme.Card.strokeColor, lineWidth: AppTheme.Card.strokeWidth)
                    )
            )
        }
        .padding(.horizontal, 24)
        // 扁平风格：去掉阴影
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
                                    .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
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
