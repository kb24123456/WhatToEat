# Cloudflare Worker Proxy Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 WhatToEat 提供可上线的 Cloudflare Workers 后端代理，对齐现有 iOS 客户端的 3 个接口契约且不改变功能表现。

**Architecture:** 在仓库内新增一个独立的 Workers 项目，负责代理 Doubao 与 Juhe 第三方接口，并在边缘侧做基础超时、错误映射、GET 缓存与 JSON 清洗。iOS 客户端继续调用既有 3 个代理路径，不感知第三方密钥与第三方域名。

**Tech Stack:** Cloudflare Workers, TypeScript, Wrangler, Fetch API

---

### Task 1: Worker 项目骨架

**Files:**
- Create: `backend/cloudflare-worker/package.json`
- Create: `backend/cloudflare-worker/tsconfig.json`
- Create: `backend/cloudflare-worker/wrangler.toml`
- Create: `backend/cloudflare-worker/src/index.ts`

**Step 1:** 创建独立 Worker 项目，避免污染 iOS 主工程。

**Step 2:** 定义生产环境变量与默认路由。

### Task 2: 实现 3 个代理接口

**Files:**
- Modify: `backend/cloudflare-worker/src/index.ts`

**Step 1:** 实现 `GET /v1/fortune/lunar`，返回与客户端兼容的 Juhe 黄历响应。

**Step 2:** 实现 `GET /v1/fortune/constellation`，返回与客户端兼容的 Juhe 星座响应。

**Step 3:** 实现 `POST /v1/food-fortune/generate`，内部调用 Doubao 并输出 `DailyFoodFortune` JSON。

### Task 3: 文档与部署说明

**Files:**
- Create: `backend/cloudflare-worker/.dev.vars.example`
- Create: `backend/cloudflare-worker/README.md`
- Modify: `WhatToEat/Config/Config.example.xcconfig`

**Step 1:** 说明本地开发、Cloudflare Secret 配置、生产部署命令。

**Step 2:** 明确客户端需要填写的 `BACKEND_BASE_URL`。

### Task 4: 验证

**Files:**
- Modify: `backend/cloudflare-worker/package-lock.json`（若安装依赖）

**Step 1:** 安装依赖并执行类型检查或 dry run。

**Step 2:** 若本机有 Cloudflare 登录态，再尝试实际部署；否则保留可部署产物并输出所需支持。
