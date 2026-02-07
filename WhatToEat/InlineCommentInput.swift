import SwiftUI
import Combine

// MARK: - 内联评论输入框
/// 实现小红书风格的评论输入体验
/// 页面显示已有评语，点击后弹出键盘，inputAccessoryView 作为输入区域（支持多行）
struct InlineCommentInput: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "点击添加点评..."
    var onSave: (() -> Void)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil  // 编辑状态变化回调
    
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
        
        // 设置初始文本
        let initialText = text
        if initialText.isEmpty {
            textView.text = placeholder
            textView.textColor = UIColor.placeholderText
        } else {
            textView.text = initialText
            textView.textColor = UIColor.label
        }
        
        // 创建 inputAccessoryView
        let accessoryView = createInputAccessoryView(context: context, initialText: initialText)
        textView.inputAccessoryView = accessoryView
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        textView.addGestureRecognizer(tapGesture)
        
        // 注册键盘通知
        context.coordinator.registerKeyboardNotifications()
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if !uiView.isFirstResponder {
            let currentText = uiView.text ?? ""
            let expectedText = text.isEmpty ? placeholder : text
            
            if currentText != expectedText {
                uiView.text = expectedText
                uiView.textColor = text.isEmpty ? UIColor.placeholderText : UIColor.label
            }
        }
        
        // 同步更新 inputAccessoryView 中的文本
        if let inputTextView = context.coordinator.inputTextView {
            if inputTextView.text != text {
                inputTextView.text = text
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createInputAccessoryView(context: Context, initialText: String) -> UIView {
        // 创建容器视图 - 全透明背景
        let container = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 70))
        container.backgroundColor = UIColor.clear  // 全透明
        container.clipsToBounds = true
        
        // 创建输入框容器 - 胶囊样式
        let inputContainer = UIView()
        inputContainer.backgroundColor = UIColor.systemBackground  // 输入框保持白色背景
        inputContainer.layer.cornerRadius = 22
        inputContainer.layer.shadowColor = UIColor.black.cgColor
        inputContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        inputContainer.layer.shadowRadius = 8
        inputContainer.layer.shadowOpacity = 0.15  // 增加阴影让胶囊更突出
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(inputContainer)
        
        // 创建多行输入框（UITextView 替代 UITextField）
        let inputTextView = UITextView()
        inputTextView.delegate = context.coordinator
        inputTextView.font = UIFont.systemFont(ofSize: 16)
        inputTextView.textColor = UIColor.label
        inputTextView.backgroundColor = UIColor.clear
        inputTextView.isScrollEnabled = true
        inputTextView.showsVerticalScrollIndicator = false
        inputTextView.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        inputTextView.returnKeyType = .send  // 回车键显示"发送"
        inputTextView.text = initialText.isEmpty ? "" : initialText
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputTextView)
        
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
            inputTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 80)
        ])
        
        // 保存引用
        context.coordinator.inputTextView = inputTextView
        context.coordinator.inputContainer = inputContainer
        context.coordinator.accessoryContainer = container
        
        return container
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: InlineCommentInput
        weak var inputTextView: UITextView?  // inputAccessoryView 中的输入框
        weak var textView: UITextView?       // 页面上的文本视图
        weak var inputContainer: UIView?     // 输入框容器
        weak var accessoryContainer: UIView? // 整个 accessoryView 容器
        
        init(_ parent: InlineCommentInput) {
            self.parent = parent
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
            // 通知外部键盘即将显示
            parent.onEditingChanged?(true)
        }
        
        @objc func keyboardWillHide(_ notification: Notification) {
            // 当键盘即将收起时，确保所有输入框都退出第一响应者
            inputTextView?.resignFirstResponder()
            textView?.resignFirstResponder()
            
            // 通知外部键盘即将隐藏
            parent.onEditingChanged?(false)
        }
        
        @objc func handleTap() {
            // 点击页面上的文本视图，让 inputAccessoryView 的输入框成为第一响应者
            textView?.becomeFirstResponder()
            
            // 然后让 inputTextView 成为第一响应者
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.inputTextView?.becomeFirstResponder()
            }
        }
        
        // MARK: - UITextViewDelegate (inputAccessoryView 中的输入框)
        func textViewDidBeginEditing(_ textView: UITextView) {
            // 设置初始文本
            let currentText = parent.text
            if !currentText.isEmpty {
                textView.text = currentText
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // 实时更新文本
            let newText = textView.text ?? ""
            parent.text = newText
            
            // 同步更新页面上的文本视图
            self.textView?.text = newText.isEmpty ? parent.placeholder : newText
            self.textView?.textColor = newText.isEmpty ? UIColor.placeholderText : UIColor.label
            
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
            // 同步最终文本
            let finalText = textView.text ?? ""
            parent.text = finalText
            
            // 更新页面显示
            if finalText.isEmpty {
                self.textView?.text = parent.placeholder
                self.textView?.textColor = UIColor.placeholderText
            } else {
                self.textView?.text = finalText
                self.textView?.textColor = UIColor.label
            }
        }
        
        // MARK: - 动态调整高度
        private func updateInputAccessoryViewHeight() {
            guard let inputTextView = inputTextView,
                  let accessoryContainer = accessoryContainer else { return }
            
            // 计算文本高度
            let fixedWidth = inputTextView.frame.width
            let newSize = inputTextView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
            let textHeight = newSize.height
            
            // 计算新的容器高度（最小70，最大120）
            let newHeight = min(max(textHeight + 28, 70), 120)  // 28 = 上下padding 12*2 + 容器间距
            
            // 更新容器高度
            var frame = accessoryContainer.frame
            frame.size.height = newHeight
            accessoryContainer.frame = frame
            
            // 更新圆角遮罩
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
            
            // 获取最终文本
            let finalText = inputTextView.text ?? ""
            parent.text = finalText
            
            // 更新页面文本视图
            if finalText.isEmpty {
                textView?.text = parent.placeholder
                textView?.textColor = UIColor.placeholderText
            } else {
                textView?.text = finalText
                textView?.textColor = UIColor.label
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
    @Binding var text: String
    var placeholder: String = "点击添加点评..."
    var onSave: (() -> Void)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    
    var body: some View {
        InlineCommentInput(text: $text, placeholder: placeholder, onSave: onSave, onEditingChanged: onEditingChanged)
            .frame(minHeight: 80, maxHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.softBackground)
            )
    }
}

// MARK: - 预览
#Preview {
    InlineCommentInputView(text: .constant(""))
        .padding()
}
