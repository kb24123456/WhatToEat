import SwiftUI
import MapKit
import SwiftData

struct RestaurantCard: View {
    let restaurant: Restaurant
    @ObservedObject var locationManager: LocationManager
    @State private var showCheckInSheet = false
    
    // 计算距离文本
    private func distanceText(from: CLLocation, to restaurant: Restaurant) -> String {
        let distance = from.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    // 获取消费数据文本
    private var priceText: String {
        if restaurant.averagePrice > 0 {
            return "¥\(Int(restaurant.averagePrice))/人"
        } else {
            return "暂无消费数据"
        }
    }
    
    // 获取星级文本
    private var ratingText: String {
        return "⭐️\(restaurant.rating)"
    }
    
    var body: some View {
        Group {
            // 守卫判断：只有对象上下文合法时才访问其属性
            if restaurant.modelContext != nil {
                
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    // 封面图：使用 AsyncImageView 实现异步加载和预解码
                    AsyncImageView(
                        filename: restaurant.coverPhotoFilename,
                        placeholder: AnyView(
                            ZStack {
                                AppTheme.Colors.primary.opacity(0.1)
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.Colors.primary.opacity(0.3)) 
                            }
                        )
                    )
                    .frame(width: AppTheme.Cards.restaurantCoverWidth, height: AppTheme.Cards.restaurantCoverHeight)
                    .cornerRadius(AppTheme.Radius.image) // 封面图圆角与卡片基座圆角一致
                    .clipped() // 确保内容不溢出容器
                    
                    // 右侧内容列：高度与封面图一致，添加右侧内边距
                    VStack(alignment: .leading, spacing: 0) {
                        // MARK: 顶部组合行 - 餐厅名称、元信息、打卡组件
                        HStack(alignment: .top, spacing: 0) {
                            // 左侧 VStack：餐厅名称 + 元信息
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                // 第一行 - 餐厅名称
                                Text(restaurant.name)
                                    .font(AppTheme.Fonts.headline)
                                    .bold()
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                
                                // 第二行 - 元信息：人均消费、地区、距离
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    Text(priceText)
                                        .font(AppTheme.Fonts.footnote)
                                        .foregroundColor(AppTheme.Colors.price)
                                    
                                    // 小圆点分隔符
                                    Circle()
                                        .frame(width: 3, height: 3)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    Text(restaurant.district)
                                        .font(AppTheme.Fonts.footnote)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    // 小圆点分隔符
                                    Circle()
                                        .frame(width: 3, height: 3)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    
                                    // 距离显示（如果有定位）
                                    if let userLocation = locationManager.userLocation {
                                        Text(distanceText(from: userLocation, to: restaurant))
                                            .font(AppTheme.Fonts.footnote)
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    } else {
                                        Text("未定位")
                                        .font(AppTheme.Fonts.footnote)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // 右侧打卡组件
                            VStack(alignment: .center, spacing: 2) {
                                Image(systemName: "heart")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppTheme.Colors.secondary)
                                Text("\(restaurant.checkInCount)")
                                    .font(AppTheme.Fonts.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .onTapGesture {
                                showCheckInSheet = true
                            }
                        }
                        
                        // 第三行 - 属性：星级、品类、标签
                        HStack(spacing: AppTheme.Spacing.sm) {
                            // 星级
                            Text(ratingText)
                                .font(AppTheme.Fonts.subheadline)
                                .foregroundColor(AppTheme.Colors.secondary)
                                .bold()
                            
                            // 品类
                            Text(restaurant.type)
                                .font(AppTheme.Fonts.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            // 标签：只显示前两个，使用小胶囊样式
                            ForEach(restaurant.tags.prefix(2), id: \.self) {
                                Text($0)
                                    .font(AppTheme.Fonts.caption)
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .padding(.horizontal, AppTheme.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.Colors.primary.opacity(0.1))
                                    .cornerRadius(AppTheme.Radius.circle)
                            }
                        }
                        .padding(.top, AppTheme.Spacing.sm)
                        
                        // 弹性占位符：将评论区域推到容器底部
                        Spacer(minLength: 0)
                        
                        // MARK: 底部组 - 评论容器
                        if !restaurant.review.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\"\(restaurant.review)\"")
                                    .font(AppTheme.Fonts.footnote)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, AppTheme.Spacing.md)
                                    .padding(.vertical, AppTheme.Spacing.sm)
                                    .background(AppTheme.Colors.lightGray)
                                    .cornerRadius(AppTheme.Radius.base)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(height: AppTheme.Cards.restaurantCoverHeight) // 确保右侧高度与左侧封面图一致
                }
                .contentShape(Rectangle()) // 👈 确保全卡片可点
                .background(AppTheme.Colors.card)
                .cornerRadius(AppTheme.Radius.base) // 卡片基座圆角
                .clipped() // 确保内容不溢出容器，保持圆角效果
            } else {
                EmptyView()
            }
        }
    }
}