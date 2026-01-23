import Foundation
import SwiftData

@Model
final class Restaurant {
    var id: UUID
    var name: String
    var type: String
    var district: String
    var city: String
    var rating: Int
    var address: String
    var latitude: Double
    var longitude: Double
    var coverPhotoFilename: String?  // 只能存字符串文件名
    var review: String
    var tags: [String]
    var averagePrice: Double
    var createdAt: Date
    
    // 关系：确保这里写得标准
    @Relationship(deleteRule: .cascade) var logs: [VisitLog] = []
    
    init(name: String = "", type: String = "未分类", district: String = "其他", city: String = "", rating: Int = 3, address: String = "", latitude: Double = 0.0, longitude: Double = 0.0, coverPhotoFilename: String? = nil, review: String = "", tags: [String] = [], averagePrice: Double = 0.0) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.district = district
        self.city = city
        self.rating = rating
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.coverPhotoFilename = coverPhotoFilename
        self.review = review
        self.tags = tags
        self.averagePrice = averagePrice
        self.createdAt = Date()
    }
    
    func updateAveragePrice() {
        guard !logs.isEmpty else {
            self.averagePrice = 0
            return
        }
        let total = logs.reduce(0.0) { $0 + ($1.expense / Double(max(1, $1.peopleCount))) }
        self.averagePrice = total / Double(logs.count)
    }
    
    // MARK: - 计算属性
    
    /// 打卡次数
    var checkInCount: Int {
        return logs.count
    }
    
    /// 收录天数文本
    var recordTimeDisplay: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: createdAt, to: now)
        let days = components.day ?? 0
        
        if days == 0 {
            return "今天收录"
        } else if days <= 30 {
            return "收录第 \(days) 天"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy.MM"
            return "收录于 \(dateFormatter.string(from: createdAt))"
        }
    }
}