//
//  WhatToEatApp.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/17.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - App Delegate (用于配置全局设置)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // 仅支持竖屏
        return .portrait
    }
}

@main
struct WhatToEatApp: App {
    // 注册 AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage(AppSettingsKeys.appAppearanceMode) private var appAppearanceMode: String = AppAppearanceMode.system.rawValue

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Restaurant.self,
            VisitLog.self,
            UserCategory.self,
        ])
        let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let emergencyConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        if CloudSyncManager.isICloudSyncEnabled() {
            do {
                let cloudConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .automatic
                )
                return try ModelContainer(for: schema, configurations: [cloudConfiguration])
            } catch {
                AppLogger.error("CloudKit 容器不可用，降级到本地存储: \(error.localizedDescription)", category: .storage)
            }
        }

        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            AppLogger.error("本地数据容器初始化失败，降级到内存容器: \(error.localizedDescription)", category: .storage)
            if let emergencyContainer = try? ModelContainer(for: schema, configurations: [emergencyConfiguration]) {
                return emergencyContainer
            }
            assertionFailure("无法创建任何可用的 ModelContainer")
            return try! ModelContainer(for: schema, configurations: [emergencyConfiguration])
        }
    }()

    init() {
        HapticManager.installGlobalHooksIfNeeded()
        bootstrapDefaultSettings()

        // 避免在启动关键路径执行文件 I/O，降低首帧白屏时长
        DispatchQueue.global(qos: .utility).async {
            Self.setupRegionsFile()
        }
    }

    private func bootstrapDefaultSettings() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: AppSettingsKeys.hapticFeedbackEnabled) == nil {
            defaults.set(true, forKey: AppSettingsKeys.hapticFeedbackEnabled)
        }
        if defaults.object(forKey: AppSettingsKeys.iCloudSyncEnabled) == nil {
            defaults.set(true, forKey: AppSettingsKeys.iCloudSyncEnabled)
        }
        refreshDailyPrimeOfferIfNeeded(defaults: defaults)
    }

    private func refreshDailyPrimeOfferIfNeeded(defaults: UserDefaults) {
        let todayKey = Self.membershipOfferDayKey(for: Date())
        let savedDay = defaults.string(forKey: AppSettingsKeys.primeOfferStartDay)

        guard savedDay != todayKey else { return }

        defaults.set(todayKey, forKey: AppSettingsKeys.primeOfferStartDay)
        defaults.set(Date().timeIntervalSince1970, forKey: AppSettingsKeys.primeOfferStartTimestamp)
    }

    private static func membershipOfferDayKey(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }

    private static func setupRegionsFile() {
        guard let executablePath = Bundle.main.executablePath else {
            AppLogger.error("无法定位应用可执行文件路径", category: .storage)
            return
        }
        let executableDirectory = (executablePath as NSString).deletingLastPathComponent
        let sourcePath = (executableDirectory as NSString).appendingPathComponent("regions.json")

        guard let appSupportDir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            AppLogger.error("无法定位 Application Support 目录", category: .storage)
            return
        }
        let appDirectory = appSupportDir.appendingPathComponent("WhatToEat", isDirectory: true)
        let destinationPath = appDirectory.appendingPathComponent("regions.json")

        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: destinationPath.path) {
                if FileManager.default.fileExists(atPath: sourcePath) {
                    try FileManager.default.copyItem(at: URL(fileURLWithPath: sourcePath), to: destinationPath)
                    AppLogger.info("regions.json 已复制到应用支持目录", category: .storage)
                }
            }
        } catch {
            AppLogger.error("复制 regions.json 失败: \(error.localizedDescription)", category: .storage)
        }
    }

    private var resolvedAppearance: ColorScheme? {
        let mode = AppAppearanceMode(rawValue: appAppearanceMode) ?? .system
        return mode.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedAppearance)
                .onAppear {
                    KeyboardWarmupService.shared.warmUpIfNeeded()
                    VisitLogDeduplicationService.runIfNeeded(in: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
