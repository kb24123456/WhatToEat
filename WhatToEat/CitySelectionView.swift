//
//  CitySelectionView.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/23.
//

import SwiftUI
import CoreLocation

/// 城市选择视图
struct CitySelectionView: View {
    // 绑定选中的城市
    @Binding var selectedCity: String
    
    // 环境变量，用于关闭视图
    @Environment(\.dismiss) private var dismiss
    
    // 搜索文本
    @State private var searchText = ""
    
    // 定位管理器
    @ObservedObject private var locationManager = LocationManager.shared
    
    // 筛选后的城市列表
    private var filteredCities: [String] {
        if searchText.isEmpty {
            return RegionManager.shared.allCities
        } else {
            return RegionManager.shared.allCities.filter { $0.contains(searchText) }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // 1. 自定义导航栏
                customNavigationBar
                
                // 2. 自定义搜索栏
                customSearchBar
                
                // 3. 当前定位卡片
                locationCard
                
                // 4. 城市列表标题
                cityListTitle
                
                // 5. 城市网格列表
                cityGrid
            }
        }
        .edgesIgnoringSafeArea(.all)
        .background(AppTheme.Colors.milkWhite)
        .onAppear {
            // 请求定位权限并获取当前城市
            locationManager.requestLocationPermission()
            locationManager.getCurrentCity { cityName in
                if let city = cityName {
                    print("当前定位城市: \(city)")
                }
            }
        }
    }
    
    // MARK: - 自定义导航栏
    private var customNavigationBar: some View {
        HStack {
            // 左侧：取消按钮
            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(AppTheme.Fonts.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            Spacer()
            
            // 中间：标题
            Text("选择城市")
                .font(AppTheme.Fonts.title3)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            // 右侧：占位，保持标题居中
            Color.clear
                .frame(width: 44) // 与左侧按钮宽度一致
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, 44) // 适配状态栏高度
        .padding(.bottom, AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
        .shadow(color: AppTheme.Shadows.light.color, radius: AppTheme.Shadows.light.radius, x: AppTheme.Shadows.light.x, y: AppTheme.Shadows.light.y)
    }
    
    // MARK: - 自定义搜索栏
    private var customSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("搜索城市", text: $searchText)
                .font(AppTheme.Fonts.footnote)
                .submitLabel(.search)  // 键盘右下角显示"搜索"
        }
        .padding(AppTheme.Spacing.md)
        .background(Color(.systemGray6))
        .cornerRadius(AppTheme.Radius.base)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    // MARK: - 当前定位卡片
    private var locationCard: some View {
        Button {
            if let city = locationManager.currentCity {
                selectedCity = city
                dismiss()
            }
        } label: {
            HStack {
                // 定位图标
                Image(systemName: "location.fill")
                    .symbolRenderingMode(.hierarchical) // 增加层次感
                    .foregroundColor(locationManager.currentCity != nil ? AppTheme.Colors.accent : .gray)
                    .font(AppTheme.Fonts.headline)
                
                // 城市名或定位中
                if let city = locationManager.currentCity {
                    Text(city)
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                } else {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.gray)
                        Text("定位中...")
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // 右箭头
                if locationManager.currentCity != nil {
                    Image(systemName: "chevron.right")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                    .fill(AppTheme.Colors.card)
                    .shadow(
                        color: AppTheme.Shadows.light.color,
                        radius: AppTheme.Shadows.light.radius,
                        x: AppTheme.Shadows.light.x,
                        y: AppTheme.Shadows.light.y
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.base)
                            .stroke(AppTheme.Colors.divider, lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: UIScreen.main.bounds.width / 3) // 宽度缩短到屏幕宽度的三分之一
        .buttonStyle(.plain)
        .disabled(locationManager.currentCity == nil)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - 城市列表标题
    private var cityListTitle: some View {
        HStack {
            Text("所有城市")
                .font(AppTheme.Fonts.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - 城市网格列表
    private var cityGrid: some View {
        // 定义自适应网格列
        let columns = [GridItem(.adaptive(minimum: 70, maximum: 120), spacing: AppTheme.Spacing.md)]
        
        return LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
            ForEach(filteredCities, id: \.self) { city in
                cityTag(city: city)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
    
    // MARK: - 城市Tag
    private func cityTag(city: String) -> some View {
        Button {
            selectedCity = city
            dismiss()
        } label: {
            Text(city)
                .font(AppTheme.Fonts.footnote)
                .foregroundColor(city == selectedCity ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(city == selectedCity ? AppTheme.Colors.accent : AppTheme.Colors.lightGray)
                .cornerRadius(AppTheme.Radius.circle)
                .shadow(
                    color: city == selectedCity ? AppTheme.Shadows.elevated.color : AppTheme.Shadows.light.color,
                    radius: city == selectedCity ? AppTheme.Shadows.elevated.radius : AppTheme.Shadows.light.radius,
                    x: city == selectedCity ? AppTheme.Shadows.elevated.x : AppTheme.Shadows.light.x,
                    y: city == selectedCity ? AppTheme.Shadows.elevated.y : AppTheme.Shadows.light.y
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预览
#Preview {
    CitySelectionView(selectedCity: .constant("上海"))
}
