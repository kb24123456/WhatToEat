# WhatToEat Cloudflare Worker Proxy

## 作用

这个 Worker 为 iOS 客户端提供 3 个代理接口：

- `GET /v1/fortune/lunar?date=yyyy-MM-dd`
- `GET /v1/fortune/constellation?consName=射手座&type=today`
- `POST /v1/food-fortune/generate`

客户端继续调用这些路径，不需要感知第三方密钥，也不需要直连 Doubao / Juhe。

## 本地开发

1. 安装依赖

```bash
cd /Users/papertiger/Desktop/WhatToEat/backend/cloudflare-worker
npm install
```

2. 复制环境变量模板

```bash
cp .dev.vars.example .dev.vars
```

3. 填入第三方密钥

```bash
DOUBAO_API_KEY=...
DOUBAO_ENDPOINT_ID=...
JUHE_LUNAR_API_KEY=...
JUHE_CONSTELLATION_API_KEY=...
APP_PROXY_TOKEN=...
```

4. 本地运行

```bash
npm run dev
```

## Cloudflare 上线

1. 登录 Cloudflare

```bash
npx wrangler login
```

2. 设置生产 Secrets

```bash
npx wrangler secret put DOUBAO_API_KEY
npx wrangler secret put DOUBAO_ENDPOINT_ID
npx wrangler secret put JUHE_LUNAR_API_KEY
npx wrangler secret put JUHE_CONSTELLATION_API_KEY
npx wrangler secret put APP_PROXY_TOKEN
```

3. 部署

```bash
npm run deploy
```

部署完成后会得到一个类似下面的域名：

```text
https://whattoeat-api.<your-subdomain>.workers.dev
```

## iOS 客户端配置

把 [Config.xcconfig](/Users/papertiger/Desktop/WhatToEat/WhatToEat/Config/Config.xcconfig) 中的：

```xcconfig
BACKEND_BASE_URL =
```

改成：

```xcconfig
BACKEND_BASE_URL = https://whattoeat-api.<your-subdomain>.workers.dev
BACKEND_PROXY_TOKEN = your_app_proxy_token
```

## 说明

- `GET` 运势接口在边缘做了基础缓存。
- `POST` AI 食签接口不缓存。
- `/v1/*` 接口支持基于 token 的最小鉴权。
- 上游第三方请求已增加统一超时与 502/504 错误映射。
- Worker 返回格式已对齐当前 iOS 客户端，不需要再改客户端接口模型。
