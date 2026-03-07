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
    private let lunarCalendarKey: String
    private let constellationKey: String
    private let lunarBaseURL: String
    private let constellationBaseURL: String
    private let session: URLSession
    
    // MARK: - 缓存
    private var lunarCache: [String: LunarCalendarData] = [:]
    private var zodiacCache: [String: ZodiacFortuneData] = [:]
    
    // MARK: - 初始化
    private init() {
        // 使用FortuneAPIConfig中的配置
        self.lunarCalendarKey = JuheAPIConfig.lunarCalendarKey
        self.constellationKey = JuheAPIConfig.constellationKey
        // 注意：黄历和星座使用不同的baseURL
        self.lunarBaseURL = JuheAPIConfig.lunarBaseURL
        self.constellationBaseURL = JuheAPIConfig.constellationBaseURL
        
        // 配置URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
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
                print("🌙 [JuheAPI] 今天已请求过黄历API，使用缓存: \(dateString)")
                return cached
            }
            
            // 如果强制刷新且今天还没请求过，则继续请求API
            if !forceRefresh {
                print("🌙 [JuheAPI] 使用缓存的黄历数据: \(dateString)")
                return cached
            }
        }
        
        // 如果今天已经请求过，但缓存不存在（异常情况），使用旧缓存
        if !shouldRequestAPI {
            // 尝试从UserDefaults恢复
            if let cached = await getCachedLunarDataFromDisk(for: dateString) {
                print("🌙 [JuheAPI] 使用磁盘缓存的黄历数据: \(dateString)")
                // 同时更新内存缓存
                lunarCache[dateString] = cached
                return cached
            }
        }
        
        // 检查API配置
        guard JuheAPIConfig.isConfigured else {
            throw FortuneAPIError.configurationMissing
        }
        
        // 构建请求（使用黄历专用的baseURL）
        let urlString = "\(lunarBaseURL)\(JuheAPIConfig.Endpoints.laohuangli)"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw FortuneAPIError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: lunarCalendarKey),
            URLQueryItem(name: "date", value: dateString)
        ]
        
        guard let url = urlComponents.url else {
            throw FortuneAPIError.invalidURL
        }
        
        // 发送请求（带超时处理）
        print("🌙 [JuheAPI] 请求黄历数据: \(dateString)")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await withTimeout(seconds: 15) {
                try await self.session.data(from: url)
            }
        } catch is TimeoutError {
            print("⏰ [JuheAPI] 黄历请求超时")
            throw FortuneAPIError.networkError(TimeoutError())
        }
        
        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FortuneAPIError.serverError
        }
        
        // 解析数据
        let decoder = JSONDecoder()
        
        // 打印原始响应用于调试
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🌙 [JuheAPI] 黄历API原始响应前200字符: \(String(jsonString.prefix(200)))")
        }
        
        let apiResponse: JuheLaohuangliResponse
        do {
            apiResponse = try decoder.decode(JuheLaohuangliResponse.self, from: data)
        } catch {
            print("❌ [JuheAPI] 黄历JSON解析失败: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ [JuheAPI] 原始响应内容: \(jsonString)")
            }
            throw FortuneAPIError.dataParsingFailed
        }
        
        guard apiResponse.isSuccess, let result = apiResponse.result else {
            print("❌ [JuheAPI] 黄历API返回错误: errorCode=\(apiResponse.errorCode), reason=\(apiResponse.reason)")
            throw FortuneAPIError.dataParsingFailed
        }
        
        // 转换为应用层模型
        let lunarData = LunarCalendarData(from: result)
        
        // 更新缓存
        lunarCache[dateString] = lunarData
        saveCacheToDisk()
        
        // 🌟 记录今天已经请求过黄历API
        await DailyRefreshManager.shared.markLunarCalendarRefreshed()
        
        print("🌙 [JuheAPI] 成功获取黄历数据: \(lunarData.fullGanzhi)")
        return lunarData
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
                print("⭐ [JuheAPI] 今天已请求过该星座API，使用缓存: \(zodiac.rawValue)")
                return cached
            }
            
            // 如果强制刷新且今天还没请求过，则继续请求API
            if !forceRefresh {
                print("⭐ [JuheAPI] 使用缓存的星座数据: \(zodiac.rawValue)")
                return cached
            }
        }
        
        // 如果今天已经请求过，但缓存不存在（异常情况），使用旧缓存
        if !shouldRequestAPI {
            // 尝试从磁盘缓存获取（可能是昨天的数据，但今天已经标记为请求过）
            if let cached = zodiacCache.values.first(where: { $0.zodiac == zodiac }) {
                print("⭐ [JuheAPI] 使用备用缓存的星座数据: \(zodiac.rawValue)")
                // 更新内存缓存
                zodiacCache[cacheKey] = cached
                return cached
            }
        }
        
        // 检查API配置
        guard JuheAPIConfig.isConfigured else {
            throw FortuneAPIError.configurationMissing
        }
        
        // 构建请求（使用星座专用的baseURL）
        let urlString = "\(constellationBaseURL)\(JuheAPIConfig.Endpoints.constellation)"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw FortuneAPIError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: constellationKey),
            URLQueryItem(name: "consName", value: zodiac.rawValue),
            URLQueryItem(name: "type", value: "today")
        ]
        
        guard let url = urlComponents.url else {
            throw FortuneAPIError.invalidURL
        }
        
        // 发送请求（带超时处理）
        print("⭐ [JuheAPI] 请求星座数据: \(zodiac.rawValue)")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await withTimeout(seconds: 15) {
                try await self.session.data(from: url)
            }
        } catch is TimeoutError {
            print("⏰ [JuheAPI] 星座请求超时")
            throw FortuneAPIError.networkError(TimeoutError())
        }
        
        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FortuneAPIError.serverError
        }
        
        // 解析数据
        let decoder = JSONDecoder()
        
        // 打印原始响应用于调试
        if let jsonString = String(data: data, encoding: .utf8) {
            print("⭐ [JuheAPI] 星座API原始响应前200字符: \(String(jsonString.prefix(200)))")
        }
        
        let apiResponse: JuheConstellationResponse
        do {
            apiResponse = try decoder.decode(JuheConstellationResponse.self, from: data)
        } catch {
            print("❌ [JuheAPI] 星座JSON解析失败: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ [JuheAPI] 原始响应内容: \(jsonString)")
            }
            throw FortuneAPIError.dataParsingFailed
        }
        
        guard apiResponse.isSuccess else {
            print("❌ [JuheAPI] 星座API返回错误: errorCode=\(apiResponse.errorCode), reason=\(apiResponse.reason ?? "nil")")
            throw FortuneAPIError.dataParsingFailed
        }
        
        // 转换为ConstellationResult
        guard let result = apiResponse.toConstellationResult() else {
            print("❌ [JuheAPI] 星座API数据转换失败")
            throw FortuneAPIError.dataParsingFailed
        }
        
        // 转换为应用层模型
        let zodiacData = ZodiacFortuneData(from: result, zodiac: zodiac)
        
        // 更新缓存
        zodiacCache[cacheKey] = zodiacData
        saveCacheToDisk()
        
        // 🌟 记录今天已经请求过该星座API
        await DailyRefreshManager.shared.markZodiacRefreshed(zodiac)
        
        print("⭐ [JuheAPI] 成功获取星座数据: \(zodiac.rawValue) 运势\(zodiacData.fortuneScore)分")
        return zodiacData
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
            print("⚠️ [JuheAPI] 解析黄历缓存失败: \(error)")
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
            return "API配置缺失，请检查FortuneAPIConfig.swift中的API Key"
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
