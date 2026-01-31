//
//  ImportDataView.swift
//  WhatToEat
//
//  CSV 数据导入视图 - 支持"馋嘴虎与好吃狗"餐厅清单导入
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var importManager = CSVImportManager.shared
    @StateObject private var geocodingManager = GeocodingManager.shared
    
    // 文件选择
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    
    // 默认城市设置
    @State private var defaultCity = "重庆"
    @State private var showCityPicker = false
    
    // 动画状态
    @State private var showConfetti = false
    @State private var isImporting = false
    
    // 删除确认
    @State private var showDeleteConfirmation = false
    @State private var importedRestaurantIDs: [UUID] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 标题区域
                        headerSection
                            .padding(.top, 20)
                        
                        // 导入状态卡片
                        statusCard
                        
                        // 默认城市设置
                        defaultCitySection
                        
                        // 导入按钮
                        importButtonSection
                        
                        // 说明文字
                        infoSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Confetti 特效层
                if showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .navigationTitle("导入餐厅数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .sheet(isPresented: $showCityPicker) {
                CityPickerView(selectedCity: $defaultCity)
            }
            .onChange(of: importManager.importPhase) { _, newPhase in
                if newPhase == .completed {
                    triggerConfetti()
                }
            }
            // 删除确认对话框
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteImportedRestaurants()
                }
            } message: {
                Text("这将删除本次导入的所有餐厅数据（共 \(importManager.importedCount) 家），此操作不可撤销。")
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        MilkyDiffuseBackground()
            .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.accent)
                .symbolRenderingMode(.hierarchical)
            
            Text("导入餐厅清单")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            Text("支持 CSV 格式的餐厅数据导入")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.mediumGray)
        }
    }
    
    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            // 状态图标
            statusIcon
            
            // 状态文字
            statusText
            
            // 进度条（仅在地理编码阶段显示）
            if importManager.importPhase == .geocoding || importManager.importPhase == .completed {
                progressBar
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
    }
    
    // MARK: - Status Icon
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.1))
                .frame(width: 80, height: 80)
            
            Image(systemName: statusIconName)
                .font(.system(size: 36))
                .foregroundColor(statusColor)
                .symbolRenderingMode(.hierarchical)
        }
    }
    
    // MARK: - Status Text
    private var statusText: some View {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
            
            Text(statusDescription)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.mediumGray)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.Colors.lightGray)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.Colors.accent)
                        .frame(width: geo.size.width * progressValue, height: 8)
                        .animation(.spring(response: 0.3), value: progressValue)
                }
            }
            .frame(height: 8)
            
            Text("正在向卫星请求坐标 (\(geocodingManager.completedCount)/\(geocodingManager.totalCount))...")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.mediumGray)
        }
    }
    
    // MARK: - Default City Section
    private var defaultCitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("默认城市")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Spacer()
                
                Button {
                    showCityPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(defaultCity)
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                }
            }
            
            Text("若无法识别城市，将默认设为该城市。建议保持「重庆」。")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.mediumGray)
                .lineLimit(2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.35))
        )
    }
    
    // MARK: - Import Button Section
    private var importButtonSection: some View {
        VStack(spacing: 12) {
            // 根据状态显示不同按钮
            if importManager.importPhase == .completed {
                // 导入完成后的操作按钮
                completedActionButtons
            } else {
                // 选择文件按钮
                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.arrow.up")
                            .font(.system(size: 18))
                        Text(selectedFileURL != nil ? "重新选择文件" : "选择 CSV 文件")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Colors.accent)
                    )
                    .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .disabled(isImporting)
            }
            
            // 已选文件显示
            if let url = selectedFileURL {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.accent)
                    
                    Text(url.lastPathComponent)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppTheme.Colors.accent.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Completed Action Buttons
    private var completedActionButtons: some View {
        VStack(spacing: 12) {
            // 完成按钮
            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text("完成")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.Colors.success)
                )
                .shadow(color: AppTheme.Colors.success.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            
            // 批量删除按钮
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 18))
                    Text("删除本次导入的餐厅")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(AppTheme.Colors.warning)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.Colors.warning.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.Colors.warning.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导入说明")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.darkText)
            
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "1.circle.fill", text: "支持 CSV 格式，标题行会被自动跳过")
                infoRow(icon: "2.circle.fill", text: "城市识别：自动从地址中识别，失败则使用默认城市")
                infoRow(icon: "3.circle.fill", text: "坐标补全：导入后会后台异步获取地理坐标")
                infoRow(icon: "4.circle.fill", text: "数据安全：所有数据仅存储在本地设备")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.35))
        )
    }
    
    // MARK: - Info Row
    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.mediumGray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Status Properties
    private var statusIconName: String {
        switch importManager.importPhase {
        case .idle:
            return "arrow.down.circle"
        case .parsing:
            return "doc.text.magnifyingglass"
        case .importingText:
            return "arrow.down.circle.fill"
        case .geocoding:
            return "location.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch importManager.importPhase {
        case .idle:
            return AppTheme.Colors.mediumGray
        case .parsing, .importingText, .geocoding:
            return AppTheme.Colors.accent
        case .completed:
            return AppTheme.Colors.success
        case .error:
            return AppTheme.Colors.warning
        }
    }
    
    private var statusTitle: String {
        switch importManager.importPhase {
        case .idle:
            return "准备导入"
        case .parsing:
            return "正在解析..."
        case .importingText:
            return "正在导入餐厅信息..."
        case .geocoding:
            return "正在获取坐标..."
        case .completed:
            return "导入完成！"
        case .error(let message):
            return "导入失败"
        }
    }
    
    private var statusDescription: String {
        switch importManager.importPhase {
        case .idle:
            return "请选择 CSV 文件开始导入"
        case .parsing:
            return "正在分析 CSV 文件结构..."
        case .importingText:
            return "已导入 \(importManager.importedCount) 家餐厅"
        case .geocoding:
            return "正在向卫星请求坐标，请保持应用在前台"
        case .completed:
            return "成功导入 \(importManager.importedCount) 家餐厅，坐标将在后台继续补全"
        case .error(let message):
            return message
        }
    }
    
    private var progressValue: Double {
        guard geocodingManager.totalCount > 0 else { return 0 }
        return Double(geocodingManager.completedCount) / Double(geocodingManager.totalCount)
    }
    
    // MARK: - File Selection Handler
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // 安全检查：确保是 CSV 文件
            guard url.pathExtension.lowercased() == "csv" else {
                importManager.errorMessage = "请选择 CSV 格式的文件"
                importManager.importPhase = .error("文件格式不正确")
                return
            }
            
            selectedFileURL = url
            
            // 开始导入
            startImport(from: url)
            
        case .failure(let error):
            importManager.errorMessage = error.localizedDescription
            importManager.importPhase = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Start Import
    private func startImport(from url: URL) {
        isImporting = true
        
        Task {
            do {
                let count = try await importManager.importCSV(
                    from: url,
                    modelContext: modelContext,
                    defaultCity: defaultCity
                )
                
                await MainActor.run {
                    isImporting = false
                    importManager.importPhase = .completed
                }
                
            } catch {
                await MainActor.run {
                    isImporting = false
                    importManager.errorMessage = error.localizedDescription
                    importManager.importPhase = .error(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Trigger Confetti
    private func triggerConfetti() {
        withAnimation(.spring(response: 0.3)) {
            showConfetti = true
        }
        
        // 3秒后自动关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showConfetti = false
            }
        }
    }
    
    // MARK: - Delete Imported Restaurants
    private func deleteImportedRestaurants() {
        Task {
            do {
                let deletedCount = try await importManager.deleteLastImportedRestaurants(
                    modelContext: modelContext
                )
                
                await MainActor.run {
                    // 重置状态，允许重新导入
                    importManager.reset()
                    selectedFileURL = nil
                }
                
                print("ImportDataView: 成功删除 \(deletedCount) 家餐厅")
                
            } catch {
                await MainActor.run {
                    importManager.errorMessage = error.localizedDescription
                    importManager.importPhase = .error(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ImportDataView()
}
