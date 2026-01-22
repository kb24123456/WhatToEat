import SwiftUI

struct ImportDataView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 标题和说明
                VStack(spacing: 8) {
                    Text("导入数据")
                        .font(AppTheme.Fonts.title2)
                        .bold()
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("从其他应用导入餐厅数据")
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // 导入按钮
                Button {
                    // 这里可以添加导入逻辑
                    print("开始导入数据")
                    dismiss()
                } label: {
                    Text("导入数据")
                        .font(AppTheme.Fonts.body)
                        .bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.accent)
                        .cornerRadius(AppTheme.Radius.base)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                
                Spacer()
            }
            .padding(.top, 24)
            .padding(.bottom, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(AppTheme.Fonts.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                }
            }
        }
    }
}

#Preview {
    ImportDataView()
}