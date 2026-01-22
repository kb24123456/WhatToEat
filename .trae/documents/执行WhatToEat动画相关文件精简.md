## 执行WhatToEat动画相关文件精简

### 1. AnimationUtils.swift
- **删除**：第129-144行 `detectOffscreenRendering` 调试方法
- **删除**：第184-224行 `debounce` 和 `throttle` 方法（与动画核心功能关联不大）

### 2. AsyncImageView.swift
- **删除**：第257-286行 `UIImage.preDecoded()` 方法（与 `AnimationUtils.preDecodeImage` 重复）
- **删除**：第291-339行 `ImageCacheManager` 类（与 `AsyncImageLoader.imageCache` 重复）
- **修改**：`ImagePreloader.getImageURL` 方法，改为调用 `AsyncImageLoader.getImageURL`
- **合并**：将 `ImagePreloader` 类的功能整合到 `AsyncImageLoader` 中
- **调整**：统一使用 `ImageCacheManager.shared` 进行图片缓存管理

### 3. SpriteKitView.swift
- **修改**：第226行中文变量名 `发射Timer` 改为英文 `launchTimer`
- **迁移**：将第466-487行 `SKView` 扩展方法移至 `SpriteKitSceneManager` 类
- **迁移**：将第490-508行 `SKEmitterNode` 扩展方法移至 `ParticleEmitterScene` 类
- **删除**：第440-463行 `SpriteKitViewExample` 示例代码

### 4. BatchAnimationManager.swift
- **删除**：第408-445行 `BatchAnimationExample` 示例代码
- **删除**：第199-219行 `View.batchAnimated` 方法（与SwiftUI内置动画系统重叠）

### 5. WhatToEat_Animation_Specification.md
- **更新**：根据代码精简情况，调整文档中的代码示例和说明

### 执行步骤
1. 先修改影响较小的文件（BatchAnimationManager.swift、SpriteKitView.swift）
2. 再修改核心动画工具（AnimationUtils.swift）
3. 最后修改图片加载相关功能（AsyncImageView.swift）
4. 验证所有修改后，更新文档
5. 运行项目确保无编译错误和功能问题

### 注意事项
- 确保所有修改都不会破坏现有功能
- 保持代码风格一致
- 更新相关注释和文档
- 测试动画效果和性能