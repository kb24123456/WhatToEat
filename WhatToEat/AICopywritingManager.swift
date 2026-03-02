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
    
    enum CodingKeys: String, CodingKey {
        case fortuneStars = "fortune_stars"
        case analysis
        case yiHighlight = "yi_highlight"
        case yiSub = "yi_sub"
        case jiHighlight = "ji_highlight"
        case jiSub = "ji_sub"
        case luckFood = "luck_food"
        case date
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
    }
    
    // 初始化方法（用于创建默认食签）
    init(fortuneStars: Int, analysis: String, yiHighlight: String, yiSub: String, 
         jiHighlight: String, jiSub: String, luckFood: String, date: Date = Date()) {
        self.fortuneStars = fortuneStars
        self.analysis = analysis
        self.yiHighlight = yiHighlight
        self.yiSub = yiSub
        self.jiHighlight = jiHighlight
        self.jiSub = jiSub
        self.luckFood = luckFood
        self.date = date
    }
}

// MARK: - 食签请求上下文
struct FortuneContext {
    let userZodiac: String      // 用户星座
    let currentDate: String     // 当前日期（yyyy-MM-dd）
    let lunarDate: String       // 农历日期
    let solarTerm: String       // 当前节气
    let city: String            // 用户所在城市
    
    /// 构建 User Prompt
    func buildUserPrompt() -> String {
        return """
        请为以下用户生成今日食签：
        - 星座：\(userZodiac)
        - 日期：\(currentDate)
        - 农历：\(lunarDate)
        - 节气：\(solarTerm)
        - 城市：\(city)
        """
    }
}

// 使用 AppConfig.swift 中的 AIConfig

// MARK: - 食签管理器
/// 赛博吃货命理师 - 每日食签生成与管理
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
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let todayFortune = "today_food_fortune"
        static let fortuneDate = "today_fortune_date"
        static let cachedZodiacSign = "cached_zodiac_sign_for_fortune"
    }
    
    // MARK: - 农历和节气工具
    
    /// 获取当前农历日期
    private func getLunarDate() -> String {
        let calendar = Calendar(identifier: .chinese)
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        
        let lunarMonths = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        let lunarDays = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                         "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                         "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
        
        guard let month = components.month, let day = components.day else {
            return "未知"
        }
        
        return "\(lunarMonths[month - 1])月\(lunarDays[day - 1])"
    }
    
    /// 获取当前节气（简化版，实际应用需要更复杂的算法）
    private func getSolarTerm() -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let day = calendar.component(.day, from: Date())
        
        // 简化节气判断（实际应用需要精确计算）
        let solarTerms: [(month: Int, day: Int, name: String)] = [
            (2, 4, "立春"), (2, 19, "雨水"),
            (3, 6, "惊蛰"), (3, 21, "春分"),
            (4, 5, "清明"), (4, 20, "谷雨"),
            (5, 6, "立夏"), (5, 21, "小满"),
            (6, 6, "芒种"), (6, 21, "夏至"),
            (7, 7, "小暑"), (7, 23, "大暑"),
            (8, 8, "立秋"), (8, 23, "处暑"),
            (9, 8, "白露"), (9, 23, "秋分"),
            (10, 8, "寒露"), (10, 23, "霜降"),
            (11, 7, "立冬"), (11, 22, "小雪"),
            (12, 7, "大雪"), (12, 22, "冬至"),
            (1, 6, "小寒"), (1, 20, "大寒")
        ]
        
        // 找到最近的节气
        var closestTerm = ""
        var minDiff = Int.max
        
        for term in solarTerms {
            let diff = abs((month - term.month) * 30 + (day - term.day))
            if diff < minDiff {
                minDiff = diff
                closestTerm = term.name
            }
        }
        
        return closestTerm.isEmpty ? "无" : closestTerm
    }
    
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
    
    // MARK: - System Prompt（赛博吃货命理师）
    private func buildSystemInstruction() -> String {
        return """
        # Role
        你是一位精通西方古典占星术与中国民俗黄历、且说话极具网感的"赛博吃货命理师"。
        
        ⚠️ 重要声明：你的回复必须基于真实数据，严禁凭记忆或感觉编造！
        
        数据来源要求（必须严格遵守）
        1. 黄历数据：必须查询当天真实的干支（如：甲子日）、十二神（如：开日、破日）、当日宜/忌项。可参考权威黄历资料（如万年历 App、农历网 nongli.pyrmj.cn）。
        2. 占星数据：必须查询该星座当天真实的综合运势分值和幸运色。可参考专业星座运势网站（如 Astro.com、星座屋）。
        3. 在 analysis 中必须注明你使用的具体黄历术语和占星依据（如："根据今日建除十二神为'收'"、"根据月亮在第X宫"）。
        
        禁止事项：
        - 禁止使用"我记得"、"应该是"、"可能是"等模糊表述
        - 禁止编造不存在的黄历术语
        - 禁止凭空给出运势分值
        
        Data Source & Accuracy
        你的结论必须基于以下真实数据来源：
        黄历数据：当日干支（如：甲子日）、十二神（如：开日、破日）、具体宜/忌项。
        占星数据：当日星座综合运势（分值）、该星座当日幸运色。
        Deduction Protocol (推演协议 - 严格遵守)
        为了防止内容同质化，你必须执行以下逻辑链条进行创作：
        黄历转换逻辑：
        提取当日黄历中的核心“宜/忌”。
        强制映射：将传统项映射至美食场景。（例：宜祭祀 -> 宜去老字号致敬；忌动土 -> 忌装修风或工业风餐厅）。
        术语引用：文案中必须自然提及一个专业术语（如：岁破、月德、建除十二神等）。
        星座色彩逻辑：
        获取该星座当日幸运色。
        颜色强绑定：生成的 luck_food 必须在视觉上包含该颜色或其相近色，并在 analysis 中点出这种关联。（例：幸运色为绿色 -> 幸运食物必须是：抹茶、泰绿、沙拉等）。
        运势评分逻辑：
        fortune_stars 必须真实反映该星座当日的综合运势水平，严禁每天都给 4-5 星。
        Content Requirements
        去 AI 味：禁止使用"美味、探索、推荐、独特"。
        语调：毒舌且精准。如果你算出用户今天运势极差，请直接开启"劝退模式"，用最狠的话劝他吃最稳的饭。
        高亮逻辑：yi_highlight 和 ji_highlight 必须是极具冲击力的短词。
        
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
        
        Format (Strictly JSON)
        {
        "fortune_stars": Int,
        "analysis": "引用星象相位或黄历术语的一句话解析（网感+玄学）",
        "yi_highlight": "高亮动作",
        "yi_sub": "基于黄历逻辑的解释（字数15-20）",
        "ji_highlight": "高亮动作",
        "ji_sub": "基于星座相位的解释（字数15-20）",
        "luck_food": "包含幸运色的具体食物"
        }
        Example (狮子座 + 辛亥日):
        {
        "fortune_stars": 2,
        "analysis": "水逆回旋镖精准命中，狮子今日虽有天德合，但也架不住食伤被克。",
        "yi_highlight": "潜伏老破小",
        "yi_sub": "今日建除十二神为'收'，利入仓，去犄角旮旯的店里收割地道烟火气。",
        "ji_highlight": "带没脑子的同事拼单",
        "ji_sub": "今日幸运色为'冷灰'，忌一切热血上脑的社交，独自去吃性冷淡风简餐。 ",
        "luck_food": "黑松露菌菇意面"
        }
        """
    }
    
    // MARK: - 请求数据结构
    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    private struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
    }
    
    private struct ChatResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
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
            print("🔄 检测到星座变化：\(cached) → \(current)")
            return true
        }
        
        return false
    }
    
    /// 更新缓存的星座信息
    func updateCachedZodiac() {
        if let currentZodiac = ZodiacUtil.loadZodiacSign() {
            UserDefaults.standard.set(currentZodiac, forKey: Keys.cachedZodiacSign)
            print("💾 已更新缓存星座：\(currentZodiac)")
        }
    }
    
    // MARK: - 获取今日食签（带缓存逻辑）
    
    /// 获取今日食签
    /// - 如果本地有今日缓存且未过00:00，直接返回
    /// - 如果星座发生变化，清理缓存并重新获取
    /// - 否则调用 API 生成新的食签
    func getTodayFortune(forceRefresh: Bool = false) async -> DailyFoodFortune? {
        // 检查星座是否发生变化
        if hasZodiacChanged() {
            print("♻️ 星座发生变化，清理食签缓存...")
            clearFortuneCache()
            updateCachedZodiac()
        }
        
        // 检查是否需要强制刷新
        if !forceRefresh {
            // 检查本地缓存
            if let cached = loadTodayFortuneFromLocal(), !isNewDay() {
                print("✅ 使用本地缓存的今日食签")
                await MainActor.run {
                    self.todayFortune = cached
                }
                return cached
            }
        }
        
        // 避免重复请求
        guard !isLoading else {
            print("⏳ 正在加载中...")
            return todayFortune
        }
        
        // 检查 API 配置
        guard AIConfig.apiKey != "YOUR_API_KEY" else {
            print("⚠️ API Key 未配置，使用默认食签")
            return getDefaultFortune()
        }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let fortune = try await fetchFortuneFromAPI()
            await MainActor.run {
                self.todayFortune = fortune
                self.isLoading = false
            }
            saveTodayFortuneToLocal(fortune)
            return fortune
        } catch {
            print("❌ 获取食签失败：\(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
            return getDefaultFortune()
        }
    }
    
    // MARK: - API 请求
    
    private func fetchFortuneFromAPI() async throws -> DailyFoodFortune {
        guard let url = URL(string: AIConfig.baseURL) else {
            throw FortuneError.invalidURL
        }
        
        // 构建上下文
        let context = FortuneContext(
            userZodiac: ZodiacUtil.loadZodiacSign() ?? "未知星座",
            currentDate: getCurrentDateString(),
            lunarDate: getLunarDate(),
            solarTerm: getSolarTerm(),
            city: LocationManager.shared.currentCity ?? "未知城市"
        )
        
        print("🔮 正在为用户 \(context.userZodiac) 推算今日食签...")
        print("📅 日期：\(context.currentDate)，农历：\(context.lunarDate)，节气：\(context.solarTerm)")
        
        let systemInstruction = buildSystemInstruction()
        let userPrompt = context.buildUserPrompt()
        
        let requestBody = ChatRequest(
            model: AIConfig.endpointID,
            messages: [
                ChatMessage(role: "system", content: systemInstruction),
                ChatMessage(role: "user", content: userPrompt)
            ]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let bodyData = try encoder.encode(requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FortuneError.apiError
        }
        
        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(ChatResponse.self, from: data)
        
        let rawContent = chatResponse.choices[0].message.content
        print("📝 AI 原始返回：\(rawContent)")
        
        let cleanedJSON = cleanJSONString(rawContent)
        print("🧹 清洗后 JSON：\(cleanedJSON)")
        
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            print("❌ 无法将清洗后的字符串转换为 Data")
            throw FortuneError.jsonParsingFailed
        }
        
        do {
            let fortune = try decoder.decode(DailyFoodFortune.self, from: jsonData)
            
            print("✅ 成功获取今日食签")
            print("   运势：\(fortune.fortuneStars)星")
            print("   宜：\(fortune.yiHighlight)")
            print("   忌：\(fortune.jiHighlight)")
            print("   开运食物：\(fortune.luckFood)")
            
            return fortune
        } catch {
            print("❌ JSON 解析失败：\(error)")
            print("❌ 尝试解析的数据：\(cleanedJSON)")
            throw FortuneError.jsonParsingFailed
        }
    }
    
    // MARK: - JSON 清洗
    
    private func cleanJSONString(_ rawString: String) -> String {
        var cleaned = rawString
        
        // 去除 markdown 代码块标记
        if let startRange = cleaned.range(of: "```json") {
            cleaned = String(cleaned[startRange.upperBound...])
        } else if let startRange = cleaned.range(of: "```") {
            cleaned = String(cleaned[startRange.upperBound...])
        }
        
        if let endRange = cleaned.range(of: "```", options: .backwards) {
            cleaned = String(cleaned[..<endRange.lowerBound])
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 提取 JSON 对象
        if let startBrace = cleaned.firstIndex(of: "{"),
           let endBrace = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startBrace...endBrace])
        }
        
        return cleaned
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
            date: Date()
        )
    }
    
    // MARK: - 本地持久化
    
    private func saveTodayFortuneToLocal(_ fortune: DailyFoodFortune) {
        if let encoded = try? JSONEncoder().encode(fortune) {
            UserDefaults.standard.set(encoded, forKey: Keys.todayFortune)
            UserDefaults.standard.set(getCurrentDateString(), forKey: Keys.fortuneDate)
            print("💾 今日食签已保存到本地")
        }
    }
    
    private func loadTodayFortuneFromLocal() -> DailyFoodFortune? {
        guard let data = UserDefaults.standard.data(forKey: Keys.todayFortune),
              let fortune = try? JSONDecoder().decode(DailyFoodFortune.self, from: data) else {
            return nil
        }
        return fortune
    }
    
    func loadFromLocal() {
        if let fortune = loadTodayFortuneFromLocal() {
            todayFortune = fortune
            print("📂 从本地加载今日食签")
        }
        hasInitialLoad = true
    }
    
    func clearLocalCache() {
        UserDefaults.standard.removeObject(forKey: Keys.todayFortune)
        UserDefaults.standard.removeObject(forKey: Keys.fortuneDate)
        todayFortune = nil
        print("🗑️ 食签缓存已清空")
    }
    
    /// 清理食签缓存（用于星座变化时）
    func clearFortuneCache() {
        UserDefaults.standard.removeObject(forKey: Keys.todayFortune)
        UserDefaults.standard.removeObject(forKey: Keys.fortuneDate)
        UserDefaults.standard.removeObject(forKey: Keys.cachedZodiacSign)
        todayFortune = nil
        print("🗑️ 食签缓存和星座缓存已清空")
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
            return "JSON 解析失败"
        case .configurationMissing:
            return "配置缺失：请设置 API Key 和 Endpoint ID"
        }
    }
}
