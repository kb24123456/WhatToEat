//
//  ProfileView.swift
//  WhatToEat
//
//  完全重构的 ProfileView，采用 Masonry 瀑布流布局 + 原生导航转场
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
    @StateObject private var primeAccessManager = PrimeAccessManager.shared
    @AppStorage(AppSettingsKeys.userSelectedCity) private var defaultCity: String = "重庆"
    @AppStorage(AppSettingsKeys.appAppearanceMode) private var appAppearanceMode: String = AppAppearanceMode.system.rawValue
    @AppStorage(AppSettingsKeys.hapticFeedbackEnabled) private var hapticFeedbackEnabled: Bool = true
    @AppStorage(AppSettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled: Bool = true
    @AppStorage(AppSettingsKeys.primeOfferStartTimestamp) private var primeOfferStartTimestamp: Double = 0
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
    @State private var settingsTopBlurProgress: CGFloat = 0
    @State private var gatewayIndicatorScale: CGFloat = 1
    @State private var lastGatewayAnimationDirection: GatewayAnimationDirection = .next
    @State private var selectedMembershipPlan: MembershipPlan = .yearly
    
    // 卡片尺寸定义（精调后）
    // 左列总高度: 156 + 212 + 184 + 158 = 710pt
    // 右列总高度: 186 + 212 + 154 + 158 = 710pt
    private let cardSizes: [String: CardSize] = [
        "stats": .medium(height: 172),
        "consumption": .medium(height: 172),
        "tags": .medium(height: 172),
        "cuisine": .medium(height: 172),
        "categories": .medium(height: 172),
        "restaurants": .medium(height: 172),
        "timeline": .medium(height: 172),
        "zodiac": .medium(height: 172)
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

    private var dashboardSurfaceColor: Color {
        AppTheme.Colors.surfacePrimary
    }
    private var dashboardSecondarySurfaceColor: Color {
        AppTheme.Colors.surfacePrimary
    }
    private var dashboardHighlightStrokeColor: Color {
        AppTheme.Colors.rimLight.opacity(colorScheme == .dark ? 0.16 : 0.2)
    }
    private var dashboardStrokeColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.04 : 0.05)
    }
    private var dashboardShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.05 : 0.1)
    }

    private var settingsCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                colorScheme == .dark ? dashboardSurfaceColor : Color.adaptiveHex(light: "#FBFBFD", dark: "#1B2636"),
                colorScheme == .dark ? dashboardSurfaceColor : Color.adaptiveHex(light: "#F2F4F8", dark: "#141E2D")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var settingsCardStroke: Color { dashboardStrokeColor }

    private var settingsCardInnerStroke: Color {
        dashboardHighlightStrokeColor
    }

    private var settingsCardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.18) : dashboardShadowColor
    }

    private var settingsPrimaryTextColor: Color { AppTheme.Colors.darkText }
    private var settingsSecondaryTextColor: Color {
        Color.adaptiveHex(light: "#95A0A7", dark: "#A7B5C8")
    }
    private var settingsTertiaryTextColor: Color { Color.adaptiveHex(light: "#636E72", dark: "#ABB6C8") }
    private var settingsChevronColor: Color { Color.adaptiveHex(light: "#AAB2B9", dark: "#6F7E93") }
    private var settingsSeparatorColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
    private var settingsPillBackground: Color {
        Color.adaptiveHex(light: "#FFFFFF", dark: "#2E384A")
    }
    private var settingsPillBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : dashboardStrokeColor
    }
    private var settingsSegmentTrack: Color {
        Color.adaptiveHex(light: "#FFFFFF", dark: "#1A2230")
    }
    private var settingsToggleTint: Color {
        Color.adaptiveHex(light: "#1A1A1A", dark: "#2A3140")
    }

    private var profileSurfaceColor: Color { dashboardSurfaceColor }
    private var profileSecondarySurfaceColor: Color { dashboardSecondarySurfaceColor }
    private var profileStrokeColor: Color { dashboardStrokeColor }
    private var profileSecondaryTextColor: Color { Color.adaptiveHex(light: "#B2BEC3", dark: "#8F9CAF") }
    private var profileMutedTextColor: Color { Color.adaptiveHex(light: "#5E646B", dark: "#AAB6C7") }
    private var profileProgressTrackColor: Color { Color.adaptiveHex(light: "#E6E8EA", dark: "#232833") }
    private var profileProgressFillColor: Color { Color.adaptiveHex(light: "#1E2430", dark: "#E9EFF9") }
    private var profileAvatarRingColor: Color { dashboardHighlightStrokeColor }
    private var profileHeaderShadowColor: Color { dashboardShadowColor }
    private var profileEditIconColor: Color { Color.adaptiveHex(light: "#636E72", dark: "#B3BED0") }
    
    private let edgeBackTriggerDistance: CGFloat = 88

    private enum GatewayType {
        case data
        case settings
        case achievement
        case membership

        var title: String {
            switch self {
            case .data:
                return "我的数据"
            case .settings:
                return "功能设置"
            case .achievement:
                return "成就等级"
            case .membership:
                return "成为会员"
            }
        }
    }

    private enum GatewayAnimationDirection {
        case previous
        case next
    }

    private enum MembershipPlan: String, CaseIterable {
        case monthly
        case yearly
        case lifetime

        var title: String {
            switch self {
            case .monthly:
                return "月付"
            case .yearly:
                return "年付"
            case .lifetime:
                return "永久"
            }
        }

        var subtitle: String {
            switch self {
            case .monthly:
                return "先体验完整 Prime"
            case .yearly:
                return "长期记录更划算"
            case .lifetime:
                return "一次开通，长期使用"
            }
        }

        var accent: Color {
            switch self {
            case .monthly:
                return Color(hex: "#61C6FF")
            case .yearly:
                return Color(hex: "#8C7AE6")
            case .lifetime:
                return Color(hex: "#F6B93B")
            }
        }

        var primePlan: PrimeMembershipPlan {
            switch self {
            case .monthly:
                return .monthly
            case .yearly:
                return .yearly
            case .lifetime:
                return .lifetime
            }
        }
    }

    private struct MembershipOfferStatus {
        let isDiscountActive: Bool
        let remainingSeconds: Int
    }

    init() {
        _viewModel = State(initialValue: ProfileViewModel())
    }
    
    var body: some View {
        profileSceneWithPresentations
    }

    private var profileSceneWithPresentations: some View {
        profileSceneWithStateObservers
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

    private var profileSceneWithStateObservers: some View {
        NavigationStack {
            profileRootScene
        }
            .onAppear {
                viewModel.modelContext = modelContext
                viewModel.restaurants = restaurants
                
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
    }

    private var profileRootScene: some View {
        ZStack {
            DiffuseGradientBackground()
            profileScrollLayer
            profileOverlayLayers
        }
    }

    private var profileScrollLayer: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                ProfileScrollViewConfigurator(
                    shouldLockDirection: showDashboardCards && selectedGateway == .membership
                )
                .frame(height: 0)

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

                profileGatewayContent

                Color.clear.frame(height: showDashboardCards ? 40 : 20)
            }
            .animation(dashboardTransition, value: showDashboardCards)
        }
        .scrollBounceBehavior(.basedOnSize)
        .coordinateSpace(name: "ProfileScrollArea")
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
    }

    @ViewBuilder
    private var profileGatewayContent: some View {
        if showDashboardCards {
            expandedGatewayContent
                .padding(.horizontal, 24)
                .padding(.top, 6)
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
    }

    @ViewBuilder
    private var profileOverlayLayers: some View {
        if showDashboardCards && selectedGateway == .settings {
            settingsTopBlurOverlay
                .zIndex(50)
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
    
    private var collapseButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedGateway.title)
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

            gatewaySwitchBar
        }
    }

    private var gatewaySwitchBar: some View {
        HStack(spacing: 4) {
            ForEach(profileGatewayOptions, id: \.title) { gateway in
                gatewaySwitchButton(for: gateway)
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(settingsSegmentTrack)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(settingsPillBorder.opacity(0.42), lineWidth: 0.8)
                )
                .shadow(color: settingsCardShadow.opacity(0.36), radius: 8, x: 0, y: 3)
        )
    }

    private var profileGatewayOptions: [GatewayType] {
        [.data, .settings, .achievement, .membership]
    }

    private func gatewaySwitchButton(for gateway: GatewayType) -> some View {
        let isActive = selectedGateway == gateway

        return Button {
            switchExpandedGateway(to: gateway)
        } label: {
            Text(gateway.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? settingsPrimaryTextColor : settingsSecondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    ZStack {
                        if isActive {
                            Capsule()
                                .fill(settingsPillBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(settingsPillBorder.opacity(0.92), lineWidth: 0.8)
                                )
                                .shadow(
                                    color: settingsCardShadow.opacity(0.7),
                                    radius: 10,
                                    x: 0,
                                    y: 4
                                )
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .scaleEffect(gatewayIndicatorScale)
                                .matchedGeometryEffect(id: "profile-gateway-indicator", in: animationNamespace)
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var expandedGatewayContent: some View {
        switch selectedGateway {
        case .data:
            dashboardCardsGrid
                .id(selectedGateway.title)
                .transition(gatewayContentTransition)
        case .settings:
            settingsDashboard
                .id(selectedGateway.title)
                .transition(gatewayContentTransition)
        case .achievement:
            achievementDashboard
                .id(selectedGateway.title)
                .transition(gatewayContentTransition)
        case .membership:
            membershipDashboard
                .id(selectedGateway.title)
                .transition(gatewayContentTransition)
        }
    }

    private var gatewayContentTransition: AnyTransition {
        switch lastGatewayAnimationDirection {
        case .next:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .previous:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private var settingsPanelTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
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
            .onEnded { value in
                guard showDashboardCards else { return }
                guard value.startLocation.x <= 28 else { return }
                guard abs(value.translation.height) < 96 else { return }

                let projectedTranslation = max(value.translation.width, value.predictedEndTranslation.width)
                if projectedTranslation >= edgeBackTriggerDistance {
                    collapseDashboard()
                }
            }
    }
    
    private func collapseDashboard() {
        withAnimation(dashboardTransition) {
            showDashboardCards = false
        }
    }

    private func switchExpandedGateway(to gateway: GatewayType) {
        guard selectedGateway != gateway else { return }
        if let currentIndex = profileGatewayOptions.firstIndex(of: selectedGateway),
           let targetIndex = profileGatewayOptions.firstIndex(of: gateway) {
            lastGatewayAnimationDirection = targetIndex > currentIndex ? .next : .previous
        }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        animateGatewayIndicatorBounce()

        withAnimation(dashboardTransition) {
            settingsTopBlurProgress = 0
            selectedGateway = gateway
        }
    }

    private func animateGatewayIndicatorBounce() {
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.82, blendDuration: 0.08)) {
            gatewayIndicatorScale = 0.94
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.78, blendDuration: 0.1)) {
                gatewayIndicatorScale = 1
            }
        }
    }
    
    // MARK: - 入口卡片
    private var gatewayCards: some View {
        VStack(spacing: 10) {
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

            HStack(spacing: 10) {
                gatewayCard(
                    title: "成就等级",
                    subtitle: "查看成长进度",
                    iconName: "medal.star.fill",
                    accent: Color(hex: "#F6B93B"),
                    type: .achievement
                )

                gatewayCard(
                    title: "成为会员",
                    subtitle: "解锁专属权益",
                    iconName: "sparkles.rectangle.stack.fill",
                    accent: Color(hex: "#8C7AE6"),
                    type: .membership
                )
            }
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
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            withAnimation(dashboardTransition) {
                selectedGateway = type
                settingsTopBlurProgress = 0
                showDashboardCards = true
            }
        } label: {
            gatewayCardLabel(
                title: title,
                subtitle: subtitle,
                iconName: iconName,
                accent: accent
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func gatewayCardLabel(
        title: String,
        subtitle: String,
        iconName: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(accent.opacity(0.15))
                    )

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(settingsSecondaryTextColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(dashboardSecondarySurfaceColor)
                    )
            }

            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(settingsPrimaryTextColor)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(settingsSecondaryTextColor)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 122)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(dashboardSurfaceColor)
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(dashboardHighlightStrokeColor, lineWidth: 0.5)
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(dashboardStrokeColor, lineWidth: 0.5)
                    }
                )
                .shadow(color: dashboardShadowColor, radius: colorScheme == .dark ? 10 : 12, x: 0, y: colorScheme == .dark ? 4 : 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var dashboardCardsGrid: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 8) {
                cardForId("stats")
                cardForId("categories")
                cardForId("cuisine")
                cardForId("restaurants")
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 8) {
                cardForId("consumption")
                cardForId("tags")
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
                title: "全局偏好"
            ) {
                VStack(spacing: 0) {
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
                title: "数据与缓存"
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
                title: "账户与安全"
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    accountStatusRow

                    settingsRowDivider()
                    faceIDSettingsRow

                    if !authManager.isSignedIn {
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
                title: "权限与支持"
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

    private var achievementDashboard: some View {
        let currentLevel = viewModel.calculateLevel()
        let progress = CGFloat(viewModel.getLevelProgress())
        let scoreBreakdown = viewModel.growthScoreBreakdown

        return VStack(spacing: 10) {
            achievementHeroCard(
                currentLevel: currentLevel,
                progress: progress,
                scoreBreakdown: scoreBreakdown
            )

            settingsSectionCard(title: "成长轨迹") {
                achievementMainPage(currentLevel: currentLevel, scoreBreakdown: scoreBreakdown)
            }

            settingsSectionCard(title: "成长说明") {
                VStack(alignment: .leading, spacing: 10) {
                    profileNoteRow(
                        icon: "sparkles",
                        tint: Color(hex: "#F6B93B"),
                        title: "成长依据",
                        body: "总等级以打卡次数为主，同时吸收餐厅沉淀与消费记录作为成长加成，统一汇总成综合成长指数。"
                    )
                    profileNoteRow(
                        icon: "trophy.fill",
                        tint: Color(hex: "#61C6FF"),
                        title: "成就节奏",
                        body: "主线等级会先快速建立反馈，后续再逐渐放缓，让成长更接近长期记录而不是短期冲刺。"
                    )
                }
            }
        }
    }

    private var membershipDashboard: some View {
        VStack(spacing: 10) {
            membershipHeroCard

            settingsSectionCard(title: "选择方案") {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let offerStatus = currentMembershipOfferStatus(at: context.date)

                    VStack(alignment: .leading, spacing: 14) {
                        if offerStatus.isDiscountActive {
                            membershipOfferBanner(offerStatus: offerStatus)
                        }

                        GeometryReader { proxy in
                            let cardWidth = max((proxy.size.width - 20) / 3, 0)

                            HStack(spacing: 10) {
                                ForEach(MembershipPlan.allCases, id: \.rawValue) { plan in
                                    membershipPlanCard(
                                        plan: plan,
                                        offerStatus: offerStatus,
                                        width: cardWidth
                                    )
                                }
                            }
                        }
                        .frame(height: 94)

                        Button {
                            handleMembershipPurchase(selectedMembershipPlan, offerStatus: offerStatus)
                        } label: {
                            Text(membershipCTAButtonTitle(for: selectedMembershipPlan))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color.black)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            handleMembershipRestore()
                        } label: {
                            Text("恢复购买")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(settingsSecondaryTextColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsSectionCard(title: "解锁 7 项 Prime 权益") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(membershipBenefits.indices, id: \.self) { index in
                        let benefit = membershipBenefits[index]
                        membershipBenefitCompactRow(
                            icon: benefit.icon,
                            tint: benefit.tint,
                            title: benefit.title
                        )

                        if index != membershipBenefits.indices.last {
                            settingsRowDivider()
                        }
                    }
                }
            }
        }
    }

    private func settingsSectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(settingsPrimaryTextColor)

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(settingsCardGradient)
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(settingsCardInnerStroke, lineWidth: 0.5)
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(settingsCardStroke, lineWidth: 0.5)
                    }
                )
                .shadow(color: settingsCardShadow, radius: colorScheme == .dark ? 10 : 14, x: 0, y: colorScheme == .dark ? 4 : 6)
        )
        .animation(settingsSectionAnimation, value: selectedGateway)
    }

    private func achievementHeroCard(
        currentLevel: Int,
        progress: CGFloat,
        scoreBreakdown: ProfileViewModel.GrowthScoreBreakdown
    ) -> some View {
        let compositeScore = scoreBreakdown.totalScore
        let levelGap = viewModel.growthGapToNextLevel()

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("综合成长")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#B9770E"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.72))
                        )

                    Text("Lv.\(currentLevel) · \(viewModel.getLevelTitle())")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsPrimaryTextColor)

                    Text(viewModel.getLevelSummary())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(settingsSecondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("成长指数")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(settingsSecondaryTextColor)
                    Text("\(compositeScore)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsPrimaryTextColor)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("主线升级进度")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(settingsPrimaryTextColor)
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsPrimaryTextColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.42))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#F6B93B"), Color(hex: "#F8C471"), Color(hex: "#61C6FF")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 10)

                Text(currentLevel >= 7 ? "你已经到达当前成长体系的最高等级，接下来更适合继续打磨餐厅与消费分支。"
                     : "距下一等级还差 \(levelGap) 成长值，再沉淀一些记录与消费轨迹，即将进入下一阶段。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(settingsSecondaryTextColor)
            }

        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.adaptiveHex(light: "#FFF8E8", dark: "#2B2414"),
                            Color.adaptiveHex(light: "#FFF2D9", dark: "#201C13"),
                            Color.adaptiveHex(light: "#F7F8FC", dark: "#161B26")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.5), lineWidth: 0.8)
                )
                .shadow(color: dashboardShadowColor.opacity(0.9), radius: 16, x: 0, y: 8)
        )
    }

    private var membershipBenefits: [(icon: String, tint: Color, title: String, body: String)] {
        [
            ("infinity", Color(hex: "#F6B93B"), "无限制餐厅数量", "不再担心记录越多越接近上限，把 WhatToEat 真正当成长期数据库来使用。"),
            ("map.fill", Color(hex: "#61C6FF"), "美食地图与洞察", "把记录从列表变成地图与足迹，看到城市分布、探索轨迹和个人偏好。"),
            ("arrow.trianglehead.2.clockwise.rotate.90.icloud.fill", Color(hex: "#8C7AE6"), "同步、备份与恢复", "让你的数据不再只停留在一台设备里，也降低意外丢失记录的风险。"),
            ("square.and.arrow.up.fill", Color(hex: "#2ECC71"), "导出与迁移", "随时导出餐厅、消费与标签数据，让美食记录成为可保存、可迁移的个人资产。"),
            ("rectangle.stack.badge.person.crop.fill", Color(hex: "#F39C12"), "批量管理", "为重度用户准备更高效的整理能力，批量编辑、归类与维护长期积累的餐厅库。"),
            ("faceid", Color(hex: "#5C8DFF"), "Prime 专属面容 ID", "为 App 冷启动增加面容 ID 验证，让长期记录更私密、更安心。"),
            ("sparkles.rectangle.stack.fill", Color(hex: "#E7A8B8"), "Prime 标识与食签", "保留一点属于 Prime 的专属感，在长期记录之外，也拥有恰到好处的仪式感。")
        ]
    }

    private var membershipHeroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("WhatToEat Prime")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color(hex: "#5D4D2C"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.76))
                    )

                    Text("把吃过的地方，沉淀成你自己的美食资产")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsPrimaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("解锁无限餐厅容量、地图洞察、同步备份与导出能力，让每一次记录都能长期保存、持续生长。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(settingsSecondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                membershipHighlightPill(title: "无限容量", tint: Color(hex: "#F6B93B"))
                membershipHighlightPill(title: "地图洞察", tint: Color(hex: "#61C6FF"))
                membershipHighlightPill(title: "同步导出", tint: Color(hex: "#8C7AE6"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Prime 首先是一组长期能力，同时也会优先支持 WhatToEat 继续迭代同步、地图与数据能力。")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(settingsSecondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.adaptiveHex(light: "#FAFBFF", dark: "#1D2330"),
                            Color.adaptiveHex(light: "#F8F3EA", dark: "#241F18"),
                            Color.adaptiveHex(light: "#F4F6FB", dark: "#171D2A")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .center) {
                    membershipDotPattern
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.55), lineWidth: 0.8)
                )
                .shadow(color: dashboardShadowColor.opacity(0.9), radius: 16, x: 0, y: 8)
        )
    }

    private var membershipDotPattern: some View {
        Canvas { context, size in
            let dotColor = Color.black.opacity(colorScheme == .dark ? 0.08 : 0.045)
            let spacing: CGFloat = 20
            for x in stride(from: spacing / 2, through: size.width, by: spacing) {
                for y in stride(from: spacing / 2, through: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: 2.2, height: 2.2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func membershipHighlightPill(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.76))
            )
    }

    private func membershipOfferBanner(offerStatus: MembershipOfferStatus) -> some View {
        ViewThatFits(in: .vertical) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日限时 5 折")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsPrimaryTextColor)

                    Text("距恢复原价还剩 \(formattedCountdown(offerStatus.remainingSeconds))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(settingsSecondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                Spacer(minLength: 0)

                membershipOfferBadge
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日限时 5 折")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsPrimaryTextColor)

                    Text("距恢复原价还剩 \(formattedCountdown(offerStatus.remainingSeconds))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(settingsSecondaryTextColor)
                }

                membershipOfferBadge
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.68))
        )
    }

    private var membershipOfferBadge: some View {
        Text("50% OFF")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "#B9770E"))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(hex: "#FFF1C9"))
            )
    }

    private func membershipPlanCard(
        plan: MembershipPlan,
        offerStatus: MembershipOfferStatus,
        width: CGFloat
    ) -> some View {
        let isSelected = selectedMembershipPlan == plan
        let isDiscountActive = offerStatus.isDiscountActive
        let currentPrice = membershipPrice(for: plan, isDiscountActive: isDiscountActive)
        let originalPrice = membershipPrice(for: plan, isDiscountActive: false)

        return Button {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.08)) {
                selectedMembershipPlan = plan
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("¥\(currentPrice)")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.white : settingsPrimaryTextColor)
                    }

                    if isDiscountActive {
                        Text("原价 ¥\(originalPrice)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.62) : settingsSecondaryTextColor)
                            .strikethrough()
                    }

                    Text(plan.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : settingsPrimaryTextColor)

                    Text(membershipPlanFooterText(for: plan, isDiscountActive: isDiscountActive))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : settingsSecondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: width, height: 94, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color.black, Color(hex: "#1A1A1A")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(settingsCardGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                isSelected ? plan.accent.opacity(0.9) : settingsPillBorder.opacity(0.45),
                                lineWidth: isSelected ? 1.2 : 0.8
                            )
                    )
                    .shadow(color: isSelected ? plan.accent.opacity(0.22) : dashboardShadowColor.opacity(0.45), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
    }

    private func membershipBenefitCompactRow(
        icon: String,
        tint: Color,
        title: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(settingsPrimaryTextColor)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(settingsPrimaryTextColor)

            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(tint.opacity(0.92))
        }
        .padding(.vertical, 14)
    }

    private func currentMembershipOfferStatus(at date: Date) -> MembershipOfferStatus {
        guard primeOfferStartTimestamp > 0 else {
            return MembershipOfferStatus(isDiscountActive: false, remainingSeconds: 0)
        }

        let startDate = Date(timeIntervalSince1970: primeOfferStartTimestamp)
        let remaining = max(0, 1800 - Int(date.timeIntervalSince(startDate)))
        return MembershipOfferStatus(isDiscountActive: remaining > 0, remainingSeconds: remaining)
    }

    private func membershipPrice(for plan: MembershipPlan, isDiscountActive: Bool) -> Int {
        switch (plan, isDiscountActive) {
        case (.monthly, true):
            return 3
        case (.monthly, false):
            return 6
        case (.yearly, true):
            return 10
        case (.yearly, false):
            return 20
        case (.lifetime, true):
            return 15
        case (.lifetime, false):
            return 30
        }
    }

    private func membershipPlanFooterText(for plan: MembershipPlan, isDiscountActive: Bool) -> String {
        switch plan {
        case .monthly:
            return "先体验完整 Prime"
        case .yearly:
            return "长期记录更划算"
        case .lifetime:
            return "一次开通，长期使用"
        }
    }

    private func membershipCTAButtonTitle(for plan: MembershipPlan) -> String {
        switch plan {
        case .monthly:
            return "按月开通 Prime"
        case .yearly:
            return "按年开通 Prime"
        case .lifetime:
            return "永久解锁 Prime"
        }
    }

    private func formattedCountdown(_ remainingSeconds: Int) -> String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        let minuteString = minutes.formatted(.number.precision(.integerLength(2)))
        let secondString = seconds.formatted(.number.precision(.integerLength(2)))
        return "\(minuteString):\(secondString)"
    }

    private func handleMembershipPurchase(_ plan: MembershipPlan, offerStatus: MembershipOfferStatus) {
        let price = membershipPrice(for: plan, isDiscountActive: offerStatus.isDiscountActive)
        let offerPrefix = offerStatus.isDiscountActive ? "限时优惠" : "当前价格"
        primeAccessManager.activate(plan.primePlan)
        showSettingsToast("已模拟开通\(plan.title) Prime（\(offerPrefix) ¥\(price)），真实支付接口待接入")
    }

    private func handleMembershipRestore() {
        let restored = primeAccessManager.restore()
        showSettingsToast(restored ? "已恢复本机 Prime 状态，真实恢复购买接口待接入" : "当前没有可恢复的 Prime 记录")
    }

    private func achievementMainPage(
        currentLevel: Int,
        scoreBreakdown: ProfileViewModel.GrowthScoreBreakdown
    ) -> some View {
        let nextRequirement = viewModel.getNextLevelRequirement()
        let currentFloor = viewModel.getCurrentLevelFloor()
        let growthGap = viewModel.growthGapToNextLevel()

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 10) {
                    achievementFormulaMetric(
                        title: "打卡主贡献",
                        stat: "\(viewModel.totalCheckIns) 次",
                        score: scoreBreakdown.checkInScore,
                        tint: Color(hex: "#F6B93B"),
                        detail: "每次打卡稳定累计成长值，是主线升级的核心来源。"
                    )
                    achievementFormulaMetric(
                        title: "餐厅加成",
                        stat: "\(viewModel.totalRestaurants) 家",
                        score: scoreBreakdown.restaurantScore,
                        tint: Color(hex: "#7BC8A4"),
                        detail: "收藏与维护的餐厅越丰富，越能体现你的长期沉淀。"
                    )
                    achievementFormulaMetric(
                        title: "消费加成",
                        stat: viewModel.formatCurrency(viewModel.totalExpense),
                        score: scoreBreakdown.expenseScore,
                        tint: Color(hex: "#E7A8B8"),
                        detail: "消费采用递减增长，强调持续投入而不是单次高消费。"
                    )
                }

                settingsRowDivider()
                    .padding(.leading, 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(scoreBreakdown.totalScore) / \(max(nextRequirement, scoreBreakdown.totalScore))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsPrimaryTextColor)

                    Text(currentLevel >= 7
                         ? "你已位于当前成长体系顶点，主线等级封顶后会更多体现为稳定记录与分支沉淀。"
                         : "当前等级区间从 \(currentFloor) 到 \(nextRequirement) 成长值；距下一等级还差 \(growthGap) 点。")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(settingsSecondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func achievementFormulaMetric(
        title: String,
        stat: String,
        score: Int,
        tint: Color,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settingsPrimaryTextColor)

                Spacer(minLength: 8)

                Text(stat)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(settingsSecondaryTextColor)

                Text("+\(score)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }

            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(settingsSecondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var expenseMetricText: String {
        if viewModel.totalExpense >= 10000 {
            return String(format: "%.1fw", viewModel.totalExpense / 10000)
        }
        return String(format: "%.0f", viewModel.totalExpense)
    }

    private func profileNoteRow(
        icon: String,
        tint: Color,
        title: String,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(settingsPrimaryTextColor)

                Text(body)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(settingsSecondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
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
                if enabled && !primeAccessManager.isPrimeActive {
                    showSettingsToast("面容 ID 为 Prime 专属功能")
                    withAnimation(settingsSectionAnimation) {
                        selectedGateway = .membership
                    }
                    return
                }
                if enabled && !authManager.isSignedIn {
                    showSettingsToast("请先登录 Apple ID 再启用面容 ID")
                    authManager.startSignIn()
                    return
                }
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
        if !primeAccessManager.isPrimeActive {
            return "Prime 专属功能，开通后可为 App 冷启动增加面容 ID 验证"
        }
        if !authManager.isSignedIn {
            return "Prime 已开通，请先登录 Apple ID 后再启用"
        }
        if !appLockManager.isFaceIDAvailable {
            return "当前设备不可用，仅支持带 Face ID 的机型"
        }
        return "开启后 App 冷启动需要面容 ID 验证"
    }

    private var faceIDSettingsRow: some View {
        Group {
            if primeAccessManager.isPrimeActive {
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
                .disabled(!authManager.isSignedIn || !appLockManager.isFaceIDAvailable)
            } else {
                Button {
                    showSettingsToast("面容 ID 为 Prime 专属功能")
                    withAnimation(settingsSectionAnimation) {
                        selectedGateway = .membership
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#5C8DFF"))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color(hex: "#5C8DFF").opacity(0.14)))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("开启面容 ID")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(settingsPrimaryTextColor)
                            Text(faceIDHintText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(settingsSecondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Text("Prime 专属")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#B9770E"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#FFF1C9"))
                            )

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(settingsChevronColor)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appleSignInSheet: some View {
        VStack(spacing: 18) {
            Text("登录 WhatToEat")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#2D3436"))

            Text("使用 Apple ID 登录以启用账户切换、iCloud 同步，以及 Prime 面容 ID 验证。")
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
        let levelProgress = CGFloat(viewModel.getLevelProgress())
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(dashboardHighlightStrokeColor, lineWidth: 0.5)
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(profileStrokeColor, lineWidth: 0.5)
                    }
                )
                .shadow(color: profileHeaderShadowColor, radius: 10, x: 0, y: 4)
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(dashboardHighlightStrokeColor, lineWidth: 0.5)
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(profileStrokeColor, lineWidth: 0.5)
                    }
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: profileHeaderShadowColor.opacity(0.9), radius: 10, x: 0, y: 4)
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
        let levelProgress = CGFloat(viewModel.getLevelProgress())
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
                .stroke(profileStrokeColor, lineWidth: 0.5)
        )
        .shadow(color: profileHeaderShadowColor.opacity(0.92), radius: 10, x: 0, y: 4)
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
                namespace: animationNamespace
            )
            
        case "consumption":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { ConsumptionCardPreview(viewModel: viewModel) },
                detail: { ConsumptionCardDetail(viewModel: viewModel) },
                namespace: animationNamespace
            )
            
        case "tags":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { TagsCardPreview(viewModel: viewModel) },
                detail: { TagsCardDetail(viewModel: viewModel) },
                namespace: animationNamespace
            )
            
        case "categories":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { CategoriesCardPreview(viewModel: viewModel) },
                detail: { CategoriesCardDetail(viewModel: viewModel) },
                namespace: animationNamespace
            )
            
        case "cuisine":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { CuisinePreferenceCardPreview(viewModel: viewModel) },
                detail: { CuisinePreferenceCardDetail(viewModel: viewModel) },
                namespace: animationNamespace
            )
            
        case "restaurants":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { RestaurantsCardPreview(viewModel: viewModel) },
                detail: { RestaurantsCardDetail(viewModel: viewModel) },
                namespace: animationNamespace
            )
            
        case "timeline":
            ZoomNavigationCard(
                id: id,
                cardSize: size,
                preview: { TimelineCardPreview(viewModel: viewModel) },
                destination: {
                    if let container = viewModel.modelContext?.container {
                        CheckInHistoryView()
                            .modelContainer(container)
                    } else {
                        CheckInHistoryView()
                    }
                },
                namespace: animationNamespace
            )
            
        case "zodiac":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { ZodiacCardPreview(viewModel: viewModel) },
                detail: { ZodiacCardDetail(viewModel: viewModel) },
                namespace: animationNamespace
            )
            
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

private struct ProfileScrollViewConfigurator: UIViewRepresentable {
    let shouldLockDirection: Bool

    func makeUIView(context: Context) -> UIView {
        let view = ScrollConfigProbeView()
        view.shouldLockDirection = shouldLockDirection
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let probe = uiView as? ScrollConfigProbeView {
            probe.shouldLockDirection = shouldLockDirection
            probe.applyConfigurationIfPossible()
        }
    }
}

private final class ScrollConfigProbeView: UIView {
    var shouldLockDirection = false
    private var contentOffsetObservation: NSKeyValueObservation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        applyConfigurationIfPossible()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyConfigurationIfPossible()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyConfigurationIfPossible()
    }

    func applyConfigurationIfPossible() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let scrollView = self.enclosingScrollView() else { return }
            scrollView.alwaysBounceHorizontal = false
            scrollView.isDirectionalLockEnabled = self.shouldLockDirection
            scrollView.bounces = true

            if self.shouldLockDirection {
                self.installHorizontalLockIfNeeded(on: scrollView)
            } else {
                self.contentOffsetObservation?.invalidate()
                self.contentOffsetObservation = nil
            }
        }
    }

    private func installHorizontalLockIfNeeded(on scrollView: UIScrollView) {
        guard contentOffsetObservation == nil else { return }

        contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak scrollView] _, _ in
            guard let scrollView else { return }
            let lockedX = -scrollView.adjustedContentInset.left
            guard abs(scrollView.contentOffset.x - lockedX) > 0.5 else { return }

            var offset = scrollView.contentOffset
            offset.x = lockedX
            scrollView.setContentOffset(offset, animated: false)
        }
    }

    private func enclosingScrollView() -> UIScrollView? {
        var current = superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView {
                return scrollView
            }
            current = candidate.superview
        }
        return nil
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
    @State private var avatarData: Data?
    @State private var showPhotoLibraryPicker = false
    @State private var pendingAvatarSelection: PendingAvatarSelection?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("头像") {
                    HStack {
                        Spacer()
                        Button {
                            showPhotoLibraryPicker = true
                        } label: {
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
                        .buttonStyle(PlainButtonStyle())
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
            .sheet(isPresented: $showPhotoLibraryPicker) {
                AvatarPhotoLibraryPicker { image in
                    pendingAvatarSelection = PendingAvatarSelection(image: image.normalized())
                }
            }
            .fullScreenCover(item: $pendingAvatarSelection) { selection in
                AvatarCropView(
                    sourceImage: selection.image,
                    onCancel: {
                        pendingAvatarSelection = nil
                    },
                    onConfirm: { croppedImage in
                        avatarData = croppedImage.jpegData(compressionQuality: 0.92)
                        pendingAvatarSelection = nil
                    }
                )
            }
        }
    }
}

private struct PendingAvatarSelection: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct AvatarPhotoLibraryPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                picker.dismiss(animated: true)
                return
            }

            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    picker.dismiss(animated: true) {
                        if let image = object as? UIImage {
                            self.onImagePicked(image)
                        }
                    }
                }
            }
        }
    }
}

private struct AvatarCropView: View {
    let sourceImage: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var currentScale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var currentOffset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    private let minimumScale: CGFloat = 1
    private let maximumScale: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let cropSize = min(geometry.size.width - 72, geometry.size.height * 0.42)
            let imageState = cropImageState(for: cropSize, scale: currentScale)

            ZStack {
                Color.black.opacity(0.96)
                    .ignoresSafeArea()

                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .blur(radius: 44)
                    .opacity(0.18)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    cropHeader(cropSize: cropSize, topInset: max(geometry.safeAreaInsets.top, 18))

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: cropSize, height: cropSize)

                        Image(uiImage: sourceImage)
                            .resizable()
                            .frame(width: imageState.width, height: imageState.height)
                            .offset(currentOffset)
                            .gesture(
                                SimultaneousGesture(
                                    dragGesture(cropSize: cropSize),
                                    magnificationGesture(cropSize: cropSize)
                                )
                            )
                    }
                    .frame(width: cropSize, height: cropSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.94), lineWidth: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.16), lineWidth: 12)
                            .blur(radius: 18)
                    )
                    .shadow(color: Color.black.opacity(0.34), radius: 28, x: 0, y: 16)

                    VStack(spacing: 10) {
                        Text("拖动与缩放，调整圆形头像取景范围")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))

                        Text("保存后将按圆形头像框显示")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.56))
                    }
                    .padding(.top, 34)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func cropHeader(cropSize: CGFloat, topInset: CGFloat) -> some View {
        HStack {
            cropHeaderButton(title: "取消", action: onCancel)

            Spacer()

            Text("裁剪头像")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white)

            Spacer()

            cropHeaderButton(title: "确认") {
                guard let croppedImage = renderCroppedAvatar(cropSize: cropSize) else { return }
                onConfirm(croppedImage)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, topInset)
    }

    private func cropHeaderButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func dragGesture(cropSize: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                currentOffset = clampedOffset(for: proposed, cropSize: cropSize, scale: currentScale)
            }
            .onEnded { value in
                let proposed = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                let clamped = clampedOffset(for: proposed, cropSize: cropSize, scale: currentScale)
                committedOffset = clamped
                currentOffset = clamped
            }
    }

    private func magnificationGesture(cropSize: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let nextScale = min(max(committedScale * value, minimumScale), maximumScale)
                currentScale = nextScale
                let clamped = clampedOffset(for: currentOffset, cropSize: cropSize, scale: nextScale)
                currentOffset = clamped
            }
            .onEnded { value in
                let nextScale = min(max(committedScale * value, minimumScale), maximumScale)
                currentScale = nextScale
                committedScale = nextScale
                let clamped = clampedOffset(for: currentOffset, cropSize: cropSize, scale: nextScale)
                committedOffset = clamped
                currentOffset = clamped
            }
    }

    private func cropImageState(for cropSize: CGFloat, scale: CGFloat) -> CGSize {
        let baseScale = max(cropSize / sourceImage.size.width, cropSize / sourceImage.size.height)
        return CGSize(
            width: sourceImage.size.width * baseScale * scale,
            height: sourceImage.size.height * baseScale * scale
        )
    }

    private func clampedOffset(for proposedOffset: CGSize, cropSize: CGFloat, scale: CGFloat) -> CGSize {
        let imageState = cropImageState(for: cropSize, scale: scale)
        let maxX = max((imageState.width - cropSize) * 0.5, 0)
        let maxY = max((imageState.height - cropSize) * 0.5, 0)

        return CGSize(
            width: min(max(proposedOffset.width, -maxX), maxX),
            height: min(max(proposedOffset.height, -maxY), maxY)
        )
    }

    private func renderCroppedAvatar(cropSize: CGFloat) -> UIImage? {
        guard let cgImage = sourceImage.cgImage else { return nil }

        let imageState = cropImageState(for: cropSize, scale: currentScale)
        let originX = ((imageState.width - cropSize) * 0.5 - currentOffset.width) / imageState.width * sourceImage.size.width
        let originY = ((imageState.height - cropSize) * 0.5 - currentOffset.height) / imageState.height * sourceImage.size.height
        let sideLength = cropSize / imageState.width * sourceImage.size.width

        let pixelScaleX = CGFloat(cgImage.width) / sourceImage.size.width
        let pixelScaleY = CGFloat(cgImage.height) / sourceImage.size.height
        let cropRect = CGRect(
            x: max(0, originX) * pixelScaleX,
            y: max(0, originY) * pixelScaleY,
            width: min(sideLength, sourceImage.size.width - max(0, originX)) * pixelScaleX,
            height: min(sideLength, sourceImage.size.height - max(0, originY)) * pixelScaleY
        ).integral

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }

        let outputSide = min(CGFloat(croppedCGImage.width), 1024)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide))
        return renderer.image { _ in
            UIImage(cgImage: croppedCGImage, scale: sourceImage.scale, orientation: .up)
                .draw(in: CGRect(origin: .zero, size: CGSize(width: outputSide, height: outputSide)))
        }
    }
}

private extension UIImage {
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
