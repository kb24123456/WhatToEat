# Prime StoreKit 最小闭环 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 WhatToEat Prime 从本地模拟会员状态切换为 StoreKit 2 驱动的最小真实付费闭环，覆盖商品加载、购买、恢复购买与会员状态判定。

**Architecture:** 新增一个 `StoreKit 2` 会员中心作为单一状态源，负责加载商品、监听交易更新、恢复购买与同步当前授权。`ProfileView` 和 `AppLockManager` 不再依赖本地模拟会员状态，而是只消费统一的 Prime 授权结果。当前“限时 5 折”营销 UI 从真实扣费链路中剥离，价格展示优先使用 App Store 商品返回值。

**Tech Stack:** SwiftUI, StoreKit 2, Swift Concurrency, ObservableObject, UserDefaults（仅保存 UI 选择，不保存会员真状态）

---

### Task 1: 建立 StoreKit 2 会员状态中心

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/PrimeStoreKitManager.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/PrimeAccessManager.swift`

**Step 1: 写最小的产品与授权模型**

- 定义 3 个商品 ID：
  - `com.pigdog.WhatToEat.prime.monthly`
  - `com.pigdog.WhatToEat.prime.yearly`
  - `com.pigdog.WhatToEat.prime.lifetime`
- 定义 `PrimeEntitlementState`，至少包含：
  - 是否有效
  - 当前有效方案
  - 是否正在加载商品
  - 商品列表
  - 最近错误信息

**Step 2: 实现商品拉取**

- 使用 `Product.products(for:)`
- 将返回值映射到 `monthly/yearly/lifetime`
- 对商品缺失、网络失败、后台未配置分别给出可展示错误

**Step 3: 实现交易监听与当前授权同步**

- 使用 `Transaction.updates`
- 使用 `Transaction.currentEntitlements`
- 对已验证交易做：
  - 自动续费订阅授权判定
  - 非消耗型永久买断授权判定
  - lifetime 优先级高于 monthly/yearly

**Step 4: 保留 `PrimeAccessManager` 为兼容层或替换成真实状态外观**

- 如果保留：
  - 让它转发到 `PrimeStoreKitManager`
- 如果替换：
  - 清理本地模拟 `activate/restore` 行为

**Step 5: 最小测试**

Run: `xcodebuild -project /Users/papertiger/Desktop/WhatToEat/WhatToEat.xcodeproj -scheme WhatToEat -destination 'platform=iOS Simulator,name=iPhone 17' build`

Expected:
- 编译通过
- 不再依赖本地模拟 Prime 状态

### Task 2: 接入购买、恢复购买与错误处理

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/PrimeStoreKitManager.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`

**Step 1: 实现购买**

- 针对选中的 `Product` 调用 `purchase()`
- 处理 4 种结果：
  - success + verified
  - success + unverified
  - pending
  - userCancelled

**Step 2: 实现恢复购买**

- 使用 `AppStore.sync()`
- 之后刷新 `currentEntitlements`
- 将结果反馈到 UI toast

**Step 3: 剥离营销价与真实支付价**

- 价格卡优先显示 `Product.displayPrice`
- 当前 30 分钟倒计时与“5 折”仅作为营销展示时，必须明确不参与真实扣费
- 如果商品未加载成功，价格卡展示“待配置”或降级态，不展示硬编码真实价格

**Step 4: 会员页接真实状态**

- CTA 文案根据状态更新：
  - 未购买：购买
  - 已购买：显示已开通或引导管理
- 恢复购买按钮接入真实 restore
- 商品未加载时禁用购买按钮并给出提示

**Step 5: 最小测试**

Run: `xcodebuild -project /Users/papertiger/Desktop/WhatToEat/WhatToEat.xcodeproj -scheme WhatToEat -destination 'platform=iOS Simulator,name=iPhone 17' build`

Expected:
- 购买和恢复逻辑可编译
- UI 不再依赖硬编码价格作为真实支付来源

### Task 3: 用真实会员状态接管 Face ID 与会员功能门槛

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/AppLockManager.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`

**Step 1: 让 Face ID 只依赖真实授权**

- `isFaceIDEnabled` 判定基于真实 Prime 授权
- 非会员时即使本地残留开关，也不应触发冷启动锁

**Step 2: 设置页改为真实锁定态**

- 未购买：显示 `Prime 专属`
- 已购买但未登录 Apple ID：显示禁用态与说明
- 已购买且设备支持：显示真实 Toggle

**Step 3: 会员页权益和状态提示同步**

- 已购买时显示当前方案名称
- 未购买时显示营销态

**Step 4: 最小测试**

Run: `xcodebuild -project /Users/papertiger/Desktop/WhatToEat/WhatToEat.xcodeproj -scheme WhatToEat -destination 'platform=iOS Simulator,name=iPhone 17' build`

Expected:
- Face ID 会员门槛与 Prime 状态一致
- 会员页与设置页不再状态冲突

### Task 4: 明确无法在当前环境完成的外部依赖

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/docs/plans/2026-03-08-prime-storekit-minimal-closure.md`

**Step 1: 记录外部前置条件**

- App Store Connect 创建商品
- 订阅组配置
- 本地 StoreKit Configuration 或沙盒账号
- Developer Program 开通后再做真链路验证

**Step 2: 记录当前可完成与不可完成边界**

- 代码可以完成
- 真购买验证无法在当前账号条件下闭环

