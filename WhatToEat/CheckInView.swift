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
        case .satisfied: return AppTheme.Colors.moodSatisfied
        case .neutral: return AppTheme.Colors.moodNeutral
        case .terrible: return AppTheme.Colors.moodTerrible
        case .amazing: return AppTheme.Colors.moodAmazing
        }
    }
}

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var expenseFieldIsFocused: Bool
    
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
    @State private var selectedMood: MoodType?
    
    @State private var showConfetti = false
    
    @State private var animatedPerPersonPrice: Double = 0
    
    // 交错入场动画状态
    @State private var isVisible = false
    
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
            // 触发交错入场动画
            withAnimation(AppTheme.Animations.standardSpring.delay(0.1)) {
                isVisible = true
            }
        }
        .onChange(of: currentPerPersonPrice) { _, newValue in
            withAnimation(AppTheme.Animations.quickSpring) {
                animatedPerPersonPrice = newValue
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        onClose()
                    }
                }
        )
    }
    
    // MARK: - Premium Soft UI Background
    private var backgroundOverlay: some View {
        AppTheme.Colors.pageBackground
    }
    
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // 顶部标题栏（带关闭按钮）
                ZStack {
                    // 中间标题
                    Text(editingLog != nil ? "编辑打卡" : "此食此刻")
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.darkText)
                    
                    // 右侧关闭按钮
                    HStack {
                        Spacer()
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.Colors.mediumGray)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.5))
                                )
                        }
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
                
                // 所有组件直接显示，无父容器包裹（水平间距：50pt）
                timeHeaderView
                    .padding(.bottom, 20)
                    .padding(.horizontal, 50)
                
                moodSelectorSection
                    .padding(.vertical, 16)
                    .padding(.horizontal, 50)
                
                receiptSection
                    .padding(.vertical, 16)
                    .padding(.horizontal, 50)
                
                tagsSection
                    .padding(.top, 16)
                    .padding(.horizontal, 50)
                
                saveButton
                    .padding(.top, 24)
                    .padding(.horizontal, 50)

                Spacer().frame(height: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - 日历式日期头部（对称布局）
    private var timeHeaderView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(String(format: "%d", Calendar.current.component(.year, from: date)))年\(Calendar.current.component(.month, from: date))月")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .tracking(1)
                    
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .contentTransition(.numericText())
                        .animation(AppTheme.Animations.standardSpring, value: date)
                    
                    Text(weekdayInChinese)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .tracking(0.5)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 1, height: 40)
                    .cornerRadius(0.5)
                
                VStack(spacing: 4) {
                    Text("现在")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .tracking(1)
                    
                    Text(date.chineseShortTime)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .contentTransition(.numericText())
                        .animation(AppTheme.Animations.standardSpring, value: date)
                    
                    Text(" ")
                        .font(.system(size: 13))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private var weekdayInChinese: String {
        let weekdays = ["", "星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekdays[weekday]
    }
    
    // MARK: - 模块分隔线
    // MARK: - 心情模块（无背景）
    private var moodSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("这次用餐的感受")
            
            HStack(spacing: 0) {
                ForEach(MoodType.allCases, id: \.self) { mood in
                    moodButton(for: mood)
                }
            }
        }
    }
    
    // MARK: - 账单模块（极致简化）
    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("消费信息")
            
            HStack(spacing: 16) {
                peopleInputSection
                
                expenseInputSection
                
                perPersonDisplaySection
            }
        }
    }
    
    // MARK: - 推荐模块（并排无边界）
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("菜品标签")
            
            HStack(spacing: 24) {
                stickyNoteView(
                    type: .red,
                    title: "必点推荐",
                    tags: $goodTags,
                    inputText: $inputGoodTag,
                    placeholder: "输入推荐菜名..."
                )
                
                stickyNoteView(
                    type: .gray,
                    title: "避雷提醒",
                    tags: $badTags,
                    inputText: $inputBadTag,
                    placeholder: "输入避雷菜名..."
                )
            }
        }
    }
    
    // MARK: - 统一标题样式
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppTheme.Colors.darkText)
    }
    
    // MARK: - 人数录入
    private var peopleInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("人数")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            HStack(spacing: 12) {
                Button {
                    if peopleCount > 1 {
                        peopleCount -= 1
                        triggerHaptic()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(peopleCount > 1 ? AppTheme.Colors.darkText : AppTheme.Colors.lightText)
                }
                .disabled(peopleCount <= 1)

                Text("\(peopleCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .frame(minWidth: 16)

                Button {
                    peopleCount += 1
                    triggerHaptic()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.Colors.darkText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Rectangle()
                .fill(AppTheme.Colors.softBackground)
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 消费总额输入（底部横线）
    private var expenseInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("消费")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            HStack(spacing: 4) {
                Text("¥")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                TextField("0", text: $expenseText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .focused($expenseFieldIsFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("完成") {
                                expenseFieldIsFocused = false
                            }
                            .foregroundColor(AppTheme.Colors.accent)
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Rectangle()
                .fill(AppTheme.Colors.softBackground)
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 人均消费显示
    private var perPersonDisplaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("人均")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.mediumGray)
            
            HStack(spacing: 2) {
                Text("¥")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Text("\(Int(animatedPerPersonPrice))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .contentTransition(.numericText())
                    .animation(AppTheme.Animations.standardSpring, value: animatedPerPersonPrice)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Rectangle()
                .fill(Color.clear)
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 便利贴视图（无背景简化版）
    private func stickyNoteView(
        type: StickyNoteType,
        title: String,
        tags: Binding<[String]>,
        inputText: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(type.color)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(type == .red ? AppTheme.Colors.darkText : AppTheme.Colors.mediumGray)
            }

            if !tags.wrappedValue.isEmpty {
                // 使用 FlowLayout 实现自动换行
                FlowLayout(spacing: 6) {
                    ForEach(tags.wrappedValue.indices, id: \.self) { index in
                        HStack(spacing: 4) {
                            Text(tags.wrappedValue[index])
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.Colors.darkText)

                            Button {
                                triggerHaptic()
                                let currentTags = tags.wrappedValue
                                if index < currentTags.count {
                                    withAnimation(AppTheme.Animations.tagSpring) {
                                        var mutableTags = currentTags
                                        mutableTags.remove(at: index)
                                        tags.wrappedValue = mutableTags
                                    }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.Colors.lightText)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(type.color.opacity(0.1))
                        )
                    }
                }
            }

            TextField(placeholder, text: inputText)
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.vertical, 8)
                .onSubmit {
                    triggerHaptic()
                    addTag(from: inputText, to: tags)
                }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 心情按钮
    private func moodButton(for mood: MoodType) -> some View {
        let isSelected = selectedMood == mood

        return Button {
            triggerHaptic()
            withAnimation(AppTheme.Animations.standardSpring) {
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
                            .fill(mood.glowColor.opacity(0.25))
                            .blur(radius: 20)
                            .frame(width: 70, height: 70)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                        .animation(AppTheme.Animations.standardSpring, value: isSelected)

                        Circle()
                            .fill(mood.glowColor.opacity(0.4))
                            .blur(radius: 12)
                            .frame(width: 55, height: 55)
                            .scaleEffect(isSelected ? 1.0 : 0.85)
                            .animation(AppTheme.Animations.standardSpring, value: isSelected)

                        Circle()
                            .fill(mood.glowColor.opacity(0.6))
                            .blur(radius: 6)
                            .frame(width: 45, height: 45)
                    }

                    Text(mood.rawValue)
                        .font(.system(size: 32))
                        .scaleEffect(isSelected ? 1.25 : 0.9)
                        .opacity(isSelected ? 1.0 : 0.5)
                        .grayscale(isSelected ? 0.0 : 0.5)
                        .offset(y: isSelected ? -8 : 0)
                        .rotationEffect(.degrees(isSelected ? Double.random(in: -5...5) : 0))
                        .animation(AppTheme.Animations.standardSpring, value: isSelected)
                }
                .frame(height: 70)

                Text(mood.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.Colors.darkText : AppTheme.Colors.lightText)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(AppTheme.Animations.standardSpring, value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - 保存按钮（黑色背景红色打钩）
    private var saveButton: some View {
        Button {
            triggerHaptic()
            saveCheckIn()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.accent)

                Text("完成记录")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(Color.black)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(expense <= 0)
    }
    
    // MARK: - 辅助方法
    private func addTag(from input: Binding<String>, to tags: Binding<[String]>) {
        let text = input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        withAnimation(AppTheme.Animations.tagSpring) {
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
        
        if let moodValue = log.mood {
            selectedMood = MoodType.allCases.first { $0.rawValue == moodValue }
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
            editingLog.review = ""
            editingLog.mood = selectedMood?.rawValue
        } else {
            let newLog = VisitLog(
                date: date,
                expense: expense,
                peopleCount: peopleCount,
                goodDishes: goodDishesString,
                badDishes: badDishesString,
                review: "",
                mood: selectedMood?.rawValue
            )
            restaurant.logs.append(newLog)
        }
        
        updateRestaurantAveragePrice()
        
        withAnimation(AppTheme.Animations.standardSpring) {
            showConfetti = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showConfetti = false
            onClose()
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
    
    var icon: String {
        switch self {
        case .red: return "hand.thumbsup.fill"
        case .gray: return "hand.thumbsdown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .red: return AppTheme.Colors.accent
        case .gray: return AppTheme.Colors.darkText
        }
    }
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
        let colors: [Color] = [AppTheme.Colors.confettiRed, AppTheme.Colors.confettiBlue, AppTheme.Colors.confettiGreen, AppTheme.Colors.confettiOrange, AppTheme.Colors.confettiPurple]
        
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
