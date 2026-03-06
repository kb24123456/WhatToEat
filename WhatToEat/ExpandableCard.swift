//
//  ExpandableCard.swift
//  WhatToEat
//
//  支持Hero动画展开的卡片容器 - 高级动画系统
//  优化：自适应高度 + 智能内容适配
//

import SwiftUI

// MARK: - Expandable Card
struct ExpandableCard<Preview: View, Detail: View>: View {
    let id: String
    let cardSize: CardSize
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let detail: () -> Detail
    
    @Binding var isExpanded: Bool
    var namespace: Namespace.ID
    var onTap: (() -> Void)?
    
    @State private var pressScale: CGFloat = 1.0
    
    var body: some View {
        preview()
            .frame(maxWidth: .infinity)
            .frame(height: cardSize.fixedHeight)
            .background(
                RoundedRectangle(cornerRadius: isExpanded ? 26 : 20, style: .continuous)
                    .fill(Color(hex: "#FFFFFF"))
                    .overlay(
                        RoundedRectangle(cornerRadius: isExpanded ? 26 : 20, style: .continuous)
                            .stroke(Color.black.opacity(0.04), lineWidth: 0.6)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
                    .matchedGeometryEffect(id: "\(id)_background", in: namespace)
            )
            .scaleEffect(pressScale)
            .onTapGesture {
                guard !isExpanded else { return }
                
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.08)) {
                    pressScale = 0.975
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        pressScale = 1.0
                    }
                }
                
                withAnimation(.interactiveSpring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.18)) {
                    isExpanded = true
                }
                
                onTap?()
            }
    }
}

private struct ExpandedContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Expanded Card Overlay (自适应高度 + 高级动效)
struct ExpandedCardOverlay<Content: View>: View {
    let id: String
    let title: String
    @ViewBuilder let content: () -> Content
    
    @Binding var isExpanded: Bool
    var namespace: Namespace.ID
    var onClose: (() -> Void)?
    
    @State private var measuredContentHeight: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.985
    @State private var cardYOffset: CGFloat = 20
    @State private var keyboardHeight: CGFloat = 0

    // 尺寸配置
    private let horizontalInset: CGFloat = 18
    private let verticalInset: CGFloat = 32
    private let minHeight: CGFloat = 300
    private let maxHeightRatio: CGFloat = 0.88
    private let headerHeight: CGFloat = 50
    private let contentBottomPadding: CGFloat = 26
    private let contentTopPadding: CGFloat = 6

    private let dismissThreshold: CGFloat = 120
    private let velocityThreshold: CGFloat = 800
    
    var body: some View {
        GeometryReader { geometry in
            let maxCardHeight = geometry.size.height * maxHeightRatio
            let desiredHeight = headerHeight + measuredContentHeight + contentBottomPadding
            let cardHeight = min(max(desiredHeight, minHeight), maxCardHeight)
            let shouldScroll = desiredHeight > maxCardHeight

            ZStack {
                // 背景层：模糊 + 暗化，提升高级感
                ZStack {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                        .ignoresSafeArea()
                    Color.black.opacity(0.14)
                        .ignoresSafeArea()
                }
                .opacity(backgroundOpacity)
                .onTapGesture {
                    close()
                }

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)

                        Spacer()

                        Button {
                            close()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#808991"))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color(hex: "#F3F5F7"))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 10)

                    Group {
                        if shouldScroll {
                            ScrollView(showsIndicators: false) {
                                measuredContent
                            }
                        } else {
                            measuredContent
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                    .padding(.top, contentTopPadding)
                }
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color(hex: "#FFFFFF"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.black.opacity(0.05), lineWidth: 0.6)
                        )
                        .matchedGeometryEffect(id: "\(id)_background", in: namespace)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 32, x: 0, y: 16)
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, verticalInset)
                .offset(y: dragOffset + cardYOffset - keyboardHeight * 0.5)
                .scaleEffect(cardScale, anchor: .center)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard value.translation.height > 0 else { return }
                            dragOffset = value.translation.height * 0.78
                            let progress = min(1.0, value.translation.height / 280)
                            backgroundOpacity = 1.0 - (progress * 0.55)
                            cardScale = 1.0 - (progress * 0.03)
                        }
                        .onEnded { value in
                            let shouldDismiss = value.translation.height > dismissThreshold ||
                                value.velocity.height > velocityThreshold

                            if shouldDismiss {
                                close(byGesture: true)
                            } else {
                                withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.16)) {
                                    dragOffset = 0
                                    cardScale = 1.0
                                    backgroundOpacity = 1.0
                                }
                            }
                        }
                )
            }
            .onAppear {
                NotificationCenter.default.post(name: .hideTabBar, object: nil)
                // 使用延迟确保布局计算完成后再开始动画，减少首次卡顿
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        backgroundOpacity = 1.0
                    }
                    withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.86, blendDuration: 0.18)) {
                        cardScale = 1.0
                        cardYOffset = 0
                    }
                }
                
                // 监听键盘通知
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        withAnimation(.easeOut(duration: 0.25)) {
                            keyboardHeight = keyboardFrame.height
                        }
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = 0
                    }
                }
            }
            .onDisappear {
                NotificationCenter.default.post(name: .restoreTabBar, object: nil)
                // 移除键盘监听
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            }
        }
    }

    private var measuredContent: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.bottom, contentBottomPadding)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ExpandedContentHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ExpandedContentHeightPreferenceKey.self) { value in
                measuredContentHeight = value
            }
    }

    private func close(byGesture: Bool = false) {
        let closeAnimation = Animation.interactiveSpring(response: 0.36, dampingFraction: 0.88, blendDuration: 0.12)
        withAnimation(.easeIn(duration: byGesture ? 0.14 : 0.18)) {
            backgroundOpacity = 0
        }
        withAnimation(closeAnimation) {
            dragOffset = byGesture ? ScreenMetrics.bounds.height * 0.3 : 0
            cardScale = 0.985
            cardYOffset = 16
        }

        withAnimation(closeAnimation) {
            isExpanded = false
        }

        onClose?()
        isExpanded = false
    }
}

// MARK: - Card Size
enum CardSize {
    case small(height: CGFloat)
    case medium(height: CGFloat)
    case large(height: CGFloat)
    case auto
    
    var fixedHeight: CGFloat? {
        switch self {
        case .small(let height): return height
        case .medium(let height): return height
        case .large(let height): return height
        case .auto: return nil
        }
    }
    
    var minHeight: CGFloat {
        switch self {
        case .small: return 140
        case .medium: return 180
        case .large: return 200
        case .auto: return 120
        }
    }
    
    var isFixedHeight: Bool {
        switch self {
        case .small, .medium, .large: return true
        case .auto: return false
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @Namespace var namespace
    @Previewable @State var isExpanded = false
    
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        
        VStack {
            ExpandableCard(
                id: "test",
                cardSize: .medium(height: 180),
                preview: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("测试卡片")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.lightText)
                        
                        Text("42")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                        
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                },
                detail: {
                    VStack(spacing: 20) {
                        ForEach(0..<10) { i in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 60)
                                .overlay(Text("详情 \(i)"))
                        }
                    }
                },
                isExpanded: $isExpanded,
                namespace: namespace
            )
            .padding(.horizontal, 24)
            
            Spacer()
        }
        
        if isExpanded {
            ExpandedCardOverlay(
                id: "test",
                title: "测试卡片详情",
                content: {
                    VStack(spacing: 20) {
                        ForEach(0..<10) { i in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 60)
                                .overlay(Text("详情 \(i)"))
                        }
                    }
                },
                isExpanded: $isExpanded,
                namespace: namespace
            )
            .zIndex(100)
        }
    }
}
