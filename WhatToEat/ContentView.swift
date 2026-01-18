//
//  ContentView.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/17.
//

import SwiftUI
import SwiftData

// MARK: - 1. Tab项定义
enum TabItem: String, CaseIterable {
    case library = "餐厅库"
    case home = "首页"
    case profile = "我的"
    
    var iconName: String {
        switch self {
        case .library: return "books.vertical"
        case .home: return "house"
        case .profile: return "person"
        }
    }
}

// MARK: - 2. 主视图
struct ContentView: View {
    @State private var selectedTab: TabItem = .library
    @Namespace private var tabAnimation
    @State private var showAddSheet = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域
            Group {
                switch selectedTab {
                case .library:
                    LibraryView()
                case .home:
                    PlaceholderView(title: "首页", description: "随机抽取功能即将上线")
                case .profile:
                    PlaceholderView(title: "我的", description: "个人设置功能即将上线")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 红色加号按钮
            if selectedTab == .library {
                addButtonOverlay
            }

            // 悬浮导航栏
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showAddSheet) {
            AddRestaurantView()
        }
    }
    
    // 红色加号按钮组件
    private var addButtonOverlay: some View {
        Button {
            showAddSheet = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(AppTheme.Colors.accent)
                .clipShape(Circle())
                .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.trailing, 25)
        .padding(.bottom, 110) // 浮在导航栏上方
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
        .transition(.scale.combined(with: .opacity))
    }
    
    // 导航栏组件
    // MARK: - 终极版：视觉绝对平衡 + 果冻缩放导航栏
    private var customTabBar: some View {
            HStack(spacing: 0) {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    Button {
                        // ✅ 1. 触发果冻弹簧动画
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            selectedTab = tab
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        // ✅ 2. 核心修正：强制从顶部(top)开始计算坐标，彻底停用自动居中
                        ZStack(alignment: .top) {
                            
                            // --- A. 白色指示器 (48pt 高) ---
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .frame(width: 60, height: 54)
                                    // 在 64pt 的总高里居中：(64 - 54) / 2 = 5
                                    .offset(y: 5)
                                    .matchedGeometryEffect(id: "tab_glow", in: tabAnimation)
                                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                            }
                            
                            // --- B. 按钮内容 (图标 + 文字) ---
                            VStack(spacing: 2) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 20))
                                    .frame(height: 22) // 固定图标高度
                                
                                Text(tab.rawValue)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .frame(height: 12) // 固定文字高度
                            }
                            // ✅ 3. 颜色锁定：确保选中时变红，不选中变灰
                            .foregroundColor(selectedTab == tab ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
                            
                            // ✅ 4. 终极视觉对齐修正 (之前最成功的数值)
                            // 数学居中是 14，为了抵消文字底部留白，实测 15 是视觉上的“绝对平衡”
                            .offset(y: 15)
                            
                            // ✅ 5. 缩放逻辑：在定好的中心点上原地膨胀
                            .scaleEffect(selectedTab == tab ? 1.15 : 1.0)
                        }
                        // 确保每个 Tab 的触控区域填满 64pt 高度
                        .frame(maxWidth: .infinity, maxHeight: 64)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            // 导航栏容器定义
            .frame(width: UIScreen.main.bounds.width * 0.9, height: 64)
            .padding(.bottom, 34)
            .background(
                ZStack {
                    BlurView(style: .systemUltraThinMaterialLight).opacity(0.9)
                    AppTheme.Colors.background.opacity(0.85)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 15, x: 0, y: 8)
        }
}

// MARK: - 3. 辅助组件

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
            Image(systemName: "construction").font(.system(size: 80)).foregroundColor(.gray)
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
