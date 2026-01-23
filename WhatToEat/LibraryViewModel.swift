//
//  LibraryViewModel.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/23.
//

import Foundation
import CoreLocation
import Combine

/// 餐厅列表视图模型，处理餐厅列表的业务逻辑
class LibraryViewModel: ObservableObject {
    // MARK: - 常量定义
    
    /// 城市存储键
    private let kSavedCityKey = "UserSelectedCity"
    
    // MARK: - 1. 输入参数
    
    /// 原始餐厅数据数组（来自SwiftData查询）
    var restaurants: [Restaurant] {
        didSet {
            updateProcessedRestaurants()
        }
    }
    
    /// 用户当前位置
    var userLocation: CLLocation? {
        didSet {
            updateProcessedRestaurants()
        }
    }
    
    // MARK: - 辅助方法
    
    /// 更新处理后的餐厅数据
    private func updateProcessedRestaurants() {
        self.processedRestaurants = processRestaurants()
    }
    
    // MARK: - 2. 状态管理
    
    /// 当前选中的城市（带有记忆功能）
    @Published var selectedCity: String {
        didSet {
            // 每当城市变化时，保存到UserDefaults
            UserDefaults.standard.set(selectedCity, forKey: kSavedCityKey)
            updateProcessedRestaurants()
        }
    }
    
    /// 当前选中的行政区（可选，为空代表全区）
    @Published var selectedDistrict: String? {
        didSet {
            updateProcessedRestaurants()
        }
    }
    
    /// 当前选中的餐厅类型（可选，为空代表全分类）
    @Published var selectedType: String? {
        didSet {
            updateProcessedRestaurants()
        }
    }
    
    /// 排序选项
    @Published var sortOption: SortOption = .smart {
        didSet {
            updateProcessedRestaurants()
        }
    }
    
    /// 排序选项枚举
    enum SortOption: String, CaseIterable {
        case smart = "智能排序"
        case distance = "距离最近"
        case rating = "评分最高"
        case createdAt = "最近添加"
        
        /// 枚举值的显示名称
        var displayName: String {
            return self.rawValue
        }
    }
    
    // MARK: - 3. 输出结果
    
    /// 处理后的餐厅显示项数组
    @Published var processedRestaurants: [RestaurantDisplayItem] = []
    
    // MARK: - 初始化方法
    
    /// 初始化ViewModel
    /// - Parameters:
    ///   - restaurants: 原始餐厅数据数组
    ///   - userLocation: 用户当前位置
    init(restaurants: [Restaurant], userLocation: CLLocation?) {
        self.restaurants = restaurants
        self.userLocation = userLocation
        
        // 从UserDefaults加载保存的城市，默认使用"上海"
        if let savedCity = UserDefaults.standard.string(forKey: kSavedCityKey) {
            self.selectedCity = savedCity
        } else {
            self.selectedCity = "上海"
        }
        
        // 初始处理餐厅数据
        self.processedRestaurants = processRestaurants()
    }
    
    // MARK: - 4. 核心处理方法
    
    /// 处理餐厅数据，包括计算距离、过滤和排序
    /// - Returns: 处理后的餐厅显示项数组
    func processRestaurants() -> [RestaurantDisplayItem] {
        // 1. 计算距离并创建显示项
        let displayItems = restaurants.map { restaurant -> RestaurantDisplayItem in
            // 计算距离（米）
            let distance = calculateDistance(from: userLocation, to: restaurant)
            // 创建显示项
            return RestaurantDisplayItem(restaurant: restaurant, distance: distance)
        }
        
        // 2. 过滤餐厅
        let filteredItems = displayItems.filter { item in
            let restaurant = item.restaurant
            
            // 按城市过滤
            guard restaurant.city == selectedCity else {
                return false
            }
            
            // 按行政区过滤（可选）
            if let district = selectedDistrict {
                guard restaurant.district == district else {
                    return false
                }
            }
            
            // 按餐厅类型过滤（可选）
            if let type = selectedType {
                guard restaurant.type == type else {
                    return false
                }
            }
            
            return true
        }
        
        // 3. 排序餐厅
        let sortedItems = sortDisplayItems(filteredItems, by: sortOption)
        
        return sortedItems
    }
    
    // MARK: - 5. 辅助方法
    
    /// 计算两个位置之间的直线距离
    /// - Parameters:
    ///   - from: 起点位置（可选）
    ///   - to: 餐厅对象
    /// - Returns: 距离（米），如果起点为空则返回0
    private func calculateDistance(from: CLLocation?, to restaurant: Restaurant) -> Double {
        guard let fromLocation = from else {
            return 0
        }
        
        let toLocation = CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// 计算智能排序得分
    /// - Parameters:
    ///   - restaurant: 餐厅对象
    ///   - distance: 距离（米）
    /// - Returns: 智能排序得分
    private func calculateSmartScore(restaurant: Restaurant, distance: Double) -> Double {
        var score: Double = 0.0
        
        // 因子 A：评分权重 (40%)
        let ratingScore = Double(restaurant.rating) * 20.0
        score += ratingScore * 0.4
        
        // 因子 B：距离权重 (40%)
        // 检查是否有定位权限且userLocation不为空
        if userLocation != nil {
            let distanceInKilometers = distance / 1000 // 转换为公里
            let distanceScore = max(0.0, 100.0 - (distanceInKilometers * 10))
            score += distanceScore * 0.4
        }
        
        // 因子 C：新鲜度权重 (20%)
        // 检查是否是最近7天内创建的记录
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        if restaurant.createdAt >= sevenDaysAgo {
            score += 20.0 // 最近7天内创建，加20分
        }
        
        return score
    }
    
    /// 对餐厅显示项进行排序
    /// - Parameters:
    ///   - items: 餐厅显示项数组
    ///   - option: 排序选项
    /// - Returns: 排序后的餐厅显示项数组
    private func sortDisplayItems(_ items: [RestaurantDisplayItem], by option: SortOption) -> [RestaurantDisplayItem] {
        switch option {
        case .smart:
            // 智能排序：按加权得分降序排列
            return items.sorted { item1, item2 in
                let score1 = calculateSmartScore(restaurant: item1.restaurant, distance: item1.distance)
                let score2 = calculateSmartScore(restaurant: item2.restaurant, distance: item2.distance)
                return score1 > score2
            }
        case .distance:
            // 按距离升序排列（距离最近）
            return items.sorted { $0.distance < $1.distance }
        case .rating:
            // 按评分降序排列（评分最高）
            return items.sorted { $0.restaurant.rating > $1.restaurant.rating }
        case .createdAt:
            // 按创建时间倒序排列（最近添加的在前）
            return items.sorted { $0.restaurant.createdAt > $1.restaurant.createdAt }
        }
    }
    
    /// 从餐厅数据中提取所有去重的餐厅类型
    /// - Parameter restaurants: 餐厅数据数组
    /// - Returns: 去重后的餐厅类型数组
    func getAvailableTypes(from restaurants: [Restaurant]) -> [String] {
        // 使用CategoryManager获取所有可用品类
        return CategoryManager.shared.getAllCategories(from: restaurants)
    }
}

// MARK: - 餐厅显示项结构体

/// 餐厅显示项，包含餐厅对象、距离和格式化的距离字符串
struct RestaurantDisplayItem: Identifiable {
    /// 餐厅对象
    let restaurant: Restaurant
    
    /// 距离（米）
    let distance: Double
    
    /// 格式化好的距离字符串（如"1.5km"）
    var formattedDistance: String {
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    /// 唯一标识符（使用餐厅的id）
    var id: UUID {
        return restaurant.id
    }
}

// MARK: - 数组扩展

/// 数组扩展，用于去重
extension Array where Element: Equatable {
    /// 去重
    /// - Returns: 去重后的数组
    func unique() -> [Element] {
        var result: [Element] = []
        for item in self {
            if !result.contains(item) {
                result.append(item)
            }
        }
        return result
    }
}
