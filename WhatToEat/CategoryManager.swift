import Foundation

/// 品类管理器，统一管理应用中的所有餐厅品类
class CategoryManager {
    // MARK: - 单例模式
    static let shared = CategoryManager()
    private init() {}
    
    // MARK: - 预设品类列表（与增强型语义映射词典完全同步）
    private let presetCategories = [
        "火锅",        // 火锅类
        "面馆",        // 面馆类
        "烧烤",        // 烧烤类
        "咖啡/甜品",   // 咖啡/甜品类
        "饮品",        // 饮品类
        "烘焙",        // 烘焙类
        "日本料理",    // 日本料理
        "韩国料理",    // 韩国料理
        "西餐",        // 西餐
        "小吃快餐",    // 小吃快餐
        "粤菜",        // 粤菜
        "川菜",        // 川菜
        "湘菜",        // 湘菜
        "海鲜",        // 海鲜
        "小酒馆",      // 小酒馆
        "特色餐厅",    // 特色餐厅
        "其他"         // 兜底
    ]
    
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