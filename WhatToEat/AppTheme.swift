import SwiftUI

// MARK: - WhatToEat Design System v2.0
// 设计文档：https://github.com/kb24123456/WhatToEat/wiki/Design-System
//
// 设计原则：
// 1. 奶脂实色卡片风格 (Milky Solid Card Style)
// 2. 纯白实色背景 + 物理深度阴影 + 边缘高光
// 3. 冷灰背景 (#F8F9FB) + 纯白卡片 (Color.white)
//
// 历史版本：
// v1.0: Glassmorphism 毛玻璃风格 (已废弃)
// v2.0: Milky Solid 奶脂实色风格 (当前)

struct AppTheme {
    // MARK: - 1. 配色方案 (Design System v2.0 - 奶脂实色风格)
    struct Colors {
        // 背景色系统
        static let background = Color(hex: "#F8F9FB") // 柔和的浅灰背景
        static let navigationBar = Colors.background
        static let card = Color.white
        
        // 文字色系统 (柔和半透明)
        static let textPrimary = Color(hex: "#2C3E50") // 深蓝灰，柔和不刺眼
        static let textSecondary = Color(hex: "#7F8C8D").opacity(0.9) // 柔和 secondary
        static let textTertiary = Color(hex: "#95A5A6").opacity(0.7) // 更淡的辅助文字
        
        // 🔴 核心强调色（小红书红）
        static let accent = Color(hex: "#FF2442")
        static let accentGradient = LinearGradient(
            colors: [Color(hex: "#FF2442"), Color(hex: "#E61238")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // ✅ 辅助色系
        static let primary = Color(hex: "#5796E6")
        static let secondary = Color(hex: "#FFB347")
        static let success = Color(hex: "#43C59E")
        static let price = Color(hex: "#FF2442") // 小红书红
        
        // 柔和背景色
        static let lightRed = Color(hex: "#FFE8EE").opacity(0.8)
        static let lightBlue = Color(hex: "#EBF3FF").opacity(0.8)
        static let lightGreen = Color(hex: "#E8F7F2").opacity(0.8)
        static let lightGray = Color(hex: "#F0F2F5") // 收据风格输入框背景
        static let softBackground = Color(hex: "#F8F9FB")
        static let divider = Color.black.opacity(0.04) // 更淡的分隔线
        
        // MARK: - 奶脂实色风格专用 (v2.0)
        static let softSecondary = Color(hex: "#A2AAB1")
        static let milkyWhite = Color.white.opacity(0.95)
        static let shadowColor = Color.black.opacity(0.04)
        
        // MARK: - 语义化补齐
        /// 破坏性颜色，用于删除、取消等警示操作
        static let destructive = Color(hex: "#FF3B30")
        /// 警告颜色，用于智能识别不确定时的提示
        static let warning = Color(hex: "#FF9500")
        /// 婴儿蓝，用于特殊强调或装饰
        static let babyBlue = Color(hex: "#89CFF0")
        
        // MARK: - 极致细节专用
        /// 极致边缘高光色 (Rim Light)，用于 overlay 描边，提升物理厚度感
        static let rimLight = Color.white.opacity(0.6)
        /// 玻璃边框色，用于玻璃态效果
        static let glassBorder = Color.white.opacity(0.5)
        /// 玻璃白色，用于玻璃态背景
        static let glassWhite = Color.white.opacity(0.3)
        
        /// 奶脂玻璃蒙层渐变：用于图片底部的文字承载区
        static let milkyOverlayGradient = LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.4),
                Colors.milkyWhite // 使用你已有的 milkyWhite
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        /// 幽灵文字颜色：用于卡片背景的大数字水印（参考图中的 6% 透明度）
        static let ghostText = Color.black.opacity(0.06)
        
        // MARK: - 常用硬编码颜色统一
        static let darkText = Color(hex: "#1A1A1A")
        static let mediumGray = Color(hex: "#525252")
        static let lightText = Color(hex: "#999999")
        static let lighterGray = Color(hex: "#BBBBBB")
        static let ultraLightGray = Color(hex: "#CCCCCC")
        static let warmBackground = Color(hex: "#FBF9F7")
        static let warmGray = Color(hex: "#F5F3F0")
        static let cardBackground = Color(hex: "#F8F8F8")
        static let separatorGray = Color(hex: "#E0E0E0")
        static let darkBackground = Color(hex: "#2C2C2C")
        static let brownText = Color(hex: "#332E2B")
        static let darkBrown = Color(hex: "#8B7355")
        
        // MARK: - 情绪颜色
        static let moodSatisfied = Color(hex: "#FFB3BA")
        static let moodNeutral = Color(hex: "#E8E8E8")
        static let moodTerrible = Color(hex: "#666666")
        static let moodAmazing = Color(hex: "#FFE566")
        
        // MARK: - 图标颜色
        static let iconOrange = Color(hex: "#FF8C42")
        static let iconPurple = Color(hex: "#6B5B95")
        static let iconBlue = Color(hex: "#007AFF")
        static let iconAmber = Color(hex: "#FF9F43")
        
        // MARK: - 状态颜色
        static let successLight = Color(hex: "#E8F5E9")
        static let warningLight = Color(hex: "#FFF3E0")
        static let warningBorder = Color(hex: "#FF9F43").opacity(0.5)
        
        // MARK: - 五彩纸屑颜色
        static let confettiRed = Color(hex: "#FF2442")
        static let confettiBlue = Color(hex: "#5796E6")
        static let confettiGreen = Color(hex: "#43C59E")
        static let confettiOrange = Color(hex: "#FFB347")
        static let confettiPurple = Color(hex: "#9966FF")
    }
        
    // MARK: - 6. 设计规则 (Design System v2.0)
    struct Rules {
        // 导航栏规则
        static let navigationBarUseShadow = false // 导航栏不允许有阴影
        
        // 卡片规则
        static let restaurantCardUseShadow = false // 餐厅信息卡片不允许有阴影
    }
    
    // MARK: - 7. 奶脂实色卡片规范 (Design System v2.0)
    struct Card {
        /// 卡片背景色：纯白实色
        static let background = Color.white

        /// 卡片圆角：28pt (continuous 风格)
        static let cornerRadius: CGFloat = 28

        /// 卡片内边距：16pt
        static let padding: CGFloat = 16

        /// 卡片间距：12pt
        static let spacing: CGFloat = 12

        /// 边缘高光：白色描边，增强物理厚度感
        static let rimLight = Color.white.opacity(0.8)
        static let rimLightWidth: CGFloat = 0.5

        /// 双层阴影系统
        struct Shadow {
            /// 底层环境光：大范围柔和阴影
            static let ambient = (
                color: Color.black.opacity(0.04),
                radius: CGFloat(20),
                x: CGFloat(0),
                y: CGFloat(10)
            )
            /// 边缘定义光：小范围清晰阴影
            static let defining = (
                color: Color.black.opacity(0.06),
                radius: CGFloat(5),
                x: CGFloat(0),
                y: CGFloat(2)
            )
        }

        /// 内部输入框背景：极浅色，产生下陷感
        static let insetBackground = Color(hex: "#F0F2F5")

        /// 轻量级立体感卡片样式 - 统一应用到所有卡片
        static func standardStyle() -> some ViewModifier {
            CardStandardStyle()
        }
    }

    /// 标准卡片样式修饰符 - 轻量级立体感
    struct CardStandardStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: Card.cornerRadius, style: .continuous)
                        .fill(Card.background)
                        // 内阴影效果 - 增加厚度感
                        .overlay(
                            RoundedRectangle(cornerRadius: Card.cornerRadius, style: .continuous)
                                .stroke(Card.rimLight, lineWidth: Card.rimLightWidth)
                        )
                )
                // 轻量级双层阴影
                .shadow(
                    color: Card.Shadow.ambient.color,
                    radius: Card.Shadow.ambient.radius,
                    x: Card.Shadow.ambient.x,
                    y: Card.Shadow.ambient.y
                )
                .shadow(
                    color: Card.Shadow.defining.color,
                    radius: Card.Shadow.defining.radius,
                    x: Card.Shadow.defining.x,
                    y: Card.Shadow.defining.y
                )
        }
    }
    
    // MARK: - 2. 字体预设
    struct Fonts {
        static let largeTitle = Font.system(.largeTitle, design: .rounded).bold()
        static let title = Font.system(.title, design: .rounded).bold()
        static let title2 = Font.system(.title2, design: .rounded).bold()
        static let title3 = Font.system(.title3, design: .rounded).bold()
        static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let subheadline = Font.system(.subheadline, design: .rounded).weight(.medium)
        static let callout = Font.system(.callout, design: .rounded)
        static let footnote = Font.system(.footnote, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let caption1 = Font.system(.caption, design: .rounded)
        static let caption2 = Font.system(.caption2, design: .rounded)
    }
    
    // MARK: - 3. 间距系统
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16 // 卡片垂直间距：16pt
        static let xl: CGFloat = 32
        static let card: CGFloat = lg // card作为lg的别名，保持向后兼容
    }
    
    // MARK: - 4. 极致圆角
    struct Radius {
        static let base: CGFloat = 24 // 卡片圆角：24pt，营造更柔和的现代感
        static let small: CGFloat = 24
        static let sm: CGFloat = 8
        static let image: CGFloat = 24 // 图片圆角与卡片圆角一致
        static let circle: CGFloat = 100
    }
    
    // MARK: - 5. 阴影系统 (Premium Soft UI)
    struct Shadows {
        struct ShadowItem {
            let color: Color; let radius: CGFloat; let x: CGFloat; let y: CGFloat
        }
        // Ambient: 大范围柔和阴影
        static let ambient = ShadowItem(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 10)
        // Defining: 小范围定义阴影
        static let defining = ShadowItem(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
        // Premium Card: 双层阴影组合
        static let premium = (ambient: ambient, defining: defining)
        // Light: 轻微阴影
        static let light = ShadowItem(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        // Base: 基础阴影
        static let base = ShadowItem(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
        // Elevated: 弥散阴影（用于浮动按钮）
        static let elevated = ShadowItem(color: Color(hex: "#FF6B6B").opacity(0.3), radius: 12, x: 0, y: 8)
        static let elevatedSecondary = ShadowItem(color: Color(hex: "#FF6B6B").opacity(0.15), radius: 20, x: 0, y: 12)
    }
    
    // 兼容别名
    typealias Shadow = Shadows
    
    // MARK: - 6. 卡片尺寸规范
    struct Cards {
        static let restaurantCoverWidth: CGFloat = 100
        static let restaurantCoverHeight: CGFloat = 133.33
        static let restaurantCoverRatio: CGFloat = 3/4
    }
    
    // MARK: - 7. Premium Soft UI 动效规范
    struct Animations {
        // 标准弹簧动画 (response: 0.55, dampingFraction: 0.82)
        static let standardSpring = Animation.spring(response: 0.55, dampingFraction: 0.82)
        
        // 快速弹簧动画
        static let quickSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
        
        // 编辑状态切换弹簧动画
        static let editingSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
        
        // 标签操作弹簧动画
        static let tagSpring = Animation.spring(response: 0.3, dampingFraction: 0.75)
        
        // 交错入场延迟
        static let staggerDelay: Double = 0.05
        
        // 缩放淡入过渡
        static let transitionScaleOpacity: AnyTransition = .scale.combined(with: .opacity)
        
        // 从顶部滑入过渡
        static let transitionMoveTop: AnyTransition = .move(edge: .top).combined(with: .opacity)
        
        // 交错入场动画
        static func staggeredEntrance(index: Int) -> Animation {
            standardSpring.delay(Double(index) * staggerDelay)
        }
        
        // 触感反馈生成器
        static let lightImpact = UIImpactFeedbackGenerator(style: .light)
        static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
        static let successFeedback = UINotificationFeedbackGenerator()
    }
}

// MARK: - 颜色 Hex 支持
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - 输入框焦点效果插件
struct FocusedInputEffectModifier: ViewModifier {
    @FocusState.Binding var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            // 1. 动态边框：聚焦时显示强调色边框，失焦时隐藏
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(isFocused ? AppTheme.Colors.accent : Color.clear, lineWidth: 1.5)
            )
            // 2. 动态阴影：聚焦时增强阴影效果，失焦时恢复默认
            .shadow(
                color: isFocused ? AppTheme.Colors.accent.opacity(0.1) : Color.black.opacity(0.05),
                radius: isFocused ? 15 : 5,
                x: 0,
                y: isFocused ? 8 : 2
            )
            // 3. 动态缩放：聚焦时轻微放大，增强视觉反馈
            .scaleEffect(isFocused ? 1.02 : 1.0)
            // 4. 平滑动画过渡
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2), value: isFocused)
    }
}

// MARK: - 触感反馈插件
struct HapticFeedbackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.simultaneousGesture(TapGesture().onEnded {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        })
    }
}

extension View {
    /// 为输入框添加聚焦时的动态效果（边框高亮、阴影增强、缩放动画）
    func withFocusedInputEffects(isFocused: FocusState<Bool>.Binding) -> some View {
        self.modifier(FocusedInputEffectModifier(isFocused: isFocused))
    }

    func withHapticFeedback() -> some View {
        self.modifier(HapticFeedbackModifier())
    }

    /// 应用标准卡片样式 - 轻量级立体感
    /// 统一应用到所有卡片，保持全局一致性
    func cardStyle() -> some View {
        self.modifier(AppTheme.CardStandardStyle())
    }
    
    /// 强制收起键盘
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// 点击空白区域自动收起键盘
    func onTapOutsideHideKeyboard() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
}
