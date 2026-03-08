# CheckIn Alignment And Minimal Splash Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复打卡页人数调节按钮与数字文本的视觉高度不一致问题，并新增一个无文案、极简风格的开屏界面接入应用启动流程。

**Architecture:** 保持现有 `ContentView` 结构不变，通过 `WhatToEatApp` 根层覆盖一个短生命周期的 `SplashScreenView`，避免侵入 Tab 与导航逻辑。人数调节区仅做局部布局重构，统一按钮容器尺寸与垂直对齐基准，降低回归面。

**Tech Stack:** SwiftUI、SwiftData、UIKit

---

### Task 1: 修复 CheckIn 人数调节对齐

**Files:**
- Modify: `WhatToEat/CheckInView.swift`

**Step 1: 定位当前问题**

检查 `peopleInputSection` 中 `HStack(alignment: .lastTextBaseline)` 对 `Image` 强制基线对齐的实现，确认导致图标视觉中心偏移。

**Step 2: 实现最小修复**

将人数区域改为统一高度容器，按钮使用固定点击尺寸和垂直中心对齐，保留数字滚动动画与交互逻辑。

**Step 3: 自检**

确认减号禁用态、加号可点击态、数字变更动画与左右间距保持正常。

### Task 2: 新增极简开屏并接入启动链路

**Files:**
- Create: `WhatToEat/SplashScreenView.swift`
- Modify: `WhatToEat/WhatToEatApp.swift`

**Step 1: 设计最小开屏结构**

使用现有 `AppTheme` 颜色系统，提供无文案的简洁背景、中心品牌符号与轻量缩放/淡入动画。

**Step 2: 接入 App 根节点**

在 `WhatToEatApp` 的 `WindowGroup` 中用 `ZStack` 覆盖 `ContentView`，通过短定时或任务控制开屏自动淡出。

**Step 3: 兼容与性能控制**

动画仅使用 SwiftUI 原生 opacity/scale，不引入主线程重计算；若开启 Reduce Motion，则降级为纯淡入淡出。

### Task 3: 构建验证

**Files:**
- Verify: `WhatToEat/CheckInView.swift`
- Verify: `WhatToEat/SplashScreenView.swift`
- Verify: `WhatToEat/WhatToEatApp.swift`

**Step 1: 运行构建**

执行 `xcodebuild` 面向 iOS Simulator 构建，确认无编译错误。

**Step 2: 汇总结果**

记录是否通过、是否存在未覆盖的视觉验证项。
