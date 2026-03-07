//
//  CategoriesCard.swift
//  WhatToEat
//
//  品类管理卡片 - 集成级联动画系统
//

import SwiftUI
import SwiftData

// MARK: - Categories Card Preview
struct CategoriesCardPreview: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        let allCategories = getAllCategories()

        VStack(alignment: .leading, spacing: 10) {
            PreviewCardTitle(title: "我的品类")

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(allCategories.count)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text("个品类")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                if let firstCategory = allCategories.first {
                    PreviewChip(text: firstCategory)
                }

                if allCategories.count > 1 {
                    PreviewChip(text: "+\(allCategories.count - 1)")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    
    // 获取所有品类：预设 + 用户自定义 + 从餐厅数据中提取
    private func getAllCategories() -> [String] {
        if let context = viewModel.modelContext {
            return CategoryManager.shared.getSelectableCategories(context: context)
        }
        let allCategories = Set(CategoryManager.shared.getPresetCategories() + viewModel.restaurants.map { $0.type })
        return Array(allCategories).sorted()
    }
}

// MARK: - Categories Card Detail with Staggered Animation (高度自适应)
struct CategoriesCardDetail: View {
    @Bindable var viewModel: ProfileViewModel
    
    @State private var localController = CardAnimationController()
    // 本地状态，关闭后重置
    @State private var isEditing = false
    @State private var newInput = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题栏
            HStack {
                let allCategories = getAllCategories()
                Text("共 \(allCategories.count) 个品类")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Spacer()
                
                // 管理按钮
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if isEditing {
                            isEditing = false
                            newInput = ""
                        } else {
                            isEditing = true
                        }
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundColor(isEditing ? AppTheme.Colors.accent : AppTheme.Colors.mediumGray)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.softBackground)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .staggeredAnimation(index: 0, controller: localController)
            
            // 品类列表 - 自适应高度
            FlowLayout(spacing: 10) {
                let allCategories = getAllCategories()
                ForEach(Array(allCategories.enumerated()), id: \.element) { index, category in
                    EditableCategoryChip(
                        name: category,
                        isPreset: CategoryManager.shared.isPresetCategory(category),
                        isEditing: isEditing,
                        onDelete: {
                            viewModel.prepareDeleteCategory(category)
                        }
                    )
                    .staggeredAnimation(index: 1 + index, controller: localController)
                }
                
                // 添加新品类 - 参考标签卡片样式
                if isEditing {
                    newCategoryInputField
                        .staggeredAnimation(index: 1 + allCategories.count, controller: localController)
                } else {
                    addCategoryButton
                        .staggeredAnimation(index: 1 + allCategories.count, controller: localController)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
        }
        // 使用新的 DeleteCategorySheet 处理有餐厅使用的品类删除
        .sheet(item: $viewModel.deleteCategoryData) { data in
            DeleteCategorySheet(
                categoryName: data.categoryName,
                restaurants: data.restaurants,
                selectedNewCategories: $viewModel.selectedRestaurantNewCategory,
                onConfirm: { updatedRestaurants in
                    // 更新餐厅品类
                    for (restaurantId, newCategory) in updatedRestaurants {
                        if let restaurant = viewModel.restaurants.first(where: { $0.id == restaurantId }) {
                            restaurant.type = newCategory
                        }
                    }
                    // 保存并删除品类
                    try? viewModel.modelContext?.save()
                    viewModel.performDeleteCategory(data.categoryName)
                    viewModel.deleteCategoryData = nil
                },
                onCancel: {
                    viewModel.deleteCategoryData = nil
                }
            )
        }
        .onAppear {
            // 每次展开重置为初始状态
            isEditing = false
            newInput = ""
            localController.beginExpansion()
        }
    }
    
    // 获取所有品类：预设 + 用户自定义 + 从餐厅数据中提取
    private func getAllCategories() -> [String] {
        if let context = viewModel.modelContext {
            return CategoryManager.shared.getSelectableCategories(context: context)
        }
        let allCategories = Set(CategoryManager.shared.getPresetCategories() + viewModel.restaurants.map { $0.type })
        return Array(allCategories).sorted()
    }
    
    // 添加新品类按钮 - 参考标签卡片样式
    private var addCategoryButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isEditing = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text("新品类")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundColor(AppTheme.Colors.lightText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                    .foregroundColor(AppTheme.Colors.separatorGray)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @FocusState private var isInputFocused: Bool
    
    private var newCategoryInputField: some View {
        HStack(spacing: 8) {
            TextField("输入新品类", text: $newInput)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
                .submitLabel(.done)
                .focused($isInputFocused)
                .onSubmit {
                    addNewCategory()
                }
            
            Button {
                addNewCategory()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(newInput.isEmpty ? AppTheme.Colors.lightText : AppTheme.Colors.xhsRed)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(newInput.isEmpty ? AppTheme.Colors.softBackground : AppTheme.Colors.xhsRed.opacity(0.1))
                    )
            }
            .disabled(newInput.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.Colors.softBackground)
        )
        .overlay(
            Capsule()
                .stroke(AppTheme.Colors.darkText.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    private func addNewCategory() {
        guard !newInput.isEmpty else { return }
        viewModel.newCategoryInput = newInput
        viewModel.addNewCategory()
        newInput = ""
    }
}

// MARK: - 可编辑品类标签组件
private struct EditableCategoryChip: View {
    let name: String
    let isPreset: Bool
    let isEditing: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.Colors.xhsRed)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isPreset ? AppTheme.Colors.softBackground : AppTheme.Colors.xhsRed.opacity(0.1))
        )
    }
}

// MARK: - Preview
#Preview {
    let viewModel = ProfileViewModel()
    
    return ScrollView {
        VStack(spacing: 20) {
            CategoriesCardPreview(viewModel: viewModel)
                .background(Color(hex: "#FFFFFF"))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 24)
            
            CategoriesCardDetail(viewModel: viewModel)
                .frame(height: 300)
        }
    }
    .background(Color.gray.opacity(0.1))
}
