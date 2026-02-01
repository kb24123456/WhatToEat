import SwiftUI

/// 奶脂风格色彩弥散背景 - 柔和氛围式
/// 主体为纯白背景，顶部和底部各三分之一处有弥散色彩，中间三分之一留白
struct MilkyDiffuseBackground: View {
    @State private var isAnimating = false

    // 定义可见的点缀色彩（中等饱和度）
    private let softBlue = Color(hex: "#B8E0F8")    // 淡蓝
    private let softPink = Color(hex: "#F0D0E0")    // 淡粉

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 基础底色：纯净白（中间三分之一留白）
                Color.white

                // 2. 顶部弥散层 - 占顶部三分之一
                VStack {
                    HStack {
                        // 左上角：淡蓝弥散
                        Circle()
                            .fill(softBlue)
                            .frame(width: geometry.size.width * 0.6)
                            .blur(radius: 55)
                            .opacity(0.28)
                            .offset(x: -geometry.size.width * 0.15,
                                    y: -geometry.size.height * 0.05)

                        Spacer()

                        // 右上角：淡粉弥散
                        Circle()
                            .fill(softPink)
                            .frame(width: geometry.size.width * 0.55)
                            .blur(radius: 52)
                            .opacity(0.26)
                            .offset(x: geometry.size.width * 0.15,
                                    y: -geometry.size.height * 0.03)
                    }
                    .frame(height: geometry.size.height * 0.33)

                    Spacer() // 中间三分之一留白
                }

                // 3. 底部弥散层 - 占底部三分之一
                VStack {
                    Spacer() // 中间三分之一留白

                    HStack {
                        // 左下角：淡粉弥散
                        Circle()
                            .fill(softPink)
                            .frame(width: geometry.size.width * 0.5)
                            .blur(radius: 50)
                            .opacity(0.24)
                            .offset(x: -geometry.size.width * 0.12,
                                    y: geometry.size.height * 0.05)

                        Spacer()

                        // 右下角：淡蓝弥散
                        Circle()
                            .fill(softBlue)
                            .frame(width: geometry.size.width * 0.45)
                            .blur(radius: 48)
                            .opacity(0.24)
                            .offset(x: geometry.size.width * 0.12,
                                    y: geometry.size.height * 0.03)
                    }
                    .frame(height: geometry.size.height * 0.33)
                }
            }
            .drawingGroup() // 高性能渲染
        }
        .ignoresSafeArea()
        .onAppear {
            // 极缓慢的呼吸动画，几乎察觉不到
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                isAnimating = true
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
