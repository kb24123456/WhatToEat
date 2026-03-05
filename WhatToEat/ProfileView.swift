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

// MARK: - Profile View
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Restaurant.createdAt, order: .reverse) private var restaurants: [Restaurant]
    @Query(sort: \VisitLog.date, order: .reverse) private var visitLogs: [VisitLog]
    
    @State private var viewModel: ProfileViewModel
    @Namespace private var animationNamespace
    @State private var showDashboardCards = false
    @State private var selectedGateway: GatewayType = .settings
    @StateObject private var locationManager = LocationManager.shared
    @AppStorage(AppSettingsKeys.preferredMapApp) private var preferredMapApp: String = ""
    @AppStorage(AppSettingsKeys.userSelectedCity) private var defaultCity: String = "重庆"
    @AppStorage(AppSettingsKeys.libraryDefaultSortOption) private var libraryDefaultSortOption: String = "智能排序"
    @AppStorage(AppSettingsKeys.smartInputProxyEnabled) private var smartInputProxyEnabled: Bool = true
    @AppStorage(AppSettingsKeys.appAppearanceMode) private var appAppearanceMode: String = AppAppearanceMode.system.rawValue
    @State private var showSettingsCityPicker = false
    @State private var showResetSettingsAlert = false
    @State private var showClearCacheAlert = false
    @State private var settingsToastMessage: String?
    @State private var showRestaurantImportPicker = false
    @State private var showExportSheet = false
    @State private var exportDocument: CSVTextDocument?
    @State private var exportFilename: String = ""
    
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
                        .scaleEffect(showDashboardCards ? 0.94 : 1.0, anchor: .top)
                        .offset(y: showDashboardCards ? -14 : 0)
                        .padding(.horizontal, 20)
                    
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
                        Group {
                            if selectedGateway == .data {
                                dashboardCardsGrid
                            } else {
                                settingsDashboard
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
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
            .background(AppTheme.Colors.pageBackground)
            
            // 展开的卡片覆盖层
            if showDashboardCards, let expandedId = viewModel.expandedCardId {
                expandedCardOverlay(id: expandedId)
                    .zIndex(100)
                    .transition(.opacity)
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
            if !librarySortOptions.contains(libraryDefaultSortOption) {
                libraryDefaultSortOption = librarySortOptions[0]
            }
        }
        .onChange(of: restaurants) { _, newRestaurants in
            viewModel.restaurants = newRestaurants
        }
        .onChange(of: smartInputProxyEnabled) { _, enabled in
            if !enabled, InputProxyManager.shared.isProxyActive {
                InputProxyManager.shared.deactivate(commit: false)
            }
            showSettingsToast(enabled ? "智能输入代理已开启" : "智能输入代理已关闭")
        }
        .sheet(isPresented: $showSettingsCityPicker) {
            CitySelectionView(selectedCity: $defaultCity)
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
        .alert("恢复系统默认设置", isPresented: $showResetSettingsAlert) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                resetSystemSettings()
            }
        } message: {
            Text("将恢复默认城市、默认排序、默认导航应用和输入代理设置。")
        }
        .alert("清理所有缓存", isPresented: $showClearCacheAlert) {
            Button("取消", role: .cancel) {}
            Button("确认清理", role: .destructive) {
                clearAllCaches()
            }
        } message: {
            Text("将清理图片、搜索、定位、食签与智能纠错等本地缓存。")
        }
    }
    
    private var collapseButton: some View {
        HStack {
            Text(selectedGateway == .settings ? "功能设置" : "我的数据")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#95A0A7"))
            
            Spacer()
            
            Button {
                withAnimation(dashboardTransition) {
                    viewModel.closeExpandedCard()
                    showDashboardCards = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                    Text("收起")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#636E72"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(hex: "#FFFFFF"))
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
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
                VStack(spacing: 10) {
                    Button {
                        showSettingsCityPicker = true
                    } label: {
                        settingsValueRow(
                            icon: "mappin.and.ellipse",
                            title: "默认城市",
                            value: defaultCity,
                            accent: Color(hex: "#61C6FF")
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

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

                    Menu {
                        ForEach(AppAppearanceMode.allCases, id: \.rawValue) { mode in
                            Button(mode.displayName) {
                                appAppearanceMode = mode.rawValue
                                showSettingsToast("已切换为\(mode.displayName)")
                            }
                        }
                    } label: {
                        settingsValueRow(
                            icon: "circle.lefthalf.filled",
                            title: "界面风格",
                            value: appearanceModeName,
                            accent: Color(hex: "#5C8DFF")
                        )
                    }

                    Menu {
                        ForEach(librarySortOptions, id: \.self) { option in
                            Button(option) {
                                libraryDefaultSortOption = option
                            }
                        }
                    } label: {
                        settingsValueRow(
                            icon: "arrow.up.arrow.down",
                            title: "食库默认排序",
                            value: libraryDefaultSortOption,
                            accent: Color(hex: "#FFC857")
                        )
                    }

                    Toggle(isOn: $smartInputProxyEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("智能输入代理")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#2D3436"))
                            Text("输入框位于底部时自动启用吸附输入栏")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#95A0A7"))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#61C6FF")))
                    .padding(.top, 2)

                    settingsActionButton(
                        icon: "arrow.counterclockwise.circle",
                        title: "恢复系统默认设置",
                        tint: Color(hex: "#E17055"),
                        isDestructive: true
                    ) {
                        showResetSettingsAlert = true
                    }
                }
            }

            settingsSectionCard(
                title: "数据与缓存",
                subtitle: "导入导出与统一缓存清理"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    settingsActionButton(
                        icon: "trash.slash",
                        title: "清理所有缓存",
                        tint: Color(hex: "#E17055")
                    ) {
                        showClearCacheAlert = true
                    }

                    settingsActionButton(
                        icon: "square.and.arrow.down",
                        title: "导入餐厅数据",
                        tint: Color(hex: "#61C6FF")
                    ) {
                        showRestaurantImportPicker = true
                    }

                    settingsActionButton(
                        icon: "square.and.arrow.up",
                        title: "导出餐厅数据",
                        tint: Color(hex: "#2ECC71")
                    ) {
                        exportRestaurantData()
                    }

                    settingsActionButton(
                        icon: "chart.bar.doc.horizontal",
                        title: "导出消费数据",
                        tint: Color(hex: "#9B59B6")
                    ) {
                        exportConsumptionData()
                    }

                    dataImportExportHintCard
                }
            }

            settingsSectionCard(
                title: "权限与支持",
                subtitle: "定位权限与系统入口"
            ) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#61C6FF"))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color(hex: "#61C6FF").opacity(0.14)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("定位权限")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#2D3436"))
                        Text(locationPermissionText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#95A0A7"))
                    }

                    Spacer()

                    Button(locationPermissionActionTitle) {
                        handleLocationPermissionAction()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#2D3436"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#F3F5F6"))
                    )
                }
            }
        }
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
                    .foregroundColor(Color(hex: "#2D3436"))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#95A0A7"))
            }

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#FFFFFF"))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
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
                .foregroundColor(accent)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(accent.opacity(0.14))
                )

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#2D3436"))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#636E72"))
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "#AAB2B9"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#F7F8FA"))
        )
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
                    .foregroundColor(tint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(tint.opacity(0.14)))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isDestructive ? Color(hex: "#D63031") : Color(hex: "#2D3436"))

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#AAB2B9"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#F7F8FA"))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var dataImportExportHintCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("导入格式要求")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#636E72"))
            Text("版本：\(DataCSVSupport.restaurantImportVersion)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#7F8C8D"))
            Text("文件：.csv（UTF-8 编码，首行为表头）")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#7F8C8D"))
            Text("必填列：name,type,rating,district,address,review")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#7F8C8D"))
            Text("导出会自动使用 UTF-8 BOM + 标准 CSV 转义，兼容 Excel/WPS/飞书。")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#7F8C8D"))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#F7F8FA"))
        )
    }

    private var librarySortOptions: [String] {
        ["智能排序", "距离最近", "评分最高", "最近添加"]
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

    private func resetSystemSettings() {
        preferredMapApp = ""
        defaultCity = "重庆"
        libraryDefaultSortOption = librarySortOptions[0]
        smartInputProxyEnabled = true
        appAppearanceMode = AppAppearanceMode.system.rawValue
        showSettingsToast("系统设置已恢复默认")
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
                .foregroundColor(Color(hex: "#2D3436"))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(hex: "#FFFFFF"))
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 3)
                )
            Spacer()
        }
        .padding(.top, 10)
    }
    
    // MARK: - Profile Header（头像穿透半透明卡片的Hero效果）
    private func profileHeader(isCompact: Bool) -> some View {
        // 使用屏幕宽度计算，确保头像尺寸正确
        let screenWidth = ScreenMetrics.bounds.width - 40  // 减去左右 padding(20)
        let avatarSize = screenWidth * (isCompact ? 0.54 : 0.67)
        let cardOverlap = avatarSize * (isCompact ? 0.15 : 0.1)
        let avatarTopOffset = avatarSize * (isCompact ? 0.07 : 0.15)
        let infoCardTopOffset = avatarTopOffset + avatarSize - cardOverlap
        let avatarOffsetInCard = avatarTopOffset - infoCardTopOffset
        let infoCardHeight: CGFloat = isCompact ? 148 : 164
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
                isCompact: isCompact,
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
                .fill(Color(hex: "#FFFFFF"))
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .sheet(isPresented: $viewModel.showingEditProfile) {
            EditProfileView(userProfile: $viewModel.userProfile)
        }
    }
    
    // MARK: - 头像层
    private func avatarLayer(size: CGFloat) -> some View {
        Button(action: {
            viewModel.showingEditProfile = true
        }) {
            ZStack {
                // 头像背景光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#FFB6C1").opacity(0.4),
                                Color(hex: "#FFC0CB").opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.25,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size * 1.15, height: size * 1.15)
                
                // 头像主体
                avatarPhoto(size: size)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                )
                .background(
                    Circle()
                        .fill(Color(hex: "#FFFFFF"))
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
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
                    .foregroundColor(Color(hex: "#FFB6C1"))
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
                        .foregroundColor(Color(hex: "#2D3436"))
                    
                    Text(viewModel.userProfile.bio)
                        .font(.system(size: subtitleFont, weight: .medium))
                        .foregroundColor(Color(hex: "#B2BEC3"))
                }
                
                Spacer(minLength: 8)
                editButton(isCompact: isCompact)
            }
            .padding(.top, topInset)
            
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(levelTitle)
                    .font(.system(size: verificationFont, weight: .medium))
                    .foregroundColor(Color(hex: "#5E646B"))
                
                Spacer()
                
                Text("\(progressPercent)%")
                    .font(.system(size: percentageFont, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#2D3436"))
                    .contentTransition(.numericText())
            }
            .padding(.top, sectionTopInset)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: "#E6E8EA"))
                        .frame(height: progressBarHeight)
                    
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: "#1E2430"))
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
                    .fill(Color(hex: "#FFFFFF"))
                
                overlapBlurBand(
                    avatarSize: avatarSize,
                    avatarOffsetInCard: avatarOffsetInCard,
                    overlapBlurHeight: overlapBlurHeight
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 10)
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
                .opacity(0.01)
        }
        .frame(maxWidth: .infinity, minHeight: overlapBlurHeight, maxHeight: overlapBlurHeight, alignment: .top)
        .overlay(
            Rectangle()
                .fill(Color(hex: "#FFFFFF").opacity(0.03))
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
                .foregroundColor(Color(hex: "#636E72"))
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
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
