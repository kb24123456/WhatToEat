import Foundation
import SwiftData

/// 用户自定义品类
@Model
class UserCategory {
    var id: UUID
    var name: String
    var createdAt: Date
    var isActive: Bool
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.isActive = true
    }
}
