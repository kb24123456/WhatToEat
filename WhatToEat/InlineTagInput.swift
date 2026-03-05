import SwiftUI
import Combine

// MARK: - 内联标签输入框
/// 实现小红书风格的标签输入体验
/// 核心逻辑：
/// 1. 页面显示"新标签..."placeholder（使用 UITextView，与 InlineCommentInput 统一）
/// 2. 点击后弹出键盘，inputAccessoryView 作为输入区域
/// 3. 编辑内容只在 inputAccessoryView 中，不显示在页面上
/// 4. 点击"完成"才添加标签；点击"返回"不添加，但保留草稿供下次编辑
struct InlineTagInput: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "新标签..."
    var onSubmit: (() -> Void)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.backgroundColor = UIColor.clear
        textView.layer.cornerRadius = 16
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        textView.isScrollEnabled = false
        textView.isEditable = false  // 禁用编辑，使用点击手势
        textView.isSelectable = false
        textView.isUserInteractionEnabled = true  // 确保可以接收交互
        
        // 保存引用
        context.coordinator.textView = textView
        
        // 设置初始显示
        updatePageDisplay(textView: textView)
        
        // 创建 inputAccessoryView
        let accessoryView = createInputAccessoryView(context: context)
        textView.inputAccessoryView = accessoryView
        
        // 添加点击手势 - 使用更可靠的方式
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.cancelsTouchesInView = false
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
        // 页面始终显示 placeholder，不显示实际内容
        textView.text = placeholder
        textView.textColor = UIColor.placeholderText
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createInputAccessoryView(context: Context) -> UIView {
        // 创建容器视图 - 全透明背景
        let container = UIView(frame: CGRect(x: 0, y: 0, width: ScreenMetrics.bounds.width, height: 60))
        container.backgroundColor = UIColor.clear
        container.clipsToBounds = true
        
        // 创建输入框容器 - 胶囊样式
        let inputContainer = UIView()
        inputContainer.backgroundColor = UIColor.systemBackground
        inputContainer.layer.cornerRadius = 20
        inputContainer.layer.shadowColor = UIColor.black.cgColor
        inputContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        inputContainer.layer.shadowRadius = 6
        inputContainer.layer.shadowOpacity = 0.1
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(inputContainer)
        
        // 创建单行输入框（UITextField）
        let inputTextField = UITextField()
        inputTextField.delegate = context.coordinator
        inputTextField.font = UIFont.systemFont(ofSize: 16)
        inputTextField.textColor = UIColor.label
        inputTextField.backgroundColor = UIColor.clear
        inputTextField.placeholder = placeholder
        inputTextField.returnKeyType = .done
        inputTextField.clearButtonMode = .whileEditing
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputTextField)
        
        // 设置约束
        NSLayoutConstraint.activate([
            // 输入容器 - 宽度为屏幕1/3，居中
            inputContainer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            inputContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            inputContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            inputContainer.widthAnchor.constraint(equalToConstant: ScreenMetrics.bounds.width / 3),
            inputContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // 输入框
            inputTextField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            inputTextField.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            inputTextField.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            inputTextField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor)
        ])
        
        // 保存引用
        context.coordinator.inputTextField = inputTextField
        context.coordinator.inputContainer = inputContainer
        context.coordinator.accessoryContainer = container
        
        return container
    }
    
    class Coordinator: NSObject, UITextViewDelegate, UITextFieldDelegate {
        var parent: InlineTagInput
        weak var inputTextField: UITextField?  // inputAccessoryView 中的输入框
        weak var textView: UITextView?         // 页面上的文本视图
        weak var inputContainer: UIView?       // 输入框容器
        weak var accessoryContainer: UIView?   // 整个 accessoryView 容器
        
        // 草稿文本（只在 inputAccessoryView 中编辑）
        private var draftText: String = ""
        
        init(_ parent: InlineTagInput) {
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
            parent.onEditingChanged?(true)
        }
        
        @objc func keyboardWillHide(_ notification: Notification) {
            inputTextField?.resignFirstResponder()
            textView?.resignFirstResponder()
            parent.onEditingChanged?(false)
        }
        
        // MARK: - 点击处理
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // 确保 inputAccessoryView 已创建
            guard let textView = textView else {
                return
            }
            
            // 让 textView 成为第一响应者以显示 inputAccessoryView
            // 然后立即让 inputTextField 成为第一响应者
            textView.becomeFirstResponder()
            
            // 延迟一小段时间后让 inputTextField 获取焦点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.inputTextField?.becomeFirstResponder()
            }
        }
        
        // MARK: - UITextFieldDelegate (inputAccessoryView 中的输入框)
        func textFieldDidBeginEditing(_ textField: UITextField) {
            // 恢复草稿文本
            textField.text = draftText
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            // 只更新草稿，不更新外部 text
            draftText = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            handleSubmitAction()
            return false
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            // 编辑结束，保留草稿但不保存到外部
        }
        
        // MARK: - 处理提交操作
        private func handleSubmitAction() {
            guard let inputTextField = inputTextField else { return }
            
            // 获取标签文本
            let tagText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 保存到外部 text（触发添加标签）
            if !tagText.isEmpty {
                parent.text = tagText
                parent.onSubmit?()
            }
            
            // 清空草稿和输入框
            draftText = ""
            inputTextField.text = ""
            parent.text = ""
            
            // 退出键盘
            inputTextField.resignFirstResponder()
            textView?.resignFirstResponder()
        }
    }
}

// MARK: - 标签输入包装视图
struct InlineTagInputView: View {
    @Binding var text: String
    var placeholder: String = "新标签..."
    var onSubmit: (() -> Void)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    
    var body: some View {
        InlineTagInput(
            text: $text,
            placeholder: placeholder,
            onSubmit: onSubmit,
            onEditingChanged: onEditingChanged
        )
        .frame(width: 100, height: 32)
    }
}

// MARK: - 预览
#Preview {
    InlineTagInputView(text: .constant(""))
        .padding()
}
