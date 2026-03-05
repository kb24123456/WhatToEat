# WhatToEat Git 快速使用

本仓库已完成：
- 远程仓库关联：`origin -> https://github.com/kb24123456/WhatToEat.git`
- 当前分支：`main`（跟踪 `origin/main`）
- 本地安全脚本：`scripts/git-safe.sh`
- 快捷别名：`git snap` / `git save` / `git undo` / `git rollback` / `git tagv`

## 1. 最常用命令

```bash
# 查看状态
git st

# 本地做一个快照提交（包含所有改动）
git snap "feat: 深色模式细节优化"

# 快照并推送（推荐日常用这个）
git save "feat: 深色模式细节优化"
```

## 2. 一键撤回错误修改（安全方式）

```bash
# 撤回最近一次提交（生成一个新的“反向提交”）
git undo

# 撤回某个历史提交（不会改写历史）
git rollback <commit-hash>
```

说明：这里用的是 `git revert`，不会用 `reset --hard`，风险更低。

## 3. 版本打点（便于随时找回）

```bash
# 在当前版本打标签并推送
git tagv v2026-03-05-dark-ui
```

之后可在任意机器上通过 tag 找回该版本。

## 4. 推荐工作流（避免“改坏后难回滚”）

1. 开始改动前先快照：`git snap "wip: before ui tuning"`
2. 每个小阶段完成后再 `git snap` 一次
3. 当阶段稳定时 `git save` 推到 GitHub
4. 如果某次改坏，执行 `git undo` 立即回滚

