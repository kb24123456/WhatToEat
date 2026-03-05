# 食签API模块

## 概述

本模块负责接入聚合数据（Juhe）的老黄历API和星座运势API，为AI生成食签提供真实数据支持。

## API配置

### 1. 申请API Key

需要申请两个独立的API：

#### 老黄历API
- 申请地址：https://www.juhe.cn/docs/api/id/65
- 免费额度：100次/天
- 提供数据：干支、宜忌、节气、建除十二神等

#### 星座运势API
- 申请地址：https://www.juhe.cn/docs/api/id/58
- 免费额度：100次/天
- 提供数据：运势分值、幸运色、幸运数字等

### 2. 配置文件

**⚠️ 重要安全提示：永远不要将真实API Key提交到Git！**

#### 步骤：

1. 复制模板文件：
```bash
cd /Users/papertiger/Desktop/WhatToEat/WhatToEat/Fortune
cp FortuneAPIConfig.example.swift FortuneAPIConfig.swift
```

2. 编辑 `FortuneAPIConfig.swift`，填入你的API Keys：

```swift
// 老黄历API Key
static let lunarCalendarKey: String = "你的真实Key"

// 星座运势API Key
static let constellationKey: String = "你的真实Key"
```

3. 确认 `.gitignore` 包含：
```
WhatToEat/Fortune/FortuneAPIConfig.swift
```

## 架构说明

### 数据流

```
[FortuneAPIConfig] 配置管理
       ↓
[JuheAPIService] API封装
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
2. 无缓存时显示服务不可用提示
3. 不会使用模拟数据，确保真实性

## 安全建议

1. **API Key保护**
   - 永远不要提交到Git
   - 定期更换Key
   - 在聚合数据后台设置IP白名单

2. **访问频率控制**
   - 使用缓存减少API调用
   - 监控每日调用次数（免费额度内）

3. **错误处理**
   - API失败时优雅降级
   - 记录错误日志便于排查

## 更新日志

### 2024-03-03
- 初始版本
- 支持聚合数据老黄历和星座运势API
- 实现双API Key配置
- 添加数据聚合层和缓存机制
- 集成熵值机制增加多样性
