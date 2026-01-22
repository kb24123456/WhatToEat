import SwiftUI

// ✅ 规范化的标签组件
struct StandardTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// ✅ 规范化的主操作按钮 (比如保存、完成)
// ✅ 规范化的主操作按钮 (修正版)
struct PrimaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        // 使用这种写法，编译器绝对不会认错
        Button {
            action() // 这里执行传入的动作
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.Colors.accent)
            .cornerRadius(AppTheme.Radius.base)
            .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain) // 确保不会被系统默认蓝色干扰
    }
}
