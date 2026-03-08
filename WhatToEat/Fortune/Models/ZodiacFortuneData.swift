//
//  ZodiacFortuneData.swift
//  WhatToEat
//
//  星座运势数据结构 - 聚合数据星座运势API响应模型
//

import Foundation

// MARK: - 星座枚举
nonisolated enum ZodiacSign: String, CaseIterable, Codable, Sendable {
    case aries = "白羊座"
    case taurus = "金牛座"
    case gemini = "双子座"
    case cancer = "巨蟹座"
    case leo = "狮子座"
    case virgo = "处女座"
    case libra = "天秤座"
    case scorpio = "天蝎座"
    case sagittarius = "射手座"
    case capricorn = "摩羯座"
    case aquarius = "水瓶座"
    case pisces = "双鱼座"
    
    /// 星座英文标识（用于API请求）
    nonisolated var apiKey: String {
        switch self {
        case .aries: return "aries"
        case .taurus: return "taurus"
        case .gemini: return "gemini"
        case .cancer: return "cancer"
        case .leo: return "leo"
        case .virgo: return "virgo"
        case .libra: return "libra"
        case .scorpio: return "scorpio"
        case .sagittarius: return "sagittarius"
        case .capricorn: return "capricorn"
        case .aquarius: return "aquarius"
        case .pisces: return "pisces"
        }
    }
    
    /// 星座日期范围（用于根据生日判断星座）
    /// 返回: (startMonth, startDay, endMonth, endDay)
    nonisolated var dateRange: (startMonth: Int, startDay: Int, endMonth: Int, endDay: Int) {
        switch self {
        case .aries: return (3, 21, 4, 19)
        case .taurus: return (4, 20, 5, 20)
        case .gemini: return (5, 21, 6, 21)
        case .cancer: return (6, 22, 7, 22)
        case .leo: return (7, 23, 8, 22)
        case .virgo: return (8, 23, 9, 22)
        case .libra: return (9, 23, 10, 23)
        case .scorpio: return (10, 24, 11, 22)
        case .sagittarius: return (11, 23, 12, 21)
        case .capricorn: return (12, 22, 1, 19)
        case .aquarius: return (1, 20, 2, 18)
        case .pisces: return (2, 19, 3, 20)
        }
    }
    
    /// 根据生日获取星座
    nonisolated static func from(birthDate: Date) -> ZodiacSign? {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: birthDate)
        let day = calendar.component(.day, from: birthDate)
        
        return ZodiacSign.allCases.first { sign in
            let range = sign.dateRange
            
            // 同月星座
            if range.startMonth == range.endMonth {
                return month == range.startMonth && day >= range.startDay && day <= range.endDay
            }
            
            // 跨年星座（如摩羯座 12/22 - 1/19）
            if range.startMonth > range.endMonth {
                // 12月部分
                if month == range.startMonth {
                    return day >= range.startDay
                }
                // 1月部分
                if month == range.endMonth {
                    return day <= range.endDay
                }
                return false
            }
            
            // 跨月但不跨年（如白羊座 3/21 - 4/19）
            if month == range.startMonth {
                return day >= range.startDay
            } else if month == range.endMonth {
                return day <= range.endDay
            }
            
            return false
        }
    }
    
    /// 根据中文名称获取星座
    nonisolated static func from(chineseName: String) -> ZodiacSign? {
        return ZodiacSign.allCases.first { $0.rawValue == chineseName }
    }
}

// MARK: - 聚合数据星座运势API响应
// 注意：星座API返回扁平化结构，不是嵌套的result对象
nonisolated struct JuheConstellationResponse: Codable, Sendable {
    // API状态字段
    let errorCode: Int
    let reason: String?
    let resultcode: String?
    
    // 星座数据字段（扁平化结构）
    let name: String?
    let datetime: String?
    let all: String?
    let love: String?
    let work: String?
    let money: String?
    let health: String?
    let color: String?
    let number: Int?
    let summary: String?
    let QFriend: String?
    
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case reason
        case resultcode
        case name
        case datetime
        case all
        case love
        case work
        case money
        case health
        case color
        case number
        case summary
        case QFriend
    }
    
    nonisolated var isSuccess: Bool {
        // 星座API返回error_code=0表示成功，且必须有name字段
        return errorCode == 0 && name != nil
    }
    
    /// 将扁平化的响应转换为ConstellationResult对象
    nonisolated func toConstellationResult() -> ConstellationResult? {
        guard let name = name,
              let all = all,
              let datetime = datetime else {
            return nil
        }
        
        return ConstellationResult(
            name: name,
            datetime: datetime,
            all: all,
            love: love ?? "",
            work: work ?? "",
            money: money ?? "",
            health: health ?? "",
            color: color ?? "",
            number: number ?? 0,
            QFriend: QFriend ?? "",
            summary: summary ?? ""
        )
    }
}

// MARK: - 星座运势结果
nonisolated struct ConstellationResult: Codable, Sendable {
    /// 星座名称
    let name: String
    
    /// 日期范围
    let datetime: String
    
    /// 综合运势分值 (0-100)
    let all: String
    
    /// 爱情运势分值
    let love: String
    
    /// 工作运势分值
    let work: String
    
    /// 财运分值
    let money: String
    
    /// 健康分值
    let health: String
    
    /// 幸运色
    let color: String
    
    /// 幸运数字（API返回整数）
    let number: Int
    
    /// 幸运数字（字符串形式）
    nonisolated var numberString: String {
        return String(number)
    }
    
    /// 速配星座
    let QFriend: String
    
    /// 运势简述
    let summary: String
}

// MARK: - 应用层星座运势数据模型
nonisolated struct ZodiacFortuneData: Codable, Sendable {
    /// 星座
    let zodiac: ZodiacSign
    
    /// 日期
    let date: String
    
    /// 综合运势分值 (1-100)
    let fortuneScore: Int
    
    /// 爱情运势分值 (1-100)
    let loveScore: Int
    
    /// 工作运势分值 (1-100)
    let workScore: Int
    
    /// 财运分值 (1-100)
    let moneyScore: Int
    
    /// 健康分值 (1-100)
    let healthScore: Int
    
    /// 幸运色（中文）
    let luckyColor: String
    
    /// 幸运数字
    let luckyNumbers: [Int]
    
    /// 速配星座
    let compatibleZodiac: String
    
    /// 运势摘要
    let summary: String
    
    /// 数据获取时间
    let fetchedAt: Date
}

// MARK: - 扩展：从聚合数据转换
extension ZodiacFortuneData {
    nonisolated init(from juheResult: ConstellationResult, zodiac: ZodiacSign) {
        self.zodiac = zodiac
        self.date = juheResult.datetime
        
        // 解析分值（API返回的是字符串）
        self.fortuneScore = Int(juheResult.all) ?? 80
        self.loveScore = Int(juheResult.love) ?? 80
        self.workScore = Int(juheResult.work) ?? 80
        self.moneyScore = Int(juheResult.money) ?? 80
        self.healthScore = Int(juheResult.health) ?? 80
        
        self.luckyColor = juheResult.color
        
        // 幸运数字（API返回整数，直接使用）
        self.luckyNumbers = [juheResult.number]
        
        self.compatibleZodiac = juheResult.QFriend
        self.summary = juheResult.summary
        self.fetchedAt = Date()
    }
}

// MARK: - 便捷属性
extension ZodiacFortuneData {
    /// 运势星级 (1-5)
    nonisolated var fortuneStars: Int {
        // 将0-100分映射到1-5星
        let score = max(0, min(100, fortuneScore))
        return max(1, Int(ceil(Double(score) / 20.0)))
    }
    
    /// 运势等级描述
    nonisolated var fortuneLevel: String {
        switch fortuneStars {
        case 5: return "大吉"
        case 4: return "吉"
        case 3: return "平"
        case 2: return "凶"
        case 1: return "大凶"
        default: return "未知"
        }
    }
    
    /// 幸运色英文（用于食物匹配）
    nonisolated var luckyColorEnglish: String {
        let colorMap: [String: String] = [
            "红色": "red", "绿色": "green", "蓝色": "blue",
            "黄色": "yellow", "白色": "white", "黑色": "black",
            "紫色": "purple", "橙色": "orange", "粉色": "pink",
            "灰色": "gray", "棕色": "brown", "青色": "cyan"
        ]
        
        // 查找包含的颜色
        for (cn, en) in colorMap {
            if luckyColor.contains(cn) {
                return en
            }
        }
        return "red" // 默认
    }
    
    /// 缓存有效期 - 星座数据按自然日判断
    /// 💡 规则：每个自然日只请求一次API（同一星座），当天数据永不过期
    nonisolated var isExpired: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // 检查是否是同一天
        guard calendar.isDate(fetchedAt, inSameDayAs: now) else {
            // 不是同一天，理论上应该由DailyRefreshManager控制不走到这里
            // 但如果走到了，说明是昨天的数据，标记为过期
            AppLogger.debug("星座缓存跨天，标记为过期", category: .storage)
            return true
        }
        
        // 是同一天，数据永不过期（由DailyRefreshManager保证每天只请求一次）
        return false
    }
}
