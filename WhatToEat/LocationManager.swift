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

// MARK: - 定位缓存模型
struct LocationCache {
    let location: CLLocation
    let timestamp: Date
    let cityName: String?
    
    var isValid: Bool {
        // 缓存有效期：30分钟
        Date().timeIntervalSince(timestamp) < 1800
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - 单例实例
    static let shared = LocationManager()
    
    // MARK: - 位置管理器
    private let locationManager = CLLocationManager()
    private var reverseGeocodingRequest: MKReverseGeocodingRequest?
    
    // MARK: - 缓存系统
    private var locationCache: LocationCache?
    private var isLocating = false
    private var pendingLocationCompletions: [(CLLocation?) -> Void] = []
    
    // MARK: - 发布状态
    @Published var userLocation: CLLocation?
    @Published var currentCity: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // MARK: - 持续定位控制（地图专用）
    private var continuousLocationTimer: Timer?
    private var isContinuousLocating = false
    
    // MARK: - 初始化
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100
        
        // 从本地存储恢复城市名
        currentCity = UserDefaults.standard.string(forKey: "cachedCityName")
        
        // 检查当前权限状态
        authorizationStatus = locationManager.authorizationStatus

        // 启动即复用系统最近定位，避免首屏“智能排序”先乱序后回正
        if let bootstrapLocation = locationManager.location {
            locationCache = LocationCache(
                location: bootstrapLocation,
                timestamp: Date(),
                cityName: currentCity
            )
            userLocation = bootstrapLocation
        }

        // 已有权限时静默刷新，逐步提高位置精度
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            refreshLocationIfNeeded()
        }
    }
    
    // MARK: - 权限管理
    
    /// 请求位置权限
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("位置权限被拒绝或限制")
        case .authorizedWhenInUse, .authorizedAlways:
            // 获得权限后，静默获取一次位置（不强制）
            refreshLocationIfNeeded()
        @unknown default:
            break
        }
    }
    
    // MARK: - 智能定位 API
    
    /// 获取当前位置（带缓存检查）
    func getCurrentLocation(completion: @escaping (CLLocation?) -> Void) {
        // 1. 检查缓存
        if let cache = locationCache, cache.isValid {
            completion(cache.location)
            return
        }
        
        // 2. 检查权限
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            completion(nil)
            return
        }
        
        // 3. 启动单次定位
        performSingleLocationUpdate { location in
            completion(location)
        }
    }
    
    /// 获取当前城市（带缓存检查）
    func getCurrentCity(completion: @escaping (String?) -> Void) {
        // 1. 检查内存缓存
        if let cache = locationCache, cache.isValid, let city = cache.cityName {
            completion(city)
            return
        }
        
        // 2. 检查本地缓存
        if let cachedCity = UserDefaults.standard.string(forKey: "cachedCityName") {
            completion(cachedCity)
            // 后台刷新位置
            refreshLocationIfNeeded()
            return
        }
        
        // 3. 需要重新定位
        getCurrentLocation { [weak self] location in
            guard let location = location else {
                completion(nil)
                return
            }
            
            // 反编码获取城市名
            self?.performGeocoding(for: location) { cityName in
                completion(cityName)
            }
        }
    }
    
    /// 强制刷新位置
    func refreshLocation(completion: @escaping (CLLocation?) -> Void) {
        // 清除缓存
        locationCache = nil
        
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            completion(nil)
            return
        }
        
        performSingleLocationUpdate { location in
            completion(location)
        }
    }

    /// 清理内存与本地定位缓存
    func clearCachedData() {
        locationCache = nil
        currentCity = nil
        UserDefaults.standard.removeObject(forKey: "cachedCityName")
    }
    
    /// 如果需要则刷新位置（静默）
    private func refreshLocationIfNeeded() {
        // 只在缓存无效时刷新
        if let cache = locationCache, cache.isValid {
            return
        }
        
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            return
        }
        
        performSingleLocationUpdate { _ in
            // 静默更新，不处理回调
        }
    }
    
    // MARK: - 持续定位（地图专用）
    
    /// 开始持续定位（地图视图使用）
    func startContinuousLocation() {
        guard !isContinuousLocating else { return }
        
        isContinuousLocating = true
        locationManager.startUpdatingLocation()
        
        // 地图视图持续定位最长60秒
        continuousLocationTimer?.invalidate()
        continuousLocationTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.stopContinuousLocation()
        }
    }
    
    /// 停止持续定位
    func stopContinuousLocation() {
        isContinuousLocating = false
        locationManager.stopUpdatingLocation()
        continuousLocationTimer?.invalidate()
        continuousLocationTimer = nil
    }
    
    // MARK: - 单次定位实现
    private var singleLocationTimer: Timer?
    
    private func performSingleLocationUpdate(completion: @escaping (CLLocation?) -> Void) {
        // 防止重复定位
        guard !isLocating else {
            pendingLocationCompletions.append(completion)
            return
        }
        
        isLocating = true
        pendingLocationCompletions = [completion]
        
        // 启动定位
        locationManager.startUpdatingLocation()
        
        // 设置超时（5秒）
        singleLocationTimer?.invalidate()
        singleLocationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.finishSingleLocationUpdate()
        }
    }
    
    private func finishSingleLocationUpdate() {
        guard isLocating else { return }

        // 停止定位
        if !isContinuousLocating {
            locationManager.stopUpdatingLocation()
        }
        
        // 回调结果
        let result = locationCache?.location
        let completions = pendingLocationCompletions
        pendingLocationCompletions.removeAll()

        for completion in completions {
            completion(result)
        }

        singleLocationTimer?.invalidate()
        singleLocationTimer = nil
        isLocating = false
    }
    
    // MARK: - 地理编码（节流控制）
    
    private var lastGeocodeTime: Date?
    
    private func performGeocoding(for location: CLLocation, completion: @escaping (String?) -> Void) {
        // 节流控制：至少间隔10秒
        if let lastTime = lastGeocodeTime, Date().timeIntervalSince(lastTime) < 10 {
            // 使用缓存的城市名
            completion(locationCache?.cityName)
            return
        }
        
        lastGeocodeTime = Date()

        reverseGeocodingRequest?.cancel()
        guard let request = MKReverseGeocodingRequest(location: location) else {
            completion(nil)
            return
        }

        reverseGeocodingRequest = request
        request.getMapItems(completionHandler: { [weak self] mapItems, _ in
            guard let self else {
                completion(nil)
                return
            }

            self.reverseGeocodingRequest = nil
            let cityName = mapItems?.first?.compatibleCity?.replacingOccurrences(of: "市", with: "")

            // 更新缓存
            if let cache = self.locationCache {
                self.locationCache = LocationCache(
                    location: cache.location,
                    timestamp: cache.timestamp,
                    cityName: cityName
                )
            }

            // 持久化城市名
            if let city = cityName {
                UserDefaults.standard.set(city, forKey: "cachedCityName")
                self.currentCity = city
            }

            completion(cityName)
        })
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // 获得权限后，静默获取一次位置
            refreshLocationIfNeeded()
        case .restricted, .denied:
            print("位置权限被拒绝或限制")
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 更新缓存
        let cache = LocationCache(
            location: location,
            timestamp: Date(),
            cityName: nil
        )
        locationCache = cache
        userLocation = location
        
        // 反编码获取城市名（节流）
        performGeocoding(for: location) { [weak self] cityName in
            if let city = cityName {
                self?.currentCity = city
            }
        }
        
        // 如果是单次定位，完成更新
        if isLocating && !isContinuousLocating {
            finishSingleLocationUpdate()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置更新失败: \(error.localizedDescription)")
        finishSingleLocationUpdate()
    }
    
    // MARK: - 距离计算（带缓存）
    
    func distanceTo(lat: Double, long: Double) -> String {
        // 优先使用缓存
        if let cache = locationCache, cache.isValid {
            return calculateDistance(from: cache.location, to: CLLocation(latitude: lat, longitude: long))
        }
        
        // 无缓存时启动定位
        getCurrentLocation { _ in
            // 定位完成后会自动更新 UI（通过 @Published）
        }
        
        return "定位中..."
    }
    
    private func calculateDistance(from: CLLocation, to: CLLocation) -> String {
        let distance = from.distance(from: to)
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    // MARK: - 路线规划
    
    func fetchRoute(to lat: Double, long: Double) async -> (distance: String, time: String)? {
        // 优先使用缓存位置
        let location: CLLocation?
        if let cache = locationCache, cache.isValid {
            location = cache.location
        } else {
            // 需要等待定位完成
            location = await withCheckedContinuation { continuation in
                getCurrentLocation { loc in
                    continuation.resume(returning: loc)
                }
            }
        }
        
        guard let userLocation = location else {
            return nil
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(location: userLocation, address: nil)
        request.destination = MKMapItem(
            location: CLLocation(latitude: lat, longitude: long),
            address: nil
        )
        request.transportType = .automobile
        
        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else { return nil }
            
            let distanceText = route.distance < 1000
                ? String(format: "%.0f m", route.distance)
                : String(format: "%.1f km", route.distance / 1000)
            
            let timeText = route.expectedTravelTime < 60
                ? String(format: "%.0f 秒", route.expectedTravelTime)
                : String(format: "%.0f 分钟", route.expectedTravelTime / 60)
            
            return (distance: distanceText, time: timeText)
        } catch {
            print("获取路线失败: \(error.localizedDescription)")
            return nil
        }
    }
}
