import SwiftUI
import MapKit

struct LocationPicker: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var errorMessage: String? // 用来显示报错给用户看
    
    var onSelect: (MKMapItem) -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                // 1. 搜索区域：输入框 + 按钮
                HStack {
                    TextField("输入地名 (如: 重庆)", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled() // 关闭自动纠错，避免干扰
                        .submitLabel(.search)  // 键盘右下角显示"搜索"
                        .onSubmit {
                            // 允许按回车键搜索
                            startSearch()
                        }
                    
                    Button(action: {
                        // 点击按钮强制搜索
                        startSearch()
                    }) {
                        Text("搜索")
                            .bold()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(searchText.isEmpty) // 没字的时候不能点
                }
                .padding()
                
                // 2. 状态显示区
                if isSearching {
                    ProgressView("正在连接地图服务...")
                        .padding()
                } else if let error = errorMessage {
                    // 如果有错误，直接显示在红字里
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // 3. 结果列表
                List(searchResults, id: \.self) { item in
                    Button {
                        onSelect(item)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.name ?? "未知地点")
                                .font(.headline)
                            Text(getAddressString(from: item.placemark))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - 搜索逻辑
    private func startSearch() {
        // 收起键盘
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        print("🔍 开始搜索: \(searchText)") // 埋点 1
        isSearching = true
        errorMessage = nil // 清除旧错误
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    // 如果出错，把错误信息显示在屏幕上，而不仅仅是控制台
                    print("❌ 搜索失败: \(error.localizedDescription)")
                    self.errorMessage = "搜索失败: \(error.localizedDescription)"
                    return
                }
                
                if let items = response?.mapItems, !items.isEmpty {
                    print("✅ 找到 \(items.count) 个结果") // 埋点 2
                    self.searchResults = items
                } else {
                    print("⚠️ 没找到结果")
                    self.errorMessage = "未找到相关地点，请尝试输入更详细的地址（如：城市+店名）"
                }
            }
        }
    }
    
    private func getAddressString(from placemark: MKPlacemark) -> String {
        let city = placemark.locality ?? ""
        let street = placemark.thoroughfare ?? ""
        let subStreet = placemark.subThoroughfare ?? ""
        let full = "\(city) \(street) \(subStreet)"
        return full.isEmpty ? "暂无详细地址" : full
    }
}
