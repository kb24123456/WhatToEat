import SwiftUI
import SwiftData
import CoreLocation

// MARK: - 心动匹配游戏视图 (简化版 - 仅筛选器和食签)
struct GourmetMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @ObservedObject var locationManager: LocationManager = LocationManager.shared
    
    // 筛选状态
    @State private var selectedDistrict: String = "全部"
    @State private var selectedType: String = "全部"
    
    // 食签显示状态
    @State private var showImmersiveFortune = false
    
    // 地区和分类数据
    private let districts = ["全部", "渝中区", "江北区", "南岸区", "九龙坡区", "沙坪坝区", "渝北区", "巴南区"]
    private let types = ["全部", "火锅", "小面", "烧烤", "川菜", "日料", "西餐", "咖啡", "甜品"]
    
    var body: some View {
        ZStack {
            // 背景
            AppTheme.Colors.pageBackground
                .ignoresSafeArea()
            
            // MARK: 顶部筛选器
            VStack {
                filterBar
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                
                Spacer()
            }
            
            // MARK: 食签视图
            immersiveFortuneButton
        }
        .overlay {
            // 食签卡片视图
            if showImmersiveFortune {
                ZStack {
                    // 背景模糊层
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showImmersiveFortune = false
                            }
                        }
                    
                    // 食签卡片内容
                    FortuneCardModalView(onClose: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showImmersiveFortune = false
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                        removal: .opacity.combined(with: .scale(scale: 1.1))
                    ))
                }
            }
        }
    }
    
    // MARK: - 顶部筛选器
    private var filterBar: some View {
        HStack(spacing: 12) {
            // 1. 地区筛选
            Menu {
                Button("全区") { selectedDistrict = "全部" }
                Divider()
                ForEach(districts.filter { $0 != "全部" }, id: \.self) { district in
                    Button(district) { selectedDistrict = district }
                }
            } label: {
                filterCapsuleLabel(
                    title: selectedDistrict == "全部" ? "地区" : selectedDistrict,
                    isSelected: selectedDistrict != "全部"
                )
            }
            
            // 2. 分类筛选
            Menu {
                Button("全部分类") { selectedType = "全部" }
                Divider()
                ForEach(types.filter { $0 != "全部" }, id: \.self) { type in
                    Button(type) { selectedType = type }
                }
            } label: {
                filterCapsuleLabel(
                    title: selectedType == "全部" ? "品类" : selectedType,
                    isSelected: selectedType != "全部"
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: - 沉浸式食签按钮
    private var immersiveFortuneButton: some View {
        VStack {
            Spacer()
            
            Button(action: {
                // 触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                showImmersiveFortune = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                    Text("今日食签")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.glass)
            .controlSize(.regular)
            
            Spacer()
                .frame(height: 100)
        }
    }
    
    // MARK: - 筛选胶囊标签
    private func filterCapsuleLabel(title: String, isSelected: Bool) -> some View {
        let displayTitle = title.count > 4 ? String(title.prefix(3)) + "…" : title
        
        return HStack(spacing: 4) {
            Text(displayTitle)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color.primary)
                .frame(width: 52, height: 18, alignment: .center)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? Color.black : Color.white)
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 6,
            x: 0,
            y: 3
        )
    }
}

// MARK: - 预览
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    
    GourmetMatchView()
        .modelContainer(container)
}
