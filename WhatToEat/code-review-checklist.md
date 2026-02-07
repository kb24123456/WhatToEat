# iOS 代码检查清单

> 构建高性能、高维护性、逻辑纯净的 iOS 应用。确保每一行代码都有其存在的必要性，严禁功能冗余与逻辑冲突。

---

## 🧹 一、代码卫生与完整性 (Code Hygiene & Integrity)

### 1. 垃圾代码清理 (Zero Stale Code)

- [ ] **废弃逻辑移除**：修改功能后，必须立即删除旧的、不再使用的函数、属性和 ViewModifier。禁止使用注释掉的代码块（Commented-out code）
- [ ] **冗余导入**：检查并移除不再需要的库导入（如移除了图片处理逻辑后，检查是否还残留 Kingfisher 导入）
- [ ] **占位符清理**：删除调试用的 print 语句、硬编码的测试字符串以及临时的背景色（如 `.background(.red)`）

### 2. 逻辑冲突预防 (Conflict Prevention)

- [ ] **路径唯一性**：确保同一交互逻辑只有一条代码路径。例如：严禁在视图内部直接修改状态的同时，又在 ViewModel 中异步修改同一状态导致竞态
- [ ] **状态自洽**：检查新旧代码对 @State 或 @Published 变量的控制逻辑是否存在矛盾。如果新逻辑取代了旧逻辑，必须重构相关联的 if/else 或 switch 分支
- [ ] **UI 样式统一**：新生成的 UI 组件必须与项目中已有的系统（如自定义的 Color 扩展、Font 样式）保持一致，严禁出现两套不兼容的样式定义

---

## 🏗 二、架构与数据流 (Data Flow & Architecture)

### 1. 单一事实来源 (SSOT)

**状态选择**：优先考虑数据流的简洁性。复杂逻辑必须抽离到 ViewModel，View 只负责声明式展示。

- [ ] **检查**：ViewModel 中是否存在相互冲突的"标记位"（Flag）？尝试用 Enum（枚举状态机）取代多个单独的 Bool 以防止非法状态组合

---

## 🎨 三、UI 布局与视觉标准 (UI & Layout)

### 1. 布局健壮性与交互

- [ ] **交互代理模式**：针对搜索、评论等高频输入场景，坚持"伪输入框按钮 + 独立弹出层"设计，确保背景静止
- [ ] **动画同步**：所有视图切换必须平滑，避免突兀的位移
- [ ] **适配性**：支持 Dark Mode、Dynamic Type 及各机型安全区域

---

## ⚡ 四、性能优化 (Performance)

- [ ] **视图拆分**：body 属性超过 40 行强制拆分
- [ ] **避免过度渲染**：严禁在 body 或计算属性中进行高能耗计算（如 Data 转换、复杂正则表达式）
- [ ] **AnyView 禁令**：禁止使用 AnyView，使用 @ViewBuilder 或 Group 替代

---

## 🧵 五、并发与安全 (Concurrency & Safety)

- [ ] **Actor 模型**：UI 更新必须绑定在 @MainActor
- [ ] **任务管理**：使用 .task 取代 onAppear 处理异步逻辑，确保视图销毁时任务自动取消

---

## 🛠 TRAE 执行修改后的"全量自检报告"格式

Trae 在完成修改后，必须严格按照以下清单汇报，否则视为未完成任务：

### 🚀 iOS 专家代码交付报告

#### 1. 功能实现与重构

**新增逻辑**：简述新增功能或修改内容

**清理项**：[已删除哪些冗余代码/过时逻辑]

#### 2. 代码卫生自查 (Hygiene Check)

**垃圾代码**：[确认已移除注释代码、废弃变量及临时调试代码]

**逻辑冲突**：[确认新逻辑与旧逻辑无交叉冲突，状态机转换正常]

#### 3. 技术标准对齐

**架构/性能**：[是否符合 SSOT，是否存在 AnyView，body 是否已拆分]

**交互反馈**：[键盘吸附/动画/安全区域处理情况]

#### 4. 潜在风险排查

[是否存在因修改导致的周边组件受损风险？]

---

## 📋 快速检查命令

```bash
# 检查未使用的导入
grep -r "import" --include="*.swift" . | sort | uniq

# 检查 print 语句
grep -r "print(" --include="*.swift" .

# 检查注释掉的代码
grep -r "^\s*//" --include="*.swift" . | grep -E "(func|var|let|struct|class)"

# 检查 AnyView 使用
grep -r "AnyView" --include="*.swift" .

# 检查 body 行数（超过40行需拆分）
awk '/body.*some.*View/,/^\s*\}/ {count++} /^\s*\}/ && count>0 {if(count>45) print FILENAME": "count" lines"; count=0}' *.swift
```

---

## 🎯 项目特定规范

### 当前项目架构

- **UI 框架**：SwiftUI
- **数据持久化**：SwiftData
- **设计系统**：AppTheme（自定义主题系统）
- **输入策略**：MilkyInputProxy（全局输入管理）

### 关键组件检查点

| 组件 | 检查要点 |
|------|----------|
| `RestaurantDetailView` | 点评按钮使用 DragGesture 实现即时响应 |
| `AddRestaurantView` | 点评按钮使用 DragGesture 实现即时响应 |
| `LibraryView` | 搜索使用 MilkyInputProxy 代理模式 |
| `NavigationManager` | 第三方导航使用路径规划模式 |
| `MapSearchSheet` | 地图搜索使用 Sheet 弹出 |

---

*最后更新：2025-02-07*
