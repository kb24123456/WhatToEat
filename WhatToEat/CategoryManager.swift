import Foundation

/// 品类管理器，统一管理应用中的所有餐厅品类
class CategoryManager {
    // MARK: - 单例模式
    static let shared = CategoryManager()
    private init() {}
    
    // MARK: - 预设品类列表
    private let presetCategories = ["火锅", "川菜", "粤菜", "家常菜", "东北菜", "西餐", "面馆", "烘焙", "早餐", "日料", "饮料", "甜品", "烧烤", "东南亚菜", "其他"]
    
    // MARK: - 获取所有可用品类
    /// 获取所有可用品类，包括预设品类和从餐厅数据中提取的品类
    /// - Parameter restaurants: 餐厅数据数组
    /// - Returns: 去重排序后的品类数组
    func getAllCategories(from restaurants: [Restaurant]) -> [String] {
        // 从餐厅数据中提取所有品类
        let restaurantCategories = restaurants.map { $0.type }
        // 合并预设品类和餐厅品类
        let allCategories = presetCategories + restaurantCategories
        // 去重并排序
        return Array(Set(allCategories)).sorted()
    }
    
    /// 获取预设品类列表
    /// - Returns: 预设品类数组
    func getPresetCategories() -> [String] {
        return presetCategories
    }
}