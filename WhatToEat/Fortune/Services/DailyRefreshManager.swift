//
//  DailyRefreshManager.swift
//  WhatToEat
//
//  每日刷新管理器 - 确保每个自然日只请求一次API
//

import Foundation

// MARK: - 每日刷新管理器
/// 管理每个自然日的API请求状态
/// 规则：每个自然日只请求一次API，当天数据永不过期
actor DailyRefreshManager {
    
    // MARK: - 单例
    static let shared = DailyRefreshManager()
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let lastLunarRequestDate = "daily_refresh_lunar_date"
        static let lastZodiacRequestDate = "daily_refresh_zodiac_date"
        static let lastLunarRequestKey = "daily_refresh_lunar_key"
        static let lastZodiacRequestKey = "daily_refresh_zodiac_key"
    }
    
    // MARK: - 内部状态
    private var userDefaults: UserDefaults {
        return UserDefaults.standard
    }
    
    // MARK: - 初始化
    private init() {}
    
    // MARK: - 公共方法：检查是否需要刷新
    
    /// 检查黄历数据是否需要刷新
    /// - Returns: true表示需要请求API，false表示使用缓存
    func shouldRefreshLunarCalendar() -> Bool {
        let lastRequestDate = userDefaults.object(forKey: Keys.lastLunarRequestDate) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        // 如果没有记录，或者不是今天，则需要刷新
        guard let lastDate = lastRequestDate else {
            AppLogger.debug("黄历无历史记录，需要刷新", category: .network)
            return true
        }
        
        let lastDay = Calendar.current.startOfDay(for: lastDate)
        
        if lastDay < today {
            AppLogger.debug("黄历上次请求非今日，需要刷新", category: .network)
            return true
        }
        
        AppLogger.debug("黄历今日已请求，使用缓存", category: .network)
        return false
    }
    
    /// 检查星座数据是否需要刷新
    /// - Parameter zodiac: 星座
    /// - Returns: true表示需要请求API，false表示使用缓存
    func shouldRefreshZodiac(_ zodiac: ZodiacSign) -> Bool {
        let lastRequestDate = userDefaults.object(forKey: Keys.lastZodiacRequestDate) as? Date
        let lastZodiac = userDefaults.string(forKey: Keys.lastZodiacRequestKey)
        let today = Calendar.current.startOfDay(for: Date())
        
        // 如果没有记录，需要刷新
        guard let lastDate = lastRequestDate,
              let lastZod = lastZodiac else {
            AppLogger.debug("星座无历史记录，需要刷新", category: .network)
            return true
        }
        
        let lastDay = Calendar.current.startOfDay(for: lastDate)
        
        // 如果不是今天，或者星座不同，都需要刷新
        if lastDay < today {
            AppLogger.debug("星座上次请求非今日，需要刷新", category: .network)
            return true
        }
        
        if lastZod != zodiac.rawValue {
            AppLogger.debug("星座切换为 \(zodiac.rawValue)，需要刷新", category: .network)
            return true
        }
        
        AppLogger.debug("星座今日已请求，使用缓存", category: .network)
        return false
    }
    
    // MARK: - 公共方法：记录请求时间
    
    /// 记录黄历数据已请求
    func markLunarCalendarRefreshed() {
        let now = Date()
        userDefaults.set(now, forKey: Keys.lastLunarRequestDate)
        userDefaults.synchronize()
        AppLogger.debug("已记录黄历请求时间: \(formatDate(now))", category: .storage)
    }
    
    /// 记录星座数据已请求
    func markZodiacRefreshed(_ zodiac: ZodiacSign) {
        let now = Date()
        userDefaults.set(now, forKey: Keys.lastZodiacRequestDate)
        userDefaults.set(zodiac.rawValue, forKey: Keys.lastZodiacRequestKey)
        userDefaults.synchronize()
        AppLogger.debug("已记录星座请求时间: \(formatDate(now)) 星座: \(zodiac.rawValue)", category: .storage)
    }
    
    // MARK: - 公共方法：重置
    
    /// 重置所有请求记录（用于测试或用户手动刷新）
    func resetAll() {
        userDefaults.removeObject(forKey: Keys.lastLunarRequestDate)
        userDefaults.removeObject(forKey: Keys.lastZodiacRequestDate)
        userDefaults.removeObject(forKey: Keys.lastLunarRequestKey)
        userDefaults.removeObject(forKey: Keys.lastZodiacRequestKey)
        userDefaults.synchronize()
        AppLogger.info("已重置每日刷新记录", category: .storage)
    }
    
    /// 重置黄历请求记录
    func resetLunarCalendar() {
        userDefaults.removeObject(forKey: Keys.lastLunarRequestDate)
        userDefaults.synchronize()
        AppLogger.info("已重置黄历请求记录", category: .storage)
    }
    
    /// 重置星座请求记录
    func resetZodiac() {
        userDefaults.removeObject(forKey: Keys.lastZodiacRequestDate)
        userDefaults.removeObject(forKey: Keys.lastZodiacRequestKey)
        userDefaults.synchronize()
        AppLogger.info("已重置星座请求记录", category: .storage)
    }
    
    // MARK: - 工具方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - 扩展属性

extension DailyRefreshManager {
    
    /// 今天是否已经请求过黄历数据
    var isLunarCalendarRefreshedToday: Bool {
        get async {
            return !shouldRefreshLunarCalendar()
        }
    }
    
    /// 今天是否已经请求过星座数据
    func isZodiacRefreshedToday(_ zodiac: ZodiacSign) async -> Bool {
        return !shouldRefreshZodiac(zodiac)
    }
}
