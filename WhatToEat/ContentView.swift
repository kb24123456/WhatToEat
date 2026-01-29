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
    
    // 自定义导航栏组件 - 悬浮胶囊设计
    private var customTabBar: some View {
        ZStack {
            // 1. 底座背景：悬浮胶囊 - 毛玻璃效果
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
                // 毛玻璃悬浮胶囊
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, 12)
            
            // 2. 中间圆形突出按钮 - 宝石按钮
            Button {
                withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.7, blendDuration: 0.2)) {
                    isAdding = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accent)
                        .frame(width: 60, height: 60)
                        // 红色弥散投影
                        .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 8)
                        .shadow(color: AppTheme.Colors.accent.opacity(0.15), radius: 20, x: 0, y: 12)
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
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .matchedGeometryEffect(id: "ADD_BUTTON", in: animationNamespace)
                }
                .offset(y: -22)
            }
            .buttonStyle(.plain)
            .scaleEffect(0.96)
            .withHapticFeedback()
        }
        .zIndex(100)
    }
    
    // MARK: - Tab Button with Milky Bubble
    private func tabButton(tab: TabItem, icon: String, title: String) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.1)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                // Milky Bubble 背板（选中时显示）
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 56, height: 44)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                        .transition(.scale.combined(with: .opacity))
                }
                
                VStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                        .frame(height: 22)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text(title)
                        .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                        .frame(height: 10)
                }
                .foregroundColor(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: 60)
        }
        .buttonStyle(.plain)
        .withHapticFeedback()
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
