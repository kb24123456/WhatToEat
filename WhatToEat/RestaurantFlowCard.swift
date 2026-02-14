import SwiftUI

/// 餐厅流卡片 - 纯图片展示（列表态）
struct RestaurantFlowCard: View {
    let restaurant: Restaurant
    let namespace: Namespace.ID
    
    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 420
    private let cornerRadius: CGFloat = 32
    
    var body: some View {
        AsyncImageView(
            filename: restaurant.coverPhotoFilename,
            placeholder: AnyView(
                ZStack {
                    Color(hex: "#F0F0F0")
                    Image(systemName: "fork.knife")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            ),
            contentMode: .fill
        )
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .matchedGeometryEffect(
            id: "card-image-\(restaurant.id)",
            in: namespace
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
    }
}

// MARK: - 预览
#Preview("餐厅流卡片") {
    struct PreviewWrapper: View {
        @Namespace var previewNamespace
        
        var body: some View {
            ZStack {
                Color(hex: "FFFDD0").ignoresSafeArea()
                
                RestaurantFlowCard(
                    restaurant: Restaurant(
                        name: "Testaurant",
                        type: "创意菜",
                        district: "三里屯",
                        coverPhotoFilename: "restaurant_1",
                        review: "一家让人流连忘返的餐厅",
                        tags: ["创意菜"]
                    ),
                    namespace: previewNamespace
                )
            }
        }
    }
    
    return PreviewWrapper()
}
