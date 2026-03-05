import SwiftUI

/// 奥利奥奶油风格背景 - 纯净奶白色调
/// 类似奥利奥夹心的柔和奶白色，干净温暖
struct OreoCreamBackground: View {
    @State private var animate = false

    // 奥利奥奶油色系
    private let creamWhite = Color(hex: "#FAF9F7")      // 主背景：暖调奶白
    private let softCream = Color(hex: "#F5F3F0")       // 浅奶油色
    private let warmMilk = Color(hex: "#F0EDE8")        // 暖牛奶色
    private let subtleShadow = Color(hex: "#E8E5E0")    // 柔和阴影色

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            ZStack {
                // 基础底色：纯净奶白色
                creamWhite.ignoresSafeArea()

                // 左上角大面积柔和奶油色 - 营造温暖感
                Ellipse()
                    .fill(softCream)
                    .frame(width: w * 0.9, height: h * 0.8)
                    .blur(radius: 100)
                    .opacity(0.6)
                    .offset(x: -w * 0.2, y: -h * 0.1)
                    .offset(x: animate ? 10 : -5)

                // 右下角暖牛奶色 - 平衡视觉
                Ellipse()
                    .fill(warmMilk)
                    .frame(width: w * 0.8, height: h * 0.7)
                    .blur(radius: 120)
                    .opacity(0.5)
                    .offset(x: w * 0.15, y: h * 0.25)
                    .offset(y: animate ? -8 : 12)

                // 中央偏上微妙高光 - 增加层次感
                Ellipse()
                    .fill(Color(hex: "#FFFFFF"))
                    .frame(width: w * 0.5, height: w * 0.5)
                    .blur(radius: 80)
                    .opacity(0.4)
                    .offset(y: -h * 0.1)
                    .offset(x: animate ? -8 : 8, y: animate ? 5 : -5)

                // 底部柔和阴影过渡 - 增加深度
                Ellipse()
                    .fill(subtleShadow)
                    .frame(width: w * 0.7, height: h * 0.4)
                    .blur(radius: 100)
                    .opacity(0.3)
                    .offset(y: h * 0.35)
            }
            .drawingGroup()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - 快捷调用扩展
extension View {
    /// 一键应用奥利奥奶油背景
    func useOreoCreamBackground() -> some View {
        self.background(OreoCreamBackground())
    }
}
