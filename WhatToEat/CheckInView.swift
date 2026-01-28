//
//  CheckInView.swift
//  WhatToEat
//
//  重构：高级手账质感 UI - 双层阴影、紧凑布局、横格纸底纹
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

enum MoodType: String, CaseIterable {
    case satisfied = "😋"
    case neutral = "😐"
    case terrible = "💣"
    case amazing = "🤩"
    
    var title: String {
        switch self {
        case .satisfied: return "满意"
        case .neutral: return "一般"
        case .terrible: return "踩雷"
        case .amazing: return "惊艳"
        }
    }
    
    var glowColor: Color {
        switch self {
        case .satisfied: return Color(hex: "#FFB3BA")
        case .neutral: return Color(hex: "#E8E8E8")
        case .terrible: return Color(hex: "#666666")
        case .amazing: return Color(hex: "#FFE566")
        }
    }
}

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    
    let restaurant: Restaurant
    var editingLog: VisitLog? = nil
    
    let onClose: () -> Void
    
    @State private var date = Date()
    @State private var peopleCount = 2
    @State private var expenseText = ""
    @State private var goodTags: [String] = []
    @State private var badTags: [String] = []
    @State private var inputGoodTag = ""
    @State private var inputBadTag = ""
    @State private var review = ""
    @State private var selectedMood: MoodType?
    
    @State private var selectedImages: [UIImage] = []
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    
    @State private var showConfetti = false
    @State private var deletingImageIndex: Int?
    
    @State private var animatedPerPersonPrice: Double = 0
    
    private var expense: Double {
        Double(expenseText) ?? 0
    }
    
    private var currentPerPersonPrice: Double {
        guard peopleCount > 0 else { return 0 }
        return expense / Double(peopleCount)
    }
    
    var body: some View {
        ZStack {
            backgroundOverlay
            closeButton
            scrollContent
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            if let log = editingLog {
                loadEditingLog(log)
            }
            animatedPerPersonPrice = currentPerPersonPrice
        }
        .onChange(of: currentPerPersonPrice) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatedPerPersonPrice = newValue
            }
        }
        .confirmationDialog("选择照片", isPresented: $showActionSheet) {
            Button("📸 拍照") { showCamera = true }
            Button("�️ 从相册选择") { showPhotoPicker = true }
            if !selectedImages.isEmpty {
                Button("🗑️ 清空所有照片", role: .destructive) {
                    for filename in (editingLog?.photoFilenames ?? []) {
                        ImageManager.shared.deleteImage(filename: filename)
                    }
                    selectedImages = []
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(selectedImages: $selectedImages).ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { (_, newItem: PhotosPickerItem?) in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedImages.append(image)
                    }
                }
                photoPickerItem = nil
            }
        }
    }
    
    private var backgroundOverlay: some View {
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
    
    private var closeButton: some View {
        VStack {
            HStack {
                Button {
                    onClose()
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
                .padding(.top, 12)
                .padding(.leading, 20)
                
                Spacer()
                
                Text(editingLog != nil ? "编辑打卡" : "记录美食")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .padding(.top, 12)
                
                Spacer()
                
                Color.clear.frame(width: 36, height: 36)
                    .padding(.trailing, 20)
            }
            Spacer()
        }
    }
    
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer().frame(height: 60)
                
                multiPhotoSection
                
                receiptCardView
                
                HStack(spacing: 12) {
                    stickyNoteView(
                        type: .red,
                        title: "👍 必点推荐",
                        tags: $goodTags,
                        inputText: $inputGoodTag,
                        placeholder: "输入菜名..."
                    )
                    
                    stickyNoteView(
                        type: .gray,
                        title: "💣 避雷提醒",
                        tags: $badTags,
                        inputText: $inputBadTag,
                        placeholder: "输入菜名..."
                    )
                }
                
                moodSelectorView
                
                reviewEditorView
                
                saveButton
                
                Spacer().frame(height: 40)
            }
            .frame(maxWidth: 400)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - 多图上传卡片
    private var multiPhotoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("上传照片")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#666666"))
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    addPhotoButton

                    ForEach(selectedImages.indices, id: \.self) { index in
                        photoThumbnail(at: index)
                    }
                }
            }
            .frame(height: 88)
        }
        .padding(16)
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
    
    // MARK: - 添加照片按钮
    private var addPhotoButton: some View {
        Button {
            showActionSheet = true
            triggerHaptic()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .foregroundStyle(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                    )

                VStack(spacing: 2) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#666666"))
                    Text("添加")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "#666666"))
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 照片缩略图
    private func photoThumbnail(at index: Int) -> some View {
        let image = selectedImages[index]
        let isSelected = deletingImageIndex == index
        
        return ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                .scaleEffect(isSelected ? 0.92 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            
            Button {
                deletingImageIndex = index
                triggerHaptic()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        let filename = editingLog?.photoFilenames[safe: index]
                        if let filename = filename {
                            ImageManager.shared.deleteImage(filename: filename)
                        }
                        selectedImages.remove(at: index)
                    }
                    deletingImageIndex = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.black.opacity(0.4))
            }
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        }
    }
    
    // MARK: - 费用信息卡片（三栏布局）
    private var receiptCardView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                peopleSection

                verticalDivider

                expenseSection

                verticalDivider

                perPersonSection
            }
        }
        .padding(16)
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
    
    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(width: 1, height: 50)
    }
    
    private var peopleSection: some View {
        VStack(spacing: 6) {
            Text("用餐人数")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#666666"))
                .tracking(1)

            HStack(spacing: 12) {
                Button {
                    if peopleCount > 1 {
                        peopleCount -= 1
                        triggerHaptic()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(peopleCount > 1 ? Color(hex: "#1A1A1A") : Color(hex: "#CCCCCC"))
                }
                .disabled(peopleCount <= 1)

                Text("\(peopleCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .frame(minWidth: 24)

                Button {
                    peopleCount += 1
                    triggerHaptic()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var expenseSection: some View {
        VStack(spacing: 6) {
            Text("消费总额")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#666666"))
                .tracking(1)

            HStack(spacing: 2) {
                Text("¥")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#1A1A1A"))

                TextField("0", text: $expenseText)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 70)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.ultraThinMaterial)
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private var perPersonSection: some View {
        VStack(spacing: 6) {
            Text("人均")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#666666"))
                .tracking(1)

            HStack(spacing: 2) {
                Text("¥")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#1A1A1A"))

                Text("\(Int(animatedPerPersonPrice))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: animatedPerPersonPrice)
            }

            Text("/人")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#999999"))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 便利贴视图
    private func stickyNoteView(
        type: StickyNoteType,
        title: String,
        tags: Binding<[String]>,
        inputText: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#666666"))
                .tracking(1)

            if !tags.wrappedValue.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags.wrappedValue.indices, id: \.self) { index in
                            HStack(spacing: 4) {
                                Text(tags.wrappedValue[index])
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: "#1A1A1A"))

                                Button {
                                    triggerHaptic()
                                    let currentTags = tags.wrappedValue
                                    if index < currentTags.count {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            var mutableTags = currentTags
                                            mutableTags.remove(at: index)
                                            tags.wrappedValue = mutableTags
                                        }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "#999999"))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
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
                .frame(height: 26)
            }

            TextField(placeholder, text: inputText)
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                        )
                )
                .onSubmit {
                    triggerHaptic()
                    addTag(from: inputText, to: tags)
                }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 心情选择器
    private var moodSelectorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这次用餐的感受")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#666666"))
                .tracking(1.2)

            HStack(spacing: 0) {
                ForEach(MoodType.allCases, id: \.self) { mood in
                    moodButton(for: mood)
                }
            }
        }
        .padding(16)
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
    
    private func moodButton(for mood: MoodType) -> some View {
        let isSelected = selectedMood == mood
        
        return Button {
            triggerHaptic()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                if isSelected {
                    selectedMood = nil
                } else {
                    selectedMood = mood
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(mood.glowColor.opacity(0.4))
                            .blur(radius: 8)
                            .frame(width: 50, height: 50)
                    }
                    
                    Text(mood.rawValue)
                        .font(.system(size: 32))
                        .scaleEffect(isSelected ? 1.15 : 0.85)
                        .opacity(isSelected ? 1.0 : 0.4)
                        .grayscale(isSelected ? 0.0 : 0.6)
                        .offset(y: isSelected ? -5 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                
                Text(mood.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#1A1A1A") : Color(hex: "#999999"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 评价编辑区
    private var reviewEditorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分享你的用餐体验")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#666666"))
                .tracking(1.2)

            TextEditor(text: $review)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(Color(hex: "#1A1A1A"))
                .frame(minHeight: 120, maxHeight: 180)
                .lineSpacing(6)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundStyle(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                            )

                        Canvas { context, size in
                            let lineSpacing: CGFloat = 26
                            for y in stride(from: 32, through: size.height - 8, by: lineSpacing) {
                                var path = Path()
                                path.move(to: CGPoint(x: 12, y: y))
                                path.addLine(to: CGPoint(x: size.width - 12, y: y))
                                context.stroke(
                                    path,
                                    with: .color(Color.black.opacity(0.04)),
                                    lineWidth: 0.5
                                )
                            }
                        }
                    }
                )

            HStack {
                Spacer()
                Text("记录于 \(Date().formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#999999"))
            }
            .padding(.top, 4)
        }
        .padding(16)
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

    // MARK: - 保存按钮
    private var saveButton: some View {
        Button {
            triggerHaptic()
            saveCheckIn()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))

                Text("保存记录")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(expense > 0 ? Color(hex: "#1A1A1A") : Color(hex: "#CCCCCC"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
        }
        .disabled(expense <= 0)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 辅助方法
    private func addTag(from input: Binding<String>, to tags: Binding<[String]>) {
        let text = input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            tags.wrappedValue.append(text)
            input.wrappedValue = ""
        }
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func loadEditingLog(_ log: VisitLog) {
        date = log.date
        expenseText = log.expense > 0 ? String(format: "%.0f", log.expense) : ""
        peopleCount = log.peopleCount > 0 ? log.peopleCount : 2
        goodTags = log.goodDishes.isEmpty ? [] : log.goodDishes.components(separatedBy: "，").map { $0.trimmingCharacters(in: .whitespaces) }
        badTags = log.badDishes.isEmpty ? [] : log.badDishes.components(separatedBy: "，").map { $0.trimmingCharacters(in: .whitespaces) }
        review = log.review
        
        if let moodValue = log.mood {
            selectedMood = MoodType.allCases.first { $0.rawValue == moodValue }
        }
        
        if !log.photoFilenames.isEmpty {
            Task {
                var images: [UIImage] = []
                for filename in log.photoFilenames {
                    if let image = ImageManager.shared.loadImage(filename: filename) {
                        images.append(image)
                    }
                }
                await MainActor.run {
                    self.selectedImages = images
                }
            }
        }
    }
    
    private func saveCheckIn() {
        let goodDishesString = goodTags.joined(separator: "，")
        let badDishesString = badTags.joined(separator: "，")
        
        if let editingLog = editingLog {
            editingLog.date = date
            editingLog.peopleCount = peopleCount
            editingLog.expense = expense
            editingLog.goodDishes = goodDishesString
            editingLog.badDishes = badDishesString
            editingLog.review = review
            editingLog.mood = selectedMood?.rawValue
            
            updatePhotoForLog(log: editingLog)
        } else {
            let newLog = VisitLog(
                date: date,
                expense: expense,
                peopleCount: peopleCount,
                goodDishes: goodDishesString,
                badDishes: badDishesString,
                review: review,
                mood: selectedMood?.rawValue
            )
            
            updatePhotoForLog(log: newLog)
            restaurant.logs.append(newLog)
        }
        
        updateRestaurantAveragePrice()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showConfetti = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showConfetti = false
            onClose()
        }
    }
    
    private func updatePhotoForLog(log: VisitLog) {
        let oldFilenames = log.photoFilenames
        let newFilenames = selectedImages.compactMap { ImageManager.shared.saveImage($0) }
        log.photoFilenames = newFilenames
        
        for oldFilename in oldFilenames {
            if !newFilenames.contains(oldFilename) {
                ImageManager.shared.deleteImage(filename: oldFilename)
            }
        }
    }
    
    private func updateRestaurantAveragePrice() {
        if restaurant.logs.isEmpty {
            restaurant.averagePrice = 0.0
        } else {
            let totalPerPersonSum = restaurant.logs.reduce(0.0) { partialResult, log in
                let perPerson = log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0.0
                return partialResult + perPerson
            }
            restaurant.averagePrice = totalPerPersonSum / Double(restaurant.logs.count)
        }
    }
}

// MARK: - 辅助类型
enum StickyNoteType {
    case red, gray
}

// MARK: - 内阴影修饰器
extension View {
    func innerShadow(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(color, lineWidth: radius * 2)
                .blur(radius: radius)
                .offset(x: x, y: y)
                .mask(RoundedRectangle(cornerRadius: 0))
        )
        .mask(self)
    }
}

// MARK: - Confetti 粒子动画
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [Color(hex: "#FF2442"), Color(hex: "#5796E6"), Color(hex: "#43C59E"), Color(hex: "#FFB347"), Color(hex: "#9966FF")]
        
        for _ in 0..<60 {
            let particle = ConfettiParticle(
                id: UUID(),
                position: CGPoint(x: size.width / 2, y: size.height / 2),
                velocity: CGVector(
                    dx: CGFloat.random(in: -10...10),
                    dy: CGFloat.random(in: -15...0)
                ),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...14),
                opacity: 1.0
            )
            particles.append(particle)
            
            withAnimation(.easeOut(duration: 1.8).delay(Double.random(in: 0...0.15))) {
                if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[index].position = CGPoint(
                        x: particle.position.x + particle.velocity.dx * 25,
                        y: particle.position.y + particle.velocity.dy * 25
                    )
                    particles[index].opacity = 0
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: UUID
    var position: CGPoint
    let velocity: CGVector
    let color: Color
    let size: CGFloat
    var opacity: Double
}

// MARK: - Array 安全下标扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
