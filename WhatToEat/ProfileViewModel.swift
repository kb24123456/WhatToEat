//
//  ProfileViewModel.swift
//  WhatToEat
//
//  Created by AI Assistant on 2026/2/27.
//

import SwiftUI
import SwiftData

// MARK: - Profile View Model
// 管理 ProfileView 的所有状态和业务逻辑

@MainActor
@Observable
class ProfileViewModel {
    struct GrowthScoreBreakdown {
        let checkInScore: Int
        let restaurantScore: Int
        let expenseScore: Int

        var totalScore: Int {
            checkInScore + restaurantScore + expenseScore
        }
    }

    private struct LevelDefinition {
        let level: Int
        let title: String
        let threshold: Int
        let summary: String
    }

    // MARK: - Dependencies
    var modelContext: ModelContext?
    var restaurants: [Restaurant] = []
    
    // MARK: - User Profile
    var userProfile = UserProfile.load()
    var showingEditProfile = false
    
    var cardOrder: [String] = [
        "stats",        // 统计概览
        "consumption",  // 消费洞察
        "tags",         // 我的标签
        "cuisine",      // 餐饮偏好
        "categories",   // 品类管理
        "restaurants",  // 常去餐厅
        "timeline",     // 美食足迹
        "zodiac"        // 味蕾星盘
    ]
    
    // MARK: - Drag & Drop State
    var draggedCardId: String? = nil
    var dragOffset: CGSize = .zero
    var isDragging = false
    
    // MARK: - Tags Management
    var userTags: [String] = UserDefaults.standard.stringArray(forKey: "userCustomTags") ?? ["氛围感", "老字号", "二刷", "排队王", "性价比"]
    var isEditingTags = false
    var newTagInput = ""
    var tagInputIsFocused = false
    
    // MARK: - Categories Management
    var isEditingCategories = false
    var newCategoryInput = ""
    var categoryInputIsFocused = false
    var userCategories: [UserCategory] = []
    var categoryRestaurantMap: [String: [Restaurant]] = [:]
    var isLoadingCategoryMap = false
    var deleteCategoryData: DeleteCategoryData? = nil
    var selectedRestaurantNewCategory: [UUID: String] = [:]
    
    // MARK: - Restaurant Detail
    var selectedRestaurantForDetail: Restaurant? = nil
    
    // MARK: - Sheets
    var showCheckInHistory = false
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Computed Properties
    var totalRestaurants: Int { restaurants.count }
    var totalCheckIns: Int { restaurants.reduce(0) { $0 + $1.logs.count } }
    var totalExpense: Double { restaurants.reduce(0) { $0 + $1.logs.reduce(0) { $0 + $1.expense } } }
    var uniqueCities: Int { Set(restaurants.map { $0.city }).count }

    var growthScoreBreakdown: GrowthScoreBreakdown {
        GrowthScoreBreakdown(
            checkInScore: totalCheckIns * 3,
            restaurantScore: restaurantContributionScore(for: totalRestaurants),
            expenseScore: expenseContributionScore(for: totalExpense)
        )
    }
    
    var joinDays: Int {
        guard let firstRestaurant = restaurants.min(by: { $0.createdAt < $1.createdAt }) else { return 0 }
        return Calendar.current.dateComponents([.day], from: firstRestaurant.createdAt, to: Date()).day ?? 0
    }
    
    // MARK: - Card Reordering
    func moveCard(from source: IndexSet, to destination: Int) {
        cardOrder.move(fromOffsets: source, toOffset: destination)
        saveCardOrder()
    }
    
    func saveCardOrder() {
        UserDefaults.standard.set(cardOrder, forKey: "profileCardOrder")
    }
    
    func loadCardOrder() {
        if let saved = UserDefaults.standard.stringArray(forKey: "profileCardOrder") {
            cardOrder = saved
        }
    }
    
    // MARK: - Tags Management
    func addNewTag() {
        let trimmed = newTagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty && !userTags.contains(trimmed) else {
            newTagInput = ""
            return
        }
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
            userTags.append(trimmed)
            newTagInput = ""
        }
        
        saveTags()
        
        if userTags.count >= 10 {
            isEditingTags = false
        }
    }
    
    func removeTag(_ tag: String) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
            userTags.removeAll { $0 == tag }
        }
        saveTags()
    }
    
    func saveTags() {
        UserDefaults.standard.set(userTags, forKey: "userCustomTags")
    }
    
    // MARK: - Categories Management
    func loadUserCategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<UserCategory>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        do {
            userCategories = try context.fetch(descriptor)
        } catch {
            print("加载用户品类失败: \(error)")
        }
    }
    
    func addNewCategory() {
        let trimmed = newCategoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let context = modelContext else { return }

        do {
            _ = try CategoryManager.shared.createCategory(name: trimmed, context: context)
            loadUserCategories()
            newCategoryInput = ""
        } catch {
            print("保存新品类失败: \(error)")
            newCategoryInput = ""
        }
    }
    
    func prepareDeleteCategory(_ categoryName: String) {
        let affectedRestaurants = restaurants.filter { $0.type == categoryName }
        
        if affectedRestaurants.isEmpty {
            performDeleteCategory(categoryName)
        } else {
            deleteCategoryData = DeleteCategoryData(
                categoryName: categoryName,
                restaurants: affectedRestaurants
            )
        }
    }
    
    func performDeleteCategory(_ categoryName: String) {
        guard let context = modelContext else { return }

        do {
            try CategoryManager.shared.deleteCategory(name: categoryName, context: context)
            loadUserCategories()
            buildCategoryRestaurantMap { }
        } catch {
            print("删除品类失败: \(error)")
        }
    }
    
    func buildCategoryRestaurantMap(completion: @escaping () -> Void) {
        guard !isLoadingCategoryMap else { return }
        isLoadingCategoryMap = true
        
        Task {
            var newMap: [String: [Restaurant]] = [:]
            
            for restaurant in restaurants {
                let category = restaurant.type
                if newMap[category] == nil {
                    newMap[category] = []
                }
                newMap[category]?.append(restaurant)
            }
            
            await MainActor.run {
                categoryRestaurantMap = newMap
                isLoadingCategoryMap = false
                completion()
            }
        }
    }
    
    // MARK: - Data Helpers
    func formatCurrency(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "¥%.1fk", value / 1000)
        } else if value >= 1000 {
            return String(format: "¥%.0f", value)
        } else {
            return String(format: "¥%.0f", value)
        }
    }
    
    func getMonthlyExpenses() -> [(month: String, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(month: String, amount: Double)] = []
        
        for i in (0..<6).reversed() {
            if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
                let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? date
                let monthStr = String(format: "%d月", calendar.component(.month, from: date))
                let amount = restaurants.reduce(0.0) { partialResult, restaurant in
                    partialResult + restaurant.logs.reduce(0.0) { sum, log in
                        if log.date >= monthStart && log.date < nextMonthStart {
                            return sum + log.expense
                        }
                        return sum
                    }
                }
                result.append((month: monthStr, amount: amount))
            }
        }
        return result
    }
    
    func getCuisineTypeDistribution() -> [(type: String, count: Int, percent: Double, color: Color)] {
        let colors: [Color] = [AppTheme.Colors.accent, AppTheme.Colors.babyBlue, AppTheme.Colors.mediumGray, AppTheme.Colors.secondary]
        let typeCounts = Dictionary(grouping: restaurants, by: { $0.type })
            .mapValues { $0.count }
        let sortedTypes = typeCounts.sorted { $0.value > $1.value }
        let total = sortedTypes.reduce(0) { $0 + $1.value }
        guard total > 0 else { return [] }
        
        return sortedTypes.enumerated().map { index, item in
            let percent = Double(item.value) / Double(total)
            return (
                type: item.key,
                count: item.value,
                percent: percent,
                color: colors[index % colors.count]
            )
        }
    }
    
    func getTopRestaurants(limit: Int) -> [Restaurant] {
        return restaurants
            .sorted { $0.logs.count > $1.logs.count }
            .prefix(limit)
            .map { $0 }
    }
    
    func getRecentLogsWithRestaurant(limit: Int) -> [(log: VisitLog, restaurantName: String)] {
        var allLogs: [(log: VisitLog, restaurantName: String)] = []
        for restaurant in restaurants {
            for log in restaurant.logs {
                allLogs.append((log: log, restaurantName: restaurant.name))
            }
        }
        return allLogs.sorted { $0.log.date > $1.log.date }.prefix(limit).map { $0 }
    }
    
    private var levelDefinitions: [LevelDefinition] {
        [
            .init(level: 1, title: "干饭学徒", threshold: 0, summary: "开始建立你的第一份个人美食档案。"),
            .init(level: 2, title: "入门吃货", threshold: 120, summary: "你已经形成稳定的外食探索节奏。"),
            .init(level: 3, title: "寻味达人", threshold: 240, summary: "开始积累属于自己的店铺与偏好地图。"),
            .init(level: 4, title: "美食品鉴家", threshold: 380, summary: "不再只是记录，而是在沉淀个人风味轨迹。"),
            .init(level: 5, title: "资深老饕", threshold: 560, summary: "你对餐厅与消费体验已经形成深度判断。"),
            .init(level: 6, title: "传奇老吃家", threshold: 790, summary: "开始拥有更成熟的选择标准与长期品味。"),
            .init(level: 7, title: "食神", threshold: 1080, summary: "你已把探索、记录与审美整合成个人体系。")
        ]
    }

    func calculateLevel() -> Int {
        let score = growthScoreBreakdown.totalScore
        return levelDefinitions.last(where: { score >= $0.threshold })?.level ?? 1
    }
    
    func getNextLevelRequirement() -> Int {
        let level = calculateLevel()
        return levelDefinitions.first(where: { $0.level == level + 1 })?.threshold ?? currentLevelDefinition.threshold
    }
    
    func getLevelTitle() -> String {
        currentLevelDefinition.title
    }

    func getLevelSummary() -> String {
        currentLevelDefinition.summary
    }

    func getLevelMilestones() -> [(level: Int, title: String, threshold: Int, summary: String)] {
        levelDefinitions.map { ($0.level, $0.title, $0.threshold, $0.summary) }
    }

    func getCurrentLevelFloor() -> Int {
        currentLevelDefinition.threshold
    }

    func getLevelProgress() -> Double {
        let currentScore = growthScoreBreakdown.totalScore
        let nextRequirement = getNextLevelRequirement()
        guard nextRequirement > 0 else { return 1 }
        let progress = Double(currentScore) / Double(nextRequirement)
        return min(max(progress, 0), 1)
    }

    func growthGapToNextLevel() -> Int {
        max(getNextLevelRequirement() - growthScoreBreakdown.totalScore, 0)
    }

    private var currentLevelDefinition: LevelDefinition {
        let level = calculateLevel()
        return levelDefinitions.first(where: { $0.level == level }) ?? levelDefinitions[0]
    }

    private func restaurantContributionScore(for count: Int) -> Int {
        switch count {
        case ..<10:
            return count * 3
        case 10..<30:
            return 30 + (count - 10) * 2
        case 30..<80:
            return 70 + count - 30
        default:
            return min(120 + Int(Double(count - 80) * 0.4), 190)
        }
    }

    private func expenseContributionScore(for expense: Double) -> Int {
        if expense <= 0 { return 0 }
        let scaled = log1p(expense / 350.0) * 42.0
        return min(Int(scaled.rounded()), 180)
    }
    
    func zodiacSymbol(for zodiac: String) -> String {
        let symbols: [String: String] = [
            "白羊座": "♈", "金牛座": "♉", "双子座": "♊",
            "巨蟹座": "♋", "狮子座": "♌", "处女座": "♍",
            "天秤座": "♎", "天蝎座": "♏", "射手座": "♐",
            "摩羯座": "♑", "水瓶座": "♒", "双鱼座": "♓"
        ]
        return symbols[zodiac] ?? "⭐"
    }
    
    func formatBirthDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

// MARK: - Delete Category Data
struct DeleteCategoryData: Identifiable {
    let id = UUID()
    let categoryName: String
    let restaurants: [Restaurant]
}
