import SwiftUI

struct AppTheme {
    // MARK: - 1. 配色方案 (小红书红 + 奶油系)
    struct Colors {
        static let background = Color.white
        static let navigationBar = Colors.background // 导航栏颜色 = 背景颜色，自动跟随背景色变化
        static let card = Color.white
        static let textPrimary = Color(hex: "#332E2B")
        static let textSecondary = Color(hex: "#7D7770") // 加深5%，增加纸质书写感
        
        // 🔴 核心强调色（小红书红）
        static let accent = Color(hex: "#FF2442")
        
        // ✅ 补齐 primary 颜色（报错的关键）
        static let primary = Color(hex: "#5796E6") // 湖蓝色
        static let secondary = Color(hex: "#FFB347") // 蛋黄橙
        static let success = Color(hex: "#43C59E") // 碧绿色
        static let price = Color(hex: "#ff96a4") // 人均消费颜色
        
        static let lightRed = Color(hex: "#FFE8EE")
        static let lightBlue = Color(hex: "#EBF3FF")
        static let lightGreen = Color(hex: "#E8F7F2")
        static let lightGray = Color(hex: "#F5F5F5") // 浅灰色，用于评价信息背景
        static let divider = Color.black.opacity(0.05)
    }
    
    // MARK: - 6. 设计规则
    struct Rules {
        // 导航栏规则
        static let navigationBarUseShadow = false // 导航栏不允许有阴影
        
        // 卡片规则
        static let restaurantCardUseShadow = false // 餐厅信息卡片不允许有阴影
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
    
    // MARK: - 5. 阴影系统 (✅ 解决 Shadows 报错)
    struct Shadows {
        struct ShadowItem {
            let color: Color; let radius: CGFloat; let x: CGFloat; let y: CGFloat
        }
        static let light = ShadowItem(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        static let base = ShadowItem(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
        static let elevated = ShadowItem(color: Color(hex: "#FF2442").opacity(0.15), radius: 12, x: 0, y: 6)
    }
    
    // 兼容别名
    typealias Shadow = Shadows
    
    // MARK: - 6. 卡片尺寸规范
    struct Cards {
        static let restaurantCoverWidth: CGFloat = 100
        static let restaurantCoverHeight: CGFloat = 133.33
        static let restaurantCoverRatio: CGFloat = 3/4
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
