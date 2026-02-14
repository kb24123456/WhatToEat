# 餐厅卡片系统实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现一个具有杂志级视觉设计和丝滑转场动画的餐厅卡片系统，包含列表态、展开态和优雅的旋转转场动画。

**Architecture:** 采用 MVVM 架构，使用 SwiftUI 的 matchedGeometryEffect 实现无缝转场，结合 Interactive Spring 物理动画和级联入场效果。

**Tech Stack:** SwiftUI, SwiftData, @MainActor, matchedGeometryEffect, MeshGradient, Interactive Spring

---

## 任务清单概览

1. [Task 1: 创建 ViewModel](#task-1-创建-viewmodel)
2. [Task 2: 创建列表态卡片视图](#task-2-创建列表态卡片视图)
3. [Task 3: 创建展开态详情视图](#task-3-创建展开态详情视图)
4. [Task 4: 实现转场动画协调器](#task-4-实现转场动画协调器)
5. [Task 5: 创建主容器视图](#task-5-创建主容器视图)
6. [Task 6: 集成到 ContentView](#task-6-集成到-contentview)
7. [Task 7: 测试和优化](#task-7-测试和优化)

---

## Task 1: 创建 ViewModel

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCardViewModel.swift`

**Step 1: 创建 ViewModel 文件**

```swift
import SwiftUI
import SwiftData

@MainActor
@Observable
class RestaurantCardViewModel {
    // MARK: - 卡片状态
    enum CardState {
        case list       // 列表态
        case expanding  // 展开中
        case expanded   // 展开态
        case collapsing // 收起中
    }
    
    var state: CardState = .list
    var selectedRestaurant: Restaurant?
    
    // MARK: - 动画状态
    var rotation: Double = 0
    var cardScale: CGFloat = 1.0
    var cardOffset: CGSize = .zero
    
    // MARK: - 元素位置（用于重力感应流）
    var titleOffset: CGSize = .zero
    var tagOffset: CGSize = .zero
    var imageFrame: CGRect = .zero
    
    // MARK: - 级联入场状态
    var isContentReady: Bool = false
    var cascadePhase: Int = 0
    
    // MARK: - 转场方法
    func expandCard(_ restaurant: Restaurant) {
        selectedRestaurant = restaurant
        state = .expanding
        
        // 阶段1: 卡片旋转
        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7)) {
            rotation = 90
        }
        
        // 阶段2: 元素位移
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
            titleOffset = CGSize(width: -20, height: 100)
            tagOffset = CGSize(width: 20, height: -50)
        }
        
        // 阶段3: 级联入场
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            isContentReady = true
            state = .expanded
        }
    }
    
    func collapseCard() {
        state = .collapsing
        isContentReady = false
        
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8)) {
            rotation = 0
            titleOffset = .zero
            tagOffset = .zero
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            state = .list
            selectedRestaurant = nil
        }
    }
}
```

**Step 2: 编译验证**

Run: `xcodebuild -project WhatToEat.xcodeproj -scheme WhatToEat -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: Build succeeded

---

## Task 2: 创建列表态卡片视图

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantListCard.swift`

**Step 1: 创建列表态卡片**

```swift
import SwiftUI

struct RestaurantListCard: View {
    let restaurant: Restaurant
    let index: Int
    @Binding var isExpanded: Bool
    var onTap: () -> Void
    
    // MARK: - 常量
    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 380
    private let cornerRadius: CGFloat = 32
    
    var body: some View {
        VStack(spacing: 0) {
            // 封面图
            heroImage
                .frame(width: cardWidth, height: cardHeight * 0.7)
            
            // 文字内容
            VStack(alignment: .leading, spacing: 8) {
                Text(restaurant.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(restaurant.review)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .italic()
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Spacer()
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: "#F9F9F7")) // Oreo Cream
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
        .onTapGesture {
            onTap()
        }
    }
    
    private var heroImage: some View {
        AsyncImageView(
            filename: restaurant.coverPhotoFilename,
            placeholder: AnyView(
                ZStack {
                    Color(hex: "#F5F5F5")
                    Image(systemName: "fork.knife")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
```

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 3: 创建展开态详情视图

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantExpandedView.swift`

**Step 1: 创建展开态视图**

```swift
import SwiftUI

struct RestaurantExpandedView: View {
    let restaurant: Restaurant
    var onClose: () -> Void
    
    @State private var cascadePhase: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Image (横向)
                heroImage
                    .frame(height: UIScreen.main.bounds.height * 0.35)
                
                // 餐厅名称
                titleSection
                    .padding(.top, 24)
                    .opacity(cascadePhase >= 1 ? 1 : 0)
                    .offset(y: cascadePhase >= 1 ? 0 : 30)
                
                // 四格数据仪表盘
                dataDashboard
                    .padding(.top, 20)
                    .opacity(cascadePhase >= 2 ? 1 : 0)
                    .offset(y: cascadePhase >= 2 ? 0 : 30)
                
                // 一句话点评
                reviewSection
                    .padding(.top, 20)
                    .opacity(cascadePhase >= 3 ? 1 : 0)
                    .offset(y: cascadePhase >= 3 ? 0 : 30)
                
                // 探店标签
                tagsSection
                    .padding(.top, 20)
                    .opacity(cascadePhase >= 4 ? 1 : 0)
                    .offset(y: cascadePhase >= 4 ? 0 : 30)
                
                // 去这里按钮
                actionButton
                    .padding(.top, 30)
                    .padding(.bottom, 40)
                    .opacity(cascadePhase >= 5 ? 1 : 0)
                    .offset(y: cascadePhase >= 5 ? 0 : 30)
            }
        }
        .background(Color(hex: "#F9F9F7"))
        .onAppear {
            startCascadeAnimation()
        }
    }
    
    private func startCascadeAnimation() {
        for i in 1...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    cascadePhase = i
                }
            }
        }
    }
    
    private var heroImage: some View {
        AsyncImageView(
            filename: restaurant.coverPhotoFilename,
            placeholder: AnyView(
                ZStack {
                    Color(hex: "#F5F5F5")
                    Image(systemName: "fork.knife")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            )
        )
    }
    
    private var titleSection: some View {
        Text(restaurant.name)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .padding(.horizontal, 24)
    }
    
    private var dataDashboard: some View {
        HStack(spacing: 12) {
            DataCard(icon: "location.fill", value: "5.7km", label: "距离")
            DataCard(icon: "car.fill", value: "11min", label: "驾车")
            DataCard(icon: "mappin", value: restaurant.district, label: "区域")
            DataCard(icon: "fork.knife", value: restaurant.type, label: "品类")
        }
        .padding(.horizontal, 20)
    }
    
    private var reviewSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppTheme.Colors.babyBlue)
                .frame(width: 4, height: 40)
            
            Text(restaurant.review)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
        .padding(.horizontal, 20)
    }
    
    private var tagsSection: some View {
        FlowLayout(spacing: 8) {
            ForEach(restaurant.tags, id: \.self) { tag in
                TagView(text: tag)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var actionButton: some View {
        Button(action: onClose) {
            Text("去这里")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black)
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 数据卡片
struct DataCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.babyBlue)
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - 标签视图
struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
            )
    }
}
```

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 4: 实现转场动画协调器

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCardTransition.swift`

**Step 1: 创建转场协调器**

```swift
import SwiftUI

struct RestaurantCardTransition: View {
    @State private var viewModel = RestaurantCardViewModel()
    let restaurants: [Restaurant]
    
    var body: some View {
        ZStack {
            // 列表态
            if viewModel.state == .list || viewModel.state == .expanding {
                listView
            }
            
            // 展开态
            if viewModel.state == .expanded || viewModel.state == .collapsing {
                if let restaurant = viewModel.selectedRestaurant {
                    RestaurantExpandedView(
                        restaurant: restaurant,
                        onClose: { viewModel.collapseCard() }
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }
    
    private var listView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(Array(restaurants.enumerated()), id: \.element.id) { index, restaurant in
                    RestaurantListCard(
                        restaurant: restaurant,
                        index: index,
                        isExpanded: .constant(viewModel.selectedRestaurant?.id == restaurant.id)
                    ) {
                        viewModel.expandCard(restaurant)
                    }
                    .rotationEffect(.degrees(viewModel.selectedRestaurant?.id == restaurant.id ? viewModel.rotation : 0))
                    .offset(viewModel.selectedRestaurant?.id == restaurant.id ? viewModel.cardOffset : .zero)
                    .scaleEffect(viewModel.selectedRestaurant?.id == restaurant.id ? viewModel.cardScale : 1.0)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
    }
}
```

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 5: 创建主容器视图

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCardContainer.swift`

**Step 1: 创建容器视图**

```swift
import SwiftUI
import SwiftData

struct RestaurantCardContainer: View {
    @Query(sort: \Restaurant.createdAt, order: .reverse) var restaurants: [Restaurant]
    
    var body: some View {
        ZStack {
            // 背景
            Color(hex: "#F9F9F7")
                .ignoresSafeArea()
            
            // 卡片系统
            RestaurantCardTransition(restaurants: restaurants)
            
            // 底部导航
            bottomNavigation
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 60)
        }
    }
    
    private var bottomNavigation: some View {
        HStack(spacing: 40) {
            Button("吃啥") {}
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Button("食库") {}
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}
```

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 6: 集成到 ContentView

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ContentView.swift`

**Step 1: 添加新视图入口**

在 ContentView 中添加 RestaurantCardContainer 的入口，可以作为一个新的 Tab 或导航目的地。

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 7: 测试和优化

**Step 1: 功能测试**
- [ ] 列表态卡片正常显示
- [ ] 点击卡片触发转场动画
- [ ] 卡片旋转 90 度正确
- [ ] 展开态信息完整显示
- [ ] 级联入场动画正常
- [ ] 关闭按钮正常工作

**Step 2: 性能测试**
- [ ] 动画流畅度 60fps+
- [ ] 内存占用正常
- [ ] 无卡顿或掉帧

**Step 3: 视觉验收**
- [ ] 32pt 连续圆角正确
- [ ] Oreo Cream 背景色正确
- [ ] 阴影效果自然
- [ ] 文字层级清晰

---

## 技术要点备忘

### 动画参数
```swift
// 卡片旋转
.interactiveSpring(response: 0.6, dampingFraction: 0.7)

// 元素位移
.interactiveSpring(response: 0.5, dampingFraction: 0.8)

// 级联入场
.spring(response: 0.5, dampingFraction: 0.7)
.delay(index * 0.08)
```

### 颜色规范
```swift
// 背景
Color(hex: "#F9F9F7") // Oreo Cream

// 点缀
AppTheme.Colors.babyBlue

// 按钮
Color.black
```

### 尺寸规范
```swift
// 卡片
let cardWidth: CGFloat = 280
let cardHeight: CGFloat = 380
let cornerRadius: CGFloat = 32

// Hero Image
height: UIScreen.main.bounds.height * 0.35
```

---

**计划完成！准备开始执行。**
