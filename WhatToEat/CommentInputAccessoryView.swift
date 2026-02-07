import SwiftUI
import Combine

// MARK: - 评论输入框作为键盘附件视图
/// 实现小红书风格的评论输入体验
/// 输入框作为键盘的 inputAccessoryView，与键盘同进同出
struct CommentInputAccessoryView: View {
    @Binding var text: String
    var placeholder: String = "添加你的点评..."
    var onSend: (() -> Void)? = nil
    
    @State private var isFocused: Bool = false
    @FocusState private var textFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Divider()
                .background(Color.gray.opacity(0.2))
            
            // 输入区域
            HStack(spacing: 12) {
                // 输入框
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 40, maxHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .focused($textFieldFocused)
                    .onAppear {
                        // 自动聚焦
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            textFieldFocused = true
                        }
                    }
                
                // 发送按钮
                if !text.isEmpty {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        onSend?()
                    } label: {
                        Text("发送")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.accent)
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - SwiftUI 包装器（用于 UIViewRepresentable）
struct CommentInputField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "添加你的点评..."
    var onSend: (() -> Void)? = nil
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textColor = UIColor.label
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 20
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        textView.isScrollEnabled = true
        textView.returnKeyType = .send
        textView.text = placeholder
        textView.textColor = UIColor.placeholderText
        
        // 创建 inputAccessoryView
        let accessoryView = UIHostingController(
            rootView: CommentInputAccessoryView(
                text: $text,
                placeholder: placeholder,
                onSend: onSend
            )
        ).view!
        accessoryView.frame.size.height = 60
        textView.inputAccessoryView = accessoryView
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text && uiView.text != placeholder {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CommentInputField
        
        init(_ parent: CommentInputField) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.placeholderText
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onSend?()
                return false
            }
            return true
        }
    }
}

// MARK: - 评论按钮（触发输入）
struct CommentTriggerButton: View {
    let review: String
    let placeholder: String
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // 指示条
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AppTheme.Colors.babyBlue)
                    .frame(width: 3, height: 12)
                
                Text(review.isEmpty ? placeholder : review)
                    .font(.body)
                    .italic()
                    .foregroundColor(review.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.textPrimary)
                    .lineSpacing(5)
                    .padding(.vertical, 14)
                
                Spacer()
            }
            .padding(.horizontal, AppTheme.Card.paddingHorizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.softBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - 预览
#Preview {
    VStack {
        CommentInputAccessoryView(
            text: .constant(""),
            onSend: { print("发送") }
        )
        
        CommentTriggerButton(
            review: "",
            placeholder: "点击添加点评...",
            onTap: { print("触发输入") }
        )
        .padding()
    }
}
