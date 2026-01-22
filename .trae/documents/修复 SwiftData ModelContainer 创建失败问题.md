## 问题分析

应用启动时崩溃，错误信息：`Could not create ModelContainer: SwiftDataError._Error`

**根本原因**：SwiftData 模型关系配置不完整
- `Restaurant` 类有一个 `@Relationship(deleteRule: .cascade) var logs: [VisitLog] = []` 关系
- 但 `VisitLog` 类中**缺少**对应的反向关系，导致 SwiftData 无法正确构建模型图

## 修复方案

在 `VisitLog.swift` 中添加完整的反向关系定义：

1. **添加关系属性**：在 `VisitLog` 类中添加指向 `Restaurant` 的反向关系
2. **更新初始化方法**：在 `init` 方法中初始化新增的关系属性
3. **确保关系一致性**：使用 `@Relationship(inverse: \.logs)` 指定正确的反向属性名

## 修改内容

### VisitLog.swift

```swift
// 在第14行后添加关系属性
@Relationship(inverse: \.logs) var restaurant: Restaurant?

// 在init方法中添加初始化
init(date: Date = Date(), expense: Double = 0.0, peopleCount: Int = 1, goodDishes: String = "", badDishes: String = "", review: String = "", photoFilename: String? = nil, restaurant: Restaurant? = nil) {
    self.id = UUID()
    self.date = date
    self.expense = expense
    self.peopleCount = max(1, peopleCount)
    self.goodDishes = goodDishes
    self.badDishes = badDishes
    self.review = review
    self.photoFilename = photoFilename
    self.restaurant = restaurant
}
```

## 预期效果

✅ ModelContainer 能够成功创建
✅ 应用启动正常
✅ SwiftData 关系正确建立
✅ 不会影响现有功能

## 风险评估

- **低风险**：仅添加关系定义，不修改现有逻辑
- **向后兼容**：新属性有默认值，不影响现有数据
- **符合 SwiftData 最佳实践**：完整的双向关系定义是 SwiftData 的要求

## 修复优先级

**高优先级**：这是导致应用崩溃的核心问题，必须立即修复