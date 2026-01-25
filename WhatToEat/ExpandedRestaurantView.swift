import SwiftUI
import MapKit
import SwiftData
import PhotosUI

struct ExpandedRestaurantView: View {
    let restaurant: Restaurant
    @Environment(\.modelContext) private var modelContext
    let locationManager: LocationManager
    let animation: Namespace.ID
    let onDismiss: () -> Void
    
    @State private var drivingRoute: (distance: String, time: String)?
    @State private var isLoadingRoute = false
    
    @State private var showSheet = false
    @State private var logToEdit: VisitLog? = nil
    
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedNewCover: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            statsCardSection
            
            tagsSection
            
            routeInfoSection
            
            restaurantReviewSection
            
            checkInHistoryList
            
            closeButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.lg)
        .task { await fetchDrivingRoute() }
        .sheet(isPresented: $showSheet) {
            CheckInView(restaurant: restaurant, editingLog: logToEdit)
        }
        .confirmationDialog("更换封面图", isPresented: $showActionSheet) {
            Button("📸 拍照") { showCamera = true }
            Button("🖼️ 从相册选择") { showPhotoPicker = true }
            if restaurant.coverPhotoFilename != nil {
                Button("🗑️ 删除封面", role: .destructive) {
                    restaurant.coverPhotoFilename = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(selectedImage: $selectedNewCover)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem)
        .onChange(of: selectedNewCover) { _, newValue in
            if let image = newValue { updateCover(image: image) }
        }
    }
    
    private var statsCardSection: some View {
        HStack(spacing: 1) {
            statsItem(
                icon: "calendar",
                title: "收录时间",
                value: restaurant.recordTimeDisplay
            )
            
            statsItem(
                icon: "flame.fill",
                title: "累计打卡",
                value: "\(restaurant.checkInCount) 次"
            )
            
            statsItem(
                icon: "yensign.circle.fill",
                title: "人均消费",
                value: restaurant.averagePrice > 0 ? "¥\(Int(restaurant.averagePrice))" : "暂无数据"
            )
        }
        .padding(AppTheme.Spacing.sm)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
        .matchedGeometryEffect(id: "stats-\(restaurant.id)", in: animation)
    }
    
    private func statsItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.accent)
                .symbolRenderingMode(.hierarchical)
            
            Text(title)
                .font(AppTheme.Fonts.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text(value)
                .font(AppTheme.Fonts.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.md)
    }
    
    private var tagsSection: some View {
        Group {
            if !restaurant.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(restaurant.tags, id: \.self) { tag in
                            Text("# \(tag)")
                                .font(AppTheme.Fonts.callout)
                                .foregroundColor(AppTheme.Colors.primary)
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.vertical, AppTheme.Spacing.xs)
                                .background(AppTheme.Colors.primary.opacity(0.1))
                                .cornerRadius(AppTheme.Radius.circle)
                        }
                    }
                }
                .matchedGeometryEffect(id: "tags-\(restaurant.id)", in: animation)
            }
        }
    }
    
    private var routeInfoSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label(restaurant.address, systemImage: "mappin.and.ellipse")
                .font(AppTheme.Fonts.footnote)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            if isLoadingRoute {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在计算路线...")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            } else if let route = drivingRoute {
                Label("驾车 \(route.time) (\(route.distance))", systemImage: "car.fill")
                    .font(AppTheme.Fonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.accent)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
        .matchedGeometryEffect(id: "route-\(restaurant.id)", in: animation)
    }
    
    private var restaurantReviewSection: some View {
        Group {
            if !restaurant.review.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Label("我的印象", systemImage: "quote.bubble.fill")
                        .font(AppTheme.Fonts.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(restaurant.review)
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineSpacing(AppTheme.Spacing.xs)
                }
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(AppTheme.Radius.base)
                .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
                .matchedGeometryEffect(id: "review-\(restaurant.id)", in: animation)
            }
        }
    }
    
    private var checkInHistoryList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Label("打卡记录 (\(restaurant.logs.count))", systemImage: "calendar.badge.clock")
                .font(AppTheme.Fonts.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if restaurant.logs.isEmpty {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "pencil.and.ruler")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.lightGray)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("暂无记录，快去打卡吧！")
                        .font(AppTheme.Fonts.footnote)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.xl)
            } else {
                ForEach(restaurant.logs.sorted(by: { $0.date > $1.date })) { log in
                    checkInLogCard(log: log)
                }
            }
        }
        .matchedGeometryEffect(id: "logs-\(restaurant.id)", in: animation)
    }
    
    private func checkInLogCard(log: VisitLog) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Label(log.date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                let perPerson = log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0
                Label("人均 ¥\(Int(perPerson))", systemImage: "yensign")
                    .font(AppTheme.Fonts.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.accent)
            }
            
            if log.photoFilename != nil {
                AsyncImageView(
                    filename: log.photoFilename,
                    placeholder: AnyView(EmptyView())
                )
                .frame(height: 160)
                .clipped()
                .cornerRadius(AppTheme.Radius.base)
            }
            
            HStack {
                Label("\(Int(log.expense)) 元", systemImage: "creditcard")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("•")
                    .foregroundColor(AppTheme.Colors.lightGray)
                
                Label("\(log.peopleCount) 人用餐", systemImage: "person.2")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            if !log.goodDishes.isEmpty || !log.badDishes.isEmpty {
                HStack(spacing: AppTheme.Spacing.md) {
                    if !log.goodDishes.isEmpty {
                        Label(log.goodDishes, systemImage: "hand.thumbsup.fill")
                            .font(AppTheme.Fonts.caption)
                            .foregroundColor(Color(hex: "#FF6B6B"))
                    }
                    if !log.badDishes.isEmpty {
                        Label(log.badDishes, systemImage: "hand.thumbsdown.fill")
                            .font(AppTheme.Fonts.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            
            if !log.review.isEmpty {
                Text(log.review)
                    .font(AppTheme.Fonts.footnote)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#FFF8E7"))
                    .cornerRadius(AppTheme.Radius.base)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        )
        .contextMenu {
            Button {
                logToEdit = log
                showSheet = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                modelContext.delete(log)
                restaurant.updateAveragePrice()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private var closeButton: some View {
        Button {
            onDismiss()
        } label: {
            HStack {
                Image(systemName: "chevron.up")
                Text("收起")
            }
            .font(AppTheme.Fonts.footnote)
            .foregroundColor(AppTheme.Colors.textSecondary)
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.horizontal, AppTheme.Spacing.md)
            .background(Color.white)
            .cornerRadius(AppTheme.Radius.base)
            .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Spacing.sm)
    }
    
    private func fetchDrivingRoute() async {
        guard locationManager.userLocation != nil else { return }
        isLoadingRoute = true
        if let info = await locationManager.fetchRoute(to: restaurant.latitude, long: restaurant.longitude) {
            drivingRoute = info
        }
        isLoadingRoute = false
    }
    
    private func updateCover(image: UIImage) {
        if let filename = ImageManager.shared.saveImage(image) {
            restaurant.coverPhotoFilename = filename
        }
    }
}
