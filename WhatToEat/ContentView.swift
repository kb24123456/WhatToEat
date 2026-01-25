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
    case friends = "食记"
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
    @Namespace private var tabAnimation
    @State private var showAddRestaurant = false
    
    var body: some View {
        ZStack {
            // 1. 主内容区域切换
            Group {
                switch selectedTab {
                case .library:
                    LibraryView() // 这里的实现已经搬到了 LibraryView.swift
                case .home:
                    PlaceholderView(title: "吃啥", description: "随机抽取功能即将上线")
                case .add:
                    EmptyView() // 加号按钮只用于触发动作，不显示内容
                case .friends:
                    PlaceholderView(title: "事友圈", description: "社交功能即将上线")
                case .profile:
                    PlaceholderView(title: "我的", description: "个人设置功能即将上线")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 2. 沉底导航栏：使用safeAreaInset确保底部安全区域被正确处理
            customTabBar
        }
        .ignoresSafeArea(.keyboard) // 防止键盘弹出时导航栏乱跑
        .sheet(isPresented: $showAddRestaurant) {
            AddRestaurantView()
        }
    }
    
    // 自定义导航栏组件 - 沉底设计
    private var customTabBar: some View {
        ZStack {
            // 1. 底座背景：悬浮玻璃效果
            HStack(spacing: 0) {
                // 1. 食库按钮
                Button {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.6, blendDuration: 0.1)) {
                        selectedTab = .library
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: TabItem.library.iconName)
                            .font(.system(size: 24))
                            .frame(height: 24)
                            .symbolRenderingMode(.hierarchical) // 图标渲染模式：分层
                        Text(TabItem.library.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .frame(height: 12)
                    }
                    .foregroundColor(selectedTab == .library ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary.opacity(0.6))
                    .scaleEffect(selectedTab == .library ? 1.15 : 1.0)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: 60)
                .scaleEffect(0.96) // 轻微的缩放反馈
                .withHapticFeedback() // 触感反馈
                
                // 2. 吃啥按钮
                Button {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.6, blendDuration: 0.1)) {
                        selectedTab = .home
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: TabItem.home.iconName)
                            .font(.system(size: 24))
                            .frame(height: 24)
                            .symbolRenderingMode(.hierarchical) // 图标渲染模式：分层
                        Text(TabItem.home.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .frame(height: 12)
                    }
                    .foregroundColor(selectedTab == .home ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary.opacity(0.6))
                    .scaleEffect(selectedTab == .home ? 1.15 : 1.0)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: 60)
                .scaleEffect(0.96) // 轻微的缩放反馈
                .withHapticFeedback() // 触感反馈
                
                // 3. 中间圆形突出按钮占位
                Button {}
                    label: {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: 60)
                    }
                    .buttonStyle(.plain)
                
                // 4. 食记按钮
                Button {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.6, blendDuration: 0.1)) {
                        selectedTab = .friends
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: TabItem.friends.iconName)
                            .font(.system(size: 24))
                            .frame(height: 24)
                            .symbolRenderingMode(.hierarchical) // 图标渲染模式：分层
                        Text(TabItem.friends.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .frame(height: 12)
                    }
                    .foregroundColor(selectedTab == .friends ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary.opacity(0.6))
                    .scaleEffect(selectedTab == .friends ? 1.15 : 1.0)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: 60)
                .scaleEffect(0.96) // 轻微的缩放反馈
                .withHapticFeedback() // 触感反馈
                
                // 5. 我的按钮
                Button {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.6, blendDuration: 0.1)) {
                        selectedTab = .profile
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: TabItem.profile.iconName)
                            .font(.system(size: 24))
                            .frame(height: 24)
                            .symbolRenderingMode(.hierarchical) // 图标渲染模式：分层
                        Text(TabItem.profile.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .frame(height: 12)
                    }
                    .foregroundColor(selectedTab == .profile ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary.opacity(0.6))
                    .scaleEffect(selectedTab == .profile ? 1.15 : 1.0)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: 60)
                .scaleEffect(0.96) // 轻微的缩放反馈
                .withHapticFeedback() // 触感反馈
            }
            .padding(.horizontal, AppTheme.Spacing.md) // 内部水平间距
            .frame(height: 60)
            .background(
                // 玻璃材质背景 - 悬浮岛样式
                RoundedRectangle(cornerRadius: AppTheme.Radius.circle)
                    .fill(.ultraThinMaterial) // 使用超薄材质，实现玻璃效果
                    .overlay(
                        // 白色半透明描边
                        RoundedRectangle(cornerRadius: AppTheme.Radius.circle)
                            .stroke(.white.opacity(0.4), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 10, y: -5) // 整体悬浮阴影
            )
            .padding(.horizontal, AppTheme.Spacing.lg) // 左右各留出16pt外边距
            .padding(.bottom, 10) // 底部留出10pt外边距
            
            // 2. 中间圆形突出按钮 - 宝石按钮
            Button {
                // 打开添加餐厅表单
                showAddRestaurant = true
            } label: {
                ZStack {
                    // 纯色背景 - 哑光材质
                    Circle()
                        .fill(AppTheme.Colors.accent) // 使用纯色强调色
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(hex: "#FF2442").opacity(0.3), radius: 8, x: 0, y: 4) // 底层投影
                        .overlay(
                            // 微弱内发光：在按钮内部顶端模拟极细的浅色内边缘
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.2), // 微弱的白色
                                            Color.clear // 到透明
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 52, height: 52) // 比按钮略小
                        )
                    
                    // 加号图标 - 白色加粗
                    Image(systemName: TabItem.add.iconName)
                        .font(.system(size: 26, weight: .bold)) // 略微加粗
                        .foregroundColor(.white)
                }
                .offset(y: -20) // 向上偏移，突出在导航栏上方
            }
            .buttonStyle(.plain)
            .scaleEffect(0.96) // 轻微的缩放反馈
            .withHapticFeedback() // 触感反馈
        }
        .zIndex(100)
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
