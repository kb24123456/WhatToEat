import SwiftUI

/// 流体黑色弥散背景组件 - 使用 MeshGradient 实现真正的无级顺滑渐变
/// iOS 18+ 原生支持，基于贝塞尔曲面插值
struct LiquidDarkHeaderBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let height: CGFloat = 320
            
            ZStack(alignment: .top) {
                // MARK: - MeshGradient 无级渐变层
                // 使用 3x4 网格实现从上到下的顺滑过渡
                MeshGradient(
                    width: 3,
                    height: 4,
                    points: [
                        // 第1行（顶部）：纯黑区域
                        .init(x: 0, y: 0),     .init(x: 0.5, y: 0),     .init(x: 1, y: 0),
                        // 第2行：纯黑保持区
                        .init(x: 0, y: 0.35),  .init(x: 0.5, y: 0.35),  .init(x: 1, y: 0.35),
                        // 第3行：开始衰减区
                        .init(x: 0, y: 0.65),  .init(x: 0.5, y: 0.65),  .init(x: 1, y: 0.65),
                        // 第4行（底部）：完全透明
                        .init(x: 0, y: 1),     .init(x: 0.5, y: 1),     .init(x: 1, y: 1),
                    ],
                    colors: [
                        // 第1行：顶部重色
                        AppTheme.Colors.topOverlayStrong, AppTheme.Colors.topOverlayStrong, AppTheme.Colors.topOverlayStrong,
                        // 第2行：保持过渡
                        AppTheme.Colors.topOverlayMid, AppTheme.Colors.topOverlayMid, AppTheme.Colors.topOverlayMid,
                        // 第3行：指数衰减到半透明
                        AppTheme.Colors.topOverlaySoft.opacity(colorScheme == .dark ? 0.72 : 0.16),
                        AppTheme.Colors.topOverlaySoft.opacity(colorScheme == .dark ? 0.56 : 0.12),
                        AppTheme.Colors.topOverlaySoft.opacity(colorScheme == .dark ? 0.72 : 0.16),
                        // 第4行：完全透明
                        Color.clear, Color.clear, Color.clear,
                    ]
                )
                .frame(height: height)
            }
            .frame(height: height)
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - 预览
#Preview {
    ZStack {
        // 奶白底色
        Color(hex: "#fdf9f3")
            .ignoresSafeArea()
        
        // MeshGradient 流体黑色背景
        LiquidDarkHeaderBackground()
        
        // 示例内容
        VStack {
            HStack(spacing: 2) {
                Text("What")
                    .foregroundColor(Color.white.opacity(0.6))
                Text("ToEat")
                    .foregroundColor(.white)
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(y: 8)
            }
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .padding(.top, 60)
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.Colors.babyBlue)
                Text("搜索餐厅...")
                    .foregroundColor(Color.white.opacity(0.5))
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#FFFFFF").opacity(0.15))
                    .background(.ultraThinMaterial)
            )
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            // 筛选栏
            HStack(spacing: 12) {
                Text("地区")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "#FFFFFF")))
                
                Text("品类")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "#FFFFFF").opacity(0.3)))
                
                Text("排序")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "#FFFFFF").opacity(0.3)))
            }
            .padding(.top, 80)
            
            Spacer()
        }
    }
}
