代码结构：仅在单个代码块中编写完整的 Swift 代码。包含必要的 import SwiftUI 和 import Charts（如果需要图表）。
样式实现：所有样式必须直接通过 SwiftUI 的内联 View Modifiers 实现。回复结构为：先写一段设计思路说明，再放代码，最后写一段功能与交互细节的说明。
术语屏蔽：不要提及 SwiftUI、Modifier、State、Binding 或 Xcode 相关术语。
完整性：必须包含完整的 struct ContentView: View 以及预览代码 struct ContentView_Previews。代码应能直接粘贴到 Xcode 中运行。
图标规范：图标使用 Apple 原生的 SF Symbols。使用 .fontWeight(.light) 或 .imageScale(.medium) 来匹配 1.5 的视觉粗细。
设计风格：除非用户指定，否则默认采用简洁现代的 UI（不要提及具体品牌）。
自定义组件：复选框（Toggle）、滑块（Slider）、下拉菜单（Picker）、开关等组件需要通过 ButtonStyle 或自定义 View 实现，以达到非原生视觉的顶级质感（仅在 UI 需要时添加）。
字重微调：字重使用比需求稍细一级的样式：例如，需求为“粗体（Bold）”时，使用 .semibold；需求为“常规”时，使用 .light。
大标题优化：字号超过 20pt 的标题，必须设置紧凑的字间距：.tracking(-0.5)。
自适应布局：确保页面支持多种屏幕尺寸，优先使用 VStack/HStack/ZStack 配合 Spacer 和 Padding，避免硬编码固定宽高。
拒绝原生样式：不要直接使用原生的 List 或 Form 默认样式，使用 ScrollView 手工构建更具设计感的列表。
图表实现：如果需要图表，使用 iOS 16+ 的 Swift Charts 框架实现。注意容器适配，确保图表在 VStack 或 Container 中有明确的高度定义。
视觉层次：在合适的位置使用极细的分隔线（.frame(height: 0.5)）和柔和的描边（.overlay(RoundedRectangle(...).stroke(...))）。
背景处理：不要在最外层容器之外设置背景，所有背景逻辑写在 ZStack 的最底层或 body 的 .background() Modifier 中。
占位素材：如果没有指定图片，使用 AsyncImage 调用 Unsplash 的 URL（例如：https://source.unsplash.com/random/800x600?portrait）。
创意边界：在字体、布局上可以发挥创意，追求极致的细节，尤其是毛玻璃效果（.ultraThinMaterial）的运用。
风格继承：如果提供了原始设计、代码或参考图，必须严格保留原始的色值、圆角半径和组件比例。
交互动画：动画效果使用 SwiftUI 原生的 .animation(.spring(), value: ...) 实现。必须添加悬停（如果是 macOS 目标）或点击时的缩放反馈（.scaleEffect）和颜色过渡。
深色模式：若设计风格偏向科技感、未来主义，默认使用 .preferredColorScheme(.dark)。
浅色模式：若设计风格偏向商务、专业，默认使用 .preferredColorScheme(.light)。
图标细节：SF Symbols 严禁使用渐变色填充，保持纯色或层次色（Hierarchical），线条宽度保持一致。
对比度控制：使用柔和的对比度，例如使用 Color.primary.opacity(0.8) 而非纯黑色文字。
文字 Logo：Logo 仅使用纯文字，字间距设置为紧凑 .tracking(-1)，字重设为 .bold 或 .black。
导航规范：避免使用右下角悬浮的 “下载” 或 “返回” 按钮，将其整合进顶栏或底部标签栏设计中。
