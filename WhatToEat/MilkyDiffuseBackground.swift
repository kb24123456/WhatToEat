import SwiftUI

/// 奶脂风格色彩弥散背景
/// 颜色：Baby Blue & Soft Pink
struct MilkyDiffuseBackground: View {
    @State private var isAnimating = false
    
    // 定义核心色彩
    private let blue = Color(hex: "#89CFF0")
    private let pink = Color(hex: "#FFD1DC")
    private let cream = Color(hex: "#FFFBEB") // 增加一点奶油黄过渡
    
    // 动画速度倍数（默认1.0，越大越快）
    var animationSpeed: Double = 1.0
    
    // 基础动画时长
    private let baseDuration: Double = 12
    
    // 计算实际动画时长
    private var animationDuration: Double {
        baseDuration / animationSpeed
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 基础底色：纯净白
                Color.white
                
                // 2. 弥散层 - 覆盖整个屏幕
                ZStack {
                    // 左上角：Baby Blue
                    Circle()
                        .fill(blue)
                        .frame(width: geometry.size.width * 1.0)
                        .blur(radius: 80)
                        .opacity(0.4)
                        .offset(x: isAnimating ? -80 : -60, y: isAnimating ? -100 : -80)
                    
                    // 右上角：Baby Blue（第二块）
                    Circle()
                        .fill(blue)
                        .frame(width: geometry.size.width * 0.9)
                        .blur(radius: 70)
                        .opacity(0.35)
                        .offset(x: isAnimating ? 100 : 80, y: isAnimating ? -60 : -40)
                    
                    // 左中部：Soft Pink
                    Circle()
                        .fill(pink)
                        .frame(width: geometry.size.width * 1.1)
                        .blur(radius: 90)
                        .opacity(0.45)
                        .offset(x: isAnimating ? -60 : -40, y: isAnimating ? 100 : 80)
                    
                    // 右中部：Soft Pink（第二块）
                    Circle()
                        .fill(pink)
                        .frame(width: geometry.size.width * 0.9)
                        .blur(radius: 80)
                        .opacity(0.4)
                        .offset(x: isAnimating ? 80 : 60, y: isAnimating ? 50 : 30)
                    
                    // 底部中央：奶油色
                    Circle()
                        .fill(cream)
                        .frame(width: geometry.size.width * 1.0)
                        .blur(radius: 70)
                        .opacity(0.5)
                        .offset(x: isAnimating ? 30 : 10, y: isAnimating ? 200 : 180)
                    
                    // 底部左侧：Baby Blue（补充）
                    Circle()
                        .fill(blue)
                        .frame(width: geometry.size.width * 0.7)
                        .blur(radius: 60)
                        .opacity(0.3)
                        .offset(x: isAnimating ? -100 : -80, y: isAnimating ? 250 : 230)
                    
                    // 底部右侧：Soft Pink（补充）
                    Circle()
                        .fill(pink)
                        .frame(width: geometry.size.width * 0.8)
                        .blur(radius: 70)
                        .opacity(0.35)
                        .offset(x: isAnimating ? 120 : 100, y: isAnimating ? 220 : 200)
                }
                .scaleEffect(1.5) // 溢出画布，确保边缘无硬边
                .rotationEffect(.degrees(isAnimating ? 10 : -8))
            }
            .drawingGroup() // 关键：开启高性能渲染
        }
        .ignoresSafeArea() // 确保背景铺满，不干扰安全区域布局计算
        .onAppear {
            withAnimation(.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
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
