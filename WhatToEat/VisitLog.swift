import Foundation
import SwiftData

@Model
final class VisitLog {
    var id: UUID
    var date: Date
    var expense: Double
    var peopleCount: Int
    var goodDishes: String
    var badDishes: String
    var review: String
    var mood: String?  // 用餐感受：拉完了 / NPC / 人上人 / 顶级 / 夯！
    var photoFilenames: [String] = [] // 支持多图存储
    
    // 关系：添加与Restaurant的反向关系，显式指定根类型
    @Relationship(inverse: \Restaurant.logs) var restaurant: Restaurant?
    
    // 计算属性：单次人均（注意：计算属性不会存入数据库，所以很安全）
    var perPersonPrice: Double {
        peopleCount > 0 ? expense / Double(peopleCount) : 0
    }
    
    init(date: Date = Date(), expense: Double = 0.0, peopleCount: Int = 1, goodDishes: String = "", badDishes: String = "", review: String = "", mood: String? = nil, photoFilenames: [String] = [], restaurant: Restaurant? = nil) {
        self.id = UUID()
        self.date = date
        self.expense = expense
        self.peopleCount = max(1, peopleCount)
        self.goodDishes = goodDishes
        self.badDishes = badDishes
        self.review = review
        self.mood = mood
        self.photoFilenames = photoFilenames
        self.restaurant = restaurant
    }
}
