## 修复计划：AddRestaurantView 保存逻辑

### 修复 1：同步逆地理编码
- 在保存前使用 `Task { @MainActor in }` 同步执行逆地理编码
- 确保坐标获取后再创建 Restaurant 对象

### 修复 2：城市兜底逻辑优化
- 使用 `UserDefaults.standard.string(forKey: "UserSelectedCity")` 获取用户当前所在城市
- 如果 UserDefaults 没有城市，则使用 `locationManager.currentCity`
- 确保城市信息被记录后再创建 Restaurant 对象

### 修复 3：保存成功后添加刷新延迟
- 在 `onClose` 回调中添加短暂延迟确保 SwiftData 刷新
- 保证新餐厅能立即显示在列表中

### 修改文件
- `WhatToEat/AddRestaurantView.swift` - 修改 `saveRestaurant()` 方法