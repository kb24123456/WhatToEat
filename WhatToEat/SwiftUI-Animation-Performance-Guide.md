# SwiftUI 动画性能与能效优化指南 (Expert Standard)

## 核心哲学

SwiftUI 动画的"丝滑感"来自于 60/120 FPS 的稳定输出。发热和卡顿通常不是因为动效太复杂，而是因为主线程的无效计算重绘和 GPU 的离屏渲染压力。

---

## 🔍 TRAE 必须执行的四大核心准则

### 1. 视图局部化与颗粒度控制 (Body Isolation)

**【现象】**：修改一个状态导致整个页面重绘。

**【准则】**：
- [ ] **状态下放**：严禁在父视图（如主 TabView 或 List 容器）中放置频繁变动的动画状态。
- [ ] **组件拆分**：将动画组件封装在独立的 struct 中。只有受状态影响的"最小单元"才应该重新运行 body。
- [ ] **显式传参**：向子视图传递基础类型（Bool, Double）而非整个大对象的引用，减少依赖追踪开销。

**示例**：
```swift
// ❌ 错误：状态在父视图，导致整个页面重绘
struct ParentView: View {
    @State private var isAnimating = false
    var body: some View {
        VStack {
            Header()
            Content()
            AnimatedButton(isAnimating: isAnimating) // 修改时整个 VStack 重绘
        }
    }
}

// ✅ 正确：状态下放到子视图
struct ParentView: View {
    var body: some View {
        VStack {
            Header()
            Content()
            AnimatedButton() // 内部管理自己的状态
        }
    }
}

struct AnimatedButton: View {
    @State private var isAnimating = false // 状态隔离
    var body: some View {
        Button(action: { isAnimating.toggle() }) {
            Image(systemName: "star")
                .scaleEffect(isAnimating ? 1.2 : 1.0)
        }
    }
}
```

---

### 2. 禁止在 body 中进行任何计算 (No-Logic Body)

**【现象】**：动画执行时 CPU 占用率飙升，风扇狂转。

**【准则】**：
- [ ] **零逻辑计算**：body 内严禁进行 filter, sort, map, DateFormatter 或复杂的数学运算。
- [ ] **预计算状态**：所有动画所需的位移（Offset）、缩放（Scale）数值应提前在 ViewModel 中计算好，或通过计算属性（Computed Property）缓存，body 只做赋值。

**示例**：
```swift
// ❌ 错误：在 body 中进行计算
struct BadView: View {
    @State private var items: [Item] = []
    var body: some View {
        List(items.filter { $0.isActive }.sorted { $0.date > $1.date }) { item in
            // 每次状态更新都会重新计算 filter 和 sort
            Text(item.name)
        }
    }
}

// ✅ 正确：预计算状态
struct GoodView: View {
    @State private var items: [Item] = []
    
    // 计算属性缓存结果
    private var sortedActiveItems: [Item] {
        items.filter { $0.isActive }.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        List(sortedActiveItems) { item in
            Text(item.name)
        }
    }
}

// ✅ 更好：使用 ViewModel
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var sortedActiveItems: [Item] = []
    
    func updateItems(_ newItems: [Item]) {
        items = newItems
        sortedActiveItems = newItems.filter { $0.isActive }.sorted { $0.date > $1.date }
    }
}
```

---

### 3. GPU 渲染加速 (Metal Optimization)

**【现象】**：使用模糊、阴影或复杂形变时掉帧。

**【准则】**：
- [ ] **drawingGroup() 强制应用**：对于涉及复杂形变（如 Genie Effect、网格扭曲）、大量子视图渐变、或复杂绘图的组件，必须添加 `.drawingGroup()`。这会将渲染路径从 Core Animation 切换到 Metal GPU 纹理混合，性能提升 3-5 倍。
- [ ] **compositingGroup() 与阴影优化**：在使用 `.shadow` 或 `.opacity` 前，先使用 `.compositingGroup()` 将子视图打组，防止 GPU 对每个子层级重复计算模糊和合成。
- [ ] **尽量规避 GeometryReader**：除非必须获取坐标系，否则优先使用 `.visualEffect` (iOS 17+) 或布局容器。如果必须使用，确保其内部不嵌套复杂的 View 层级。

**示例**：
```swift
// ❌ 错误：复杂形变无 GPU 优化
struct ComplexAnimation: View {
    @State private var isExpanded = false
    var body: some View {
        VStack {
            ForEach(0..<50) { i in
                RoundedRectangle(cornerRadius: 10)
                    .rotationEffect(.degrees(isExpanded ? 360 : 0))
                    .scaleEffect(isExpanded ? 1.5 : 1.0)
            }
        }
        .animation(.spring(), value: isExpanded)
    }
}

// ✅ 正确：使用 drawingGroup() 启用 Metal 渲染
struct OptimizedAnimation: View {
    @State private var isExpanded = false
    var body: some View {
        VStack {
            ForEach(0..<50) { i in
                RoundedRectangle(cornerRadius: 10)
                    .rotationEffect(.degrees(isExpanded ? 360 : 0))
                    .scaleEffect(isExpanded ? 1.5 : 1.0)
            }
        }
        .drawingGroup() // 切换到 Metal GPU 渲染
        .animation(.spring(), value: isExpanded)
    }
}

// ✅ 正确：compositingGroup() 优化阴影
struct ShadowView: View {
    var body: some View {
        VStack {
            Image(systemName: "star")
            Text("Title")
            Text("Subtitle")
        }
        .compositingGroup() // 先打组
        .shadow(radius: 10) // 再应用阴影
    }
}
```

---

### 4. 键盘与交互反馈 (Input Interaction)

**【现象】**：键盘弹出时背景闪烁或掉帧。

**【准则】**：
- [ ] **代理输入模式**：针对评论、搜索场景，使用"伪输入框按钮 + 独立弹出 Overlay"。
- [ ] **禁用无关避让**：在背景视图上显式使用 `.ignoresSafeArea(.keyboard)`，防止整个视图树在键盘弹出时进行坐标重算。

**示例**：
```swift
// ❌ 错误：键盘导致整个视图重绘
struct BadInputView: View {
    @State private var text = ""
    var body: some View {
        VStack {
            Header()
            List { /* ... */ }
            TextField("输入", text: $text) // 键盘弹出时整个 VStack 重算
        }
    }
}

// ✅ 正确：代理输入模式
struct GoodInputView: View {
    @State private var showInputOverlay = false
    var body: some View {
        ZStack {
            VStack {
                Header()
                List { /* ... */ }
                Button("点击输入") {
                    showInputOverlay = true
                }
            }
            .ignoresSafeArea(.keyboard) // 禁用键盘避让
            
            if showInputOverlay {
                InputOverlay() // 独立弹出层
            }
        }
    }
}
```

---

## TRAE 辅助开发与自检流程

### 第一步：代码修改指令

当要求 TRAE 修改动画代码时，必须包含以下关键词：

> "请优化此动画的渲染性能，确保视图颗粒度最小化，检查是否存在无意义的 body 重绘，并在复杂形变处考虑使用 drawingGroup。"

---

### 第二步：TRAE 交付后的自检报告格式

Trae 在提交代码后，必须回答以下检查项：

**🚀 动画性能审查 (Performance Check)**

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 重绘范围 | [ ] | 描述是否已将动画状态隔离在子视图中 |
| Body 复杂度 | [ ] | 确认 body 中无昂贵计算任务 |
| GPU 优化方案 | [ ] | 是否使用了 .drawingGroup() 或 .compositingGroup()？ |
| 布局开销 | [ ] | 是否避开了 GeometryReader 的性能陷阱？ |

---

### 第三步：Xcode 实机调试建议 (Manual Check)

1. **开启 Self._printChanges()**：在可疑视图内添加，观察控制台是否有意外的刷新频率。
   ```swift
   var body: some View {
       Self._printChanges() // 打印所有状态变化
       return VStack { /* ... */ }
   }
   ```

2. **Instruments - Hitches**：使用 Xcode Profiler 检查是否存在高于 5ms 的渲染延迟。

3. **Release 模式测试**：所有发热量和能效测试必须在 Release 配置下进行。

---

## 专家级避坑 Tips

### Opacity vs Hidden

如果你只是想让一个东西消失，`.opacity(0)` 依然会被渲染。使用 `if show { View }` 或 `.hidden()` 配合 transition。

```swift
// ❌ 错误：仍然占用渲染资源
Text("Hidden").opacity(0)

// ✅ 正确：完全从视图树移除
if show {
    Text("Visible")
} else {
    EmptyView()
}

// ✅ 或正确：使用 hidden() 配合 transition
Text("Hidden")
    .hidden(!show)
    .transition(.opacity)
```

### Continuous Corner

始终使用 `RoundedRectangle(cornerRadius: 20, style: .continuous)`。这不仅仅是为了好看，系统对平滑圆角的硬件加速更友好。

```swift
// ✅ 正确：使用 continuous 样式
RoundedRectangle(cornerRadius: 20, style: .continuous)

// ❌ 避免：默认样式性能稍差
RoundedRectangle(cornerRadius: 20)
```

### Spring 动画参数

优先使用 Response 和 Damping 参数而非秒数，这更符合物理规律，减少系统在插值计算时的震荡。

```swift
// ✅ 推荐：物理参数
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)

// ❌ 避免：固定时长
.animation(.easeInOut(duration: 0.3), value: isExpanded)
```

---

## TRAE 指引

请在后续所有涉及动画、手势、键盘吸附及复杂布局的指令中，严格遵守上述 MD 文档中的性能约束。若发现当前项目代码存在上述性能风险，请主动提出重构建议。

---

## 版本记录

| 版本 | 日期 | 更新内容 |
|------|------|---------|
| 1.0 | 2026-02-09 | 初始版本，建立四大核心准则和自检流程 |
