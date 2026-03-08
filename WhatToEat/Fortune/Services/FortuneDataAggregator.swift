//
//  FortuneDataAggregator.swift
//  WhatToEat
//
//  数据聚合层 - 整合黄历和星座数据，为AI生成提供结构化输入
//

import Foundation

// MARK: - 食签生成上下文
struct FortuneGenerationContext: Codable {
    /// 黄历数据
    let lunarData: LunarCalendarData
    
    /// 星座运势数据
    let zodiacData: ZodiacFortuneData
    
    /// 用户城市
    let city: String
    
    /// 创意主题（熵值）
    let creativeTheme: String
    
    /// 生成时间
    let generatedAt: Date
}

// MARK: - 数据聚合器
actor FortuneDataAggregator {
    
    // MARK: - 单例
    static let shared = FortuneDataAggregator()
    
    // MARK: - 依赖服务
    private let juheService = JuheAPIService.shared
    
    // MARK: - 状态
    private var lastContext: FortuneGenerationContext?
    private var isLoading = false
    
    // MARK: - 初始化
    private init() {}
    
    // MARK: - 公共方法：聚合数据
    /// 聚合黄历和星座数据，生成食签上下文
    /// - Parameters:
    ///   - zodiac: 用户星座
    ///   - city: 用户城市
    ///   - forceRefresh: 是否强制刷新
    /// - Returns: 食签生成上下文
    func aggregateFortuneData(
        for zodiac: ZodiacSign,
        city: String,
        forceRefresh: Bool = false
    ) async throws -> FortuneGenerationContext {
        
        // 检查是否正在加载
        guard !isLoading else {
            // 如果正在加载，等待并返回上次的结果
            if let last = lastContext {
                return last
            }
            throw FortuneAggregatorError.concurrentLoading
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 并行获取黄历和星座数据
            async let lunarTask = fetchLunarData(forceRefresh: forceRefresh)
            async let zodiacTask = fetchZodiacData(for: zodiac, forceRefresh: forceRefresh)
            
            let lunarData = try await lunarTask
            let zodiacData = try await zodiacTask
            
            // 生成创意主题（熵值）
            let creativeTheme = generateCreativeTheme()
            
            // 构建上下文
            let context = FortuneGenerationContext(
                lunarData: lunarData,
                zodiacData: zodiacData,
                city: city,
                creativeTheme: creativeTheme,
                generatedAt: Date()
            )
            
            // 保存上下文
            lastContext = context
            
            AppLogger.info("运势数据聚合成功", category: .network)
            return context
            
        } catch {
            AppLogger.error("运势数据聚合失败: \(error.localizedDescription)", category: .network)
            throw FortuneAggregatorError.aggregationFailed(error)
        }
    }
    
    // MARK: - 私有方法：获取黄历数据
    private func fetchLunarData(forceRefresh: Bool) async throws -> LunarCalendarData {
        // 优先使用JuheAPIService获取数据
        do {
            return try await JuheAPIService.shared.fetchLunarCalendar(forceRefresh: forceRefresh)
        } catch {
            // 如果JuheAPI失败，尝试从缓存获取
            if let cached = await getCachedLunarData() {
                AppLogger.info("黄历远端失败，使用缓存", category: .network)
                return cached
            }
            throw error
        }
    }
    
    // MARK: - 私有方法：获取星座数据
    private func fetchZodiacData(for zodiac: ZodiacSign, forceRefresh: Bool) async throws -> ZodiacFortuneData {
        // 优先使用JuheAPIService获取数据
        do {
            return try await JuheAPIService.shared.fetchZodiacFortune(for: zodiac, forceRefresh: forceRefresh)
        } catch {
            // 如果JuheAPI失败，尝试从缓存获取
            if let cached = await getCachedZodiacData(for: zodiac) {
                AppLogger.info("星座远端失败，使用缓存", category: .network)
                return cached
            }
            throw error
        }
    }
    
    // MARK: - 私有方法：获取缓存数据
    private func getCachedLunarData() async -> LunarCalendarData? {
        // 从UserDefaults读取缓存
        let userDefaults = UserDefaults.standard
        guard let data = userDefaults.data(forKey: "fortune_lunar_cache") else {
            return nil
        }
        
        do {
            let cache = try JSONDecoder().decode([String: LunarCalendarData].self, from: data)
            let today = Self.formatDate(Date())
            return cache[today]
        } catch {
            return nil
        }
    }
    
    private func getCachedZodiacData(for zodiac: ZodiacSign) async -> ZodiacFortuneData? {
        // 从UserDefaults读取缓存
        let userDefaults = UserDefaults.standard
        guard let data = userDefaults.data(forKey: "fortune_zodiac_cache") else {
            return nil
        }
        
        do {
            let cache = try JSONDecoder().decode([String: ZodiacFortuneData].self, from: data)
            let today = Self.formatDate(Date())
            let cacheKey = "\(today)_\(zodiac.rawValue)"
            return cache[cacheKey]
        } catch {
            return nil
        }
    }
    
    // MARK: - 私有方法：生成创意主题
    private func generateCreativeTheme() -> String {
        let themes = [
            "赛博朋克风格 - 用科技术语重新诠释传统美食运势",
            "古诗词风格 - 用唐诗宋词意境描述今日运势",
            "电影台词风格 - 用经典电影台词结构表达食签",
            "游戏术语风格 - 用RPG游戏属性系统类比运势",
            "化学元素风格 - 用元素周期表和化学反应比喻",
            "武侠江湖风格 - 用金庸古龙式的武侠语言描述",
            "科幻太空风格 - 用星际探索和外星文明视角",
            "侦探推理风格 - 用福尔摩斯式的推理逻辑分析"
        ]
        
        return themes.randomElement() ?? themes[0]
    }
    
    // MARK: - 工具方法
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - 聚合器错误类型
enum FortuneAggregatorError: LocalizedError {
    case concurrentLoading
    case aggregationFailed(Error)
    case cacheNotFound
    
    var errorDescription: String? {
        switch self {
        case .concurrentLoading:
            return "数据正在加载中，请稍后"
        case .aggregationFailed(let error):
            return "数据聚合失败: \(error.localizedDescription)"
        case .cacheNotFound:
            return "未找到缓存数据"
        }
    }
}
