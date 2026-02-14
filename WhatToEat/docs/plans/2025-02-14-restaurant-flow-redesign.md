# 餐厅卡片流重构实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or subagent-driven-development to implement this plan task-by-task.

**Goal:** 重构餐厅卡片系统，实现图2风格的列表态（卡片纯图片+下方文本）和图4风格的展开态（原视图变换+级联入场）

**Architecture:** 使用 matchedGeometryEffect 实现无缝转场，在同一视图内完成列表到展开的变换，避免页面跳转

**Tech Stack:** SwiftUI, matchedGeometryEffect, Namespace, Interactive Spring, Cascading Animation

---

## 任务清单

1. [Task 1: 删除旧实现文件](#task-1-删除旧实现文件)
2. [Task 2: 创建 RestaurantFlowViewModel](#task-2-创建-restaurantflowviewmodel)
3. [Task 3: 创建 RestaurantCard 纯图片卡片](#task-3-创建-restaurantcard-纯图片卡片)
4. [Task 4: 创建 CardInfoView 卡片信息](#task-4-创建-cardinfoview-卡片信息)
5. [Task 5: 创建 ExpandedInfoView 展开信息](#task-5-创建-expandedinfoview-展开信息)
6. [Task 6: 创建 RestaurantFlowView 主容器](#task-6-创建-restaurantflowview-主容器)
7. [Task 7: 实现 matchedGeometryEffect 转场](#task-7-实现-matchedgeometryeffect-转场)
8. [Task 8: 实现级联入场动画](#task-8-实现级联入场动画)
9. [Task 9: 集成到 ContentView](#task-9-集成到-contentview)
10. [Task 10: 测试和优化](#task-10-测试和优化)

---

## Task 1: 删除旧实现文件

**Files:**
- Delete: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCardViewModel.swift`
- Delete: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantListCard.swift`
- Delete: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantExpandedView.swift`
- Delete: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCardTransition.swift`
- Delete: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCardContainer.swift`

**Step 1: 删除旧文件**

```bash
rm /Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCardViewModel.swift
rm /Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantListCard.swift
rm /Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantExpandedView.swift
rm /Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCardTransition.swift
rm /Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCardContainer.swift
```

**Step 2: 编译验证**

Expected: Build failed (expected, files removed)

---

## Task 2: 创建 RestaurantFlowViewModel

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantFlowViewModel.swift`

**Step 1: 创建 ViewModel**

```swift
import SwiftUI
import SwiftData

@MainActor
@Observable
class RestaurantFlowViewModel {
    // MARK: - 状态
    enum ViewState {
        case list       // 列表态
        case expanding  // 展开中
        case expanded   // 展开态
    }
    
    var state: ViewState = .list
    var selectedRestaurant: Restaurant?
    var selectedIndex: Int = 0
    
    // MARK: - 动画命名空间（用于 matchedGeometryEffect）
    var namespace: Namespace.ID?
    
    // MARK: - 级联入场状态
    var cascadePhase: Int = 0
    
    // MARK: - 方法
    func expandRestaurant(_ restaurant: Restaurant, at index: Int, namespace: Namespace.ID) {
        self.selectedRestaurant = restaurant
        self.selectedIndex = index
        self.namespace = namespace
        
        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7)) {
            state = .expanding
        }
        
        // 延迟显示展开内容
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                state = .expanded
            }
            startCascadeAnimation()
        }
    }
    
    func collapseRestaurant() {
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8)) {
            state = .list
            cascadePhase = 0
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            selectedRestaurant = nil
            namespace = nil
        }
    }
    
    private func startCascadeAnimation() {
        for i in 1...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.cascadePhase = i
                }
            }
        }
    }
}
```

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 3: 创建 RestaurantCard 纯图片卡片

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantCard.swift`

**Step 1: 创建纯图片卡片**

```swift
import SwiftUI

struct RestaurantCard: View {
    let restaurant: Restaurant
    let index: Int
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void
    
    // MARK: - 尺寸
    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 420
    private let cornerRadius: CGFloat = 32
    
    var body: some View {
        AsyncImageView(
            filename: restaurant.coverPhotoFilename,
            placeholder: AnyView(
                ZStack {
                    Color(hex: "#F0F0F0")
                    Image(systemName: "fork.knife")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            )
        )
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: isSelected ? Color.black.opacity(0.2) : Color.black.opacity(0.1),
            radius: isSelected ? 30 : 20,
            x: 0,
            y: isSelected ? 15 : 10
        )
        .matchedGeometryEffect(id: "card-image-\(restaurant.id)", in: namespace)
        .onTapGesture {
            onTap()
        }
    }
}
```

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 4: 创建 CardInfoView 卡片信息

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/CardInfoView.swift`

**Step 1: 创建卡片下方信息视图**

```swift
import SwiftUI

struct CardInfoView: View {
    let restaurant: Restaurant
    let isVisible: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(restaurant.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(restaurant.review)
                .font(.system(size: 14, weight: .medium, design: .default))
                .italic()
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isVisible)
    }
}
```

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 5: 创建 ExpandedInfoView 展开信息

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ExpandedInfoView.swift`

**Step 1: 创建展开态详细信息视图**

```swift
import SwiftUI

struct ExpandedInfoView: View {
    let restaurant: Restaurant
    let cascadePhase: Int
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 餐厅名称
            titleSection
                .padding(.top, 24)
                .opacity(cascadePhase >= 1 ? 1 : 0)
                .offset(y: cascadePhase >= 1 ? 0 : 30)
            
            // 四格数据
            dataGrid
                .padding(.top, 20)
                .opacity(cascadePhase >= 2 ? 1 : 0)
                .offset(y: cascadePhase >= 2 ? 0 : 30)
            
            // 点评
            reviewSection
                .padding(.top, 20)
                .opacity(cascadePhase >= 3 ? 1 : 0)
                .offset(y: cascadePhase >= 3 ? 0 : 30)
            
            // 标签
            tagsSection
                .padding(.top, 20)
                .opacity(cascadePhase >= 4 ? 1 : 0)
                .offset(y: cascadePhase >= 4 ? 0 : 30)
            
            // 按钮
            actionButton
                .padding(.top, 30)
                .padding(.bottom, 40)
                .opacity(cascadePhase >= 5 ? 1 : 0)
                .offset(y: cascadePhase >= 5 ? 0 : 30)
        }
        .padding(.horizontal, 20)
    }
    
    private var titleSection: some View {
        Text(restaurant.name)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var dataGrid: some View {
        HStack(spacing: 12) {
            DataCell(icon: "location.fill", value: "5.7km", label: "距离")
            DataCell(icon: "car.fill", value: "11min", label: "驾车")
            DataCell(icon: "mappin", value: restaurant.district, label: "区域")
            DataCell(icon: "fork.knife", value: restaurant.type, label: "品类")
        }
    }
    
    private var reviewSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppTheme.Colors.babyBlue)
                .frame(width: 4, height: 50)
            
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
    }
    
    private var tagsSection: some View {
        FlowLayout(spacing: 8) {
            ForEach(restaurant.tags, id: \.self) { tag in
                TagPill(text: tag)
            }
        }
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
    }
}

// MARK: - 数据单元
struct DataCell: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.babyBlue)
            
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 10))
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

// MARK: - 标签 pill
struct TagPill: View {
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

## Task 6: 创建 RestaurantFlowView 主容器

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantFlowView.swift`

**Step 1: 创建主容器视图**

```swift
import SwiftUI
import SwiftData

struct RestaurantFlowView: View {
    @Query(sort: \Restaurant.createdAt, order: .reverse) var restaurants: [Restaurant]
    @State private var viewModel = RestaurantFlowViewModel()
    @Namespace private var animationNamespace
    
    var body: some View {
        ZStack {
            // 背景
            Color(hex: "#F9F9F7")
                .ignoresSafeArea()
            
            // 主内容
            VStack(spacing: 0) {
                // 卡片区域
                cardSection
                    .frame(height: viewModel.state == .list ? 520 : 280)
                
                // 列表态：卡片下方信息
                if viewModel.state == .list, let selected = viewModel.selectedRestaurant {
                    CardInfoView(
                        restaurant: selected,
                        isVisible: true
                    )
                    .padding(.top, 20)
                }
                
                // 展开态：详细信息
                if viewModel.state == .expanded, let selected = viewModel.selectedRestaurant {
                    ExpandedInfoView(
                        restaurant: selected,
                        cascadePhase: viewModel.cascadePhase,
                        onClose: { viewModel.collapseRestaurant() }
                    )
                }
                
                Spacer()
            }
        }
    }
    
    private var cardSection: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let cardWidth: CGFloat = 300
            let spacing: CGFloat = 20
            
            HStack(spacing: spacing) {
                ForEach(Array(restaurants.enumerated()), id: \.element.id) { index, restaurant in
                    RestaurantCard(
                        restaurant: restaurant,
                        index: index,
                        isSelected: viewModel.selectedRestaurant?.id == restaurant.id,
                        namespace: animationNamespace
                    ) {
                        handleCardTap(restaurant, at: index)
                    }
                    .frame(width: cardWidth)
                    .offset(x: calculateCardOffset(index: index, screenWidth: screenWidth, cardWidth: cardWidth, spacing: spacing))
                    .scaleEffect(calculateCardScale(index: index))
                    .opacity(calculateCardOpacity(index: index))
                    .zIndex(calculateZIndex(index: index))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func handleCardTap(_ restaurant: Restaurant, at index: Int) {
        if viewModel.state == .list {
            viewModel.expandRestaurant(restaurant, at: index, namespace: animationNamespace)
        } else {
            viewModel.collapseRestaurant()
        }
    }
    
    // MARK: - 卡片位置计算
    private func calculateCardOffset(index: Int, screenWidth: CGFloat, cardWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        guard let selectedIndex = viewModel.selectedRestaurant.flatMap({ r in restaurants.firstIndex(where: { $0.id == r.id }) }) else {
            return 0
        }
        
        if viewModel.state == .list {
            return 0
        }
        
        // 展开态：非选中卡片移出屏幕
        let offset = CGFloat(index - selectedIndex) * (cardWidth + spacing)
        if index == selectedIndex {
            return 0
        } else if index < selectedIndex {
            return offset - screenWidth / 2 - cardWidth
        } else {
            return offset + screenWidth / 2 + cardWidth
        }
    }
    
    private func calculateCardScale(index: Int) -> CGFloat {
        guard let selected = viewModel.selectedRestaurant else { return 1.0 }
        let isSelected = restaurants[index].id == selected.id
        
        if viewModel.state == .list {
            return 1.0
        }
        
        return isSelected ? 1.0 : 0.8
    }
    
    private func calculateCardOpacity(index: Int) -> Double {
        guard let selected = viewModel.selectedRestaurant else { return 1.0 }
        let isSelected = restaurants[index].id == selected.id
        
        if viewModel.state == .list {
            return 1.0
        }
        
        return isSelected ? 1.0 : 0.3
    }
    
    private func calculateZIndex(index: Int) -> Double {
        guard let selected = viewModel.selectedRestaurant else { return 0 }
        return restaurants[index].id == selected.id ? 1 : 0
    }
}
```

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 7: 实现 matchedGeometryEffect 转场

**说明**: 已在 Task 3 和 Task 6 中实现，通过 `matchedGeometryEffect(id: "card-image-\(restaurant.id)", in: namespace)` 实现图片无缝转场

---

## Task 8: 实现级联入场动画

**说明**: 已在 Task 2 和 Task 5 中实现，通过 `cascadePhase` 和 `DispatchQueue.main.asyncAfter` 实现 5 阶段级联入场

---

## Task 9: 集成到 ContentView

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ContentView.swift`

**Step 1: 修改 ContentView**

将 `.home` case 中的 `GourmetMatchView()` 替换为 `RestaurantFlowView()`

```swift
case .home:
    RestaurantFlowView()
```

**Step 2: 编译验证**

Expected: Build succeeded

---

## Task 10: 测试和优化

**测试清单**:
- [ ] 列表态卡片纯图片显示
- [ ] 卡片下方文本正确显示
- [ ] 点击卡片触发转场动画
- [ ] 图片使用 matchedGeometryEffect 无缝变形
- [ ] 两侧卡片移出屏幕
- [ ] 详细信息级联入场
- [ ] 再次点击收起
- [ ] 动画流畅 60fps+

**优化点**:
- 使用 `.drawingGroup()` 优化复杂渲染
- 图片预加载
- 手势响应优化

---

**计划完成！准备开始执行。**
