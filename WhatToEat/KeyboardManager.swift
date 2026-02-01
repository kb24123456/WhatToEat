import SwiftUI
import Combine

// MARK: - 全局键盘管理器
class KeyboardManager: ObservableObject {
    static let shared = KeyboardManager()
    
    // 键盘动画延迟时间
    let keyboardAnimationDelay: TimeInterval = 0.25
    
    // 当前是否有动画正在进行
    @Published private var isAnimationInProgress = false
    
    // 待处理的焦点请求
    private var pendingFocusRequest: (() -> Void)?
    private var focusTimer: Timer?
    
    private init() {}
    
    // MARK: - 请求键盘焦点（带延迟）
    func requestFocus(_ focusAction: @escaping () -> Void) {
        // 取消之前的请求
        focusTimer?.invalidate()
        pendingFocusRequest = focusAction
        
        // 延迟执行焦点请求
        focusTimer = Timer.scheduledTimer(withTimeInterval: keyboardAnimationDelay, repeats: false) { _ in
            DispatchQueue.main.async {
                focusAction()
                self.pendingFocusRequest = nil
            }
        }
    }
    
    // MARK: - 取消待处理的焦点请求
    func cancelPendingFocus() {
        focusTimer?.invalidate()
        focusTimer = nil
        pendingFocusRequest = nil
    }
    
    // MARK: - 标记动画开始
    func beginAnimation() {
        isAnimationInProgress = true
    }
    
    // MARK: - 标记动画结束
    func endAnimation() {
        isAnimationInProgress = false
        // 如果有待处理的焦点请求，立即执行
        if let request = pendingFocusRequest {
            request()
            pendingFocusRequest = nil
        }
    }
}

// MARK: - 全局键盘避让修饰符
struct KeyboardAvoidanceModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    @State private var bottomPadding: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - bottomPadding : 0)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
            .onAppear {
                // 获取底部安全区域高度
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    bottomPadding = windowScene.windows.first?.safeAreaInsets.bottom ?? 0
                }
            }
    }
}

// MARK: - View 扩展
extension View {
    // 全局键盘避让
    func globalKeyboardAvoidance() -> some View {
        modifier(KeyboardAvoidanceModifier())
    }
    
    // 延迟聚焦（带动画等待）
    func delayedFocus(_ isFocused: FocusState<Bool>.Binding, delay: TimeInterval? = nil) -> some View {
        self.onAppear {
            let delayTime = delay ?? KeyboardManager.shared.keyboardAnimationDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
                isFocused.wrappedValue = true
            }
        }
    }
}

// MARK: - 全局焦点状态包装器
@propertyWrapper
struct DelayedFocus: DynamicProperty {
    @FocusState private var isFocused: Bool
    private let delay: TimeInterval
    
    var wrappedValue: Bool {
        get { isFocused }
        nonmutating set { isFocused = newValue }
    }
    
    var projectedValue: FocusState<Bool>.Binding {
        $isFocused
    }
    
    init(wrappedValue: Bool = false, delay: TimeInterval = 0.25) {
        self.delay = delay
        self._isFocused = FocusState()
        self.isFocused = wrappedValue
    }
    
    func activate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isFocused = true
        }
    }
    
    func deactivate() {
        isFocused = false
    }
}
