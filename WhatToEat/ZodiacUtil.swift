import Foundation

// MARK: - 星座工具类
/// 根据日期计算星座
struct ZodiacUtil {
    
    /// 星座枚举
    enum ZodiacSign: String, CaseIterable {
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
    }
    
    /// 根据日期计算星座
    /// - Parameter date: 出生日期
    /// - Returns: 星座字符串
    static func getZodiacSign(from date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        
        guard let month = components.month, let day = components.day else {
            return "未知星座"
        }
        
        switch (month, day) {
        case (3, 21...31), (4, 1...19):
            return ZodiacSign.aries.rawValue
        case (4, 20...30), (5, 1...20):
            return ZodiacSign.taurus.rawValue
        case (5, 21...31), (6, 1...21):
            return ZodiacSign.gemini.rawValue
        case (6, 22...30), (7, 1...22):
            return ZodiacSign.cancer.rawValue
        case (7, 23...31), (8, 1...22):
            return ZodiacSign.leo.rawValue
        case (8, 23...31), (9, 1...22):
            return ZodiacSign.virgo.rawValue
        case (9, 23...30), (10, 1...23):
            return ZodiacSign.libra.rawValue
        case (10, 24...31), (11, 1...22):
            return ZodiacSign.scorpio.rawValue
        case (11, 23...30), (12, 1...21):
            return ZodiacSign.sagittarius.rawValue
        case (12, 22...31), (1, 1...19):
            return ZodiacSign.capricorn.rawValue
        case (1, 20...31), (2, 1...18):
            return ZodiacSign.aquarius.rawValue
        case (2, 19...29), (3, 1...20):
            return ZodiacSign.pisces.rawValue
        default:
            return "未知星座"
        }
    }
    
    /// 保存用户生日到 UserDefaults
    /// - Parameter date: 出生日期
    static func saveBirthDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "user_birth_date")
        let zodiac = getZodiacSign(from: date)
        UserDefaults.standard.set(zodiac, forKey: "user_zodiac_sign")
        print("💾 已保存生日：\(date)，星座：\(zodiac)")
    }
    
    /// 从 UserDefaults 读取用户生日
    /// - Returns: 出生日期，未设置则返回 nil
    static func loadBirthDate() -> Date? {
        return UserDefaults.standard.object(forKey: "user_birth_date") as? Date
    }
    
    /// 从 UserDefaults 读取用户星座
    /// - Returns: 星座字符串，未设置则返回 nil
    static func loadZodiacSign() -> String? {
        return UserDefaults.standard.string(forKey: "user_zodiac_sign")
    }
    
    /// 清除用户生日和星座数据
    static func clearBirthData() {
        UserDefaults.standard.removeObject(forKey: "user_birth_date")
        UserDefaults.standard.removeObject(forKey: "user_zodiac_sign")
        print("🗑️ 已清除生日和星座数据")
    }
}
