## 问题分析
SwiftData ModelContainer创建失败是由于模型架构变更（Restaurant模型添加了city属性）导致的持久化存储不兼容引起的。当isStoredInMemoryOnly设置为false时，系统尝试使用旧的数据库文件，但该文件的模型架构与当前代码不匹配。

## 解决方案
我将采用以下步骤彻底解决这个问题：

### 1. 实现数据库重置机制
- 在WhatToEatApp.swift中添加数据库重置逻辑
- 当检测到ModelContainer创建失败时，自动删除旧的数据库文件并重新创建

### 2. 优化ModelContainer初始化
- 使用更健壮的错误处理机制
- 添加日志记录以便调试
- 确保模型架构的一致性

### 3. 验证修复效果
- 运行应用，确认ModelContainer能够成功创建
- 测试持久化存储功能是否正常工作
- 验证餐厅数据的增删改查功能

## 代码修改计划

### WhatToEatApp.swift
```swift
// 修改sharedModelContainer初始化代码
var sharedModelContainer: ModelContainer = {
    let schema = Schema([Restaurant.self, VisitLog.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        // 尝试重置数据库
        if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("WhatToEat") {
            try? FileManager.default.removeItem(at: url)
        }
        // 重新创建ModelContainer
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer after reset: \(error)")
        }
    }
}()
```

## 预期结果
- 应用能够成功启动，不再崩溃
- ModelContainer能够成功创建
- 持久化存储功能正常工作
- 餐厅数据能够正确保存和读取

## 后续优化建议
- 在正式发布版本中，实现SwiftData的迁移策略
- 添加数据备份和恢复功能
- 优化模型设计，减少未来架构变更的可能性