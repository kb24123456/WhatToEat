import SwiftUI

/// 奥利奥奶脂瓷感背景 - 高标准的纯净奶白视觉
/// 类似高级陶瓷的温润质感，干净、温暖、有层次
struct MilkyCanvas: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 底色层：奶白基础色
                AppTheme.Colors.milkyBase
                    .ignoresSafeArea()
                
                // 光影层：顶部中央柔和高光
                RadialGradient(
                    colors: [
                        Color(hex: "#FFFFFF").opacity(0.4),
                        Color(hex: "#FFFFFF").opacity(0.0)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.2),
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.8
                )
                .ignoresSafeArea()
                
                // 纹理层：极其微弱的噪点质感
                Color.black.opacity(0.01)
                    .blur(radius: 0.5)
                    .ignoresSafeArea()
                    .blendMode(.overlay)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 快捷调用扩展
extension View {
    /// 一键应用奶白瓷感背景
    func useMilkyCanvas() -> some View {
        self.background(MilkyCanvas())
    }
}
