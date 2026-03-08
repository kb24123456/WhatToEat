# 食签API模块

## 概述

本模块负责通过应用后端代理接入黄历与星座运势接口，为 AI 生成食签提供真实数据支持。

## API配置

### 1. 安全原则

- 客户端不持有任何第三方生产密钥。
- 客户端只知道自有后端代理地址。
- 第三方 API Key 仅存在于服务端环境变量或密钥管理系统中。

### 2. 客户端配置文件

#### 步骤：

1. 复制模板文件：
```bash
cp /Users/papertiger/Desktop/WhatToEat/WhatToEat/Config/Config.example.xcconfig \
   /Users/papertiger/Desktop/WhatToEat/WhatToEat/Config/Config.xcconfig
```

2. 配置后端代理地址：

```xcconfig
BACKEND_BASE_URL = https://api.example.com
BACKEND_AI_FORTUNE_PATH = /v1/food-fortune/generate
BACKEND_FORTUNE_LUNAR_PATH = /v1/fortune/lunar
BACKEND_FORTUNE_CONSTELLATION_PATH = /v1/fortune/constellation
```

3. 确认 `.gitignore` 包含：
```
WhatToEat/Config/Config.xcconfig
```

## 架构说明

### 数据流

```
[AppEnvironment / JuheAPIConfig] 代理配置管理
       ↓
[JuheAPIService] 后端代理封装
  ├─ fetchLunarCalendar() - 获取黄历数据
  └─ fetchZodiacFortune() - 获取星座数据
       ↓
[FortuneDataAggregator] 数据聚合
  ├─ 并行获取黄历和星座数据
  ├─ 生成创意主题（熵值）
  └─ 构建FortuneGenerationContext
       ↓
[AI文案生成] 使用真实数据生成食签
```

### 缓存策略

| 数据类型 | 缓存时长 | 说明 |
|---------|---------|------|
| 黄历数据 | 24小时 | 每天只需获取一次 |
| 星座数据 | 6小时 | 支持用户当天内多次刷新 |

### 降级策略

当API调用失败时：
1. 优先使用缓存数据（即使已过期）
2. 无缓存时由上层降级到默认食签
3. 不会把第三方原始响应明文打到生产日志

## 安全建议

1. **密钥保护**
   - 第三方 API Key 只放服务端
   - 本仓库只保留后端代理地址
   - 历史已暴露的第三方密钥必须立即轮换

2. **访问频率控制**
   - 客户端使用缓存减少请求
   - 服务端负责限流、熔断、告警与审计

3. **错误处理**
   - 代理失败时优雅降级
   - 生产日志不记录原始响应体

## 更新日志

### 2026-03-08
- 客户端改为后端代理接入模型
- 删除第三方密钥客户端入口
- 新增缓存优先与安全降级说明
