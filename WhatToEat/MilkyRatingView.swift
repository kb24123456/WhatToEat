import SwiftUI

// MARK: - MilkyRatingView
// 奶脂风格流体进度条评分组件 - 小红书红版本
struct MilkyRatingView: View {
    @Binding var rating: Double
    
    // 动画状态
    @State private var isDragging: Bool = false
    @State private var dragLocation: CGFloat = 0
    @State private var lastHapticRating: Int = 0
    @State private var displayedRating: Int = 0  // 用于数字动画
    
    // 情感化标签
    private let ratingLabels = [
        1: "踩雷 💣",
        2: "一般般 😐",
        3: "值得一试 ✨",
        4: "非常推荐 👍",
        5: "人生必吃 🏆"
    ]
    
    private let hapticGenerator = UISelectionFeedbackGenerator()
    
    // 使用 AppTheme accent 颜色（与智能搜索框边框一致）
    private var accentColor: Color { AppTheme.Colors.accent }
    private var accentColorDark: Color { AppTheme.Colors.accent.opacity(0.85) }
    
    var body: some View {
        VStack(spacing: 12) {
            // 流体进度条
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let progress = min(max(rating / 5.0, 0), 1.0)
                let fillWidth = totalWidth * progress
                
                ZStack(alignment: .leading) {
                    // 底座背景 - 带内阴影
                    Capsule()
                        .fill(AppTheme.Colors.softBackground)
                        .overlay(
                            // 内阴影效果
                            Capsule()
                                .stroke(Color.black.opacity(0.03), lineWidth: 1)
                                .overlay(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.black.opacity(0.02),
                                                    Color.clear
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                        )
                        .overlay(
                            // 白色高光描边
                            Capsule()
                                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                        )
                    
                    // 填充层 - 使用 AppTheme accent 颜色（与智能搜索框边框一致）
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColorDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                        .animation(.easeInOut(duration: 0.1), value: rating)
                    
                    // 分数分割线 - 动态显示/隐藏
                    HStack(spacing: 0) {
                        ForEach(1..<5) { index in
                            let segmentPosition = CGFloat(index) * (totalWidth / 5)
                            let isFilled = fillWidth >= segmentPosition
                            
                            Rectangle()
                                .fill(Color.white.opacity(isFilled ? 0 : 0.4))
                                .frame(width: 1.5)
                                .frame(maxHeight: .infinity)
                                .animation(.easeInOut(duration: 0.1), value: isFilled)
                            
                            if index < 4 {
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, totalWidth / 5)
                }
                .frame(height: 32)  // 提升高度
                .scaleEffect(isDragging ? 1.02 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let location = value.location.x
                            let newRating = min(max(location / totalWidth * 5.0, 0), 5.0)
                            
                            // 实时更新评分
                            rating = newRating
                            
                            // 整数吸附触感反馈
                            let currentIntRating = Int(newRating)
                            if currentIntRating != lastHapticRating && currentIntRating >= 1 && currentIntRating <= 5 {
                                hapticGenerator.selectionChanged()
                                lastHapticRating = currentIntRating
                                // 更新显示的数字
                                withAnimation(AppTheme.Animations.standardSpring) {
                                    displayedRating = currentIntRating
                                }
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            // 吸附到最近的 0.5
                            let snappedRating = round(rating * 2) / 2
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                rating = snappedRating
                            }
                        }
                )
                .onTapGesture { location in
                    let newRating = min(max(location.x / totalWidth * 5.0, 0), 5.0)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        rating = newRating
                    }
                    
                    // 触感反馈
                    let currentIntRating = Int(newRating)
                    if currentIntRating >= 1 && currentIntRating <= 5 {
                        hapticGenerator.selectionChanged()
                        lastHapticRating = currentIntRating
                        withAnimation(AppTheme.Animations.standardSpring) {
                            displayedRating = currentIntRating
                        }
                    }
                }
            }
            .frame(height: 32)  // 提升高度
            
            // 数字分数 + 情感化标签
            ratingLabelView
        }
        .onAppear {
            hapticGenerator.prepare()
            lastHapticRating = Int(rating)
            displayedRating = Int(rating)
        }
        .onChange(of: rating) { _, newValue in
            let newIntRating = Int(newValue)
            if newIntRating != displayedRating && newIntRating >= 1 && newIntRating <= 5 {
                withAnimation(AppTheme.Animations.standardSpring) {
                    displayedRating = newIntRating
                }
            }
        }
    }
    
    // 评分标签视图 - 数字 + 文本
    @ViewBuilder
    private var ratingLabelView: some View {
        let currentRating = Int(rating)
        
        if currentRating >= 1 && currentRating <= 5 {
            HStack(spacing: 8) {
                // 数字分数 - 与人均消费样式一致
                HStack(spacing: 2) {
                    Text("\(displayedRating)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .contentTransition(.numericText())
                    
                    Text("分")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
                
                Text("·")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.lighterGray)
                
                // 情感化标签 - 使用与数字相同的动效
                Text(ratingLabels[currentRating] ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                    .contentTransition(.numericText())
            }
            .animation(AppTheme.Animations.standardSpring, value: currentRating)
        } else {
            Text("滑动或点击评分")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.lighterGray)
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var rating: Double = 0
        
        var body: some View {
            VStack(spacing: 40) {
                MilkyRatingView(rating: $rating)
                    .padding(.horizontal, 40)
                
                Text("当前评分: \(String(format: "%.1f", rating))")
                    .font(.headline)
                
                // 测试按钮
                HStack(spacing: 20) {
                    Button("1分") { withAnimation { rating = 1 } }
                    Button("3分") { withAnimation { rating = 3 } }
                    Button("5分") { withAnimation { rating = 5 } }
                }
            }
            .padding()
            .background(AppTheme.Colors.warmGray)
        }
    }
    
    return PreviewWrapper()
}
