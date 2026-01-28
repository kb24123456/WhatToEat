import SwiftUI
import MapKit
import SwiftData
import UIKit
import PhotosUI

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Environment(\.modelContext) private var modelContext
    let locationManager: LocationManager
    @Binding var isPresented: Bool
    
    @State private var showSheet = false
    @State private var logToEdit: VisitLog? = nil
    
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var newCoverImages: [UIImage] = []
    
    @State private var isEditingReview = false
    @State private var editedReview = ""
    @FocusState private var reviewIsFocused: Bool
    
    @State private var isEditingTags = false
    @State private var newTagInput = ""
    @FocusState private var tagInputIsFocused: Bool
    
    @State private var animateOffset: CGFloat = 500
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroSection
.overlay(
    RoundedRectangle(cornerRadius: 36, style: .continuous)
        .stroke(Color.white.opacity(0.9), lineWidth: 6)
)                            .padding(.horizontal, 20)
                            .padding(.top, 8 + geometry.safeAreaInsets.top)
                            .padding(.bottom, 16)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            statsSection
                            
                            reviewSection
                            
                            tagsSection
                            
                            checkInHistorySection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .offset(y: animateOffset)
            .animation(
                .interpolatingSpring(stiffness: 120, damping: 15)
                .speed(1.2)
                .delay(0.1),
                value: animateOffset
            )
        }
        .onAppear {
            animateOffset = 0
            editedReview = restaurant.review
        }
        .sheet(isPresented: $showSheet) {
            CheckInView(restaurant: restaurant, editingLog: logToEdit, onClose: {
                showSheet = false
            })
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
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "#F5F3F0"),
                Color(hex: "#FBF9F7"),
                Color(hex: "#FBF9F7")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    Rectangle()
                        .fill(Color(hex: "#E8E4DF"))
                        .overlay(
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(Color(hex: "#CCCCCC"))
                                .symbolRenderingMode(.hierarchical)
                        )
                )
            )
            .frame(height: 300)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
            
            VStack {
                HStack {
                    closeButton
                        .padding(.top, 24)
                        .padding(.leading, 24)
                    Spacer()
                }
                Spacer()
            }
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(restaurant.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                    
                    HStack(spacing: 8) {
                        if !restaurant.type.isEmpty {
                            Text(restaurant.type)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        
                        if restaurant.averagePrice > 0 {
                            Text("¥\(Int(restaurant.averagePrice))/人")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                
                Spacer()
                
                softCheckInButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .padding(.trailing, 8)
        }
    }
    
    private var softCheckInButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppTheme.Colors.accent)
                Text("去打卡")
                    .foregroundColor(.black.opacity(0.8))
            }
            .font(.callout)
            .fontWeight(.bold)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.white)
            )
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
            .shadow(color: Color.white.opacity(0.5), radius: 2, x: 0, y: -2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var closeButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented = false
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            statMiniCard(
                icon: "flame.fill",
                iconColor: Color(hex: "#FF8C42"),
                title: "累计打卡",
                value: "\(restaurant.checkInCount) 次"
            )
            
            statMiniCard(
                icon: "creditcard.fill",
                iconColor: Color(hex: "#6B5B95"),
                title: "总消费",
                value: restaurant.totalExpense > 0 ? "¥\(Int(restaurant.totalExpense))" : "暂无"
            )
        }
    }
    
    private func statMiniCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#666666"))
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#1A1A1A"))
            }
            
            Spacer()
        }
        .padding(14)
        .background(
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                )
        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 8)
    }
    
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("一句话点评")
                .font(.headline)
                .foregroundColor(Color(hex: "#1A1A1A"))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            ZStack(alignment: .bottomTrailing) {
                reviewCardContent
                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)

                bubbleButtons(
                    isEditing: isEditingReview,
                    onSave: saveReview,
                    onCancel: cancelReview
                )
            }
        }
        .onTapGesture {
            if !isEditingReview {
                editedReview = restaurant.review
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    isEditingReview = true
                }
            }
        }
    }

    private var reviewCardContent: some View {
        VStack(spacing: 0) {
            reviewContent
                .frame(minHeight: isEditingReview ? 150 : 60)
                .id(isEditingReview)
        }
        .background(
                    RoundedRectangle(cornerRadius: 24)
                        .foregroundStyle(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                )
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isEditingReview)
    }
    
    @ViewBuilder
    private var reviewContent: some View {
        if isEditingReview {
            ZStack(alignment: .center) {
                TextField(restaurant.review.isEmpty ? "添加你的点评..." : restaurant.review, text: $editedReview, axis: .vertical)
                    .font(.body)
                    .foregroundColor(Color(hex: "#332E2B"))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .focused($reviewIsFocused)
                    .scrollContentBackground(.hidden)
                    .padding(20)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .onAppear {
                        reviewIsFocused = true
                    }
                    .onDisappear {
                        reviewIsFocused = false
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
        } else {
            Text(restaurant.review.isEmpty ? "添加你的点评..." : restaurant.review)
                .font(.body)
                .foregroundColor(restaurant.review.isEmpty ? Color(hex: "#BBBBBB") : Color(hex: "#555555"))
                .lineSpacing(4)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("标签")
                .font(.headline)
                .foregroundColor(Color(hex: "#1A1A1A"))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            ZStack(alignment: .bottomTrailing) {
                tagsCardContent
                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)

                bubbleButtons(
                    isEditing: isEditingTags,
                    onSave: saveTags,
                    onCancel: cancelTags
                )
            }
        }
        .onTapGesture {
            if !isEditingTags {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isEditingTags = true
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditingTags)
    }

    private var tagsCardContent: some View {
        VStack(spacing: 0) {
            tagsFlowContent
                .padding(20)

            if isEditingTags {
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal, 20)

                presetTagsSection
                    .padding(20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
        )
    }

    private var tagsFlowContent: some View {
        FlowLayout(spacing: 10) {
            ForEach(restaurant.tags, id: \.self) { tag in
                tagSticker(tag: tag, isEditing: isEditingTags)
            }

            if isEditingTags {
                newTagInputField
            }
        }
    }

    private var newTagInputField: some View {
        HStack(spacing: 6) {
            TextField("新标签", text: $newTagInput)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#1A1A1A"))
                .frame(width: 60)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($tagInputIsFocused)
                .onSubmit {
                    addNewTag()
                }

            Button {
                addNewTag()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .disabled(newTagInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
                Capsule()
                    .foregroundStyle(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                    )
        )
    }

    private var presetTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用标签")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#666666"))
                .padding(.horizontal, 4)

            FlowLayout(spacing: 10) {
                ForEach(presetTags, id: \.self) { presetTag in
                    presetTagButton(presetTag: presetTag)
                }
            }
        }
    }

    private func presetTagButton(presetTag: String) -> some View {
        let isAdded = restaurant.tags.contains(presetTag)
        return Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                if isAdded {
                    restaurant.tags.removeAll { $0 == presetTag }
                } else {
                    restaurant.tags.append(presetTag)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 12))
                Text(presetTag)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isAdded ? .white : Color(hex: "#1A1A1A"))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isAdded ? AnyShapeStyle(Color(hex: "#1A1A1A")) : AnyShapeStyle(.ultraThinMaterial))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                    )
            )
        }
        .frame(minHeight: 44)
    }
    
    private func tagSticker(tag: String, isEditing: Bool) -> some View {
        HStack(spacing: 6) {
            Text("#")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#666666"))

            Text(tag)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#1A1A1A"))

            if isEditing {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        restaurant.tags.removeAll { $0 == tag }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                )
        )
    }
    
    @State private var wiggleRotation: Double = 0
    @State private var isWiggling: Bool = false
    
    private func bubbleButtons(isEditing: Bool, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack {
            Spacer()
                .frame(height: 36)
            
            if isEditing {
                HStack(spacing: 16) {
                    cancelBubble(onCancel: onCancel)
                        .offset(y: 12)
                    
                    saveBubble(onSave: onSave)
                        .offset(y: 12)
                }
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    triggerWiggleAnimation()
                }
            }
        }
        .animation(
            .spring(response: 0.4, dampingFraction: 0.6),
            value: isEditing
        )
    }
    
    private func cancelBubble(onCancel: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            onCancel()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .foregroundStyle(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .contentShape(Circle())
        .frame(width: 48, height: 48)
        .rotationEffect(Angle.degrees(wiggleRotation))
    }
    
    private func saveBubble(onSave: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            onSave()
        }) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color(hex: "#FF6B6B"))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.red.opacity(0.2), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .contentShape(Circle())
        .frame(width: 48, height: 48)
        .rotationEffect(Angle.degrees(-wiggleRotation))
    }
    
    private func triggerWiggleAnimation() {
        isWiggling = true
        withAnimation(
            Animation.linear(duration: 0.05)
                .repeatCount(6, autoreverses: true)
        ) {
            wiggleRotation = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                wiggleRotation = 0
                isWiggling = false
            }
        }
    }
    
    private func saveReview() {
        restaurant.review = editedReview
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isEditingReview = false
        }
        try? modelContext.save()
    }
    
    private func cancelReview() {
        editedReview = restaurant.review
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isEditingReview = false
        }
    }
    
    private func saveTags() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isEditingTags = false
        }
        try? modelContext.save()
    }
    
    private func cancelTags() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isEditingTags = false
        }
    }
    
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
    
    private let presetTags = ["网红店", "性价比", "环境好", "服务好", "排队久", "踩雷", "常客", "回头客"]
    
    private var checkInHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("打卡记录")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1A1A1A"))

                Text("(\(restaurant.logs.count))")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#666666"))

                Spacer()
            }

            if restaurant.logs.isEmpty {
                emptyCheckInState
            } else {
                ForEach(restaurant.logs.sorted(by: { $0.date > $1.date })) { log in
                    checkInLogCard(log: log)
                }
            }

            deleteRestaurantButton
        }
    }

    private var emptyCheckInState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(Color(hex: "#999999"))

            Text("暂无记录")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#666666"))

            Button {
                showSheet = true
            } label: {
                Text("立即打卡")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#1A1A1A"))
                    )
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
    }
    
    private var deleteRestaurantButton: some View {
        Button(role: .destructive) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            modelContext.delete(restaurant)
            isPresented = false
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("删除餐厅")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(Color(hex: "#1A1A1A"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .foregroundStyle(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.8), lineWidth: 1)
                    )
            )
        }
        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 8)
    }
    
    private func checkInLogCard(log: VisitLog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(log.date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#666666"))

                Spacer()

                let perPerson = log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0
                Text("人均 ¥\(Int(perPerson))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .foregroundStyle(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                            )
                    )
            }

            if let firstFilename = log.photoFilenames.first {
                AsyncImageView(
                    filename: firstFilename,
                    placeholder: AnyView(EmptyView())
                )
                .frame(height: 180)
                .clipped()
                .cornerRadius(20)
            }

            HStack(spacing: 16) {
                Label("\(Int(log.expense)) 元", systemImage: "creditcard")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#666666"))

                Text("•")
                    .foregroundColor(Color(hex: "#999999"))

                Label("\(log.peopleCount) 人", systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#666666"))
            }

            if !log.goodDishes.isEmpty || !log.badDishes.isEmpty {
                HStack(spacing: 12) {
                    if !log.goodDishes.isEmpty {
                        Label(log.goodDishes, systemImage: "hand.thumbsup.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#1A1A1A"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .foregroundStyle(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                                    )
                            )
                    }
                    if !log.badDishes.isEmpty {
                        Label(log.badDishes, systemImage: "hand.thumbsdown.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#666666"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .foregroundStyle(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                                    )
                            )
                    }
                }
            }

            if !log.review.isEmpty {
                Text(log.review)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundStyle(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                            )
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
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

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 自定义按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
