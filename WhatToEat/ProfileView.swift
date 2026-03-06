//
//  ProfileView.swift
//  WhatToEat
//
//  完全重构的 ProfileView，采用 Masonry 瀑布流布局 + Hero 展开动画
//

import SwiftUI
import SwiftData
import Charts
import PhotosUI
import UIKit
import CoreLocation
import UniformTypeIdentifiers
import AuthenticationServices

// MARK: - Profile View
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Restaurant.createdAt, order: .reverse) private var restaurants: [Restaurant]
    @Query(sort: \VisitLog.date, order: .reverse) private var visitLogs: [VisitLog]
    
    @State private var viewModel: ProfileViewModel
    @Namespace private var animationNamespace
    @State private var showDashboardCards = false
    @State private var selectedGateway: GatewayType = .settings
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appLockManager = AppLockManager.shared
    @AppStorage(AppSettingsKeys.preferredMapApp) private var preferredMapApp: String = ""
    @AppStorage(AppSettingsKeys.userSelectedCity) private var defaultCity: String = "重庆"
    @AppStorage(AppSettingsKeys.appAppearanceMode) private var appAppearanceMode: String = AppAppearanceMode.system.rawValue
    @AppStorage(AppSettingsKeys.hapticFeedbackEnabled) private var hapticFeedbackEnabled: Bool = true
    @AppStorage(AppSettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled: Bool = true
    @State private var showClearCacheAlert = false
    @State private var settingsToastMessage: String?
    @State private var showRestaurantImportPicker = false
    @State private var showRestaurantImportAssistDialog = false
    @State private var showExportSheet = false
    @State private var exportDocument: CSVTextDocument?
    @State private var exportFilename: String = ""
    @State private var showICloudRestartAlert = false
    @State private var showSignOutAlert = false
    @State private var showSwitchAccountAlert = false
    @State private var edgeBackGestureOffset: CGFloat = 0
    @State private var settingsTopBlurProgress: CGFloat = 0
    
    // 卡片尺寸定义（精调后）
    // 左列总高度: 156 + 212 + 184 + 158 = 710pt
    // 右列总高度: 186 + 212 + 154 + 158 = 710pt
    private let cardSizes: [String: CardSize] = [
        "stats": .small(height: 156),        // 数据概览
        "consumption": .large(height: 212),  // 消费洞察
        "tags": .medium(height: 184),        // 我的标签
        "cuisine": .medium(height: 158),     // 餐饮偏好
        "categories": .medium(height: 186),  // 品类管理
        "restaurants": .large(height: 212),  // 常去餐厅
        "timeline": .medium(height: 158),    // 美食足迹
        "zodiac": .small(height: 154)        // 味蕾星盘
    ]
    
    private let dashboardTransition = Animation.interactiveSpring(
        response: 0.55,
        dampingFraction: 0.88,
        blendDuration: 0.16
    )

    private var headerTransitionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .interactiveSpring(response: 0.5, dampingFraction: 0.86, blendDuration: 0.14)
    }

    private var profileAvatarAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .interactiveSpring(response: 0.44, dampingFraction: 0.84, blendDuration: 0.12)
    }

    private var settingsSectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .interactiveSpring(response: 0.58, dampingFraction: 0.87, blendDuration: 0.18)
    }

    private var settingsCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.adaptiveHex(light: "#FBFBFD", dark: "#1B2636"),
                Color.adaptiveHex(light: "#F2F4F8", dark: "#141E2D")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var settingsCardStroke: Color {
        Color.adaptiveHex(light: "#FFFFFF", dark: "#304056").opacity(colorScheme == .dark ? 0.9 : 0.92)
    }

    private var settingsCardInnerStroke: Color {
        Color.adaptiveHex(light: "#FFFFFF", dark: "#223247").opacity(colorScheme == .dark ? 0.42 : 0.72)
    }

    private var settingsCardShadow: Color {
        Color.black.opacity(colorScheme == .dark ? 0.24 : 0.05)
    }

    private var settingsPrimaryTextColor: Color { AppTheme.Colors.darkText }
    private var settingsSecondaryTextColor: Color { Color.adaptiveHex(light: "#95A0A7", dark: "#8F9CB0") }
    private var settingsTertiaryTextColor: Color { Color.adaptiveHex(light: "#636E72", dark: "#ABB6C8") }
    private var settingsChevronColor: Color { Color.adaptiveHex(light: "#AAB2B9", dark: "#6F7E93") }
    private var settingsSeparatorColor: Color { Color.adaptiveHex(light: "#E9EDF2", dark: "#29384B") }
    private var settingsPillBackground: Color { Color.adaptiveHex(light: "#FFFFFF", dark: "#223149") }
    private var settingsPillBorder: Color { Color.adaptiveHex(light: "#EDF1F5", dark: "#334760") }
    private var settingsSegmentTrack: Color { Color.adaptiveHex(light: "#E9EDF2", dark: "#202C3E") }
    private var settingsToggleTint: Color { Color.adaptiveHex(light: "#61C6FF", dark: "#6DB8FF") }

    private var profileSurfaceColor: Color { Color.adaptiveHex(light: "#FFFFFF", dark: "#141E2C") }
    private var profileSecondarySurfaceColor: Color { Color.adaptiveHex(light: "#F3F5F6", dark: "#223149") }
    private var profileStrokeColor: Color { Color.adaptiveHex(light: "#FFFFFF", dark: "#2C3A50").opacity(colorScheme == .dark ? 0.88 : 0.9) }
    private var profileSecondaryTextColor: Color { Color.adaptiveHex(light: "#B2BEC3", dark: "#8F9CAF") }
    private var profileMutedTextColor: Color { Color.adaptiveHex(light: "#5E646B", dark: "#AAB6C7") }
    private var profileProgressTrackColor: Color { Color.adaptiveHex(light: "#E6E8EA", dark: "#28384C") }
    private var profileProgressFillColor: Color { Color.adaptiveHex(light: "#1E2430", dark: "#E9EFF9") }
    private var profileAvatarRingColor: Color { Color.adaptiveHex(light: "#FFFFFF", dark: "#2F3C50") }
    private var profileHeaderShadowColor: Color { Color.black.opacity(colorScheme == .dark ? 0.24 : 0.06) }
    private var profileEditIconColor: Color { Color.adaptiveHex(light: "#636E72", dark: "#B3BED0") }
    
    private let edgeBackTriggerDistance: CGFloat = 88
    
    private enum GatewayType {
        case data
        case settings
    }
    
    init() {
        _viewModel = State(initialValue: ProfileViewModel())
    }
    
    var body: some View {
        ZStack {
            // 背景层：弥散渐变
            DiffuseGradientBackground()
            
            // 主内容
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    // 个人资料卡片（不参与展开）
                    profileHeader(isCompact: showDashboardCards)
                        .padding(.horizontal, showDashboardCards ? 24 : 20)
                    
                    if showDashboardCards {
                        collapseButton
                            .padding(.horizontal, 24)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                    
                    if showDashboardCards {
                        if selectedGateway == .data {
                            dashboardCardsGrid
                                .padding(.horizontal, 24)
                                .padding(.top, 6)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )
                        } else {
                            settingsDashboard
                                .padding(.horizontal, 24)
                                .padding(.top, 6)
                                .transition(settingsPanelTransition)
                        }
                    } else {
                        gatewayCards
                            .padding(.horizontal, 24)
                            .padding(.top, 6)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .scale(scale: 0.92, anchor: .top).combined(with: .opacity)
                                )
                            )
                    }
                    
                    // 底部空间
                    Color.clear.frame(height: showDashboardCards ? 40 : 20)
                }
                .animation(dashboardTransition, value: showDashboardCards)
            }
            .coordinateSpace(name: "ProfileScrollArea")
            .offset(x: showDashboardCards ? edgeBackGestureOffset * 0.16 : 0)
            .background(AppTheme.Colors.pageBackground)
            .onPreferenceChange(SettingsPanelOffsetPreferenceKey.self) { minY in
                guard showDashboardCards, selectedGateway == .settings else {
                    settingsTopBlurProgress = 0
                    return
                }
                let progress = min(max((-minY - 4) / 36, 0), 1)
                if abs(progress - settingsTopBlurProgress) > 0.015 {
                    settingsTopBlurProgress = progress
                }
            }
            
            if showDashboardCards && selectedGateway == .settings {
                settingsTopBlurOverlay
                    .zIndex(50)
                    .transition(.opacity)
            }
            
            // 展开的卡片覆盖层
            if showDashboardCards, let expandedId = viewModel.expandedCardId {
                expandedCardOverlay(id: expandedId)
                    .zIndex(100)
                    .transition(.opacity)
            }
            
            if showDashboardCards {
                edgeBackGestureHotZone
                    .zIndex(160)
            }

            if let settingsToastMessage {
                settingsToastView(message: settingsToastMessage)
                    .zIndex(200)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.restaurants = restaurants
            
            // 延迟加载数据，避免首次进入卡顿
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.loadUserCategories()
                viewModel.loadCardOrder()
            }

            if defaultCity.isEmpty {
                defaultCity = "重庆"
            }
        }
        .onChange(of: restaurants) { _, newRestaurants in
            viewModel.restaurants = newRestaurants
        }
        .onChange(of: showDashboardCards) { _, shown in
            if !shown {
                edgeBackGestureOffset = 0
                settingsTopBlurProgress = 0
            }
        }
        .onChange(of: selectedGateway) { _, gateway in
            if gateway != .settings {
                settingsTopBlurProgress = 0
            }
        }
        .onChange(of: hapticFeedbackEnabled) { _, enabled in
            HapticManager.shared.setEnabled(enabled)
            showSettingsToast(enabled ? "震动反馈已开启" : "震动反馈已关闭")
        }
        .onChange(of: iCloudSyncEnabled) { oldValue, newValue in
            guard oldValue != newValue else { return }
            handleICloudToggleChanged(to: newValue)
        }
        .sheet(isPresented: $authManager.showSignInSheet) {
            appleSignInSheet
        }
        .confirmationDialog("是否需要示例文档？", isPresented: $showRestaurantImportAssistDialog, titleVisibility: .visible) {
            Button("需要示例文档") {
                exportRestaurantTemplate()
            }
            Button("直接导入 .csv") {
                showRestaurantImportPicker = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("示例文档包含导入版本 \(DataCSVSupport.restaurantImportVersion) 与标准列格式。")
        }
        .fileImporter(
            isPresented: $showRestaurantImportPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleRestaurantImport(result)
        }
        .fileExporter(
            isPresented: $showExportSheet,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { result in
            handleDataExportResult(result)
        }
        .alert("清理所有缓存", isPresented: $showClearCacheAlert) {
            Button("取消", role: .cancel) {}
            Button("确认清理", role: .destructive) {
                clearAllCaches()
            }
        } message: {
            Text("将清理图片、搜索、定位、食签与智能纠错等本地缓存。")
        }
        .alert("iCloud 同步设置已更新", isPresented: $showICloudRestartAlert) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text("重启 App 后生效。建议开启 iCloud 同步，避免数据丢失并保持多设备一致。")
        }
        .alert("退出账户", isPresented: $showSignOutAlert) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                authManager.signOut(keepLocalData: true)
                appLockManager.setFaceIDEnabled(false)
                showSettingsToast("已退出账户，本机数据已保留")
            }
        } message: {
            Text("仅退出 Apple ID 会话，本机餐厅与消费数据将保留。")
        }
        .alert("切换账户", isPresented: $showSwitchAccountAlert) {
            Button("取消", role: .cancel) {}
            Button("继续") {
                authManager.switchAccount()
            }
        } message: {
            Text("将先退出当前账户，再重新登录 Apple ID。")
        }
    }
    
    private var collapseButton: some View {
        HStack {
            Text(selectedGateway == .settings ? "功能设置" : "我的数据")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(settingsSecondaryTextColor)
            
            Spacer()
            
            Button {
                collapseDashboard()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                    Text("收起")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(settingsTertiaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(settingsPillBackground)
                        .overlay(
                            Capsule()
                                .stroke(settingsPillBorder.opacity(0.92), lineWidth: 0.8)
                        )
                        .shadow(color: settingsCardShadow.opacity(0.7), radius: 10, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var settingsPanelTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: BlurSlideTransitionModifier(yOffset: 26, blurRadius: 6, opacity: 0, scale: 0.965),
                identity: BlurSlideTransitionModifier(yOffset: 0, blurRadius: 0, opacity: 1, scale: 1)
            ),
            removal: .modifier(
                active: BlurSlideTransitionModifier(yOffset: -14, blurRadius: 4, opacity: 0, scale: 0.985),
                identity: BlurSlideTransitionModifier(yOffset: 0, blurRadius: 0, opacity: 1, scale: 1)
            )
        )
    }
    
    private var settingsTopBlurOverlay: some View {
        let progress = Double(settingsTopBlurProgress)
        let topHeight = 54 + settingsTopBlurProgress * 24
        
        return VStack(spacing: 0) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: topHeight)
                .overlay(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.topOverlayStrong.opacity(progress * 0.95),
                            AppTheme.Colors.topOverlaySoft.opacity(progress * 0.45),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(progress)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .top)
        .animation(.easeOut(duration: 0.18), value: progress)
    }
    
    private var edgeBackGestureHotZone: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 24)
                .contentShape(Rectangle())
                .highPriorityGesture(edgeBackCollapseGesture)
            Spacer(minLength: 0)
        }
        .ignoresSafeArea(.container, edges: .vertical)
    }
    
    private var edgeBackCollapseGesture: some Gesture {
        DragGesture(minimumDistance: 9, coordinateSpace: .global)
            .onChanged { value in
                guard showDashboardCards else { return }
                guard value.startLocation.x <= 28 else { return }
                guard abs(value.translation.height) < 64 else { return }
                
                let translation = max(value.translation.width, 0)
                edgeBackGestureOffset = min(translation, 120)
            }
            .onEnded { value in
                guard showDashboardCards else { return }
                guard value.startLocation.x <= 28 else { return }
                guard abs(value.translation.height) < 96 else {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                        edgeBackGestureOffset = 0
                    }
                    return
                }
                
                let projectedTranslation = max(value.translation.width, value.predictedEndTranslation.width)
                if projectedTranslation >= edgeBackTriggerDistance {
                    collapseDashboard()
                    return
                }
                
                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                    edgeBackGestureOffset = 0
                }
            }
    }
    
    private func collapseDashboard() {
        withAnimation(dashboardTransition) {
            viewModel.closeExpandedCard()
            edgeBackGestureOffset = 0
            showDashboardCards = false
        }
    }
    
    // MARK: - 入口卡片
    private var gatewayCards: some View {
        HStack(spacing: 10) {
            gatewayCard(
                title: "我的数据",
                subtitle: "查看统计与趋势",
                iconName: "chart.bar.fill",
                accent: Color(hex: "#61C6FF"),
                type: .data
            )
            
            gatewayCard(
                title: "功能设置",
                subtitle: "系统偏好与权限",
                iconName: "slider.horizontal.3",
                accent: Color(hex: "#FF7A9B"),
                type: .settings
            )
        }
    }
    
    private func gatewayCard(
        title: String,
        subtitle: String,
        iconName: String,
        accent: Color,
        type: GatewayType
    ) -> some View {
        Button {
            selectedGateway = type
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            withAnimation(dashboardTransition) {
                showDashboardCards = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accent)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(accent.opacity(0.15))
                        )
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#95A0A7"))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(hex: "#F5F7F8"))
                        )
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(height: 122)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(hex: "#FFFFFF"))
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dashboardCardsGrid: some View {
        // 两列卡片布局 - 8个卡片，左右各4个
        // 美食足迹(timeline)放在右侧最下方
        HStack(alignment: .top, spacing: 8) {
            // 左列：4个卡片
            VStack(spacing: 8) {
                cardForId("stats")
                cardForId("consumption")
                cardForId("tags")
                cardForId("cuisine")
            }
            .frame(maxWidth: .infinity)
            
            // 右列：4个卡片 - timeline放在最下方
            VStack(spacing: 8) {
                cardForId("categories")
                cardForId("restaurants")
                cardForId("zodiac")
                cardForId("timeline")
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 功能设置面板
    private var settingsDashboard: some View {
        VStack(spacing: 10) {
            settingsSectionCard(
                title: "全局偏好",
                subtitle: "这些配置会影响整个 App 的默认行为"
            ) {
                VStack(spacing: 0) {
                    Menu {
                        Button("每次询问") { preferredMapApp = "" }
                        Button("苹果地图") { preferredMapApp = "apple" }
                        Button("高德地图") { preferredMapApp = "gaode" }
                        Button("百度地图") { preferredMapApp = "baidu" }
                    } label: {
                        settingsValueRow(
                            icon: "location.circle",
                            title: "默认导航应用",
                            value: preferredMapAppName,
                            accent: Color(hex: "#FF7A9B")
                        )
                    }

                    settingsRowDivider()
                    appearanceModeSegmentedRow
                    settingsRowDivider()

                    Toggle(isOn: $hapticFeedbackEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("震动反馈")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(settingsPrimaryTextColor)
                            Text("关闭后全局禁用轻震动与提示反馈")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(settingsSecondaryTextColor)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: settingsToggleTint))
                    .padding(.vertical, 12)
                }
            }

            settingsSectionCard(
                title: "数据与缓存",
                subtitle: "导入导出与统一缓存清理"
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    settingsActionButton(
                        icon: "trash.slash",
                        title: "清理所有缓存",
                        tint: Color(hex: "#E17055")
                    ) {
                        showClearCacheAlert = true
                    }

                    settingsRowDivider()
                    settingsActionButton(
                        icon: "square.and.arrow.down",
                        title: "导入餐厅数据",
                        tint: Color(hex: "#61C6FF")
                    ) {
                        showRestaurantImportAssistDialog = true
                    }

                    settingsRowDivider()
                    settingsActionButton(
                        icon: "square.and.arrow.up",
                        title: "导出餐厅数据",
                        tint: Color(hex: "#2ECC71")
                    ) {
                        exportRestaurantData()
                    }

                    settingsRowDivider()
                    settingsActionButton(
                        icon: "chart.bar.doc.horizontal",
                        title: "导出消费数据",
                        tint: Color(hex: "#9B59B6")
                    ) {
                        exportConsumptionData()
                    }

                    settingsRowDivider()
                    Toggle(isOn: $iCloudSyncEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("iCloud 同步")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(settingsPrimaryTextColor)
                            Text("建议开启 iCloud 同步，避免数据丢失并保持多设备一致。")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(settingsSecondaryTextColor)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: settingsToggleTint))
                    .padding(.vertical, 12)
                }
            }

            settingsSectionCard(
                title: "账户与安全",
                subtitle: "Apple ID 登录与面容 ID 保护"
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    accountStatusRow

                    if authManager.isSignedIn {
                        settingsRowDivider()
                        Toggle(isOn: faceIDEnabledBinding) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("开启面容 ID")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(settingsPrimaryTextColor)
                                Text(faceIDHintText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(settingsSecondaryTextColor)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: settingsToggleTint))
                        .padding(.vertical, 12)
                        .disabled(!appLockManager.isFaceIDAvailable)
                    } else {
                        settingsRowDivider()
                        settingsActionButton(
                            icon: "apple.logo",
                            title: "使用 Apple ID 登录",
                            tint: Color(hex: "#2D3436")
                        ) {
                            authManager.startSignIn()
                        }
                    }

                    if authManager.isSignedIn {
                        settingsRowDivider()
                        settingsActionButton(
                            icon: "arrow.triangle.2.circlepath",
                            title: "切换账户",
                            tint: Color(hex: "#5C8DFF")
                        ) {
                            showSwitchAccountAlert = true
                        }

                        settingsRowDivider()
                        settingsActionButton(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "退出账户",
                            tint: Color(hex: "#E17055"),
                            isDestructive: true
                        ) {
                            showSignOutAlert = true
                        }
                    }
                }
            }

            settingsSectionCard(
                title: "权限与支持",
                subtitle: "定位权限与系统入口"
            ) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#61C6FF"))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color(hex: "#61C6FF").opacity(0.14)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("定位权限")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(settingsPrimaryTextColor)
                        Text(locationPermissionText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(settingsSecondaryTextColor)
                    }

                    Spacer()

                    Button(locationPermissionActionTitle) {
                        handleLocationPermissionAction()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(settingsPrimaryTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(settingsPillBackground)
                            .overlay(
                                Capsule()
                                    .stroke(settingsPillBorder.opacity(0.86), lineWidth: 0.8)
                            )
                    )
                }
                .padding(.vertical, 2)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SettingsPanelOffsetPreferenceKey.self,
                    value: proxy.frame(in: .named("ProfileScrollArea")).minY
                )
            }
        )
    }

    private func settingsSectionCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(settingsPrimaryTextColor)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(settingsSecondaryTextColor)
            }

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(settingsCardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(settingsCardStroke, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(settingsCardInnerStroke, lineWidth: 0.5)
                        .padding(1.1)
                )
                .shadow(color: settingsCardShadow, radius: colorScheme == .dark ? 22 : 14, x: 0, y: colorScheme == .dark ? 10 : 6)
        )
        .transition(settingsPanelTransition)
        .animation(settingsSectionAnimation, value: showDashboardCards)
    }

    private func settingsRowDivider() -> some View {
        Rectangle()
            .fill(settingsSeparatorColor.opacity(colorScheme == .dark ? 0.84 : 1))
            .frame(height: 1)
            .padding(.leading, 38)
    }
    
    private var appearanceModeSegmentedRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#5C8DFF"))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(hex: "#5C8DFF").opacity(0.14))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("界面风格")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(settingsPrimaryTextColor)
                    Text(appearanceModeName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(settingsSecondaryTextColor)
                }
            }
            
            Spacer(minLength: 8)
            
            HStack(spacing: 4) {
                appearanceModeButton(mode: .light, icon: "sun.max.fill")
                appearanceModeButton(mode: .dark, icon: "moon.fill")
                appearanceModeButton(mode: .system, icon: "circle.lefthalf.filled")
            }
            .padding(3)
            .background(
                Capsule(style: .continuous)
                    .fill(settingsSegmentTrack)
            )
        }
        .padding(.vertical, 12)
    }
    
    private func appearanceModeButton(mode: AppAppearanceMode, icon: String) -> some View {
        let isActive = appAppearanceMode == mode.rawValue
        
        return Button {
            guard appAppearanceMode != mode.rawValue else { return }
            appAppearanceMode = mode.rawValue
            showSettingsToast("已切换为\(mode.displayName)")
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? settingsPrimaryTextColor : settingsSecondaryTextColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isActive ? settingsPillBackground : Color.clear)
                        .overlay(
                            Circle()
                                .stroke(isActive ? settingsPillBorder.opacity(0.82) : Color.clear, lineWidth: 0.8)
                        )
                        .shadow(
                            color: isActive ? settingsCardShadow.opacity(0.75) : Color.clear,
                            radius: isActive ? 8 : 0,
                            x: 0,
                            y: 3
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func settingsValueRow(
        icon: String,
        title: String,
        value: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(accent.opacity(0.14))
                )

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(settingsPrimaryTextColor)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(settingsTertiaryTextColor)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(settingsChevronColor)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func settingsActionButton(
        icon: String,
        title: String,
        tint: Color,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(tint.opacity(0.14)))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDestructive ? Color(hex: "#D63031") : settingsPrimaryTextColor)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(settingsChevronColor)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var accountStatusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#5C8DFF"))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color(hex: "#5C8DFF").opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("账户状态")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(settingsPrimaryTextColor)
                Text(authManager.isSignedIn ? authManager.displayLabel : "未登录 Apple ID")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(settingsSecondaryTextColor)
            }

            Spacer()

            Text(authManager.isSignedIn ? "已登录" : "未登录")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(authManager.isSignedIn ? Color(hex: "#2ECC71") : Color(hex: "#E17055"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(settingsPillBackground)
                        .overlay(
                            Capsule()
                                .stroke(settingsPillBorder.opacity(0.86), lineWidth: 0.8)
                        )
                )
        }
        .padding(.vertical, 12)
    }

    private var faceIDEnabledBinding: Binding<Bool> {
        Binding(
            get: { appLockManager.isFaceIDEnabled },
            set: { enabled in
                if enabled && !appLockManager.isFaceIDAvailable {
                    showSettingsToast("当前设备不支持面容 ID")
                    return
                }
                appLockManager.setFaceIDEnabled(enabled)
                showSettingsToast(enabled ? "面容 ID 已开启（冷启动验证）" : "面容 ID 已关闭")
            }
        )
    }

    private var faceIDHintText: String {
        if !appLockManager.isFaceIDAvailable {
            return "当前设备不可用，仅支持带 Face ID 的机型"
        }
        return "开启后 App 冷启动需要面容 ID 验证"
    }

    private var appleSignInSheet: some View {
        VStack(spacing: 18) {
            Text("登录 WhatToEat")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#2D3436"))

            Text("使用 Apple ID 登录以启用账户切换、面容 ID 与 iCloud 同步关联。")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#636E72"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                showSettingsToast(authManager.handleAuthorizationResult(result))
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 18)

            Button("稍后再说") {
                authManager.showSignInSheet = false
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(hex: "#636E72"))
        }
        .padding(.vertical, 22)
        .presentationDetents([.height(260)])
    }

    private var preferredMapAppName: String {
        switch preferredMapApp {
        case "apple":
            return "苹果地图"
        case "gaode":
            return "高德地图"
        case "baidu":
            return "百度地图"
        default:
            return "每次询问"
        }
    }

    private var appearanceModeName: String {
        let mode = AppAppearanceMode(rawValue: appAppearanceMode) ?? .system
        return mode.displayName
    }

    private var locationPermissionText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用 App 时允许"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限制"
        case .notDetermined:
            return "未请求"
        @unknown default:
            return "未知状态"
        }
    }

    private var locationPermissionActionTitle: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "请求权限"
        case .authorizedAlways, .authorizedWhenInUse:
            return "系统设置"
        case .denied, .restricted:
            return "去开启"
        @unknown default:
            return "系统设置"
        }
    }

    private func handleLocationPermissionAction() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestLocationPermission()
        default:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
    }

    private func handleICloudToggleChanged(to enabled: Bool) {
        if enabled {
            CloudSyncManager.shared.prepareMigrationPayloadIfNeeded(
                restaurants: restaurants,
                logs: visitLogs
            )
            UserDefaults.standard.set(false, forKey: AppSettingsKeys.didMigrateToICloud)
        }

        CloudSyncManager.shared.setICloudSyncEnabled(enabled)
        showSettingsToast(enabled ? "iCloud 同步已开启，重启后生效" : "iCloud 同步已关闭，重启后生效")
        showICloudRestartAlert = true
    }

    private func clearAllCaches() {
        Task {
            // 基础缓存
            URLCache.shared.removeAllCachedResponses()
            UserDefaults.standard.removeObject(forKey: AppSettingsKeys.searchHistory)
            UserDefaults.standard.set("{}", forKey: AppSettingsKeys.categoryCorrectionMap)
            PinyinMatcher.clearCache()
            AsyncImageLoader.clearCache()
            LocationManager.shared.clearCachedData()

            // 食签相关缓存
            await DailyRefreshManager.shared.resetAll()
            await JuheAPIService.shared.clearAllCache()
            await MainActor.run {
                AICopywritingManager.shared.clearFortuneCache()
                CSVImportManager.shared.reset()
                showSettingsToast("本地缓存已清理")
            }
        }
    }

    private func exportRestaurantTemplate() {
        let csv = DataCSVSupport.makeRestaurantTemplateCSV(defaultCity: defaultCity)
        exportDocument = CSVTextDocument(text: csv)
        exportFilename = DataCSVSupport.makeExportFilename(prefix: "whattoeat_restaurant_template")
        showExportSheet = true
    }

    private func handleRestaurantImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.pathExtension.lowercased() == "csv" else {
                showSettingsToast("导入失败：请选择 .csv 文件")
                return
            }

            showSettingsToast("开始导入餐厅数据...")
            Task {
                do {
                    let count = try await CSVImportManager.shared.importCSV(
                        from: url,
                        modelContext: modelContext,
                        defaultCity: defaultCity
                    )
                    showSettingsToast("导入完成：\(count) 家餐厅")
                } catch {
                    showSettingsToast("导入失败：\(error.localizedDescription)")
                }
            }

        case .failure(let error):
            showSettingsToast("导入失败：\(error.localizedDescription)")
        }
    }

    private func exportRestaurantData() {
        guard !restaurants.isEmpty else {
            showSettingsToast("暂无餐厅数据可导出")
            return
        }

        let csv = DataCSVSupport.makeRestaurantCSV(restaurants: restaurants)
        exportDocument = CSVTextDocument(text: csv)
        exportFilename = DataCSVSupport.makeExportFilename(prefix: "whattoeat_restaurants")
        showExportSheet = true
    }

    private func exportConsumptionData() {
        guard !visitLogs.isEmpty else {
            showSettingsToast("暂无消费数据可导出")
            return
        }

        let csv = DataCSVSupport.makeConsumptionCSV(logs: visitLogs)
        exportDocument = CSVTextDocument(text: csv)
        exportFilename = DataCSVSupport.makeExportFilename(prefix: "whattoeat_consumption")
        showExportSheet = true
    }

    private func handleDataExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            showSettingsToast("导出成功")
        case .failure(let error):
            showSettingsToast("导出失败：\(error.localizedDescription)")
        }
    }

    private func showSettingsToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            settingsToastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            guard settingsToastMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                settingsToastMessage = nil
            }
        }
    }

    private func settingsToastView(message: String) -> some View {
        VStack {
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(settingsPrimaryTextColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(settingsPillBackground)
                        .overlay(
                            Capsule()
                                .stroke(settingsPillBorder.opacity(0.86), lineWidth: 0.8)
                        )
                        .shadow(color: settingsCardShadow.opacity(0.82), radius: 10, x: 0, y: 3)
                )
            Spacer()
        }
        .padding(.top, 10)
    }
    
    // MARK: - Profile Header
    private func profileHeader(isCompact: Bool) -> some View {
        ZStack {
            if isCompact {
                compactProfileHeader
                    .transition(
                        .asymmetric(
                            insertion: .modifier(
                                active: BlurSlideTransitionModifier(yOffset: -10, blurRadius: 0, opacity: 0, scale: 0.95),
                                identity: BlurSlideTransitionModifier(yOffset: 0, blurRadius: 0, opacity: 1, scale: 1)
                            ),
                            removal: .modifier(
                                active: BlurSlideTransitionModifier(yOffset: 12, blurRadius: 0, opacity: 0, scale: 1.01),
                                identity: BlurSlideTransitionModifier(yOffset: 0, blurRadius: 0, opacity: 1, scale: 1)
                            )
                        )
                    )
            } else {
                expandedProfileHeader
                    .transition(
                        .asymmetric(
                            insertion: .modifier(
                                active: BlurSlideTransitionModifier(yOffset: 16, blurRadius: 0, opacity: 0, scale: 0.975),
                                identity: BlurSlideTransitionModifier(yOffset: 0, blurRadius: 0, opacity: 1, scale: 1)
                            ),
                            removal: .modifier(
                                active: BlurSlideTransitionModifier(yOffset: -12, blurRadius: 0, opacity: 0, scale: 0.965),
                                identity: BlurSlideTransitionModifier(yOffset: 0, blurRadius: 0, opacity: 1, scale: 1)
                            )
                        )
                    )
            }
        }
        .animation(headerTransitionAnimation, value: isCompact)
        .sheet(isPresented: $viewModel.showingEditProfile) {
            EditProfileView(userProfile: $viewModel.userProfile)
        }
    }

    // MARK: - 紧凑头部（给展开面板腾空间）
    private var compactProfileHeader: some View {
        let levelProgress = min(
            CGFloat(viewModel.totalCheckIns) / CGFloat(max(viewModel.getNextLevelRequirement(), 1)),
            1.0
        )
        let progressPercent = Int((levelProgress * 100).rounded())
        let levelTitle = "Lv.\(viewModel.calculateLevel()) · \(viewModel.getLevelTitle())"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    viewModel.showingEditProfile = true
                } label: {
                    profileAvatar(size: 48, shadowRadius: 10, shadowYOffset: 4, showsHalo: false)
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.userProfile.nickname)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsPrimaryTextColor)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(levelTitle)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(progressPercent)%")
                            .contentTransition(.numericText())
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settingsTertiaryTextColor)
                }

                Button {
                    viewModel.showingEditProfile = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(profileEditIconColor)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(profileSecondarySurfaceColor)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(profileProgressTrackColor)
                        .frame(height: 6)

                    Capsule()
                        .fill(profileProgressFillColor)
                        .frame(width: geometry.size.width * levelProgress, height: 6)
                        .animation(.spring(response: 0.45, dampingFraction: 0.84), value: levelProgress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(profileSurfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(profileStrokeColor.opacity(0.9), lineWidth: 0.9)
                )
                .shadow(color: profileHeaderShadowColor, radius: 12, x: 0, y: 5)
        )
        .matchedGeometryEffect(id: "profile-summary-card", in: animationNamespace)
    }

    // MARK: - 展开前头部（原始大头像名片）
    private var expandedProfileHeader: some View {
        // 使用屏幕宽度计算，确保头像尺寸正确
        let screenWidth = ScreenMetrics.bounds.width - 40  // 减去左右 padding(20)
        let avatarSize = screenWidth * 0.67
        let cardOverlap = avatarSize * 0.1
        let avatarTopOffset = avatarSize * 0.15
        let infoCardTopOffset = avatarTopOffset + avatarSize - cardOverlap
        let avatarOffsetInCard = avatarTopOffset - infoCardTopOffset
        let infoCardHeight: CGFloat = 164
        let containerHeight = infoCardTopOffset + infoCardHeight
        
        return ZStack(alignment: .top) {
            // Layer 2: 头像层（位于卡片后方）
            // 头像顶部与白色背景顶部对齐，向下偏移以露出部分头像
            avatarLayer(size: avatarSize)
                .zIndex(0)
                .offset(y: avatarTopOffset)
            
            // Layer 3: 毛玻璃信息卡片层
            // 卡片顶部位置 = 头像偏移 + 头像高度 - 卡片覆盖部分
            glassInfoCard(
                cardOverlap: cardOverlap,
                isCompact: false,
                cardHeight: infoCardHeight,
                avatarSize: avatarSize,
                avatarOffsetInCard: avatarOffsetInCard
            )
            .zIndex(1)
            .padding(.top, infoCardTopOffset)
        }
        .frame(maxWidth: .infinity, minHeight: containerHeight, maxHeight: containerHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(profileSurfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(profileStrokeColor.opacity(0.82), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: profileHeaderShadowColor.opacity(0.9), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - 头像层
    private func avatarLayer(size: CGFloat) -> some View {
        Button(action: {
            viewModel.showingEditProfile = true
        }) {
            ZStack {
                // 头像背景光晕
                profileAvatar(
                    size: size,
                    shadowRadius: 20,
                    shadowYOffset: 10,
                    showsHalo: true
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func profileAvatar(
        size: CGFloat,
        shadowRadius: CGFloat,
        shadowYOffset: CGFloat,
        showsHalo: Bool
    ) -> some View {
        ZStack {
            if showsHalo {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#FFB6C1").opacity(0.34),
                                Color(hex: "#FFC0CB").opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.22,
                            endRadius: size * 0.62
                        )
                    )
                    .frame(width: size * 1.16, height: size * 1.16)
                    .transition(.opacity)
            }

            Circle()
                .fill(profileSurfaceColor)
                .frame(width: size, height: size)
                .shadow(color: profileHeaderShadowColor.opacity(0.98), radius: shadowRadius, x: 0, y: shadowYOffset)
                .matchedGeometryEffect(id: "profile-avatar-shell", in: animationNamespace)

            avatarPhoto(size: size)
                .matchedGeometryEffect(id: "profile-avatar-image", in: animationNamespace)

            Circle()
                .stroke(profileAvatarRingColor, lineWidth: 3)
                .frame(width: size, height: size)
                .matchedGeometryEffect(id: "profile-avatar-ring", in: animationNamespace)
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .animation(profileAvatarAnimation, value: showDashboardCards)
    }
    
    @ViewBuilder
    private func avatarPhoto(size: CGFloat) -> some View {
        Group {
            if let avatarData = viewModel.userProfile.avatarData,
               let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(Color(hex: "#FFB6C1"))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    // MARK: - 毛玻璃信息卡片
    private func glassInfoCard(
        cardOverlap: CGFloat,
        isCompact: Bool,
        cardHeight: CGFloat,
        avatarSize: CGFloat,
        avatarOffsetInCard: CGFloat
    ) -> some View {
        let cornerRadius: CGFloat = isCompact ? 26 : 30
        let nameFont: CGFloat = isCompact ? 19 : 22
        let subtitleFont: CGFloat = isCompact ? 12 : 14
        let verificationFont: CGFloat = isCompact ? 12 : 14
        let percentageFont: CGFloat = isCompact ? 17 : 20
        let topInset: CGFloat = isCompact ? 18 : 20
        let nameSubtitleSpacing: CGFloat = isCompact ? 10 : 12
        let sectionTopInset: CGFloat = isCompact ? 12 : 16
        let barTopInset: CGFloat = isCompact ? 8 : 10
        let progressBarHeight: CGFloat = isCompact ? 6 : 6
        // 需求：进度条到底部间距 = 用户名到顶部间距
        let progressBottomInset: CGFloat = topInset
        let contentHorizontalInset: CGFloat = isCompact ? 18 : 20
        let overlapBlurHeight: CGFloat = max(cardOverlap - (isCompact ? 4 : 6), isCompact ? 22 : 26)
        let levelProgress = min(
            CGFloat(viewModel.totalCheckIns) / CGFloat(max(viewModel.getNextLevelRequirement(), 1)),
            1.0
        )
        let progressPercent = Int((levelProgress * 100).rounded())
        let levelTitle = "Lv.\(viewModel.calculateLevel()) · \(viewModel.getLevelTitle())"
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: nameSubtitleSpacing) {
                    Text(viewModel.userProfile.nickname)
                        .font(.system(size: nameFont, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsPrimaryTextColor)
                    
                    Text(viewModel.userProfile.bio)
                        .font(.system(size: subtitleFont, weight: .medium))
                        .foregroundStyle(profileSecondaryTextColor)
                }
                
                Spacer(minLength: 8)
                editButton(isCompact: isCompact)
            }
            .padding(.top, topInset)
            
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(levelTitle)
                    .font(.system(size: verificationFont, weight: .medium))
                    .foregroundStyle(profileMutedTextColor)
                
                Spacer()
                
                Text("\(progressPercent)%")
                    .font(.system(size: percentageFont, weight: .bold, design: .rounded))
                    .foregroundStyle(settingsPrimaryTextColor)
                    .contentTransition(.numericText())
            }
            .padding(.top, sectionTopInset)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(profileProgressTrackColor)
                        .frame(height: progressBarHeight)
                    
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(profileProgressFillColor)
                        .frame(width: geometry.size.width * levelProgress, height: progressBarHeight)
                        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: levelProgress)
                }
            }
            .frame(height: progressBarHeight)
            .padding(.top, barTopInset)
                .padding(.bottom, progressBottomInset)
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .padding(.horizontal, contentHorizontalInset)  // 内容边距
        .background(
            // 文本位于上层，模糊仅作用于底层背景
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(profileSurfaceColor)
                
                overlapBlurBand(
                    avatarSize: avatarSize,
                    avatarOffsetInCard: avatarOffsetInCard,
                    overlapBlurHeight: overlapBlurHeight
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(profileStrokeColor.opacity(0.8), lineWidth: 0.9)
        )
        .shadow(color: profileHeaderShadowColor.opacity(0.92), radius: 20, x: 0, y: 10)
        .matchedGeometryEffect(id: "profile-summary-card", in: animationNamespace)
        // 注意：不在卡片外部添加 padding，由 profileHeader 的调用方控制
    }
    
    private func overlapBlurBand(
        avatarSize: CGFloat,
        avatarOffsetInCard: CGFloat,
        overlapBlurHeight: CGFloat
    ) -> some View {
        ZStack(alignment: .top) {
            // 复制头像并做更强高斯模糊（仅背景层）
            avatarPhoto(size: avatarSize)
                .scaleEffect(1.06)
                .blur(radius: 34)
                .saturation(1.15)
                .opacity(0.34)
                .offset(y: avatarOffsetInCard)
            
            avatarPhoto(size: avatarSize)
                .scaleEffect(1.02)
                .blur(radius: 16)
                .saturation(1.06)
                .opacity(0.18)
                .offset(y: avatarOffsetInCard)
            
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: overlapBlurHeight)
                .opacity(colorScheme == .dark ? 0.08 : 0.01)
        }
        .frame(maxWidth: .infinity, minHeight: overlapBlurHeight, maxHeight: overlapBlurHeight, alignment: .top)
        .overlay(
            Rectangle()
                .fill(Color.adaptiveHex(light: "#FFFFFF", dark: "#223149").opacity(colorScheme == .dark ? 0.12 : 0.03))
        )
        .mask(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.98),
                            Color.black.opacity(0.98),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.98),
                            Color.black.opacity(0.86),
                            Color.black.opacity(0.38),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .allowsHitTesting(false)
    }
    
    // MARK: - 编辑按钮
    private func editButton(isCompact: Bool) -> some View {
        let iconSize: CGFloat = isCompact ? 16 : 18
        let buttonSize: CGFloat = isCompact ? 40 : 44
        
        return Button(action: {
            viewModel.showingEditProfile = true
        }) {
            Image(systemName: "pencil")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(profileEditIconColor)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(profileSecondarySurfaceColor)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Card Factory
    @ViewBuilder
    private func cardForId(_ id: String) -> some View {
        let size = cardSizes[id] ?? .medium(height: 180)
        
        switch id {
        case "stats":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { StatsCardPreview(viewModel: viewModel) },
                detail: { StatsCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "consumption":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { ConsumptionCardPreview(viewModel: viewModel) },
                detail: { ConsumptionCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "tags":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { TagsCardPreview(viewModel: viewModel) },
                detail: { TagsCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "categories":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { CategoriesCardPreview(viewModel: viewModel) },
                detail: { CategoriesCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "cuisine":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { CuisinePreferenceCardPreview(viewModel: viewModel) },
                detail: { CuisinePreferenceCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "restaurants":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { RestaurantsCardPreview(viewModel: viewModel) },
                detail: { RestaurantsCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "timeline":
            // 美食足迹卡片 - 点击直接打开打卡记录sheet，不使用hero动画
            TimelineCardPreview(viewModel: viewModel)
                .frame(height: size.fixedHeight) // 应用固定高度
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: "#FFFFFF"))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                )
                .onTapGesture {
                    // 触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    viewModel.showCheckInHistory = true
                }
                .sheet(isPresented: $viewModel.showCheckInHistory) {
                    CheckInHistoryView()
                }
            
        case "zodiac":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { ZodiacCardPreview(viewModel: viewModel) },
                detail: { ZodiacCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Expanded Card Overlay
    private func expandedCardOverlay(id: String) -> some View {
        let title = cardTitle(for: id)
        
        return ExpandedCardOverlay(
            id: id,
            title: title,
            content: {
                expandedContentForId(id)
            },
            isExpanded: .init(
                get: { viewModel.expandedCardId == id },
                set: { if !$0 { viewModel.closeExpandedCard() } }
            ),
            namespace: animationNamespace
        )
    }
    
    private func cardTitle(for id: String) -> String {
        switch id {
        case "stats": return "数据概览"
        case "consumption": return "消费洞察"
        case "tags": return "我的标签"
        case "categories": return "品类管理"
        case "cuisine": return "餐饮偏好"
        case "restaurants": return "常去餐厅"
        case "timeline": return "美食足迹"
        case "zodiac": return "味蕾星盘"
        default: return ""
        }
    }
    
    @ViewBuilder
    private func expandedContentForId(_ id: String) -> some View {
        switch id {
        case "stats":
            StatsCardDetail(viewModel: viewModel)
        case "consumption":
            ConsumptionCardDetail(viewModel: viewModel)
        case "tags":
            TagsCardDetail(viewModel: viewModel)
        case "categories":
            CategoriesCardDetail(viewModel: viewModel)
        case "cuisine":
            CuisinePreferenceCardDetail(viewModel: viewModel)
        case "restaurants":
            RestaurantsCardDetail(viewModel: viewModel)
        case "timeline":
            TimelineCardDetail(viewModel: viewModel)
        case "zodiac":
            ZodiacCardDetail(viewModel: viewModel)
        default:
            EmptyView()
        }
    }
}

// MARK: - Level Badge View
struct LevelBadgeView: View {
    let level: Int
    let checkIns: Int
    
    var levelInfo: (name: String, color: Color, hasGoldRim: Bool) {
        switch level {
        case 5: return ("米其林猎手", Color.purple, true)
        case 4: return ("美食家", Color.orange, true)
        case 3: return ("资深吃货", Color.blue, false)
        case 2: return ("吃货练习生", Color.green, false)
        default: return ("美食新手", Color.gray, false)
        }
    }
    
    var body: some View {
        let info = levelInfo
        
        HStack(spacing: 4) {
            Text(info.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundColor(info.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(info.color.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(
                    info.hasGoldRim ? Color.yellow.opacity(0.6) : info.color.opacity(0.3),
                    lineWidth: info.hasGoldRim ? 1.5 : 1
                )
        )
    }
}

private struct BlurSlideTransitionModifier: ViewModifier {
    let yOffset: CGFloat
    let blurRadius: CGFloat
    let opacity: Double
    let scale: CGFloat

    init(yOffset: CGFloat, blurRadius: CGFloat, opacity: Double, scale: CGFloat = 1) {
        self.yOffset = yOffset
        self.blurRadius = blurRadius
        self.opacity = opacity
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .offset(y: yOffset)
            .scaleEffect(scale, anchor: .top)
            .blur(radius: blurRadius)
            .opacity(opacity)
    }
}

private struct SettingsPanelOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Next Level Progress View
struct NextLevelProgressView: View {
    let currentLevel: Int
    let checkIns: Int
    let nextLevelRequirement: Int
    @State private var glowOpacity: Double = 0.5

    var progress: Double {
        if currentLevel >= 5 { return 1.0 }
        let prevLevelRequirement = getPrevLevelRequirement()
        let progressInCurrentLevel = Double(checkIns - prevLevelRequirement)
        let levelRange = Double(nextLevelRequirement - prevLevelRequirement)
        return min(progressInCurrentLevel / levelRange, 1.0)
    }

    var nextLevelName: String {
        switch currentLevel {
        case 1: return "吃货练习生"
        case 2: return "资深吃货"
        case 3: return "美食家"
        case 4: return "米其林猎手"
        default: return "已满级"
        }
    }

    private func getPrevLevelRequirement() -> Int {
        switch currentLevel {
        case 1: return 0
        case 2: return 10
        case 3: return 50
        case 4: return 100
        default: return 500
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if currentLevel >= 5 {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text("已满级")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            } else {
                Text(nextLevelName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGray)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.babyBlue, Color.white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 4)
                            .shadow(color: AppTheme.Colors.babyBlue.opacity(glowOpacity), radius: 4, x: 0, y: 0)
                    }
                }
                .frame(width: 60, height: 4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        glowOpacity = 0.8
                    }
                }

                Text("还需 \(nextLevelRequirement - checkIns) 次打卡")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(AppTheme.Colors.lightText)
            }
        }
        .frame(width: 80)
    }
}

// MARK: - User Profile
struct UserProfile: Codable {
    var nickname: String
    var bio: String
    var avatarData: Data?
    
    static let `default` = UserProfile(nickname: "美食探险家", bio: "今天吃什么？", avatarData: nil)
    
    static func load() -> UserProfile {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        return .default
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Binding var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    @State private var nickname: String = ""
    @State private var bio: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarData: Data?
    
    var body: some View {
        NavigationView {
            Form {
                Section("头像") {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.babyBlue.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                if let avatarData = avatarData,
                                   let uiImage = UIImage(data: avatarData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 96)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("基本信息") {
                    TextField("昵称", text: $nickname)
                    TextField("个性签名", text: $bio)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        userProfile.nickname = nickname
                        userProfile.bio = bio
                        userProfile.avatarData = avatarData
                        userProfile.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                nickname = userProfile.nickname
                bio = userProfile.bio
                avatarData = userProfile.avatarData
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
        }
    }
}
