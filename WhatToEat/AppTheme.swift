import SwiftUI
import UIKit

// MARK: - App Appearance Mode
enum AppAppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

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
    // MARK: - 1. 配色方案 (Misty Oreo Design System)
    struct Colors {
        // 背景色系统
        static let background = Color(hex: "#FFFFFF") // 纯白背景
        static let navigationBar = Colors.background
        static let card = Color.adaptiveHex(light: "#FFFFFF", dark: "#1C1F25")
        
        // 文字色系统
        static let textPrimary = Color(hex: "#1A1A1A") // 主文字
        static let textSecondary = Color(hex: "#1A1A1A").opacity(0.6) // 次要文字
        static let textTertiary = Color(hex: "#1A1A1A").opacity(0.4) // 辅助文字
        
        // 🔴 核心强调色（小红书红）- 感性动作
        static let accent = Color(hex: "#FF2442")
        static let xhsRed = Color(hex: "#FF2442")
        static let accentGradient = LinearGradient(
            colors: [Color(hex: "#FF2442"), Color(hex: "#E61238")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // 🪸 珊瑚红 - 温暖活力点缀色
        static let coralRed = Color(hex: "#FF6B6B")
        static let coralGradient = LinearGradient(
            colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E8E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // ✅ 辅助色系
        static let primary = Color(hex: "#89CFF0") // Baby Blue - 理性数据
        static let babyBlue = Color(hex: "#89CFF0") // 理性数据专用
        static let secondary = Color(hex: "#FFB347")
        static let success = Color(hex: "#43C59E")
        static let price = Color(hex: "#89CFF0") // 价格用 babyBlue
        
        // 柔和背景色
        static let lightRed = Color(hex: "#FFE8EE").opacity(0.8)
        static let lightBlue = Color(hex: "#EBF3FF").opacity(0.8)
        static let lightGreen = Color(hex: "#E8F7F2").opacity(0.8)
        static let lightGray = Color(hex: "#F0F2F5") // 收据风格输入框背景
        static let softBackground = Color(hex: "#F8F9FB")
        static let divider = Color.adaptiveHex(light: "#1A1A1A", dark: "#E6EBF4").opacity(0.08) // 更淡的分隔线
        
        // MARK: - Misty Oreo 专用
        static let softSecondary = Color(hex: "#A2AAB1")
        static let milkyWhite = Color.adaptiveHex(light: "#FFFFFF", dark: "#171A20").opacity(0.25) // 极淡透明度
        static let shadowColor = Color.adaptiveHex(light: "#000000", dark: "#000000").opacity(0.22)
        
        // MARK: - 奥利奥奶脂专用 (Oreo Cream)
        static let milkyBase = Color(hex: "#F7F8FA")      // 大背景色，比纯白深一点
        static let pureWhite = Color(hex: "#FFFFFF")      // 用于卡片和容器
        static let rimLight = Color.adaptiveHex(light: "#FFFFFF", dark: "#2C333E").opacity(0.75)    // 卡片边缘高光
        static let ceramicShadow = Color.adaptiveHex(light: "#000000", dark: "#000000").opacity(0.22)  // 极其弥散的阴影
        static let physicalEdge = Color.adaptiveHex(light: "#000000", dark: "#FFFFFF").opacity(0.06)   // 物理切痕感描边
        
        // MARK: - LibraryView 专用
        static let milkWhite = Color(hex: "#fdf9f3")  // 奶白背景色
        
        // MARK: - 全局背景色（中性灰白，所有视图统一使用）
        static let pageBackground = Color.adaptiveHex(light: "#f9f9f7", dark: "#0E1320")
        
        // MARK: - 语义化补齐
        /// 破坏性颜色，用于删除、取消等警示操作
        static let destructive = Color(hex: "#FF3B30")
        /// 警告颜色，用于智能识别不确定时的提示
        static let warning = Color(hex: "#FF9500")
        
        // MARK: - 极致细节专用
        // rimLight 已在奥利奥奶脂专用中定义：Color(hex: "#FFFFFF").opacity(0.8)
        /// 玻璃边框色，用于玻璃态效果
        static let glassBorder = Color(hex: "#FFFFFF").opacity(0.5)
        /// 玻璃白色，用于玻璃态背景
        static let glassWhite = Color(hex: "#FFFFFF").opacity(0.3)
        
        /// Misty Oreo 蒙层渐变：极淡
        static let milkyOverlayGradient = LinearGradient(
            colors: [
                Color(hex: "#FFFFFF").opacity(0),
                Color(hex: "#FFFFFF").opacity(0.1),
                Colors.milkyWhite // 0.2 透明度
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        /// 幽灵文字颜色：用于卡片背景的大数字水印（参考图中的 6% 透明度）
        static let ghostText = Color.adaptiveHex(light: "#000000", dark: "#FFFFFF").opacity(0.10)
        
        // MARK: - 常用硬编码颜色统一
        static let darkText = Color.adaptiveHex(light: "#1A1A1A", dark: "#EEF2F8")
        static let mediumGray = Color.adaptiveHex(light: "#525252", dark: "#B8C0CE")
        static let lightText = Color.adaptiveHex(light: "#999999", dark: "#929CAD")
        static let lighterGray = Color.adaptiveHex(light: "#BBBBBB", dark: "#A4AEBD")
        static let ultraLightGray = Color.adaptiveHex(light: "#CCCCCC", dark: "#8E99AA")
        static let warmBackground = Color(hex: "#FBF9F7")
        static let warmGray = Color(hex: "#F5F3F0")
        static let cardBackground = Color(hex: "#F8F8F8")
        static let separatorGray = Color.adaptiveHex(light: "#E0E0E0", dark: "#343A45")
        static let darkBackground = Color.adaptiveHex(light: "#2C2C2C", dark: "#101217")
        static let brownText = Color(hex: "#332E2B")
        static let darkBrown = Color(hex: "#8B7355")

        // MARK: - 语义化补充（深色模式核心）
        static let modalBackground = Color.adaptiveHex(light: "#FFFFFF", dark: "#111A27")
        static let elevatedCard = Color.adaptiveHex(light: "#FFFFFF", dark: "#171A20")
        static let overlay = Color.adaptiveHex(light: "#000000", dark: "#000000").opacity(0.30)
        static let primaryButtonBackground = Color.adaptiveHex(light: "#1A1A1A", dark: "#EEF2F8")
        static let primaryButtonText = Color.adaptiveHex(light: "#FFFFFF", dark: "#101217")
        static let secondaryButtonBackground = Color.adaptiveHex(light: "#FFFFFF", dark: "#1D2330")
        static let surfacePrimary = Color.adaptiveHex(light: "#FFFFFF", dark: "#171A20")
        static let surfaceSecondary = Color.adaptiveHex(light: "#F5F7F8", dark: "#1D2430")
        static let inputFieldBackground = Color.adaptiveHex(light: "#FFFFFF", dark: "#1B2230")
        static let headerPillBackground = Color.adaptiveHex(light: "#FFFFFF", dark: "#1B2536")
        static let headerPillBorder = Color.adaptiveHex(light: "#E6EBF4", dark: "#2D3B4E")
        static let topOverlayStrong = Color.adaptiveHex(light: "#FFFFFF", dark: "#0C1320")
        static let topOverlayMid = Color.adaptiveHex(light: "#FFFFFF", dark: "#0F1827")
        static let topOverlaySoft = Color.adaptiveHex(light: "#FFFFFF", dark: "#132033")
        static let tabActive = Color.adaptiveHex(light: "#1A1A1A", dark: "#FFFFFF")
        static let tabInactive = Color.adaptiveHex(light: "#7F8C8D", dark: "#96A6BC")
        
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
        
    // MARK: - 5. 布局规范 (Design System v2.0)
    struct Layout {
        /// 页面水平边距：50pt - 去容器化后的宽松边距，营造杂志感
        static let pagePadding: CGFloat = 50
        
        /// 模块垂直间距：24pt - 组件之间的呼吸空间
        static let sectionSpacing: CGFloat = 24
        
        /// 元素内部间距：16pt - 紧凑元素组
        static let elementSpacing: CGFloat = 16
    }

    // MARK: - 6. 设计规则 (Design System v2.0)
    struct Rules {
        // 导航栏规则
        static let navigationBarUseShadow = false // 导航栏不允许有阴影
        
        // 卡片规则
        static let restaurantCardUseShadow = false // 餐厅信息卡片不允许有阴影
    }
    
    // MARK: - 7. Misty Oreo 卡片规范
    struct Card {
        /// 卡片背景色：纯白实色
        static let background = Colors.elevatedCard

        /// 卡片圆角：32pt (continuous 风格)
        static let cornerRadius: CGFloat = 32

        /// 卡片内边距
        static let paddingHorizontal: CGFloat = 24
        static let paddingVertical: CGFloat = 20

        /// 模块间距：32pt 或 48pt
        static let spacingSmall: CGFloat = 32
        static let spacingLarge: CGFloat = 48

        /// 边框：极细黑色描边
        static let strokeColor = Colors.separatorGray.opacity(0.45)
        static let strokeWidth: CGFloat = 0.5

        /// 废弃阴影
        struct Shadow {
            static let ambient = (color: Color.clear, radius: CGFloat(0), x: CGFloat(0), y: CGFloat(0))
        }

        /// Misty Oreo 卡片样式 - 扁平 + 细边框
        static func standardStyle() -> some ViewModifier {
            CardStandardStyle()
        }
    }

    /// Misty Oreo 标准卡片样式 - 扁平 + 细边框
    struct CardStandardStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(.horizontal, Card.paddingHorizontal)
                .padding(.vertical, Card.paddingVertical)
                .background(
                    RoundedRectangle(cornerRadius: Card.cornerRadius, style: .continuous)
                        .fill(Card.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: Card.cornerRadius, style: .continuous)
                                .stroke(Card.strokeColor, lineWidth: Card.strokeWidth)
                        )
                )
            // 无阴影 - Misty Oreo 扁平风格
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
        
        // 思源圆体 (Resource Han Rounded CN) - 用于卡片中文标题
        static let titleYuanti = Font.custom("ResourceHanRoundedCN-Bold", size: 22)
        static let title2Yuanti = Font.custom("ResourceHanRoundedCN-Bold", size: 20)
        static let title3Yuanti = Font.custom("ResourceHanRoundedCN-Bold", size: 18)
        static let subheadlineYuanti = Font.custom("ResourceHanRoundedCN-Medium", size: 16)
        static let bodyYuanti = Font.custom("ResourceHanRoundedCN-Medium", size: 14)
        static let footnoteYuanti = Font.custom("ResourceHanRoundedCN-Medium", size: 12)
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
    static func fixedHex(_ hex: String) -> Color {
        Color(UIColor(hex: hex))
    }

    static func adaptiveHex(light: String, dark: String) -> Color {
        Color(
            UIColor { traits in
                UIColor(
                    hex: traits.userInterfaceStyle == .dark ? dark : light
                )
            }
        )
    }

    init(hex: String) {
        let normalized = Self.normalizeHex(hex)

        // 在深色模式对常见中性色做自动映射，减少历史硬编码改造成本
        let mappedLight = normalized
        let mappedDark = Self.resolvedDarkHex(for: normalized)

        self = Color(
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? mappedDark : mappedLight)
            }
        )
    }

    private static func normalizeHex(_ hex: String) -> String {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        if cleaned.count == 3 {
            return cleaned.map { "\($0)\($0)" }.joined()
        }
        return cleaned
    }

    private static func resolvedDarkHex(for normalized: String) -> String {
        if let mapped = darkHexMap[normalized] {
            return mapped
        }
        // 自动兜底：将“高亮+低饱和”的历史浅色背景在深色模式转为暗面底色
        guard let (r, g, b) = rgbComponents(from: normalized) else {
            return normalized
        }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(red: r, green: g, blue: b, alpha: 1).getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        )
        if brightness >= 0.94 && saturation <= 0.24 {
            return "1A1E26"
        }
        if brightness >= 0.88 && saturation <= 0.28 {
            return "242B36"
        }
        return normalized
    }

    private static func rgbComponents(from normalized: String) -> (CGFloat, CGFloat, CGFloat)? {
        var value: UInt64 = 0
        switch normalized.count {
        case 6:
            guard Scanner(string: normalized).scanHexInt64(&value) else { return nil }
            let r = CGFloat((value >> 16) & 0xFF) / 255.0
            let g = CGFloat((value >> 8) & 0xFF) / 255.0
            let b = CGFloat(value & 0xFF) / 255.0
            return (r, g, b)
        case 8:
            guard Scanner(string: normalized).scanHexInt64(&value) else { return nil }
            let r = CGFloat((value >> 16) & 0xFF) / 255.0
            let g = CGFloat((value >> 8) & 0xFF) / 255.0
            let b = CGFloat(value & 0xFF) / 255.0
            return (r, g, b)
        default:
            return nil
        }
    }

    private static let darkHexMap: [String: String] = [
        // Base surfaces
        "FFFFFF": "171A20",
        "FDF9F3": "171A20",
        "F9F9F7": "13161B",
        "F8F9FB": "1B1F26",
        "F7F8FA": "1A1D24",
        "FBF9F7": "161920",
        "F5F3F0": "1F242D",
        "F0F2F5": "252B36",
        "F8F8F8": "1D222B",
        "FAFAF8": "1A1F27",
        "F8F7F4": "1A1F27",
        "F5F5F5": "202631",
        "F0F0F0": "252B36",
        "F3F5F6": "242A34",
        "F3F5F7": "242A34",
        "F5F7F8": "242A34",
        "FFF5F0": "1E242E",
        "FFEEE5": "222833",
        "FFF8F5": "1E242E",
        "FFE8E0": "252C37",
        "FFF0EB": "212833",
        "FFF5F2": "1E242E",
        "FFEFE8": "222933",
        "FFF2EE": "212833",
        "FFF7F5": "1E242E",
        "FFF9F7": "1A2029",
        "FFF9F5": "1A2029",
        "FFF9E6": "2B2F39",
        "FFF0CC": "373A43",
        "FFF0F0": "2A2227",
        "FFF5F5": "2A2227",
        "FFE4D6": "3A3137",
        "FFD4C4": "51474B",
        "FFE0E0": "3C3136",
        "FFE8EE": "2A222B",
        "EBF3FF": "1D2431",
        "E8F7F2": "1D2A28",
        "E8F8F5": "1D2A28",
        "E8F5E9": "1E2924",
        "FFF3E0": "2F2A22",
        "E8E5E0": "2C313A",
        "F0EDE8": "2A3038",
        "E0E0E0": "343A45",
        "DFE6E9": "38414C",
        "E6E8EA": "37404A",
        // Text neutrals
        "1A1A1A": "EEF2F8",
        "2C2C2C": "E3E9F3",
        "2D3436": "E4EAF4",
        "332E2B": "E9DFD6",
        "4A4A4A": "BEC8D8",
        "525252": "B8C0CE",
        "5E646B": "A6B2C3",
        "636E72": "AEB9C9",
        "6B6B6B": "B0B8C6",
        "7F8C8D": "AAB5C2",
        "808991": "A9B3C2",
        "999999": "929CAD",
        "95A0A7": "9DA9B9",
        "B2BEC3": "96A3B3",
        "BBBBBB": "A4AEBD",
        "CCCCCC": "8E99AA",
        "A2AAB1": "9AA5B5",
        "AAB2B9": "9BA6B6",
        "8B7355": "CCBDA9",
        // Low-contrast supporting colors
        "E8E8E8": "3B404A"
    ]
}

private extension UIColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64

        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}

// MARK: - 宜忌类型扩展
extension YiJiType {
    var accentColor: Color {
        switch self {
        case .yi: return Color(hex: "#FF6B6B")  // 宜 - 红色
        case .ji: return Color(hex: "#00B894")  // 忌 - 绿色
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .yi: return Color(hex: "#FFF5F5")  // 宜 - 浅红色背景
        case .ji: return Color(hex: "#E8F8F5")  // 忌 - 浅绿色背景
        }
    }
}

// MARK: - 输入框焦点效果插件
struct FocusedInputEffectModifier: ViewModifier {
    @FocusState.Binding var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            // 1. 动态边框：聚焦时显示 Baby Blue 边框（适配黑色背景），失焦时隐藏
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .stroke(isFocused ? AppTheme.Colors.babyBlue : Color.clear, lineWidth: 1.5)
            )
            // 2. 动态阴影：聚焦时增强白色光晕效果，失焦时恢复默认
            .shadow(
                color: isFocused ? AppTheme.Colors.babyBlue.opacity(0.3) : Color.black.opacity(0.05),
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

// MARK: - Oreo 点击效果修饰符
struct OreoClickEffectModifier: ViewModifier {
    @State private var isPressed = false
    let impactStyle: UIImpactFeedbackGenerator.FeedbackStyle
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.1, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            UIImpactFeedbackGenerator(style: impactStyle).impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
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
    
    /// Oreo 点击效果 - 微交互升级
    /// - Parameter style: 震动反馈强度，黑色按钮用 .medium，彩色按钮用 .light
    func oreoClickEffect(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.modifier(OreoClickEffectModifier(impactStyle: style))
    }
}

// MARK: - Oreo 骨架屏组件
struct SkeletonView: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#F8F9FA"),
                        Color(hex: "#FFFFFF"),
                        Color(hex: "#F8F9FA")
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color(hex: "#FFFFFF").opacity(0.6),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.4)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.4)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - 骨架屏修饰符
struct SkeletonModifier: ViewModifier {
    let isLoading: Bool
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        ZStack {
            if isLoading {
                SkeletonView(width: width, height: height, cornerRadius: cornerRadius)
            } else {
                content
            }
        }
    }
}

extension View {
    /// Oreo: 骨架屏加载效果
    func skeleton(
        isLoading: Bool,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = 32
    ) -> some View {
        self.modifier(SkeletonModifier(
            isLoading: isLoading,
            width: width,
            height: height,
            cornerRadius: cornerRadius
        ))
    }
}
