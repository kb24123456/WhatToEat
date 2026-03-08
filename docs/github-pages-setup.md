# WhatToEat GitHub Pages 发布说明

## 目录结构

当前仓库已经准备好可直接用于 GitHub Pages 的静态目录：

- `/docs/index.html`
- `/docs/privacy/index.html`
- `/docs/support/index.html`
- `/docs/styles.css`
- `/docs/.nojekyll`

## 发布方式

根据 GitHub 官方文档，仓库可以直接从某个分支的根目录 `/` 或 `/docs` 目录发布。  
官方参考：

- [Quickstart for GitHub Pages](https://docs.github.com/en/pages/quickstart)
- [Configuring a publishing source for your GitHub Pages site](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)

## 推荐设置

1. 打开 GitHub 仓库
2. 进入 `Settings`
3. 打开 `Pages`
4. 在 `Build and deployment` 中：
   - `Source` 选择 `Deploy from a branch`
   - `Branch` 选择你的主分支
   - `Folder` 选择 `/docs`
5. 保存后等待 GitHub Pages 发布完成

## URL 对应关系

当前仓库 `https://github.com/kb24123456/WhatToEat` 在启用 GitHub Pages 并选择 `/docs` 作为发布目录后，URL 一般会是：

- 首页：`https://kb24123456.github.io/WhatToEat/`
- 隐私政策：`https://kb24123456.github.io/WhatToEat/privacy/`
- 支持与联系：`https://kb24123456.github.io/WhatToEat/support/`

## App Store Connect 填写建议

- `Privacy Policy URL`：填写 `https://kb24123456.github.io/WhatToEat/privacy/`
- `Support URL`：填写 `https://kb24123456.github.io/WhatToEat/support/`

## 发布后建议

- 手动打开隐私政策页和支持页，确认能公开访问
- 确认邮箱和小红书链接可点击
- 若后续更换为独立域名，可保留相同路径结构，避免频繁修改 App Store Connect 中的 URL
