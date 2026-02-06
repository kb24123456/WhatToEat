import SwiftUI

/// 高性能输入组件 - 解决键盘调起时的性能瓶颈
/// 特点：
/// 1. 内部管理焦点状态，避免全局重绘
/// 2. 异步触发高亮动画（延迟 0.3s），错位键盘弹出
/// 3. 使用 compositingGroup 光栅化，减少渲染压力
/// 4. 极细描边替代复杂阴影
struct MilkyInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    // 内部管理焦点状态，隔离重绘
    @FocusState private var isFocused: Bool
    
    // 异步高亮状态（延迟触发）
    @State private var showHighlight = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.mediumGray)
                .tracking(0.5)
            
            // 输入框
            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.bottom, 4)
                .overlay(
                    // 底线：仅改变线条，不改变布局大小
                    Rectangle()
                        .fill(showHighlight ? AppTheme.Colors.babyBlue : Color.gray.opacity(0.2))
                        .frame(height: showHighlight ? 1.5 : 0.5),
                    alignment: .bottom
                )
                .focused($isFocused)
        }
        // 关键：将该组件光栅化，减少渲染压力
        .compositingGroup()
        // 监听焦点变化，异步触发高亮
        .onChange(of: isFocused) { _, newValue in
            if newValue {
                // 键盘先滑出，等键盘稳住了，底线再变蓝加粗
                withAnimation(.easeOut(duration: 0.2).delay(0.3)) {
                    showHighlight = true
                }
            } else {
                // 失焦时立即恢复
                withAnimation(.easeOut(duration: 0.15)) {
                    showHighlight = false
                }
            }
        }
    }
}

/// 高性能多行文本输入组件
struct MilkyTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    // 内部管理焦点状态
    @FocusState private var isFocused: Bool
    
    // 异步高亮状态
    @State private var showHighlight = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.mediumGray)
                .tracking(0.5)
            
            // 多行文本框
            ZStack(alignment: .topLeading) {
                // 占位符
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundColor(Color.gray.opacity(0.4))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                
                // 文本编辑器
                TextEditor(text: $text)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.darkText)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .frame(minHeight: 80)
            }
            .padding(.bottom, 4)
            .overlay(
                // 底线
                Rectangle()
                    .fill(showHighlight ? AppTheme.Colors.babyBlue : Color.gray.opacity(0.2))
                    .frame(height: showHighlight ? 1.5 : 0.5),
                alignment: .bottom
            )
        }
        // 光栅化
        .compositingGroup()
        // 异步高亮
        .onChange(of: isFocused) { _, newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.2).delay(0.3)) {
                    showHighlight = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    showHighlight = false
                }
            }
        }
    }
}

/// 高性能输入框变体：带图标
struct MilkyInputFieldWithIcon: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    
    @FocusState private var isFocused: Bool
    @State private var showHighlight = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.mediumGray)
                .tracking(0.5)
            
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(showHighlight ? AppTheme.Colors.babyBlue : Color.gray.opacity(0.4))
                
                TextField(placeholder, text: $text)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.darkText)
            }
            .padding(.bottom, 4)
            .overlay(
                Rectangle()
                    .fill(showHighlight ? AppTheme.Colors.babyBlue : Color.gray.opacity(0.2))
                    .frame(height: showHighlight ? 1.5 : 0.5),
                alignment: .bottom
            )
            .focused($isFocused)
        }
        .compositingGroup()
        .onChange(of: isFocused) { _, newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.2).delay(0.3)) {
                    showHighlight = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    showHighlight = false
                }
            }
        }
    }
}
