# iOS 丝滑原生动效（SwiftUI优先）Skill

目标：让 Codex/Agent 在实现交互与动效时，遵循“原生质感 + 高性能 + 可持续迭代”的方式工作，并把动效能力沉淀为可复用模块。

适用范围：
- SwiftUI 为主（UIKit 可混用）
- iOS 17+ 为主；部分能力 iOS 18+
- 优先“性能稳定/不掉帧”的实现方式（避免主线程重活）

------------------------------------------------------------
一、版本能力速查（重要）
iOS 17+：
- 数字滚轮文字过渡：contentTransition(.numericText)（数字变化更丝滑）[Apple Docs]
- SF Symbols 动效：symbolEffect / SymbolEffectTransition [Apple Docs]
- 视差与变形：visualEffect（基于几何代理的高性能效果）[Apple Docs]
- 多阶段/关键帧动画：PhaseAnimator / KeyframeAnimator [Apple Docs]
- ScrollView 新体系：scrollTargetBehavior(.viewAligned/.paging)、containerRelativeFrame、scrollClipDisabled、scrollTransition [Apple Docs]
- Metal Shader：colorEffect / distortionEffect / layerEffect（GPU）[Apple Docs]
- 触觉反馈：sensoryFeedback（声明式）[Apple Docs]

iOS 18+：
- 原生连续性导航转场：navigationTransition / zoomNavigationTransition（配合 matchedTransitionSource）[Apple Docs]
- 高级背景：MeshGradient（高质感流体渐变）[Apple Docs]
- 文字渲染：TextRenderer（逐字/波浪/乱码等高级文本效果）[Apple Docs]
- 滚动相位：ScrollPhase（拖拽/惯性/停止/程序滚动等）[Apple Docs]

------------------------------------------------------------
二、动效能力地图（从“便宜但高级”到“天花板”）

A. 交互反馈层（Interaction）
1) SF Symbols 动效（提示状态变化/反馈）
- 用途：按钮点击、状态切换、加载/录音等
- API：.symbolEffect(...)；或 SymbolEffectTransition
- 要点：用“短促、可解释”的效果；避免无意义持续摆动

2) 触觉（Haptics）
- SwiftUI：.sensoryFeedback(_:trigger:)（iOS17+）
- UIKit：UIImpactFeedbackGenerator / UINotificationFeedbackGenerator
- 要点：触觉与视觉同步；频率要克制；在关键动作点触发

3) 交互映射（Gesture-to-Visual mapping）
- 思路：手势进度 -> 视觉参数（blur/scale/offset/opacity）
- 高级：用 UIViewPropertyAnimator 做“可打断/可反转/跟手”的动画（UIKit）

B. 滚动系统层（Scroll System）
1) 磁吸/分页
- API：.scrollTargetBehavior(.viewAligned) / .paging
- 配套：.scrollTargetLayout + .scrollPosition（按需）
- 适合：相册式卡片、App Store 横向轮播

2) 滚动过渡（iOS17+）
- API：.scrollTransition(...)
- 用途：卡片进入/离开可视区域时自动做缩放/淡入/旋转/模糊
- 组合：scrollTransition + ScrollPhase（iOS18+）用于“停下瞬间强调”

3) 溢出裁剪与开放感
- API：.scrollClipDisabled(true)
- 用途：卡片可在滚动时穿越 header/tabbar 区域制造层级感

C. 内容与转场层（Transitions）
1) 数字内容过渡（iOS17+）
- API：contentTransition(.numericText(value:))
- 用途：计数、金额、排行榜名次等（“原生滚轮感”）

2) 自定义 Transition 体系
- AnyTransition 的 combined/asymmetric
- 统一定义：入场/退场的 offset+opacity+blur+scale 组合
- 目标：整 app 动效风格一致

3) 连续性/共享元素（Hero）
- SwiftUI：matchedGeometryEffect（iOS14+）
- iOS18+：navigationTransition(.zoom) + matchedTransitionSource
- 用途：列表卡片 -> 详情；头像 -> 个人页；图片 -> 浏览器

D. 渲染与特效层（Rendering）
1) MeshGradient（iOS18+）
- 用途：高级流体渐变背景（类似 Apple Card/Apple Intelligence 气质）
- 要点：轻微动、慢速动，避免喧宾夺主

2) TextRenderer（iOS18+）
- 用途：逐字入场、波浪、故障风、字符变换
- 要点：只在标题/关键段落使用；正文慎用

3) GPU Shader（iOS17+）
- API：colorEffect / distortionEffect / layerEffect
- 用途：水波纹、像素化、果冻扭曲、扫描线、发光
- 重点：尽量纯 GPU，避免主线程计算；限定采样偏移避免性能炸裂

4) Canvas + 视觉魔术（Metaballs）
- Canvas + blur + threshold（阈值）可做“液体融合/磁吸”
- 适合：录音按钮、浮动球、动态标签

E. 布局魔法层（Layout Magic）
1) containerRelativeFrame（iOS17+）
- 用途：App Store 风格横向轮播“一屏显示 1.2 张/3 张”
- 避免 GeometryReader 过度参与布局导致复杂度上升

2) visualEffect（iOS17+）
- 用途：视差/变形/跟随滚动位置做缩放旋转
- 要点：用几何代理驱动效果，不要频繁读取/计算昂贵数据

F. 物理动力学层（Spring & Physics）
1) 自定义 Spring
- 目标：形成你 app 的“黄金手感”
- 原则：弹簧只用于“回弹/吸附/强调”，常态动画用更克制的曲线
- UIKit：UISpringTimingParameters（更底层可控）

2) Keyframe / Phase 编排（iOS17+）
- PhaseAnimator：多阶段（缩小->放大->轻微抖动->复位）
- KeyframeAnimator：时间轴级精确控制

------------------------------------------------------------
三、性能与掉帧红线（必须遵守）
1) 禁止主线程重活：图片解码/大 JSON 解析/文件 IO/大循环
2) 滚动期间避免昂贵 work：onAppear 内不要做网络/解码/复杂布局计算
3) 动效优先 GPU：shader / compositing 优于 CPU 逐帧计算
4) 任何“炫酷效果”必须提供降级：
- 低电量/低端机/Reduce Motion 时自动降级（减少 blur/shader/频率）

------------------------------------------------------------
四、Codex 复用的工作法（强制流程）
每次实现动效/交互时，按以下步骤输出与执行：

Step 1：定义“动效意图”
- 这是反馈？强调？层级？连续性？还是叙事节奏？
- 对应选择：Interaction / Scroll / Transition / Rendering / Layout / Physics

Step 2：选 API（注明 iOS 版本与降级方案）
- iOS 17 基线实现
- iOS 18 增强实现（可选）
- Reduce Motion 降级实现（必须）

Step 3：实现小步可验证 Demo
- 先做最小可运行页面/组件
- 再接入真实页面
- 最后统一风格与抽象复用

Step 4：性能自检（必做）
- 列表滚动 10 秒无明显卡顿
- 快速进出页面 20 次不累积卡顿
- 关键动效触发 30 次不掉帧（主观+ Instruments）

Step 5：沉淀复用
- 把动效封装为：ViewModifier / Transition / 独立组件
- 写入：/ui/animations 或 /core/animations
- 在本 skill 文档补充“已实现的范式”链接

------------------------------------------------------------
五、可直接复制的 Prompt 模板（给 Codex）
模板A：实现“原生高级动效”
“为以下页面/组件设计并实现原生高级动效（以性能稳定为先）。
1) 先描述动效意图（反馈/连续性/层级/叙事节奏），再选 SwiftUI 原生 API。
2) iOS17 必须可用；如用到 iOS18+，必须写清降级策略。
3) 必须避免主线程重活与滚动掉帧；必要时改为 GPU shader 或更轻量方案。
4) 最后把实现抽象为可复用的 ViewModifier/Transition，并补充到本 skill.md 的‘已实现范式’。”

模板B：做“列表卡片 -> 详情”的丝滑连续性
“实现列表卡片到详情页的连续性转场：
- iOS18+ 优先使用 navigationTransition(.zoom) + matchedTransitionSource
- iOS17 降级使用 matchedGeometryEffect
要求：交互一致、可回退、卡顿为 0（滚动/转场期间不触发昂贵任务）。”

------------------------------------------------------------
六、推荐的“默认动效风格”参数（先给一个可调基线）
- 常规过渡：短、克制、速度一致
- 强调（点击/完成）：弹簧但幅度小，回弹快
- 滚动特效：慢、轻微、只对少量元素
- 背景动态：低频、低对比、避免抢内容

（注：具体曲线/参数建议在项目内形成统一常量：AnimationTokens.swift）
