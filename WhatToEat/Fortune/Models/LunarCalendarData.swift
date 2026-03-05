//
//  LunarCalendarData.swift
//  WhatToEat
//
//  黄历数据结构 - 聚合数据老黄历API响应模型
//

import Foundation

// MARK: - 聚合数据老黄历API响应
struct JuheLaohuangliResponse: Codable {
    let reason: String
    let result: LaohuangliResult?
    let errorCode: Int
    
    enum CodingKeys: String, CodingKey {
        case reason
        case result
        case errorCode = "error_code"
    }
    
    var isSuccess: Bool {
        return errorCode == 0 && result != nil
    }
}

// MARK: - 老黄历结果
struct LaohuangliResult: Codable {
    /// 阳历日期 yyyy-MM-dd
    let yangli: String
    
    /// 农历日期（包含干支信息，如：丙午(马)年正月十六）
    let yinli: String
    
    /// 宜事项列表
    let yi: String
    
    /// 忌事项列表
    let ji: String
    
    /// 五行
    let wuxing: String?
    
    /// 冲煞
    let chongsha: String?
    
    /// 百忌（原彭祖百忌）
    let baiji: String?
    
    /// 吉神
    let jishen: String?
    
    /// 凶神
    let xiongshen: String?
    
    /// 从农历日期提取干支年（如：丙午年）
    var ganzhiYear: String {
        // 从yinli中提取，如：丙午(马)年正月十六 → 丙午年
        if let match = yinli.range(of: "^[^（(]+", options: .regularExpression) {
            return String(yinli[match]).trimmingCharacters(in: .whitespaces) + "年"
        }
        return "未知"
    }
    
    /// 从农历日期提取干支月日（简化处理）
    var ganzhiMonth: String {
        return "正月" // 简化处理
    }
    
    var ganzhiDay: String {
        return "十六" // 从yinli提取日期
    }
    
    /// 建除十二神（从吉神中提取或返回默认值）
    var jianchu: String {
        return jishen?.components(separatedBy: " ").first ?? "未知"
    }
    
    /// 彭祖百忌（使用百忌字段）
    var pengzu: String {
        return baiji ?? "未知"
    }
    
    /// 节气（API可能不返回，使用默认值）
    var jieqi: String? {
        return nil
    }
    
    /// 节日（API可能不返回，使用默认值）
    var festival: String? {
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case yangli
        case yinli
        case yi
        case ji
        case wuxing
        case chongsha
        case baiji
        case jishen
        case xiongshen
    }
}

// MARK: - 应用层黄历数据模型
struct LunarCalendarData: Codable {
    /// 阳历日期
    let solarDate: String
    
    /// 农历日期
    let lunarDate: String
    
    /// 干支年 (如: 甲辰年)
    let ganzhiYear: String
    
    /// 干支月 (如: 丙寅月)
    let ganzhiMonth: String
    
    /// 干支日 (如: 甲子日)
    let ganzhiDay: String
    
    /// 宜事项列表
    let suitable: [String]
    
    /// 忌事项列表
    let unsuitable: [String]
    
    /// 建除十二神 (如: 开日、破日、收日)
    let jianchu: String
    
    /// 冲煞信息
    let chongsha: String
    
    /// 彭祖百忌
    let pengzu: String
    
    /// 当前节气
    let solarTerm: String
    
    /// 节日名称
    let festival: String
    
    /// 数据获取时间
    let fetchedAt: Date
}

// MARK: - 扩展：从聚合数据转换
extension LunarCalendarData {
    init(from juheResult: LaohuangliResult) {
        self.solarDate = juheResult.yangli
        self.lunarDate = juheResult.yinli
        self.ganzhiYear = juheResult.ganzhiYear
        self.ganzhiMonth = juheResult.ganzhiMonth
        self.ganzhiDay = juheResult.ganzhiDay
        
        // 解析宜忌列表（以空格分隔）
        self.suitable = juheResult.yi
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        
        self.unsuitable = juheResult.ji
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        
        self.jianchu = juheResult.jianchu ?? "未知"
        self.chongsha = juheResult.chongsha ?? "未知"
        self.pengzu = juheResult.pengzu ?? "未知"
        self.solarTerm = juheResult.jieqi ?? "无"
        self.festival = juheResult.festival ?? "无"
        self.fetchedAt = Date()
    }
}

// MARK: - 便捷属性
extension LunarCalendarData {
    /// 完整干支日期（如：甲辰年丙寅月甲子日）
    var fullGanzhi: String {
        return "\(ganzhiYear)\(ganzhiMonth)\(ganzhiDay)"
    }
    
    /// 宜忌摘要（用于展示）
    var yiJiSummary: String {
        let yiStr = suitable.prefix(3).joined(separator: "、")
        let jiStr = unsuitable.prefix(3).joined(separator: "、")
        return "宜:\(yiStr) 忌:\(jiStr)"
    }
    
    // MARK: - 缓存相关
    
    /// 缓存有效期 - 黄历数据按自然日判断
    /// 💡 规则：每个自然日只请求一次API，当天数据永不过期
    var isExpired: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // 检查是否是同一天
        guard calendar.isDate(fetchedAt, inSameDayAs: now) else {
            // 不是同一天，理论上应该由DailyRefreshManager控制不走到这里
            // 但如果走到了，说明是昨天的数据，标记为过期
            print("🌙 [LunarCalendarData] 数据是昨天的，标记为过期")
            return true
        }
        
        // 是同一天，数据永不过期（由DailyRefreshManager保证每天只请求一次）
        return false
    }
}
