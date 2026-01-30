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
    
    var body: some View {
        ZStack {
            // 背景层：弥散背景铺满整个屏幕（包括安全区域）
            MilkyDiffuseBackground()
                .ignoresSafeArea()
            
            Group {
                switch selectedTab {
                case .library:
                    LibraryView()
                case .home:
                    GourmetMatchView()
                case .add:
                    EmptyView()
                case .friends:
                    // 将餐厅数据传入地图视图
                    RestaurantMapView(restaurants: restaurants)
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
                VStack {
                    Spacer()
                    customTabBar
                }
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
    
    // 自定义导航栏组件 - 沉底样式
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        .background(Color.white)
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
                    
                    Text(title)
                        .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                        .frame(height: 10)
                }
                .foregroundColor(isSelected ? .black : AppTheme.Colors.textSecondary.opacity(0.7))
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
