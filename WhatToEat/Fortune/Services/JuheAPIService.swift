//
//  JuheAPIService.swift
//  WhatToEat
//
//  聚合数据API服务 - 封装黄历和星座运势API调用
//

import Foundation

// MARK: - 聚合数据API服务
actor JuheAPIService {
    
    // MARK: - 单例
    static let shared = JuheAPIService()
    
    // MARK: - 配置
    private let httpClient: AppHTTPClient
    
    // MARK: - 缓存
    private var lunarCache: [String: LunarCalendarData] = [:]
    private var zodiacCache: [String: ZodiacFortuneData] = [:]
    
    // MARK: - 初始化
    private init() {
        self.httpClient = AppHTTPClient(timeout: 15)
        
        // 初始化阶段先从磁盘恢复缓存，避免在 actor init 中调用隔离方法
        let restoredCache = Self.loadCacheFromDisk()
        self.lunarCache = restoredCache.lunar
        self.zodiacCache = restoredCache.zodiac
    }
    
    // MARK: - 公共方法：获取黄历数据
    /// 获取指定日期的黄历数据
    /// - Parameters:
    ///   - date: 日期，默认为今天
    ///   - forceRefresh: 是否强制刷新，忽略缓存
    /// - Returns: 黄历数据
    ///
    /// 💡 刷新规则：每个自然日只请求一次API
    /// - 今天第一次打开：请求API
    /// - 今天再次打开：使用缓存（即使forceRefresh=true也优先使用当日缓存）
    /// - 跨天（明天）：自动请求新数据
    func fetchLunarCalendar(
        for date: Date = Date(),
        forceRefresh: Bool = false
    ) async throws -> LunarCalendarData {
        
        let dateString = Self.formatDate(date)
        let dailyManager = DailyRefreshManager.shared
        
        // 🔑 核心逻辑：检查今天是否已经请求过
        let shouldRequestAPI = await dailyManager.shouldRefreshLunarCalendar()
        
        // 检查内存缓存
        if let cached = lunarCache[dateString], !cached.isExpired {
            // 如果今天已经请求过API，优先使用缓存
            if !shouldRequestAPI {
                AppLogger.debug("今日黄历已请求过，直接使用缓存", category: .network)
                return cached
            }
            
            // 如果强制刷新且今天还没请求过，则继续请求API
            if !forceRefresh {
                AppLogger.debug("使用黄历缓存", category: .network)
                return cached
            }
        }
        
        // 如果今天已经请求过，但缓存不存在（异常情况），使用旧缓存
        if !shouldRequestAPI {
            // 尝试从UserDefaults恢复
            if let cached = await getCachedLunarDataFromDisk(for: dateString) {
                AppLogger.debug("从磁盘恢复黄历缓存", category: .storage)
                // 同时更新内存缓存
                lunarCache[dateString] = cached
                return cached
            }
        }
        
        // 检查API配置
        guard JuheAPIConfig.isConfigured else {
            throw FortuneAPIError.configurationMissing
        }
        
        guard let baseURL = JuheAPIConfig.lunarCalendarURL,
              var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else {
            throw FortuneAPIError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "date", value: dateString)
        ]
        
        guard let url = urlComponents.url else {
            throw FortuneAPIError.invalidURL
        }
        
        do {
            AppLogger.debug("请求黄历代理接口", category: .network)
            let apiResponse = try await withTimeout(seconds: 15) {
                try await self.httpClient.get(url, decode: JuheLaohuangliResponse.self)
            }

            guard apiResponse.isSuccess, let result = apiResponse.result else {
                AppLogger.error("黄历代理返回业务错误 code=\(apiResponse.errorCode)", category: .network)
                throw FortuneAPIError.dataParsingFailed
            }

            let lunarData = LunarCalendarData(from: result)
            lunarCache[dateString] = lunarData
            saveCacheToDisk()
            await DailyRefreshManager.shared.markLunarCalendarRefreshed()

            AppLogger.info("成功获取黄历数据", category: .network)
            return lunarData
        } catch is TimeoutError {
            AppLogger.error("黄历代理请求超时", category: .network)
            throw FortuneAPIError.networkError(TimeoutError())
        } catch let error as AppHTTPError {
            AppLogger.error("黄历代理请求失败: \(error.localizedDescription)", category: .network)
            throw FortuneAPIError.networkError(error)
        } catch {
            AppLogger.error("黄历请求失败: \(error.localizedDescription)", category: .network)
            throw FortuneAPIError.networkError(error)
        }
    }
    
    // MARK: - 公共方法：获取星座运势
    /// 获取指定星座的今日运势
    /// - Parameters:
    ///   - zodiac: 星座
    ///   - forceRefresh: 是否强制刷新
    /// - Returns: 星座运势数据
    ///
    /// 💡 刷新规则：每个自然日只请求一次API（同一星座）
    /// - 今天第一次查看该星座：请求API
    /// - 今天再次查看同一星座：使用缓存
    /// - 切换不同星座：请求新数据
    /// - 跨天（明天）：自动请求新数据
    func fetchZodiacFortune(
        for zodiac: ZodiacSign,
        forceRefresh: Bool = false
    ) async throws -> ZodiacFortuneData {
        
        let today = Self.formatDate(Date())
        let cacheKey = "\(today)_\(zodiac.rawValue)"
        let dailyManager = DailyRefreshManager.shared
        
        // 🔑 核心逻辑：检查今天是否已经请求过该星座
        let shouldRequestAPI = await dailyManager.shouldRefreshZodiac(zodiac)
        
        // 检查内存缓存
        if let cached = zodiacCache[cacheKey], !cached.isExpired {
            // 如果今天已经请求过该星座，优先使用缓存
            if !shouldRequestAPI {
                AppLogger.debug("今日星座已请求过，直接使用缓存", category: .network)
                return cached
            }
            
            // 如果强制刷新且今天还没请求过，则继续请求API
            if !forceRefresh {
                AppLogger.debug("使用星座缓存", category: .network)
                return cached
            }
        }
        
        // 如果今天已经请求过，但缓存不存在（异常情况），使用旧缓存
        if !shouldRequestAPI {
            // 尝试从磁盘缓存获取（可能是昨天的数据，但今天已经标记为请求过）
            if let cached = zodiacCache.values.first(where: { $0.zodiac == zodiac }) {
                AppLogger.debug("使用备用星座缓存", category: .storage)
                // 更新内存缓存
                zodiacCache[cacheKey] = cached
                return cached
            }
        }
        
        // 检查API配置
        guard JuheAPIConfig.isConfigured else {
            throw FortuneAPIError.configurationMissing
        }
        
        guard let baseURL = JuheAPIConfig.constellationURL,
              var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else {
            throw FortuneAPIError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "consName", value: zodiac.rawValue),
            URLQueryItem(name: "type", value: "today")
        ]
        
        guard let url = urlComponents.url else {
            throw FortuneAPIError.invalidURL
        }
        
        do {
            AppLogger.debug("请求星座代理接口", category: .network)
            let apiResponse = try await withTimeout(seconds: 15) {
                try await self.httpClient.get(url, decode: JuheConstellationResponse.self)
            }

            guard apiResponse.isSuccess else {
                AppLogger.error("星座代理返回业务错误 code=\(apiResponse.errorCode)", category: .network)
                throw FortuneAPIError.dataParsingFailed
            }

            guard let result = apiResponse.toConstellationResult() else {
                throw FortuneAPIError.dataParsingFailed
            }

            let zodiacData = ZodiacFortuneData(from: result, zodiac: zodiac)
            zodiacCache[cacheKey] = zodiacData
            saveCacheToDisk()
            await DailyRefreshManager.shared.markZodiacRefreshed(zodiac)

            AppLogger.info("成功获取星座运势", category: .network)
            return zodiacData
        } catch is TimeoutError {
            AppLogger.error("星座代理请求超时", category: .network)
            throw FortuneAPIError.networkError(TimeoutError())
        } catch let error as AppHTTPError {
            AppLogger.error("星座代理请求失败: \(error.localizedDescription)", category: .network)
            throw FortuneAPIError.networkError(error)
        } catch {
            AppLogger.error("星座请求失败: \(error.localizedDescription)", category: .network)
            throw FortuneAPIError.networkError(error)
        }
    }
    
    // MARK: - 缓存持久化
    
    private func saveCacheToDisk() {
        let userDefaults = UserDefaults.standard
        
        // 保存黄历缓存
        if let lunarData = try? JSONEncoder().encode(lunarCache) {
            userDefaults.set(lunarData, forKey: "fortune_lunar_cache")
        }
        
        // 保存星座缓存
        if let zodiacData = try? JSONEncoder().encode(zodiacCache) {
            userDefaults.set(zodiacData, forKey: "fortune_zodiac_cache")
        }
    }
    
    private nonisolated static func loadCacheFromDisk() -> (
        lunar: [String: LunarCalendarData],
        zodiac: [String: ZodiacFortuneData]
    ) {
        let userDefaults = UserDefaults.standard
        var lunarCache: [String: LunarCalendarData] = [:]
        var zodiacCache: [String: ZodiacFortuneData] = [:]
        
        // 恢复黄历缓存
        if let lunarData = userDefaults.data(forKey: "fortune_lunar_cache"),
           let cache = try? JSONDecoder().decode([String: LunarCalendarData].self, from: lunarData) {
            lunarCache = cache
        }
        
        // 恢复星座缓存
        if let zodiacData = userDefaults.data(forKey: "fortune_zodiac_cache"),
           let cache = try? JSONDecoder().decode([String: ZodiacFortuneData].self, from: zodiacData) {
            zodiacCache = cache
        }

        return (lunarCache, zodiacCache)
    }
    
    // MARK: - 工具方法
    
    /// 格式化日期为 yyyy-MM-dd
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 从磁盘缓存获取黄历数据
    private func getCachedLunarDataFromDisk(for dateString: String) async -> LunarCalendarData? {
        let userDefaults = UserDefaults.standard
        guard let data = userDefaults.data(forKey: "fortune_lunar_cache") else {
            return nil
        }
        
        do {
            let cache = try JSONDecoder().decode([String: LunarCalendarData].self, from: data)
            return cache[dateString]
        } catch {
            AppLogger.error("解析黄历缓存失败: \(error.localizedDescription)", category: .storage)
            return nil
        }
    }
    
    /// 清空所有缓存
    func clearAllCache() {
        lunarCache.removeAll()
        zodiacCache.removeAll()
        
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "fortune_lunar_cache")
        userDefaults.removeObject(forKey: "fortune_zodiac_cache")
    }
}

// MARK: - API 错误类型
enum FortuneAPIError: LocalizedError {
    case configurationMissing
    case invalidURL
    case serverError
    case dataParsingFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "运势后端代理未配置"
        case .invalidURL:
            return "无效的API地址"
        case .serverError:
            return "服务器返回错误"
        case .dataParsingFailed:
            return "数据解析失败"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - 超时处理

/// 超时错误类型
struct TimeoutError: Error {}

/// 带超时限制的异步操作包装器
/// - Parameters:
///   - seconds: 超时时间（秒）
///   - operation: 异步操作
/// - Returns: 操作结果
/// - Throws: TimeoutError 或操作中的其他错误
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // 添加实际任务
        group.addTask {
            try await operation()
        }
        
        // 添加超时任务
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        // 等待第一个完成的任务
        let result = try await group.next()!
        // 取消其他任务
        group.cancelAll()
        return result
    }
}
