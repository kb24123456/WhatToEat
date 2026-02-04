import SwiftUI
import MapKit
import SwiftData

struct RestaurantCard: View {
    let restaurant: Restaurant
    @ObservedObject var locationManager: LocationManager
    let isExpanded: Bool
    
    @State private var showCheckInSheet = false
    
    private func distanceText(from: CLLocation, to restaurant: Restaurant) -> String {
        let distance = from.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    private var priceText: String {
        if restaurant.averagePrice > 0 {
            return "¥\(Int(restaurant.averagePrice))/人"
        } else {
            return "暂无消费数据"
        }
    }
    
    var body: some View {
        Group {
            if restaurant.modelContext != nil {
                cardContent
            } else {
                EmptyView()
            }
        }
    }
    
    private var cardContent: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            coverImage
            cardInfo
        }
        .contentShape(Rectangle())
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .cardStyle()
    }
    
    private var coverImage: some View {
        ZStack {
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    ZStack {
                        AppTheme.Colors.primary.opacity(0.1)
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.Colors.primary.opacity(0.3))
                            .symbolRenderingMode(.hierarchical)
                    }
                )
            )
            .frame(width: AppTheme.Cards.restaurantCoverWidth, height: AppTheme.Cards.restaurantCoverHeight)
            .cornerRadius(AppTheme.Radius.image)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.image)
                    .fill(LinearGradient(
                        colors: [Color.black.opacity(0.05), Color.clear, Color.clear, Color.black.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            )
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.image).stroke(AppTheme.Colors.divider, lineWidth: 1.2))
        }
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 4, y: 6)
    }
    
    private var cardInfo: some View {
        ZStack(alignment: .topTrailing) {
            infoContent
            checkInButton
        }
    }
    
    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(restaurant.name)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Color.clear.frame(height: 12)

            metaInfo

            Color.clear.frame(height: 6)

            tagsRow

            Color.clear.frame(height: 6)

            if !restaurant.review.isEmpty {
                reviewView
            }
        }
        .frame(height: AppTheme.Cards.restaurantCoverHeight, alignment: .center)
    }
    
    private var metaInfo: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text(priceText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.price)

            Text(restaurant.district)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#6B7280"))

            if let userLocation = locationManager.userLocation {
                Text(distanceText(from: userLocation, to: restaurant))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .lineLimit(1)
            } else {
                Text("未定位")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(metaBackground)
    }
    
    private var metaBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.Colors.softBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
            )
    }
    
    private var tagsRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ratingView
            
            Text(restaurant.type)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(Color(hex: "#6B7280"))
            
            ForEach(restaurant.tags.prefix(2), id: \.self) { tag in
                TagView(tag: tag)
            }
        }
    }
    
    private var ratingView: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.secondary)
                .symbolRenderingMode(.hierarchical)
            Text("\(Int(restaurant.rating))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.secondary)
        }
    }
    
    private var reviewView: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(AppTheme.Colors.accent)
                .frame(width: 1.5, height: 12)
                .cornerRadius(0.75)

            Text("\(restaurant.review)")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(Color(hex: "#6B7280"))
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .tracking(0.3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.Colors.softBackground)
        .cornerRadius(6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var checkInButton: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FF6B6B"))
            Text("\(restaurant.checkInCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.Colors.card)
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
        )
        .onTapGesture {
            showCheckInSheet = true
        }
    }
}

// MARK: - 辅助视图
private struct TagView: View {
    let tag: String
    
    var body: some View {
        Text(tag)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(Color(hex: "#89CFF0"))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color(hex: "#89CFF0").opacity(0.1))
            )
    }
}
