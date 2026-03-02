//
//  ContentView.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/17.
//

import SwiftUI
import SwiftData

// MARK: - Tab项枚举 (保留在这里作为导航定义)
enum TabItem: String, CaseIterable {
    case library = "食库"
    case home = "吃啥"
    case add = ""
    case friends = "食图"
    case profile = "我的"
    
    var iconName: String {
        switch self {
        case .library: return "pointer.arrow.ipad.square"
        case .home: return "lasso.badge.sparkles"
        case .add: return "plus"
        case .friends: return "pencil.and.scribble"
        case .profile: return "person.crop.circle"
        }
    }
}

// MARK: - 主视图
struct ContentView: View {
    @State private var selectedTab: TabItem = .library
    @Namespace private var animationNamespace
    @State private var isAdding: Bool = false
    @State private var isTabBarHidden: Bool = false
    
    // 从数据库查询所有餐厅数据，供子视图使用
    @Query private var restaurants: [Restaurant]
    
    // 缓存餐厅数据，避免频繁重建
    @State private var cachedRestaurants: [Restaurant] = []
    @State private var lastRestaurantCount: Int = 0
    @State private var lastRestaurantUpdate: Date = Date.distantPast
    
    // MARK: - 输入代理管理器
    @StateObject private var inputProxyManager = InputProxyManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景层：奶白背景铺满整个屏幕（包括安全区域）
            AppTheme.Colors.milkWhite
                .ignoresSafeArea()
            
            // MARK: - 主内容区域（性能冻结保护）
            Group {
                switch selectedTab {
                case .library:
                    LibraryView()
                case .home:
                    // 新的餐厅卡片流视图 - 使用 matchedGeometryEffect 实现无缝转场
                    RestaurantFlowView()
                case .add:
                    EmptyView()
                case .friends:
                    // 将缓存的餐厅数据传入地图视图
                    RestaurantMapView(restaurants: cachedRestaurants)
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 性能冻结：当代理激活时冻结底层渲染
            .performanceFreeze()
            .sheet(isPresented: $isAdding) {
                AddRestaurantView(onClose: {
                    withAnimation {
                        isAdding = false
                    }
                })
                .presentationDetents([.large])
                .presentationBackground(.white)
            }
            
            // 导航条放置在安全区域内，紧贴底部
            if !isTabBarHidden {
                customTabBar
            }
            
            // MARK: - 键盘吸附栏（全局输入代理）
            AccessoryInputView()
                .zIndex(100)  // 确保在最上层
        }
        // 忽略键盘安全区域
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .hideTabBar)) { _ in
            withAnimation {
                isTabBarHidden = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .restoreTabBar)) { _ in
            withAnimation {
                isTabBarHidden = false
            }
        }
        .onChange(of: restaurants) { _, newRestaurants in
            // 只有当餐厅数量变化或超过5秒未更新时才刷新缓存
            let shouldUpdate = newRestaurants.count != lastRestaurantCount ||
                              Date().timeIntervalSince(lastRestaurantUpdate) > 5.0
            
            if shouldUpdate {
                cachedRestaurants = newRestaurants
                lastRestaurantCount = newRestaurants.count
                lastRestaurantUpdate = Date()
            }
        }
        .onAppear {
            // 初始化缓存
            cachedRestaurants = restaurants
            lastRestaurantCount = restaurants.count
            lastRestaurantUpdate = Date()
        }
    }
    
    // 自定义导航栏组件 - 胶囊样式 + 玻璃质感 + 边框高亮与轻量阴影
    // 使用 safeAreaInset 嵌入，紧贴安全区域底部
    private var customTabBar: some View {
        HStack(spacing: 0) {
            // 1. 食库按钮
            tabButton(
                tab: .library,
                icon: TabItem.library.iconName,
                title: TabItem.library.rawValue
            )
            
            // 2. 吃啥按钮
            tabButton(
                tab: .home,
                icon: TabItem.home.iconName,
                title: TabItem.home.rawValue
            )
            
            // 3. 中间加号按钮
            Button {
                withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.7, blendDuration: 0.2)) {
                    isAdding = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 44, height: 44)

                    Image(systemName: TabItem.add.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .oreoClickEffect(style: .medium)
            
            // 4. 食记按钮
            tabButton(
                tab: .friends,
                icon: TabItem.friends.iconName,
                title: TabItem.friends.rawValue
            )
            
            // 5. 我的按钮
            tabButton(
                tab: .profile,
                icon: TabItem.profile.iconName,
                title: TabItem.profile.rawValue
            )
        }
        .frame(height: 64)
        // 增强玻璃质感：多层材质叠加 + 渐变边框 + 柔和阴影
        .background(
            ZStack {
                // 底层：模糊材质
                Capsule()
                    .fill(.ultraThinMaterial)
                
                // 中层：半透明白色增强玻璃感
                Capsule()
                    .fill(Color.white.opacity(0.15))
            }
        )
        // 多层边框营造玻璃边缘光感
        .overlay(
            ZStack {
                // 外层：柔和白色光晕
                Capsule()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                
                // 内层：更亮的边缘高光
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                    .padding(0.5)
            }
        )
        // 柔和多层阴影营造悬浮感
        .shadow(color: Color.black.opacity(0.06), radius: 24, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        // 负值底部间距，让胶囊下边缘紧贴系统导航条（Home Indicator）
        .padding(.bottom, -12)
        .zIndex(100)
    }
    
    // MARK: - Tab Button
    private func tabButton(tab: TabItem, icon: String, title: String) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.1)) {
                selectedTab = tab
            }
            // 触感反馈
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .frame(height: 22)
                
                Text(title)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                    .frame(height: 10)
            }
            .foregroundColor(isSelected ? .black : AppTheme.Colors.textSecondary.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: 60)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 辅助组件 (全局通用)

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct PlaceholderView: View {
    let title: String
    let description: String
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "construction")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            Text(title).font(.title).bold()
            Text(description).foregroundColor(.gray).multilineTextAlignment(.center).padding()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    return ContentView().modelContainer(container)
}
