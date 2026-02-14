import SwiftUI

struct CardInfoView: View {
    let restaurant: Restaurant
    let isVisible: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(restaurant.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(restaurant.review)
                .font(.system(size: 14, weight: .medium, design: .default))
                .italic()
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isVisible)
    }
}
