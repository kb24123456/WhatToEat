import SwiftUI
import MapKit
import SwiftData
import PhotosUI

struct CenteredDetailCardView: View {
    let restaurant: Restaurant
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let locationManager: LocationManager
    let animation: Namespace.ID
    @Binding var isPresented: Bool
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
    
    @State private var showEditReviewSheet = false
    @State private var editedReview: String = ""
    
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width - (AppTheme.Spacing.lg * 2) - 28
    }
    
    private var cardHeight: CGFloat {
        screenWidth * 2.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissDetail()
                    }
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    detailCard
                        .frame(width: screenWidth, height: cardHeight)
                        .cornerRadius(AppTheme.Radius.base)
                        .shadow(color: Color.black.opacity(0.4), radius: 25, x: 0, y: 15)
                    
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
        }
        .ignoresSafeArea()
        .task {
            await fetchDrivingRoute()
            hideTabBar()
        }
        .sheet(isPresented: $showSheet) {
            CheckInView(restaurant: restaurant, editingLog: logToEdit)
        }
        .sheet(isPresented: $showEditReviewSheet) {
            editReviewSheet
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
        .onDisappear {
            restoreTabBar()
        }
    }
    
    private func hideTabBar() {
        NotificationCenter.default.post(name: .hideTabBar, object: nil)
    }
    
    private func restoreTabBar() {
        NotificationCenter.default.post(name: .restoreTabBar, object: nil)
    }
    
    private var detailCard: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                coverImageSection
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    headerSection
                    
                    Divider()
                        .background(AppTheme.Colors.divider)
                    
                    statsSection
                    
                    Divider()
                        .background(AppTheme.Colors.divider)
                    
                    infoSection
                    
                    if !restaurant.review.isEmpty {
                        reviewSection
                        
                        Divider()
                            .background(AppTheme.Colors.divider)
                    }
                    
                    logsSection
                }
                .padding(AppTheme.Spacing.md)
            }
        }
        .background(Color(hex: "#FBF9F7"))
    }
    
    private var coverImageSection: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    Rectangle()
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .overlay(
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(AppTheme.Colors.primary.opacity(0.3))
                                .symbolRenderingMode(.hierarchical)
                        )
                )
            )
            .matchedGeometryEffect(id: "coverImage-\(restaurant.id)", in: animation)
            .frame(height: 180)
            .clipped()
            
            Button {
                showActionSheet = true
            } label: {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(AppTheme.Colors.accent.opacity(0.8))
                    .clipShape(Circle())
            }
            .padding(12)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(restaurant.name)
                        .font(AppTheme.Fonts.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .matchedGeometryEffect(id: "title-\(restaurant.id)", in: animation)
                    
                    HStack(spacing: 8) {
                        categoryButton
                        ratingButton
                    }
                }
                
                Spacer()
                
                Button {
                    logToEdit = nil
                    showSheet = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.Colors.accent)
                        Text("打卡")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            
            HStack(spacing: AppTheme.Spacing.md) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.accent)
                    Text(restaurant.district)
                        .font(AppTheme.Fonts.footnote)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .matchedGeometryEffect(id: "district-\(restaurant.id)", in: animation)
                }
                
                if let userLocation = locationManager.userLocation {
                    let distance = userLocation.distance(from: CLLocation(latitude: restaurant.latitude, longitude: restaurant.longitude))
                    let distanceText = distance < 1000 ? String(format: "%.0fm", distance) : String(format: "%.1fkm", distance / 1000)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text(distanceText)
                            .font(AppTheme.Fonts.footnote)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }
    
    private var categoryButton: some View {
        Menu {
            ForEach(CategoryManager.shared.getPresetCategories(), id: \.self) { category in
                Button {
                    withAnimation {
                        restaurant.type = category
                    }
                } label: {
                    HStack {
                        Text(category)
                        if restaurant.type == category {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(restaurant.type)
                    .font(AppTheme.Fonts.footnote)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(AppTheme.Colors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppTheme.Colors.primary.opacity(0.1))
            .cornerRadius(AppTheme.Radius.base)
        }
        .matchedGeometryEffect(id: "type-\(restaurant.id)", in: animation)
    }
    
    private var ratingButton: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                starIcon(for: star)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            restaurant.rating = Double(star)
                        }
                    }
            }
        }
        .matchedGeometryEffect(id: "rating-\(restaurant.id)", in: animation)
    }
    
    private func starIcon(for star: Int) -> some View {
        let isFilled = star <= Int(restaurant.rating + 0.5)
        return Image(systemName: isFilled ? "star.fill" : "star")
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "#FFD700"))
            .symbolRenderingMode(.hierarchical)
    }
    
    private var statsSection: some View {
        HStack(spacing: 1) {
            statItem(icon: "calendar", title: "收录时间", value: restaurant.recordTimeDisplay)
            statItem(icon: "flame.fill", title: "累计打卡", value: "\(restaurant.checkInCount)")
            statItem(icon: "yensign.circle.fill", title: "人均消费", value: restaurant.averagePrice > 0 ? "¥\(Int(restaurant.averagePrice))" : "暂无")
        }
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .matchedGeometryEffect(id: "stats-\(restaurant.id)", in: animation)
    }
    
    private func statItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppTheme.Colors.accent)
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(AppTheme.Fonts.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text(title)
                .font(AppTheme.Fonts.caption2)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text(restaurant.address)
                    .font(AppTheme.Fonts.footnote)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            if isLoadingRoute {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("正在计算路线...")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            } else if let route = drivingRoute {
                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.accent)
                    Text("驾车 \(route.time) (\(route.distance))")
                        .font(AppTheme.Fonts.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.accent)
                }
            }
        }
        .padding(AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .matchedGeometryEffect(id: "route-\(restaurant.id)", in: animation)
    }
    
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.accent)
                Text("我的印象")
                    .font(AppTheme.Fonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    editedReview = restaurant.review
                    showEditReviewSheet = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            Text(restaurant.review)
                .font(AppTheme.Fonts.footnote)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineSpacing(4)
        }
        .padding(AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .matchedGeometryEffect(id: "review-\(restaurant.id)", in: animation)
    }
    
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.accent)
                Text("打卡记录")
                    .font(AppTheme.Fonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("(\(restaurant.logs.count))")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            if restaurant.logs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.ruler")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Colors.lightGray)
                        .symbolRenderingMode(.hierarchical)
                    Text("暂无记录，快去打卡吧！")
                        .font(AppTheme.Fonts.footnote)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
            } else {
                let sortedLogs = restaurant.logs.sorted(by: { $0.date > $1.date }).prefix(4)
                ForEach(Array(sortedLogs), id: \.self) { log in
                    logMiniCard(log: log)
                }
            }
        }
        .padding(AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .matchedGeometryEffect(id: "logs-\(restaurant.id)", in: animation)
    }
    
    private func logMiniCard(log: VisitLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.date.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                let perPerson = log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0
                Text("¥\(Int(perPerson)) • \(log.peopleCount)人")
                    .font(AppTheme.Fonts.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.accent)
            }
            
            if !log.goodDishes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                    Text(log.goodDishes)
                        .font(AppTheme.Fonts.caption2)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            
            if !log.review.isEmpty {
                Text(log.review)
                    .font(AppTheme.Fonts.caption2)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(AppTheme.Spacing.xs)
    }
    
    private var editReviewSheet: some View {
        NavigationStack {
            Form {
                Section("我的印象") {
                    TextEditor(text: $editedReview)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("编辑印象")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showEditReviewSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        restaurant.review = editedReview
                        showEditReviewSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func dismissDetail() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isPresented = false
        }
        onDismiss()
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

extension Notification.Name {
    static let hideTabBar = Notification.Name("hideTabBar")
    static let restoreTabBar = Notification.Name("restoreTabBar")
}
