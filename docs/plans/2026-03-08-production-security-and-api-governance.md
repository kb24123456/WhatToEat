# Production Security And API Governance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在不引入服务端仓库的前提下，完成 WhatToEat 客户端的上架前生产安全收口与接口治理重构。

**Architecture:** 客户端不再持有任何第三方生产密钥，所有 AI/运势网络能力统一改为“应用后端代理优先”的接入模型；本地敏感标识与迁移载荷迁移到 Keychain / 受保护文件；生产日志统一收敛到可控的 `OSLog` 封装。对于当前仓库外的服务端能力，客户端改为安全降级而不是继续直连第三方。

**Tech Stack:** SwiftUI, SwiftData, AuthenticationServices, StoreKit, Security, OSLog, Foundation

---

### Task 1: 安全基础设施

**Files:**
- Create: `WhatToEat/AppLogger.swift`
- Create: `WhatToEat/KeychainStore.swift`
- Create: `WhatToEat/ProtectedFileStore.swift`

**Step 1:** 新增统一日志包装，Release 禁止调试噪音。

**Step 2:** 新增 Keychain 读写工具，承载账号标识与个人敏感偏好。

**Step 3:** 新增受保护文件存储，承载迁移载荷等不适合放在 `UserDefaults` 的数据。

### Task 2: 配置与网络治理

**Files:**
- Modify: `WhatToEat/AppConfig.swift`
- Modify: `WhatToEat/Fortune/FortuneAPIConfig.swift`
- Create: `WhatToEat/AppHTTPClient.swift`
- Modify: `WhatToEat/Info.plist`

**Step 1:** 把配置模型改为“后端代理 URL + 路径”的非密钥配置。

**Step 2:** 统一 HTTP 调用、状态码校验、超时与错误映射。

**Step 3:** 删除包内第三方密钥入口，保留可安全提交的代理配置项。

### Task 3: 业务代码接入安全配置

**Files:**
- Modify: `WhatToEat/AICopywritingManager.swift`
- Modify: `WhatToEat/Fortune/Services/JuheAPIService.swift`
- Modify: `WhatToEat/Fortune/Services/FortuneDataAggregator.swift`
- Modify: `WhatToEat/NavigationManager.swift`

**Step 1:** AI 食签改为请求应用后端代理；未配置代理时自动降级到本地默认食签。

**Step 2:** 黄历/星座接口改为应用后端代理；未配置代理时只使用缓存并返回可解释错误。

**Step 3:** 收敛原始响应日志与错误日志，避免生产泄露响应片段。

**Step 4:** 将 Apple Maps 外链从 `http` 改为 `https`。

### Task 4: 敏感存储迁移

**Files:**
- Modify: `WhatToEat/AuthManager.swift`
- Modify: `WhatToEat/ZodiacUtil.swift`
- Modify: `WhatToEat/CloudSyncManager.swift`
- Modify: `WhatToEat/AppSettingsKeys.swift`

**Step 1:** Apple 登录标识与展示名迁移到 Keychain。

**Step 2:** 生日/星座迁移到 Keychain。

**Step 3:** iCloud 迁移载荷迁移到受保护文件并清理旧 `UserDefaults` 数据。

### Task 5: 文档与示例配置

**Files:**
- Modify: `WhatToEat/Config/Config.example.xcconfig`
- Modify: `WhatToEat/Config/Config.xcconfig`
- Modify: `WhatToEat/AppConfig.example.swift`
- Modify: `WhatToEat/Fortune/FortuneAPIConfig.example.swift`
- Modify: `WhatToEat/Fortune/README.md`

**Step 1:** 用“后端代理配置”替换旧“第三方密钥模板”说明。

**Step 2:** 明确服务端契约与客户端降级行为。

### Task 6: 验证

**Files:**
- Modify: `WhatToEat.xcodeproj/project.pbxproj`（仅在需要时）

**Step 1:** 执行 `xcodebuild` 构建验证。

**Step 2:** 若发现编译问题，最小化修复并再次验证。
