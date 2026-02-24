import SwiftUI

// MARK: - 简化版城市选择视图
// 支持全国333个地级市，带搜索功能
struct SimpleCitySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCity: String
    
    @State private var searchText = ""
    @StateObject private var locationManager = LocationManager.shared
    
    // 过滤后的城市列表
    var filteredCities: [String] {
        if searchText.isEmpty {
            // 热门城市 + 其他城市
            return CityData.getCities()
        } else {
            // 搜索结果
            return CityData.searchCities(query: searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // GPS定位
                Section {
                    Button(action: {
                        locationManager.getCurrentCity { city in
                            if let city = city {
                                selectedCity = city
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(AppTheme.Colors.accent)
                            Text("定位当前城市")
                                .foregroundColor(AppTheme.Colors.darkText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.mediumGray)
                        }
                    }
                }
                
                // 城市列表
                Section {
                    ForEach(filteredCities, id: \.self) { city in
                        Button(action: {
                            selectedCity = city
                            dismiss()
                        }) {
                            HStack {
                                Text(city)
                                    .foregroundColor(AppTheme.Colors.darkText)
                                Spacer()
                                if city == selectedCity {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                            }
                        }
                    }
                } header: {
                    if searchText.isEmpty {
                        Text("热门城市")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.mediumGray)
                    } else {
                        Text("搜索结果 (\(filteredCities.count))")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.mediumGray)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("选择城市")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索城市（支持拼音首字母）"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            }
        }
    }
}

// MARK: - 预览
#Preview {
    SimpleCitySelectionView(selectedCity: .constant("北京市"))
}
