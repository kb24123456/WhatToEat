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
    case friends = "事友圈"
    case profile = "我的"
    
    var iconName: String {
        switch self {
        case .library: return "books.vertical"
        case .home: return "house"
        case .add: return "plus"
        case .friends: return "person.3"
        case .profile: return "person"
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
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                if tab == .add {
                    // 中间圆形突出按钮
                    Button {
                        // 打开添加餐厅表单
                        showAddRestaurant = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#FF2442"))
                                .frame(width: 56, height: 56)
                                .shadow(color: Color(hex: "#FF2442").opacity(0.3), radius: 10, x: 0, y: 2)
                            Image(systemName: tab.iconName)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        .offset(y: 2) // 向上偏移，顶部距离导航栏上边缘4pt
                    }
                    .buttonStyle(.plain)
                    .frame(width: 80, height: 60) // 固定中间按钮宽度，确保两侧按钮有足够空间
                } else {
                    // 普通导航按钮
                    Button {
                        // 使用交互式弹簧动画，提供更流畅的体验
                        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.6, blendDuration: 0.1)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 24))
                                .frame(height: 24)
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .frame(height: 12)
                        }
                        .foregroundColor(selectedTab == tab ? Color(hex: "#FF2442") : Color(hex: "#948E88"))
                        .scaleEffect(selectedTab == tab ? 1.15 : 1.0)
                        .frame(maxWidth: .infinity, alignment: getButtonAlignment(for: tab)) // 动态对齐方式
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: 60)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg) // 添加16pt水平间距
        .frame(height: 60)
        .background(Color.white)

        .zIndex(100)
    }
    
    // 辅助方法：根据按钮位置返回对齐方式
    private func getButtonAlignment(for tab: TabItem) -> Alignment {
        switch tab {
        case .library: // 左端按钮
            return .leading
        case .home: // 左侧中间按钮
            return .center
        case .add: // 中间按钮
            return .center
        case .friends: // 右侧中间按钮
            return .center
        case .profile: // 右端按钮
            return .trailing
        }
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
