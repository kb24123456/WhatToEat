import SwiftUI

/// 奶脂风格色彩弥散背景 (支持深色模式)
/// 浅色：Baby Blue & Soft Pink
/// 深色：深蓝紫 & 暗粉紫 (霓虹灯效果)
struct MilkyDiffuseBackground: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    
    // 浅色模式色彩
    private let lightBlue = Color(hex: "#89CFF0")
    private let lightPink = Color(hex: "#FFD1DC")
    private let lightCream = Color(hex: "#FFFBEB")
    
    // 深色模式色彩 (深蓝紫调)
    private let darkBlue = Color(hex: "#4A90D9")
    private let darkPurple = Color(hex: "#6B5B95")
    private let darkPink = Color(hex: "#9B6B8A")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 基础底色：动态适配
                Color.dynamic(light: Color.white, dark: Color.black)
                
                // 2. 弥散层 - 覆盖整个屏幕
                ZStack {
                    // 左上角：Baby Blue / 深蓝
                    Circle()
                        .fill(colorScheme == .dark ? darkBlue : lightBlue)
                        .frame(width: geometry.size.width * 1.0)
                        .blur(radius: 80)
                        .opacity(colorScheme == .dark ? 0.15 : 0.4)
                        .offset(x: isAnimating ? -80 : -60, y: isAnimating ? -100 : -80)
                    
                    // 右上角：Baby Blue（第二块）/ 深紫
                    Circle()
                        .fill(colorScheme == .dark ? darkPurple : lightBlue)
                        .frame(width: geometry.size.width * 0.9)
                        .blur(radius: 70)
                        .opacity(colorScheme == .dark ? 0.12 : 0.35)
                        .offset(x: isAnimating ? 100 : 80, y: isAnimating ? -60 : -40)
                    
                    // 左中部：Soft Pink / 暗粉紫
                    Circle()
                        .fill(colorScheme == .dark ? darkPink : lightPink)
                        .frame(width: geometry.size.width * 1.1)
                        .blur(radius: 90)
                        .opacity(colorScheme == .dark ? 0.18 : 0.45)
                        .offset(x: isAnimating ? -60 : -40, y: isAnimating ? 100 : 80)
                    
                    // 右中部：Soft Pink（第二块）/ 深紫
                    Circle()
                        .fill(colorScheme == .dark ? darkPurple : lightPink)
                        .frame(width: geometry.size.width * 0.9)
                        .blur(radius: 80)
                        .opacity(colorScheme == .dark ? 0.15 : 0.4)
                        .offset(x: isAnimating ? 80 : 60, y: isAnimating ? 50 : 30)
                    
                    // 底部中央：奶油色 / 深蓝
                    Circle()
                        .fill(colorScheme == .dark ? darkBlue : lightCream)
                        .frame(width: geometry.size.width * 1.0)
                        .blur(radius: 70)
                        .opacity(colorScheme == .dark ? 0.12 : 0.5)
                        .offset(x: isAnimating ? 30 : 10, y: isAnimating ? 200 : 180)
                    
                    // 底部左侧：Baby Blue（补充）/ 深紫
                    Circle()
                        .fill(colorScheme == .dark ? darkPurple : lightBlue)
                        .frame(width: geometry.size.width * 0.7)
                        .blur(radius: 60)
                        .opacity(colorScheme == .dark ? 0.1 : 0.3)
                        .offset(x: isAnimating ? -100 : -80, y: isAnimating ? 250 : 230)
                    
                    // 底部右侧：Soft Pink（补充）/ 暗粉
                    Circle()
                        .fill(colorScheme == .dark ? darkPink : lightPink)
                        .frame(width: geometry.size.width * 0.8)
                        .blur(radius: 70)
                        .opacity(colorScheme == .dark ? 0.12 : 0.35)
                        .offset(x: isAnimating ? 120 : 100, y: isAnimating ? 220 : 200)
                }
                .scaleEffect(1.5)
                .rotationEffect(.degrees(isAnimating ? 10 : -8))
            }
            .drawingGroup()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
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
