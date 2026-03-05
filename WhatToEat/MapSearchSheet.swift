import SwiftUI
import SwiftData

// MARK: - 地图搜索 Sheet
/// 用于地图视图的餐厅搜索，支持模糊搜索
struct MapSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // 所有餐厅数据
    let restaurants: [Restaurant]
    
    // 搜索回调
    var onSelectRestaurant: ((Restaurant) -> Void)?
    
    @State private var searchQuery = ""
    @State private var searchResults: [Restaurant] = []
    
    // 防抖计时器
    @State private var debounceTimer: Timer?

    private var sheetBackground: Color {
        colorScheme == .dark ? Color.fixedHex("#111A28") : AppTheme.Colors.milkyBase
    }

    private var inputBackground: Color {
        colorScheme == .dark ? AppTheme.Colors.inputFieldBackground : Color.fixedHex("#FFFFFF")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? AppTheme.Colors.surfacePrimary : Color.fixedHex("#FFFFFF")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                sheetBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 搜索栏
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    // 结果列表
                    resultsList
                }
            }
            .navigationTitle("搜索餐厅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.darkText)
                }
            }
        }
        .onAppear {
            // 初始显示所有餐厅
            searchResults = restaurants
        }
        .onDisappear {
            debounceTimer?.invalidate()
            debounceTimer = nil
        }
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            TextField("搜索餐厅名称、类型、区域...", text: $searchQuery)
                .font(.body)
                .foregroundColor(AppTheme.Colors.darkText)
                .submitLabel(.search)
                .onChange(of: searchQuery) { _, newValue in
                    // 防抖搜索
                    debounceTimer?.invalidate()
                    debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        performSearch(query: newValue)
                    }
                }
            
            // 液体融合清除按钮
            if !searchQuery.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchQuery = ""
                        searchResults = restaurants
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .background(
                            Circle()
                                .fill(inputBackground)
                        )
                }
                .buttonStyle(LiquidFusionButtonStyle())
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(inputBackground)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.04), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - 结果列表
    private var resultsList: some View {
        List {
            if searchResults.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("未找到匹配的餐厅")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 60)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            } else {
                Section {
                    ForEach(searchResults) { restaurant in
                        restaurantRow(restaurant)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                } header: {
                        Text("共 \(searchResults.count) 家餐厅")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.mediumGray)
                            .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
    }
    
    // MARK: - 餐厅行
    private func restaurantRow(_ restaurant: Restaurant) -> some View {
        Button {
            onSelectRestaurant?(restaurant)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // 封面图
                if let filename = restaurant.coverPhotoFilename {
                    AsyncImageView(filename: filename)
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.softBackground)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        )
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(restaurant.type)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                        
                        Text("·")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                        
                        Text(restaurant.district)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                    }
                    
                    if restaurant.averagePrice > 0 {
                        Text("¥\(Int(restaurant.averagePrice))/人")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.babyBlue)
                    }
                }
                
                Spacer()
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.lightText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.03), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 执行搜索
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = restaurants
            return
        }
        
        let searchLower = query.lowercased()
        
        searchResults = restaurants.filter { r in
            // 名称匹配（支持拼音）
            let nameMatch = r.name.localizedCaseInsensitiveContains(query) ||
                           r.name.pinyinContains(searchLower)
            
            // 类型匹配
            let typeMatch = r.type.localizedCaseInsensitiveContains(query) ||
                           r.type.pinyinContains(searchLower)
            
            // 区域匹配
            let districtMatch = r.district.localizedCaseInsensitiveContains(query) ||
                               r.district.pinyinContains(searchLower)
            
            // 地址匹配
            let addressMatch = r.address.localizedCaseInsensitiveContains(query) ||
                              r.address.pinyinContains(searchLower)
            
            return nameMatch || typeMatch || districtMatch || addressMatch
        }
        
        // 按匹配度排序
        searchResults.sort { r1, r2 in
            let score1 = calculateMatchScore(restaurant: r1, query: searchLower)
            let score2 = calculateMatchScore(restaurant: r2, query: searchLower)
            return score1 > score2
        }
    }
    
    // MARK: - 计算匹配分数
    private func calculateMatchScore(restaurant: Restaurant, query: String) -> Int {
        var score = 0
        let nameLower = restaurant.name.lowercased()
        
        // 完全匹配分数最高
        if nameLower == query {
            score += 100
        }
        // 开头匹配
        else if nameLower.hasPrefix(query) {
            score += 80
        }
        // 包含匹配
        else if nameLower.contains(query) {
            score += 60
        }
        // 拼音匹配
        else if restaurant.name.pinyinContains(query) {
            score += 40
        }
        
        return score
    }
}

// MARK: - 液体融合按钮样式
struct LiquidFusionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - 预览
#Preview {
    MapSearchSheet(restaurants: [])
}
