//
//  FortuneAPIConfig.swift
//  WhatToEat
//
//  聚合数据 API 配置
//  API Keys 从 Info.plist 读取（由 Config.xcconfig 在构建时注入）
//

import Foundation

// MARK: - 聚合数据 API 配置
// 聚合数据官网：https://www.juhe.cn/
struct JuheAPIConfig {
    
    /// 从 Info.plist 读取配置值
    private nonisolated static func getConfigValue(forKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            print("⚠️ [JuheAPIConfig] 未找到配置项: \(key)")
            return ""
        }
        return value
    }
    
    // ==========================================
    // 老黄历 API Key（从Config.xcconfig注入）
    // ==========================================
    nonisolated static var lunarCalendarKey: String {
        return getConfigValue(forKey: "APIKeyJuheLunar")
    }
    
    // ==========================================
    // 星座运势 API Key（从Config.xcconfig注入）
    // ==========================================
    nonisolated static var constellationKey: String {
        return getConfigValue(forKey: "APIKeyJuheConstellation")
    }
    
    /// 黄历 API 基础 URL
    nonisolated static let lunarBaseURL: String = "https://v.juhe.cn"
    
    /// 星座 API 基础 URL（注意：星座和黄历使用不同的域名）
    nonisolated static let constellationBaseURL: String = "https://web.juhe.cn"
    
    /// API 端点
    nonisolated enum Endpoints {
        /// 老黄历 - 获取当日黄历信息（干支、宜忌、节气等）
        static let laohuangli = "/laohuangli/d"
        
        /// 星座运势 - 获取当日星座运势
        static let constellation = "/constellation/getAll"
    }
    
    /// 验证配置是否有效
    nonisolated static var isConfigured: Bool {
        let lunarKey = lunarCalendarKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let constellationKey = constellationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 两个Key都需要配置，且不能是占位符
        guard !lunarKey.isEmpty, !lunarKey.hasPrefix("$"),
              !constellationKey.isEmpty, !constellationKey.hasPrefix("$") else {
            return false
        }
        return true
    }
    
    /// 验证黄历API是否配置
    nonisolated static var isLunarCalendarConfigured: Bool {
        let key = lunarCalendarKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && !key.hasPrefix("$")
    }
    
    /// 验证星座API是否配置
    nonisolated static var isConstellationConfigured: Bool {
        let key = constellationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && !key.hasPrefix("$")
    }
}

// MARK: - 备用 API 配置（当聚合数据不可用时）
struct BackupAPIConfig {
    /// 备用 API Key（如阿里云市场、其他黄历API）
    static let lunarCalendarKey: String = "YOUR_BACKUP_LUNAR_KEY_HERE"
    static let constellationKey: String = "YOUR_BACKUP_CONSTELLATION_KEY_HERE"
    static let baseURL: String = ""
    
    static var isConfigured: Bool {
        let lunarKey = lunarCalendarKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let constellationKey = constellationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !lunarKey.isEmpty && !lunarKey.hasPrefix("YOUR_") &&
               !constellationKey.isEmpty && !constellationKey.hasPrefix("YOUR_")
    }
}

// MARK: - API 配置统一管理
enum FortuneAPIProvider {
    case juhe        // 聚合数据（主）
    case backup      // 备用API
    case none        // 未配置
    
    static var current: FortuneAPIProvider {
        if JuheAPIConfig.isConfigured {
            return .juhe
        } else if BackupAPIConfig.isConfigured {
            return .backup
        } else {
            return .none
        }
    }
    
    var isAvailable: Bool {
        return self != .none
    }
}
