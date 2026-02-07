import SwiftUI

// MARK: - 明亮主题背景
/// 全新的 iOS 17+ 风格明亮背景
struct LightThemeBackground: View {
    var body: some View {
        Color(hex: "#F8F8F8")
            .ignoresSafeArea()
    }
}

// MARK: - 明亮主题颜色配置
extension Color {
    // 主色调
    static let lightBackground = Color(hex: "#F8F8F8")
    static let lightCard = Color(hex: "#FFFFFF")
    static let lightTextPrimary = Color(hex: "#1A1A1A")
    static let lightTextSecondary = Color(hex: "#666666")
    static let lightTextTertiary = Color(hex: "#999999")
    
    // 强调色（温暖橙色）
    static let accentWarm = Color(hex: "#FF6B35")
    static let accentWarmLight = Color(hex: "#FFF5F0")
    
    // 搜索框背景
    static let searchBackground = Color(hex: "#F2F2F2")
    
    // 标签背景
    static let tagBackground = Color(hex: "#FFF5F0")
    static let tagText = Color(hex: "#FF6B35")
}

// MARK: - 明亮主题卡片样式
struct LightCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.lightCard)
            .cornerRadius(20)
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 20,
                x: 0,
                y: 4
            )
    }
}

extension View {
    func lightCard() -> some View {
        modifier(LightCardStyle())
    }
}

// MARK: - 搜索框样式
struct LightSearchBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.searchBackground)
            .cornerRadius(16)
    }
}

extension View {
    func lightSearchBar() -> some View {
        modifier(LightSearchBarStyle())
    }
}

// MARK: - 标签样式
struct LightTagStyle: ViewModifier {
    var isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentWarm : Color.tagBackground)
            .foregroundColor(isSelected ? .white : Color.tagText)
            .cornerRadius(12)
            .font(.system(size: 13, weight: .medium))
    }
}

extension View {
    func lightTag(isSelected: Bool = false) -> some View {
        modifier(LightTagStyle(isSelected: isSelected))
    }
}
