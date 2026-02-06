import Foundation
import CoreFoundation

// MARK: - 拼音转换缓存
private let pinyinCache = NSCache<NSString, PinyinCacheEntry>()

private final class PinyinCacheEntry {
    let fullPinyin: String
    let initials: String
    
    init(fullPinyin: String, initials: String) {
        self.fullPinyin = fullPinyin
        self.initials = initials
    }
}

// MARK: - String 拼音扩展
extension String {
    
    /// 拼音转换结果
    struct PinyinResult {
        let fullPinyin: String      // 全拼，如 "zhongguo"
        let initials: String        // 首字母，如 "zg"
        let original: String        // 原始字符串
        
        /// 模糊匹配：检查 query 是否匹配原文、全拼或首字母
        func fuzzyMatch(query: String) -> Bool {
            let lowerQuery = query.lowercased()
            let lowerOriginal = original.lowercased()
            
            // 1. 直接匹配原文
            if lowerOriginal.contains(lowerQuery) {
                return true
            }
            
            // 2. 匹配全拼
            if fullPinyin.contains(lowerQuery) {
                return true
            }
            
            // 3. 匹配首字母
            if initials.contains(lowerQuery) {
                return true
            }
            
            return false
        }
        
        /// 计算匹配分数（用于排序）
        func matchScore(query: String) -> Int {
            let lowerQuery = query.lowercased()
            let lowerOriginal = original.lowercased()
            
            // 完全匹配分数最高
            if lowerOriginal == lowerQuery {
                return 100
            }
            
            // 开头匹配分数较高
            if lowerOriginal.hasPrefix(lowerQuery) {
                return 90
            }
            
            // 包含匹配
            if lowerOriginal.contains(lowerQuery) {
                return 80
            }
            
            // 全拼开头匹配
            if fullPinyin.hasPrefix(lowerQuery) {
                return 70
            }
            
            // 全拼包含匹配
            if fullPinyin.contains(lowerQuery) {
                return 60
            }
            
            // 首字母完全匹配
            if initials == lowerQuery {
                return 50
            }
            
            // 首字母开头匹配
            if initials.hasPrefix(lowerQuery) {
                return 40
            }
            
            return 0
        }
    }
    
    /// 转换为拼音（带缓存）
    var pinyin: PinyinResult {
        // 检查缓存
        if let cached = pinyinCache.object(forKey: self as NSString) {
            return PinyinResult(
                fullPinyin: cached.fullPinyin,
                initials: cached.initials,
                original: self
            )
        }
        
        // 转换为拼音
        let mutableString = NSMutableString(string: self)
        
        // 转换为不带音标的拼音
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        
        let fullPinyin = mutableString.lowercased as String
        
        // 提取首字母
        let initials = self.extractInitials()
        
        // 存入缓存
        let cacheEntry = PinyinCacheEntry(fullPinyin: fullPinyin, initials: initials)
        pinyinCache.setObject(cacheEntry, forKey: self as NSString)
        
        return PinyinResult(
            fullPinyin: fullPinyin,
            initials: initials,
            original: self
        )
    }
    
    /// 提取拼音首字母
    private func extractInitials() -> String {
        var initials = ""
        
        for char in self {
            let charString = String(char)
            let mutableString = NSMutableString(string: charString)
            
            CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
            CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
            
            let swiftString = mutableString as String
            if let firstChar = swiftString.first {
                initials.append(firstChar)
            }
        }
        
        return initials.lowercased()
    }
    
    /// 快速模糊匹配（静态方法）
    static func fuzzyMatch(text: String, query: String) -> Bool {
        return text.pinyin.fuzzyMatch(query: query)
    }
    
    /// 获取匹配分数（静态方法）
    static func matchScore(text: String, query: String) -> Int {
        return text.pinyin.matchScore(query: query)
    }
    
    /// 拼音包含检查（实例方法）
    /// 检查字符串的拼音是否包含查询词
    func pinyinContains(_ query: String) -> Bool {
        return self.pinyin.fuzzyMatch(query: query)
    }
}

// MARK: - 拼音匹配器（用于批量匹配和排序）
class PinyinMatcher {
    
    /// 在列表中搜索匹配项
    static func search<T: Searchable>(
        query: String,
        in items: [T],
        maxResults: Int = 10
    ) -> [T] {
        guard !query.isEmpty else { return [] }
        
        let lowerQuery = query.lowercased()
        
        // 过滤并计算分数
        let scoredItems: [(item: T, score: Int)] = items.compactMap { item in
            let searchText = item.searchText
            let score = String.matchScore(text: searchText, query: lowerQuery)
            
            guard score > 0 else { return nil }
            return (item, score)
        }
        
        // 按分数降序排序
        let sortedItems = scoredItems.sorted { $0.score > $1.score }
        
        // 返回前 N 个结果
        return sortedItems.prefix(maxResults).map { $0.item }
    }
    
    /// 异步搜索（用于大数据集）
    static func searchAsync<T: Searchable>(
        query: String,
        in items: [T],
        maxResults: Int = 10
    ) async -> [T] {
        return await Task.detached {
            return await MainActor.run {
                return search(query: query, in: items, maxResults: maxResults)
            }
        }.value
    }
}

// MARK: - 可搜索协议
protocol Searchable {
    var searchText: String { get }
}

// MARK: - 常用扩展
extension Restaurant: Searchable {
    var searchText: String {
        return name
    }
}

// MARK: - 缓存清理
extension PinyinMatcher {
    static func clearCache() {
        pinyinCache.removeAllObjects()
    }
}
