//
//  AICopywritingManager.swift
//  WhatToEat
//
//  赛博吃货命理师 - 每日食签生成与管理（集成实时黄历/星座API）
//

import Foundation
import Combine

// MARK: - 食签数据结构
struct DailyFoodFortune: Codable, Equatable {
    let fortuneStars: Int           // 运势星级 1-5
    let analysis: String            // 基于星座和黄历的一句话网感解析
    let yiHighlight: String         // 宜：需要变红的高亮动作
    let yiSub: String               // 宜的补充说明
    let jiHighlight: String         // 忌：需要变黑的高亮动作
    let jiSub: String               // 忌的补充说明
    let luckFood: String            // 开运食物
    var date: Date                  // 生成日期（AI返回中可能不包含，解析后自动填充）
    
    // 新增：数据来源标记
    var dataSource: DataSource = .api
    
    enum DataSource: String, Codable {
        case api = "api"           // 实时API数据
        case cache = "cache"       // 缓存数据
        case fallback = "fallback" // 降级默认数据
    }
    
    enum CodingKeys: String, CodingKey {
        case fortuneStars = "fortune_stars"
        case analysis
        case yiHighlight = "yi_highlight"
        case yiSub = "yi_sub"
        case jiHighlight = "ji_highlight"
        case jiSub = "ji_sub"
        case luckFood = "luck_food"
        case date
        case dataSource
    }
    
    // 自定义解码器，处理 AI 返回中可能不包含 date 字段的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        fortuneStars = try container.decode(Int.self, forKey: .fortuneStars)
        analysis = try container.decode(String.self, forKey: .analysis)
        yiHighlight = try container.decode(String.self, forKey: .yiHighlight)
        yiSub = try container.decode(String.self, forKey: .yiSub)
        jiHighlight = try container.decode(String.self, forKey: .jiHighlight)
        jiSub = try container.decode(String.self, forKey: .jiSub)
        luckFood = try container.decode(String.self, forKey: .luckFood)
        
        // date 字段是可选的，如果 AI 没有返回，使用当前日期
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        
        // dataSource 是可选的，默认为 api
        dataSource = try container.decodeIfPresent(DataSource.self, forKey: .dataSource) ?? .api
    }
    
    // 初始化方法（用于创建默认食签）
    init(fortuneStars: Int, analysis: String, yiHighlight: String, yiSub: String, 
         jiHighlight: String, jiSub: String, luckFood: String, date: Date = Date(),
         dataSource: DataSource = .fallback) {
        self.fortuneStars = fortuneStars
        self.analysis = analysis
        self.yiHighlight = yiHighlight
        self.yiSub = yiSub
        self.jiHighlight = jiHighlight
        self.jiSub = jiSub
        self.luckFood = luckFood
        self.date = date
        self.dataSource = dataSource
    }
}

// MARK: - 食签请求上下文（集成实时API数据）
struct FortuneContext {
    let userZodiac: String      // 用户星座
    let currentDate: String     // 当前日期（yyyy-MM-dd）
    let lunarDate: String       // 农历日期
    let solarTerm: String       // 当前节气
    let city: String            // 用户所在城市
    
    // 新增：实时API数据
    let lunarData: LunarCalendarData?     // 黄历数据
    let zodiacData: ZodiacFortuneData?    // 星座运势数据
    let creativeTheme: String              // 创意主题（熵值）
    
    /// 构建 User Prompt（使用真实API数据）
    func buildUserPrompt() -> String {
        // 基础信息
        var prompt = """
        请为以下用户生成今日食签：
        - 星座：\(userZodiac)
        - 日期：\(currentDate)
        - 农历：\(lunarDate)
        - 节气：\(solarTerm)
        - 城市：\(city)
        """
        
        // 如果有实时黄历数据，加入详细黄历信息
        if let lunar = lunarData {
            prompt += """
            
            【黄历信息】（真实数据）
            - 阳历日期：\(lunar.solarDate)
            - 农历日期：\(lunar.lunarDate)
            - 干支：\(lunar.fullGanzhi)
            - 建除十二神：\(lunar.jianchu)
            - 宜：\(lunar.suitable.joined(separator: "、"))
            - 忌：\(lunar.unsuitable.joined(separator: "、"))
            - 节气：\(lunar.solarTerm)
            - 彭祖百忌：\(lunar.pengzu)
            """
        }
        
        // 如果有实时星座数据，加入运势信息
        if let zodiac = zodiacData {
            prompt += """
            
            【星座运势】（真实数据）
            - 星座：\(zodiac.zodiac.rawValue)
            - 综合运势：\(zodiac.fortuneScore)分（\(zodiac.fortuneLevel)）
            - 幸运色：\(zodiac.luckyColor)
            - 幸运数字：\(zodiac.luckyNumbers.map { String($0) }.joined(separator: ","))
            - 运势摘要：\(zodiac.summary)
            """
        }
        
        // 加入创意主题（熵值）
        prompt += """
        
        【创意方向】\(creativeTheme)
        """
        
        return prompt
    }
}

// MARK: - 食签管理器（集成实时API）
class AICopywritingManager: ObservableObject {
    
    // MARK: - 单例模式
    static let shared = AICopywritingManager()
    private init() {
        loadFromLocal()
    }
    
    // MARK: - 发布状态
    @Published var todayFortune: DailyFoodFortune?
    @Published var isLoading: Bool = false
    @Published var hasInitialLoad: Bool = false
    
    // MARK: - API聚合器
    private let dataAggregator = FortuneDataAggregator.shared
    private let httpClient = AppHTTPClient(timeout: 30)
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let todayFortune = "today_food_fortune"
        static let fortuneDate = "today_fortune_date"
        static let cachedZodiacSign = "cached_zodiac_sign_for_fortune"
    }
    
    // MARK: - 生日变化检测
    
    /// 检查生日是否发生变化（星座改变）
    /// - Returns: 如果星座发生变化，返回 true
    func hasZodiacChanged() -> Bool {
        let currentZodiac = ZodiacUtil.loadZodiacSign()
        let cachedZodiac = UserDefaults.standard.string(forKey: Keys.cachedZodiacSign)
        
        // 如果当前没有设置星座，不认为发生变化
        guard let current = currentZodiac else {
            return false
        }
        
        // 如果缓存为空（首次使用），保存当前星座
        guard let cached = cachedZodiac else {
            UserDefaults.standard.set(current, forKey: Keys.cachedZodiacSign)
            return false
        }
        
        // 比较星座是否变化
        if current != cached {
            return true
        }
        
        return false
    }
    
    /// 更新缓存的星座信息
    func updateCachedZodiac() {
        if let currentZodiac = ZodiacUtil.loadZodiacSign() {
            UserDefaults.standard.set(currentZodiac, forKey: Keys.cachedZodiacSign)
        }
    }
    
    // MARK: - 获取今日食签（带缓存逻辑，集成实时API）
    
    /// 获取今日食签
    /// - 如果本地有今日缓存且未过00:00，直接返回
    /// - 如果星座发生变化，清理缓存并重新获取
    /// - 否则调用 API 生成新的食签
    func getTodayFortune(forceRefresh: Bool = false) async -> DailyFoodFortune? {
        AppLogger.debug("开始获取今日食签", category: .network)
        
        // 检查星座是否发生变化
        if hasZodiacChanged() {
            AppLogger.info("星座变更，清理食签缓存", category: .storage)
            clearFortuneCache()
            updateCachedZodiac()
        }
        
        // 检查是否需要强制刷新
        if !forceRefresh {
            // 检查本地缓存
            if let cached = loadTodayFortuneFromLocal(), !isNewDay() {
                AppLogger.debug("使用本地食签缓存", category: .storage)
                await MainActor.run {
                    self.todayFortune = cached
                }
                return cached
            }
        }
        
        // 避免重复请求
        guard !isLoading else {
            AppLogger.debug("已有食签请求在进行中，返回当前状态", category: .network)
            return todayFortune
        }
        
        // 检查 AI 配置
        guard AIConfig.isConfigured else {
            AppLogger.info("未配置 AI 后端代理，降级为默认食签", category: .network)
            return getDefaultFortune()
        }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            // 使用新的API集成方式生成食签
            let fortune = try await generateFortuneWithAPIData()
            
            await MainActor.run {
                self.todayFortune = fortune
                self.isLoading = false
            }
            
            saveTodayFortuneToLocal(fortune)
            return fortune
            
        } catch {
            AppLogger.error("获取食签失败: \(error.localizedDescription)", category: .network)
            
            // 错误降级：使用缓存或默认数据
            if let cached = loadTodayFortuneFromLocal() {
                await MainActor.run {
                    self.todayFortune = cached
                    self.isLoading = false
                }
                return cached
            }
            
            await MainActor.run {
                self.isLoading = false
            }
            
            return getDefaultFortune()
        }
    }
    
    // MARK: - 新增：使用实时API数据生成食签
    
    /// 使用实时黄历/星座API数据生成食签
    private func generateFortuneWithAPIData() async throws -> DailyFoodFortune {
        // 获取用户信息
        guard let zodiacSign = ZodiacUtil.loadZodiacSign(),
              let zodiac = ZodiacSign.from(chineseName: zodiacSign) else {
            throw FortuneError.configurationMissing
        }
        
        let city = LocationManager.shared.currentCity ?? "未知城市"
        
        // 1. 使用FortuneDataAggregator获取实时API数据
        let context = try await dataAggregator.aggregateFortuneData(
            for: zodiac,
            city: city,
            forceRefresh: false
        )
        
        // 2. 构建使用真实API数据的System Prompt
        let systemPrompt = buildSystemInstructionWithAPIData(context)
        
        // 3. 构建User Prompt
        let userPrompt = buildUserPromptWithAPIData(context)
        
        // 4. 调用AI生成食签
        let fortune = try await fetchFortuneFromAI(systemPrompt: systemPrompt, userPrompt: userPrompt)
        
        // 5. 标记数据来源
        var result = fortune
        result.dataSource = .api
        AppLogger.info("食签生成成功，数据源: \(result.dataSource.rawValue)", category: .network)
        return result
    }
    
    // MARK: - 新增：使用API数据构建System Prompt
    
    /// 使用实时API数据构建System Prompt
    private func buildSystemInstructionWithAPIData(_ context: FortuneGenerationContext) -> String {
        let lunar = context.lunarData
        let zodiac = context.zodiacData
        
        return """
        # Role
        你是一位精通西方古典占星术与中国民俗黄历、且说话极具网感的"赛博吃货命理师"。
        
        ⚠️ 重要声明：你的回复必须基于以下真实数据，严禁凭记忆或感觉编造！
        
        ## 语言风格指南（必须遵守）
        你的文案必须年轻化、生活化、趣味化，符合Z世代用户的阅读习惯：
        
        1. **使用网络流行语**：如"绝绝子"、"yyds"、"拿捏了"、"破防了"、"真香"、"emo"、"躺平"、"内卷"、"氛围感"、"仪式感"等
        2. **使用emoji表情**：在analysis中必须包含1-2个emoji（如：✨🍀🔥💫🌟💥🎯🎉😋🤤）
        3. **语气轻松幽默**：像朋友聊天一样，不要太正式
        4. **多用短句**：避免长难句，多用逗号分隔的短句
        5. **口语化表达**：用"咱"、"你"、"宝子"等称呼，拉近距离
        
        【真实黄历数据】（来自聚合数据API）
        - 阳历日期：\(lunar.solarDate)
        - 农历日期：\(lunar.lunarDate)
        - 干支：\(lunar.fullGanzhi)
        - 建除十二神：\(lunar.jianchu)
        - 宜：\(lunar.suitable.joined(separator: "、"))
        - 忌：\(lunar.unsuitable.joined(separator: "、"))
        - 节气：\(lunar.solarTerm)
        - 彭祖百忌：\(lunar.pengzu)
        
        【真实星座运势数据】（来自聚合数据API）
        - 星座：\(zodiac.zodiac.rawValue)
        - 综合运势：\(zodiac.fortuneScore)分（\(zodiac.fortuneLevel)）
        - 幸运色：\(zodiac.luckyColor)
        - 幸运数字：\(zodiac.luckyNumbers.map { String($0) }.joined(separator: ","))
        - 运势摘要：\(zodiac.summary)
        
        【创意方向】\(context.creativeTheme)
        
        Deduction Protocol (推演协议 - 严格遵守)
        为了防止内容同质化，你必须执行以下逻辑链条进行创作：
        
        黄历转换逻辑：
        1. 提取真实黄历数据中的核心"宜/忌"
        2. 强制映射：将传统宜忌项映射至美食场景（例：宜祭祀 -> 宜去老字号致敬传统味道；忌动土 -> 忌装修风或工业风餐厅）
        3. 术语引用：文案中必须自然引用一个真实黄历术语（如：\(lunar.jianchu)、岁破、月德等）
        
        星座色彩逻辑：
        1. 使用真实幸运色：\(zodiac.luckyColor)
        2. 颜色强绑定：生成的 luck_food 必须在视觉上包含该颜色或其相近色，并在 analysis 中点出这种关联
        3. 运势评分逻辑：fortune_stars 必须真实反映 \(zodiac.fortuneScore) 分对应的水平，严禁每天都给 4-5 星
        
        创意主题逻辑：
        1. 严格按照【创意方向】\(context.creativeTheme) 指定的风格生成文案
        2. 避免使用近期的常见表达方式
        3. 尝试不同的修辞风格和比喻角度
        
        开运食物要求（严格遵守）：
        luck_food 必须是符合以下标准的食物：
        1. 中国人日常饮食中的常见食物（如：火锅、小面、烧烤、奶茶、咖啡、汉堡、披萨、寿司、拉面、麻辣烫、煎饼果子、肉夹馍、螺蛳粉、炸鸡、牛排、沙拉、三明治等）
        2. 知名连锁餐饮品牌的招牌产品（如：麦当劳巨无霸、肯德基原味鸡、星巴克拿铁、喜茶多肉葡萄、海底捞火锅等）
        3. 各地特色小吃（如：北京烤鸭、重庆火锅、西安肉夹馍、兰州拉面、武汉热干面、广州早茶、上海生煎、成都串串等）
        4. 常见国际美食（如：意大利面、日式拉面、韩式烤肉、泰式冬阴功、墨西哥卷饼、美式汉堡等）
        
        禁止生成以下类型食物：
        - 不常见的食材组合（如：蓝莓山药泥、紫薯燕麦杯）
        - 过于小众或地方特色极强的食物（如：折耳根炒腊肉、臭豆腐炖肥肠）
        - 听起来像药膳或养生的奇怪搭配（如：枸杞红枣糕、银耳莲子羹）
        - 过于抽象或文艺的食物名称（如：星空慕斯、云朵舒芙蕾）
        
        幸运色绑定规则：
        生成的 luck_food 必须在视觉上包含该星座当日幸运色或其相近色，并在 analysis 中点出这种关联。
        幸运色食物参考：
        - 红色系：火锅、红烧肉、番茄炒蛋、草莓蛋糕、西瓜、麻辣小龙虾
        - 绿色系：抹茶拿铁、牛油果沙拉、青椒炒肉、黄瓜、绿茶、蔬菜沙拉
        - 黄色系：炸鸡、蛋炒饭、芒果、菠萝、玉米、芝士汉堡、奶茶
        - 蓝色系：蓝莓、蓝纹芝士、蝶豆花饮品、蓝莓奶昔
        - 白色系：小笼包、豆腐脑、米饭、牛奶、白切鸡、银耳羹
        - 黑色系：黑芝麻糊、黑森林蛋糕、墨鱼汁意面、可乐
        
        Content Requirements
        去 AI 味：禁止使用"美味、探索、推荐、独特"。
        语调：像闺蜜/兄弟聊天一样，时而毒舌吐槽，时而暖心鼓励，穿插网络梗和emoji。
        高亮逻辑：yi_highlight 和 ji_highlight 必须是极具网感的短词（如："冲就完了"、"原地躺平"、"拿捏了"）。
        
        ## 文案风格示例
        - 运势好："宝子，今天运势简直绝绝子！✨ 建除十二神是'满'，宜大吃大喝，加上射手座今日运势拉满，这波不冲真的亏大了！"
        - 运势一般："今天运势中规中矩，别想着搞事情了🍀 老老实实吃顿好的，给自己充充电，明天再战！"
        - 运势差："emmm...今天黄历说'诸事不宜'，咱就别折腾了😅 找个舒服的地方躺平，吃点治愈系美食，保命要紧！"
        
        Format (Strictly JSON)
        {
        "fortune_stars": Int,
        "analysis": "引用真实黄历术语和星座数据的一句话解析（网感+玄学）",
        "yi_highlight": "高亮动作",
        "yi_sub": "基于真实黄历宜忌项的解释（字数15-20）",
        "ji_highlight": "高亮动作",
        "ji_sub": "基于真实星座运势的解释（字数15-20）",
        "luck_food": "包含幸运色的具体食物"
        }
        Example (年轻化网感风格):
        {
        "fortune_stars": 4,
        "analysis": "宝子，今天运势简直绝绝子！✨ 建除十二神是'满'，宜大吃大喝，加上射手座今日运势拉满，这波不冲真的亏大了！",
        "yi_highlight": "冲就完了",
        "yi_sub": "今日宜满，宜囤货，宜大口吃肉！火锅烧烤奶茶全安排上，快乐就完事了～",
        "ji_highlight": "原地躺平",
        "ji_sub": "今日忌动土，别想着搞装修或者搬家了，老实待着，点外卖不香吗？😋",
        "luck_food": "麻辣小龙虾"
        }
        """
    }
    
    /// 使用API数据构建User Prompt
    private func buildUserPromptWithAPIData(_ context: FortuneGenerationContext) -> String {
        // 简单提示，主要信息已在System Prompt中
        return """
        请基于以上提供的真实黄历和星座数据，生成今日食签。
        
        要求：
        1. 严格引用真实数据中的黄历术语（如干支、建除十二神、宜忌等）
        2. 幸运食物必须包含真实幸运色：\(context.zodiacData.luckyColor)
        3. 遵循指定的创意主题风格
        4. 运势星级必须真实反映\(context.zodiacData.fortuneScore)分的水平
        
        请以JSON格式返回结果。
        """
    }
    
    // MARK: - 核心API调用方法
    
    /// 调用AI API生成食签
    private func fetchFortuneFromAI(systemPrompt: String, userPrompt: String) async throws -> DailyFoodFortune {
        guard let url = AIConfig.generateFortuneURL else {
            throw FortuneError.configurationMissing
        }
        let requestBody = FortuneGenerationRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        do {
            return try await httpClient.post(url, body: requestBody, decode: DailyFoodFortune.self)
        } catch {
            AppLogger.error("AI 代理请求失败: \(error.localizedDescription)", category: .network)
            throw FortuneError.apiError
        }
    }
    
    // MARK: - 默认食签
    
    private func getDefaultFortune() -> DailyFoodFortune {
        return DailyFoodFortune(
            fortuneStars: 4,
            analysis: "今日星盘显示你的胃动力MAX，黄历也说你宜大开吃戒。",
            yiHighlight: "想吃啥就吃啥",
            yiSub: "别委屈自己，你的胃值得最好的。",
            jiHighlight: "为了减肥不吃晚饭",
            jiSub: "饿着肚子睡觉会做饿梦的。",
            luckFood: "你最爱吃的那家",
            date: Date(),
            dataSource: .fallback
        )
    }
    
    // MARK: - 本地持久化（使用文件存储，避免UserDefaults 4MB限制）
    
    private var fortuneCacheFileURL: URL? {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls.first?.appendingPathComponent("today_fortune_cache.json")
    }
    
    private func saveTodayFortuneToLocal(_ fortune: DailyFoodFortune) {
        guard let fileURL = fortuneCacheFileURL else { return }
        
        do {
            let encoded = try JSONEncoder().encode(fortune)
            try encoded.write(to: fileURL, options: .atomic)
            UserDefaults.standard.set(getCurrentDateString(), forKey: Keys.fortuneDate)
            AppLogger.debug("食签已写入本地缓存", category: .storage)
        } catch {
            AppLogger.error("保存食签缓存失败: \(error.localizedDescription)", category: .storage)
        }
    }
    
    private func loadTodayFortuneFromLocal() -> DailyFoodFortune? {
        guard let fileURL = fortuneCacheFileURL,
              FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let fortune = try? JSONDecoder().decode(DailyFoodFortune.self, from: data) else {
            return nil
        }
        return fortune
    }
    
    func loadFromLocal() {
        if let fortune = loadTodayFortuneFromLocal() {
            todayFortune = fortune
        }
        hasInitialLoad = true
    }
    
    func clearLocalCache() {
        if let fileURL = fortuneCacheFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        UserDefaults.standard.removeObject(forKey: Keys.fortuneDate)
        todayFortune = nil
        AppLogger.info("已清理本地食签缓存", category: .storage)
    }
    
    /// 清理食签缓存（用于星座变化时）
    func clearFortuneCache() {
        if let fileURL = fortuneCacheFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        UserDefaults.standard.removeObject(forKey: Keys.fortuneDate)
        UserDefaults.standard.removeObject(forKey: Keys.cachedZodiacSign)
        todayFortune = nil
        AppLogger.info("已清理食签缓存和缓存星座", category: .storage)
    }
    
    // MARK: - 工具方法
    
    /// 获取当前日期字符串
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    /// 检查是否是新的一天
    private func isNewDay() -> Bool {
        guard let savedDate = UserDefaults.standard.string(forKey: Keys.fortuneDate) else {
            return true
        }
        return savedDate != getCurrentDateString()
    }
    
    // MARK: - 请求数据结构
    private struct FortuneGenerationRequest: Codable {
        let systemPrompt: String
        let userPrompt: String
    }
}

// MARK: - 错误类型
enum FortuneError: Error, LocalizedError {
    case invalidURL
    case apiError
    case jsonParsingFailed
    case configurationMissing
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .apiError:
            return "API 请求失败"
        case .jsonParsingFailed:
            return "食签 JSON 解析失败"
        case .configurationMissing:
            return "配置缺失：请设置后端代理地址与用户星座信息"
        }
    }
}
