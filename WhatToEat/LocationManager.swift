//
//  LocationManager.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/17.
//

import Foundation
import CoreLocation
import Combine
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // 单例实例
    static let shared = LocationManager()
    
    // 位置管理器
    private let locationManager = CLLocationManager()
    
    // 发布用户当前位置
    @Published var userLocation: CLLocation?
    
    // 发布当前位置对应的城市名
    @Published var currentCity: String?
    
    // 地理编码器
    private let geocoder = CLGeocoder()
    
    // 初始化方法
    override init() {
        super.init()
        
        // 配置位置管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // 精度设置为百米级，为了省电
        locationManager.distanceFilter = 100 // 位置变化超过100米时更新
        
        // 请求位置权限
        requestLocationPermission()
    }
    
    // 请求位置权限
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // 用户尚未决定，请求权限
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            // 权限被拒绝或限制
            print("位置权限被拒绝或限制")
        case .authorizedWhenInUse, .authorizedAlways:
            // 已获得权限，开始更新位置
            startUpdatingLocation()
        @unknown default:
            print("未知的权限状态")
        }
    }
    
    // 开始更新位置
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    // 停止更新位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // 计算直线距离
    func distanceTo(lat: Double, long: Double) -> String {
        // 检查用户位置是否可用
        guard let userLocation = userLocation else {
            return "定位中..."
        }
        
        // 创建目标位置
        let targetLocation = CLLocation(latitude: lat, longitude: long)
        
        // 计算距离（米）
        let distance = userLocation.distance(from: targetLocation)
        
        // 格式化距离显示
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    // 获取真实驾车距离和时间
    func fetchRoute(to lat: Double, long: Double) async -> (distance: String, time: String)? {
        // 全面安全检查
        guard let userLocation = userLocation, 
              lat != 0.0, 
              long != 0.0, 
              CLLocationCoordinate2DIsValid(userLocation.coordinate),
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: long)) else {
            print("无效的位置参数")
            return nil
        }
        
        // 使用兼容的API创建MKMapItem
        let sourcePlacemark = MKPlacemark(coordinate: userLocation.coordinate)
        let destinationPlacemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: long))
        
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        // 创建路线请求
        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destinationItem
        request.transportType = .automobile // 使用驾车方式
        
        do {
            // 计算路线，添加超时保护
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            
            // 获取第一条路线
            guard let route = response.routes.first else {
                print("未找到路线")
                return nil
            }
            
            // 格式化距离
            let distance = route.distance
            let distanceText: String
            if distance < 1000 {
                distanceText = String(format: "%.0f m", distance)
            } else {
                distanceText = String(format: "%.1f km", distance / 1000)
            }
            
            // 格式化时间
            let time = route.expectedTravelTime
            let timeText: String
            if time < 60 {
                timeText = String(format: "%.0f 秒", time)
            } else {
                timeText = String(format: "%.0f 分钟", time / 60)
            }
            
            return (distance: distanceText, time: timeText)
        } catch {
            print("获取路线失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    // 位置权限变化时调用
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // 权限已获得，开始更新位置
            startUpdatingLocation()
        case .restricted, .denied:
            // 权限被拒绝或限制
            print("位置权限被拒绝或限制")
        default:
            break
        }
    }
    
    // 位置更新时调用
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            userLocation = location
            // 获取城市名称
            getCityName(from: location)
        }
    }
    
    // 根据位置获取城市名称
    private func getCityName(from location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self, let placemark = placemarks?.first else {
                return
            }
            
            if let city = placemark.locality {
                // 去除城市名称中的“市”字（如“上海市”→“上海”）
                let cityName = city.replacingOccurrences(of: "市", with: "")
                self.currentCity = cityName
            }
        }
    }
    
    // 位置更新失败时调用
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置更新失败: \(error.localizedDescription)")
    }
}
