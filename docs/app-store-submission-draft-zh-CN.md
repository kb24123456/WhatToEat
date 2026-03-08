# WhatToEat App Store 上架资料草稿（中国大陆）

> 适用范围：App Store Connect 首发资料准备  
> 当前日期：2026 年 3 月 8 日  
> 面向市场：中国大陆

---

## 一、先说结论

当前这份草稿已经覆盖了你首发最需要补的两类内容：

1. App Store 产品页文案
2. App Privacy 问卷首版填写建议

但有两个边界我不能假装已经完全确定：

- 你的 `Privacy Policy URL` 和 `Support URL` 还要等 GitHub Pages 真正发布后，才能替换成最终可提交地址
- `App Privacy` 里和外部 AI / 运势服务有关的数据项，我给的是**保守且偏审核安全**的填法；上线前你最好再对照实际发布版本做一次最终确认

---

## 二、已确认事实

以下内容来自当前代码库，可作为填写依据：

- App 名称当前可用名：`WhatToEat`
- Bundle ID：`com.pigdog.WhatToEat`
- 当前版本号：`1.0`
- 核心能力：
  - 餐厅记录
  - 打卡与消费记录
  - 标签与品类整理
  - 美食地图
  - 图片选择/拍摄
  - Apple ID 登录
  - iCloud 同步
  - Prime 会员
  - Face ID（Prime 专属）
- 当前代码里存在的外部/云端能力：
  - Apple Sign in
  - StoreKit 2
  - CloudKit / iCloud
  - AI 食签请求
  - 聚合数据运势接口

代码依据：

- [project.pbxproj](/Users/papertiger/Desktop/WhatToEat/WhatToEat.xcodeproj/project.pbxproj)
- [WhatToEatApp.swift](/Users/papertiger/Desktop/WhatToEat/WhatToEat/WhatToEatApp.swift)
- [Info.plist](/Users/papertiger/Desktop/WhatToEat/WhatToEat/Info.plist)
- [AuthManager.swift](/Users/papertiger/Desktop/WhatToEat/WhatToEat/AuthManager.swift)
- [PrimeAccessManager.swift](/Users/papertiger/Desktop/WhatToEat/WhatToEat/PrimeAccessManager.swift)

---

## 三、URL 草稿

### 1. 发布后建议填写

如果你的 GitHub Pages 使用当前项目仓库发布，推荐填写：

- `Privacy Policy URL`  
  `https://kb24123456.github.io/WhatToEat/privacy/`

- `Support URL`  
  `https://kb24123456.github.io/WhatToEat/support/`

如果你后续改成独立域名，建议保持相同路径结构：

- `/privacy/`
- `/support/`

### 2. 对应静态页面

- [隐私政策页](/Users/papertiger/Desktop/WhatToEat/docs/privacy/index.html)
- [支持与联系页](/Users/papertiger/Desktop/WhatToEat/docs/support/index.html)
- [GitHub Pages 发布说明](/Users/papertiger/Desktop/WhatToEat/docs/github-pages-setup.md)

---

## 四、App Store 产品页文案草稿

### 1. App Name

推荐：

`WhatToEat`

说明：

- 事实：Apple 要求 App Name 不超过 30 个字符  
  来源：[App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- 推演：你当前品牌识别已经集中在 `WhatToEat`，首发不建议再临时加中文副标题，避免名称膨胀和搜索词浪费

### 2. Subtitle

推荐：

`记录餐厅与美食足迹`

备选：

- `你的个人美食记录库`
- `餐厅打卡与地图整理`

说明：

- 事实：Subtitle 不能超过 30 个字符  
  来源：[App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)

### 3. Promotional Text

推荐：

`用 WhatToEat 记录餐厅、打卡、消费与地图足迹。首发版本已支持 Prime 会员、iCloud 同步、导入导出与美食地图能力。`

说明：

- 事实：Promotional Text 最长 170 个字符，且可随时更新  
  来源：[Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-review-information)
- 事实：Apple 不建议在描述和元数据里写价格  
  来源：[Creating Your Product Page](https://developer.apple.com/app-store/product-page)

### 4. Keywords

推荐草稿：

`餐厅记录,美食地图,探店,打卡,消费统计,足迹,吃什么`

说明：

- 事实：关键词总长上限为 100 bytes  
  来源：[Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-review-information)
- 推演：这串关键词相对保守，避免重复品牌名、避免堆砌热门无关词

### 5. Description

推荐草稿：

`WhatToEat 是一款面向个人用户的美食记录工具，帮助你把吃过的餐厅、打卡记录、消费金额、标签偏好和地图足迹，沉淀成可长期保存的个人美食资产。`

`你可以在 WhatToEat 中收录餐厅、记录每一次打卡、整理标签与品类，并通过地图查看自己的美食分布与探索轨迹。对于长期使用者，App 还提供 iCloud 同步、导入导出、Prime 会员等进阶能力。`

`WhatToEat 适合这些场景：`

`• 记录自己吃过哪些餐厅，以及最常去的店`

`• 统计总消费、打卡次数与常吃品类`

`• 在地图中查看自己的探店足迹`

`• 用标签和备注沉淀长期的餐厅偏好`

`• 在更换设备后继续保留和整理自己的美食数据`

`首发版本已支持：`

`• 餐厅收录、编辑与删除`

`• 打卡、消费、图片与备注记录`

`• 美食地图与常去餐厅统计`

`• 标签、品类、偏好预览`

`• CSV 导入导出`

`• iCloud 同步`

`• Prime 会员与恢复购买`

`WhatToEat 由独立开发持续打磨。如果你希望把零散的探店记录沉淀成长期可回看的个人资产，这款 App 会是一个更适合长期使用的起点。`

说明：

- 事实：Description 最长 4000 个字符  
  来源：[Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-review-information)
- 推演：这版首段先讲“是什么”，中段讲“能做什么”，尾段讲“适合谁”，更符合 App Store 首屏阅读习惯

### 6. Primary / Secondary Category

推荐：

- Primary Category：`Food & Drink`
- Secondary Category：`Lifestyle`

说明：

- 推演：你的核心不是地图工具，也不是纯记账工具，而是美食记录与餐厅管理，`Food & Drink` 更准确

### 7. What’s New（1.0 首发）

推荐：

`WhatToEat 首个正式版本上线。`

`本次版本包含餐厅记录、打卡与消费管理、美食地图、标签与品类整理、iCloud 同步、CSV 导入导出，以及 Prime 会员首版能力。`

说明：

- 事实：Apple 要求 “What’s New” 要准确描述重要变化  
  来源：[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines)

### 8. 审核备注（Review Notes）草稿

推荐：

`1. App 支持基础餐厅记录、打卡、消费、地图与标签整理。`

`2. Apple ID 登录不是强制项；未登录用户也可使用基础记录功能。`

`3. Prime 会员相关能力通过 Apple 的 In-App Purchase / StoreKit 体系处理。`

`4. 隐私政策与支持页已公开提供，URL 可在 App Information 与 Platform Version Information 中查看。`

`5. App 内“功能设置”尾部也提供隐私政策、支持与联系、会员说明、删除账户说明入口。`

---

## 五、App Privacy 问卷草稿

## 总体建议

### 1. Tracking

推荐填写：

- `Does this app track users?` -> `No`

依据：

- 事实：当前代码中没有看到 AppTrackingTransparency、AdSupport、广告归因或跨 App/跨网站跟踪逻辑

### 2. 隐私问卷填写策略

我建议你采用 **保守且可解释** 的首版填法：

- 对已经确认会离开设备的数据，按 Apple 分类如实披露
- 对只在设备本地处理、未发送到服务器的数据，不主动勾选
- 对是否会发送到第三方 AI/运势接口、且口径存在不确定性的项，采用偏安全的“保守披露”原则

官方依据：

- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

---

## 六、推荐填写项

### A. Purchases（购买）

推荐填写：

- `Data Type`：Purchases
- `Collected`：Yes
- `Linked to the user`：Yes
- `Used for tracking`：No
- `Purpose`：App Functionality

原因：

- 事实：Prime 会员依赖 StoreKit 2 交易与恢复购买
- 推演：购买记录直接决定会员状态，属于 App 功能闭环

### B. Photos or Videos（照片或视频）

推荐填写：

- `Data Type`：Photos or Videos
- `Collected`：Yes
- `Linked to the user`：Yes
- `Used for tracking`：No
- `Purpose`：App Functionality

原因：

- 事实：用户可以在餐厅与打卡记录中选择或拍摄图片
- 事实：如果开启 iCloud，同步数据会离开设备
- 推演：保守填法应披露图片内容

### C. Other User Content（其他用户内容）

推荐填写：

- `Data Type`：Other User Content
- `Collected`：Yes
- `Linked to the user`：Yes
- `Used for tracking`：No
- `Purpose`：App Functionality

原因：

- 事实：App 允许用户记录备注、评价、推荐菜、不推荐菜、标签、餐厅信息、打卡与消费内容
- 事实：这些内容在开启同步后会进入 CloudKit
- 事实：Apple 对通用自由文本/用户保存内容建议用 `Other User Content` 表示  
  来源：[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

### D. Coarse Location（粗略位置）- 条件性推荐

推荐填写：

- `Data Type`：Coarse Location
- `Collected`：Yes
- `Linked to the user`：No
- `Used for tracking`：No
- `Purpose`：App Functionality

前提：

- 仅当你保留当前“把城市信息发送给 AI / 运势服务”的实现时，建议这样填

原因：

- 事实：当前 AI 食签上下文会包含 `city`
- 事实：Apple 将城市这类较低精度位置归入 Coarse Location  
  来源：[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- 不确定点：如果你发布前改掉这条云端请求，或城市信息只在设备本地使用，则这项可以重新评估

---

## 七、当前建议不要勾选的项

### 1. Precise Location

当前建议：

- `No`

原因：

- 事实：当前定位主要用于设备本地的距离计算、地图显示与导航发起
- 我没有在代码里确认到“精确定位被持续发送到你自己的服务器或第三方伙伴”的证据

### 2. Contact Info

当前建议：

- `No`

原因：

- 事实：虽然支持页展示了邮箱和小红书，但 App 内没有用户填写邮箱或手机号并上传的流程

### 3. User ID / Device ID

当前建议：

- `No`

原因：

- 事实：本地保存了 Apple ID 关联状态
- 不确定点：我没有在代码里确认它被作为你自己或第三方的数据收集项上传并长期保存
- 结论：现阶段不建议贸然勾选；上线前若你引入服务端账户体系，再重新评估

### 4. Diagnostics / Usage Data

当前建议：

- `No`

原因：

- 事实：当前代码里没有看到 Crashlytics、Sentry、埋点 SDK、广告分析 SDK

---

## 八、上线前必须二次确认的项

以下 3 项在你真正提审前，必须再对照发布版本检查一次：

1. **Coarse Location**
   - 如果 AI / 运势服务继续收到城市信息，建议保留
   - 如果你改成纯本地或不再传城市，可以删掉

2. **Photos or Videos / Other User Content**
   - 如果你首发版保留 iCloud 同步，建议保留披露
   - 如果你临时关闭同步并保证这些数据不离开设备，可重新评估

3. **Purchases**
   - 只要首发版继续保留 Prime 购买/恢复逻辑，就应该保留

---

## 九、你后续在 App Store Connect 中可以直接照着填的最小版本

### App Information

- Name：`WhatToEat`
- Subtitle：`记录餐厅与美食足迹`
- Privacy Policy URL：`https://kb24123456.github.io/WhatToEat/privacy/`

### Platform Version Information

- Promotional Text：使用本草稿第 4 节文本
- Description：使用本草稿第 4 节文本
- Keywords：`餐厅记录,美食地图,探店,打卡,消费统计,足迹,吃什么`
- Support URL：`https://kb24123456.github.io/WhatToEat/support/`
- What’s New：使用本草稿第 4 节文本
- Review Notes：使用本草稿第 4 节文本

### App Privacy

- Tracking：`No`
- Purchases：`Yes`
- Photos or Videos：`Yes`
- Other User Content：`Yes`
- Coarse Location：`Yes（如果保留城市外发）`

---

## 十、参考来源

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-review-information)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Creating Your Product Page](https://developer.apple.com/app-store/product-page)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines)
