# WhatToEat 动画规范

## 目录

1. [引言](#引言)
2. [性能优化规范](#性能优化规范)
   1. [1.1 动画载体规则](#11-动画载体规则)
   2. [1.2 主线程隔离规则](#12-主线程隔离规则)
   3. [1.3 渲染优化规则](#13-渲染优化规则)
   4. [1.4 批量动画规则](#14-批量动画规则)
   5. [1.5 动画资源管理规则](#15-动画资源管理规则)
   6. [1.6 动画状态管理](#16-动画状态管理)
   7. [1.7 设备性能适配策略](#17-设备性能适配策略)
3. [视觉/交互规范](#视觉/交互规范)
   1. [2.1 统一动画基础参数](#21-统一动画基础参数)
   2. [2.2 组件动效标准化](#22-组件动效标准化)
   3. [2.3 核心交互动效规范](#23-核心交互动效规范)
   4. [2.4 动态类型与深色模式适配](#24-动态类型与深色模式适配)
   5. [2.5 动画无障碍支持](#25-动画无障碍支持)
4. [开发落地支撑](#开发落地支撑)
   1. [3.1 统一动画工具类](#31-统一动画工具类)
   2. [3.2 组件调用示例代码](#32-组件调用示例代码)
   3. [3.3 代码审查标准](#33-代码审查标准)
   4. [3.4 规范执行流程](#34-规范执行流程)
   5. [3.5 规范与代码一致性检查](#35-规范与代码一致性检查)
5. [规范验证](#规范验证)
   1. [4.1 动画测试策略](#41-动画测试策略)
   2. [4.2 性能验证方法](#42-性能验证方法)
   3. [4.3 视觉效果验证方法](#43-视觉效果验证方法)
   4. [4.4 动画性能监控](#44-动画性能监控)

## 引言

本规范旨在统一WhatToEat应用的动画实现，确保所有动画在iOS14+设备上60帧流畅运行，同时保持统一的视觉交互体验。规范分为性能优化规范和视觉/交互规范两大核心模块，覆盖动画载体、主线程隔离、渲染优化、批量动画、资源管理等关键方面，并提供可直接落地的代码示例和开发流程。

## 性能优化规范

### 1.1 动画载体规则

#### 规则说明
- **SwiftUI场景**：优先使用SwiftUI原生动画系统，如`withAnimation`、`animation(_:value:)`
- **UIKit场景**：强制优先使用Core Animation（CALayer）实现动画
- **混合场景**：SwiftUI视图内嵌UIKit组件时，UIKit部分仍需遵循Core Animation规则
- 优先操作transform/opacity/position等轻量级属性
- 禁止动画frame/bounds属性
- 禁止使用UIView.animate实现复杂动画

#### 执行要求
- **SwiftUI场景**：使用SwiftUI原生动画系统，复杂动画可结合规范提供的工具类
- **UIKit场景**：所有动画必须使用CALayer实现，仅允许在简单UI控件上使用UIView.animate
- **混合场景**：分别遵循对应框架的动画规则
- 必须使用规范提供的AnimationUtils工具类（UIKit）或遵循SwiftUI最佳实践（SwiftUI）

#### 代码示例

**正例1：SwiftUI动画**
```swift
// 使用SwiftUI原生动画
struct AnimatedView: View {
    @State private var isExpanded = false
    
    var body: some View {
        Text("Animated Text")
            .scaleEffect(isExpanded ? 1.2 : 1.0)
            .opacity(isExpanded ? 1.0 : 0.7)
            .animation(.easeInOut(duration: 0.3), value: isExpanded)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
    }
}
```

**正例2：使用CALayer动画**
```swift
// 使用AnimationUtils工具类实现CALayer动画
AnimationUtils.animateLayer(
    view.layer,
    keyPath: "transform.scale",
    toValue: 1.1,
    duration: 0.3,
    timingFunction: .easeInEaseOut
)
```

**反例1：SwiftUI动画性能问题**
```swift
// 错误：在动画闭包中进行复杂计算
struct BadAnimatedView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Text("Bad Animation")
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isAnimating)
            .onTapGesture {
                // 错误：在动画触发处进行复杂计算
                let result = performExpensiveCalculation()
                withAnimation {
                    isAnimating.toggle()
                }
            }
    }
}
```

**反例2：使用UIView.animate动画frame**
```swift
// 错误：使用UIView.animate动画frame属性
UIView.animate(withDuration: 0.3) {
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 200) // 禁止动画frame
}
```

#### 关键优化点
- **SwiftUI优化**：
  - 避免在动画闭包中进行复杂计算或数据获取
  - 使用`animation(_:value:)`而非全局动画，确保动画只在特定值变化时触发
  - 复杂动画考虑使用`GeometryEffect`或`AnimatableModifier`实现
- **UIKit优化**：
  - CALayer动画直接在GPU层执行，避免了UIKit的额外开销
  - transform/opacity/position等属性动画不会触发布局计算和重绘
  - frame/bounds动画会触发完整的布局流程，导致性能下降

### 1.2 主线程隔离规则

#### 规则说明
- 动画所有回调/进度监听中，禁止执行耗时操作
- 耗时逻辑必须迁移至子线程，仅UI更新回主线程
- 禁止在动画回调中执行网络请求、数据解析、列表刷新等操作

#### 执行要求
- 使用GCD或OperationQueue实现主线程隔离
- 动画完成回调中仅允许执行简单的UI更新
- 必须使用规范提供的主线程隔离工具

#### 代码示例

**正例：主线程隔离**
```swift
// 使用AnimationUtils工具类实现主线程隔离
AnimationUtils.runAnimationWithBackgroundWork(
    animationBlock: {
        // 主线程执行动画
        AnimationUtils.animateLayer(
            view.layer,
            keyPath: "transform.scale",
            toValue: 1.1,
            duration: 0.3
        )
    },
    backgroundWork: {
        // 子线程执行耗时操作
        performExpensiveOperation()
    },
    mainThreadCompletion: {
        // 主线程执行UI更新
        updateUI()
    }
)
```

**反例：主线程执行耗时操作**
```swift
// 错误：在动画回调中执行耗时操作
UIView.animate(withDuration: 0.3) {
    view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
} completion: {
    // 禁止在回调中执行耗时操作
    performExpensiveOperation() // 耗时操作应在子线程执行
    updateUI()
}
```

#### 关键优化点
- 动画回调在主线程执行，耗时操作会阻塞UI响应
- 将耗时操作迁移至子线程，避免阻塞主线程
- 仅将最终的UI更新回调到主线程

### 1.3 渲染优化规则

#### 规则说明
- 针对圆角+阴影视图，强制设置shadowPath避免离屏渲染
- 规范masksToBounds的使用场景
- 动画所用图片必须实现子线程预解码
- 标记不透明视图的opaque属性为true

#### 执行要求
- 所有带圆角+阴影的视图必须设置shadowPath
- 禁止同时使用masksToBounds和shadow
- 所有动画使用的图片必须经过预解码处理
- 不透明视图必须设置opaque=true

#### 代码示例

**正例：优化圆角+阴影视图**
```swift
// 使用AnimationUtils工具类优化圆角+阴影
AnimationUtils.optimizeRoundedShadowView(
    view,
    cornerRadius: 12,
    shadowColor: .black,
    shadowOffset: CGSize(width: 0, height: 4),
    shadowOpacity: 0.1,
    shadowRadius: 8
)
```

**正例：图片预解码**
```swift
// 使用AsyncImageView实现图片预解码
AsyncImageView(
    filename: imageFilename,
    systemPlaceholder: "photo"
)
```

**反例：导致离屏渲染**
```swift
// 错误：同时使用masksToBounds和shadow
view.layer.cornerRadius = 12
view.layer.masksToBounds = true // 禁止同时使用masksToBounds和shadow
view.layer.shadowColor = UIColor.black.cgColor
view.layer.shadowOffset = CGSize(width: 0, height: 4)
view.layer.shadowOpacity = 0.1
view.layer.shadowRadius = 8
```

#### 关键优化点
- 设置shadowPath可以避免GPU进行复杂的阴影计算
- masksToBounds会导致离屏渲染，应谨慎使用
- 图片预解码可以减少GPU负担，提高渲染性能
- 设置opaque=true可以减少GPU混合计算

### 1.4 批量动画规则

#### 规则说明
- 餐厅卡片/列表cell等批量动画必须分批执行
- 单批次最大数量：10个
- 批次延迟时间：0.05秒
- 必须使用规范提供的BatchAnimationManager工具类

#### 执行要求
- 所有列表项动画必须使用分批执行
- 必须使用规范提供的默认配置
- 禁止一次性触发大量动画

#### 代码示例

**正例：使用BatchAnimationManager**
```swift
// 使用BatchAnimationManager实现分批动画
let manager = BatchAnimationManager(config: .default)

for (index, restaurant) in restaurants.enumerated() {
    manager.addAnimation {
        // 执行单个餐厅卡片的动画
        animateRestaurantCard(restaurant)
    }
}

// 开始执行动画
manager.start()
```

**正例：使用数组扩展**
```swift
// 使用数组扩展实现分批动画
restaurants.forEachWithBatchAnimation(
    batchSize: 10,
    delay: 0.05,
    animation: { restaurant, index in
        // 执行单个餐厅卡片的动画
        animateRestaurantCard(restaurant)
    }
)
```

**反例：一次性触发大量动画**
```swift
// 错误：一次性触发大量动画
for restaurant in restaurants {
    UIView.animate(withDuration: 0.3) {
        restaurant.view.transform = .identity
    }
}
```

#### 关键优化点
- 分批动画可以分散GPU渲染压力，避免掉帧
- 单批次10个动画是经过测试的最优值
- 0.05秒的批次延迟可以保证动画的连贯性

### 1.5 动画资源管理规则

#### 规则说明
- 规范CALayer动画、SpriteKit粒子动画的创建/销毁逻辑
- 避免内存泄漏
- 超复杂动画明确SpriteKit替代Core Animation的使用场景

#### 执行要求
- 必须在视图消失时移除所有CALayer动画
- 必须正确管理SpriteKit场景的生命周期
- 超复杂粒子动画必须使用SpriteKit实现

#### 代码示例

**正例：正确管理CALayer动画**
```swift
// 在视图消失时移除所有动画
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // 移除所有CALayer动画
    view.layer.removeAllAnimations()
}
```

**正例：使用SpriteKit实现复杂粒子动画**
```swift
// 使用SpriteKitView实现复杂粒子动画
SpriteKitView(sceneType: .fireworks)
    .frame(width: 300, height: 300)
```

**反例：动画资源泄漏**
```swift
// 错误：未移除CALayer动画
func animateView() {
    let animation = CABasicAnimation(keyPath: "transform.scale")
    animation.toValue = 1.1
    animation.duration = 0.3
    view.layer.add(animation, forKey: "scale")
    // 未在适当时候移除动画，可能导致内存泄漏
}
```

#### 关键优化点
- 未移除的CALayer动画会导致内存泄漏
- SpriteKit专门优化了粒子动画的性能，适合复杂动画
- 正确管理动画资源可以提高应用的整体性能

### 1.6 动画状态管理

#### 规则说明
- 明确管理动画的生命周期状态（idle、running、completed、cancelled）
- 实现可靠的动画取消和中断机制
- 避免动画状态不一致导致的视觉异常
- 规范动画序列和组合动画的状态管理

#### 执行要求
- **SwiftUI**：使用@State/@Binding等状态变量清晰管理动画触发条件
- **UIKit**：实现动画状态枚举，明确跟踪动画的当前状态
- 所有可取消的动画必须提供取消方法
- 组合动画必须确保所有子动画状态一致
- 动画中断时必须正确恢复到初始状态

#### 代码示例

**正例1：SwiftUI动画状态管理**
```swift
struct StateManagedAnimation: View {
    @State private var animationState: AnimationState = .idle
    @State private var scale: CGFloat = 1.0
    
    enum AnimationState {
        case idle
        case running
        case completed
        case cancelled
    }
    
    var body: some View {
        VStack {
            Rectangle()
                .frame(width: 100, height: 100)
                .scaleEffect(scale)
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.7), 
                    value: scale
                )
            
            Button(animationState == .running ? "取消动画" : "开始动画") {
                withAnimation {
                    if animationState == .running {
                        // 取消动画，恢复初始状态
                        scale = 1.0
                        animationState = .cancelled
                    } else {
                        // 开始动画
                        scale = 1.5
                        animationState = .running
                    }
                }
            }
        }
        .onChange(of: scale) {
            // 监听动画完成状态
            if scale == 1.5 && animationState == .running {
                animationState = .completed
            } else if scale == 1.0 && animationState == .cancelled {
                animationState = .idle
            }
        }
    }
}
```

**正例2：UIKit动画状态管理**
```swift
class AnimationStateManager {
    enum AnimationState {
        case idle
        case running
        case completed
        case cancelled
    }
    
    private(set) var state: AnimationState = .idle
    private var animations: [String: CABasicAnimation] = [:]
    
    func startAnimation(on layer: CALayer, keyPath: String, toValue: Any) {
        state = .running
        
        // 取消当前相同keyPath的动画
        cancelAnimation(forKeyPath: keyPath)
        
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.toValue = toValue
        animation.duration = 0.3
        animation.delegate = self
        
        layer.add(animation, forKey: keyPath)
        animations[keyPath] = animation
    }
    
    func cancelAnimation(forKeyPath keyPath: String) {
        if let _ = animations[keyPath] {
            // 实现动画取消逻辑
            animations.removeValue(forKey: keyPath)
            state = .cancelled
        }
    }
    
    func cancelAllAnimations() {
        animations.removeAll()
        state = .cancelled
    }
}

extension AnimationStateManager: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            state = .completed
        }
    }
}
```

**反例：动画状态管理不当**
```swift
// 错误：缺乏动画状态管理
class BadAnimationManager {
    func startAnimation(on layer: CALayer) {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.toValue = 1.5
        animation.duration = 0.3
        layer.add(animation, forKey: "scale")
        // 没有跟踪动画状态，无法取消或检测完成
    }
    
    func stopAnimation(on layer: CALayer) {
        layer.removeAnimation(forKey: "scale")
        // 强制移除动画，可能导致视觉跳跃
    }
}
```

#### 关键优化点
- 明确的动画状态管理可以避免动画冲突和视觉异常
- 可靠的取消机制可以提高用户体验，尤其是在快速交互场景下
- 组合动画的状态同步可以确保复杂动画序列的正确性
- 动画状态反馈可以用于后续业务逻辑的触发

### 1.7 设备性能适配策略

#### 规则说明
- 不同设备性能差异大，需要根据设备性能调整动画复杂度
- 老旧设备和新设备需要采用不同的动画策略
- 低功耗模式下需要进一步简化动画
- 动态检测设备性能，实时调整动画参数

#### 执行要求
- **性能检测**：实现设备性能检测机制，区分高、中、低性能设备
- **动态调整**：根据设备性能动态调整动画复杂度、帧率和效果
- **低功耗模式**：监听低功耗模式变化，简化或禁用非必要动画
- **渐进增强**：在高性能设备上提供更丰富的动画效果，在低性能设备上保证流畅度

#### 代码示例

**正例1：SwiftUI设备性能适配**
```swift
struct PerformanceAdaptiveAnimation: View {
    @State private var isAnimating = false
    @State private var performanceLevel: PerformanceLevel = .medium
    
    enum PerformanceLevel {
        case low
        case medium
        case high
    }
    
    var body: some View {
        VStack {
            if performanceLevel == .high {
                // 高性能设备：复杂动画效果
                ComplexAnimationView(isAnimating: $isAnimating)
            } else if performanceLevel == .medium {
                // 中性能设备：中等复杂度动画
                MediumAnimationView(isAnimating: $isAnimating)
            } else {
                // 低性能设备：简化动画
                SimpleAnimationView(isAnimating: $isAnimating)
            }
            
            Button("触发动画") {
                withAnimation {
                    isAnimating.toggle()
                }
            }
        }
        .onAppear {
            // 检测设备性能
            detectDevicePerformance()
            
            // 监听低功耗模式
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { _ in
                detectDevicePerformance()
            }
        }
    }
    
    private func detectDevicePerformance() {
        let processInfo = ProcessInfo.processInfo
        
        // 检查低功耗模式
        if processInfo.isLowPowerModeEnabled {
            performanceLevel = .low
            return
        }
        
        // 根据设备型号和CPU核心数判断性能
        let device = UIDevice.current.modelIdentifier
        let processorCount = processInfo.processorCount
        
        // 简单的性能检测逻辑，实际项目中可根据需求调整
        if processorCount >= 8 && !device.contains("iPhone12") && !device.contains("iPhone13") {
            performanceLevel = .high
        } else if processorCount >= 6 {
            performanceLevel = .medium
        } else {
            performanceLevel = .low
        }
    }
    
    // 高性能设备的复杂动画
    struct ComplexAnimationView: View {
        @Binding var isAnimating: Bool
        
        var body: some View {
            ZStack {
                ForEach(0..<10) {
                    Circle()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.random())
                        .position(x: CGFloat.random(in: 50...300), y: CGFloat.random(in: 50...300))
                        .scaleEffect(isAnimating ? 1.5 : 1.0)
                        .opacity(isAnimating ? 1.0 : 0.5)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAnimating)
        }
    }
    
    // 中性能设备的中等复杂度动画
    struct MediumAnimationView: View {
        @Binding var isAnimating: Bool
        
        var body: some View {
            ZStack {
                ForEach(0..<5) {
                    Circle()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.random())
                        .position(x: CGFloat.random(in: 50...300), y: CGFloat.random(in: 50...300))
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .opacity(isAnimating ? 1.0 : 0.5)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isAnimating)
        }
    }
    
    // 低性能设备的简化动画
    struct SimpleAnimationView: View {
        @Binding var isAnimating: Bool
        
        var body: some View {
            Circle()
                .frame(width: 50, height: 50)
                .foregroundColor(.blue)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.linear(duration: 0.3), value: isAnimating)
        }
    }
}

extension Color {
    static func random() -> Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
```

**正例2：UIKit设备性能适配**
```swift
class PerformanceAdaptiveViewController: UIViewController {
    
    enum PerformanceLevel {
        case low
        case medium
        case high
    }
    
    private let animatedView = UIView()
    private var performanceLevel: PerformanceLevel = .medium
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAnimatedView()
        detectDevicePerformance()
        setupLowPowerModeObserver()
    }
    
    private func setupAnimatedView() {
        animatedView.backgroundColor = .blue
        animatedView.frame = CGRect(x: 100, y: 100, width: 100, height: 100)
        animatedView.layer.cornerRadius = 50
        animatedView.isUserInteractionEnabled = true
        view.addSubview(animatedView)
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(startAnimation))
        animatedView.addGestureRecognizer(tapGesture)
    }
    
    private func detectDevicePerformance() {
        let processInfo = ProcessInfo.processInfo
        
        // 检查低功耗模式
        if processInfo.isLowPowerModeEnabled {
            performanceLevel = .low
            return
        }
        
        // 根据设备型号和CPU核心数判断性能
        let device = UIDevice.current.modelIdentifier
        let processorCount = processInfo.processorCount
        let physicalMemory = processInfo.physicalMemory
        
        // 简单的性能检测逻辑，实际项目中可根据需求调整
        if physicalMemory > 8 * 1024 * 1024 * 1024 && processorCount >= 8 {
            performanceLevel = .high
        } else if physicalMemory > 4 * 1024 * 1024 * 1024 && processorCount >= 6 {
            performanceLevel = .medium
        } else {
            performanceLevel = .low
        }
    }
    
    private func setupLowPowerModeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.detectDevicePerformance()
        }
    }
    
    @objc private func startAnimation() {
        switch performanceLevel {
        case .high:
            // 高性能设备：复杂动画
            performHighPerformanceAnimation()
        case .medium:
            // 中性能设备：中等复杂度动画
            performMediumPerformanceAnimation()
        case .low:
            // 低性能设备：简化动画
            performLowPerformanceAnimation()
        }
    }
    
    private func performHighPerformanceAnimation() {
        // 复杂动画：缩放+旋转+透明度变化
        let group = CAAnimationGroup()
        group.duration = 0.4
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.toValue = 1.5
        
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.toValue = CGFloat.pi * 2
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.toValue = 0.7
        
        group.animations = [scaleAnimation, rotationAnimation, opacityAnimation]
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.autoreverses = true
        
        animatedView.layer.add(group, forKey: "complexAnimation")
    }
    
    private func performMediumPerformanceAnimation() {
        // 中等复杂度动画：缩放+透明度变化
        let group = CAAnimationGroup()
        group.duration = 0.3
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.toValue = 1.3
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.toValue = 0.8
        
        group.animations = [scaleAnimation, opacityAnimation]
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.autoreverses = true
        
        animatedView.layer.add(group, forKey: "mediumAnimation")
    }
    
    private func performLowPerformanceAnimation() {
        // 简化动画：仅缩放
        AnimationUtils.animateLayer(
            animatedView.layer,
            keyPath: "transform.scale",
            toValue: 1.2,
            duration: 0.2,
            timingFunction: .easeInEaseOut,
            autoreverses: true
        )
    }
}
```

**反例：未考虑设备性能**
```swift
// 错误：未考虑设备性能，所有设备使用相同的复杂动画
struct BadPerformanceView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<20) {
                Circle()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.random())
                    .position(x: CGFloat.random(in: 50...300), y: CGFloat.random(in: 50...300))
                    .scaleEffect(isAnimating ? 1.5 : 1.0)
                    .opacity(isAnimating ? 1.0 : 0.5)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAnimating)
        .onTapGesture {
            withAnimation {
                isAnimating.toggle()
            }
        }
    }
}
```

#### 关键优化点
- 设备性能检测是基础，需要根据实际项目需求调整检测逻辑
- 渐进增强是核心策略，确保所有设备都能获得良好的体验
- 低功耗模式下必须简化动画，延长设备电池寿命
- 动态调整动画复杂度可以平衡视觉效果和性能
- 避免在老旧设备上执行过多的同时动画，减少GPU和CPU负载

## 视觉/交互规范

### 2.1 统一动画基础参数

#### 规则说明
- 按“基础动画、中等动画、复杂动画”分类，明确统一的动画时长、缓动曲线
- 所有组件必须使用规范内的参数，禁止硬编码
- 必须使用规范提供的动画参数常量

#### 执行要求
- 必须使用规范提供的AppTheme.Animation常量
- 禁止在代码中硬编码动画时长和缓动曲线
- 必须按照动画类型选择对应的参数

#### 动画参数表

| 动画类型 | 时长 | 缓动曲线 | 使用场景 |
|---------|------|----------|----------|
| 基础动画 | 0.2s | easeInEaseOut | 按钮、开关、标签切换 |
| 中等动画 | 0.3s | easeInEaseOut | 搜索框、菜单展开/收起 |
| 复杂动画 | 0.4s | interactiveSpring | 页面转场、弹窗展示/隐藏 |

#### 代码示例

**正例：使用规范的动画参数**
```swift
// 使用规范提供的动画参数
AnimationUtils.animateLayer(
    view.layer,
    keyPath: "transform.scale",
    toValue: 1.1,
    duration: AppTheme.Animation.mediumDuration,
    timingFunction: AppTheme.Animation.defaultTimingFunction
)
```

**反例：硬编码动画参数**
```swift
// 错误：硬编码动画参数
AnimationUtils.animateLayer(
    view.layer,
    keyPath: "transform.scale",
    toValue: 1.1,
    duration: 0.3, // 禁止硬编码时长
    timingFunction: .easeInEaseOut // 禁止硬编码缓动曲线
)
```

### 2.2 组件动效标准化

#### 搜索类组件

**餐厅搜索框**
- **触发时机**：聚焦/失焦、输入反馈
- **动效类型**：缩放、阴影变化
- **动画参数**：时长0.3s，缓动曲线easeInEaseOut
- **代码示例**：
```swift
// 搜索框聚焦动画
AnimationUtils.animateLayer(
    searchBar.layer,
    keyPath: "transform.scale",
    toValue: 1.02,
    duration: AppTheme.Animation.mediumDuration,
    timingFunction: AppTheme.Animation.defaultTimingFunction
)
```

#### 筛选类组件

**筛选开关按钮**
- **触发时机**：点击切换
- **动效类型**：颜色变化、缩放
- **动画参数**：时长0.2s，缓动曲线easeInEaseOut

**二级筛选菜单**
- **触发时机**：点击展开/收起
- **动效类型**：缩放、透明度变化
- **动画参数**：时长0.3s，缓动曲线interactiveSpring

**筛选标签**
- **触发时机**：选中/取消
- **动效类型**：颜色变化、缩放
- **动画参数**：时长0.2s，缓动曲线easeInEaseOut

#### 弹窗类组件

**提示弹窗**
- **触发时机**：展示/隐藏
- **动效类型**：缩放、透明度变化
- **动画参数**：时长0.4s，缓动曲线interactiveSpring

**确认弹窗**
- **触发时机**：展示/隐藏
- **动效类型**：缩放、透明度变化
- **动画参数**：时长0.4s，缓动曲线interactiveSpring

**加载弹窗**
- **触发时机**：展示/隐藏
- **动效类型**：透明度变化
- **动画参数**：时长0.3s，缓动曲线easeInEaseOut

#### 导航类组件

**顶部导航栏**
- **触发时机**：页面转场、标题切换
- **动效类型**：透明度变化、平移
- **动画参数**：时长0.3s，缓动曲线easeInEaseOut

**底部TabBar**
- **触发时机**：切换、选中反馈
- **动效类型**：缩放、颜色变化
- **动画参数**：时长0.3s，缓动曲线interactiveSpring

#### 其他组件

**蒙层**
- **触发时机**：显示/隐藏
- **动效类型**：透明度变化
- **动画参数**：时长0.3s，缓动曲线easeInEaseOut

**空页面/错误页面**
- **触发时机**：展示/消失
- **动效类型**：缩放、透明度变化
- **动画参数**：时长0.4s，缓动曲线interactiveSpring

### 2.3 核心交互动效规范

#### 物理动效
- **使用场景**：卡片滑动、下拉刷新
- **动画参数**：时长0.4s，缓动曲线interactiveSpring
- **代码示例**：
```swift
// 使用交互式弹簧动画
AnimationUtils.animateLayerSpring(
    view.layer,
    keyPath: "transform",
    toValue: transform,
    duration: 0.4,
    damping: 0.7,
    stiffness: 300,
    mass: 1
)
```

#### 归位动效
- **使用场景**：未成功滑动的卡片、取消操作的弹窗
- **动画参数**：时长0.3s，缓动曲线easeInEaseOut

#### 微交互
- **使用场景**：按钮点击反馈、输入框状态变化
- **动画参数**：时长0.2s，缓动曲线easeInEaseOut

#### 层级胶囊菜单
- **使用场景**：筛选菜单、下拉菜单
- **动画参数**：时长0.3s，缓动曲线interactiveSpring

### 2.4 动态类型与深色模式适配

#### 规则说明
- 动画必须适配不同文本大小（动态类型）
- 动画颜色必须适配浅色/深色模式
- 动画效果必须在各种显示设置下保持一致

#### 执行要求
- **动态类型**：动画距离、速度必须适应不同文本大小
- **深色模式**：动画颜色必须使用系统语义颜色或主题颜色
- **过渡效果**：模式切换时，动画必须平滑过渡，无视觉跳跃
- **自适应布局**：动画必须考虑自适应布局变化

#### 代码示例

**正例1：SwiftUI动态类型与深色模式适配**
```swift
struct AdaptiveAnimationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var isAnimating = false
    
    // 根据动态类型调整动画参数
    private var animationDuration: Double {
        // 较大文本尺寸时，动画速度稍慢，提高可读性
        switch dynamicTypeSize {
        case .accessibility5:
            return 0.5
        case .accessibility4, .accessibility3:
            return 0.4
        default:
            return 0.3
        }
    }
    
    // 根据深色模式调整动画颜色
    private var animationColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        Text("Adaptive Animation")
            .foregroundColor(animationColor)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 1.0 : 0.7)
            .animation(
                .easeInOut(duration: animationDuration), 
                value: isAnimating
            )
            .onTapGesture {
                withAnimation {
                    isAnimating.toggle()
                }
            }
    }
}
```

**正例2：UIKit动态类型与深色模式适配**
```swift
class AdaptiveAnimationViewController: UIViewController {
    
    private let animatedLabel = UILabel()
    private var animationDuration: Double = 0.3
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAnimatedLabel()
        setupDynamicTypeObserver()
        setupColorSchemeObserver()
    }
    
    private func setupAnimatedLabel() {
        animatedLabel.text = "Adaptive Animation"
        animatedLabel.textAlignment = .center
        animatedLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        animatedLabel.adjustsFontForContentSizeCategory = true
        animatedLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animatedLabel)
        
        NSLayoutConstraint.activate([
            animatedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animatedLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(startAnimation))
        animatedLabel.isUserInteractionEnabled = true
        animatedLabel.addGestureRecognizer(tapGesture)
    }
    
    // 监听动态类型变化
    private func setupDynamicTypeObserver() {
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAnimationDuration()
        }
        updateAnimationDuration()
    }
    
    // 监听深色模式变化
    private func setupColorSchemeObserver() {
        NotificationCenter.default.addObserver(
            forName: UIColor.systemBackgroundColor.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAnimationColor()
        }
        updateAnimationColor()
    }
    
    private func updateAnimationDuration() {
        let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        switch contentSizeCategory {
        case .accessibilityExtraExtraExtraLarge:
            animationDuration = 0.5
        case .accessibilityExtraExtraLarge, .accessibilityExtraLarge:
            animationDuration = 0.4
        default:
            animationDuration = 0.3
        }
    }
    
    private func updateAnimationColor() {
        animatedLabel.textColor = traitCollection.userInterfaceStyle == .dark ? .white : .black
    }
    
    @objc private func startAnimation() {
        AnimationUtils.animateLayer(
            animatedLabel.layer,
            keyPath: "transform.scale",
            toValue: 1.2,
            duration: animationDuration,
            timingFunction: .easeInOut
        ) { [weak self] in
            // 恢复初始状态
            AnimationUtils.animateLayer(
                self?.animatedLabel.layer ?? CALayer(),
                keyPath: "transform.scale",
                toValue: 1.0,
                duration: self?.animationDuration ?? 0.3,
                timingFunction: .easeInOut
            )
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // 深色模式切换时的处理
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            updateAnimationColor()
        }
    }
}
```

**反例：未适配动态类型和深色模式**
```swift
// 错误：硬编码颜色和动画参数，未适配动态类型和深色模式
struct BadAdaptiveView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Text("Bad Animation")
            .foregroundColor(.black) // 错误：硬编码颜色，不适配深色模式
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isAnimating) // 错误：固定动画时长，不适配动态类型
            .onTapGesture {
                withAnimation {
                    isAnimating.toggle()
                }
            }
    }
}
```

#### 关键优化点
- 动态类型适配：较大文本尺寸时，动画速度应稍慢，提高可读性
- 深色模式适配：使用语义颜色或主题颜色，确保动画在不同模式下清晰可见
- 平滑过渡：模式切换时，动画应平滑过渡，避免视觉跳跃
- 自适应布局：动画应考虑布局变化，确保在各种屏幕尺寸和文本大小下都能正常工作

### 2.5 动画无障碍支持

#### 规则说明
- 必须支持系统级"减少动画"设置
- 避免使用可能引起前庭障碍的强烈动画
- 确保动画不影响屏幕阅读器等辅助技术
- 为用户提供应用内减少/禁用动画的选项

#### 执行要求
- **检测系统设置**：监听系统"减少动画"设置变化
- **条件动画**：根据系统设置和用户偏好条件性触发动画
- **温和动画**：避免闪烁、旋转过快、缩放过大的动画
- **辅助技术兼容**：确保动画不会干扰屏幕阅读器的焦点管理

#### 代码示例

**正例1：SwiftUI无障碍动画支持**
```swift
struct AccessibleAnimationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            Rectangle()
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 1.0 : 0.7)
                .animation(
                    shouldAnimate ? .spring(response: 0.3, dampingFraction: 0.7) : nil, 
                    value: isAnimating
                )
            
            Button("触发动画") {
                withAnimation(shouldAnimate ? .spring(response: 0.3, dampingFraction: 0.7) : nil) {
                    isAnimating.toggle()
                }
            }
        }
    }
    
    // 根据系统设置决定是否启用动画
    private var shouldAnimate: Bool {
        return !reduceMotion
    }
}
```

**正例2：UIKit无障碍动画支持**
```swift
class AccessibleAnimationViewController: UIViewController {
    
    private let animatedView = UIView()
    private var shouldAnimate: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAnimatedView()
        setupAccessibilityObserver()
        updateShouldAnimate()
    }
    
    private func setupAnimatedView() {
        animatedView.backgroundColor = .blue
        animatedView.frame = CGRect(x: 100, y: 100, width: 100, height: 100)
        animatedView.layer.cornerRadius = 50
        animatedView.isUserInteractionEnabled = true
        view.addSubview(animatedView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(startAnimation))
        animatedView.addGestureRecognizer(tapGesture)
    }
    
    private func setupAccessibilityObserver() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateShouldAnimate()
        }
    }
    
    private func updateShouldAnimate() {
        shouldAnimate = !UIAccessibility.isReduceMotionEnabled
    }
    
    @objc private func startAnimation() {
        guard shouldAnimate else {
            // 减少动画模式下，直接切换状态，不执行动画
            toggleStateWithoutAnimation()
            return
        }
        
        // 正常模式下，执行动画
        AnimationUtils.animateLayer(
            animatedView.layer,
            keyPath: "transform.scale",
            toValue: 1.5,
            duration: 0.3,
            timingFunction: .easeInEaseOut
        ) { [weak self] in
            AnimationUtils.animateLayer(
                self?.animatedView.layer ?? CALayer(),
                keyPath: "transform.scale",
                toValue: 1.0,
                duration: 0.3,
                timingFunction: .easeInEaseOut
            )
        }
    }
    
    private func toggleStateWithoutAnimation() {
        // 直接切换状态，不执行动画
        // 例如：更新数据、切换显示状态等
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // 检查reduceMotion设置变化
        if previousTraitCollection?.accessibilityReduceMotion != traitCollection.accessibilityReduceMotion {
            updateShouldAnimate()
        }
    }
}
```

**反例：未考虑无障碍支持**
```swift
// 错误：未考虑系统"减少动画"设置
struct BadAccessibleAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 错误：强烈的闪烁动画，可能引起前庭障碍
            ForEach(0..<20) {
                Circle()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.random())
                    .opacity(isAnimating ? 1.0 : 0.1)
            }
        }
        .animation(.easeInOut(duration: 0.2).repeatForever(), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}
```

#### 关键优化点
- 始终尊重系统"减少动画"设置，这是无障碍支持的基础
- 避免使用强烈、闪烁、旋转过快的动画，保护前庭障碍用户
- 为应用内添加减少/禁用动画的选项，提供更灵活的用户控制
- 确保动画不干扰辅助技术，如屏幕阅读器的焦点管理
- 减少动画模式下，提供替代方案，确保功能完整性

## 开发落地支撑

### 3.1 统一动画工具类

**AnimationUtils.swift**
```swift
// 核心动画工具类，包含CALayer动画封装、主线程隔离、渲染优化等功能
// 主要功能：
// - CALayer动画封装（基础动画、弹簧动画）
// - 主线程隔离工具
// - 渲染优化（圆角+阴影优化）
// - 图片预解码
// 已在项目中实现，详见AnimationUtils.swift文件
```

**BatchAnimationManager.swift**
```swift
// 分批动画管理器，包含分批执行、并发控制等功能
// 主要功能：
// - 控制动画并发执行，避免一次性触发大量动画导致掉帧
// - 支持多种配置选项（默认配置、高性能配置、快速配置）
// - 提供数组扩展方法，方便调用
// 已在项目中实现，详见BatchAnimationManager.swift文件
```

**AsyncImageView.swift**
```swift
// 异步图片加载组件，包含预解码、缓存等功能
// 主要功能：
// - 异步图片加载，支持缓存和预解码
// - 图片预加载功能
// - 统一的图片缓存管理
// 已在项目中实现，详见AsyncImageView.swift文件
```

**SpriteKitView.swift**
```swift
// SpriteKit集成组件，包含粒子动画、高性能渲染等功能
// 主要功能：
// - 支持多种粒子动画（粒子发射器、烟花效果、彩带效果）
// - 高性能配置
// - 内存优化
// 已在项目中实现，详见SpriteKitView.swift文件
```

### 3.2 组件调用示例代码

#### SwiftUI示例

**搜索框动画示例**
```swift
struct SearchBar: View {
    @FocusState private var isFocused: Bool
    @State private var searchText = ""
    
    var body: some View {
        TextField("搜索餐厅...", text: $searchText)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .shadow(radius: isFocused ? 8 : 4)
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .focused($isFocused)
            .padding()
    }
}
```

**列表项动画示例**
```swift
struct AnimatedListView: View {
    let items = ["餐厅1", "餐厅2", "餐厅3", "餐厅4", "餐厅5"]
    @State private var showItems = false
    
    var body: some View {
        VStack {
            Button("显示列表") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
                    showItems.toggle()
                }
            }
            
            if showItems {
                List {
                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                        Text(item)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .scaleEffect(showItems ? 1.0 : 0.8)
                            .opacity(showItems ? 1.0 : 0.0)
                            .animation(
                                .spring(response: 0.3, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.05),
                                value: showItems
                            )
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
```

**过渡动画示例**
```swift
struct TransitionAnimationView: View {
    @State private var showDetails = false
    
    var body: some View {
        VStack {
            Button("显示详情") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDetails.toggle()
                }
            }
            
            if showDetails {
                Text("餐厅详细信息")
                    .font(.title)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.2).combined(with: .opacity)
                    ))
            }
        }
        .padding()
    }
}
```

**筛选菜单动画示例**
```swift
struct FilterMenu: View {
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack {
            Button("筛选选项") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("菜系")
                        .font(.headline)
                    HStack {
                        ForEach(["川菜", "粤菜", "西餐"], id: \.self) {
                            Text($0)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                    
                    Text("价格")
                        .font(.headline)
                    HStack {
                        ForEach(["¥", "¥¥", "¥¥¥"], id: \.self) {
                            Text($0)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .scaleEffect(isExpanded ? 1.0 : 0.95)
                .opacity(isExpanded ? 1.0 : 0.0)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
            }
        }
        .padding()
    }
}
```

**弹窗动画示例**
```swift
struct PopupView: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        ZStack {
            if isVisible {
                // 背景蒙层
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation {
                            isVisible.toggle()
                        }
                    }
                
                // 弹窗内容
                VStack {
                    Text("提示")
                        .font(.title)
                        .padding()
                    Text("这是一个弹窗示例，用于显示重要信息或确认操作。")
                        .padding()
                    Button("确定") {
                        withAnimation {
                            isVisible.toggle()
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                }
                .background(Color.white)
                .cornerRadius(16)
                .padding()
                .scaleEffect(isVisible ? 1.0 : 0.8)
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7), value: isVisible)
            }
        }
    }
}
```

#### UIKit示例

**复杂动画序列示例**
```swift
class ComplexAnimationViewController: UIViewController {
    
    private let animatedView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAnimatedView()
    }
    
    private func setupAnimatedView() {
        animatedView.backgroundColor = .blue
        animatedView.frame = CGRect(x: 100, y: 100, width: 100, height: 100)
        animatedView.layer.cornerRadius = 50
        animatedView.isUserInteractionEnabled = true
        view.addSubview(animatedView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(startComplexAnimation))
        animatedView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func startComplexAnimation() {
        // 复杂动画序列：缩放→旋转→颜色变化→移动
        let group1 = CAAnimationGroup()
        group1.duration = 0.5
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.toValue = 1.3
        
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.toValue = CGFloat.pi / 2
        
        group1.animations = [scaleAnimation, rotationAnimation]
        group1.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group1.fillMode = .forwards
        group1.isRemovedOnCompletion = false
        
        animatedView.layer.add(group1, forKey: "group1")
        
        // 延迟执行第二个动画组
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let group2 = CAAnimationGroup()
            group2.duration = 0.5
            
            let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
            colorAnimation.toValue = UIColor.red.cgColor
            
            let positionAnimation = CABasicAnimation(keyPath: "position")
            positionAnimation.toValue = CGPoint(x: 200, y: 200)
            
            group2.animations = [colorAnimation, positionAnimation]
            group2.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            group2.fillMode = .forwards
            group2.isRemovedOnCompletion = false
            
            self.animatedView.layer.add(group2, forKey: "group2")
        }
        
        // 延迟执行第三个动画组（恢复初始状态）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let group3 = CAAnimationGroup()
            group3.duration = 0.5
            
            let resetScaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            resetScaleAnimation.toValue = 1.0
            
            let resetRotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
            resetRotationAnimation.toValue = 0
            
            let resetColorAnimation = CABasicAnimation(keyPath: "backgroundColor")
            resetColorAnimation.toValue = UIColor.blue.cgColor
            
            let resetPositionAnimation = CABasicAnimation(keyPath: "position")
            resetPositionAnimation.toValue = CGPoint(x: 100, y: 100)
            
            group3.animations = [resetScaleAnimation, resetRotationAnimation, resetColorAnimation, resetPositionAnimation]
            group3.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            group3.fillMode = .forwards
            group3.isRemovedOnCompletion = false
            
            self.animatedView.layer.add(group3, forKey: "group3")
        }
    }
}

### 3.3 代码审查标准

#### 审查要点
1. **动画载体**：是否使用CALayer动画，是否操作轻量级属性
2. **主线程隔离**：动画回调中是否执行耗时操作
3. **渲染优化**：是否设置shadowPath，是否实现图片预解码
4. **批量动画**：批量动画是否分批执行，是否使用BatchAnimationManager
5. **资源管理**：是否正确管理动画资源，是否存在内存泄漏风险
6. **视觉参数**：是否使用规范的动画参数，是否硬编码
7. **交互一致性**：是否符合组件动效标准化要求

#### 审查流程
1. **开发自检**：开发者根据规范进行自我检查
2. **代码审查**：代码审查人员根据审查要点进行审查
3. **性能测试**：使用Instruments检测动画性能
4. **视觉验证**：确认动画效果符合规范

### 3.4 规范执行流程

#### 开发阶段
1. 参考规范选择合适的动画载体和实现方式
2. 使用规范提供的工具类和代码示例
3. 遵循规范的动画参数和交互效果
4. 进行自我检查，确保符合规范要求
5. 运行静态分析工具检查动画代码合规性

#### 测试阶段
1. 使用Instruments检测动画性能
2. 检查动画流畅度和视觉效果
3. 验证批量动画是否分批执行
4. 确认无内存泄漏
5. 运行自动化测试套件

#### 发布阶段
1. 进行最终性能检查
2. 确认所有动画符合规范
3. 生成性能报告

### 3.5 规范与代码一致性检查

#### 静态分析工具
1. **SwiftLint规则**：
   - 自定义SwiftLint规则，检查动画相关代码是否符合规范
   - 规则示例：
     - 禁止使用UIView.animate实现复杂动画
     - 强制使用AnimationUtils工具类
     - 检查动画时长是否符合规范
     - 禁止硬编码动画参数

2. **自定义脚本**：
   - 开发自定义脚本，定期检查代码库中的动画实现
   - 脚本功能：
     - 统计使用UIView.animate的复杂动画数量
     - 检查是否所有圆角+阴影视图都设置了shadowPath
     - 验证批量动画是否使用了BatchAnimationManager
     - 检查动画资源是否正确释放

#### CI/CD集成
1. **自动化检查**：
   - 在CI流程中集成SwiftLint和自定义脚本
   - 动画规范检查失败时，禁止合并代码

2. **性能测试自动化**：
   - 集成自动化性能测试，监控动画FPS
   - 设置性能阈值，超过阈值时触发警报

3. **文档同步检查**：
   - 定期检查代码中的动画实现与规范文档的一致性
   - 发现不一致时，自动生成文档更新建议

#### 代码审查标准细化

**动画载体审查要点**：
| 审查项 | 符合规范 | 不符合规范 |
|-------|---------|-----------|
| SwiftUI场景 | 使用SwiftUI原生动画 | 使用UIView.animate或CALayer动画 |
| UIKit场景 | 使用CALayer动画 | 动画frame/bounds属性 |
| 复杂动画 | 使用AnimationUtils工具类 | 直接使用CAAnimation |

**性能优化审查要点**：
| 审查项 | 符合规范 | 不符合规范 |
|-------|---------|-----------|
| 圆角+阴影 | 设置了shadowPath | 未设置shadowPath |
| 批量动画 | 使用BatchAnimationManager | 一次性触发大量动画 |
| 动画回调 | 无耗时操作 | 包含网络请求、数据解析等耗时操作 |
| 图片预解码 | 使用AsyncImageView | 直接使用UIImage加载 |

**视觉/交互审查要点**：
| 审查项 | 符合规范 | 不符合规范 |
|-------|---------|-----------|
| 动画时长 | 使用AppTheme.Animation常量 | 硬编码时长 |
| 缓动曲线 | 使用规范的缓动曲线 | 自定义缓动曲线 |
| 组件动效 | 符合组件动效标准化 | 不符合组件动效标准化 |
| 深色模式 | 适配深色模式 | 硬编码颜色 |

**状态管理审查要点**：
| 审查项 | 符合规范 | 不符合规范 |
|-------|---------|-----------|
| 动画状态 | 明确管理动画状态 | 未管理动画状态 |
| 取消机制 | 提供取消方法 | 无法取消动画 |
| 资源释放 | 正确释放动画资源 | 存在内存泄漏风险 |

#### 文档与代码同步机制
1. **文档版本控制**：
   - 为规范文档添加版本号
   - 代码中注明使用的规范版本
   - 定期更新文档，保持与代码的同步

2. **变更通知机制**：
   - 规范更新时，通知所有开发人员
   - 提供规范更新的迁移指南
   - 组织规范培训，确保所有开发人员理解新规范

3. **示例代码维护**：
   - 定期更新示例代码，确保与最新规范一致
   - 示例代码与实际项目代码保持同步
   - 提供可直接运行的示例项目

## 规范验证

### 4.1 动画测试策略

#### 测试类型
1. **自动化测试**：
   - 单元测试：验证动画工具类的正确性
   - UI测试：验证动画触发条件和状态变化
   - 快照测试：验证动画前后的视图状态

2. **性能测试**：
   - FPS监控：确保动画稳定在60帧
   - CPU/GPU使用率测试：避免过度消耗资源
   - 内存泄漏测试：确保动画资源正确释放

3. **视觉测试**：
   - 动画效果一致性检查
   - 不同设备/系统版本的兼容性测试
   - 动态类型和深色模式适配测试

#### 测试方法

**自动化测试**
```swift
// 示例：SwiftUI动画自动化测试
class AnimationTests: XCTestCase {
    
    func testAnimationTriggersCorrectly() {
        // 创建测试视图
        let testView = StateManagedAnimation()
        let hostingController = UIHostingController(rootView: testView)
        
        // 加载视图
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        
        // 触发动画
        let button = hostingController.view.subviews.first?.subviews.last as? UIButton
        XCTAssertNotNil(button, "Button not found")
        
        // 模拟点击按钮
        button?.sendActions(for: .touchUpInside)
        
        // 验证动画状态变化
        // 注意：由于SwiftUI的异步特性，实际测试中需要使用异步等待或期望值
    }
    
    func testAnimationDurationIsCorrect() {
        // 测试动画工具类的动画时长是否符合规范
        let expectation = self.expectation(description: "Animation completes")
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let startTime = Date()
        
        AnimationUtils.animateLayer(
            view.layer,
            keyPath: "transform.scale",
            toValue: 1.1,
            duration: 0.3,
            timingFunction: .easeInEaseOut
        ) { [weak self] in
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // 验证动画时长是否在允许范围内
            XCTAssertTrue(duration >= 0.25 && duration <= 0.35, "Animation duration is not correct")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
```

**性能测试**
1. **使用Core Animation工具**：
   - 打开Xcode Instruments，选择Core Animation工具
   - 运行应用，观察以下指标：
     - FPS：确保稳定在60帧
     - Offscreen Rendered Yellow：避免过多黄色区域
     - Compositing Fast Path Blue：确保蓝色区域占比高

2. **使用Time Profiler工具**：
   - 打开Xcode Instruments，选择Time Profiler工具
   - 运行应用，执行动画操作
   - 检查主线程耗时，确保无长时间阻塞
   - 检查CPU使用率，确保在合理范围内

3. **使用Memory Graph工具**：
   - 运行应用，执行动画操作
   - 拍摄内存快照，检查是否存在内存泄漏
   - 重点检查动画相关对象是否正确释放

4. **使用Energy Log工具**：
   - 打开Xcode Instruments，选择Energy Log工具
   - 运行应用，执行动画操作
   - 检查能源消耗，确保动画不会导致能源消耗过高

#### 视觉测试

**组件动效一致性检查**
1. 检查同类型组件的动画效果是否一致
2. 验证动画参数是否符合规范
3. 确认触发时机和动效类型是否正确

**交互体验检查**
1. 测试动画的流畅度和响应性
2. 确认动画反馈是否直观
3. 验证动画是否符合用户预期

**兼容性测试**
1. 在不同设备型号上测试动画效果
2. 在不同iOS版本上测试动画兼容性
3. 测试动态类型和深色模式下的动画效果

**遵循HIG检查**
1. 确认动画符合iOS Human Interface Guidelines
2. 检查动画是否符合iOS用户的操作习惯
3. 验证动画是否自然、流畅

#### 测试流程
1. **开发阶段**：
   - 编写单元测试验证动画工具类
   - 进行自我性能测试
   - 验证动画效果是否符合规范

2. **测试阶段**：
   - 运行自动化测试套件
   - 使用Instruments进行性能测试
   - 进行视觉效果验证
   - 执行兼容性测试

3. **发布前验证**：
   - 最终性能检查
   - 跨设备兼容性测试
   - 动态类型和深色模式测试
   - 无障碍支持测试

### 4.2 性能验证方法

#### 使用Core Animation工具
1. 打开Xcode Instruments，选择Core Animation工具
2. 运行应用，观察以下指标：
   - FPS：确保稳定在60帧
   - Offscreen Rendered Yellow：避免过多黄色区域
   - Compositing Fast Path Blue：确保蓝色区域占比高

#### 使用Time Profiler工具
1. 打开Xcode Instruments，选择Time Profiler工具
2. 运行应用，执行动画操作
3. 检查主线程耗时，确保无长时间阻塞
4. 检查CPU使用率，确保在合理范围内

#### 使用Energy Log工具
1. 打开Xcode Instruments，选择Energy Log工具
2. 运行应用，执行动画操作
3. 检查能源消耗，确保动画不会导致能源消耗过高

### 4.3 视觉效果验证方法

#### 组件动效一致性检查
1. 检查同类型组件的动画效果是否一致
2. 验证动画参数是否符合规范
3. 确认触发时机和动效类型是否正确

#### 交互体验检查
1. 测试动画的流畅度和响应性
2. 确认动画反馈是否直观
3. 验证动画是否符合用户预期

#### 遵循HIG检查
1. 确认动画符合iOS Human Interface Guidelines
2. 检查动画是否符合iOS用户的操作习惯
3. 验证动画是否自然、流畅

### 4.4 动画性能监控

#### 监控指标
1. **FPS（每秒帧数）**：
   - 目标：稳定在60帧
   - 警告阈值：低于55帧
   - 严重阈值：低于45帧

2. **CPU/GPU使用率**：
   - CPU：动画期间使用率不超过60%
   - GPU：动画期间使用率不超过70%

3. **内存使用**：
   - 监控动画前后内存变化
   - 避免内存泄漏
   - 单次动画内存增长不超过10MB

4. **掉帧统计**：
   - 统计掉帧次数和持续时间
   - 单次掉帧时长不超过16ms（60fps）

#### 实现方法

**1. FPS监控**
```swift
class FPSMonitor {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fps: Double = 60.0
    
    var fpsCallback: ((Double) -> Void)?
    
    func startMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func update(_ displayLink: CADisplayLink) {
        guard lastTimestamp != 0 else {
            lastTimestamp = displayLink.timestamp
            return
        }
        
        frameCount += 1
        let elapsed = displayLink.timestamp - lastTimestamp
        
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            fpsCallback?(fps)
            frameCount = 0
            lastTimestamp = displayLink.timestamp
            
            // 记录FPS数据
            logFPS(fps)
        }
    }
    
    private func logFPS(_ fps: Double) {
        // 可以将FPS数据发送到日志系统或分析平台
        print("Current FPS: \(String(format: "%.1f", fps))")
        
        if fps < 55 {
            // 低于警告阈值，记录警告
            print("WARNING: Low FPS detected: \(String(format: "%.1f", fps))")
        }
        
        if fps < 45 {
            // 低于严重阈值，记录错误
            print("ERROR: Very low FPS detected: \(String(format: "%.1f", fps))")
        }
    }
}
```

**2. 动画性能监控工具类**
```swift
class AnimationPerformanceMonitor {
    static let shared = AnimationPerformanceMonitor()
    
    private let fpsMonitor = FPSMonitor()
    private var performanceData: [String: Any] = [:]
    
    private init() {}
    
    func startMonitoring() {
        fpsMonitor.startMonitoring()
        fpsMonitor.fpsCallback = { [weak self] fps in
            self?.performanceData["currentFPS"] = fps
        }
        
        // 记录初始内存使用
        recordMemoryUsage()
    }
    
    func stopMonitoring() {
        fpsMonitor.stopMonitoring()
        
        // 记录结束内存使用
        recordMemoryUsage()
        
        // 生成性能报告
        generatePerformanceReport()
    }
    
    private func recordMemoryUsage() {
        let memoryUsage = getCurrentMemoryUsage()
        let timestamp = Date().timeIntervalSince1970
        
        if performanceData["startMemory"] == nil {
            performanceData["startMemory"] = memoryUsage
            performanceData["startTime"] = timestamp
        } else {
            performanceData["endMemory"] = memoryUsage
            performanceData["endTime"] = timestamp
        }
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return taskInfo.resident_size
        } else {
            return 0
        }
    }
    
    private func generatePerformanceReport() {
        guard let startMemory = performanceData["startMemory"] as? UInt64,
              let endMemory = performanceData["endMemory"] as? UInt64,
              let currentFPS = performanceData["currentFPS"] as? Double else {
            return
        }
        
        let memoryChange = Int64(endMemory - startMemory) / 1024 / 1024 // MB
        
        let report = """\n
=== Animation Performance Report ===
Current FPS: \(String(format: "%.1f", currentFPS))
Memory Change: \(memoryChange) MB
Start Memory: \(startMemory / 1024 / 1024) MB
End Memory: \(endMemory / 1024 / 1024) MB
"""
        
        print(report)
        
        // 可以将报告发送到分析平台
    }
    
    // 监控单个动画的性能
    func monitorAnimation(_ animationName: String, animationBlock: () -> Void) {
        startMonitoring()
        
        // 执行动画
        animationBlock()
        
        // 延迟停止监控，确保动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.stopMonitoring()
        }
    }
}
```

**3. 在动画中使用监控**
```swift
// 使用性能监控
AnimationPerformanceMonitor.shared.monitorAnimation("RestaurantCardAnimation") {
    // 执行动画
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        // 动画代码
    }
}
```

#### 集成建议

1. **开发阶段**：
   - 集成FPS监控到调试版本
   - 在开发过程中实时查看FPS
   - 及时发现并修复性能问题

2. **测试阶段**：
   - 使用性能监控工具类测试所有动画
   - 生成性能报告
   - 比较不同实现方案的性能差异

3. **发布阶段**：
   - 在发布版本中可选集成性能监控
   - 仅在用户同意的情况下收集性能数据
   - 将性能数据发送到分析平台

#### 关键优化点
- 实时监控FPS，及时发现性能问题
- 记录动画前后内存变化，检测内存泄漏
- 生成性能报告，便于分析和优化
- 集成到CI流程，自动化检测动画性能
- 提供可视化性能数据，便于开发人员理解

## 总结

本规范旨在统一WhatToEat应用的动画实现，确保所有动画在iOS14+设备上60帧流畅运行，同时保持统一的视觉交互体验。规范分为性能优化规范和视觉/交互规范两大核心模块，覆盖动画载体、主线程隔离、渲染优化、批量动画、资源管理等关键方面，并提供可直接落地的代码示例和开发流程。

所有开发人员必须严格遵循本规范，确保应用的动画性能和视觉效果达到最佳状态。规范将定期更新，以适应新的技术和设计趋势。
