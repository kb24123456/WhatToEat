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
            print("🌙 [DailyRefresh] 黄历：无历史记录，需要请求API")
            return true
        }
        
        let lastDay = Calendar.current.startOfDay(for: lastDate)
        
        if lastDay < today {
            print("🌙 [DailyRefresh] 黄历：上次请求是昨天，需要刷新")
            return true
        }
        
        print("🌙 [DailyRefresh] 黄历：今天已经请求过，使用缓存")
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
            print("⭐ [DailyRefresh] 星座：无历史记录，需要请求API")
            return true
        }
        
        let lastDay = Calendar.current.startOfDay(for: lastDate)
        
        // 如果不是今天，或者星座不同，都需要刷新
        if lastDay < today {
            print("⭐ [DailyRefresh] 星座：上次请求是昨天，需要刷新")
            return true
        }
        
        if lastZod != zodiac.rawValue {
            print("⭐ [DailyRefresh] 星座：切换星座从 \(lastZod) 到 \(zodiac.rawValue)，需要刷新")
            return true
        }
        
        print("⭐ [DailyRefresh] 星座：今天已经请求过该星座，使用缓存")
        return false
    }
    
    // MARK: - 公共方法：记录请求时间
    
    /// 记录黄历数据已请求
    func markLunarCalendarRefreshed() {
        let now = Date()
        userDefaults.set(now, forKey: Keys.lastLunarRequestDate)
        userDefaults.synchronize()
        print("🌙 [DailyRefresh] 已记录黄历请求时间: \(formatDate(now))")
    }
    
    /// 记录星座数据已请求
    func markZodiacRefreshed(_ zodiac: ZodiacSign) {
        let now = Date()
        userDefaults.set(now, forKey: Keys.lastZodiacRequestDate)
        userDefaults.set(zodiac.rawValue, forKey: Keys.lastZodiacRequestKey)
        userDefaults.synchronize()
        print("⭐ [DailyRefresh] 已记录星座请求时间: \(formatDate(now)) 星座: \(zodiac.rawValue)")
    }
    
    // MARK: - 公共方法：重置
    
    /// 重置所有请求记录（用于测试或用户手动刷新）
    func resetAll() {
        userDefaults.removeObject(forKey: Keys.lastLunarRequestDate)
        userDefaults.removeObject(forKey: Keys.lastZodiacRequestDate)
        userDefaults.removeObject(forKey: Keys.lastLunarRequestKey)
        userDefaults.removeObject(forKey: Keys.lastZodiacRequestKey)
        userDefaults.synchronize()
        print("🔄 [DailyRefresh] 已重置所有请求记录")
    }
    
    /// 重置黄历请求记录
    func resetLunarCalendar() {
        userDefaults.removeObject(forKey: Keys.lastLunarRequestDate)
        userDefaults.synchronize()
        print("🔄 [DailyRefresh] 已重置黄历请求记录")
    }
    
    /// 重置星座请求记录
    func resetZodiac() {
        userDefaults.removeObject(forKey: Keys.lastZodiacRequestDate)
        userDefaults.removeObject(forKey: Keys.lastZodiacRequestKey)
        userDefaults.synchronize()
        print("🔄 [DailyRefresh] 已重置星座请求记录")
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
