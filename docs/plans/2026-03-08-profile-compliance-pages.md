# Profile Compliance Pages Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在“功能设置”中补齐可提审使用的 App 内合规入口，包括隐私政策、支持与联系、会员说明、删除账户说明，以及仅解除 Apple ID 关联的删除账户流程。

**Architecture:** 复用现有 `ProfileView` 的设置面板作为入口承载层，在页面尾部增加小字合规链接，并通过 SwiftUI 导航推入新的合规说明页。账户删除不新增服务端逻辑，只在本地清除 Apple ID 关联与本地安全状态，同时保留餐厅与打卡数据。

**Tech Stack:** SwiftUI, NavigationStack, ObservableObject, UserDefaults, AuthenticationServices

---

### Task 1: 规划合规入口与页面结构

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCompliancePages.swift`

**Step 1: 明确入口位置**

- 在 `settingsDashboard` 末尾增加一组小字入口：
  - 隐私政策
  - 支持与联系
  - 会员说明
  - 删除账户说明
- 保持入口在界面尾部，视觉权重低于主要设置项。

**Step 2: 规划页面骨架**

- 新建一个轻量复用页面骨架：
  - 顶部标题
  - 更新时间
  - 多段正文
  - 可选的联系方式区块
  - 可选的破坏性操作区块

**Step 3: 规划导航方式**

- 使用现有 `NavigationStack`，通过 `NavigationLink` 直接 push，不引入 sheet。

### Task 2: 实现 App 内合规文案页面

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCompliancePages.swift`

**Step 1: 编写隐私政策首版中文文案**

- 覆盖以下内容：
  - 收集的数据类型
  - 数据如何使用
  - iCloud/同步说明
  - 第三方服务说明
  - 用户控制与删除说明

**Step 2: 编写支持与联系首版中文文案**

- 明确展示：
  - 邮箱：`357831193@qq.com`
  - 小红书：`https://xhslink.com/m/9qcmtV4wkKg`
- 说明用途：
  - Bug 反馈
  - 功能建议
  - 商务或合作联系

**Step 3: 编写会员说明首版中文文案**

- 覆盖：
  - Prime 核心权益
  - 月付 / 年付 / 永久 的产品类型说明
  - 价格以 App Store 真实支付页为准
  - 恢复购买与会员状态说明

**Step 4: 编写删除账户说明首版中文文案**

- 明确说明：
  - 删除的是 Apple ID 关联
  - 不删除本地餐厅、打卡、消费数据
  - 关闭面容 ID 锁定
  - 可再次重新登录 Apple ID

### Task 3: 设置页接入尾部小字入口

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`

**Step 1: 在设置面板尾部新增合规入口区**

- 放在“权限与支持”卡片下方
- 使用较小字号和较弱层级
- 保持可点击区域足够大，避免审核时不好点按

**Step 2: 将入口分别接入对应页面**

- 隐私政策 -> 隐私政策页
- 支持与联系 -> 支持与联系页
- 会员说明 -> 会员说明页
- 删除账户说明 -> 删除账户说明页

### Task 4: 实现删除账户关联流程

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/AuthManager.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/AppLockManager.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`

**Step 1: 在 `AuthManager` 增加删除账户关联方法**

- 清除：
  - `appleUserID`
  - `appleUserDisplayName`
- 保留：
  - 本地餐厅与打卡数据

**Step 2: 清除本地安全状态**

- 删除账户关联后，关闭面容 ID 开关
- 避免残留安全状态导致重新打开 App 时逻辑不一致

**Step 3: 在删除账户说明页提供确认操作**

- 增加破坏性按钮：
  - `删除 Apple ID 账户关联`
- 增加二次确认 alert
- 成功后回到设置页并给出 toast/提示

### Task 5: 验证与回归

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCompliancePages.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/AuthManager.swift`

**Step 1: 构建验证**

Run:

```bash
xcodebuild -project /Users/papertiger/Desktop/WhatToEat/WhatToEat.xcodeproj -scheme WhatToEat -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected:

```text
BUILD SUCCEEDED
```

**Step 2: 手动回归**

- 打开“我的 -> 功能设置”
- 确认尾部可看到 4 个小字合规入口
- 确认 4 个页面均可正常进入
- 登录 Apple ID 后打开删除账户说明页，执行删除账户关联
- 确认：
  - Apple ID 状态变为未登录
  - 本地餐厅与打卡仍在
  - Face ID 开关被关闭

