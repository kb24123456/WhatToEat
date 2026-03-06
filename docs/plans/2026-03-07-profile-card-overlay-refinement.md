# Profile Card Overlay Refinement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 提升头像/名片收展动画精细度，移除展开数据卡片顶部拖拽条，并在数据卡片展开时自动丝滑隐藏底部导航条。

**Architecture:** 基于现有 `ProfileView` 的 matched geometry 结构继续精修，避免重写页面结构。通过收敛头像动画层级、减弱不必要的 blur 过渡、在 `ExpandedCardOverlay` 内联动 TabBar 显隐，并让 `ContentView` 为 TabBar 提供稳定 transition，实现低风险优化。

**Tech Stack:** SwiftUI, matchedGeometryEffect, NotificationCenter, spring animation

---

### Task 1: 头像/名片动画精修

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: 收敛头像动画层级**
- 将头像图片、圆形底、圆环描边拆成稳定的连续几何层。
- 避免只对图片做几何过渡导致边框脱节。

**Step 2: 减少冲突动画**
- 去掉或显著减轻头像头部切换时的 blur 干扰。
- 保留位移/缩放/透明度的连续过渡。

### Task 2: 展开卡片顶部清理

**Files:**
- Modify: `WhatToEat/ExpandableCard.swift`

**Step 1: 去掉顶部拖拽条**
- 删除顶部 `Capsule` 手势导航条视觉元素。
- 保留原有下拉关闭手势能力。

### Task 3: 展开卡片联动隐藏底部导航条

**Files:**
- Modify: `WhatToEat/ExpandableCard.swift`
- Modify: `WhatToEat/ContentView.swift`

**Step 1: Overlay 生命周期发通知**
- 展开进入时发送 `hideTabBar`。
- 关闭或消失时发送 `restoreTabBar`。

**Step 2: TabBar 增加过渡动画**
- 为底部导航条增加 bottom move + opacity + scale 过渡。
- 使用统一 spring，避免硬切。

### Task 4: 验证

**Files:**
- Modify: `WhatToEat/ProfileView.swift`
- Modify: `WhatToEat/ExpandableCard.swift`
- Modify: `WhatToEat/ContentView.swift`

**Step 1: 编译检查**
- 运行 `xcodebuild` 验证 SwiftUI 改动无语法或布局构建错误。

**Step 2: 手动检查点**
- 头像圆环在收展过程中是否仍有分层、跳变、边缘模糊异常。
- 展开数据卡片时顶部拖拽条是否完全移除。
- 展开/关闭数据卡片时底部导航条是否平滑隐藏和恢复。
