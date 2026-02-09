import Foundation
import Combine

// MARK: - AI 文案数据结构
struct AISlogan: Codable, Equatable {
    let title: String
    let subtitle: String
}

// MARK: - AI 文案管理器
/// 连接豆包 API 的核心桥梁，用于生成创意文案
/// 具备智能缓存、自动补货、循环显示功能
class AICopywritingManager: ObservableObject {
    
    // MARK: - 单例模式
    static let shared = AICopywritingManager()
    private init() {
        // 初始化时加载本地缓存
        loadFromLocal()
    }
    
    // MARK: - 缓存池
    /// 文案缓存池，使用 @Published 支持 SwiftUI 自动更新
    @Published var sloganPool: [AISlogan] = []
    
    /// 当前已使用的文案数量（用于计算剩余量）
    @Published var usedCount: Int = 0
    
    /// 是否正在加载中
    @Published var isLoading: Bool = false
    
    /// 是否已完成首次加载
    @Published var hasInitialLoad: Bool = false
    
    // MARK: - 本地金句兜底（The Safety Net）
    /// 当网络请求失败且本地无缓存时的兜底文案
    static let fallbackSlogans: [AISlogan] = [
        AISlogan(title: "把决策权交给胃", subtitle: "让灵感瞬时抵达。"),
        AISlogan(title: "食光正好", subtitle: "让味蕾在岁月中沉淀出温柔。"),
        AISlogan(title: "人间烟火气", subtitle: "最抚凡人心。"),
        AISlogan(title: "寻味而来", subtitle: "在食物的香气里遇见自己。"),
        AISlogan(title: "好食光", subtitle: "不负遇见。")
    ]
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let sloganPool = "ai_slogan_pool"
        static let usedCount = "ai_slogan_used_count"
    }
    
    // MARK: - System Prompt（系统指令）
    private let systemInstruction = """
    你是一位拥有 10 年经验的顶级美食生活方式杂志主编。你擅长用意蕴深长、极简且治愈的文字，描述人与食物、空间的关系。
    
    任务：生成关于'在餐厅库中寻找灵感'的创意短句。
    
    格式要求：严格返回 JSON 数组格式，包含 title (6-10字) 和 subtitle (10-18字)。不要包含任何多余的解释文字。
    
    禁忌：严禁使用'绝绝子、yyds、不容错过'等廉价词汇。
    
    示例输出格式：
    [
        {
            "title": "食光正好",
            "subtitle": "让味蕾在岁月中沉淀出温柔"
        },
        {
            "title": "人间烟火",
            "subtitle": "每一餐都是生活的仪式感"
        }
    ]
    """
    
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
    
    // MARK: - 持久化逻辑
    
    /// 保存缓存池到本地
    func saveToLocal() {
        if let encoded = try? JSONEncoder().encode(sloganPool) {
            UserDefaults.standard.set(encoded, forKey: Keys.sloganPool)
            UserDefaults.standard.set(usedCount, forKey: Keys.usedCount)
            print("💾 文案缓存已保存到本地，共 \(sloganPool.count) 条")
        }
    }
    
    /// 从本地加载缓存池
    func loadFromLocal() {
        // 加载文案池
        if let data = UserDefaults.standard.data(forKey: Keys.sloganPool),
           let decoded = try? JSONDecoder().decode([AISlogan].self, from: data) {
            sloganPool = decoded
            print("📂 从本地加载文案缓存，共 \(sloganPool.count) 条")
        }
        
        // 加载已使用数量
        usedCount = UserDefaults.standard.integer(forKey: Keys.usedCount)
        
        // 标记已完成初始加载
        hasInitialLoad = true
    }
    
    // MARK: - 智能补货逻辑 (The Refill Logic)
    
    /// 检查并补充文案池
    /// 当剩余文案少于 10 条时，自动发起请求补充
    func checkAndRefillPool() async {
        // 计算剩余可用文案数量
        let remaining = sloganPool.count - usedCount
        
        // 如果剩余文案充足，无需补货
        guard remaining < 10 else {
            print("✅ 文案池充足，剩余 \(remaining) 条")
            return
        }
        
        // 避免重复请求
        guard !isLoading else {
            print("⏳ 正在加载中，跳过本次补货")
            return
        }
        
        print("🔄 文案池不足（剩余 \(remaining) 条），开始补货...")
        isLoading = true
        
        do {
            // 请求 20 条新文案
            let newSlogans = try await fetchSlogans(count: 20)
            
            // 合并策略：追加到末尾并去重
            await MainActor.run {
                // 去重：只添加不存在的文案
                let existingTitles = Set(sloganPool.map { $0.title })
                let uniqueNewSlogans = newSlogans.filter { !existingTitles.contains($0.title) }
                
                sloganPool.append(contentsOf: uniqueNewSlogans)
                
                print("✅ 补货完成，新增 \(uniqueNewSlogans.count) 条，当前共 \(sloganPool.count) 条")
                
                // 保存到本地
                saveToLocal()
            }
        } catch {
            print("❌ 补货失败：\(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - 获取文案
    
    /// 根据索引获取文案
    /// - Parameter index: 当前卡片索引
    /// - Returns: 对应的文案（使用取模运算循环显示）
    func getSlogan(for index: Int) -> AISlogan {
        // 如果缓存池为空，返回兜底金句
        guard !sloganPool.isEmpty else {
            // 使用兜底金句循环显示
            let fallbackIndex = index % Self.fallbackSlogans.count
            return Self.fallbackSlogans[fallbackIndex]
        }
        
        // 使用取模运算循环显示
        let poolIndex = index % sloganPool.count
        return sloganPool[poolIndex]
    }
    
    /// 获取加载占位文案
    /// - Returns: 加载中的占位文案
    func getLoadingSlogan() -> AISlogan {
        return AISlogan(
            title: "正在为您打捞灵感...",
            subtitle: "请稍等片刻，美味即将就位 ✨"
        )
    }
    
    // MARK: - 网络请求
    
    /// 从 API 获取文案
    /// - Parameter count: 需要生成的文案组数
    /// - Returns: 解析后的文案数组
    private func fetchSlogans(count: Int) async throws -> [AISlogan] {
        // 检查配置
        guard !AIConfig.apiKey.isEmpty, !AIConfig.endpointID.isEmpty else {
            throw AIError.configurationMissing
        }
        
        // 1. 构建请求 URL
        guard let url = URL(string: AIConfig.baseURL) else {
            throw AIError.invalidURL
        }
        
        // 2. 构建请求体
        let requestBody = ChatRequest(
            model: AIConfig.endpointID,
            messages: [
                ChatMessage(role: "system", content: systemInstruction),
                ChatMessage(role: "user", content: "请立刻为我生成 \(count) 组文案。")
            ]
        )
        
        // 3. 编码请求体
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let bodyData = try encoder.encode(requestBody)
        
        // 4. 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 30 // 30秒超时
        
        // 5. 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 6. 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // 7. 解析响应
        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(ChatResponse.self, from: data)
        
        // 8. 提取 content 并清洗
        let rawContent = chatResponse.choices[0].message.content
        let cleanedJSON = cleanJSONString(rawContent)
        
        // 9. 解析为 AISlogan 数组
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw AIError.jsonParsingFailed
        }
        
        let slogans = try decoder.decode([AISlogan].self, from: jsonData)
        
        // 10. 调试输出
        print("✅ AI 成功返回 \(slogans.count) 条数据")
        if let first = slogans.first {
            print("   第一条：\(first.title) - \(first.subtitle)")
        }
        
        return slogans
    }
    
    // MARK: - 私有方法
    
    /// 清洗 AI 返回的 JSON 字符串
    /// 去除可能存在的 ```json ... ``` 标记，只保留 [] 之间的内容
    private func cleanJSONString(_ rawString: String) -> String {
        var cleaned = rawString
        
        // 去除开头的 ```json 或 ```
        if let startRange = cleaned.range(of: "```json") {
            cleaned = String(cleaned[startRange.upperBound...])
        } else if let startRange = cleaned.range(of: "```") {
            cleaned = String(cleaned[startRange.upperBound...])
        }
        
        // 去除结尾的 ```
        if let endRange = cleaned.range(of: "```", options: .backwards) {
            cleaned = String(cleaned[..<endRange.lowerBound])
        }
        
        // 去除前后空白字符
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 提取 [ 和 ] 之间的内容（如果存在）
        if let startBracket = cleaned.firstIndex(of: "["),
           let endBracket = cleaned.lastIndex(of: "]") {
            cleaned = String(cleaned[startBracket...endBracket])
        }
        
        return cleaned
    }
}

// MARK: - 错误类型
enum AIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case jsonParsingFailed
    case invalidData
    case configurationMissing
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let statusCode):
            return "HTTP 错误：状态码 \(statusCode)"
        case .jsonParsingFailed:
            return "JSON 解析失败"
        case .invalidData:
            return "无效的数据"
        case .configurationMissing:
            return "配置缺失：请在 AppConfig.swift 中设置 API Key 和 Endpoint ID"
        }
    }
}
