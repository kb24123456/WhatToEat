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
        Button(action: { onNavigate?() }) {
            HStack(alignment: .center, spacing: 16) {
                // 左侧：图片
                heroImage
                
                // 右侧：内容
                contentSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        // 物理质感实色系统：压住背景流动感
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(AppTheme.Colors.milkWhite)  // 奶白背景，防止透视
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
        // 增强浮动阴影
        .shadow(
            color: Color.black.opacity(0.03),
            radius: 20,
            x: 0,
            y: 10
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
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
    }
    
    // MARK: - 内容区域 (参照图中布局)
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：店名 + 打卡勋章
            HStack {
                Text(restaurant.name)
                    .font(.custom("ResourceHanRoundedCN-Bold", size: 19))
                    .foregroundColor(Color(hex: "#1A1A1A"))  // 店名使用 #1A1A1A
                    .lineLimit(1)

                Spacer(minLength: 0)

                // 小红书红打卡勋章
                checkInBadge
            }

            // 第二行：距离 / 区域 / 品类 / 价格
            metadataRow

            // 第三行：评分星星 + 标签（始终显示）
            ratingAndTagsRow
                .padding(.top, 2)

            // 第四行：评论（始终显示）
            if !restaurant.review.isEmpty {
                reviewRow
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
            // 评分星星
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(restaurant.rating) ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundColor(index < Int(restaurant.rating) ? AppTheme.Colors.secondary : Color.gray.opacity(0.3))
                }
            }
            
            // 标签（最多显示2个）
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
    
    // MARK: - 打卡勋章（胶囊样式）
    @State private var isPressed = false
    
    private var checkInBadge: some View {
        Button(action: { onCheckInTap?() }) {
            HStack(spacing: 4) {
                // 打钩图标 - 增大尺寸
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)
                
                // 打卡次数 - 增大尺寸
                if restaurant.checkInCount > 0 {
                    Text("\(restaurant.checkInCount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white)
            )
            // 轻量白色阴影
            .shadow(color: Color.white.opacity(0.8), radius: 3, x: 0, y: 1)
            // 灵动的缩放动效
            .scaleEffect(isPressed ? 0.92 : 1.0)
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
