import SwiftUI
import SwiftData

// MARK: - 食签步骤
enum FortuneStep: Int, CaseIterable {
    case fortuneStars = 0
    case analysis = 1
    case yiJi = 2
    case luckyFood = 3
}

// MARK: - 沉浸式食签视图
struct ImmersiveFortuneView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiManager = AICopywritingManager.shared
    
    // 当前步骤
    @State private var currentStep: FortuneStep = .fortuneStars
    
    // 动画状态
    @State private var titleOffset: CGFloat = -100
    @State private var titleOpacity: Double = 0
    @State private var contentOffset: CGFloat = 100
    @State private var contentOpacity: Double = 0
    @State private var isTransitioning: Bool = false
    
    // 星星动画
    @State private var animatedStars: Int = 0
    
    var body: some View {
        ZStack {
            // 背景层
            Color.clear
                .ignoresSafeArea()
            
            // 内容层
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 100)
                
                // 标题区域
                titleView
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
                
                Spacer()
                    .frame(height: 40)
                
                // 内容区域
                contentView
                    .offset(y: contentOffset)
                    .opacity(contentOpacity)
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            animateIn()
            // 延迟开始星星动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let fortune = aiManager.todayFortune {
                    animateStars(to: fortune.fortuneStars)
                }
            }
        }
    }
    
    // MARK: - 标题视图
    private var titleView: some View {
        Group {
            switch currentStep {
            case .fortuneStars:
                Text("今日食运")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
            case .analysis:
                Text("运势解读")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
            case .yiJi:
                Text("今日宜忌")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
            case .luckyFood:
                Text("开运食物")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
            }
        }
    }
    
    // MARK: - 内容视图
    @ViewBuilder
    private var contentView: some View {
        if let fortune = aiManager.todayFortune {
            switch currentStep {
            case .fortuneStars:
                fortuneStarsView(fortune: fortune)
            case .analysis:
                analysisView(fortune: fortune)
            case .yiJi:
                yiJiView(fortune: fortune)
            case .luckyFood:
                luckyFoodView(fortune: fortune)
            }
        } else {
            loadingView
        }
    }
    
    // MARK: - 运势星级视图
    private func fortuneStarsView(fortune: DailyFoodFortune) -> some View {
        VStack(spacing: 30) {
            // 星级显示
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < animatedStars ? "star.fill" : "star")
                        .font(.system(size: 36, weight: .semibold))
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
                            .delay(Double(index) * 0.1),
                            value: animatedStars
                        )
                }
            }
            
            // 运势等级文字
            Text(starsDescription(animatedStars))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            // 下一步按钮
            ImmersiveNextButton(title: "查看解读") {
                goToNextStep()
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - 运势解读视图
    private func analysisView(fortune: DailyFoodFortune) -> some View {
        VStack(spacing: 24) {
            Text(fortune.analysis)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 8)
            
            // 下一步按钮
            ImmersiveNextButton(title: "查看宜忌") {
                goToNextStep()
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - 宜忌视图
    private func yiJiView(fortune: DailyFoodFortune) -> some View {
        VStack(spacing: 20) {
            // 宜
            ImmersiveYiJiCard(
                type: YiJiType.yi,
                highlight: fortune.yiHighlight,
                detail: fortune.yiSub
            )
            
            // 忌
            ImmersiveYiJiCard(
                type: YiJiType.ji,
                highlight: fortune.jiHighlight,
                detail: fortune.jiSub
            )
            
            // 下一步按钮
            ImmersiveNextButton(title: "查看开运食物") {
                goToNextStep()
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - 开运食物视图
    private func luckyFoodView(fortune: DailyFoodFortune) -> some View {
        VStack(spacing: 30) {
            // 食物图标
            ZStack {
                Circle()
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
                                Color.pink.opacity(0.2),
                                Color.orange.opacity(0.15),
                                Color.purple.opacity(0.1),
                                Color.orange.opacity(0.15),
                                Color.yellow.opacity(0.1),
                                Color.pink.opacity(0.15),
                                Color.purple.opacity(0.1),
                                Color.pink.opacity(0.15),
                                Color.orange.opacity(0.1)
                            ]
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.pink, Color.orange, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            // 食物名称
            Text(fortune.luckFood)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            Text("今日开运食物")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            // 完成按钮
            ImmersiveActionButton(title: "去吃点好的") {
                dismiss()
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .fill(AppTheme.Colors.babyBlue)
                    .frame(width: 5, height: 5)
                    .offset(x: 40)
                    .rotationEffect(.degrees(isTransitioning ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 3).repeatForever(autoreverses: false),
                        value: isTransitioning
                    )
            }
            .frame(width: 100, height: 100)
            
            Text("正在翻阅今日黄历...")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .onAppear {
            isTransitioning = true
        }
    }
    
    // MARK: - 星级描述
    private func starsDescription(_ stars: Int) -> String {
        switch stars {
        case 5: return "大吉"
        case 4: return "吉"
        case 3: return "平"
        case 2: return "凶"
        case 1: return "大凶"
        default: return "未知"
        }
    }
    
    // MARK: - 星星动画
    private func animateStars(to targetStars: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                animatedStars = targetStars
            }
        }
    }
    
    // MARK: - 动画进入
    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            titleOffset = 0
            titleOpacity = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                contentOffset = 0
                contentOpacity = 1
            }
        }
    }
    
    // MARK: - 步骤切换动画
    private func transitionToNextStep() {
        guard !isTransitioning else { return }
        isTransitioning = true
        
        // 当前内容消失
        withAnimation(.easeOut(duration: 0.2)) {
            titleOffset = -40
            titleOpacity = 0
            contentOffset = 40
            contentOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // 更新步骤
            if let nextStep = FortuneStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
            }
            
            // 重置动画状态
            titleOffset = -80
            contentOffset = 80
            
            // 新内容弹入
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                titleOffset = 0
                titleOpacity = 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    contentOffset = 0
                    contentOpacity = 1
                }
                isTransitioning = false
            }
        }
    }
    
    // MARK: - 进入下一步
    private func goToNextStep() {
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        transitionToNextStep()
    }
}

// MARK: - 沉浸式宜忌卡片
struct ImmersiveYiJiCard: View {
    let type: YiJiType
    let highlight: String
    let detail: String
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: type.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(type.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(type.color)
                    
                    Text(highlight)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
                
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#FFFFFF").opacity(0.9))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                .shadow(color: Color(hex: "#FFFFFF").opacity(0.8), radius: 2, x: 0, y: -1)
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    return ImmersiveFortuneView()
        .modelContainer(container)
}
