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
    @Namespace private var animationNamespace
    @State private var isAdding: Bool = false
    @State private var isTabBarHidden: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .library:
                    LibraryView()
                case .home:
                    PlaceholderView(title: "吃啥", description: "随机抽取功能即将上线")
                case .add:
                    EmptyView()
                case .friends:
                    PlaceholderView(title: "事友圈", description: "社交功能即将上线")
                case .profile:
                    PlaceholderView(title: "我的", description: "个人设置功能即将上线")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .fullScreenCover(isPresented: $isAdding) {
                AddRestaurantView(onClose: {
                    withAnimation {
                        isAdding = false
                    }
                })
            }

            if !isTabBarHidden {
                customTabBar
            }
        }
        .ignoresSafeArea(.keyboard)
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
    }
    
    // 自定义导航栏组件 - 奶脂实色风格
    private var customTabBar: some View {
        ZStack {
            // 1. 底座背景：奶脂实色悬浮胶囊
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
                
                // 3. 中间圆形突出按钮占位
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: 60)
                
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
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(height: 64)
            .background(
                // 奶脂实色悬浮胶囊
                ZStack {
                    // 基础颜色层
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(AppTheme.Colors.milkyWhite)
                    
                    // 模糊效果层
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // 边缘高光描边
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, 12)
            
            // 2. 中间圆形突出按钮 - 宝石按钮（弥散红色阴影）
            Button {
                withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.7, blendDuration: 0.2)) {
                    isAdding = true
                }
                // 触感反馈
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accent)
                        .frame(width: 60, height: 60)
                        // 弥散红色阴影
                        .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 15, x: 0, y: 8)
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.25),
                                            Color.clear
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 56, height: 56)
                        )
                    
                    Image(systemName: TabItem.add.iconName)
                        .font(.system(size: 24, weight: .bold))  // 图标稍微缩小
                        .foregroundColor(.white)
                        .matchedGeometryEffect(id: "ADD_BUTTON", in: animationNamespace)
                }
                .offset(y: -22)
            }
            .buttonStyle(.plain)
        }
        .zIndex(100)
    }
    
    // MARK: - Tab Button with 奶脂实色风格
    private func tabButton(tab: TabItem, icon: String, title: String) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.1)) {
                selectedTab = tab
            }
            // 触感反馈
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            ZStack {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                        .frame(height: 22)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text(title)
                        .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                        .frame(height: 10)
                    
                    // 选中态：红色横向胶囊短线
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(AppTheme.Colors.accent)
                                .frame(width: 16, height: 3)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .frame(height: 3)
                }
                .foregroundColor(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary.opacity(0.7))
            }
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
