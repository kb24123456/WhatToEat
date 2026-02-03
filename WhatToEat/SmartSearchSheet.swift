import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - 可唯一标识的 MapItem 包装器
struct IdentifiableMapItem: Identifiable {
    let id = UUID() // 每次搜索生成新 ID，强制刷新视图
    let item: MKMapItem
}

// MARK: - 智能搜索半屏浮层
struct SmartSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var locationManager = LocationManager.shared
    
    @Query private var allRestaurants: [Restaurant]
    
    @Binding var selectedName: String
    @Binding var selectedAddress: String
    @Binding var selectedDistrict: String
    @Binding var selectedCategory: String
    @Binding var selectedLatitude: Double
    @Binding var selectedLongitude: Double
    
    // 高亮回调
    var onAutoFill: (() -> Void)?
    
    @State private var searchQuery = ""
    @State private var searchResults: [IdentifiableMapItem] = []
    @State private var nearbyPlaces: [IdentifiableMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
    // 防抖计时器
    @State private var debounceTimer: Timer?
    
    // 预热后的品类词库
    @State private var existingCategories: [String] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [
                        Color(hex: "#F5F3F0"),
                        Color(hex: "#FBF9F7")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 搜索栏
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    // 结果列表
                    resultsList
                }
            }
            .navigationTitle("智能搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#1A1A1A"))
                }
            }
        }
        .onAppear {
            precomputeExistingCategories()
            loadNearbyPlaces()
        }
    }
    
    // MARK: - 预热品类词库
    private func precomputeExistingCategories() {
        let presetCategories = CategoryManager.shared.getPresetCategories()
        let existingTypes = Set(allRestaurants.compactMap { $0.type })
        existingCategories = Array(Set(presetCategories + existingTypes))
    }
    
    // MARK: - 用户修正记忆库（局部进化）
    @AppStorage("categoryCorrectionMap") private var categoryCorrectionMapData: String = "{}"
    
    private var categoryCorrectionMap: [String: String] {
        get {
            guard let data = categoryCorrectionMapData.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                categoryCorrectionMapData = jsonString
            }
        }
    }
    
    // MARK: - 增强型语义映射词典（去重优化版）
    // 设计原则：
    // 1. 每个关键词只归属于最精准的品类
    // 2. 通过权重区分优先级，高权重品类优先匹配
    // 3. 通用词（如"店"）不放进去，避免误匹配
    private let semanticMappings: [(standard: String, keywords: [String], weight: Int)] = [
        // 火锅类 - 最高权重，关键词专属
        ("火锅", [
            "火锅", "串串", "打边炉", "冒菜", "涮", "重油", "肚", "肉卷", "毛肚", "鸭肠", "黄喉",
            "锅底", "九宫格", "鸳鸯锅", "麻辣", "牛油", "红油", "老火锅", "新派火锅",
            "海底捞", "小龙坎", "大龙燚", "德庄", "巴奴", "珮姐", "电台巷", "蜀大侠", "周师兄"
        ], weight: 10),
        
        // 面馆类 - 中式面食专属
        ("面馆", [
            "面", "面庄", "面馆", "拉面", "抄手", "馄饨", "饺子", "水饺",
            "担担面", "宜宾燃面", "刀削面", "烩面", "炸酱面", "热干面",
            "重庆小面", "豌杂面", "肥肠面", "牛肉面", "排骨面", "鸡杂面"
        ], weight: 8),
        
        // 粉线类 - 从原面馆分离，更精准
        ("粉线", [
            "粉", "米线", "河粉", "米粉", "螺蛳粉", "酸辣粉", "桂林米粉", "过桥米线",
            "新疆炒米粉", "南昌拌粉", "湖南米粉", "肠粉", "沙河粉"
        ], weight: 8),
        
        // 烧烤类
        ("烧烤", [
            "烧烤", "烤肉", "炙", "烤串", "烤鱼", "烤羊腿", "烤全羊", "烤翅",
            "撸串", "大排档", "夜市", "烤吧", "BBQ", "Barbecue",
            "炭火", "火盆烧烤", "韩式烤肉", "日式烧肉", "和牛烤肉"
        ], weight: 8),
        
        // 咖啡类 - 专注咖啡，去除烘焙重叠词
        ("咖啡", [
            "咖啡", "拿铁", "美式", "卡布奇诺", "摩卡", "Espresso", "Latte", "Cappuccino",
            "Coffee", "咖啡店", "咖啡馆", "咖啡厅", "咖啡屋", "咖啡实验室",
            "星巴克", "瑞幸", "Luckin", "Manner", "M Stand", "%Arabica", "Seesaw",
            "Tims", "Costa", "Peets", "皮爷", "蓝瓶", "Blue Bottle"
        ], weight: 7),
        
        // 茶饮类 - 专注奶茶果茶
        ("茶饮", [
            "奶茶", "果茶", "柠檬茶", "鲜榨", "茶饮", "Tea", "喜茶", "HeyTea",
            "奈雪", "Naixue", "茶颜悦色", "一点点", "CoCo", "都可", "贡茶",
            "蜜雪冰城", "茶百道", "古茗", "书亦", "益禾堂"
        ], weight: 7),
        
        // 甜品类 - 专注甜品甜点
        ("甜品", [
            "甜品", "甜点", "蛋糕", "Cake", "千层", "慕斯", "提拉米苏", "芝士蛋糕",
            "舒芙蕾", "松饼", "华夫饼", "可丽饼", "冰淇淋", "Ice Cream",
            "糖水", "双皮奶", "姜撞奶", "龟苓膏", "冰粉", "凉糕"
        ], weight: 7),
        
        // 烘焙类 - 专注面包糕点
        ("烘焙", [
            "烘焙", "面包", "Bread", "吐司", "可颂", "贝果", "Bagel", "Croissant",
            "欧包", "法棍", "甜甜圈", "Donut", "泡芙", "蛋挞", "马卡龙",
            "法甜", "法式甜品", "日式面包", "软欧包", "碱水包"
        ], weight: 6),
        
        // 日本料理
        ("日本料理", [
            "日料", "寿司", "Sushi", "刺身", "Sashimi", "天妇罗", "Tempura",
            "居酒屋", "Izakaya", "烧鸟", "Yakitori", "铁板烧", "Teppanyaki",
            "丼饭", "Donburi", "和牛", "Wagyu", "omakase", "Omakase", "怀石", "Kaiseki",
            "关东煮", "寿喜烧", "Sukiyaki", "拉面", "Ramen", "味千"
        ], weight: 7),
        
        // 韩国料理
        ("韩国料理", [
            "韩式", "韩餐", "韩国料理", "Korean", "部队锅", "石锅拌饭", "Bibimbap",
            "泡菜", "Kimchi", "炸鸡", "韩式炸鸡", "年糕", "Tteokbokki",
            "冷面", "Naengmyeon", "参鸡汤", "大酱汤", "烤肉", "韩式烤肉"
        ], weight: 6),
        
        // 西餐
        ("西餐", [
            "西餐", "西餐厅", "Western", "牛排", "Steak", "意面", "Pasta", "意大利面",
            "披萨", "Pizza", "汉堡", "Hamburger", "三明治", "Sandwich",
            "沙拉", "Salad", "轻食", "Brunch", "法餐", "French", "意大利", "Italian",
            "扒房", "Grill", "Bistro", "牛排馆", "意式", "法式"
        ], weight: 7),
        
        // 小吃快餐
        ("小吃快餐", [
            "快餐", "小吃", "Fast Food", "盖浇饭", "黄焖鸡", "卤肉饭", "猪脚饭",
            "蛋炒饭", "炒饭", "炒面", "炒粉", "便当", "盒饭", "简餐",
            "兰州拉面", "沙县", "沙县小吃", "速食", "快餐店",
            "麦当劳", "McDonald", "肯德基", "KFC", "汉堡王", "Burger King",
            "华莱士", "塔斯汀", "Shake Shack", "Five Guys", "Subway", "赛百味"
        ], weight: 5),
        
        // 粤菜
        ("粤菜", [
            "粤菜", "广东菜", "Cantonese", "茶餐厅", "港式", "点心", "Dim Sum",
            "烧腊", "烧鹅", "叉烧", "白切鸡", "肠粉", "Cheung Fun",
            "煲仔饭", "Claypot Rice", "粥", "Congee", "早茶", "虾饺", "凤爪",
            "干炒牛河", "云吞面", "及第粥", "双皮奶"
        ], weight: 7),
        
        // 川菜
        ("川菜", [
            "川菜", "四川菜", "Sichuan", "川味", "水煮", "酸菜鱼", "毛血旺",
            "辣子鸡", "回锅肉", "麻婆豆腐", "夫妻肺片", "口水鸡",
            "钵钵鸡", "冷吃兔", "江湖菜", "自贡菜", "盐帮菜", "成都菜",
            "重庆菜", "渝菜", "麻辣", "红油", "花椒", "泡椒"
        ], weight: 7),
        
        // 湘菜
        ("湘菜", [
            "湘菜", "湖南菜", "Hunan", "剁椒", "小炒肉", "辣椒炒肉",
            "口味虾", "口味蛇", "臭豆腐", "糖油粑粑", "擂椒", "土匪鸭",
            "剁椒鱼头", "农家小炒肉", "干锅", "湘西", "长沙菜"
        ], weight: 6),
        
        // 海鲜
        ("海鲜", [
            "海鲜", "Seafood", "鱼", "虾", "蟹", "贝类", "水产",
            "渔港", "码头", "蒸汽海鲜", "海鲜大咖", "海鲜自助",
            "生蚝", "扇贝", "鲍鱼", "龙虾", "Lobster", "大闸蟹",
            "帝王蟹", "三文鱼", "金枪鱼", "日料海鲜", "刺身海鲜"
        ], weight: 7),
        
        // 小酒馆
        ("小酒馆", [
            "酒馆", "酒吧", "Bar", "Pub", "精酿", "Craft Beer",
            "啤酒", "Beer", "调酒", "鸡尾酒", "Cocktail",
            "Whisky", "威士忌", "Whiskey", "清吧", "Livehouse",
            "驻唱", "DJ", "夜店", "Club", "Lounge", "酒廊"
        ], weight: 6),
        
        // 特色餐厅 - 兜底但有特色
        ("特色餐厅", [
            "私房菜", "Private Kitchen", "创意菜", "融合菜", "分子料理",
            "地方菜", "农家菜", "土菜", "土菜馆", "农家乐",
            "老字号", "百年老店", "非遗", "传统美食",
            "网红店", "打卡", "必吃", "必吃榜", "黑珍珠", "米其林"
        ], weight: 4)
    ]
    
    // MARK: - 相似度词库（用于自动修正）
    private let similarCategories: [String: [String]] = [
        "火锅": ["串串", "麻辣烫", "冒菜"],
        "面馆": ["面食", "面条", "面庄"],
        "粉线": ["米粉", "米线", "河粉"],
        "烧烤": ["烤肉", "烤串"],
        "咖啡": ["咖啡店", "咖啡馆"],
        "茶饮": ["奶茶店", "果茶"],
        "甜品": ["甜点", "蛋糕店"],
        "烘焙": ["面包店", "糕点"],
        "日本料理": ["日料", "寿司店"],
        "西餐": ["西餐厅", "牛排馆"],
        "小吃快餐": ["快餐", "小吃"]
    ]
    
    // MARK: - 确定品类（三层级深度优化识别引擎）
    private func determineCategory(from mapItem: MKMapItem) -> (category: String, isAutoMatched: Bool) {
        let rawName = mapItem.name ?? ""
        let title = mapItem.placemark.title ?? ""
        
        // 第零步：字符串脱敏预处理
        let cleanedName = deepCleanString(rawName)
        let cleanedTitle = deepCleanString(title)
        let searchString = preprocessString(cleanedName + " " + cleanedTitle)
        
        // 第一步：用户修正记忆库（局部进化）
        if let correctedCategory = categoryCorrectionMap[cleanedName] {
            return (correctedCategory, true)
        }
        
        // 第二步：数据库"记忆"学习（User-Data First）
        if let matched = findBestMatchFromUserHistory(cleanedName: cleanedName, searchString: searchString) {
            return (matched, true)
        }
        
        // 第三步：增强型语义映射（词频加权 + 权重优先级）
        if let matched = findBestMatchFromSemanticMappings(searchString: searchString) {
            // 尝试自动修正为数据库已有的相近品类
            if let corrected = correctToExistingCategory(matched) {
                return (corrected, true)
            }
            return (matched, true)
        }
        
        // 第四步：MapKit 原生 POI 深度解析
        let poiCategory = mapPOICategoryToOurCategory(mapItem.pointOfInterestCategory, name: cleanedName)
        if poiCategory != "其他" {
            return (poiCategory, true)
        }
        
        // 第五步：模糊匹配补丁（编辑距离算法）
        if let fuzzyMatched = findFuzzyMatch(searchString: searchString) {
            return (fuzzyMatched, true)
        }
        
        // 第六步：兜底
        return ("其他", false)
    }
    
    // MARK: - 字符串脱敏预处理（The Cleaner）
    private func deepCleanString(_ input: String) -> String {
        var cleaned = input
        
        // 1. 移除所有括号及其内容
        cleaned = cleaned.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\[([^\\]]*)\\]", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "【([^】]*)】", with: "", options: .regularExpression)
        
        // 2. 移除常见分店标识
        let branchPatterns = ["旗舰店", "总店", "分店", "直营店", "加盟店", "概念店", "体验店", "快闪店", "POPUP"]
        for pattern in branchPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
        }
        
        // 3. 移除常用地名后缀（但保留核心词）
        // 注意：这里不移除"店"，因为很多店名包含"店"字
        let locationPatterns = ["馆", "厅", "房", "屋", "社", "坊", "阁", "轩", "斋", "居", "苑", "园"]
        for pattern in locationPatterns {
            if cleaned.hasSuffix(pattern) && cleaned.count > 2 {
                cleaned = String(cleaned.dropLast(pattern.count))
                break
            }
        }
        
        // 4. 移除特殊符号和多余空格
        cleaned = cleaned.replacingOccurrences(of: "[^\\u4e00-\\u9fa5a-zA-Z0-9]", with: "", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 基础字符串预处理
    private func preprocessString(_ input: String) -> String {
        input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }
    
    // MARK: - 第二步：数据库"记忆"学习（User-Data First）
    private func findBestMatchFromUserHistory(cleanedName: String, searchString: String) -> String? {
        // 1. 精确匹配：已有餐厅名称包含当前搜索店名
        for restaurant in allRestaurants {
            let existingName = restaurant.name
            let existingType = restaurant.type
            
            let cleanedExistingName = deepCleanString(existingName)
            
            // 如果已有餐厅名称包含当前搜索关键词，复用品类
            if cleanedExistingName.contains(cleanedName) || cleanedName.contains(cleanedExistingName) {
                return existingType
            }
            
            // 检查核心词匹配（如"张姐火锅"和"张姐火锅大坪店"）
            let existingCore = extractCoreName(cleanedExistingName)
            let currentCore = extractCoreName(cleanedName)
            if !existingCore.isEmpty && !currentCore.isEmpty &&
               (existingCore == currentCore || existingCore.contains(currentCore) || currentCore.contains(existingCore)) {
                return existingType
            }
        }
        
        // 2. 数据库既有品类直配
        if let exactMatch = existingCategories.first(where: { category in
            searchString.contains(preprocessString(category))
        }) {
            return exactMatch
        }
        
        // 次之：店名包含数据库品类
        if let containsMatch = existingCategories.first(where: { category in
            let categoryClean = preprocessString(category)
            return searchString.contains(categoryClean)
        }) {
            return containsMatch
        }
        
        return nil
    }
    
    // MARK: - 提取核心店名（去除通用后缀）
    private func extractCoreName(_ name: String) -> String {
        var core = name
        let suffixes = ["火锅", "烧烤", "面馆", "餐厅", "咖啡", "奶茶", "汉堡", "炸鸡", "寿司", "料理", "西餐", "中餐", "快餐", "小吃"]
        for suffix in suffixes {
            if core.hasSuffix(suffix) {
                core = String(core.dropLast(suffix.count))
                break
            }
        }
        return core
    }
    
    // MARK: - 第三步：增强型语义映射（词频加权 + 权重优先级）
    private func findBestMatchFromSemanticMappings(searchString: String) -> String? {
        var matches: [(category: String, score: Int, weight: Int)] = []
        
        for mapping in semanticMappings {
            var score = 0
            for keyword in mapping.keywords {
                let cleanKeyword = preprocessString(keyword)
                if searchString.contains(cleanKeyword) {
                    // 词频加权：匹配到的关键词数量 × 品类权重
                    score += mapping.weight
                }
            }
            
            // 记录所有有分数的匹配
            if score > 0 {
                matches.append((mapping.standard, score, mapping.weight))
            }
        }
        
        // 按权重降序、分数降序排序
        matches.sort { a, b in
            if a.weight != b.weight {
                return a.weight > b.weight  // 权重高的优先
            }
            return a.score > b.score  // 同权重下分数高的优先
        }
        
        // 返回最高分的匹配（需要达到一定阈值）
        guard let bestMatch = matches.first else { return nil }
        
        // 阈值判断：根据权重设定不同阈值
        let threshold = bestMatch.weight >= 8 ? bestMatch.weight : bestMatch.weight + 2
        return bestMatch.score >= threshold ? bestMatch.category : nil
    }
    
    // MARK: - 自动修正为数据库已有的相近品类
    private func correctToExistingCategory(_ matched: String) -> String? {
        // 1. 如果数据库已有该品类，直接返回
        if existingCategories.contains(matched) {
            return matched
        }
        
        // 2. 查找相似词库中是否有数据库已有的品类
        if let similarWords = similarCategories[matched] {
            if let existingSimilar = existingCategories.first(where: { dbCategory in
                similarWords.contains { $0 == dbCategory }
            }) {
                return existingSimilar
            }
        }
        
        // 3. 模糊匹配：检查数据库品类是否包含匹配词
        if let dbMatch = existingCategories.first(where: { dbCategory in
            let dbClean = preprocessString(dbCategory)
            let matchedClean = preprocessString(matched)
            // 检查是否有交集字符
            return Set(dbClean).intersection(Set(matchedClean)).count >= min(dbClean.count, matchedClean.count) / 2
        }) {
            return dbMatch
        }
        
        // 4. 检查是否可以通过部分字符匹配
        if let partialMatch = existingCategories.first(where: { dbCategory in
            let dbClean = preprocessString(dbCategory)
            let matchedClean = preprocessString(matched)
            // 一个包含另一个的部分字符
            return dbClean.contains(matchedClean) || matchedClean.contains(dbClean)
        }) {
            return partialMatch
        }
        
        return nil
    }
    
    // MARK: - 第四步：MapKit 原生 POI 深度解析
    private func mapPOICategoryToOurCategory(_ category: MKPointOfInterestCategory?, name: String) -> String {
        guard let category = category else {
            // 无 POI 类别时，尝试从名称推断
            return inferCategoryFromName(name)
        }
        
        // 使用 switch 精确匹配 MKPointOfInterestCategory
        switch category {
        case .bakery:
            return "烘焙"
        case .brewery, .winery, .distillery:
            return "小酒馆"
        case .cafe:
            // 根据名称区分咖啡和茶饮
            return inferCafeType(from: name)
        case .restaurant:
            // 餐厅类别但名称无特征时，设为"特色餐厅"而非"其他"
            let inferred = inferCategoryFromName(name)
            return inferred != "其他" ? inferred : "特色餐厅"
        case .foodMarket:
            return "小吃快餐"
        case .nightlife:
            return "小酒馆"
        case .hotel:
            // 酒店餐厅通常有特色
            return "特色餐厅"
        default:
            // 尝试从名称推断
            return inferCategoryFromName(name)
        }
    }
    
    // MARK: - 推断咖啡店类型
    private func inferCafeType(from name: String) -> String {
        let lowerName = name.lowercased()
        
        // 茶饮品牌
        let teaBrands = ["喜茶", "奈雪", "茶颜", "一点点", "coco", "贡茶", "蜜雪", "茶百道", "古茗", "书亦"]
        for brand in teaBrands {
            if lowerName.contains(brand.lowercased()) {
                return "茶饮"
            }
        }
        
        // 甜品店
        let dessertKeywords = ["甜", "蛋糕", "甜品", "千层", "慕斯", "舒芙蕾"]
        for keyword in dessertKeywords {
            if lowerName.contains(keyword) {
                return "甜品"
            }
        }
        
        // 默认为咖啡
        return "咖啡"
    }
    
    // MARK: - 从名称推断品类（POI 辅助）
    private func inferCategoryFromName(_ name: String) -> String {
        let lowerName = name.lowercased()
        
        // 咖啡品牌识别
        let coffeeBrands = [
            "starbucks", "starbuck", "瑞幸", "luckin", "manner",
            "m stand", "%arabica", "seesaw", "tims", "costa", "peets", "皮爷"
        ]
        for brand in coffeeBrands {
            if lowerName.contains(brand) {
                return "咖啡"
            }
        }
        
        // 茶饮品牌识别
        let teaBrands = [
            "喜茶", "heytea", "奈雪", "nayuki", "茶颜悦色",
            "一点点", "coco", "贡茶", "蜜雪冰城"
        ]
        for brand in teaBrands {
            if lowerName.contains(brand.lowercased()) {
                return "茶饮"
            }
        }
        
        // 快餐品牌识别
        let fastFoodBrands = [
            "麦当劳", "mcdonald", "肯德基", "kfc",
            "汉堡王", "burger king", "华莱士", "塔斯汀"
        ]
        for brand in fastFoodBrands {
            if lowerName.contains(brand) {
                return "小吃快餐"
            }
        }
        
        // 火锅品牌识别
        let hotpotBrands = [
            "海底捞", "小龙坎", "大龙燚", "德庄",
            "巴奴", "珮姐", "电台巷", "蜀大侠"
        ]
        for brand in hotpotBrands {
            if lowerName.contains(brand) {
                return "火锅"
            }
        }
        
        return "其他"
    }
    
    // MARK: - 第五步：模糊匹配补丁（编辑距离算法思想）
    private func findFuzzyMatch(searchString: String) -> String? {
        // 检查是否有 2 个字符以上的重合
        for mapping in semanticMappings {
            let standard = mapping.standard
            let cleanStandard = preprocessString(standard)
            
            // 计算字符交集
            let searchSet = Set(searchString)
            let standardSet = Set(cleanStandard)
            let intersection = searchSet.intersection(standardSet)
            
            // 如果交集字符数 >= 2，且占标准品类名的一半以上
            if intersection.count >= 2 && intersection.count >= cleanStandard.count / 2 {
                return standard
            }
            
            // 检查是否包含标准品类的核心词（如"日料中心"与"日料"）
            if searchString.contains(cleanStandard) || cleanStandard.contains(searchString) {
                return standard
            }
        }
        
        // 检查数据库品类
        for category in existingCategories {
            let cleanCategory = preprocessString(category)
            let searchSet = Set(searchString)
            let categorySet = Set(cleanCategory)
            let intersection = searchSet.intersection(categorySet)
            
            if intersection.count >= 2 && intersection.count >= cleanCategory.count / 2 {
                return category
            }
        }
        
        return nil
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "#999999"))
            
            TextField("输入店名，智能填充所有信息...", text: $searchQuery)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#1A1A1A"))
                .onChange(of: searchQuery) { _, newValue in
                    handleSearchInput(newValue)
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }
    
    // MARK: - 结果列表（优化版：ScrollView + LazyVStack 替代 List）
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if searchQuery.isEmpty {
                    // 默认显示附近推荐
                    if !nearbyPlaces.isEmpty {
                        // Header
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                            Text("附近推荐")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#666666"))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // 附近地点卡片
                        ForEach(nearbyPlaces) { identifiableItem in
                            nearbyPlaceCard(for: identifiableItem)
                                .padding(.horizontal, 20)
                        }
                    }
                } else {
                    // 搜索结果
                    if isSearching {
                        // 加载中
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.2)
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else if searchResults.isEmpty {
                        // 无结果提示
                        VStack(spacing: 12) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: "#CCCCCC"))
                            Text("未找到相关地点")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#999999"))
                        }
                        .padding(.top, 60)
                    } else {
                        // 搜索结果列表
                        ForEach(searchResults) { identifiableItem in
                            searchResultCard(for: identifiableItem)
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 附近地点卡片
    private func nearbyPlaceCard(for identifiableItem: IdentifiableMapItem) -> some View {
        let item = identifiableItem.item
        let name = item.name ?? "未知地点"
        let address = item.placemark.title ?? ""
        let distance = calculateDistance(to: item.placemark.coordinate)
        
        return Button {
            selectPlace(identifiableItem)
        } label: {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F0F0F0"))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "mappin.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                        .lineLimit(1)
                    
                    if !address.isEmpty {
                        Text(address)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#999999"))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 距离
                if let distance = distance {
                    Text(distance)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#FFF0F0"))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 搜索结果卡片
    private func searchResultCard(for identifiableItem: IdentifiableMapItem) -> some View {
        let item = identifiableItem.item
        let name = item.name ?? "未知地点"
        let address = item.placemark.title ?? ""
        let (category, isAutoMatched) = determineCategory(from: item)
        
        return Button {
            selectPlace(identifiableItem)
        } label: {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F5F3F0"))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconForCategory(category))
                        .font(.system(size: 18))
                        .foregroundColor(colorForCategory(category))
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                        
                        // 智能识别标签
                        if isAutoMatched {
                            Text(category)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#FFF0F0"))
                                )
                        }
                    }
                    .lineLimit(1)
                    
                    if !address.isEmpty {
                        Text(address)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#999999"))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#CCCCCC"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 选择地点
    private func selectPlace(_ identifiableItem: IdentifiableMapItem) {
        let item = identifiableItem.item
        let placemark = item.placemark
        
        // 设置基本信息
        selectedName = item.name ?? ""
        selectedAddress = placemark.title ?? ""
        selectedLatitude = placemark.coordinate.latitude
        selectedLongitude = placemark.coordinate.longitude
        
        // 智能识别品类
        let (category, _) = determineCategory(from: item)
        selectedCategory = category
        
        // 提取区域信息
        if let city = placemark.locality {
            // 从地址中提取区县
            let addressComponents = [placemark.subLocality, placemark.thoroughfare].compactMap { $0 }
            selectedDistrict = addressComponents.first ?? ""
        }
        
        // 触发高亮动画
        onAutoFill?()
        
        // 关闭浮层
        dismiss()
    }
    
    // MARK: - 处理搜索输入
    private func handleSearchInput(_ query: String) {
        // 取消之前的任务
        searchTask?.cancel()
        debounceTimer?.invalidate()
        
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // 防抖：延迟 0.3 秒后执行搜索
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            self.performSearch(query: query)
        }
    }
    
    // MARK: - 执行搜索
    private func performSearch(query: String) {
        searchTask = Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = .pointOfInterest
            
            // 设置搜索区域为当前位置附近
            if let userLocation = locationManager.userLocation {
                request.region = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    latitudinalMeters: 50000,  // 50km 范围
                    longitudinalMeters: 50000
                )
            }
            
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                guard !Task.isCancelled else { return }
                
                // 过滤并排序结果
                let filteredResults = response.mapItems
                    .filter { item in
                        // 过滤掉非餐饮类地点
                        if let category = item.pointOfInterestCategory {
                            let categoryString = String(describing: category)
                            return categoryString.contains("restaurant") ||
                                   categoryString.contains("food") ||
                                   categoryString.contains("cafe") ||
                                   categoryString.contains("bakery") ||
                                   categoryString.contains("bar")
                        }
                        // 如果没有类别信息，保留结果让语义识别处理
                        return true
                    }
                    .sorted { a, b in
                        // 按距离排序
                        guard let userLocation = locationManager.userLocation else { return true }
                        let distA = userLocation.distance(from: CLLocation(latitude: a.placemark.coordinate.latitude, longitude: a.placemark.coordinate.longitude))
                        let distB = userLocation.distance(from: CLLocation(latitude: b.placemark.coordinate.latitude, longitude: b.placemark.coordinate.longitude))
                        return distA < distB
                    }
                
                await MainActor.run {
                    self.searchResults = filteredResults.map { IdentifiableMapItem(item: $0) }
                    self.isSearching = false
                }
            } catch {
                print("搜索失败: \(error)")
                await MainActor.run {
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }
    
    // MARK: - 加载附近地点
    private func loadNearbyPlaces() {
        guard let userLocation = locationManager.userLocation else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "餐厅"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: 5000,  // 5km 范围
            longitudinalMeters: 5000
        )
        
        Task {
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                await MainActor.run {
                    self.nearbyPlaces = response.mapItems.prefix(5).map { IdentifiableMapItem(item: $0) }
                }
            } catch {
                print("加载附近地点失败: \(error)")
            }
        }
    }
    
    // MARK: - 计算距离
    private func calculateDistance(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let userLocation = locationManager.userLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = userLocation.distance(from: targetLocation)
        
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    // MARK: - 品类图标
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "火锅": return "flame.fill"
        case "面馆", "粉线": return "fork.knife"
        case "烧烤": return "flame"
        case "咖啡": return "cup.and.saucer.fill"
        case "茶饮": return "mug.fill"
        case "甜品": return "birthday.cake.fill"
        case "烘焙": return "bag.fill"
        case "日本料理": return "fish.fill"
        case "韩国料理": return "bowl.fill"
        case "西餐": return "fork.knife.circle.fill"
        case "小吃快餐": return "takeoutbag.and.cup.and.straw.fill"
        case "粤菜": return "bowl.fill"
        case "川菜": return "pepper.hot.fill"
        case "湘菜": return "leaf.fill"
        case "海鲜": return "fish.circle.fill"
        case "小酒馆": return "wineglass.fill"
        case "特色餐厅": return "star.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    // MARK: - 品类颜色
    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "火锅": return Color(hex: "#FF6B6B")
        case "面馆", "粉线": return Color(hex: "#FFB347")
        case "烧烤": return Color(hex: "#FF8C42")
        case "咖啡": return Color(hex: "#8B4513")
        case "茶饮": return Color(hex: "#90EE90")
        case "甜品": return Color(hex: "#FFB6C1")
        case "烘焙": return Color(hex: "#DDA0DD")
        case "日本料理": return Color(hex: "#FF69B4")
        case "韩国料理": return Color(hex: "#FF1493")
        case "西餐": return Color(hex: "#4169E1")
        case "小吃快餐": return Color(hex: "#FFD700")
        case "粤菜": return Color(hex: "#32CD32")
        case "川菜": return Color(hex: "#DC143C")
        case "湘菜": return Color(hex: "#228B22")
        case "海鲜": return Color(hex: "#00CED1")
        case "小酒馆": return Color(hex: "#9370DB")
        case "特色餐厅": return Color(hex: "#FF6347")
        default: return Color(hex: "#999999")
        }
    }
}

// MARK: - 预览
#Preview {
    SmartSearchSheet(
        selectedName: .constant(""),
        selectedAddress: .constant(""),
        selectedDistrict: .constant(""),
        selectedCategory: .constant(""),
        selectedLatitude: .constant(0),
        selectedLongitude: .constant(0)
    )
}
