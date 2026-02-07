import SwiftUI

/// 奶脂风格色彩弥散背景 - 完美还原 bg_cow_pattern 色彩布局
/// 通过适度虚化展现高级感，保留原图视觉比例
struct MilkyDiffuseBackground: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - 1. 底层底色：白色（仅用于图片边缘溢出时保持干净）
                Color.white
                    .ignoresSafeArea()

                // MARK: - 2. 主体材质：完美还原奶牛纹理
                Image("bg_cow_pattern")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    // MARK: - 4. 极简动态呼吸：小范围位移和缩放
                    .offset(x: animate ? 10 : -10, y: animate ? -10 : 10)
                    .scaleEffect(animate ? 1.05 : 1.0)
                    // MARK: - 2. 精准高斯模糊：黄金区间 40-50pt
                    .blur(radius: 45)
                    // MARK: - 3. 画面后期校色
                    .contrast(1.1)      // 对比度强化，防止灰暗感
                    .saturation(1.0)    // 保持原色，保留粉色和黑色
                    // MARK: - 1. 还原原始构图：提升透明度至 0.6
                    .opacity(0.6)

                // 注意：已移除中心遮罩，保留满版奶牛纹理感
            }
            // MARK: - 性能保障：硬件加速
            .drawingGroup()
        }
        .ignoresSafeArea()
        .onAppear {
            // 极简动态呼吸：缓慢循环
            withAnimation(
                .easeInOut(duration: 20)
                .repeatForever(autoreverses: true)
            ) {
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

// MARK: - 预览
#Preview {
    ZStack {
        MilkyDiffuseBackground()

        Text("奶牛纹理")
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(Color(hex: "#3D3D3D"))
    }
}
