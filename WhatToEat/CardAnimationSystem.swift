//
//  CardAnimationSystem.swift
//  WhatToEat
//
//  卡片动画系统 - 提供高级展开/收回动画支持
//

import SwiftUI

private struct DisableDashboardDetailAnimationsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var disableDashboardDetailAnimations: Bool {
        get { self[DisableDashboardDetailAnimationsKey.self] }
        set { self[DisableDashboardDetailAnimationsKey.self] = newValue }
    }
}

// MARK: - 动画阶段状态
enum CardAnimationPhase: Equatable {
    case idle           // 初始状态
    case expanding    // 展开动画中
    case expanded     // 完全展开
    case collapsing   // 收回动画中
    
    var isAnimating: Bool {
        self == .expanding || self == .collapsing
    }
}

// MARK: - 卡片内容动画控制器
@Observable
final class CardAnimationController {
    var phase: CardAnimationPhase = .idle
    var contentReady: Bool = false
    var staggerIndex: Int = 0
    
    // 动画时间配置
    let staggerDelay: Double = 0.05      // 级联延迟
    let contentFadeDuration: Double = 0.4 // 内容淡入时长
    let springResponse: Double = 0.35    // 弹簧响应时间
    let springDamping: Double = 0.75     // 弹簧阻尼
    
    // 开始展开动画
    func beginExpansion() {
        phase = .expanding
        contentReady = false
        staggerIndex = 0
        
        // 延迟显示内容，等待容器动画开始
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            contentReady = true
            
            // 开始级联动画
            await runStaggerAnimation()
        }
    }
    
    // 开始收回动画
    func beginCollapse() {
        phase = .collapsing
        contentReady = false
    }
    
    // 完成动画
    func completeAnimation() {
        phase = phase == .expanding ? .expanded : .idle
    }
    
    // 级联动画
    private func runStaggerAnimation() async {
        let maxStagger = 10 // 最大级联元素数
        for i in 0..<maxStagger {
            guard phase == .expanding else { break }
            staggerIndex = i + 1
            try? await Task.sleep(for: .milliseconds(Int(staggerDelay * 1000)))
        }

        // 级联完成后进入 fully expanded，避免后续元素长期不可见。
        if phase == .expanding {
            completeAnimation()
        }
    }
    
    // 获取元素的动画状态
    func animationState(for index: Int) -> AnimationState {
        if phase == .expanded {
            return AnimationState(opacity: 1, offset: 0, scale: 1)
        }

        guard phase == .expanding else {
            return AnimationState(opacity: 0, offset: 20, scale: 0.95)
        }
        
        let isVisible = contentReady && staggerIndex > index
        let progress = min(1.0, Double(staggerIndex - index) * 0.5)
        
        return AnimationState(
            opacity: isVisible ? 1.0 : 0.0,
            offset: isVisible ? 0 : 20 * (1 - progress),
            scale: isVisible ? 1.0 : 0.95 + (0.05 * progress)
        )
    }
}

// MARK: - 动画状态结构
struct AnimationState {
    let opacity: Double
    let offset: CGFloat
    let scale: CGFloat
}

// MARK: - 内容级联动画修饰符
struct StaggeredAnimationModifier: ViewModifier {
    @Environment(\.disableDashboardDetailAnimations) private var disableDashboardDetailAnimations
    let index: Int
    let controller: CardAnimationController
    
    func body(content: Content) -> some View {
        guard !disableDashboardDetailAnimations else {
            return AnyView(content)
        }

        let state = controller.animationState(for: index)
        
        return AnyView(
            content
            .opacity(state.opacity)
            .offset(y: state.offset)
            .scaleEffect(state.scale, anchor: .top)
            .animation(
                .spring(
                    response: controller.springResponse,
                    dampingFraction: controller.springDamping
                ),
                value: controller.staggerIndex
            )
        )
    }
}

extension View {
    // 应用级联动画
    func staggeredAnimation(index: Int, controller: CardAnimationController) -> some View {
        modifier(StaggeredAnimationModifier(index: index, controller: controller))
    }
}

// MARK: - 几何匹配动画修饰符
struct MatchedContentModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(id: id, in: namespace, properties: .position, isSource: isActive)
    }
}

extension View {
    // 内容几何匹配
    func matchedContent(id: String, in namespace: Namespace.ID, isActive: Bool) -> some View {
        modifier(MatchedContentModifier(id: id, namespace: namespace, isActive: isActive))
    }
}

// MARK: - 展开内容容器
struct AnimatedExpandedContent<Content: View>: View {
    let controller: CardAnimationController
    let namespace: Namespace.ID
    let cardId: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            content()
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .padding(.top, 8)
        }
        .onAppear {
            controller.beginExpansion()
        }
        .onDisappear {
            controller.beginCollapse()
        }
    }
}

// MARK: - 数字滚动动画
struct AnimatedNumberText: View {
    let value: Int
    let font: Font
    let color: Color
    
    @State private var displayValue: Int = 0
    
    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .onAppear {
                animateNumber()
            }
            .onChange(of: value) { _, _ in
                animateNumber()
            }
    }
    
    private func animateNumber() {
        let duration: Double = 0.6
        let steps = 20
        let stepDuration = duration / Double(steps)
        let increment = Double(value) / Double(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * stepDuration)) {
                let newValue = min(value, Int(Double(i) * increment))
                withAnimation(.easeOut(duration: stepDuration)) {
                    displayValue = newValue
                }
            }
        }
    }
}

// MARK: - 图表展开动画
struct ChartExpansionAnimation: ViewModifier {
    let isExpanded: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isExpanded ? 1.0 : 0.8, anchor: .center)
            .opacity(isExpanded ? 1.0 : 0.0)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.7),
                value: isExpanded
            )
    }
}

extension View {
    func chartExpansion(isExpanded: Bool) -> some View {
        modifier(ChartExpansionAnimation(isExpanded: isExpanded))
    }
}

// MARK: - 手势关闭控制器
struct DismissibleCardModifier: ViewModifier {
    @Binding var isExpanded: Bool
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let dismissThreshold: CGFloat = 120
    private let velocityThreshold: CGFloat = 800
    
    func body(content: Content) -> some View {
        content
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard value.translation.height > 0 else { return }
                        isDragging = true
                        // 阻力效果
                        dragOffset = value.translation.height * 0.6
                    }
                    .onEnded { value in
                        isDragging = false
                        let shouldDismiss = value.translation.height > dismissThreshold ||
                                          value.velocity.height > velocityThreshold
                        
                        if shouldDismiss {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = ScreenMetrics.bounds.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDismiss()
                            }
                        } else {
                            withAnimation(
                                .interpolatingSpring(stiffness: 300, damping: 25)
                            ) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onChange(of: isExpanded) { _, newValue in
                if !newValue {
                    dragOffset = 0
                }
            }
    }
}

extension View {
    func dismissibleCard(isExpanded: Binding<Bool>, onDismiss: @escaping () -> Void) -> some View {
        modifier(DismissibleCardModifier(isExpanded: isExpanded, onDismiss: onDismiss))
    }
}

// MARK: - 预览
#Preview {
    struct Preview: View {
        @Namespace var namespace
        @State private var controller = CardAnimationController()
        
        var body: some View {
            VStack(spacing: 20) {
                // 测试级联动画
                VStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.3))
                            .frame(height: 40)
                            .staggeredAnimation(index: index, controller: controller)
                    }
                }
                .padding()
                
                Button("触发展开动画") {
                    controller.beginExpansion()
                }
                
                Button("触发收回动画") {
                    controller.beginCollapse()
                }
            }
        }
    }
    
    return Preview()
}
