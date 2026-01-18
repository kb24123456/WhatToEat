import SwiftUI

// MARK: - 🎨 核心设计系统 (全量名称兼容版)
struct AppTheme {
    
    // MARK: - 1. 色彩规范
    struct Colors {
        static let background = Color(hex: "#FCF9F7")
        static let card = Color.white
        static let textPrimary = Color(hex: "#332E2B")
        static let textSecondary = Color(hex: "#948E88")
        static let accent = Color(hex: "#FF2442") // 🔴 小红书红
        
        // 原始色值定义
        static let tagBlue = Color(hex: "#5796E6")
        static let tagOrange = Color(hex: "#FFB347")
        static let tagGreen = Color(hex: "#43C59E")
        static let tagPurple = Color(hex: "#9B6BFF")
        static let divider = Color.black.opacity(0.05)

        // ✅ 关键别名映射：解决 primary/secondary/success 报错
        static let primary = tagBlue     // 菜系用蓝
        static let secondary = tagOrange // 评分用橙
        static let success = tagGreen   // 区域用绿
        
        // 浅色底背景别名 (如果代码中有用到)
        static let lightBlue = tagBlue.opacity(0.12)
        static let lightOrange = tagOrange.opacity(0.12)
        static let lightGreen = tagGreen.opacity(0.12)
    }
    
    // MARK: - 2. 字体规范
    struct Fonts {
        static let largeTitle = Font.system(.largeTitle, design: .rounded).bold()
        static let title = Font.system(.title, design: .rounded).bold()
        static let title2 = Font.system(.title2, design: .rounded).bold()
        static let title3 = Font.system(.title3, design: .rounded).bold()
        static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let subheadline = Font.system(.subheadline, design: .rounded).weight(.medium)
        static let caption = Font.system(.caption, design: .rounded)
        static let caption1 = Font.system(.caption, design: .rounded)
        static let caption2 = Font.system(.caption2, design: .rounded)
    }

    // MARK: - 3. 几何布局规范
    struct Layout {
        static let cardRadius: CGFloat = 26
        static let capsuleRadius: CGFloat = 100
        static let menuRadius: CGFloat = 24
        static let spacingLg: CGFloat = 20
        static let spacingMd: CGFloat = 12
    }
    
    // MARK: - 4. 间距规范
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 32
        static let card: CGFloat = 16
    }
    
    // MARK: - 5. 圆角规范
    struct Radius {
        static let base: CGFloat = 26
        static let small: CGFloat = 16
        static let sm: CGFloat = 8
        static let circle: CGFloat = 100
        static let image: CGFloat = 20 // 解决卡片图片圆角报错
    }
    
    // MARK: - 6. 动效规范
    struct Animation {
        static let jelly = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0)
        static let morph = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)
        static let contentFade = SwiftUI.Animation.easeInOut(duration: 0.2)
    }
    
    // MARK: - 7. 阴影系统
    struct Shadows {
        static let cardShadow = Color.black.opacity(0.04)
        static let menuShadow = Color.black.opacity(0.12)
        static let buttonGlow = Color(hex: "#FF2442").opacity(0.2)
        
        // 内部结构定义
        struct ShadowItem {
            let color: Color; let radius: CGFloat; let x: CGFloat; let y: CGFloat
        }
        
        static let light = ShadowItem(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        static let base = ShadowItem(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
        static let elevated = ShadowItem(color: Color(hex: "#FF2442").opacity(0.15), radius: 12, x: 0, y: 6)
    }
    
    // 别名映射
    typealias Shadow = Shadows
}

// MARK: - 🛠️ 辅助工具与 View 修饰符 (保持不变)
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

struct StandardCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.Colors.card)
            .cornerRadius(AppTheme.Layout.cardRadius)
            .shadow(color: AppTheme.Shadows.cardShadow, radius: 10, x: 0, y: 4)
    }
}

extension View {
    func applyCardStyle() -> some View {
        self.modifier(StandardCardModifier())
    }
    func withHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.simultaneousGesture(TapGesture().onEnded {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        })
    }
}
