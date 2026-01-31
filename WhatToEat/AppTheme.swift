import SwiftUI

// MARK: - WhatToEat Design System v3.0
// 设计文档：https://github.com/kb24123456/WhatToEat/wiki/Design-System
//
// 设计原则：
// 1. 奶脂实色卡片风格 (Milky Solid Card Style)
// 2. 纯白实色背景 + 物理深度阴影 + 边缘高光
// 3. 冷灰背景 (#F8F9FB) + 纯白卡片 (Color.white)
// 4. 深色模式：深灰背景 + 层级递进
//
// 历史版本：
// v1.0: Glassmorphism 毛玻璃风格 (已废弃)
// v2.0: Milky Solid 奶脂实色风格 (浅色模式)
// v3.0: 支持深色模式的奶脂风格 (当前)

struct AppTheme {
    
    // MARK: - 环境感知颜色系统 (支持深色模式)
    struct Colors {
        
        // MARK: 核心动态颜色
        /// 卡片底色 - 动态适配
        static var card: Color {
            Color.dynamic(
                light: Color.white,
                dark: Color(hex: "#1C1C1E") // iOS 标准二级深色背景
            )
        }
        
        /// 全局背景色 - 动态适配
        static var softBackground: Color {
            Color.dynamic(
                light: Color(hex: "#F8F9FB"),
                dark: Color.black
            )
        }
        
        /// 文字主色 - 动态适配
        static var textPrimary: Color {
            Color.dynamic(
                light: Color(hex: "#1A1A1A"),
                dark: Color.white.opacity(0.9)
            )
        }
        
        /// 文字副色 - 动态适配
        static var textSecondary: Color {
            Color.dynamic(
                light: Color(hex: "#525252"),
                dark: Color.white.opacity(0.6)
            )
        }
        
        /// 背景色系统
        static var background: Color {
            Color.dynamic(
                light: Color(hex: "#F8F9FB"),
                dark: Color.black
            )
        }
        
        static var navigationBar: Color { background }
        
        // MARK: 文字色系统 (柔和半透明) - 保留向后兼容
        static var darkText: Color { textPrimary }
        static var mediumGray: Color { textSecondary }
        static var lightText: Color {
            Color.dynamic(
                light: Color(hex: "#999999"),
                dark: Color.white.opacity(0.4)
            )
        }
        static var lighterGray: Color {
            Color.dynamic(
                light: Color(hex: "#BBBBBB"),
                dark: Color.white.opacity(0.3)
            )
        }
        static var ultraLightGray: Color {
            Color.dynamic(
                light: Color(hex: "#CCCCCC"),
                dark: Color.white.opacity(0.25)
            )
        }
        
        // MARK: 辅助文字色
        static var textTertiary: Color {
            Color.dynamic(
                light: Color(hex: "#95A5A6").opacity(0.7),
                dark: Color.white.opacity(0.4)
            )
        }
        
        // MARK: 🔴 核心强调色（小红书红）- 深色模式下略微降低饱和度
        static var accent: Color {
            Color.dynamic(
                light: Color(hex: "#FF2442"),
                dark: Color(hex: "#FF3B5C") // 稍微亮一点，在深色中更醒目
            )
        }
        
        static var accentGradient: LinearGradient {
            LinearGradient(
                colors: [
                    Color.dynamic(light: Color(hex: "#FF2442"), dark: Color(hex: "#FF3B5C")),
                    Color.dynamic(light: Color(hex: "#E61238"), dark: Color(hex: "#FF2442"))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // MARK: ✅ 辅助色系
        static var primary: Color {
            Color.dynamic(
                light: Color(hex: "#5796E6"),
                dark: Color(hex: "#6BA3E8")
            )
        }
        static var secondary: Color {
            Color.dynamic(
                light: Color(hex: "#FFB347"),
                dark: Color(hex: "#FFC46B")
            )
        }
        static var success: Color {
            Color.dynamic(
                light: Color(hex: "#43C59E"),
                dark: Color(hex: "#5DD4B0")
            )
        }
        static var price: Color { accent }
        
        // MARK: 柔和背景色 - 深色模式下加深
        static var lightRed: Color {
            Color.dynamic(
                light: Color(hex: "#FFE8EE").opacity(0.8),
                dark: Color(hex: "#3D1F26").opacity(0.8)
            )
        }
        static var lightBlue: Color {
            Color.dynamic(
                light: Color(hex: "#EBF3FF").opacity(0.8),
                dark: Color(hex: "#1F2D3D").opacity(0.8)
            )
        }
        static var lightGreen: Color {
            Color.dynamic(
                light: Color(hex: "#E8F7F2").opacity(0.8),
                dark: Color(hex: "#1F3D33").opacity(0.8)
            )
        }
        static var lightGray: Color {
            Color.dynamic(
                light: Color(hex: "#F0F2F5"),
                dark: Color(hex: "#2C2C2E")
            )
        }
        static var softBackgroundColor: Color { softBackground }
        static var divider: Color {
            Color.dynamic(
                light: Color.black.opacity(0.04),
                dark: Color.white.opacity(0.08)
            )
        }
        
        // MARK: - 奶脂实色风格专用 (v3.0 支持深色)
        static var softSecondary: Color {
            Color.dynamic(
                light: Color(hex: "#A2AAB1"),
                dark: Color.white.opacity(0.5)
            )
        }
        static var milkyWhite: Color {
            Color.dynamic(
                light: Color.white.opacity(0.95),
                dark: Color.white.opacity(0.1)
            )
        }
        static var shadowColor: Color {
            Color.dynamic(
                light: Color.black.opacity(0.04),
                dark: Color.white.opacity(0.02)
            )
        }
        
        // MARK: - 语义化补齐
        static var destructive: Color {
            Color.dynamic(
                light: Color(hex: "#FF3B30"),
                dark: Color(hex: "#FF453A")
            )
        }
        static var warning: Color {
            Color.dynamic(
                light: Color(hex: "#FF9500"),
                dark: Color(hex: "#FFB340")
            )
        }
        static var babyBlue: Color {
            Color.dynamic(
                light: Color(hex: "#89CFF0"),
                dark: Color(hex: "#A0D9F5")
            )
        }
        
        // MARK: - 极致细节专用
        static var rimLight: Color {
            Color.dynamic(
                light: Color.white.opacity(0.6),
                dark: Color.white.opacity(0.15)
            )
        }
        static var glassBorder: Color {
            Color.dynamic(
                light: Color.white.opacity(0.5),
                dark: Color.white.opacity(0.1)
            )
        }
        static var glassWhite: Color {
            Color.dynamic(
                light: Color.white.opacity(0.3),
                dark: Color.white.opacity(0.08)
            )
        }
        
        /// 奶脂玻璃蒙层渐变 - 动态适配
        static var milkyOverlayGradient: LinearGradient {
            LinearGradient(
                colors: [
                    Color.dynamic(light: Color.white.opacity(0), dark: Color.black.opacity(0)),
                    Color.dynamic(light: Color.white.opacity(0.4), dark: Color.black.opacity(0.4)),
                    Color.dynamic(light: Colors.milkyWhite, dark: Color(hex: "#1C1C1E").opacity(0.9))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        /// 幽灵文字颜色
        static var ghostText: Color {
            Color.dynamic(
                light: Color.black.opacity(0.06),
                dark: Color.white.opacity(0.05)
            )
        }
        
        // MARK: - 常用硬编码颜色统一 (支持深色)
        static var warmBackground: Color {
            Color.dynamic(
                light: Color(hex: "#FBF9F7"),
                dark: Color(hex: "#1C1C1E")
            )
        }
        static var warmGray: Color {
            Color.dynamic(
                light: Color(hex: "#F5F3F0"),
                dark: Color(hex: "#2C2C2E")
            )
        }
        static var cardBackground: Color {
            Color.dynamic(
                light: Color(hex: "#F8F8F8"),
                dark: Color(hex: "#1C1C1E")
            )
        }
        static var separatorGray: Color {
            Color.dynamic(
                light: Color(hex: "#E0E0E0"),
                dark: Color(hex: "#3A3A3C")
            )
        }
        static var darkBackground: Color {
            Color.dynamic(
                light: Color(hex: "#2C2C2C"),
                dark: Color(hex: "#121212")
            )
        }
        static var brownText: Color {
            Color.dynamic(
                light: Color(hex: "#332E2B"),
                dark: Color(hex: "#E8E3DF")
            )
        }
        static var darkBrown: Color {
            Color.dynamic(
                light: Color(hex: "#8B7355"),
                dark: Color(hex: "#A68B6A")
            )
        }
        
        // MARK: - 情绪颜色 (深色模式下更柔和)
        static var moodSatisfied: Color {
            Color.dynamic(
                light: Color(hex: "#FFB3BA"),
                dark: Color(hex: "#FFB3BA").opacity(0.8)
            )
        }
        static var moodNeutral: Color {
            Color.dynamic(
                light: Color(hex: "#E8E8E8"),
                dark: Color(hex: "#3A3A3C")
            )
        }
        static var moodTerrible: Color {
            Color.dynamic(
                light: Color(hex: "#666666"),
                dark: Color(hex: "#8E8E93")
            )
        }
        static var moodAmazing: Color {
            Color.dynamic(
                light: Color(hex: "#FFE566"),
                dark: Color(hex: "#FFE566").opacity(0.9)
            )
        }
        
        // MARK: - 图标颜色
        static var iconOrange: Color {
            Color.dynamic(
                light: Color(hex: "#FF8C42"),
                dark: Color(hex: "#FFA366")
            )
        }
        static var iconPurple: Color {
            Color.dynamic(
                light: Color(hex: "#6B5B95"),
                dark: Color(hex: "#8B7BB5")
            )
        }
        static var iconBlue: Color {
            Color.dynamic(
                light: Color(hex: "#007AFF"),
                dark: Color(hex: "#0A84FF")
            )
        }
        static var iconAmber: Color {
            Color.dynamic(
                light: Color(hex: "#FF9F43"),
                dark: Color(hex: "#FFB86B")
            )
        }
        
        // MARK: - 状态颜色
        static var successLight: Color {
            Color.dynamic(
                light: Color(hex: "#E8F5E9"),
                dark: Color(hex: "#1C3320")
            )
        }
        static var warningLight: Color {
            Color.dynamic(
                light: Color(hex: "#FFF3E0"),
                dark: Color(hex: "#3D2E1F")
            )
        }
        static var warningBorder: Color {
            Color.dynamic(
                light: Color(hex: "#FF9F43").opacity(0.5),
                dark: Color(hex: "#FFB86B").opacity(0.4)
            )
        }
        
        // MARK: - 五彩纸屑颜色
        static var confettiRed: Color { accent }
        static var confettiBlue: Color { primary }
        static var confettiGreen: Color { success }
        static var confettiOrange: Color { secondary }
        static var confettiPurple: Color {
            Color.dynamic(
                light: Color(hex: "#9966FF"),
                dark: Color(hex: "#B794FF")
            )
        }
    }
    
    // MARK: - 6. 设计规则 (Design System v3.0)
    struct Rules {
        static let navigationBarUseShadow = false
        static let restaurantCardUseShadow = false
    }
    
    // MARK: - 7. 奶脂实色卡片规范 (v3.0 支持深色)
    struct Card {
        /// 卡片背景色 - 动态适配
        static var background: Color { Colors.card }
        
        static let cornerRadius: CGFloat = 28
        static let padding: CGFloat = 16
        static let spacing: CGFloat = 12
        
        /// 边缘高光 - 动态适配
        static var rimLight: Color { Colors.rimLight }
        static let rimLightWidth: CGFloat = 0.5
        
        /// 双层阴影系统 - 深色模式下使用白色微光
        struct Shadow {
            static var ambient: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
                (
                    color: Color.dynamic(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.02)),
                    radius: 20,
                    x: 0,
                    y: 10
                )
            }
            static var defining: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
                (
                    color: Color.dynamic(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.03)),
                    radius: 5,
                    x: 0,
                    y: 2
                )
            }
        }
        
        /// 内部输入框背景 - 动态适配
        static var insetBackground: Color {
            Color.dynamic(
                light: Color(hex: "#F0F2F5"),
                dark: Color(hex: "#2C2C2E")
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
        static let lg: CGFloat = 16
        static let xl: CGFloat = 32
        static let card: CGFloat = lg
    }
    
    // MARK: - 4. 极致圆角
    struct Radius {
        static let base: CGFloat = 24
        static let small: CGFloat = 24
        static let sm: CGFloat = 8
        static let image: CGFloat = 24
        static let circle: CGFloat = 100
    }
    
    // MARK: - 5. 阴影系统 (Premium Soft UI) - 深色模式适配
    struct Shadows {
        struct ShadowItem {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        
        static var ambient: ShadowItem {
            ShadowItem(
                color: Color.dynamic(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.02)),
                radius: 20,
                x: 0,
                y: 10
            )
        }
        
        static var defining: ShadowItem {
            ShadowItem(
                color: Color.dynamic(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.03)),
                radius: 5,
                x: 0,
                y: 2
            )
        }
        
        static var premium: (ambient: ShadowItem, defining: ShadowItem) {
            (ambient: ambient, defining: defining)
        }
        
        static var light: ShadowItem {
            ShadowItem(
                color: Color.dynamic(light: Color.black.opacity(0.03), dark: Color.white.opacity(0.015)),
                radius: 10,
                x: 0,
                y: 4
            )
        }
        
        static var base: ShadowItem {
            ShadowItem(
                color: Color.dynamic(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.025)),
                radius: 15,
                x: 0,
                y: 8
            )
        }
        
        static var elevated: ShadowItem {
            ShadowItem(
                color: Color.dynamic(
                    light: Color(hex: "#FF6B6B").opacity(0.3),
                    dark: Color(hex: "#FF6B6B").opacity(0.2)
                ),
                radius: 12,
                x: 0,
                y: 8
            )
        }
        
        static var elevatedSecondary: ShadowItem {
            ShadowItem(
                color: Color.dynamic(
                    light: Color(hex: "#FF6B6B").opacity(0.15),
                    dark: Color(hex: "#FF6B6B").opacity(0.1)
                ),
                radius: 20,
                x: 0,
                y: 12
            )
        }
    }
    
    typealias Shadow = Shadows
    
    // MARK: - 6. 卡片尺寸规范
    struct Cards {
        static let restaurantCoverWidth: CGFloat = 100
        static let restaurantCoverHeight: CGFloat = 133.33
        static let restaurantCoverRatio: CGFloat = 3/4
    }
    
    // MARK: - 7. Premium Soft UI 动效规范
    struct Animations {
        static let standardSpring = Animation.spring(response: 0.55, dampingFraction: 0.82)
        static let quickSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let editingSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let tagSpring = Animation.spring(response: 0.3, dampingFraction: 0.75)
        static let staggerDelay: Double = 0.05
        static let transitionScaleOpacity: AnyTransition = .scale.combined(with: .opacity)
        static let transitionMoveTop: AnyTransition = .move(edge: .top).combined(with: .opacity)
        
        static func staggeredEntrance(index: Int) -> Animation {
            standardSpring.delay(Double(index) * staggerDelay)
        }
        
        static let lightImpact = UIImpactFeedbackGenerator(style: .light)
        static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
        static let successFeedback = UINotificationFeedbackGenerator()
    }
}

// MARK: - 颜色动态适配扩展
extension Color {
    /// 创建动态适配浅色/深色模式的颜色
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            UIColor(traitCollection.userInterfaceStyle == .dark ? dark : light)
        })
    }
    
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
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(isFocused ? AppTheme.Colors.accent : Color.clear, lineWidth: 1.5)
            )
            .shadow(
                color: isFocused ? AppTheme.Colors.accent.opacity(0.1) : AppTheme.Colors.shadowColor,
                radius: isFocused ? 15 : 5,
                x: 0,
                y: isFocused ? 8 : 2
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
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
    func withFocusedInputEffects(isFocused: FocusState<Bool>.Binding) -> some View {
        self.modifier(FocusedInputEffectModifier(isFocused: isFocused))
    }
    
    func withHapticFeedback() -> some View {
        self.modifier(HapticFeedbackModifier())
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func onTapOutsideHideKeyboard() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
}
