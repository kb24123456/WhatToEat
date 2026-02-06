import SwiftUI
import Combine
import CoreLocation

// MARK: - 地图类型枚举
enum MapType: String, CaseIterable {
    case amap = "高德"
    case baidu = "百度"
    case apple = "苹果"
    
    var iconName: String {
        return "arrow.turn.up.right"
    }
}

// MARK: - 导航管理器
/// 封装第三方地图导航逻辑，处理 URL 拼接和应用检测
@MainActor
final class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    // MARK: - 提示框状态
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    
    private init() {}
    
    // MARK: - 打开地图导航（路径规划模式）
    /// 根据地图类型打开对应的应用进行路径规划（显示多条路线选择）
    /// - Parameters:
    ///   - type: 地图类型（高德、百度、苹果）
    ///   - restaurant: 目标餐厅
    func openMap(type: MapType, restaurant: Restaurant) {
        let lat = restaurant.latitude
        let lon = restaurant.longitude
        let name = restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        var urlString: String
        var scheme: String
        
        switch type {
        case .apple:
            // 苹果地图路径规划：使用 http://maps.apple.com/?daddr=lat,lon&dirflg=d
            // dirflg=d 表示驾车模式，会显示路线选择界面
            urlString = "http://maps.apple.com/?daddr=\(lat),\(lon)&dirflg=d"
            scheme = "maps"
            
        case .amap:
            // 高德地图路径规划：iosamap://path?sourceApplication=WhatToEat&dlat=lat&dlon=lon&dname=name&dev=0&t=0
            // t=0 表示驾车路径规划（显示路线选择），t=1 表示公交，t=2 表示步行，t=3 表示骑行
            urlString = "iosamap://path?sourceApplication=WhatToEat&dlat=\(lat)&dlon=\(lon)&dname=\(name)&dev=0&t=0"
            scheme = "iosamap"
            
        case .baidu:
            // 百度地图路径规划：baidumap://map/direction?destination=latlng:lat,lon|name:name&mode=driving
            // mode=driving 表示驾车路径规划（显示路线选择）
            urlString = "baidumap://map/direction?destination=latlng:\(lat),\(lon)|name:\(name)&mode=driving"
            scheme = "baidumap"
        }
        
        // 检查应用是否已安装
        guard let url = URL(string: urlString) else {
            showMilkyToast(message: "导航链接无效")
            return
        }
        
        // 苹果地图不需要检查（系统自带）
        if type != .apple {
            guard let schemeURL = URL(string: "\(scheme)://"),
                  UIApplication.shared.canOpenURL(schemeURL) else {
                showMilkyToast(message: "请先安装\(type.rawValue)地图 App")
                return
            }
        }
        
        // 打开地图应用
        UIApplication.shared.open(url) { success in
            if !success {
                self.showMilkyToast(message: "打开\(type.rawValue)地图失败")
            }
        }
    }
    
    // MARK: - 奶脂风格提示框
    /// 显示淡入淡出的奶脂风格提示框
    private func showMilkyToast(message: String) {
        toastMessage = message
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showToast = true
        }
        
        // 2秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showToast = false
            }
        }
    }
}

// MARK: - 奶脂风格提示框视图
struct MilkyToastView: View {
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.darkText)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    // 奶脂风格背景
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                )
                .padding(.bottom, 100)
        }
    }
}

// MARK: - 导航按钮组件
struct NavigationButton: View {
    let type: MapType
    let restaurant: Restaurant
    @StateObject private var manager = NavigationManager.shared
    
    var body: some View {
        Button {
            manager.openMap(type: type, restaurant: restaurant)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.system(size: 11))
                Text(type.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 第三方导航按钮组
struct ThirdPartyNavigationButtons: View {
    let restaurant: Restaurant
    @StateObject private var manager = NavigationManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(MapType.allCases, id: \.self) { type in
                NavigationButton(type: type, restaurant: restaurant)
            }
        }
        .overlay(
            // 奶脂风格提示框
            Group {
                if manager.showToast {
                    MilkyToastView(message: manager.toastMessage)
                }
            }
        )
    }
}

// MARK: - 预览
#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        
        VStack(spacing: 20) {
            Text("导航按钮预览")
                .font(.headline)
            
            // 模拟餐厅
            let mockRestaurant = Restaurant(
                name: "测试餐厅",
                type: "中餐",
                district: "渝中区",
                city: "重庆",
                address: "测试地址",
                latitude: 29.5630,
                longitude: 106.5516
            )
            
            ThirdPartyNavigationButtons(restaurant: mockRestaurant)
        }
    }
}
