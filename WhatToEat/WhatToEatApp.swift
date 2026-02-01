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

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Restaurant.self,
            VisitLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        setupRegionsFile()
    }

    private func setupRegionsFile() {
        guard let executablePath = Bundle.main.executablePath else {
            print("Could not find executable path")
            return
        }
        let executableDirectory = (executablePath as NSString).deletingLastPathComponent
        let sourcePath = (executableDirectory as NSString).appendingPathComponent("regions.json")

        guard let appSupportDir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            print("Could not find Application Support directory")
            return
        }
        let appDirectory = appSupportDir.appendingPathComponent("WhatToEat", isDirectory: true)
        let destinationPath = appDirectory.appendingPathComponent("regions.json")

        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: destinationPath.path) {
                if FileManager.default.fileExists(atPath: sourcePath) {
                    try FileManager.default.copyItem(at: URL(fileURLWithPath: sourcePath), to: destinationPath)
                    print("regions.json copied to \(destinationPath.path)")
                }
            }
        } catch {
            print("Failed to copy regions.json: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
