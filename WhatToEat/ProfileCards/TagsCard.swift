//
//  TagsCard.swift
//  WhatToEat
//
//  我的标签卡片 - 集成级联动画系统
//

import SwiftUI

// MARK: - Tags Card Preview
struct TagsCardPreview: View {
    let viewModel: ProfileViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text("我的标签")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
                .tracking(0.5)
            
            // 标签数量
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(viewModel.userTags.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text("个标签")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
            }
            
            Spacer(minLength: 0)
            
            // 标签预览（显示前3个）
            FlowLayout(spacing: 6) {
                ForEach(viewModel.userTags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.coralRed.opacity(0.1))
                        )
                }
                
                if viewModel.userTags.count > 3 {
                    Text("+\(viewModel.userTags.count - 3)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Colors.lightText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.softBackground)
                        )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Tags Card Detail with Staggered Animation (高度自适应)
struct TagsCardDetail: View {
    @Bindable var viewModel: ProfileViewModel
    
    @State private var localController = CardAnimationController()
    // 本地状态，关闭后重置
    @State private var isEditing = false
    @State private var newInput = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // 标签数量统计
            HStack {
                Text("共 \(viewModel.userTags.count) 个标签")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Spacer()
                
                // 管理按钮
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isEditing.toggle()
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
            
            // 标签列表 - 自适应高度
            FlowLayout(spacing: 10) {
                ForEach(Array(viewModel.userTags.enumerated()), id: \.element) { index, tag in
                    tagItem(tag)
                        .staggeredAnimation(index: 1 + index, controller: localController)
                }
                
                // 添加新标签
                if isEditing {
                    newTagInputField
                        .staggeredAnimation(index: 1 + viewModel.userTags.count, controller: localController)
                } else if viewModel.userTags.count < 10 {
                    addTagButton
                        .staggeredAnimation(index: 1 + viewModel.userTags.count, controller: localController)
                }
            }
            .padding(.horizontal, 20)
            
            // 推荐标签
            if isEditing {
                presetTagsSection
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }
            
            Spacer(minLength: 0)
        }
        .onAppear {
            // 每次展开重置为初始状态
            isEditing = false
            newInput = ""
            localController.beginExpansion()
        }
    }
    
    private func tagItem(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            if isEditing {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    viewModel.removeTag(tag)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.Colors.coralRed)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.Colors.coralRed.opacity(0.1))
        )
    }
    
    private var newTagInputField: some View {
        TextField("新标签...", text: $newInput)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.Colors.darkText)
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
            .frame(minWidth: 80)
            .submitLabel(.done)
            .onSubmit {
                addNewTag()
            }
    }
    
    private var addTagButton: some View {
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
                Text("添加")
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
    
    private var presetTagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("推荐标签")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText)
            
            FlowLayout(spacing: 8) {
                let presetTags = ["网红店", "性价比", "环境好", "服务好", "排队久", "踩雷", "常客", "回头客"]
                ForEach(presetTags.filter { !viewModel.userTags.contains($0) }, id: \.self) { tag in
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                            viewModel.userTags.append(tag)
                            viewModel.saveTags()
                        }
                    } label: {
                        Text(tag)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.Colors.darkText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.softBackground)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func addNewTag() {
        guard !newInput.isEmpty else { return }
        viewModel.newTagInput = newInput
        viewModel.addNewTag()
        newInput = ""
    }
}

// MARK: - Preview
#Preview {
    let viewModel = ProfileViewModel()
    
    return ScrollView {
        VStack(spacing: 20) {
            TagsCardPreview(viewModel: viewModel)
                .background(Color(hex: "#FFFFFF"))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 24)
            
            TagsCardDetail(viewModel: viewModel)
                .frame(height: 350)
        }
    }
    .background(Color.gray.opacity(0.1))
}
