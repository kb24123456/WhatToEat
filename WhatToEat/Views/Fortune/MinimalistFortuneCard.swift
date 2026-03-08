//
//  MinimalistFortuneCard.swift
//  WhatToEat
//
//  极简INS风毛玻璃食签卡片
//  设计理念：静谧的东方美学
//

import SwiftUI
import SwiftData

// MARK: - 极简食签卡片视图
struct MinimalistFortuneCard: View {
    @StateObject private var aiManager = AICopywritingManager.shared
    let onClose: () -> Void
    
    // 动画状态
    @State private var showContent: Bool = false
    @State private var cardScale: CGFloat = 0.95
    @State private var cardOpacity: Double = 0

    private func cardWidth(for availableWidth: CGFloat) -> CGFloat {
        min(340, max(availableWidth - 32, 280))
    }
    
    var body: some View {
        GeometryReader { proxy in
            let currentCardWidth = cardWidth(for: proxy.size.width)

            ZStack {
                minimalistBackground

                if let fortune = aiManager.todayFortune {
                    cardContent(fortune: fortune, cardWidth: currentCardWidth)
                } else {
                    MinimalistLoadingView(cardWidth: currentCardWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            animateEntrance()
            
            // 隐藏底部导航条
            NotificationCenter.default.post(name: .hideTabBar, object: nil)
            
            // 确保食签已加载
            Task {
                await loadFortuneIfNeeded()
            }
        }
        .onDisappear {
            // 恢复底部导航条
            NotificationCenter.default.post(name: .restoreTabBar, object: nil)
        }
    }
    
    // MARK: - 背景 - 中性彩虹色弥散渐变
    private var minimalistBackground: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                // 基础中性背景 - 暖灰白色
                Color(hex: "#F8F7F4")
                    .ignoresSafeArea()
                
                // 弥散光斑1 - 左上：柔和蓝
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#A8D5E5").opacity(0.4),
                                Color(hex: "#A8D5E5").opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .position(x: size.width * 0.15, y: size.height * 0.2)
                    .blur(radius: 80)
                
                // 弥散光斑2 - 右下：柔和橙
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#F4B393").opacity(0.38),
                                Color(hex: "#F4B393").opacity(0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 350
                        )
                    )
                    .frame(width: 700, height: 700)
                    .position(x: size.width * 0.85, y: size.height * 0.8)
                    .blur(radius: 90)
                
                // 弥散光斑3 - 中间偏左：柔和紫
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#C5B9E8").opacity(0.35),
                                Color(hex: "#C5B9E8").opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 280
                        )
                    )
                    .frame(width: 560, height: 560)
                    .position(x: size.width * 0.2, y: size.height * 0.6)
                    .blur(radius: 70)
                
                // 弥散光斑4 - 右上：柔和青绿
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#9ED2C6").opacity(0.35),
                                Color(hex: "#9ED2C6").opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 45,
                            endRadius: 320
                        )
                    )
                    .frame(width: 640, height: 640)
                    .position(x: size.width * 0.8, y: size.height * 0.15)
                    .blur(radius: 75)
                
                // 弥散光斑5 - 底部中央：柔和黄
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#F4E4A6").opacity(0.32),
                                Color(hex: "#F4E4A6").opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .position(x: size.width * 0.5, y: size.height * 0.85)
                    .blur(radius: 80)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - 卡片内容
    private func cardContent(fortune: DailyFoodFortune, cardWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 关闭按钮
            closeButton
            
            // 标题
            titleView
                .padding(.top, 4)
                .padding(.bottom, 16)
            
            // 运势星级
            MinimalistFortuneStars(stars: fortune.fortuneStars, showContent: showContent)
                .padding(.bottom, 16)
            
            // 运势解读
            analysisView(text: fortune.analysis)
                .padding(.horizontal, MinimalistTheme.Spacing.cardPadding)
                .padding(.bottom, 20)
            
            // 分隔线
            Divider()
                .background(MinimalistTheme.Colors.cardBorder)
                .padding(.horizontal, MinimalistTheme.Spacing.cardPadding)
                .padding(.bottom, 16)
            
            // 宜忌区域
            yiJiSection(yiHighlight: fortune.yiHighlight, yiSub: fortune.yiSub,
                       jiHighlight: fortune.jiHighlight, jiSub: fortune.jiSub)
                .padding(.horizontal, MinimalistTheme.Spacing.cardPadding)
                .padding(.bottom, 16)
            
            // 开运食物
            MinimalistLuckyFood(food: fortune.luckFood, showContent: showContent)
                .padding(.horizontal, MinimalistTheme.Spacing.cardPadding)
                .padding(.bottom, 24)
        }
        .frame(width: cardWidth)
        .minimalistCardStyle()
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .animation(MinimalistTheme.Animations.entrance, value: cardScale)
        .animation(MinimalistTheme.Animations.entrance, value: cardOpacity)
    }
    
    // MARK: - 关闭按钮
    private var closeButton: some View {
        HStack {
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(MinimalistTheme.Colors.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color(hex: "#FFFFFF").opacity(0.5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
    }
    
    // MARK: - 标题
    private var titleView: some View {
        Text("今日食签")
            .font(MinimalistTheme.Typography.titleLarge)
            .foregroundColor(MinimalistTheme.Colors.textPrimary)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)
            .animation(MinimalistTheme.Animations.entranceDelayed, value: showContent)
    }
    
    // MARK: - 运势解读
    private func analysisView(text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .foregroundColor(MinimalistTheme.Colors.textSecondary)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 15)
            .animation(MinimalistTheme.Animations.entranceDelayed.delay(0.1), value: showContent)
    }
    
    // MARK: - 宜忌区域
    private func yiJiSection(yiHighlight: String, yiSub: String,
                            jiHighlight: String, jiSub: String) -> some View {
        VStack(spacing: MinimalistTheme.Spacing.medium) {
            // 宜
            MinimalistYiJiRow(
                type: .yi,
                highlight: yiHighlight,
                detail: yiSub,
                delay: 0.3
            )
            
            // 忌
            MinimalistYiJiRow(
                type: .ji,
                highlight: jiHighlight,
                detail: jiSub,
                delay: 0.4
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(MinimalistTheme.Animations.entranceDelayed.delay(0.15), value: showContent)
    }
    
    // MARK: - 入场动画
    private func animateEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(MinimalistTheme.Animations.entrance) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(MinimalistTheme.Animations.entrance) {
                    showContent = true
                }
            }
        }
    }
    
    // MARK: - 加载食签
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

// MARK: - 预览
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    
    ZStack {
        MinimalistTheme.Colors.backgroundStart
            .ignoresSafeArea()
        
        MinimalistFortuneCard(onClose: {})
    }
    .modelContainer(container)
}
