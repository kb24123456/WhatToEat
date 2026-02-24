import SwiftUI
import MapKit
import SwiftData

// MARK: - iOS 锁屏通知风格堆叠卡片
struct StackedRestaurantCard: View {
    let restaurant: Restaurant
    @ObservedObject var locationManager: LocationManager
    let index: Int
    let stackScale: CGFloat
    let isStacked: Bool
    
    var onCheckInTap: (() -> Void)? = nil
    var onNavigate: (() -> Void)? = nil
    
    // MARK: - 动力学参数
    private enum Metrics {
        static let cornerRadius: CGFloat = 32  // 保持32pt圆角
        static let strokeWidth: CGFloat = 0.5
        static let strokeOpacity: CGFloat = 0.04  // 4%黑色描边
    }
    
    private var isCheckedIn: Bool {
        restaurant.checkInCount > 0
    }
    
    var body: some View {
        Button(action: {
            // 触觉反馈：轻微震动
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            onNavigate?()
        }) {
            HStack(alignment: .center, spacing: 16) {
                // 左侧：图片
                heroImage
                
                // 右侧：内容
                contentSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
        // 物理质感实色系统：压住背景流动感
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(Color.white)  // 与RestaurantDetailView胶囊相同的白色背景
        )
        // 双层描边系统：白色高光 + 黑色物理边框
        .overlay(
            ZStack {
                // 内层：白色高光描边（顶部/左侧光源效果）
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                
                // 外层：极淡黑色物理边框
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
            }
        )
        // iOS 26 小组件风格阴影
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 16,
            x: 0,
            y: 4
        )
        // 距离屏幕左右边缘 16pt 间距
        .padding(.horizontal, 16)
    }
    
    // MARK: - 图片区域
    private var heroImage: some View {
        AsyncImageView(
            filename: restaurant.coverPhotoFilename,
            placeholder: AnyView(
                ZStack {
                    AppTheme.Colors.babyBlue.opacity(0.1)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                }
            )
        )
        .frame(width: 80, height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
    }
    
    // MARK: - 内容区域 (参照图中布局)
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部填充：0pt
            
            // 第一行：店名 + 打卡勋章
            HStack(spacing: 8) {
                // 店名带智能淡出效果（仅在需要时显示）
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        // 店名文字，使用 fixedSize 防止省略号
                        Text(restaurant.name)
                            .font(.custom("ResourceHanRoundedCN-Bold", size: 18))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                            .fixedSize(horizontal: true, vertical: false)
                            .background(
                                // 用于测量文字实际宽度
                                GeometryReader { textGeometry in
                                    Color.clear.preference(
                                        key: TextWidthPreferenceKey.self,
                                        value: textGeometry.size.width
                                    )
                                }
                            )
                        
                        // 右侧淡出渐变遮罩（仅在文字超出时显示）
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0),
                                AppTheme.Colors.milkWhite
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: min(60, geometry.size.width * 0.3))
                        .opacity(restaurant.name.width(withFont: UIFont(name: "ResourceHanRoundedCN-Bold", size: 18) ?? UIFont.systemFont(ofSize: 18)) > geometry.size.width ? 1 : 0)
                    }
                    .frame(width: geometry.size.width, height: 20, alignment: .leading)
                    .clipped()
                }

                // 小红书红打卡勋章
                checkInBadge
            }
            .frame(height: 20) // 固定高度
            // 店名与其他信息间距：14pt（大幅突出店名）
            .padding(.bottom, 14)

            // 第二行：距离 / 区域 / 品类 / 价格
            metadataRow
            .frame(height: 16) // 固定高度
            // 第二行与第三行间距：2pt（紧凑）
            .padding(.bottom, 2)

            // 第三行：评分星星 + 标签（始终显示）
            ratingAndTagsRow
            // 第三行与第四行间距：2pt（紧凑）
            .padding(.bottom, 2)

            // 第四行：评论（始终显示）
            if !restaurant.review.isEmpty {
                reviewRow
                    .frame(height: 32) // 固定2行高度
            } else {
                Color.clear.frame(height: 32) // 无评论时占位
            }
            
            // 底部填充：0pt
        }
        .frame(maxWidth: .infinity, maxHeight: 108, alignment: .leading)
    }
    
    // MARK: - 元数据行 (距离 / 区域 / 品类 / 价格)
    private var metadataRow: some View {
        let distanceText: String = {
            guard let userLocation = locationManager.userLocation else { return "" }
            let distance = userLocation.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
            return distance < 1000 ? String(format: "%.0fm", distance) : String(format: "%.1fkm", distance / 1000)
        }()
        
        let priceText = restaurant.averagePrice > 0 ? "¥\(Int(restaurant.averagePrice))" : "-"
        
        var parts: [String] = []
        if !distanceText.isEmpty { parts.append(distanceText) }
        if !restaurant.district.isEmpty { parts.append(restaurant.district) }
        if !restaurant.type.isEmpty { parts.append(restaurant.type) }
        parts.append(priceText)
        
        return Text(parts.joined(separator: " / "))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppTheme.Colors.textSecondary)
    }
    
    // MARK: - 评分和标签行
    private var ratingAndTagsRow: some View {
        HStack(spacing: 10) {
            // 评分星星 - 高度与13pt文本一致
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(restaurant.rating) ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundColor(index < Int(restaurant.rating) ? AppTheme.Colors.secondary : Color.gray.opacity(0.3))
                }
            }
            .frame(height: 16) // 固定高度与13pt文本行高一致
            
            // 标签（最多显示2个）- 高度与13pt文本一致
            if !restaurant.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(restaurant.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.babyBlue.opacity(0.12))
                            )
                    }
                }
                .frame(height: 16) // 固定高度与13pt文本行高一致
            }
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - 评论行
    private var reviewRow: some View {
        HStack(alignment: .top, spacing: 6) {
            // Baby Blue 指示条
            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppTheme.Colors.babyBlue)
                .frame(width: 3, height: 14)
                .padding(.top, 2)
            
            // 评论文字
            Text(restaurant.review)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#7F8C8D"))  // 评论使用 #7F8C8D
                .lineLimit(2)
                .lineSpacing(2)
        }
    }
    
    // MARK: - 打卡勋章（圆形容器样式 - 参考图）
    @State private var isPressed = false
    
    private var checkInBadge: some View {
        Button(action: {
            // 触觉反馈：轻微震动
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            onCheckInTap?()
        }) {
            ZStack {
                // 圆形背景
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                
                // 打钩图标 + 数字
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accent)
                    
                    if restaurant.checkInCount > 0 {
                        Text("\(restaurant.checkInCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                }
            }
            // 轻量阴影
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
            // 灵动的缩放动效
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - 文字宽度计算扩展
extension String {
    func width(withFont font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        return self.size(withAttributes: attributes).width
    }
}

// MARK: - 文字宽度 PreferenceKey
struct TextWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 预览
#Preview {
    StackedRestaurantCard(
        restaurant: Restaurant(
            name: "测试餐厅",
            type: "火锅",
            district: "渝中区",
            city: "重庆",
            rating: 4,
            address: "测试地址123号",
            latitude: 29.5630,
            longitude: 106.5516,
            coverPhotoFilename: nil,
            review: "味道很不错，值得再来",
            tags: ["辣", "正宗"],
            averagePrice: 88
        ),
        locationManager: LocationManager(),
        index: 0,
        stackScale: 1.0,
        isStacked: false
    )
    .padding()
}
