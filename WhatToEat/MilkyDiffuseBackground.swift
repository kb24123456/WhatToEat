import SwiftUI

/// 奶脂风格色彩弥散背景
/// 颜色：Baby Blue & Soft Pink
struct MilkyDiffuseBackground: View {
    @State private var isAnimating = false
    
    // 定义核心色彩
    private let blue = Color(hex: "#89CFF0")
    private let pink = Color(hex: "#FFD1DC")
    private let cream = Color(hex: "#FFFBEB") // 增加一点奶油黄过渡
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 基础底色：纯净白
                Color.white
                
                // 2. 弥散层
                ZStack {
                    // 右上角：Baby Blue
                    Circle()
                        .fill(blue)
                        .frame(width: geometry.size.width * 1.2)
                        .blur(radius: 80)
                        .opacity(0.35)
                        .offset(x: isAnimating ? 30 : -20, y: isAnimating ? -50 : 20)
                    
                    // 左下角：Soft Pink
                    Circle()
                        .fill(pink)
                        .frame(width: geometry.size.width * 1.1)
                        .blur(radius: 90)
                        .opacity(0.4)
                        .offset(x: isAnimating ? -40 : 40, y: isAnimating ? 60 : -30)
                    
                    // 中间偏右：奶油色（增加通透感）
                    Circle()
                        .fill(cream)
                        .frame(width: geometry.size.width * 0.8)
                        .blur(radius: 60)
                        .opacity(0.5)
                        .offset(x: isAnimating ? 50 : -30, y: isAnimating ? 20 : 80)
                }
                .scaleEffect(1.3) // 溢出画布，确保边缘无硬边
                .rotationEffect(.degrees(isAnimating ? 15 : -10))
            }
            .drawingGroup() // 关键：开启高性能渲染
        }
        .ignoresSafeArea() // 确保背景铺满，不干扰安全区域布局计算
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
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
