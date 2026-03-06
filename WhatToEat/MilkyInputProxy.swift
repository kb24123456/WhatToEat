import SwiftUI
import Combine

// MARK: - 全局输入代理管理器
/// 轻量级 ObservableObject，仅在 ContentView 最顶层渲染一次
/// 用于解决键盘遮挡问题并维持页面静止
@MainActor
final class InputProxyManager: ObservableObject {
    static let shared = InputProxyManager()
    
    // MARK: - 代理状态
    /// 是否激活吸附栏模式
    @Published var isProxyActive: Bool = false
    
    /// 代理输入框中的文字，与原输入框同步
    @Published var proxyText: String = ""
    
    /// 输入完成后的回调闭包
    var onCommit: ((String) -> Void)?
    
    /// 原始输入框的绑定（用于双向同步）
    private var originalBinding: Binding<String>?
    
    /// 占位符文本
    @Published var placeholder: String = ""
    
    /// 键盘高度通知订阅
    private var keyboardCancellable: AnyCancellable?
    
    /// 当前键盘高度
    @Published var keyboardHeight: CGFloat = 0
    
    private init() {
        setupKeyboardNotifications()
    }

    static func isSmartInputProxyEnabled() -> Bool {
        true
    }
    
    // MARK: - 键盘高度监听
    private func setupKeyboardNotifications() {
        keyboardCancellable = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { notification -> CGFloat? in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return nil
                }
                return frame.height
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = height
                }
            }
    }
    
    // MARK: - 激活代理模式
    /// 激活输入代理
    /// - Parameters:
    ///   - text: 当前输入框的文字
    ///   - binding: 原始输入框的绑定
    ///   - placeholder: 占位符文本
    ///   - onCommit: 输入完成回调
    func activate(
        text: String,
        binding: Binding<String>,
        placeholder: String = "",
        onCommit: @escaping (String) -> Void
    ) {
        guard Self.isSmartInputProxyEnabled() else {
            return
        }

        self.proxyText = text
        self.originalBinding = binding
        self.placeholder = placeholder
        self.onCommit = onCommit
        
        withAnimation(.easeOut(duration: 0.2)) {
            self.isProxyActive = true
        }
    }
    
    // MARK: - 关闭代理模式
    /// 关闭输入代理，将数据回流到原输入框
    func deactivate(commit: Bool = true) {
        if commit {
            // 触发完成回调
            onCommit?(proxyText)
            // 同步回原输入框
            originalBinding?.wrappedValue = proxyText
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            self.isProxyActive = false
        }
        
        // 清理
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.proxyText = ""
            self.originalBinding = nil
            self.onCommit = nil
        }
    }
    
    // MARK: - 实时同步
    /// 将代理输入同步回原输入框（实时）
    func syncToOriginal() {
        originalBinding?.wrappedValue = proxyText
    }
}

// MARK: - 触发式焦点修饰符
/// 仅在输入框被点击或获得焦点时触发位置判定
struct SmartFocusModifier: ViewModifier {
    @Binding var text: String
    let placeholder: String
    let onCommit: (String) -> Void
    
    /// 输入框的唯一标识
    let inputId: String
    
    /// 本地焦点状态（用于检测焦点变化）
    @FocusState private var isFocused: Bool
    
    /// 是否已触发代理（避免重复触发）
    @State private var hasTriggeredProxy = false
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { _, newValue in
                if newValue && !hasTriggeredProxy {
                    // 获得焦点时检查位置
                    checkPositionAndTriggerProxy()
                }
            }
            .onTapGesture {
                // 点击时检查位置
                if !hasTriggeredProxy {
                    checkPositionAndTriggerProxy()
                }
            }
    }
    
    /// 检查输入框位置并决定是否触发代理
    private func checkPositionAndTriggerProxy() {
        guard InputProxyManager.isSmartInputProxyEnabled() else {
            return
        }

        // 获取输入框在屏幕中的位置
        // 使用延迟确保布局完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let window = scenes
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })?
                .windows.first(where: \.isKeyWindow)
                ?? scenes.first?.windows.first

            guard let window,
                  let rootView = window.rootViewController?.view else {
                return
            }
            
            // 查找输入框的坐标
            // 通过遍历视图层级找到包含该修饰符的输入框
            findInputFieldPosition(in: rootView) { centerY in
                let screenHeight = ScreenMetrics.bounds.height
                let threshold = screenHeight * 0.5  // 屏幕下半部阈值
                
                if centerY > threshold {
                    // 处于屏幕下半部：激活代理模式
                    hasTriggeredProxy = true
                    isFocused = false  // 拦截原地焦点
                    
                    InputProxyManager.shared.activate(
                        text: text,
                        binding: $text,
                        placeholder: placeholder,
                        onCommit: onCommit
                    )
                }
            }
        }
    }
    
    /// 查找输入框在屏幕中的 Y 坐标中心
    private func findInputFieldPosition(in view: UIView, completion: @escaping (CGFloat) -> Void) {
        if let firstResponder = findFirstResponder(in: view) {
            let frame = firstResponder.convert(firstResponder.bounds, to: nil)
            completion(frame.midY)
            return
        }

        // 找不到输入框时使用中位值，避免误触发。
        completion(ScreenMetrics.bounds.height * 0.5)
    }

    private func findFirstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder {
            return view
        }
        for subview in view.subviews {
            if let responder = findFirstResponder(in: subview) {
                return responder
            }
        }
        return nil
    }
}

// MARK: - 键盘吸附栏组件
/// 紧贴键盘上边缘的输入栏
struct AccessoryInputView: View {
    @StateObject private var proxyManager = InputProxyManager.shared
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if proxyManager.isProxyActive {
                inputBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: proxyManager.isProxyActive) { _, isActive in
            if isActive {
                // 吸附栏出现后自动获取焦点
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            } else {
                isInputFocused = false
            }
        }
    }
    
    /// 输入栏主体
    private var inputBar: some View {
        HStack(spacing: 12) {
            // 输入框
            TextField(proxyManager.placeholder, text: $proxyManager.proxyText)
                .font(.body)
                .foregroundColor(AppTheme.Colors.darkText)
                .focused($isInputFocused)
                .onChange(of: proxyManager.proxyText) { _, _ in
                    // 实时同步回原输入框
                    proxyManager.syncToOriginal()
                }
                .onSubmit {
                    commitInput()
                }
            
            // 完成按钮
            Button {
                commitInput()
            } label: {
                Text("完成")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.babyBlue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 52)
        .background(
            // Misty Oreo 风格背景
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    /// 提交输入
    private func commitInput() {
        // 触感反馈
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // 关闭代理
        proxyManager.deactivate(commit: true)
    }
}

// MARK: - 性能冻结修饰符
/// 当代理激活时冻结底层视图渲染
struct PerformanceFreezeModifier: ViewModifier {
    @StateObject private var proxyManager = InputProxyManager.shared
    
    func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .disabled(proxyManager.isProxyActive)
    }
}

// MARK: - 便捷扩展
extension View {
    /// 应用智能焦点修饰符（触发式代理）
    func smartFocus(
        text: Binding<String>,
        placeholder: String = "",
        inputId: String = UUID().uuidString,
        onCommit: @escaping (String) -> Void = { _ in }
    ) -> some View {
        self.modifier(SmartFocusModifier(
            text: text,
            placeholder: placeholder,
            onCommit: onCommit,
            inputId: inputId
        ))
    }
    
    /// 应用性能冻结（用于底层视图）
    func performanceFreeze() -> some View {
        self.modifier(PerformanceFreezeModifier())
    }
}
