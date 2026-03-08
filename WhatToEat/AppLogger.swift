import Foundation
import OSLog

enum AppLogCategory: String {
    case general
    case security
    case network
    case auth
    case storage
}

enum AppLogger {
    private nonisolated static let subsystem = Bundle.main.bundleIdentifier ?? "com.pigdog.WhatToEat"

    private nonisolated static func logger(for category: AppLogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    nonisolated static func debug(_ message: String, category: AppLogCategory = .general) {
#if DEBUG
        logger(for: category).debug("\(message, privacy: .public)")
#endif
    }

    nonisolated static func info(_ message: String, category: AppLogCategory = .general) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    nonisolated static func error(_ message: String, category: AppLogCategory = .general) {
        logger(for: category).error("\(message, privacy: .public)")
    }
}
