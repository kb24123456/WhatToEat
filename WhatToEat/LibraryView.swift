import SwiftUI
import SwiftData
import MapKit

// MARK: - 1. 核心视图
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    
    // 状态管理
    @State private var searchText = ""
    @State private var showImportSheet = false
    @FocusState private var isSearchFocused: Bool // ✅ 专门监听搜索框是否被点中
    
    @StateObject private var locationManager = LocationManager.shared

    // MARK: - 过滤逻辑
    private var filteredRestaurants: [Restaurant] {
        restaurants.filter { restaurant in
            if searchText.isEmpty { return true }
            let s = searchText.lowercased()
            return restaurant.name.lowercased().contains(s) ||
                   restaurant.type.lowercased().contains(s) ||
                   restaurant.address.lowercased().contains(s)
        }
    }

    var body: some View {
        NavigationStack {
            // ✅ 使用 topLeading，这是所有像素级对齐的基准
            ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
            headerSection
            filterBarSection
            listSection
        }
            .background(AppTheme.Colors.background)
        }
            .sheet(isPresented: $showImportSheet) { ImportDataView() }
        }
    }
    
    // MARK: - 顶部 Header (整合标题、搜索框和地图图标)
    private var headerSection: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // 1. 标题"吃啥呢"
            Text("吃啥呢")
                .font(AppTheme.Fonts.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            // 2. 搜索框（占据剩余空间）
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("搜索餐厅名称、菜系...", text: $searchText)
                    .font(AppTheme.Fonts.body)
                    .focused($isSearchFocused) // ✅ 绑定焦点状态
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.card)
            .cornerRadius(AppTheme.Radius.base)
            // 1. ✅ 动态边框：聚焦时显示“小红书红”，平时显示透明或极浅灰
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(isSearchFocused ? AppTheme.Colors.accent : Color.clear, lineWidth: 1.5)
            )
            // 2. ✅ 动态阴影：聚焦时变深变大，呈现“浮起”感
            .shadow(
                color: isSearchFocused ? AppTheme.Colors.accent.opacity(0.1) : Color.black.opacity(0.04),
                radius: isSearchFocused ? 15 : 8,
                x: 0,
                y: isSearchFocused ? 8 : 2
            )
            // 3. ✅ 动态缩放与动画：带一点点 Q 弹感
            .scaleEffect(isSearchFocused ? 1.02 : 1.0)
            // 使用 matchedGeometryEffect 替代传统动画，提高性能
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2), value: isSearchFocused)
            
            // 3. 地图图标按钮
            Button(action: { 
                // 暂不添加任何功能
            }) {
                Image(systemName: "map")
                    .font(AppTheme.Fonts.title3)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.background)
    }

    // MARK: - 筛选按钮栏
    private var filterBarSection: some View {
        HStack(spacing: 12) {
            ForEach(["地区", "品类", "排序"], id: \.self) { title in
                Button(action: { 
                    // 后续添加筛选逻辑
                }) {
                    Text(title)
                        .font(AppTheme.Fonts.footnote)
                        .fontWeight(.medium)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.base) // 16pt圆角
                                .fill(AppTheme.Colors.card)
                                .shadow(
                                    color: Color.black.opacity(0.05), 
                                    radius: 5, 
                                    x: 0, 
                                    y: 2
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.xs) // 与搜索框的最小间距
        .padding(.bottom, AppTheme.Spacing.md)
    }

    // MARK: - 列表展示区
    private var listSection: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.lg) {
                ForEach(filteredRestaurants, id: \.id) { restaurant in
                    RestaurantCard(restaurant: restaurant, locationManager: locationManager)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }
            }
            .padding(.bottom, 90)
        }
    }


}

// MARK: - 餐厅卡片组件 (自适应尺寸，完美适配所有设备)
struct RestaurantCard: View {
    @Environment(\.modelContext) private var modelContext
    let restaurant: Restaurant
    @ObservedObject var locationManager: LocationManager
    @State private var showDeleteAlert = false
    
    // 使用 AsyncImageView 替代手动图片加载，实现预解码和缓存
    
    var body: some View {
        NavigationLink(destination: RestaurantDetailView(restaurant: restaurant, locationManager: locationManager)) {
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
                .cornerRadius(AppTheme.Radius.image) // 封面图圆角与卡片圆角一致：16pt
                .clipped() // 确保内容不溢出容器
                
                // 信息区域：调整顶部对齐，使餐厅名称与封面图上边缘齐平
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(restaurant.name)
                            .font(AppTheme.Fonts.title3)
                            .bold()
                            .lineLimit(1)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Spacer()
                        Button { showDeleteAlert = true } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.4)) 
                        }
                    }
                    
                    HStack(spacing: 12) {
                        if restaurant.averagePrice > 0 { 
                            Text("¥\(Int(restaurant.averagePrice))/人")
                                .font(AppTheme.Fonts.subheadline)
                                .foregroundColor(AppTheme.Colors.accent)
                                .bold() 
                        }
                        Text(restaurant.district)
                            .font(Font.system(.footnote, design: .rounded))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(locationManager.distanceTo(lat: restaurant.latitude, long: restaurant.longitude))
                        }
                        .font(Font.system(.footnote, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    HStack(spacing: 12) {
                        TagView(text: "⭐️ \(restaurant.rating)", color: AppTheme.Colors.secondary)
                        Text(restaurant.type)
                            .font(AppTheme.Fonts.footnote)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer() // 添加分隔符，将标签推到右侧
                        
                        if !restaurant.tags.isEmpty {
                            // 标签水平排列，使用ScrollView确保在小屏幕上能滚动查看
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Spacing.xs) {
                                    ForEach(restaurant.tags, id: \.self) {
                                        Text("# \($0)")
                                            .font(AppTheme.Fonts.footnote)
                                            .foregroundColor(AppTheme.Colors.primary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.Colors.primary.opacity(0.1))
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !restaurant.review.isEmpty {
                        // 仅保留评论内容，移除评论人名
                        Text("\"\(restaurant.review)\"")
                            .font(Font.system(.footnote, design: .rounded))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2) // 允许两行显示，确保评论完整
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.Colors.lightGray) // 使用AppTheme中定义的浅灰色
                            .cornerRadius(6)
                    }
                }
                .alignmentGuide(.top) { _ in -8 } // 自定义顶部对齐，向上偏移8pt，抵消字体ascent和默认间距
                .frame(maxWidth: .infinity, alignment: .leading) // 确保占据剩余全部空间
                .padding(.vertical, AppTheme.Spacing.sm) // 增加垂直内边距，避免内容紧贴边缘
            }
            .background(AppTheme.Colors.card)
            .cornerRadius(AppTheme.Radius.base)
        }
        .buttonStyle(.plain)
        .alert("确认删除", isPresented: $showDeleteAlert) { 
            Button("删除", role: .destructive) { withAnimation { modelContext.delete(restaurant) } }
            Button("取消", role: .cancel) {}
        } message: { Text("确定要删除吗？") }
    }
}

// MARK: - 辅助结构与定义
struct TagView: View {
    let text: String; let color: Color
    var body: some View { Text(text).font(.system(size: 11, weight: .medium, design: .rounded)).padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.12)).foregroundColor(color).cornerRadius(6) }
}
