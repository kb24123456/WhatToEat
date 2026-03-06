# Settings Panel Material Animation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让“功能设置”菜单卡片材质、深色模式适配和头像/名片收展动画与当前数据卡片体系保持一致且更顺滑。

**Architecture:** 仅修改 `ProfileView.swift` 的设置面板和头部呈现层，不调整现有设置项行为。通过新增语义化设置面板 token、统一卡片材质 modifier、替换行内容器背景、以及重构头部/设置面板 transition，实现视觉统一和低风险落地。

**Tech Stack:** SwiftUI, AppTheme, iOS material/background APIs, spring animation

---

### Task 1: 审核设置面板视觉债务

**Files:**
- Modify: `WhatToEat/ProfileView.swift`
- Reference: `WhatToEat/AppTheme.swift`

**Step 1: 找出浅色硬编码与行级容器背景**
- 关注 `settingsSectionCard`、`settingsValueRow`、`settingsActionButton`、`accountStatusRow`、`appearanceModeSegmentedRow`。

**Step 2: 定义最小 token 集**
- 为设置面板补充卡片背景、描边、高光、行文字、胶囊按钮背景等语义色。

### Task 2: 改造设置卡片材质

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: 将 section 卡片改成参考图风格**
- 使用更柔和的浅色/深色奶油材质。
- 保留细描边和轻阴影，不引入新功能按钮形态。

**Step 2: 移除行内独立容器背景**
- 行本身只保留排版、图标圆底、必要的分隔留白。
- 选中态胶囊和顶部切换控件维持必要承载，但不再包裹一层行背景卡片。

### Task 3: 动画统一

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: 设置面板入场动画对齐数据卡片风格**
- 用 spring + scale/offset/opacity 的连续过渡替换当前单纯 blur-slide。

**Step 2: 头像图片与名片收起/展开改为连续收展**
- 避免仅靠淡入淡出。
- 让 compact/expanded 头部都体现“折叠/展开”的位移与缩放感。

### Task 4: 验证

**Files:**
- Modify: `WhatToEat/ProfileView.swift`

**Step 1: 编译检查**
- 运行针对项目的 `xcodebuild` 或至少做 Swift 级编译验证。

**Step 2: 手动检查点**
- 浅色/深色模式下设置卡片边界、文字层级、按钮可读性。
- 设置页展开时卡片入场是否连续。
- 头像+名片在展开/收起时是否表现为收展，而不是硬切或纯淡入淡出。
