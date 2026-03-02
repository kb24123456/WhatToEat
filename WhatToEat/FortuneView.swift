import SwiftUI
import SwiftData

// MARK: - 食签动画常量
enum FortuneAnimationConstants {
    static let springResponse: Double = 0.5
    static let springDamping: Double = 0.75
    static let cardWidth: CGFloat = 340
    static let cardHeight: CGFloat = 520
    static let staggerDelay: Double = 0.08
}

// MARK: - 食签视图模型
@MainActor
@Observable
class FortuneViewModel {
    var isFortuneExpanded: Bool = false
    var isAnimating: Bool = false
    var cardOffset: CGFloat = UIScreen.main.bounds.height
    var heroOpacity: Double = 0
    var contentReady: Bool = false
    var dragOffset: CGFloat = 0
    var isDragging: Bool = false
    
    nonisolated func openFortune() {
        Task { @MainActor in
            guard !isAnimating else { return }
            isAnimating = true
            contentReady = false
            
            cardOffset = UIScreen.main.bounds.height
            heroOpacity = 0.0
            dragOffset = 0
            
            isFortuneExpanded = true
            
            // 使用 asyncAfter 替代 DispatchQueue
            try? await Task.sleep(nanoseconds: 400_000_000)
            contentReady = true
            
            try? await Task.sleep(nanoseconds: 800_000_000)
            isAnimating = false
        }
    }
    
    nonisolated func closeFortune() {
        Task { @MainActor in
            guard !isAnimating else { return }
            isAnimating = true
            contentReady = false
            
            withAnimation(.easeIn(duration: 0.25)) {
                cardOffset = -UIScreen.main.bounds.height
                heroOpacity = 0.0
            }
            
            try? await Task.sleep(nanoseconds: 250_000_000)
            isFortuneExpanded = false
            cardOffset = UIScreen.main.bounds.height
            dragOffset = 0
            isAnimating = false
        }
    }
    
    // iOS App Switcher 风格的上滑关闭手势（优化版，保证120Hz）
    func handleDragChange(_ translation: CGFloat) {
        // 向上滑动时（translation.height < 0），卡片向上移动
        // 使用阻尼系数让移动更自然，同时限制更新频率
        let damping: CGFloat = 0.75
        let newOffset = translation * damping
        
        // 只在变化足够大时更新，减少重绘次数
        if abs(newOffset - dragOffset) > 1.0 {
            dragOffset = newOffset
        }
    }
    
    nonisolated func handleDragEnd(_ translation: CGFloat, _ velocity: CGFloat) {
        Task { @MainActor in
            let screenHeight = UIScreen.main.bounds.height
            let threshold = screenHeight * 0.20 // 20% 屏幕高度阈值（更容易触发）
            
            // 向上滑动超过阈值，或速度足够快，触发关闭
            if translation < -threshold || velocity < -600 {
                // 自动完成关闭动画（使用更流畅的曲线）
                withAnimation(.easeOut(duration: 0.2)) {
                    dragOffset = -screenHeight
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
                await closeFortune()
            } else {
                // 回弹到原位（快速回弹，减少等待）
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    dragOffset = 0
                }
            }
        }
    }
    
    func reset() {
        isFortuneExpanded = false
        isAnimating = false
        contentReady = false
        cardOffset = UIScreen.main.bounds.height
        heroOpacity = 0.0
        dragOffset = 0
    }
}

// MARK: - 食签主视图
struct FortuneView: View {
    @State private var viewModel = FortuneViewModel()
    @StateObject private var aiManager = AICopywritingManager.shared
    
    var body: some View {
        ZStack {
            if viewModel.isFortuneExpanded {
                fortuneInteractionSystem
            } else {
                fortunePendantButton
            }
        }
        // 视图首次出现时获取今日食签
        .task {
            await loadTodayFortuneIfNeeded()
        }
    }
    
    // 加载今日食签（如果需要）
    private func loadTodayFortuneIfNeeded() async {
        // 如果已经有今日食签且不是新的一天，不需要重新获取
        if let fortune = aiManager.todayFortune {
            let calendar = Calendar.current
            if calendar.isDateInToday(fortune.date) {
                print("✅ 今日食签已存在且有效，无需重新获取")
                return
            }
        }
        
        // 获取今日食签（会自动处理缓存逻辑）
        print("🔄 开始获取今日食签...")
        _ = await aiManager.getTodayFortune()
    }
    
    // MARK: - 食签交互系统
    private var fortuneInteractionSystem: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.closeFortune()
                }
            
            if viewModel.isFortuneExpanded {
                expandedFortuneCard
                    .offset(y: viewModel.cardOffset + viewModel.dragOffset)
                    .opacity(viewModel.heroOpacity)
                    // iOS App Switcher 风格上滑关闭手势（120Hz优化）
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .onChanged { value in
                                viewModel.isDragging = true
                                // 直接更新偏移量，减少计算开销
                                viewModel.dragOffset = value.translation.height * 0.75
                            }
                            .onEnded { value in
                                viewModel.isDragging = false
                                viewModel.handleDragEnd(value.translation.height, value.velocity.height)
                            }
                    )
                    .onAppear {
                        withAnimation(.spring(
                            response: FortuneAnimationConstants.springResponse,
                            dampingFraction: FortuneAnimationConstants.springDamping
                        )) {
                            viewModel.cardOffset = 0
                            viewModel.heroOpacity = 1.0
                        }
                    }
            }
        }
    }
    
    // MARK: - 食签按钮（收起状态）
    private var fortunePendantButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                .fill(AppTheme.Card.background)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                        .stroke(AppTheme.Card.strokeColor, lineWidth: AppTheme.Card.strokeWidth)
                )
                .frame(width: 120, height: 120)
            
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.babyBlue)
                
                Text("今日食签")
                    .font(AppTheme.Fonts.title3Yuanti)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            if aiManager.todayFortune != nil {
                Circle()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: 10, height: 10)
                    .offset(x: 42, y: -42)
            }
        }
        .onTapGesture {
            viewModel.openFortune()
        }
    }
    
    // MARK: - 展开的食签卡片
    private var expandedFortuneCard: some View {
        Group {
            if let fortune = aiManager.todayFortune {
                FortuneCardContent(
                    fortune: fortune,
                    contentReady: viewModel.contentReady,
                    onClose: { viewModel.closeFortune() }
                )
            } else {
                LoadingFortuneView()
            }
        }
    }
}

// MARK: - 食签卡片内容（美化版）
struct FortuneCardContent: View {
    let fortune: DailyFoodFortune
    let contentReady: Bool
    let onClose: () -> Void
    @State private var animatedStars: Int = 0
    @State private var starScales: [CGFloat] = [0, 0, 0, 0, 0]
    @State private var foodGlowOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏（带关闭按钮）
            headerView
            
            // 运势星级
            enhancedFortuneMetrics
                .padding(.bottom, 20)
            
            // 运势解析
            analysisView
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            
            // 宜忌区域
            yiJiSection
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
            // 开运食物
            enhancedLuckyFoodView
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .frame(width: 320)
        .background(
            ZStack {
                // 主背景 - 冷白色
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                
                // 顶部微光效果
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                Color.white.opacity(0.4),
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
                                Color.white.opacity(0.8),
                                Color(hex: "#FFE4D6").opacity(0.3),
                                Color.white.opacity(0.6)
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
        .onChange(of: contentReady) { _, newValue in
            if newValue {
                animateStars()
                animateFoodGlow()
            }
        }
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
        .opacity(contentReady ? 1 : 0)
        .offset(y: contentReady ? 0 : 20)
    }
    
    // MARK: - 增强版运势星级
    private var enhancedFortuneMetrics: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                EnhancedStarView(
                    isFilled: index < fortune.fortuneStars,
                    isAnimated: index < animatedStars,
                    scale: starScales[index]
                )
            }
        }
    }
    
    private func animateStars() {
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1 + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    starScales[i] = 1.0
                    if i < fortune.fortuneStars {
                        animatedStars = i + 1
                    }
                }
            }
        }
    }
    
    // MARK: - 运势解析
    private var analysisView: some View {
        Text(fortune.analysis)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .lineLimit(3)
            .foregroundColor(Color(hex: "#2D3436"))
            .opacity(contentReady ? 1 : 0)
            .offset(y: contentReady ? 0 : 15)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: contentReady)
    }
    
    // MARK: - 宜忌区域
    private var yiJiSection: some View {
        VStack(spacing: 12) {
            EnhancedYiJiRowProfile(
                type: .yi,
                highlight: fortune.yiHighlight,
                detail: fortune.yiSub,
                contentReady: contentReady,
                delay: 0.3
            )
            
            Rectangle()
                .fill(Color(hex: "#FFE4D6").opacity(0.5))
                .frame(height: 0.5)
                .padding(.horizontal, 8)
            
            EnhancedYiJiRowProfile(
                type: .ji,
                highlight: fortune.jiHighlight,
                detail: fortune.jiSub,
                contentReady: contentReady,
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
        .opacity(contentReady ? 1 : 0)
        .offset(y: contentReady ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.25), value: contentReady)
    }
    
    // MARK: - 增强版开运食物
    private var enhancedLuckyFoodView: some View {
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
                    .opacity(foodGlowOpacity)
                
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
                
                Text(fortune.luckFood)
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
        .opacity(contentReady ? 1 : 0)
        .offset(y: contentReady ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: contentReady)
    }
    
    private func animateFoodGlow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                foodGlowOpacity = 1
            }
        }
    }
}

// MARK: - 标题
struct TitleView: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.Colors.babyBlue, AppTheme.Colors.babyBlue.opacity(0)],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                )
                .frame(width: 50, height: 2)
            
            Text("今日食签")
                .font(AppTheme.Fonts.titleYuanti)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.Colors.accent, AppTheme.Colors.accent.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 50, height: 2)
        }
    }
}

// MARK: - 运势星级
struct FortuneMetrics: View {
    let stars: Int
    @State private var animatedStars: Int = 0
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < animatedStars ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        index < animatedStars
                        ? LinearGradient(
                            colors: [AppTheme.Colors.accent, AppTheme.Colors.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [AppTheme.Colors.textTertiary, AppTheme.Colors.textTertiary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(index < animatedStars ? 1.0 : 0.8)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6)
                        .delay(Double(index) * 0.05),
                        value: animatedStars
                    )
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                animatedStars = stars
            }
        }
    }
}

// MARK: - 分隔线
struct DividerLine: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppTheme.Colors.divider)
                .frame(height: 1)
            
            Circle()
                .fill(AppTheme.Colors.babyBlue.opacity(0.5))
                .frame(width: 4, height: 4)
            
            Rectangle()
                .fill(AppTheme.Colors.divider)
                .frame(height: 1)
        }
    }
}

// MARK: - 宜/忌类型
enum YiJiType {
    case yi, ji
    
    var title: String { self == .yi ? "宜" : "忌" }
    var icon: String { self == .yi ? "checkmark" : "xmark" }
    var color: Color { self == .yi ? AppTheme.Colors.accent : AppTheme.Colors.textPrimary }
}

// MARK: - 宜/忌行
struct YiJiRow: View {
    let type: YiJiType
    let highlight: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(type.color)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(type.title)
                        .font(AppTheme.Fonts.subheadlineYuanti)
                        .foregroundStyle(type.color)
                    
                    Text(highlight)
                        .font(AppTheme.Fonts.subheadlineYuanti)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                
                Text(detail)
                    .font(AppTheme.Fonts.footnoteYuanti)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - 幸运食物视图
struct LuckyFoodView: View {
    let food: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.pink, Color.orange, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("开运食物")
                    .font(AppTheme.Fonts.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Text(food)
                    .font(AppTheme.Fonts.title3Yuanti)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        MeshGradient(
                            width: 3,
                            height: 3,
                            points: [
                                .init(x: 0, y: 0), .init(x: 0.5, y: 0), .init(x: 1, y: 0),
                                .init(x: 0, y: 0.5), .init(x: 0.5, y: 0.5), .init(x: 1, y: 0.5),
                                .init(x: 0, y: 1), .init(x: 0.5, y: 1), .init(x: 1, y: 1)
                            ],
                            colors: [
                                Color.pink.opacity(0.08),
                                Color.pink.opacity(0.15),
                                Color.orange.opacity(0.06),
                                Color.orange.opacity(0.10),
                                Color.yellow.opacity(0.05),
                                Color.purple.opacity(0.08),
                                Color.pink.opacity(0.06),
                                Color.pink.opacity(0.12),
                                Color.orange.opacity(0.08)
                            ]
                        )
                    )
                
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                Color.white.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 40)
                    .offset(y: -20)
                
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 30)
                    .offset(y: 25)
            }
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 12,
                x: 0,
                y: 6
            )
        )
        .drawingGroup()
    }
}

// MARK: - 加载中视图
struct LoadingFortuneView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(AppTheme.Colors.babyBlue.opacity(0.3), lineWidth: 1)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .fill(AppTheme.Colors.babyBlue)
                    .frame(width: 5, height: 5)
                    .offset(x: 40)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 3).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                Circle()
                    .fill(AppTheme.Colors.accent.opacity(0.2))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.accent, lineWidth: 1.5)
                    )
            }
            .frame(width: 100, height: 100)
            
            Text("正在翻阅今日黄历...")
                .font(AppTheme.Fonts.bodyYuanti)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(width: FortuneAnimationConstants.cardWidth, height: FortuneAnimationConstants.cardHeight)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                .fill(AppTheme.Card.background)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Card.cornerRadius, style: .continuous)
                        .stroke(AppTheme.Card.strokeColor, lineWidth: AppTheme.Card.strokeWidth)
                )
        )
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// MARK: - 增强版星星视图
struct EnhancedStarView: View {
    let isFilled: Bool
    let isAnimated: Bool
    let scale: CGFloat
    
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
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 4, height: 4)
                        .offset(x: -6, y: -6)
                        .blur(radius: 1)
                }
            }
    }
}

// MARK: - 增强版宜忌行（Profile版）
struct EnhancedYiJiRowProfile: View {
    let type: YiJiType
    let highlight: String
    let detail: String
    let contentReady: Bool
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
        .onChange(of: contentReady) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        show = true
                    }
                }
            }
        }
    }
}

// MARK: - 预览
#Preview {
    FortuneView()
}
