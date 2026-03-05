import SwiftUI
import Combine

// MARK: - 标准化搜索栏
struct StandardizedSearchBar: View {
    @Binding var query: String
    @Binding var isEditing: Bool
    var placeholder: String = "搜索..."
    var onSearch: () -> Void
    var onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            // 输入框
            TextField(placeholder, text: $query)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.darkText)
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in
                    isEditing = focused
                }
            
            // 清除按钮
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.Colors.lighterGray)
                }
                .transition(.opacity)
            }
            
            // 取消按钮（编辑状态时显示）
            if isEditing {
                Button {
                    isFocused = false
                    query = ""
                    onCancel()
                } label: {
                    Text("取消")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.accent)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(hex: "#FFFFFF"))
        )
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

// MARK: - 带联想功能的搜索栏
struct SmartSearchBar<Content: View>: View {
    @Binding var query: String
    @Binding var isEditing: Bool
    var placeholder: String = "搜索..."
    var onSearch: (String) -> Void
    var suggestionContent: () -> Content
    
    @FocusState private var isFocused: Bool
    @State private var debounceTimer: Timer?
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // 搜索栏
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                    
                    TextField(placeholder, text: $query)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .focused($isFocused)
                        .onChange(of: isFocused) { _, focused in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditing = focused
                            }
                        }
                        .onChange(of: query) { _, newValue in
                            debounceTimer?.invalidate()
                            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                                onSearch(newValue)
                            }
                        }
                    
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.Colors.lighterGray)
                        }
                        .transition(.opacity)
                    }
                    
                    if isEditing {
                        Button {
                            isFocused = false
                            query = ""
                        } label: {
                            Text("取消")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.accent)
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(hex: "#FFFFFF"))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                .animation(.easeInOut(duration: 0.2), value: isEditing)
                .zIndex(1)
                
                // 联想列表
                if isEditing {
                    suggestionContent()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(0)
                }
            }
        }
    }
}

// MARK: - 搜索状态管理器
class SearchStateManager: ObservableObject {
    @Published var query: String = ""
    @Published var isEditing: Bool = false
    @Published var suggestions: [SearchSuggestion] = []
    @Published var searchHistory: [String] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let historyKey = "searchHistory"
    
    init() {
        loadHistory()
    }
    
    // 加载搜索历史
    private func loadHistory() {
        if let data = UserDefaults.standard.array(forKey: historyKey) as? [String] {
            searchHistory = data
        }
    }
    
    // 保存搜索历史
    private func saveHistory() {
        UserDefaults.standard.set(searchHistory, forKey: historyKey)
    }
    
    // 添加到历史
    func addToHistory(_ text: String) {
        guard !text.isEmpty else { return }
        
        // 移除重复项
        searchHistory.removeAll { $0 == text }
        
        // 添加到开头
        searchHistory.insert(text, at: 0)
        
        // 限制数量
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        
        saveHistory()
    }
    
    // 清除历史
    func clearHistory() {
        searchHistory.removeAll()
        saveHistory()
    }
    
    // 更新建议
    func updateSuggestions(with items: [SearchSuggestion]) {
        withAnimation(.easeInOut(duration: 0.2)) {
            suggestions = items
        }
    }
    
    // 清空建议
    func clearSuggestions() {
        withAnimation(.easeInOut(duration: 0.2)) {
            suggestions.removeAll()
        }
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 30) {
        // 基础搜索栏
        StandardizedSearchBar(
            query: .constant(""),
            isEditing: .constant(false),
            placeholder: "搜索餐厅...",
            onSearch: {},
            onCancel: {}
        )
        .padding(.horizontal)
        
        // 带联想的搜索栏
        SmartSearchBar(
            query: .constant("hg"),
            isEditing: .constant(true),
            placeholder: "输入拼音或文字...",
            onSearch: { _ in },
            suggestionContent: {
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
                .padding(.top, 8)
            }
        )
        .padding(.horizontal)
        
        Spacer()
    }
    .padding(.vertical)
    .background(AppTheme.Colors.warmGray)
}
