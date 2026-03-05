import SwiftUI
import MapKit
import CoreLocation
import UIKit

// MARK: - 餐厅选择详情视图（展示距离、时间和导航）
struct RestaurantSelectionDetailView: View {
    let restaurant: Restaurant
    let locationManager: LocationManager
    let onClose: () -> Void
    let onContinue: () -> Void
    
    @State private var drivingDistance: String = "--"
    @State private var drivingTime: String = "--"
    @State private var isCalculatingRoute = true
    
    var body: some View {
        ZStack {
            // 背景
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部关闭按钮
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(hex: "#FFFFFF").opacity(0.5))
                            )
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 餐厅名称
                        Text(restaurant.name)
                            .font(.custom("ResourceHanRoundedCN-Bold", size: 28))
                            .foregroundColor(AppTheme.Colors.darkText)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                        
                        // 餐厅信息卡片
                        restaurantInfoCard
                        
                        // 距离和时间信息
                        distanceTimeCard
                        
                        // 导航按钮
                        navigationButton
                            .padding(.top, 20)
                        
                        // 继续匹配按钮
                        continueButton
                            .padding(.top, 12)
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            calculateRoute()
        }
    }
    
    // MARK: - 餐厅信息卡片
    private var restaurantInfoCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(AppTheme.Colors.accent)
                Text(restaurant.district)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.darkText)
                Spacer()
            }
            
            if !restaurant.address.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .font(.caption)
                    Text(restaurant.address)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .lineLimit(2)
                    Spacer()
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundColor(AppTheme.Colors.iconOrange)
                Text(restaurant.type)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.darkText)
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#FFFFFF").opacity(0.5))
        )
    }
    
    // MARK: - 距离和时间卡片
    private var distanceTimeCard: some View {
        HStack(spacing: 16) {
            // 距离
            VStack(spacing: 8) {
                Image(systemName: "car.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.accent)
                
                if isCalculatingRoute {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(drivingDistance)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
                
                Text("驾车距离")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#FFFFFF").opacity(0.5))
            )
            
            // 时间
            VStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.iconOrange)
                
                if isCalculatingRoute {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(drivingTime)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
                
                Text("预计时间")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#FFFFFF").opacity(0.5))
            )
        }
    }
    
    // MARK: - 导航按钮（弹出地图选择）
    private var navigationButton: some View {
        Menu {
            Button {
                // 触感反馈 + NavigationManager 导航
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                NavigationManager.shared.openMap(type: .apple, restaurant: restaurant)
            } label: {
                Label("苹果地图", systemImage: "map.fill")
            }
            
            Button {
                // 触感反馈 + NavigationManager 导航
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                NavigationManager.shared.openMap(type: .amap, restaurant: restaurant)
            } label: {
                Label("高德地图", systemImage: "car.fill")
            }
            
            Button {
                // 触感反馈 + NavigationManager 导航
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                NavigationManager.shared.openMap(type: .baidu, restaurant: restaurant)
            } label: {
                Label("百度地图", systemImage: "car.fill")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("开始导航")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(AppTheme.Colors.primaryButtonText)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.primaryButtonBackground)
            )
        }
    }
    
    // MARK: - 继续匹配按钮
    private var continueButton: some View {
        Button {
            onContinue()
        } label: {
            Text("继续匹配")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.mediumGray)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
    }
    
    // MARK: - 计算路线
    private func calculateRoute() {
        guard let userLocation = locationManager.userLocation else {
            isCalculatingRoute = false
            drivingDistance = "无法获取位置"
            drivingTime = "--"
            return
        }
        
        let restaurantLocation = CLLocation(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        
        // 计算直线距离
        let distance = userLocation.distance(from: restaurantLocation)
        
        // 使用 MKDirections 获取实际驾车路线
        let source = MKMapItem(location: userLocation, address: nil)
        let destination = MKMapItem(location: restaurantLocation, address: nil)
        
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            DispatchQueue.main.async {
                isCalculatingRoute = false
                
                if let route = response?.routes.first {
                    // 使用实际路线距离和时间
                    let distanceInKm = route.distance / 1000
                    drivingDistance = String(format: "%.1f公里", distanceInKm)
                    
                    let timeInMinutes = Int(route.expectedTravelTime / 60)
                    if timeInMinutes < 60 {
                        drivingTime = "\(timeInMinutes)分钟"
                    } else {
                        let hours = timeInMinutes / 60
                        let minutes = timeInMinutes % 60
                        if minutes == 0 {
                            drivingTime = "\(hours)小时"
                        } else {
                            drivingTime = "\(hours)小时\(minutes)分"
                        }
                    }
                } else {
                    // 如果无法获取路线，使用直线距离估算
                    let distanceInKm = distance / 1000
                    drivingDistance = String(format: "%.1f公里", distanceInKm)
                    // 估算时间（假设平均车速 30km/h）
                    let estimatedMinutes = Int((distance / 1000) / 30 * 60)
                    drivingTime = "约\(estimatedMinutes)分钟"
                }
            }
        }
    }
}

// MARK: - 预览
#Preview {
    RestaurantSelectionDetailView(
        restaurant: Restaurant(
            name: "测试餐厅",
            type: "火锅",
            district: "渝中区",
            city: "重庆",
            rating: 4.5,
            address: "测试地址123号",
            latitude: 29.5630,
            longitude: 106.5516,
            review: "",
            tags: [],
            averagePrice: 100
        ),
        locationManager: LocationManager(),
        onClose: {},
        onContinue: {}
    )
}
