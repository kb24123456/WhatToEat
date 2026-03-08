import Foundation
import SwiftData

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

    /// 判断是否为预设品类
    /// - Parameter name: 品类名称
    /// - Returns: 是否为预设品类
    func isPresetCategory(_ name: String) -> Bool {
        presetCategories.contains(name)
    }

    // MARK: - 用户自定义品类管理

    /// 获取所有可选品类（预设 + 用户自定义 + 餐厅实际品类）
    /// - Parameter context: SwiftData 上下文
    /// - Returns: 去重排序后的品类数组
    func getSelectableCategories(context: ModelContext, restaurants: [Restaurant]? = nil) -> [String] {
        let userCategories = fetchUserCategories(from: context)
        let activeUserCategoryNames = userCategories.map { $0.name }
        let restaurantCategoryNames = fetchRestaurantCategoryNames(from: context, restaurants: restaurants)
        
        // 获取被删除的预设品类
        let deletedPresets = fetchDeletedPresetCategories(from: context)
        
        // 过滤掉被删除的预设品类
        let availablePresets = presetCategories.filter { preset in
            !deletedPresets.contains(preset)
        }
        
        let allCategories = availablePresets + activeUserCategoryNames + restaurantCategoryNames
        return Array(Set(allCategories)).sorted()
    }
    
    /// 获取被删除的预设品类
    /// - Parameter context: SwiftData 上下文
    /// - Returns: 被删除的预设品类名称数组
    func fetchDeletedPresetCategories(from context: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<UserCategory>(
            predicate: #Predicate { $0.isActive == false && $0.name.starts(with: "__DELETED_PRESET_") }
        )
        
        do {
            let deletedCategories = try context.fetch(descriptor)
            return deletedCategories.map { category in
                // 提取原始品类名称（去掉前缀）
                String(category.name.dropFirst("__DELETED_PRESET_".count))
            }
        } catch {
            AppLogger.error("获取已删除预设品类失败: \(error.localizedDescription)", category: .storage)
            return []
        }
    }

    /// 删除品类（支持预设品类与用户自定义品类）
    /// - Parameters:
    ///   - name: 品类名称
    ///   - context: SwiftData 上下文
    func deleteCategory(name: String, context: ModelContext) throws {
        if isPresetCategory(name) {
            try markPresetCategoryAsDeleted(name: name, context: context)
            return
        }

        let activeUserCategories = fetchUserCategories(from: context)
        guard let categoryToDelete = activeUserCategories.first(where: { $0.name == name }) else {
            return
        }

        context.delete(categoryToDelete)
        try context.save()
    }

    /// 将预设品类标记为删除（通过 tombstone 记录）
    private func markPresetCategoryAsDeleted(name: String, context: ModelContext) throws {
        let deletedPresets = fetchDeletedPresetCategories(from: context)
        guard !deletedPresets.contains(name) else { return }

        let tombstone = UserCategory(name: "__DELETED_PRESET_\(name)")
        tombstone.isActive = false
        context.insert(tombstone)
        try context.save()
    }

    /// 创建新品类
    /// - Parameters:
    ///   - name: 品类名称
    ///   - context: SwiftData 上下文
    /// - Returns: 创建的用户品类
    /// - Throws: CategoryError
    func createCategory(name: String, context: ModelContext) throws -> UserCategory {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 验证：不能为空
        guard !trimmedName.isEmpty else {
            throw CategoryError.emptyName
        }

        // 验证：不能重复
        let existingCategories = fetchUserCategories(from: context)
        let restaurantCategories = fetchRestaurantCategoryNames(from: context)
        let allExistingNames = (presetCategories + existingCategories.map { $0.name })
            + restaurantCategories
        let normalizedExistingNames = allExistingNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        if normalizedExistingNames.contains(trimmedName.lowercased()) {
            throw CategoryError.duplicateName
        }

        // 创建新品类
        let newCategory = UserCategory(name: trimmedName)
        context.insert(newCategory)
        try context.save()

        return newCategory
    }

    /// 从数据库获取用户自定义品类
    /// - Parameter context: SwiftData 上下文
    /// - Returns: 用户品类数组
    private func fetchUserCategories(from context: ModelContext) -> [UserCategory] {
        let descriptor = FetchDescriptor<UserCategory>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            AppLogger.error("获取用户品类失败: \(error.localizedDescription)", category: .storage)
            return []
        }
    }

    /// 从数据库获取餐厅中实际使用的品类
    /// - Parameter context: SwiftData 上下文
    /// - Returns: 餐厅品类名称数组
    private func fetchRestaurantCategoryNames(from context: ModelContext, restaurants: [Restaurant]? = nil) -> [String] {
        if let restaurants {
            return restaurants
                .map { $0.type.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let descriptor = FetchDescriptor<Restaurant>()

        do {
            return try context.fetch(descriptor)
                .map { $0.type.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }
}

// MARK: - 错误类型
enum CategoryError: Error, LocalizedError {
    case emptyName
    case duplicateName
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "品类名称不能为空"
        case .duplicateName:
            return "该品类已存在"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        }
    }
}
