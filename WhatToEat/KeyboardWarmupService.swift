import UIKit

/// 预热系统输入会话，降低首次激活键盘时的卡顿感。
final class KeyboardWarmupService {
    static let shared = KeyboardWarmupService()

    private var hasWarmedUp = false

    private init() {}

    func warmUpIfNeeded() {
        guard !hasWarmedUp else { return }
        hasWarmedUp = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.performWarmUp()
        }
    }

    private func performWarmUp() {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            return
        }

        let textField = UITextField(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
        textField.alpha = 0.01
        textField.autocorrectionType = .default
        textField.spellCheckingType = .default
        textField.keyboardType = .default
        textField.returnKeyType = .done

        keyWindow.addSubview(textField)
        textField.becomeFirstResponder()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            textField.resignFirstResponder()
            textField.removeFromSuperview()
        }
    }
}

