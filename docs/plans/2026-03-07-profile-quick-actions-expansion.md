# Profile Quick Actions Expansion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 ProfileView 折叠态底部新增“成就等级”“成为会员”两张卡片，保持与现有入口卡片一致的视觉风格，并通过与“我的数据 / 功能设置”同款的页内展开效果进入各自的轻量详情页。

**Architecture:** 继续复用 `ProfileView` 当前 `showDashboardCards` 与 `selectedGateway` 的页内展开结构，不引入新的全局路由层。将入口状态从 2 个扩展为 4 个，并把顶部切换区升级为四项切换条。

**Tech Stack:** SwiftUI, ScrollView, in-page state-driven transition, spring animation

---

### Task 1: 扩展折叠态入口卡片布局

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: 调整入口卡片布局**

- 将当前单行两张卡片改成两行四张卡片布局。
- 保持现有圆角、阴影、描边、图标容器、标题/副标题样式不变。

**Step 2: 抽出统一卡片壳层**

- 将现有入口卡片公共样式抽成复用结构，避免新增两张卡片后出现重复样式代码。
- 保留“我的数据”“功能设置”的点击行为不变。

### Task 2: 扩展展开态切换结构

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: 扩展入口状态**

- 将当前二元入口状态扩展为四个入口状态。
- 复用现有 `showDashboardCards` 动画逻辑，不引入额外导航层。

**Step 2: 升级顶部切换区**

- 将当前“切到我的数据 / 切到功能设置”的二元切换，改为四项切换条。
- 保留“收起”能力与现有 spring 过渡节奏。

### Task 3: 实现“成就等级”“成为会员”详情页

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: 实现成就等级详情页**

- 展示当前等级、当前头衔、打卡次数、升级进度。
- 补充静态等级说明与成长路径文案。

**Step 2: 实现成为会员详情页**

- 展示静态会员价值说明、权益列表与未来可开放能力。
- 明确当前为展示版，不接支付与账号开通逻辑。

### Task 4: 验证

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: 构建验证**

Run: `xcodebuild -project /Users/papertiger/Desktop/WhatToEat/WhatToEat.xcodeproj -scheme WhatToEat -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build`

Expected: BUILD SUCCEEDED

**Step 2: 手动检查点**

- 折叠态入口卡片是否从 2 张扩展为 4 张且风格一致。
- 点击“成就等级”“成为会员”是否以和现有两张卡片一致的方式展开。
- 展开态顶部是否可以在四个页面间丝滑切换。
- 页面底部留白是否明显收敛。
