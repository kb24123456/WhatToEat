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
    
    // 获取星级视图
    private var ratingView: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 16)) // 星星图标放大到16pt
                .foregroundColor(AppTheme.Colors.secondary)
                .symbolRenderingMode(.hierarchical) // 增加层次感
            Text("\(restaurant.rating)")
                .font(AppTheme.Fonts.callout)
                .foregroundColor(AppTheme.Colors.secondary)
                .bold()
        }
    }
    
    var body: some View {
        Group {
            // 守卫判断：只有对象上下文合法时才访问其属性
            if restaurant.modelContext != nil {
                
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    // 封面图：使用 AsyncImageView 实现异步加载和预解码，添加拍立得悬浮效果
                    ZStack {
                        AsyncImageView(
                            filename: restaurant.coverPhotoFilename,
                            placeholder: AnyView(
                                ZStack {
                                    AppTheme.Colors.primary.opacity(0.1)
                                    Image(systemName: "fork.knife.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.primary.opacity(0.3)) 
                                        .symbolRenderingMode(.hierarchical) // 增加层次感
                                }
                            )
                        )
                        .frame(width: AppTheme.Cards.restaurantCoverWidth, height: AppTheme.Cards.restaurantCoverHeight)
                        .cornerRadius(AppTheme.Radius.image) // 封面图圆角与卡片基座圆角一致
                        .clipped() // 确保内容不溢出容器
                        // 极淡的内部阴影
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.image)
                                .fill(LinearGradient(
                                    colors: [Color.black.opacity(0.05), Color.clear, Color.clear, Color.black.opacity(0.03)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                        )
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.image).stroke(Color.white.opacity(0.8), lineWidth: 1.2)) // 白色描边线宽降为1.2pt
                        
                        // 物理胶带效果
                        Rectangle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 35, height: 10)
                            .rotationEffect(.degrees(-15))
                            .offset(x: -25, y: -18) // 位置调整到图片顶部左侧
                            .blur(radius: 0.5)
                            .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1) // 极淡阴影，模拟厚度
                    }
                    .scaleEffect(1.02) // 微量放大
                    .rotationEffect(.degrees(-1.5)) // 2D微旋，符合手账贴纸逻辑
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 4, y: 6) // 增加阴影浓度和半径，制造更强的物理悬浮感
                    
                    // 右侧内容列：高度与封面图一致，垂直居中对齐
                    ZStack(alignment: .topTrailing) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 第一行 - 餐厅名称
                            Text(restaurant.name)
                                .font(AppTheme.Fonts.title3)
                                .bold()
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            
                            // 标题与内容的呼吸感间距：14pt，增加呼吸感
                            Color.clear.frame(height: 14)
                            
                            // 第二行 - 元信息：人均消费、地区、距离
                            HStack(spacing: AppTheme.Spacing.md) {
                                Text(priceText)
                                    .font(AppTheme.Fonts.subheadline)
                                    .foregroundColor(AppTheme.Colors.price)
                                
                                Text(restaurant.district)
                                    .font(AppTheme.Fonts.subheadline)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                
                                // 距离显示（如果有定位）
                                if let userLocation = locationManager.userLocation {
                                    Text(distanceText(from: userLocation, to: restaurant))
                                        .font(AppTheme.Fonts.subheadline)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .lineLimit(1)
                                } else {
                                    Text("未定位")
                                        .font(AppTheme.Fonts.subheadline)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            // 压印效果：半透明背景 + 内部描边
                            .background(AppTheme.Colors.lightGray.opacity(0.2)) // 背景透明度降到0.2
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                                    .inset(by: 0.5) // 内部描边，深嵌效果
                                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                            )
                            .cornerRadius(AppTheme.Radius.base)
                            
                            // 标准行间距：8pt
                            Color.clear.frame(height: 8)
                            
                            // 第三行 - 属性：星级、品类、标签
                            HStack(spacing: AppTheme.Spacing.sm) {
                                // 星级
                                ratingView
                                
                                // 品类
                                Text(restaurant.type)
                                    .font(AppTheme.Fonts.callout)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                
                                // 标签：只显示前两个，使用小胶囊样式，高度与品类文本一致
                                ForEach(restaurant.tags.prefix(2), id: \.self) {
                                    Text($0)
                                        .font(AppTheme.Fonts.callout)
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .padding(.horizontal, 8) // 调整水平内边距
                                        .padding(.vertical, 2) // 减少垂直内边距，与品类文本高度一致
                                        .background(AppTheme.Colors.primary.opacity(0.1))
                                        .cornerRadius(AppTheme.Radius.circle)
                                }
                            }
                            
                            // 标准行间距：8pt
                            Color.clear.frame(height: 8)
                            
                            // 第四行 - 评论便签区
                            if !restaurant.review.isEmpty {
                                HStack(spacing: 8) {
                                    // 红色装饰条：高度跟随文字行高自动撑开，墨水晕染/高级丝带效果
                                    Rectangle()
                                        .fill(AppTheme.Colors.accent) // 使用单一颜色，不使用渐变
                                        .frame(width: 1.5) // 宽度设为1.5pt
                                        .cornerRadius(1)
                                        // 微弱外发光效果，营造墨水晕染感
                                        .shadow(color: AppTheme.Colors.accent.opacity(0.2), radius: 1.5, x: 0, y: 0)
                                    
                                    // 评论内容
                                    Text("“ \(restaurant.review) ”")
                                        .font(AppTheme.Fonts.callout)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .lineLimit(1)
                                        .multilineTextAlignment(.leading)
                                        .fontWeight(.medium)
                                        .tracking(0.5) // 字间距0.5，增强书法感
                                }
                                .padding(.horizontal, 12) // 水平内边距保持12pt
                                .padding(.vertical, 8) // 垂直内边距增加到8pt
                                .background(AppTheme.Colors.lightGray.opacity(0.5)) // 背景色调整为0.5透明度
                                .cornerRadius(AppTheme.Radius.base)
                                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2) // 增加独立投影
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(height: AppTheme.Cards.restaurantCoverHeight, alignment: .center) // 固定高度，垂直居中对齐
                        
                        // 右侧打卡组件：圆形玻璃态勋章，中心高度与餐厅名称对齐
                        VStack(alignment: .center, spacing: 1) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 18)) // 红心图标大小
                                .foregroundColor(Color(hex: "#FF6B6B")) // 更有活力的珊瑚红
                                .symbolRenderingMode(.multicolor) // 开启多彩渲染模式，增加光泽
                            Text("\(restaurant.checkInCount)")
                                .font(AppTheme.Fonts.caption) // 数字字号微缩
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .frame(width: 38, height: 38) // 圆形勋章大小：38x38
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.5))
                                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                        )
                        .scaleEffect(1.05) // 动态缩放，使其更突出
                        .onTapGesture {
                            showCheckInSheet = true
                        }
                    }
                }
                .contentShape(Rectangle()) // 👈 确保全卡片可点
                .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16))
                .background(
                    LinearGradient(colors: [.white, Color(hex: "#F9F7F5")], startPoint: .topLeading, endPoint: .bottomTrailing) // 极微弱斜向渐变，模拟纸张自然光感
                )
                .overlay(
                    Group {
                        // 内部白边，模拟厚纸片切线
                        RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                            .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                        // 手工切边效果
                        RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                            .stroke(Color.black.opacity(0.015), lineWidth: 1)
                    }
                )
                // 复合阴影系统
                .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10) // 底层软投影
                .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 2) // 顶层环境光
                .cornerRadius(AppTheme.Radius.base) // 卡片基座圆角
            } else {
                EmptyView()
            }
        }
    }
}