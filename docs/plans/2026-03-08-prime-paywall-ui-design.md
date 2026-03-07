# Prime Paywall UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将当前 Profile 内的会员预览页升级为可上线预演的 Prime 购买页，补齐限时优惠、价格方案、权益文案与占位支付入口。

**Architecture:** 继续复用 `ProfileView` 内的会员页面结构，在 `WhatToEatApp` 中记录“每日首次打开 App 的优惠开始时间”，再由会员页通过 `TimelineView` 实时刷新倒计时和价格态。支付不接 StoreKit，只保留可挂接的购买/恢复接口与 toast 反馈。

**Tech Stack:** SwiftUI, TimelineView, AppStorage, UserDefaults, existing ProfileView card system

---

### Task 1: 建立每日优惠时间状态

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/AppSettingsKeys.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/WhatToEatApp.swift`

**Step 1:** 新增会员优惠开始时间与日期键位。

**Step 2:** 在 `WhatToEatApp.bootstrapDefaultSettings()` 中写入“每日首次打开 App”的优惠开始时间。

**Step 3:** 保证同一天内重复启动不重置，跨天首次启动才刷新。

### Task 2: 重写会员页信息架构

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`

**Step 1:** 用新的 Hero 卡替换当前“会员预览”文案，改为长期资产叙事。

**Step 2:** 增加价格方案卡片区，支持月 / 年 / 永久三档，展示限时价与原价。

**Step 3:** 增加限时优惠倒计时与 50% OFF 表达，30 分钟结束后自动切回原价。

**Step 4:** 增加核心权益区、为什么开通区、独立开发者表达区、FAQ 区。

### Task 3: 预留支付接口与本地交互

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`

**Step 1:** 新增当前选中会员方案状态。

**Step 2:** 新增“立即开通”“恢复购买”的占位动作。

**Step 3:** 使用现有 toast/提示机制反馈“支付接口待接入”。

### Task 4: 验证

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/WhatToEatApp.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/AppSettingsKeys.swift`

**Step 1:** 运行 iPhone 17 模拟器构建。

**Step 2:** 检查会员页在折扣中和折扣结束后的文案与按钮状态。

**Step 3:** 确认未接支付时 CTA 与恢复购买都只走占位逻辑。
