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
    
    // 筛选状态
    @State private var selectedCuisine: String? = nil
    @State private var selectedDistrict: String? = nil
    @State private var activeSort: SortOption = .default
    @State private var activeFilterType: FilterType? = nil
    
    // 动画与位置捕获
    @State private var showMenuContent = false
    @State private var buttonFrames: [FilterType: CGRect] = [:]
    @Namespace private var menuNamespace
    @StateObject private var locationManager = LocationManager.shared

    // MARK: - 过滤逻辑
    private var filteredAndSortedRestaurants: [Restaurant] {
        var filtered = restaurants.filter { restaurant in
            if searchText.isEmpty { return true }
            let s = searchText.lowercased()
            return restaurant.name.lowercased().contains(s) ||
                   restaurant.type.lowercased().contains(s) ||
                   restaurant.address.lowercased().contains(s)
        }
        if let c = selectedCuisine { filtered = filtered.filter { $0.type == c } }
        if let d = selectedDistrict { filtered = filtered.filter { $0.district == d } }
        
        return filtered.sorted { lhs, rhs in
            switch activeSort {
            case .rating: return lhs.rating > rhs.rating
            case .distance:
                guard let userLoc = locationManager.userLocation else { return true }
                let lLoc = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
                let rLoc = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
                return userLoc.distance(from: lLoc) < userLoc.distance(from: rLoc)
            case .name: return lhs.name < rhs.name
            default: return true
            }
        }
    }

    var body: some View {
        NavigationStack {
            // ✅ 使用 topLeading，这是所有像素级对齐的基准
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    headerSection
                    searchBarSection
                    filterBarSection
                    listSection
                }
                .background(AppTheme.Colors.background)
                
                // 1. 沉浸式蒙层
                if activeFilterType != nil {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .onTapGesture { closeMenu() }
                        .zIndex(90)
                }
                
                // 2. 核心：自展开内嵌胶囊菜单
                if let type = activeFilterType, let rect = buttonFrames[type] {
                    expandedMenuOverlay(for: type, at: rect)
                        .zIndex(100)
                }
            }
            .coordinateSpace(name: "LibraryBase")
            .onPreferenceChange(FilterPositionKey.self) { value in
                if self.buttonFrames != value { self.buttonFrames = value }
            }
            .sheet(isPresented: $showImportSheet) { ImportDataView() }
        }
    }
    
    // MARK: - 顶部 Header (图标颜色锁定)
    private var headerSection: some View {
        HStack {
            Text("餐厅库").font(AppTheme.Fonts.largeTitle).foregroundColor(AppTheme.Colors.textPrimary)
            Spacer()
            Button { showImportSheet = true } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .font(AppTheme.Fonts.title3)
            .foregroundColor(AppTheme.Colors.textPrimary) // ✅ 确保是黑色
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.card)
    }

    // MARK: - 搜索栏
    private var searchBarSection: some View {
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchFocused)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    // MARK: - 筛选按钮栏 (带重置按钮)
    private var filterBarSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach([FilterType.cuisine, .district, .sort], id: \.self) { type in
                    filterCapsule(type: type)
                }
                if selectedCuisine != nil || selectedDistrict != nil || activeSort != .default {
                    Button { closeMenu(); withAnimation { selectedCuisine = nil; selectedDistrict = nil; activeSort = .default }} label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
        }
    }

    // MARK: - 列表展示区
    private var listSection: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.lg) {
                ForEach(filteredAndSortedRestaurants) { restaurant in
                    RestaurantCard(restaurant: restaurant, locationManager: locationManager)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }
            }
            .padding(.bottom, 160)
            .animation(.spring(), value: filteredAndSortedRestaurants)
        }
    }

    // MARK: - 胶囊组件 (Source)
    @ViewBuilder
    private func filterCapsule(type: FilterType) -> some View {
        let isOpening = activeFilterType == type
        let isSelected = checkIsSelected(type: type)
        let title = getCapsuleTitle(for: type)
        
        Text(title)
            .font(AppTheme.Fonts.caption)
            .fontWeight(isSelected || isOpening ? .bold : .medium)
            .padding(.horizontal, 18).padding(.vertical, 10)
            .foregroundColor(isSelected || isOpening ? .white : AppTheme.Colors.textPrimary)
            .background(
                ZStack {
                    if activeFilterType != type {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.circle)
                            .fill(isSelected || isOpening ? AppTheme.Colors.accent : AppTheme.Colors.card)
                            // ✅ 关键 A：几何匹配锁定 anchor
                            .matchedGeometryEffect(id: "BG\(type)", in: menuNamespace, anchor: .topLeading, isSource: true)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                }
            )
            .scaleEffect(isOpening ? 1.1 : 1.0)
            .opacity(isOpening ? 0 : 1)
            .background(
                GeometryReader { geo in
                    let frame = geo.frame(in: .named("LibraryBase"))
                    Color.clear.preference(key: FilterPositionKey.self, value: [type: frame])
                }
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                    activeFilterType = type
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeIn(duration: 0.15)) { showMenuContent = true }
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
    }

    // MARK: - 沉浸式二级菜单 (同心圆吻合版)
    @ViewBuilder
    private func expandedMenuOverlay(for type: FilterType, at rect: CGRect) -> some View {
        let items = getItems(for: type)
        let menuWidth: CGFloat = 240
        let spacing: CGFloat = 10
        let menuHeight = CGFloat(items.count * 48 + 72)
        
        let isLeaningRight = rect.midX > UIScreen.main.bounds.width / 2
        let targetX = isLeaningRight ? rect.maxX - menuWidth : rect.minX
        
        VStack(alignment: .leading, spacing: 0) {
            if showMenuContent {
                // 1. 顶部内嵌胶囊 (Radius = 22)
                HStack {
                    Text(getCapsuleTitle(for: type))
                        .font(AppTheme.Fonts.body).bold()
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .padding(.horizontal, spacing)
                .padding(.top, spacing) // ✅ 确保留白是 10
                .padding(.bottom, 8)
                .transition(.opacity)
                
                // 2. 选项内容
                VStack(spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        Button { handleSelection(item, for: type) } label: {
                            HStack {
                                Text(item).font(AppTheme.Fonts.body)
                                Spacer(); if isItemSelected(item, for: type) { Image(systemName: "checkmark").bold().foregroundColor(AppTheme.Colors.accent) }
                            }
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(.vertical, 12).padding(.horizontal, 20)
                            .background(Color.white)
                        }.buttonStyle(.plain)
                        Divider().opacity(0.08).padding(.horizontal)
                    }
                }.transition(.opacity)
            }
        }
        .frame(width: menuWidth, height: menuHeight, alignment: .top) // ✅ 强制置顶，解决居中留白问题
        .background(
            // 3. 外层容器 (Radius = 22 + 10 = 32)
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                // ✅ 关键 B：几何匹配锁定起点
                .matchedGeometryEffect(id: "BG\(type)", in: menuNamespace, anchor: .topLeading, isSource: false)
                .shadow(color: Color.black.opacity(0.12), radius: 30, x: 0, y: 15)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        // ✅ 核心 C：坐标锚定，实现原地爆炸式展开
        .position(x: targetX + menuWidth/2, y: rect.minY + menuHeight/2)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.2, anchor: isLeaningRight ? .topTrailing : .topLeading).combined(with: .opacity),
            removal: .scale(scale: 0.2, anchor: isLeaningRight ? .topTrailing : .topLeading).combined(with: .opacity)
        ))
    }

    // MARK: - 逻辑方法
    private func closeMenu() {
        showMenuContent = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { activeFilterType = nil }
    }
    private func handleSelection(_ item: String, for type: FilterType) {
        withAnimation {
            switch type {
            case .cuisine: selectedCuisine = (selectedCuisine == item) ? nil : item
            case .district: selectedDistrict = (selectedDistrict == item) ? nil : item
            case .sort: activeSort = SortOption(rawValue: item) ?? .default
            }
        }
        closeMenu()
    }
    private func getCapsuleTitle(for type: FilterType) -> String {
        switch type {
        case .cuisine: return selectedCuisine ?? "菜系"
        case .district: return selectedDistrict ?? "全城"
        case .sort: return activeSort.title
        }
    }
    private func checkIsSelected(type: FilterType) -> Bool {
        switch type {
        case .cuisine: return selectedCuisine != nil
        case .district: return selectedDistrict != nil
        case .sort: return activeSort != .default
        }
    }
    private func isItemSelected(_ item: String, for type: FilterType) -> Bool {
        switch type {
        case .cuisine: return selectedCuisine == item
        case .district: return selectedDistrict == item
        case .sort: return activeSort.title == item
        }
    }
    private func getItems(for type: FilterType) -> [String] {
        switch type {
        case .cuisine: return ["火锅", "烧烤", "西餐", "快餐", "日料", "甜品"]
        case .district: return ["渝中", "江北", "渝北", "南岸", "沙坪坝", "九龙坡"]
        case .sort: return SortOption.allCases.map { $0.title }
        }
    }
}

// MARK: - 餐厅卡片组件 (恢复大卡片 100x100 比例)
struct RestaurantCard: View {
    @Environment(\.modelContext) private var modelContext
    let restaurant: Restaurant
    @ObservedObject var locationManager: LocationManager
    @State private var showDeleteAlert = false
    var body: some View {
        NavigationLink(destination: RestaurantDetailView(restaurant: restaurant, locationManager: locationManager)) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                // 封面图锁定 100x100
                Group {
                    if let filename = restaurant.coverPhotoFilename, let image = ImageManager.shared.loadImage(filename: filename) { Image(uiImage: image).resizable().scaledToFill() }
                    else { ZStack { AppTheme.Colors.primary.opacity(0.1); Image(systemName: "fork.knife.circle.fill").font(.system(size: 40)).foregroundColor(AppTheme.Colors.primary.opacity(0.3)) } }
                }.frame(width: 100, height: 100).cornerRadius(12).clipped()
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(restaurant.name).font(AppTheme.Fonts.title3).bold().lineLimit(1).foregroundColor(AppTheme.Colors.textPrimary)
                        Spacer(); Button { showDeleteAlert = true } label: { Image(systemName: "trash").font(.caption).foregroundColor(.gray.opacity(0.4)) }
                    }
                    HStack(spacing: 6) {
                        TagView(text: restaurant.type, color: AppTheme.Colors.primary)
                        TagView(text: "⭐️ \(restaurant.rating)", color: AppTheme.Colors.secondary)
                        TagView(text: restaurant.district, color: AppTheme.Colors.success)
                    }
                    HStack(spacing: 12) {
                        if restaurant.averagePrice > 0 { Text("¥\(Int(restaurant.averagePrice))/人").font(AppTheme.Fonts.headline).foregroundColor(AppTheme.Colors.accent).bold() }
                        HStack(spacing: 2) { Image(systemName: "location.fill").font(.system(size: 10)); Text(locationManager.distanceTo(lat: restaurant.latitude, long: restaurant.longitude)) }.font(AppTheme.Fonts.caption).foregroundColor(.gray)
                    }
                    if !restaurant.review.isEmpty {
                        Text(restaurant.review).font(AppTheme.Fonts.caption).foregroundColor(.secondary).lineLimit(1).padding(.horizontal, 8).padding(.vertical, 4).background(AppTheme.Colors.background).cornerRadius(6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading) // ✅ 确保占据剩余全部空间，解决卡片缩水
            }
            .padding(AppTheme.Spacing.card).background(AppTheme.Colors.card).cornerRadius(AppTheme.Radius.base).shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }.buttonStyle(.plain)
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
enum FilterType: Equatable { case cuisine, district, sort }
enum SortOption: String, CaseIterable {
    case `default` = "排序", rating = "按评分", distance = "按距离", name = "按名称"
    var title: String { self.rawValue }
}
struct FilterPositionKey: PreferenceKey {
    static var defaultValue: [FilterType: CGRect] = [:]
    static func reduce(value: inout [FilterType: CGRect], nextValue: () -> [FilterType: CGRect]) { value.merge(nextValue()) { $1 } }
}
