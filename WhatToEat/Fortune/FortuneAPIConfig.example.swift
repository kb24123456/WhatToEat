//
//  FortuneAPIConfig.example.swift
//  WhatToEat
//
//  ⚠️ API配置模板文件
//  使用说明：
//  1. 复制此文件为 FortuneAPIConfig.swift
//  2. 填入你的聚合数据API Keys
//  3. 确保 FortuneAPIConfig.swift 已添加到 .gitignore，不要提交到 Git
//
//  ⚠️ 注意：此文件仅作为模板参考，不会被编译到项目中
//  实际使用的是 FortuneAPIConfig.swift 中的配置
//

/*
import Foundation

// MARK: - 聚合数据 API 配置
// 聚合数据官网：https://www.juhe.cn/
struct JuheAPIConfig {
    
    // ==========================================
    // 老黄历 API Key
    // 申请地址：https://www.juhe.cn/docs/api/id/65
    // 免费额度：100次/天
    // ==========================================
    static let lunarCalendarKey: String = "YOUR_LUNAR_CALENDAR_API_KEY_HERE"
    
    // ==========================================
    // 星座运势 API Key
    // 申请地址：https://www.juhe.cn/docs/api/id/58
    // 免费额度：100次/天
    // ==========================================
    static let constellationKey: String = "YOUR_CONSTELLATION_API_KEY_HERE"
    
    /// 基础 URL
    static let baseURL: String = "http://v.juhe.cn"
    
    /// API 端点
    enum Endpoints {
        /// 老黄历 - 获取当日黄历信息（干支、宜忌、节气等）
        static let laohuangli = "/laohuangli/d"
        
        /// 星座运势 - 获取当日星座运势
        static let constellation = "/constellation/getAll"
    }
    
    /// 验证配置是否有效
    static var isConfigured: Bool {
        let lunarKey = lunarCalendarKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let constellationKey = constellationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 两个Key都需要配置
        guard !lunarKey.isEmpty, !lunarKey.hasPrefix("YOUR_"),
              !constellationKey.isEmpty, !constellationKey.hasPrefix("YOUR_") else {
            return false
        }
        return true
    }
    
    /// 验证黄历API是否配置
    static var isLunarCalendarConfigured: Bool {
        let key = lunarCalendarKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && !key.hasPrefix("YOUR_")
    }
    
    /// 验证星座API是否配置
    static var isConstellationConfigured: Bool {
        let key = constellationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && !key.hasPrefix("YOUR_")
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
*/
