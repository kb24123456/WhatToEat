import SwiftUI
import MapKit
import SwiftData

struct RestaurantCard: View {
    let restaurant: Restaurant
    @ObservedObject var locationManager: LocationManager
    let animation: Namespace.ID
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
        .background(cardBackground)
        .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.75))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
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
            .matchedGeometryEffect(id: "coverImage-\(restaurant.id)", in: animation)
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
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.image).stroke(Color.white.opacity(0.8), lineWidth: 1.2))
            
            Rectangle()
                .fill(.white.opacity(0.4))
                .frame(width: 35, height: 10)
                .rotationEffect(.degrees(-15))
                .offset(x: -25, y: -18)
                .blur(radius: 0.5)
                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
        }
        .scaleEffect(1.02)
        .rotationEffect(.degrees(-1.5))
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
                .font(AppTheme.Fonts.title3)
                .bold()
                .foregroundColor(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .matchedGeometryEffect(id: "title-\(restaurant.id)", in: animation)
            
            Color.clear.frame(height: 14)
            
            metaInfo
            
            Color.clear.frame(height: 8)
            
            tagsRow
            
            Color.clear.frame(height: 8)
            
            if !restaurant.review.isEmpty {
                reviewView
            }
        }
        .frame(height: AppTheme.Cards.restaurantCoverHeight, alignment: .center)
    }
    
    private var metaInfo: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Text(priceText)
                .font(AppTheme.Fonts.subheadline)
                .foregroundColor(AppTheme.Colors.price)
                .matchedGeometryEffect(id: "price-\(restaurant.id)", in: animation)
            
            Text(restaurant.district)
                .font(AppTheme.Fonts.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .matchedGeometryEffect(id: "district-\(restaurant.id)", in: animation)
            
            if let userLocation = locationManager.userLocation {
                Text(distanceText(from: userLocation, to: restaurant))
                    .font(AppTheme.Fonts.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            } else {
                Text("未定位")
                    .font(AppTheme.Fonts.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(metaBackground)
        .matchedGeometryEffect(id: "meta-\(restaurant.id)", in: animation)
    }
    
    private var metaBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.Colors.softBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
            )
    }
    
    private var tagsRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ratingView
                .matchedGeometryEffect(id: "rating-\(restaurant.id)", in: animation)
            
            Text(restaurant.type)
                .font(AppTheme.Fonts.callout)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .matchedGeometryEffect(id: "type-\(restaurant.id)", in: animation)
            
            ForEach(restaurant.tags.prefix(2), id: \.self) { tag in
                TagView(tag: tag)
            }
        }
        .matchedGeometryEffect(id: "tags-\(restaurant.id)", in: animation)
    }
    
    private var ratingView: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.secondary)
                .symbolRenderingMode(.hierarchical)
            Text("\(Int(restaurant.rating))")
                .font(AppTheme.Fonts.callout)
                .foregroundColor(AppTheme.Colors.secondary)
                .bold()
        }
    }
    
    private var reviewView: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(AppTheme.Colors.accent)
                .frame(width: 1.5)
                .cornerRadius(1)
                .shadow(color: AppTheme.Colors.accent.opacity(0.2), radius: 1.5, x: 0, y: 0)
            
            Text("\(restaurant.review)")
                .font(AppTheme.Fonts.callout)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .fontWeight(.medium)
                .tracking(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.lightGray.opacity(0.5))
        .cornerRadius(AppTheme.Radius.base)
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .matchedGeometryEffect(id: "review-\(restaurant.id)", in: animation)
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
                .fill(Color.white.opacity(0.9))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
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
            .font(AppTheme.Fonts.callout)
            .foregroundColor(Color(hex: "#89CFF0"))
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(Color(hex: "#89CFF0").opacity(0.1))
            )
    }
}
