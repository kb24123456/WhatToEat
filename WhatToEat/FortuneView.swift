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

// MARK: - 食签卡片内容
struct FortuneCardContent: View {
    let fortune: DailyFoodFortune
    let contentReady: Bool
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TitleView()
                .padding(.top, 24)
                .padding(.bottom, 16)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: contentReady)
            
            FortuneMetrics(stars: fortune.fortuneStars)
                .padding(.bottom, 16)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(FortuneAnimationConstants.staggerDelay * 2), value: contentReady)
            
            Text(fortune.analysis)
                .font(AppTheme.Fonts.bodyYuanti)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .lineLimit(3)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(FortuneAnimationConstants.staggerDelay * 3), value: contentReady)
            
            DividerLine()
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(FortuneAnimationConstants.staggerDelay * 4), value: contentReady)
            
            YiJiRow(type: .yi, highlight: fortune.yiHighlight, detail: fortune.yiSub)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(FortuneAnimationConstants.staggerDelay * 5), value: contentReady)
            
            YiJiRow(type: .ji, highlight: fortune.jiHighlight, detail: fortune.jiSub)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(FortuneAnimationConstants.staggerDelay * 6), value: contentReady)
            
            DividerLine()
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(FortuneAnimationConstants.staggerDelay * 7), value: contentReady)
            
            LuckyFoodView(food: fortune.luckFood)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(FortuneAnimationConstants.staggerDelay * 8), value: contentReady)
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
        .compositingGroup()
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

// MARK: - 预览
#Preview {
    FortuneView()
}
