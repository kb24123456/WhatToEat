# Profile Data Preview Unification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一“我的数据”展开页 8 张预览态卡片的高度与骨架，修正文案错误，并在保证内容完整的前提下提升信息效率。

**Architecture:** 继续沿用现有 `ExpandableCard` 结构，不改展开态交互，只收口预览态内容与 `cardSizes`。通过统一卡片高度、统一三段式排版骨架、压缩低价值装饰信息来提升一致性。保留“常去餐厅”“美食足迹”的对象感，但让其仍服从统一骨架。

**Tech Stack:** SwiftUI, existing `ExpandableCard`, `ProfileView`, preview card views under `ProfileCards/`

---

### Task 1: 统一预览卡高度来源

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileView.swift`

**Step 1: 将 8 张数据卡的 `cardSizes` 统一成同一预览高度**
- 修改 `stats / consumption / tags / cuisine / categories / restaurants / timeline / zodiac` 的高度定义为统一值。
- 保持不改动详情页逻辑和卡片 ID。

**Step 2: 保证统一高度下布局仍能完整显示**
- 如某张卡在统一高度下内容溢出，则回到对应 Preview 组件调整排版密度，而不是再放宽高度。

### Task 2: 统一预览态骨架与文案

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCards/StatsCard.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCards/ConsumptionCard.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCards/CategoriesCard.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCards/TagsCard.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCards/CuisinePreferenceCard.swift`
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCards/RemainingCards.swift`

**Step 1: 统一预览卡的三段式骨架**
- 顶部：统一标题样式
- 中部：统一主信息块（主数值 / 主对象）
- 底部：统一为一行辅助信息或简洁标签

**Step 2: 修正错误文案**
- 将 `消费洞察` 预览态的“本月消费”改为“总消费”。

**Step 3: 删除低信息密度元素**
- 删除或替换“常去餐厅”的底部排名圆点
- 删除或替换“美食足迹”的 3 个小圆点
- 压缩“我的标签 / 我的品类 / 餐饮偏好”底部标签流，避免撑高和显得杂乱

**Step 4: 保留有限个性化表达**
- `常去餐厅`：保留具体餐厅名称与去过次数
- `美食足迹`：保留最近一次记录的餐厅与日期
- `味蕾星盘`：保留但降低存在感，避免破坏数据页整体节奏

### Task 3: 验证与收口

**Files:**
- Modify if needed: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/ProfileCards/*.swift`

**Step 1: 构建验证**
Run: `xcodebuild -project /Users/papertiger/Desktop/WhatToEat/WhatToEat.xcodeproj -scheme WhatToEat -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `BUILD SUCCEEDED`

**Step 2: 视觉检查要点**
- 8 张预览卡高度完全一致
- 没有明显多余留白
- 没有标题或主信息被截断
- `消费洞察` 文案已修正为“总消费”
- `常去餐厅 / 美食足迹` 仍保留对象识别度
