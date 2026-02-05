import SwiftUI

/// 奶脂风格色彩弥散背景 - 参考图实现版
/// 大面积柔和渐变，左侧和右下淡粉，右上淡青
struct MilkyDiffuseBackground: View {
    @State private var animate = false

    // 参考图色彩分析
    private let softPink = Color(hex: "#FCE8E8")      // 极淡粉色
    private let softCyan = Color(hex: "#E8F8F5")      // 极淡青色/薄荷
    private let softLavender = Color(hex: "#F0E8F8")  // 极淡薰衣草紫

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            ZStack {
                // 基础底色：极淡的暖白色
                Color(hex: "#FDFCFB").ignoresSafeArea()

                // 左侧大面积淡粉色 - 从左边渐入
                Ellipse()
                    .fill(softPink)
                    .frame(width: w * 0.8, height: h * 0.9)
                    .blur(radius: 120)
                    .opacity(0.5)
                    .offset(x: -w * 0.25, y: -h * 0.05)
                    .offset(x: animate ? 15 : -10)

                // 右下角淡粉色 - 大面积覆盖
                Ellipse()
                    .fill(softPink)
                    .frame(width: w * 0.9, height: h * 0.8)
                    .blur(radius: 140)
                    .opacity(0.45)
                    .offset(x: w * 0.2, y: h * 0.3)
                    .offset(y: animate ? -10 : 15)

                // 右上角淡青色/薄荷 - 清新感
                Ellipse()
                    .fill(softCyan)
                    .frame(width: w * 0.7, height: h * 0.7)
                    .blur(radius: 100)
                    .opacity(0.4)
                    .offset(x: w * 0.15, y: -h * 0.15)
                    .offset(x: animate ? -10 : 10, y: animate ? 10 : -10)

                // 中央偏下淡薰衣草紫 - 过渡色
                Ellipse()
                    .fill(softLavender)
                    .frame(width: w * 0.6, height: w * 0.6)
                    .blur(radius: 80)
                    .opacity(0.25)
                    .offset(y: h * 0.1)
            }
            .drawingGroup()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 25).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - 快捷调用扩展
extension View {
    /// 一键应用奶脂弥散背景
    func useMilkyDiffuseBackground() -> some View {
        self.background(MilkyDiffuseBackground())
    }
}
