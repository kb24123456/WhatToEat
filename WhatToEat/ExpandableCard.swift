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
    
    @State private var isAnimating = false
    @State private var animationCompleted = true
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        preview()
            .frame(maxWidth: .infinity)
            .frame(height: cardSize.fixedHeight)
            .background(
                RoundedRectangle(cornerRadius: isExpanded ? 28 : 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                    .matchedGeometryEffect(id: "\(id)_background", in: namespace)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isExpanded ? 28 : 20, style: .continuous)
                    .stroke(Color.clear, lineWidth: 0)
                    .matchedGeometryEffect(id: "\(id)_border", in: namespace)
            )
            .scaleEffect(scale)
            .opacity(isAnimating ? 0.9 : 1.0)
            .onTapGesture {
                guard animationCompleted && !isAnimating else { return }
                
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.1)) {
                    scale = 0.96
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        scale = 1.0
                    }
                }
                
                isAnimating = true
                animationCompleted = false
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0)) {
                    isExpanded = true
                }
                
                onTap?()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAnimating = false
                    animationCompleted = true
                }
            }
    }
}

// MARK: - Expanded Card Overlay (优化版)
struct ExpandedCardOverlay<Content: View>: View {
    let id: String
    let title: String
    @ViewBuilder let content: () -> Content
    
    @Binding var isExpanded: Bool
    var namespace: Namespace.ID
    var onClose: (() -> Void)?
    
    @State private var animationController = CardAnimationController()
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var backgroundOpacity: Double = 0
    @State private var isAnimating = false
    @State private var animationCompleted = false
    
    // 高度配置
    private let minHeight: CGFloat = 300
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.75
    private let dismissThreshold: CGFloat = 120
    private let velocityThreshold: CGFloat = 800
    
    var body: some View {
        ZStack {
            // 背景模糊层
            VisualEffectBlur(blurStyle: .systemMaterial)
                .ignoresSafeArea()
                .opacity(backgroundOpacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.25)) {
                        backgroundOpacity = 1.0
                    }
                }
                .onTapGesture {
                    guard animationCompleted && !isAnimating else { return }
                    close()
                }
            
            // 卡片容器 - 使用 GeometryReader 实现自适应高度
            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                let cardHeight = min(maxHeight, max(minHeight, availableHeight * 0.7))
                
                VStack(spacing: 0) {
                    // 标题栏
                    HStack {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                        
                        Spacer()
                        
                        Button {
                            guard animationCompleted && !isAnimating else { return }
                            close()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(AppTheme.Colors.softBackground)
                                )
                        }
                        .disabled(isAnimating)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .staggeredAnimation(index: 0, controller: animationController)
                    
                    // 内容区域 - 使用 ScrollView 但限制最大高度
                    ScrollView(showsIndicators: false) {
                        content()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                    }
                    .frame(maxHeight: cardHeight - 70) // 减去标题栏高度
                }
                .frame(maxWidth: .infinity, maxHeight: cardHeight, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white)
                        .matchedGeometryEffect(id: "\(id)_background", in: namespace)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.clear, lineWidth: 0)
                        .matchedGeometryEffect(id: "\(id)_border", in: namespace)
                )
                .padding(.horizontal, 20)
                .offset(y: dragOffset)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard animationCompleted && !isAnimating else { return }
                            
                            if value.translation.height > 0 {
                                isDragging = true
                                dragOffset = value.translation.height * 0.5
                                let progress = min(1.0, value.translation.height / 300)
                                backgroundOpacity = 1.0 - (progress * 0.5)
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            let shouldDismiss = value.translation.height > dismissThreshold ||
                                              value.velocity.height > velocityThreshold
                            
                            if shouldDismiss {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    dragOffset = UIScreen.main.bounds.height
                                    backgroundOpacity = 0
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    performClose()
                                }
                            } else {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                                    dragOffset = 0
                                    backgroundOpacity = 1.0
                                }
                            }
                        }
                )
            }
        }
        .onAppear {
            isAnimating = true
            animationCompleted = false
            animationController.beginExpansion()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimating = false
                animationCompleted = true
            }
        }
    }
    
    private func close() {
        isAnimating = true
        animationCompleted = false
        
        withAnimation(.easeIn(duration: 0.15)) {
            backgroundOpacity = 0
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85, blendDuration: 0)) {
            isExpanded = false
            dragOffset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            onClose?()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isAnimating = false
            animationCompleted = true
        }
    }
    
    private func performClose() {
        isExpanded = false
        dragOffset = 0
        onClose?()
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
