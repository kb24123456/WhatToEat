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
    @FocusState private var reviewIsFocused: Bool
    
    // 评论文字动画状态
    @State private var textScale: CGFloat = 1.0
    @State private var textOpacity: Double = 1.0
    @State private var editorScale: CGFloat = 0.8
    @State private var editorOpacity: Double = 0.0
    
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
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 24) {
                            locationSection
                            
                            statsSection
                            
                            reviewSection
                            
                            tagsSection
                            
                            checkInHistorySection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 120)
                    }
                }
                .ignoresSafeArea(edges: .top)
                
                closeButton
                
                floatingActionBar
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
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FBF9F7"),
                Color(hex: "#F5F2EF"),
                Color(hex: "#F0EDE9")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
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
            .frame(height: 280)
            .clipped()
            .cornerRadius(32)
            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
            
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.4)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 140)
            .cornerRadius(32)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(restaurant.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                HStack(spacing: 16) {
                    if !restaurant.type.isEmpty {
                        Label(restaurant.type, systemImage: "tag.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if restaurant.averagePrice > 0 {
                        Label("¥\(Int(restaurant.averagePrice))/人", systemImage: "yensign.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.95))
                    }
                }
            }
            .padding(.leading, 20)
            .padding(.bottom, 20)
            
            HStack(alignment: .bottom) {
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFD700"))
                    
                    Text("\(Int(restaurant.rating))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    private var closeButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented = false
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary.opacity(0.7))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .padding(.top, 12)
        .padding(.leading, 20)
    }
    
    private var floatingActionBar: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    showSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("去打卡")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#FF6B6B"),
                                        Color(hex: "#FF2442")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color(hex: "#FF2442").opacity(0.35), radius: 16, x: 0, y: 8)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea()
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(restaurant.address)
                .font(.caption)
                .foregroundColor(Color(hex: "#999999"))
                .lineLimit(2)
            
            if isLoadingRoute {
                HStack {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("正在计算路线...")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#999999"))
                }
            } else if let route = drivingRoute {
                HStack(spacing: 20) {
                    Label("驾车 \(route.time)", systemImage: "car.fill")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("•")
                        .foregroundColor(Color(hex: "#DDDDDD"))
                    
                    Label(route.distance, systemImage: "location.fill")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#888888"))
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#332E2B"))
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#F5F2EF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                )
        )
    }
    
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("一句话点评")
                .font(.headline)
                .foregroundColor(Color(hex: "#332E2B"))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    Group {
                        if isEditingReview {
                            TextEditor(text: $editedReview)
                                .font(.body)
                                .foregroundColor(Color(hex: "#332E2B"))
                                .lineSpacing(4)
                                .frame(minHeight: isEditingReview ? 150 : 60)
                                .padding(20)
                                .focused($reviewIsFocused)
                                .scrollContentBackground(.hidden)
                                .scaleEffect(editorScale)
                                .opacity(editorOpacity)
                                .onAppear {
                                    reviewIsFocused = true
                                }
                                .onDisappear {
                                    reviewIsFocused = false
                                }
                        } else {
                            Text(restaurant.review.isEmpty ? "添加你的点评..." : restaurant.review)
                                .font(.body)
                                .foregroundColor(restaurant.review.isEmpty ? Color(hex: "#BBBBBB") : Color(hex: "#555555"))
                                .lineSpacing(4)
                                .padding(20)
                                .frame(minHeight: 60, alignment: .topLeading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .scaleEffect(textScale)
                                .opacity(textOpacity)
                        }
                    }
                    .frame(minHeight: 60)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "#FDFCF9"))
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
                )
                
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
                
                // 第一阶段：文字缩放至消失
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    textScale = 0.1
                    textOpacity = 0.0
                }
                
                // 第二阶段：从放大中心淡入编辑器
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05)) {
                        isEditingReview = true
                        editorScale = 1.0
                        editorOpacity = 1.0
                    }
                }
            }
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("标签")
                .font(.headline)
                .foregroundColor(Color(hex: "#332E2B"))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    FlowLayout(spacing: 10) {
                        ForEach(restaurant.tags, id: \.self) { tag in
                            tagSticker(tag: tag, isEditing: isEditingTags)
                        }
                        
                        if isEditingTags {
                            HStack(spacing: 6) {
                                TextField("新标签", text: $newTagInput)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color(hex: "#4A5D6B"))
                                    .frame(width: 80)
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
                                        .foregroundColor(Color(hex: "#43C59E"))
                                }
                                .disabled(newTagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(hex: "#E8F7F2"))
                            )
                        }
                    }
                    .padding(20)
                    
                    if isEditingTags {
                        Divider()
                            .background(Color(hex: "#E0DDD8"))
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("常用标签")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "#888888"))
                                .padding(.horizontal, 4)
                            
                            FlowLayout(spacing: 10) {
                                ForEach(presetTags, id: \.self) { presetTag in
                                    let isAdded = restaurant.tags.contains(presetTag)
                                    Button {
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
                                        .foregroundColor(isAdded ? .white : Color(hex: "#6B8BA4"))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(isAdded ? Color(hex: "#4A90A4") : Color(hex: "#EBE8E0"))
                                        )
                                    }
                                    .frame(minHeight: 44)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "#F8F6F2"))
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
                )
                
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
    
    private func tagSticker(tag: String, isEditing: Bool) -> some View {
        HStack(spacing: 6) {
            Text("#")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#6B8BA4"))
            
            Text(tag)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#4A5D6B"))
            
            if isEditing {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        restaurant.tags.removeAll { $0 == tag }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#BBBBBB"))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "#EBE8E0"))
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
                        .fill(.ultraThinMaterial)
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
        
        // 先缩小编辑器
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            editorScale = 0.8
            editorOpacity = 0.0
        }
        
        // 再显示文字
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isEditingReview = false
                textScale = 1.0
                textOpacity = 1.0
            }
        }
        try? modelContext.save()
    }
    
    private func cancelReview() {
        editedReview = restaurant.review
        
        // 先缩小编辑器
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            editorScale = 0.8
            editorOpacity = 0.0
        }
        
        // 再显示文字
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isEditingReview = false
                textScale = 1.0
                textOpacity = 1.0
            }
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
    
    private let presetTags = ["网红店", "性价比高", "环境好", "服务好", "排队久", "味道一般", "性价比低", "踩雷", "回头客", "约会圣地", "商务宴请", "家庭聚餐", "朋友聚会", "一人食"]
    
    private var checkInHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("打卡记录")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#332E2B"))
                
                Text("(\(restaurant.logs.count))")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#888888"))
                
                Spacer()
                
                if !restaurant.logs.isEmpty {
                    Button {
                        showSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("打卡")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Color(hex: "#FF6B6B"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "#FFE8EE"))
                        )
                    }
                }
            }
            
            if restaurant.logs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "#DDDDDD"))
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("暂无记录")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#999999"))
                    
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
                                    .fill(Color(hex: "#FF6B6B"))
                            )
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "#F8F6F2"))
                )
            } else {
                ForEach(restaurant.logs.sorted(by: { $0.date > $1.date })) { log in
                    checkInLogCard(log: log)
                }
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
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(Color(hex: "#E57373"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.clear)
            .overlay(
                Capsule()
                    .stroke(Color(hex: "#E57373"), lineWidth: 1)
            )
        }
    }
    
    private func checkInLogCard(log: VisitLog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(log.date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#888888"))
                
                Spacer()
                
                let perPerson = log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0
                Text("人均 ¥\(Int(perPerson))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#FF6B6B"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#FFE8EE"))
                    )
            }
            
            if let firstFilename = log.photoFilenames.first {
                AsyncImageView(
                    filename: firstFilename,
                    placeholder: AnyView(EmptyView())
                )
                .frame(height: 180)
                .clipped()
                .cornerRadius(16)
            }
            
            HStack(spacing: 16) {
                Label("\(Int(log.expense)) 元", systemImage: "creditcard")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#666666"))
                
                Text("•")
                    .foregroundColor(Color(hex: "#DDDDDD"))
                
                Label("\(log.peopleCount) 人", systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#666666"))
            }
            
            if !log.goodDishes.isEmpty || !log.badDishes.isEmpty {
                HStack(spacing: 16) {
                    if !log.goodDishes.isEmpty {
                        Label(log.goodDishes, systemImage: "hand.thumbsup.fill")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#43C59E"))
                    }
                    if !log.badDishes.isEmpty {
                        Label(log.badDishes, systemImage: "hand.thumbsdown.fill")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#999999"))
                    }
                }
            }
            
            if !log.review.isEmpty {
                Text(log.review)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#555555"))
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#FAFAFA"))
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#F8F6F2"))
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 3)
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
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
