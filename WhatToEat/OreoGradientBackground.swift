import SwiftUI

/// 奥利奥渐变背景 - 黑白撞色视觉秩序
/// 顶部黑色像奥利奥饼干，向下溶入牛奶
struct OreoGradientBackground: View {
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                stops: [
                    // 0.0 - 0.2: 纯黑色（Header 扎实底座）
                    Gradient.Stop(color: Color(hex: "#1A1A1A"), location: 0.0),
                    Gradient.Stop(color: Color(hex: "#1A1A1A"), location: 0.2),
                    // 0.2 - 0.5: 平滑过渡到奶白色
                    Gradient.Stop(color: Color(hex: "#4A4A4A"), location: 0.35),
                    Gradient.Stop(color: Color(hex: "#F7F8FA"), location: 0.5),
                    // 0.5 - 1.0: 完全奶白色
                    Gradient.Stop(color: Color(hex: "#F7F8FA"), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - 快捷调用扩展
extension View {
    /// 一键应用奥利奥渐变背景
    func useOreoGradientBackground() -> some View {
        self.background(OreoGradientBackground())
    }
}
