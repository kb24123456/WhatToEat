import SwiftUI
import Combine

// MARK: - 内联评论输入框
/// 实现小红书风格的评论输入体验
/// 核心逻辑：
/// 1. 页面显示已有评语（或placeholder）
/// 2. 点击后弹出键盘，inputAccessoryView 作为输入区域
/// 3. 编辑内容只在 inputAccessoryView 中，不实时同步到页面
/// 4. 点击"发送"才保存到页面；点击"返回"不保存，但保留草稿供下次编辑
struct InlineCommentInput: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    var placeholder: String = "点击添加点评..."
    var onSave: (() -> Void)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    
    // 草稿文本（内部状态，不暴露给外部）
    @State private var draftText: String = ""
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.clear
        textView.layer.cornerRadius = 16
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        textView.isScrollEnabled = true
        textView.isEditable = false  // 页面上的文本视图只读
        textView.isSelectable = false
        
        // 保存引用
        context.coordinator.textView = textView
        
        // 设置初始显示（显示外部 text 或 placeholder）
        updatePageDisplay(textView: textView)
        
        // 创建 inputAccessoryView
        let accessoryView = createInputAccessoryView(context: context)
        textView.inputAccessoryView = accessoryView
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        textView.addGestureRecognizer(tapGesture)
        
        // 注册键盘通知
        context.coordinator.registerKeyboardNotifications()
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 只有在非编辑状态下才更新页面显示
        if !uiView.isFirstResponder {
            updatePageDisplay(textView: uiView)
        }
    }
    
    private func updatePageDisplay(textView: UITextView) {
        if text.isEmpty {
            textView.text = placeholder
            textView.textColor = UIColor(dynamicProvider: { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor(red: 127 / 255, green: 145 / 255, blue: 171 / 255, alpha: 1)
                }
                return UIColor.placeholderText
            })
        } else {
            textView.text = text
            textView.textColor = UIColor(dynamicProvider: { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor(red: 220 / 255, green: 230 / 255, blue: 246 / 255, alpha: 1)
                }
                return UIColor.label
            })
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createInputAccessoryView(context: Context) -> UIView {
        // 创建容器视图 - 全透明背景
        let container = UIView(frame: CGRect(x: 0, y: 0, width: ScreenMetrics.bounds.width, height: 70))
        container.backgroundColor = UIColor.clear
        container.clipsToBounds = true
        
        // 创建输入框容器 - 胶囊样式
        let inputContainer = UIView()
        inputContainer.backgroundColor = UIColor(dynamicProvider: { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 24 / 255, green: 38 / 255, blue: 56 / 255, alpha: 0.96)
            }
            return UIColor.white
        })
        inputContainer.layer.cornerRadius = 22
        inputContainer.layer.shadowColor = UIColor.black.cgColor
        inputContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        inputContainer.layer.shadowRadius = 10
        inputContainer.layer.shadowOpacity = colorScheme == .dark ? 0.32 : 0.15
        inputContainer.layer.borderWidth = 0.8
        inputContainer.layer.borderColor = UIColor(dynamicProvider: { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 48 / 255, green: 74 / 255, blue: 103 / 255, alpha: 0.75)
            }
            return UIColor.gray.withAlphaComponent(0.14)
        }).cgColor
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(inputContainer)
        
        // 创建多行输入框
        let inputTextView = UITextView()
        inputTextView.delegate = context.coordinator
        inputTextView.font = UIFont.systemFont(ofSize: 16)
        inputTextView.textColor = UIColor(dynamicProvider: { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 220 / 255, green: 230 / 255, blue: 246 / 255, alpha: 1)
            }
            return UIColor.label
        })
        inputTextView.backgroundColor = UIColor.clear
        inputTextView.isScrollEnabled = true
        inputTextView.showsVerticalScrollIndicator = false
        inputTextView.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 36) // 右侧留出清除按钮空间
        inputTextView.returnKeyType = .send
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputTextView)
        
        // 创建清除按钮（仿照 UITextField 的 clearButtonMode）
        let clearButton = UIButton(type: .system)
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = UIColor(dynamicProvider: { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 139 / 255, green: 160 / 255, blue: 188 / 255, alpha: 1)
            }
            return UIColor.placeholderText
        })
        clearButton.alpha = 0  // 初始隐藏
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.addTarget(context.coordinator, action: #selector(Coordinator.handleClearButtonTapped), for: .touchUpInside)
        inputContainer.addSubview(clearButton)
        context.coordinator.clearButton = clearButton
        
        // 设置约束
        NSLayoutConstraint.activate([
            inputContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            inputContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            inputContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            inputContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            
            inputTextView.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 4),
            inputTextView.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -4),
            inputTextView.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 4),
            inputTextView.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -4),
            inputTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            inputTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 80),
            
            // 清除按钮约束 - 垂直居中，右侧对齐
            clearButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -8),
            clearButton.widthAnchor.constraint(equalToConstant: 24),
            clearButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // 保存引用
        context.coordinator.inputTextView = inputTextView
        context.coordinator.inputContainer = inputContainer
        context.coordinator.accessoryContainer = container
        
        return container
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: InlineCommentInput
        weak var inputTextView: UITextView?
        weak var textView: UITextView?
        weak var inputContainer: UIView?
        weak var accessoryContainer: UIView?
        weak var clearButton: UIButton?  // 清除按钮引用
        
        // 草稿文本（只在 inputAccessoryView 中编辑）
        private var draftText: String = ""
        
        init(_ parent: InlineCommentInput) {
            self.parent = parent
            // 初始化草稿为当前外部文本
            self.draftText = parent.text
        }
        
        // MARK: - 清除按钮处理
        @objc func handleClearButtonTapped() {
            guard let inputTextView = inputTextView else { return }
            
            // 清空输入框
            inputTextView.text = ""
            draftText = ""
            
            // 隐藏清除按钮
            updateClearButtonVisibility()
        }
        
        // 更新清除按钮可见性
        private func updateClearButtonVisibility() {
            guard let clearButton = clearButton else { return }
            
            let hasText = !(inputTextView?.text ?? "").isEmpty
            UIView.animate(withDuration: 0.2) {
                clearButton.alpha = hasText ? 1.0 : 0.0
            }
        }
        
        deinit {
            unregisterKeyboardNotifications()
        }
        
        // MARK: - 键盘通知
        func registerKeyboardNotifications() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }
        
        func unregisterKeyboardNotifications() {
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        
        @objc func keyboardWillShow(_ notification: Notification) {
            parent.onEditingChanged?(true)
        }
        
        @objc func keyboardWillHide(_ notification: Notification) {
            inputTextView?.resignFirstResponder()
            textView?.resignFirstResponder()
            parent.onEditingChanged?(false)
        }
        
        @objc func handleTap() {
            // 点击页面上的文本视图，准备编辑
            textView?.becomeFirstResponder()
            
            // 延迟后让 inputTextView 成为第一响应者并设置草稿文本
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.inputTextView?.becomeFirstResponder()
            }
        }
        
        // MARK: - UITextViewDelegate (inputAccessoryView 中的输入框)
        func textViewDidBeginEditing(_ textView: UITextView) {
            // 设置草稿文本到 inputAccessoryView
            // 如果有草稿就显示草稿，否则显示外部文本
            textView.text = draftText
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // 只更新草稿，不更新外部 text
            draftText = textView.text ?? ""
            
            // 更新清除按钮可见性
            updateClearButtonVisibility()
            
            // 动态调整高度
            updateInputAccessoryViewHeight()
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // 处理键盘的"发送"按钮（回车键）
            if text == "\n" {
                handleSendAction()
                return false
            }
            return true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            // 编辑结束，但不保存草稿到外部
            // 草稿保留在 draftText 中，供下次编辑使用
        }
        
        // MARK: - 动态调整高度
        private func updateInputAccessoryViewHeight() {
            guard let inputTextView = inputTextView,
                  let accessoryContainer = accessoryContainer else { return }
            
            let fixedWidth = inputTextView.frame.width
            let newSize = inputTextView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
            let textHeight = newSize.height
            
            let newHeight = min(max(textHeight + 28, 70), 120)
            
            var frame = accessoryContainer.frame
            frame.size.height = newHeight
            accessoryContainer.frame = frame
            
            let cornerRadius: CGFloat = 16
            let maskLayer = CAShapeLayer()
            let path = UIBezierPath(
                roundedRect: frame,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
            )
            maskLayer.path = path.cgPath
            accessoryContainer.layer.mask = maskLayer
        }
        
        // MARK: - 处理发送操作
        private func handleSendAction() {
            guard let inputTextView = inputTextView else { return }
            
            // 保存草稿到外部 text
            let finalText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
            parent.text = finalText
            
            // 更新页面显示
            if finalText.isEmpty {
                textView?.text = parent.placeholder
                textView?.textColor = UIColor(dynamicProvider: { traits in
                    if traits.userInterfaceStyle == .dark {
                        return UIColor(red: 127 / 255, green: 145 / 255, blue: 171 / 255, alpha: 1)
                    }
                    return UIColor.placeholderText
                })
            } else {
                textView?.text = finalText
                textView?.textColor = UIColor(dynamicProvider: { traits in
                    if traits.userInterfaceStyle == .dark {
                        return UIColor(red: 220 / 255, green: 230 / 255, blue: 246 / 255, alpha: 1)
                    }
                    return UIColor.label
                })
            }
            
            // 执行保存回调
            parent.onSave?()
            
            // 退出键盘
            inputTextView.resignFirstResponder()
            textView?.resignFirstResponder()
        }
    }
}

// MARK: - 评论输入包装视图
struct InlineCommentInputView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    var placeholder: String = "点击添加点评..."
    var onSave: (() -> Void)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    
    var body: some View {
        InlineCommentInput(text: $text, placeholder: placeholder, onSave: onSave, onEditingChanged: onEditingChanged)
            .frame(minHeight: 80, maxHeight: 120)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.02))
                        .offset(y: colorScheme == .dark ? 2 : 1)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            colorScheme == .dark
                            ? Color.fixedHex("#1A2A3D").opacity(0.82)
                            : Color.white.opacity(0.98)
                        )

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                            ? Color.fixedHex("#355273").opacity(0.62)
                            : Color.white.opacity(0.8),
                            lineWidth: colorScheme == .dark ? 0.8 : 1
                        )

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.gray.opacity(0.15),
                            lineWidth: 0.5
                        )
                }
            )
    }
}

// MARK: - 预览
#Preview {
    InlineCommentInputView(text: .constant(""))
        .padding()
}
