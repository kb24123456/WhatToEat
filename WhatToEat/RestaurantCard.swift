import SwiftUI
import MapKit
import SwiftData

// MARK: - 杂志级餐厅卡片 (Editorial Magazine Card)
struct RestaurantCard: View {
    let restaurant: Restaurant
    @ObservedObject var locationManager: LocationManager
    let isExpanded: Bool
    let index: Int

    var onCheckInTap: (() -> Void)? = nil
    @State private var isPressed = false

    // MARK: - 杂志级间距系统 (Golden Ratio Spacing)
    private enum Spacing {
        static let micro: CGFloat = 12     // 微间距：行内元素（从 8 增大到 12）
        static let small: CGFloat = 8      // 小间距：紧密相关元素
        static let medium: CGFloat = 12    // 中间距：卡片垂直内边距（12pt，总间距24pt）
        static let large: CGFloat = 20     // 大间距：主要模块间
        static let section: CGFloat = 24   // 章节间距：卡片边缘
    }

    // MARK: - 字体系统 (Typography Scale) - Oreo 排版校对
    private enum Typography {
        static let title = Font.system(size: 17, weight: .bold, design: .default)
        static let metadata = Font.system(size: 11, weight: .medium, design: .default)
        static let quote = Font.system(size: 13, weight: .medium, design: .default)
        static let badge = Font.system(size: 11, weight: .semibold, design: .default)
    }
    
    // Oreo: 标题字间距
    private var titleTracking: CGFloat { 0.5 }

    private func distanceText(from: CLLocation, to restaurant: Restaurant) -> String {
        let distance = from.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
        return distance < 1000 ? String(format: "%.0fm", distance) : String(format: "%.1fkm", distance / 1000)
    }

    private var priceText: String {
        restaurant.averagePrice > 0 ? "¥\(Int(restaurant.averagePrice))" : "-"
    }

    private var metaLine: String {
        var parts: [String] = []
        if let userLocation = locationManager.userLocation {
            parts.append(distanceText(from: userLocation, to: restaurant))
        }
        if !restaurant.district.isEmpty { parts.append(restaurant.district) }
        if !restaurant.type.isEmpty { parts.append(restaurant.type) }
        parts.append(priceText)
        return parts.joined(separator: " / ")
    }

    var body: some View {
        Group {
            if restaurant.modelContext != nil {
                cardContent
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - 杂志级布局 (Magazine Layout)
    private var cardContent: some View {
        HStack(alignment: .center, spacing: 16) {
            heroImage
            editorialContent
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.milkyBase)  // Misty White 雾白背景 #F7F8FA
        // 极细边框增强轮廓感 - Misty Oreo 风格
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .offset(y: isPressed ? -2 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
    }

    // MARK: - 影像呈现 (Hero Image with Parallax)
    @State private var imageOffset: CGFloat = 0
    
    private var heroImage: some View {
        GeometryReader { geo in
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    ZStack {
                        Color(hex: "#F5F5F5")
                        Image(systemName: "fork.knife")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }
                )
            )
            .frame(width: 140, height: 140) // 增大尺寸以容纳视差位移
            .offset(x: imageOffset)
            .onAppear {
                // 根据索引产生不同的初始偏移，创造错落感
                imageOffset = CGFloat(index % 2 == 0 ? -5 : 5)
            }
            // 监听列表滚动产生视差
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ParallaxPreferenceKey.self, value: proxy.frame(in: .global).minY)
                }
            )
            .onPreferenceChange(ParallaxPreferenceKey.self) { value in
                // 根据视图在屏幕中的位置计算视差偏移
                let screenHeight = ScreenMetrics.bounds.height
                let normalizedPosition = value / screenHeight
                withAnimation(.linear(duration: 0.1)) {
                    imageOffset = normalizedPosition * 20 - 10 // ±10pt 视差范围
                }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.image, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.image, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        // Oreo: 内阴影效果 - 高级相框质感
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.image, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.08),
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
    
    // MARK: - 视差偏移 PreferenceKey
    struct ParallaxPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    // MARK: - 编辑内容 (Editorial Content)
    private var editorialContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行：标题 + 打卡徽章
            HStack(spacing: 8) {
                Text(restaurant.name)
                    .font(Typography.title)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .tracking(titleTracking)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                checkInBadge
            }

            // 元数据：距离 / 区域 / 品类 / 价格
            metadataRow
                .padding(.top, Spacing.micro)

            // 评分和标签
            if restaurant.rating > 0 {
                ratingRow
                    .padding(.top, Spacing.small)
            }

            // 评论
            if !restaurant.review.isEmpty {
                quoteSection
                    .padding(.top, Spacing.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 标题（带淡出遮罩）- Oreo 排版校对
    private var titleWithFade: some View {
        GeometryReader { geometry in
            Text(restaurant.name)
                .font(Typography.title)
                .foregroundColor(Color(hex: "#1A1A1A"))
                .tracking(titleTracking) // Oreo: 17pt 以上标题增加字间距
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask(
                    HStack(spacing: 0) {
                        // 主要文字区域（不透明）
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: max(0, geometry.size.width - 40))
                        // 右侧淡出区域（渐变透明）
                        LinearGradient(
                            colors: [Color.black, Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 40)
                    }
                )
        }
        .frame(height: 22) // Typography.title 的高度
    }

    // MARK: - 打卡勋章（圆形带次数，32pt）
    private var checkInBadge: some View {
        Button(action: { onCheckInTap?() }) {
            ZStack {
                // 圆形背景（更透明）
                Circle()
                    .fill(Color(hex: "#FFFFFF").opacity(0.7))
                    .frame(width: 32, height: 32)
                    .shadow(
                        color: Color.black.opacity(0.06),
                        radius: 2,
                        x: 0,
                        y: 1
                    )

                // 对勾图标（有打卡次数时显示数字）
                if restaurant.checkInCount > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(restaurant.checkInCount)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(AppTheme.Colors.accent)
                } else {
                    // 无打卡时只显示勾
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Colors.accent)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 元数据行
    private var metadataRow: some View {
        Text(metaLine)
            .font(Typography.metadata)
            .foregroundColor(AppTheme.Colors.mediumGray)
    }

    // MARK: - 评论区域
    private var quoteSection: some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            // 指示条
            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppTheme.Colors.babyBlue)
                .frame(width: 3, height: 12)
                .padding(.top, 2)

            // 评论文字 - Oreo: 统一行间距 5pt
            Text(restaurant.review)
                .font(Typography.quote)
                .foregroundColor(AppTheme.Colors.darkText.opacity(0.85))
                .lineLimit(2)
                .lineSpacing(5) // Oreo: 画报阅读感
        }
    }

    // MARK: - 评分和标签行
    private var ratingRow: some View {
        HStack(spacing: 10) {
            // 评分星星
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(restaurant.rating) ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundColor(index < Int(restaurant.rating) ? AppTheme.Colors.secondary : Color.gray.opacity(0.3))
                }
            }

            // 标签 - 紧凑布局
            if !restaurant.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(restaurant.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.babyBlue.opacity(0.12))
                            )
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - 预览
#Preview {
    struct PreviewWrapper: View {
        var body: some View {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: Restaurant.self, configurations: config)

            let restaurant = Restaurant(
                name: "厚道烤肉",
                type: "烧烤",
                district: "两江新区",
                city: "重庆",
                rating: 4.5,
                address: "测试地址",
                latitude: 39.9,
                longitude: 116.4,
                coverPhotoFilename: nil,
                review: "一定要老板亲自烤！",
                tags: [],
                averagePrice: 48
            )

            for _ in 0..<3 {
                let log = VisitLog(date: Date(), expense: 200, peopleCount: 2, goodDishes: "", badDishes: "", review: "", mood: "😋", restaurant: restaurant)
                restaurant.logs.append(log)
            }

            return RestaurantCard(
                restaurant: restaurant,
                locationManager: LocationManager.shared,
                isExpanded: false,
                index: 0,
                onCheckInTap: {}
            )
            .modelContainer(container)
        }
    }
    return PreviewWrapper()
}
