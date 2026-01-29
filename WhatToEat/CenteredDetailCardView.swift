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
    @State private var newCoverImages: [UIImage] = []
    
    @State private var showEditReviewSheet = false
    @State private var editedReview: String = ""
    
    @State private var showEditTagsSheet = false
    @State private var editingTags: [String] = []
    @State private var tagsInput: String = ""
    
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width - (AppTheme.Spacing.lg * 2) - 28
    }
    
    private var cardHeight: CGFloat {
        screenWidth * 2.0
    }
    
    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .center) {
                backgroundOverlay
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    detailCard
                        .frame(width: screenWidth, height: cardHeight)
                        .cornerRadius(AppTheme.Radius.base)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 15)
                    
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
            CheckInView(restaurant: restaurant, editingLog: logToEdit, onClose: {
                showSheet = false
            })
        }
        .sheet(isPresented: $showEditReviewSheet) {
            editReviewSheet
        }
        .sheet(isPresented: $showEditTagsSheet) {
            tagEditSheet
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
            CameraPickerView(selectedImages: $newCoverImages)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem)
        .onChange(of: newCoverImages.first) { _, newValue in
            if let image = newValue { updateCover(image: image) }
        }
        .onDisappear {
            restoreTabBar()
        }
    }
    
    private var backgroundOverlay: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .onTapGesture {
                dismissDetail()
            }
            .opacity(isPresented ? 1 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPresented)
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
            .animation(.spring(response: 0.15, dampingFraction: 0.72), value: isPresented)
            .frame(height: 180)
            .clipped()
            .zIndex(1)
            
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
                    
                    HStack(spacing: 8) {
                        categoryButton
                        ratingButton
                    }
                }
                .zIndex(1)
                
                Spacer()
                
                checkInButton
            }
            
            tagRow
            
            HStack(spacing: AppTheme.Spacing.md) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.accent)
                    Text(restaurant.district)
                        .font(AppTheme.Fonts.footnote)
                        .foregroundColor(AppTheme.Colors.textSecondary)
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
        .animation(.spring(response: 0.15, dampingFraction: 0.72), value: isPresented)
    }
    
    private func starIcon(for star: Int) -> some View {
        let isFilled = star <= Int(restaurant.rating + 0.5)
        return Image(systemName: isFilled ? "star.fill" : "star")
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "#FFD700"))
            .symbolRenderingMode(.hierarchical)
    }
    
    private var tagRow: some View {
        Group {
            if !restaurant.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(restaurant.tags.indices, id: \.self) { index in
                            Text(restaurant.tags[index])
                                .font(AppTheme.Fonts.caption)
                                .foregroundColor(AppTheme.Colors.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.Colors.primary.opacity(0.08))
                                .cornerRadius(12)
                        }
                        
                        Button {
                            editingTags = restaurant.tags
                            tagsInput = ""
                            showEditTagsSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.accent)
                        }
                    }
                }
                .frame(height: 28)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Button("添加标签") {
                        editingTags = restaurant.tags
                        tagsInput = ""
                        showEditTagsSheet = true
                    }
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.accent)
                }
            }
        }
    }
    
    private var checkInButton: some View {
        Button {
            logToEdit = nil
            showSheet = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(AppTheme.Colors.accent)
                Text("打卡")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
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
    
    private var tagEditSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if !editingTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(editingTags.indices, id: \.self) { index in
                                HStack(spacing: 4) {
                                    Text(editingTags[index])
                                        .font(AppTheme.Fonts.footnote)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            editingTags.remove(atOffsets: [index])
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#EBF3FF"))
                                .opacity(0.6)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .frame(height: 32)
                }
                
                TextField("添加标签...", text: $tagsInput)
                    .font(AppTheme.Fonts.body)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                            .stroke(AppTheme.Colors.divider, lineWidth: 0.5)
                    )
                    .cornerRadius(AppTheme.Radius.base)
                
                let presetTags = ["氛围感", "老字号", "二刷", "排队王", "性价比"]
                if !presetTags.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(presetTags.indices, id: \.self) { index in
                            Button(action: {
                                if !editingTags.contains(presetTags[index]) && !tagsInput.contains(presetTags[index]) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        editingTags.append(presetTags[index])
                                    }
                                }
                            }) {
                                Text(presetTags[index])
                                    .font(AppTheme.Fonts.footnote)
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .padding(.vertical, 6)
                            }
                            
                            if index < presetTags.count - 1 {
                                Text("|")
                                    .font(AppTheme.Fonts.footnote)
                                    .foregroundColor(AppTheme.Colors.divider)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
                
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.lg)
            .navigationTitle("编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showEditTagsSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let inputTags = tagsInput.components(
                            separatedBy: CharacterSet(charactersIn: ",， ")
                        )
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        
                        var allTags = editingTags
                        allTags.append(contentsOf: inputTags)
                        restaurant.tags = Array(Set(allTags))
                        showEditTagsSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
        withAnimation(.spring(response: 0.2, dampingFraction: 0.72)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
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
