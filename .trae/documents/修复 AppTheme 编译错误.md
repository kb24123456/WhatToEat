# 修复 AppTheme 编译错误

## 问题
`transitionScaleOpacity` 和 `transitionMoveTop` 缺少 `Animation.` 前缀

## 修复方案
```swift
// 修改前
static let transitionScaleOpacity = .scale.combined(with: .opacity)
static let transitionMoveTop = .move(edge: .top).combined(with: .opacity)

// 修改后
static let transitionScaleOpacity = Animation.scale.combined(with: .opacity)
static let transitionMoveTop = Animation.move(edge: .top).combined(with: .opacity)
```

## 修改文件
`AppTheme.swift` - 第 101、104 行