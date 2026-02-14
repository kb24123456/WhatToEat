import SwiftUI
import SwiftData

// MARK: - 餐厅卡片流视图模型
@MainActor
@Observable
class RestaurantFlowViewModel {
    var isExpanded: Bool = false
    var selectedRestaurant: Restaurant?
    var centeredRestaurantID: Restaurant.ID?
    var cascadePhase: Int = 0
    
    /// 展开卡片
    func expand(restaurant: Restaurant) {
        self.selectedRestaurant = restaurant
        self.isExpanded = true
        startCascadeAnimation()
    }
    
    /// 收起卡片
    func collapse() {
        self.isExpanded = false
        self.cascadePhase = 0
        
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if !self.isExpanded {
                self.selectedRestaurant = nil
            }
        }
    }
    
    /// 启动级联动画
    private func startCascadeAnimation() {
        cascadePhase = 0
        
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            cascadePhase = 1
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            cascadePhase = 2
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            cascadePhase = 3
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            cascadePhase = 4
        }
    }
}
