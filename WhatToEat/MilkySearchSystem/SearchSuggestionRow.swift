import SwiftUI

// MARK: - 搜索建议行（抖音式联想行）
struct SearchSuggestionRow: View {
    let text: String
    let query: String
    var onTap: () -> Void
    var onFill: () -> Void
    
    // 高亮匹配部分
    private var attributedText: AttributedString {
        var attributed = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        
        // 查找匹配范围
        if let range = lowerText.range(of: lowerQuery) {
            let startIndex = attributed.index(attributed.startIndex, offsetByCharacters: range.lowerBound.utf16Offset(in: lowerText))
            let endIndex = attributed.index(startIndex, offsetByCharacters: range.upperBound.utf16Offset(in: lowerText) - range.lowerBound.utf16Offset(in: lowerText))
            
            attributed[startIndex..<endIndex].foregroundColor = AppTheme.Colors.accent
            attributed[startIndex..<endIndex].font = .system(size: 16, weight: .semibold)
        }
        
        return attributed
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧搜索图标
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.mediumGray)
                .frame(width: 20)
            
            // 中间文本（带高亮）
            Text(attributedText)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.darkText)
                .lineLimit(1)
            
            Spacer()
            
            // 右侧填充按钮（arrow.up.backward）
            Button {
                onFill()
            } label: {
                Image(systemName: "arrow.up.backward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
        .background(Color.white)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - 搜索建议数据模型
struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    
    enum SuggestionType {
        case history      // 搜索历史
        case local        // 本地数据匹配
        case popular      // 热门搜索
        case related      // 相关推荐
    }
}

// MARK: - 搜索建议列表
struct SearchSuggestionList: View {
    let suggestions: [SearchSuggestion]
    let query: String
    let onSelect: (SearchSuggestion) -> Void
    let onFill: (SearchSuggestion) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(suggestions) { suggestion in
                    SearchSuggestionRow(
                        text: suggestion.text,
                        query: query,
                        onTap: {
                            onSelect(suggestion)
                        },
                        onFill: {
                            onFill(suggestion)
                        }
                    )
                    
                    // 分隔线（最后一项不显示）
                    if suggestion.id != suggestions.last?.id {
                        Divider()
                            .padding(.leading, 48)
                            .padding(.trailing, 16)
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - 空搜索建议视图（显示历史/热门）
struct EmptySearchSuggestions: View {
    let history: [String]
    let popular: [String]
    let onSelect: (String) -> Void
    let onClearHistory: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 搜索历史
                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("搜索历史")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.darkText)
                            
                            Spacer()
                            
                            Button {
                                onClearHistory()
                            } label: {
                                Text("清除")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.mediumGray)
                            }
                        }
                        
                        FlowLayout(spacing: 10) {
                            ForEach(history, id: \.self) { item in
                                HistoryTag(text: item) {
                                    onSelect(item)
                                }
                            }
                        }
                    }
                }
                
                // 热门搜索
                if !popular.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("热门搜索")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.darkText)
                        
                        FlowLayout(spacing: 10) {
                            ForEach(popular, id: \.self) { item in
                                PopularTag(text: item, rank: popular.firstIndex(of: item) ?? 0) {
                                    onSelect(item)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - 历史标签
private struct HistoryTag: View {
    let text: String
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                Text(text)
                    .font(.system(size: 13))
            }
            .foregroundColor(AppTheme.Colors.mediumGray)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.softBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 热门标签
private struct PopularTag: View {
    let text: String
    let rank: Int
    let onTap: () -> Void
    
    var rankColor: Color {
        switch rank {
        case 0: return Color(hex: "#FF2442")  // 红色
        case 1: return Color(hex: "#FF6B35")  // 橙色
        case 2: return Color(hex: "#FFB800")  // 黄色
        default: return AppTheme.Colors.mediumGray
        }
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 4) {
                if rank < 3 {
                    Text("\(rank + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(rankColor)
                }
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.darkText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.softBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        // 搜索建议行
        SearchSuggestionRow(
            text: "海底捞火锅",
            query: "hg",
            onTap: {},
            onFill: {}
        )
        .padding(.horizontal)
        
        // 搜索建议列表
        SearchSuggestionList(
            suggestions: [
                SearchSuggestion(text: "海底捞火锅", type: .local),
                SearchSuggestion(text: "红馆", type: .local),
                SearchSuggestion(text: "韩国料理", type: .local)
            ],
            query: "hg",
            onSelect: { _ in },
            onFill: { _ in }
        )
        .padding(.horizontal)
        
        // 空搜索建议
        EmptySearchSuggestions(
            history: ["火锅", "烧烤", "日料"],
            popular: ["火锅", "烧烤", "日料", "西餐", "奶茶"],
            onSelect: { _ in },
            onClearHistory: {}
        )
        .padding(.horizontal)
    }
    .padding(.vertical)
    .background(AppTheme.Colors.warmGray)
}
