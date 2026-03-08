# GitHub Pages Compliance Site Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 WhatToEat 生成一套可直接用于 GitHub Pages 发布的静态站点文件，至少包含隐私政策页、支持与联系页，以及用于审核与上架填写的稳定 URL 入口。

**Architecture:** 直接复用仓库现有 `/docs` 目录作为 GitHub Pages 发布源，在该目录下新增首页、隐私政策页、支持页和共享样式文件。页面采用纯静态 HTML/CSS，不依赖构建工具，确保后续只需在 GitHub 仓库设置中将 Pages 源指向 `/docs` 即可发布。

**Tech Stack:** Static HTML, CSS, GitHub Pages

---

### Task 1: 规划站点结构

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/index.html`
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/privacy/index.html`
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/support/index.html`
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/styles.css`
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/.nojekyll`

**Step 1: 选择直接可发布的目录**

- 采用仓库 `/docs` 目录作为 GitHub Pages 发布根目录
- 保留现有 `/docs/plans` 不动，不把计划文档暴露为导航入口

**Step 2: 定义审核友好的 URL 结构**

- 首页：`/`
- 隐私政策：`/privacy/`
- 支持与联系：`/support/`

### Task 2: 编写隐私政策页

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/privacy/index.html`
- Modify: `/Users/papertiger/Desktop/WhatToEat/docs/styles.css`

**Step 1: 写入可提审首版中文隐私政策**

- 覆盖：
  - 数据类型
  - 使用目的
  - 同步与存储
  - 权限说明
  - 第三方服务
  - 用户控制方式
  - 联系方式

**Step 2: 提供导航返回与页面更新时间**

- 顶部保留返回站点首页的入口
- 页内展示最后更新时间，便于审核识别

### Task 3: 编写支持与联系页

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/support/index.html`
- Modify: `/Users/papertiger/Desktop/WhatToEat/docs/styles.css`

**Step 1: 写入支持说明**

- 覆盖：
  - 问题反馈范围
  - 建议附带的信息
  - 响应说明

**Step 2: 展示联系信息**

- 邮箱：`357831193@qq.com`
- 小红书：`https://xhslink.com/m/9qcmtV4wkKg`

### Task 4: 编写首页与共享样式

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/index.html`
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/styles.css`

**Step 1: 编写首页**

- 明确 WhatToEat 是什么
- 提供两个审核所需入口：
  - 隐私政策
  - 支持与联系

**Step 2: 统一视觉风格**

- 采用克制、可信、可审核的静态页面视觉
- 保持移动端友好
- 避免复杂脚本和外部依赖

### Task 5: 补充发布说明

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/docs/github-pages-setup.md`

**Step 1: 写清楚 GitHub Pages 发布步骤**

- 仓库 Settings -> Pages
- Source 选择当前分支
- Folder 选择 `/docs`
- 发布后 URL 对应关系

### Task 6: 校验结果

**Files:**
- Verify: `/Users/papertiger/Desktop/WhatToEat/docs/index.html`
- Verify: `/Users/papertiger/Desktop/WhatToEat/docs/privacy/index.html`
- Verify: `/Users/papertiger/Desktop/WhatToEat/docs/support/index.html`
- Verify: `/Users/papertiger/Desktop/WhatToEat/docs/styles.css`

**Step 1: 校验文件结构**

Run:

```bash
find /Users/papertiger/Desktop/WhatToEat/docs -maxdepth 2 -type f | sort
```

Expected:

```text
/Users/papertiger/Desktop/WhatToEat/docs/.nojekyll
/Users/papertiger/Desktop/WhatToEat/docs/index.html
/Users/papertiger/Desktop/WhatToEat/docs/privacy/index.html
/Users/papertiger/Desktop/WhatToEat/docs/support/index.html
/Users/papertiger/Desktop/WhatToEat/docs/styles.css
```

**Step 2: 手动检查**

- 首页可打开
- `privacy` 与 `support` 相互可跳转
- 联系邮箱和小红书链接正确
- 文案不含占位文本

