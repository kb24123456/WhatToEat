import SwiftUI
import SwiftData

// MARK: - 食签卡片模态视图（深度美化版）
struct FortuneCardModalView: View {
    @StateObject private var aiManager = AICopywritingManager.shared
    let onClose: () -> Void
    
    // 动画状态
    @State private var showContent: Bool = false
    @State private var starScale: CGFloat = 0.5
    @State private var starRotation: Double = -180
    
    var body: some View {
        ZStack {
            // 背景渐变层
            fortuneGradientBackground
            
            if let fortune = aiManager.todayFortune {
                // 有食签数据，显示卡片内容
                fortuneCardContent(fortune: fortune)
            } else {
                // 无食签数据，显示加载中
                EnhancedLoadingView()
            }
        }
        .onAppear {
            triggerEntranceAnimation()
            
            // 确保食签已加载
            Task {
                await loadFortuneIfNeeded()
            }
        }
    }
    
    // MARK: - 背景渐变
    private var fortuneGradientBackground: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(x: 0, y: 0), .init(x: 0.5, y: 0), .init(x: 1, y: 0),
                .init(x: 0, y: 0.5), .init(x: 0.5, y: 0.5), .init(x: 1, y: 0.5),
                .init(x: 0, y: 1), .init(x: 0.5, y: 1), .init(x: 1, y: 1)
            ],
            colors: [
                Color(hex: "#FFF5F0"),
                Color(hex: "#FFEEE5"),
                Color(hex: "#FFF8F5"),
                Color(hex: "#FFE8E0"),
                Color(hex: "#FFF0EB"),
                Color(hex: "#FFF5F2"),
                Color(hex: "#FFEFE8"),
                Color(hex: "#FFF2EE"),
                Color(hex: "#FFF7F5")
            ]
        )
        .opacity(0.6)
        .ignoresSafeArea()
    }
    
    // MARK: - 食签卡片内容
    private func fortuneCardContent(fortune: DailyFoodFortune) -> some View {
        VStack(spacing: 0) {
            // 标题栏（带关闭按钮）
            headerView
            
            // 运势星级
            EnhancedFortuneMetrics(stars: fortune.fortuneStars, showContent: showContent)
                .padding(.bottom, 20)
            
            // 运势解析
            analysisView(text: fortune.analysis)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            
            // 宜忌区域
            yiJiSection(yiHighlight: fortune.yiHighlight, yiSub: fortune.yiSub,
                       jiHighlight: fortune.jiHighlight, jiSub: fortune.jiSub)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
            // 开运食物
            EnhancedLuckyFoodView(food: fortune.luckFood, showContent: showContent)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .frame(width: 320)
        .background(
            ZStack {
                // 主背景 - 冷白色
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: "#FFFFFF"))
                
                // 顶部微光效果
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFFFFF").opacity(0.9),
                                Color(hex: "#FFFFFF").opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 120)
                    .offset(y: -100)
                
                // 边框
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFFFFF").opacity(0.8),
                                Color(hex: "#FFE4D6").opacity(0.3),
                                Color(hex: "#FFFFFF").opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(
            color: Color(hex: "#FF6B6B").opacity(0.08),
            radius: 40,
            x: 0,
            y: 20
        )
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 60,
            x: 0,
            y: 30
        )
        .scaleEffect(showContent ? 1 : 0.9)
        .opacity(showContent ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showContent)
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            Spacer()
            
            Text("今日食签")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#2D3436"), Color(hex: "#636E72")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#B2BEC3"), Color(hex: "#DFE6E9")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.trailing, 16)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - 运势解析
    private func analysisView(text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .lineLimit(3)
            .foregroundColor(Color(hex: "#2D3436"))
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 15)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showContent)
    }
    
    // MARK: - 宜忌区域
    private func yiJiSection(yiHighlight: String, yiSub: String,
                            jiHighlight: String, jiSub: String) -> some View {
        VStack(spacing: 12) {
            // 宜
            EnhancedYiJiRow(
                type: .yi,
                highlight: yiHighlight,
                detail: yiSub,
                delay: 0.3
            )
            
            // 分隔线
            Rectangle()
                .fill(Color(hex: "#FFE4D6").opacity(0.5))
                .frame(height: 0.5)
                .padding(.horizontal, 8)
            
            // 忌
            EnhancedYiJiRow(
                type: .ji,
                highlight: jiHighlight,
                detail: jiSub,
                delay: 0.4
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#FFF9F7"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "#FFE4D6").opacity(0.5), lineWidth: 1)
                )
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.25), value: showContent)
    }
    
    // MARK: - 触发动画
    private func triggerEntranceAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
    
    // MARK: - 加载食签（如果需要）
    private func loadFortuneIfNeeded() async {
        if let fortune = aiManager.todayFortune {
            let calendar = Calendar.current
            if calendar.isDateInToday(fortune.date) {
                return
            }
        }
        _ = await aiManager.getTodayFortune()
    }
}

// MARK: - 增强版运势星级
struct EnhancedFortuneMetrics: View {
    let stars: Int
    let showContent: Bool
    @State private var animatedStars: Int = 0
    @State private var starScales: [CGFloat] = [0, 0, 0, 0, 0]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                StarView(
                    isFilled: index < stars,
                    isAnimated: index < animatedStars,
                    scale: starScales[index]
                )
            }
        }
        .onChange(of: showContent) { _, newValue in
            if newValue {
                animateStars()
            }
        }
    }
    
    private func animateStars() {
        // 依次点亮星星
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    starScales[i] = 1.0
                    if i < stars {
                        animatedStars = i + 1
                    }
                }
            }
        }
    }
}

// MARK: - 星星视图
struct StarView: View {
    let isFilled: Bool
    let isAnimated: Bool
    let scale: CGFloat
    @State private var rotation: Double = 0
    
    var body: some View {
        Image(systemName: isFilled ? "star.fill" : "star")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(
                isFilled && isAnimated
                ? LinearGradient(
                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E8E")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color(hex: "#DFE6E9"), Color(hex: "#B2BEC3")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(isFilled && !isAnimated ? -180 : 0))
            .overlay {
                if isFilled && isAnimated {
                    // 闪光效果
                    Circle()
                        .fill(Color(hex: "#FFFFFF").opacity(0.8))
                        .frame(width: 4, height: 4)
                        .offset(x: -6, y: -6)
                        .blur(radius: 1)
                }
            }
    }
}

// MARK: - 增强版宜忌行
struct EnhancedYiJiRow: View {
    let type: YiJiType
    let highlight: String
    let detail: String
    let delay: Double
    @State private var show: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(type.backgroundColor)
                    .frame(width: 28, height: 28)
                
                Image(systemName: type.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(type.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(type.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(type.accentColor)
                    
                    Text(highlight)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#2D3436"))
                }
                
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#636E72"))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .opacity(show ? 1 : 0)
        .offset(x: show ? 0 : -20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    show = true
                }
            }
        }
    }
}

// MARK: - 增强版开运食物视图
struct EnhancedLuckyFoodView: View {
    let food: String
    let showContent: Bool
    @State private var show: Bool = false
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // 食物图标
            ZStack {
                // 外发光
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#FFD93D").opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                    .opacity(glowOpacity)
                
                // 图标背景
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFF9E6"),
                                Color(hex: "#FFF0CC")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#FFD93D"), Color(hex: "#FFA502")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FFA502"), Color(hex: "#FF6B6B")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("开运食物")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#B2BEC3"))
                
                Text(food)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#2D3436"))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#FFF9F5"),
                            Color(hex: "#FFF5F0")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#FFE4D6").opacity(0.6),
                                    Color(hex: "#FFD4C4").opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .opacity(show ? 1 : 0)
        .offset(y: show ? 0 : 20)
        .onChange(of: showContent) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        show = true
                    }
                    // 发光动画
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        glowOpacity = 1
                    }
                }
            }
        }
    }
}

// MARK: - 增强版加载视图
struct EnhancedLoadingView: View {
    @State private var isAnimating = false
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 外圈
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#FFE4D6"), Color(hex: "#FFEEE5")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 80, height: 80)
                
                // 旋转的小圆点
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E8E")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 8, height: 8)
                        .offset(y: -35)
                        .rotationEffect(.degrees(rotation + Double(index) * 120))
                }
            }
            .frame(width: 100, height: 100)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            
            Text("正在翻阅今日黄历...")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#636E72"))
        }
        .frame(width: 320, height: 480)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "#FFFFFF"))
                .shadow(
                    color: Color(hex: "#FF6B6B").opacity(0.08),
                    radius: 40,
                    x: 0,
                    y: 20
                )
        )
    }
}

// MARK: - 预览
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    
    ZStack {
        Color(hex: "#FFF5F0")
            .ignoresSafeArea()
        
        FortuneCardModalView(onClose: {})
    }
    .modelContainer(container)
}
