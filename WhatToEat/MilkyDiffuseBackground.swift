import SwiftUI

/// 奶脂风格色彩弥散背景 - 支持深色模式
/// 浅色：Baby Blue & Soft Pink
/// 深色：Deep Purple & Midnight Blue
struct MilkyDiffuseBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    
    // 浅色模式颜色
    private let lightBlue = Color(hex: "#89CFF0")
    private let lightPink = Color(hex: "#FFD1DC")
    private let lightCream = Color(hex: "#FFFBEB")
    
    // 深色模式颜色
    private let darkPurple = Color(hex: "#4A3F6B")
    private let darkBlue = Color(hex: "#2A3F5F")
    private let darkIndigo = Color(hex: "#3D3F5C")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 基础底色
                baseColor
                
                // 2. 弥散层 - 覆盖整个屏幕
                ZStack {
                    // 左上角
                    Circle()
                        .fill(orbColor1)
                        .frame(width: geometry.size.width * 1.0)
                        .blur(radius: 80)
                        .opacity(orbOpacity1)
                        .offset(x: isAnimating ? -80 : -60, y: isAnimating ? -100 : -80)
                    
                    // 右上角
                    Circle()
                        .fill(orbColor2)
                        .frame(width: geometry.size.width * 0.9)
                        .blur(radius: 70)
                        .opacity(orbOpacity2)
                        .offset(x: isAnimating ? 100 : 80, y: isAnimating ? -60 : -40)
                    
                    // 左中部
                    Circle()
                        .fill(orbColor3)
                        .frame(width: geometry.size.width * 1.1)
                        .blur(radius: 90)
                        .opacity(orbOpacity3)
                        .offset(x: isAnimating ? -60 : -40, y: isAnimating ? 100 : 80)
                    
                    // 右中部
                    Circle()
                        .fill(orbColor4)
                        .frame(width: geometry.size.width * 0.9)
                        .blur(radius: 80)
                        .opacity(orbOpacity4)
                        .offset(x: isAnimating ? 80 : 60, y: isAnimating ? 50 : 30)
                    
                    // 底部中央
                    Circle()
                        .fill(orbColor5)
                        .frame(width: geometry.size.width * 1.0)
                        .blur(radius: 70)
                        .opacity(orbOpacity5)
                        .offset(x: isAnimating ? 30 : 10, y: isAnimating ? 200 : 180)
                    
                    // 底部左侧
                    Circle()
                        .fill(orbColor6)
                        .frame(width: geometry.size.width * 0.7)
                        .blur(radius: 60)
                        .opacity(orbOpacity6)
                        .offset(x: isAnimating ? -100 : -80, y: isAnimating ? 250 : 230)
                    
                    // 底部右侧
                    Circle()
                        .fill(orbColor7)
                        .frame(width: geometry.size.width * 0.8)
                        .blur(radius: 70)
                        .opacity(orbOpacity7)
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
    
    // MARK: - 基础背景色
    private var baseColor: Color {
        colorScheme == .dark ? Color(hex: "#1A1F2E") : Color.white
    }
    
    // MARK: - 弥散光球颜色（浅色模式）
    private var orbColor1: Color { colorScheme == .dark ? darkBlue : lightBlue }
    private var orbColor2: Color { colorScheme == .dark ? darkPurple : lightBlue }
    private var orbColor3: Color { colorScheme == .dark ? darkPurple : lightPink }
    private var orbColor4: Color { colorScheme == .dark ? darkIndigo : lightPink }
    private var orbColor5: Color { colorScheme == .dark ? darkBlue : lightCream }
    private var orbColor6: Color { colorScheme == .dark ? darkIndigo : lightBlue }
    private var orbColor7: Color { colorScheme == .dark ? darkPurple : lightPink }
    
    // MARK: - 弥散光球透明度（深色模式更低，避免太亮）
    private var orbOpacity1: Double { colorScheme == .dark ? 0.25 : 0.4 }
    private var orbOpacity2: Double { colorScheme == .dark ? 0.2 : 0.35 }
    private var orbOpacity3: Double { colorScheme == .dark ? 0.3 : 0.45 }
    private var orbOpacity4: Double { colorScheme == .dark ? 0.25 : 0.4 }
    private var orbOpacity5: Double { colorScheme == .dark ? 0.2 : 0.5 }
    private var orbOpacity6: Double { colorScheme == .dark ? 0.15 : 0.3 }
    private var orbOpacity7: Double { colorScheme == .dark ? 0.2 : 0.35 }
}

// MARK: - 快捷调用扩展
extension View {
    /// 一键应用奶脂弥散背景
    func useMilkyDiffuseBackground() -> some View {
        self.background(MilkyDiffuseBackground())
    }
}
