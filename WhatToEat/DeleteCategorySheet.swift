//
//  DeleteCategorySheet.swift
//  WhatToEat
//
//  删除品类 Sheet - 与 ProfileView 设计语言一致的优化版本
//

import SwiftUI
import SwiftData

// MARK: - 删除品类 Sheet
struct DeleteCategorySheet: View {
    let categoryName: String
    let restaurants: [Restaurant]
    @Binding var selectedNewCategories: [UUID: String]
    let onConfirm: ([UUID: String]) -> Void
    let onCancel: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var localSelections: [UUID: String] = [:]
    @State private var showSuccessAnimation = false
    @State private var isReady = false
    
    // 动画控制器
    @State private var animationController = CardAnimationController()
    
    // 缓存可用品类列表
    private let availableCategories: [String]
    
    init(categoryName: String, restaurants: [Restaurant], selectedNewCategories: Binding<[UUID: String]>, onConfirm: @escaping ([UUID: String]) -> Void, onCancel: @escaping () -> Void) {
        self.categoryName = categoryName
        self.restaurants = restaurants
        self._selectedNewCategories = selectedNewCategories
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.availableCategories = CategoryManager.shared.getPresetCategories()
            .filter { $0 != categoryName }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色 - 冷白
                AppTheme.Colors.pageBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部提示区域 - 卡片风格
                    headerCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .staggeredAnimation(index: 0, controller: animationController)
                    
                    // 餐厅列表
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(restaurants.enumerated()), id: \.element.id) { index, restaurant in
                                RestaurantCategoryRow(
                                    restaurant: restaurant,
                                    selectedCategory: binding(for: restaurant.id),
                                    availableCategories: availableCategories,
                                    index: index
                                )
                                .staggeredAnimation(index: 1 + index, controller: animationController)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    // 底部按钮区域
                    bottomButtons
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            Rectangle()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: -4)
                        )
                }
            }
            .navigationTitle("修改餐厅品类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                }
            }
        }
        .onAppear {
            localSelections = selectedNewCategories
            animationController.beginExpansion()
        }
    }
    
    // MARK: - 顶部提示卡片
    private var headerCard: some View {
        VStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.iconAmber.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.Colors.iconAmber)
            }
            
            // 标题和说明
            VStack(spacing: 8) {
                Text("「\(categoryName)」正在被使用")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text("以下 \(restaurants.count) 家餐厅正在使用该品类，请为它们选择新的品类")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - 底部按钮
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            // 确认按钮
            Button {
                performUpdate()
            } label: {
                HStack(spacing: 8) {
                    if showSuccessAnimation {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Text("确认修改并删除品类")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(canConfirm ? AppTheme.Colors.coralRed : AppTheme.Colors.lightText)
                )
            }
            .disabled(!canConfirm)
            .scaleEffect(canConfirm ? 1.0 : 0.98)
            .animation(.spring(response: 0.2), value: canConfirm)
            
            // 取消按钮
            Button {
                onCancel()
            } label: {
                Text("取消")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
    }
    
    private func binding(for restaurantId: UUID) -> Binding<String> {
        Binding(
            get: { localSelections[restaurantId] ?? "" },
            set: { localSelections[restaurantId] = $0 }
        )
    }
    
    private var canConfirm: Bool {
        restaurants.allSatisfy { localSelections[$0.id] != nil && !localSelections[$0.id]!.isEmpty }
    }
    
    private func performUpdate() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.3)) {
            showSuccessAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onConfirm(localSelections)
        }
    }
}

// MARK: - 餐厅品类选择行
struct RestaurantCategoryRow: View {
    let restaurant: Restaurant
    @Binding var selectedCategory: String
    let availableCategories: [String]
    let index: Int
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 餐厅信息行
            HStack(spacing: 12) {
                // 餐厅图片
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.softBackground)
                        .frame(width: 52, height: 52)
                    
                    if let imageName = restaurant.coverPhotoFilename,
                       let uiImage = ImageManager.shared.loadImage(filename: imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.Colors.mediumGray)
                    }
                }
                
                // 餐厅名称和地区
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .lineLimit(1)
                    
                    Text(restaurant.district)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.lightText)
                }
                
                Spacer()
                
                // 当前品类标签
                Text(restaurant.type)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.iconAmber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.iconAmber.opacity(0.12))
                    )
            }
            
            // 分隔线
            Rectangle()
                .fill(AppTheme.Colors.divider)
                .frame(height: 0.5)
            
            // 新品类选择
            HStack(spacing: 8) {
                Text("新分类")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.lightText)
                    .frame(width: 44, alignment: .leading)
                
                Menu {
                    ForEach(availableCategories, id: \.self) { category in
                        Button(category) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                selectedCategory = category
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedCategory.isEmpty ? "请选择新品类" : selectedCategory)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(selectedCategory.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.darkText)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.lightText)
                            .rotationEffect(.degrees(selectedCategory.isEmpty ? 0 : 180))
                            .animation(.spring(response: 0.2), value: selectedCategory.isEmpty)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.Colors.softBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selectedCategory.isEmpty ? AppTheme.Colors.coralRed.opacity(0.4) : AppTheme.Colors.coralRed.opacity(0.6), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let viewModel = ProfileViewModel()
    
    return DeleteCategorySheet(
        categoryName: "小吃",
        restaurants: [],
        selectedNewCategories: .constant([:]),
        onConfirm: { _ in },
        onCancel: {}
    )
}
