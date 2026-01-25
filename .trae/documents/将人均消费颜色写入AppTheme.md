# 将人均消费颜色写入AppTheme

## 目标
将人均消费的颜色值#ff96a4添加到AppTheme中，实现颜色的集中管理和统一调用。

## 实现步骤

### 1. 在AppTheme.swift中添加人均消费颜色常量
在`AppTheme.Colors`结构体中添加一个新的颜色常量`price`，值为`#ff96a4`。

### 2. 更新LibraryView.swift中的颜色引用
将`LibraryView.swift`中硬编码的`Color(hex: "#ff96a4")`替换为`AppTheme.Colors.price`。

## 预期效果
- 所有人均消费文本的颜色将通过AppTheme统一管理
- 便于后续统一调整颜色方案
- 保持代码的可维护性和一致性

## 代码修改点

### 1. AppTheme.swift
```swift
struct Colors {
    // 现有颜色...
    static let price = Color(hex: "#ff96a4") // 人均消费颜色
    // 现有颜色...
}
```

### 2. LibraryView.swift
```swift
Text(priceText)
    .font(AppTheme.Fonts.footnote)
    .foregroundColor(AppTheme.Colors.price) // 替换硬编码颜色
```

## 验证方法
- 编译项目确保没有错误
- 运行应用查看人均消费颜色是否正确显示为#ff96a4