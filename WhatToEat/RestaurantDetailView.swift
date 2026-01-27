import SwiftUI
import MapKit
import SwiftData
import UIKit
import PhotosUI

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let locationManager: LocationManager
    @Binding var isPresented: Bool
    
    @State private var drivingRoute: (distance: String, time: String)?
    @State private var isLoadingRoute = false
    
    @State private var showSheet = false
    @State private var logToEdit: VisitLog? = nil
    
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var newCoverImages: [UIImage] = []
    
    @State private var isEditingReview = false
    @State private var editedReview = ""
    @State private var isEditingTags = false
    @State private var newTagInput = ""
    @State private var isEditingInfo = false
    @State private var editedDistrict = ""
    @State private var editedCategory = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color(hex: "#FBF9F7")
                    .ignoresSafeArea()
                    .opacity(0.95)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroSection
                        
                        checkInButtonSection
                        
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                            titleSection
                            
                            metaSection
                            
                            statsCardSection
                            
                            infoSection
                            
                            tagsSection
                            
                            routeInfoSection
                            
                            restaurantReviewSection
                            
                            checkInHistoryList
                        }
                        .padding(.top, AppTheme.Spacing.lg)
                        .padding(.bottom, 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
                
                closeButton
            }
        }
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
            CameraPickerView(selectedImages: $newCoverImages)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem)
        .onChange(of: newCoverImages.first) { _, newValue in
            if let image = newValue { updateCover(image: image) }
        }
    }
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    Rectangle()
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .overlay(
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.Colors.primary.opacity(0.3))
                                .symbolRenderingMode(.hierarchical)
                        )
                )
            )
            .frame(height: 280)
            .clipped()
            
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 100)
        }
    }
    
    private var checkInButtonSection: some View {
        HStack {
            Spacer()
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text("去打卡")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(hex: "#FF2442"))
                        .shadow(color: Color(hex: "#FF2442").opacity(0.3), radius: 12, x: 0, y: 6)
                )
            }
            .padding(.trailing, AppTheme.Spacing.lg)
            .offset(y: -20)
        }
    }
    
    private var closeButton: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isPresented = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white, .black.opacity(0.2))
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.top, 60)
        .padding(.leading, AppTheme.Spacing.lg)
    }
    
    private var titleSection: some View {
        Text(restaurant.name)
            .font(AppTheme.Fonts.title)
            .fontWeight(.bold)
            .foregroundColor(AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    private var metaSection: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Text(priceText)
                .font(AppTheme.Fonts.subheadline)
                .foregroundColor(AppTheme.Colors.price)
            
            Text(restaurant.district)
                .font(AppTheme.Fonts.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.Colors.lightGray.opacity(0.2))
        .cornerRadius(AppTheme.Radius.base)
        .padding(.horizontal, AppTheme.Spacing.lg)
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
            
            ratingItem
        }
        .padding(AppTheme.Spacing.sm)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    private var ratingItem: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Menu {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            restaurant.rating = Double(star)
                        }
                        let successGenerator = UINotificationFeedbackGenerator()
                        successGenerator.notificationOccurred(.success)
                    } label: {
                        HStack {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { s in
                                    Image(systemName: s <= star ? "star.fill" : "star")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#FFD700"))
                                }
                            }
                            Spacer()
                            Text("\(star) 星")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(restaurant.rating) ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#FFD700"))
                        }
                    }
                    Text("评分")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Text(String(format: "%.1f", restaurant.rating))
                .font(AppTheme.Fonts.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#FFD700"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.md)
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
    
    private var infoSection: some View {
        HStack(spacing: 8) {
            Text("信息")
                .font(AppTheme.Fonts.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Menu {
                ForEach(currentCityDistricts, id: \.self) { district in
                    Button(district) {
                        editedDistrict = district
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        saveInfo()
                    }
                }
            } label: {
                CapsuleButton(
                    icon: "mappin.circle.fill",
                    title: editedDistrict.isEmpty ? (restaurant.district.isEmpty ? "地区" : restaurant.district) : editedDistrict,
                    isSelected: !editedDistrict.isEmpty || !restaurant.district.isEmpty
                )
            }
            .buttonStyle(.plain)
            
            Menu {
                ForEach(CategoryManager.shared.getPresetCategories(), id: \.self) { category in
                    Button(category) {
                        editedCategory = category
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        saveInfo()
                    }
                }
            } label: {
                CapsuleButton(
                    icon: "tag.fill",
                    title: editedCategory.isEmpty ? (restaurant.type.isEmpty ? "品类" : restaurant.type) : editedCategory,
                    isSelected: !editedCategory.isEmpty || !restaurant.type.isEmpty
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    private var currentCity: String {
        UserDefaults.standard.string(forKey: "UserSelectedCity") ?? "上海"
    }
    
    private var currentCityDistricts: [String] {
        RegionManager.shared.getDistricts(for: currentCity).sorted()
    }
    
    private func saveInfo() {
        restaurant.district = editedDistrict
        restaurant.type = editedCategory
    }
    
    private struct CapsuleButton: View {
        let icon: String
        let title: String
        let isSelected: Bool
        
        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : Color(hex: "#666"))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "#FF2442") : Color(hex: "#F5F5F5"))
            )
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("标签")
                    .font(AppTheme.Fonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isEditingTags.toggle()
                    }
                } label: {
                    Image(systemName: isEditingTags ? "checkmark.circle.fill" : "square.and.pencil.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isEditingTags ? Color(hex: "#43C59E") : AppTheme.Colors.accent)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            if isEditingTags {
                editingTagsView
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                readonlyTagsView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    private var editingTagsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("常用标签")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#888"))
                
                FlowLayout(spacing: 8) {
                    ForEach(presetTags, id: \.self) { presetTag in
                        let isAdded = restaurant.tags.contains(presetTag)
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                if isAdded {
                                    restaurant.tags.removeAll { $0 == presetTag }
                                } else {
                                    restaurant.tags.append(presetTag)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 11))
                                Text(presetTag)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(isAdded ? .white : Color(hex: "#5B8DEF"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isAdded ? Color(hex: "#FF2442") : Color(hex: "#E8F4FF"))
                            )
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("我的标签")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#888"))
                
                FlowLayout(spacing: 8) {
                    ForEach(restaurant.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("# \(tag)")
                                .font(AppTheme.Fonts.callout)
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    restaurant.tags.removeAll { $0 == tag }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(AppTheme.Radius.circle)
                    }
                    
                    HStack(spacing: 4) {
                        TextField("新标签", text: $newTagInput)
                            .font(AppTheme.Fonts.callout)
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 70)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                addNewTag()
                            }
                        
                        Button {
                            addNewTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#43C59E"))
                        }
                        .disabled(newTagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(Color(hex: "#F0F8F0"))
                    .cornerRadius(AppTheme.Radius.circle)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    private var readonlyTagsView: some View {
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
    }
    
    private let presetTags = ["网红店", "性价比高", "环境好", "服务好", "排队久", "味道一般", "性价比低", "踩雷", "回头客", "约会圣地", "商务宴请", "家庭聚餐", "朋友聚会", "一人食"]
    
    private func addNewTag() {
        let tag = newTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if !restaurant.tags.contains(tag) {
                restaurant.tags.append(tag)
            }
            newTagInput = ""
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
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    private var restaurantReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("我的印象", systemImage: "quote.bubble.fill")
                    .font(AppTheme.Fonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    if !isEditingReview {
                        editedReview = restaurant.review
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isEditingReview.toggle()
                    }
                } label: {
                    Image(systemName: isEditingReview ? "checkmark.circle.fill" : "square.and.pencil.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isEditingReview ? Color(hex: "#43C59E") : AppTheme.Colors.accent)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            
            if isEditingReview {
                TextEditor(text: $editedReview)
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineSpacing(6)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(restaurant.review.isEmpty ? "添加你的用餐印象..." : restaurant.review)
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(restaurant.review.isEmpty ? AppTheme.Colors.textSecondary.opacity(0.6) : AppTheme.Colors.textSecondary)
                    .lineSpacing(AppTheme.Spacing.xs)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background(Color.white)
        .cornerRadius(AppTheme.Radius.base)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .onChange(of: isEditingReview) { _, newValue in
            if !newValue && editedReview != restaurant.review {
                restaurant.review = editedReview
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    private var checkInHistoryList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Label("打卡记录 (\(restaurant.logs.count))", systemImage: "calendar.badge.clock")
                .font(AppTheme.Fonts.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.lg)
            
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
                .padding(.horizontal, AppTheme.Spacing.lg)
            } else {
                ForEach(restaurant.logs.sorted(by: { $0.date > $1.date })) { log in
                    checkInLogCard(log: log)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
            
            deleteRestaurantButton
        }
    }
    
    private var deleteRestaurantButton: some View {
        Button(role: .destructive) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            modelContext.delete(restaurant)
            dismiss()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("删除餐厅")
            }
            .font(AppTheme.Fonts.subheadline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(Color.red.opacity(0.1))
            .cornerRadius(AppTheme.Radius.base)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.md)
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
            
            if let firstFilename = log.photoFilenames.first {
                AsyncImageView(
                    filename: firstFilename,
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
    
    private var priceText: String {
        if restaurant.averagePrice > 0 {
            return "¥\(Int(restaurant.averagePrice))/人"
        } else {
            return "暂无消费数据"
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

// MARK: - FlowLayout 自动换行布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
