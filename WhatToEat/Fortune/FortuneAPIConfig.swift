//
//  FortuneAPIConfig.swift
//  WhatToEat
//
//  聚合数据 API 配置
//  API Keys 从 Info.plist 读取（由 Config.xcconfig 在构建时注入）
//

import Foundation

struct JuheAPIConfig {
    nonisolated static var lunarCalendarURL: URL? {
        AppEnvironment.backendURL(
            pathKey: "BackendFortuneLunarPath",
            defaultPath: "/v1/fortune/lunar"
        )
    }

    nonisolated static var constellationURL: URL? {
        AppEnvironment.backendURL(
            pathKey: "BackendFortuneConstellationPath",
            defaultPath: "/v1/fortune/constellation"
        )
    }

    nonisolated static var isConfigured: Bool {
        lunarCalendarURL != nil && constellationURL != nil
    }

    nonisolated static var isLunarCalendarConfigured: Bool {
        lunarCalendarURL != nil
    }

    nonisolated static var isConstellationConfigured: Bool {
        constellationURL != nil
    }
}

enum FortuneAPIProvider {
    case backend
    case none

    static var current: FortuneAPIProvider {
        if JuheAPIConfig.isConfigured {
            return .backend
        }
        return .none
    }

    var isAvailable: Bool {
        return self != .none
    }
}
