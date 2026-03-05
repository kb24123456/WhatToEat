import Foundation

// MARK: - AI 配置
// 用于配置豆包 API 的相关参数
// API Keys 从 Info.plist 读取（由 Config.xcconfig 在构建时注入）
struct AIConfig {
    
    /// 从 Info.plist 读取配置值
    private static func getConfigValue(forKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            print("⚠️ [AIConfig] 未找到配置项: \(key)")
            return ""
        }
        return value
    }
    
    /// API Key - 从 Config.xcconfig 通过 Info.plist 注入
    static var apiKey: String {
        return getConfigValue(forKey: "APIKeyDoubao")
    }
    
    /// 接入点 ID - 从 Config.xcconfig 通过 Info.plist 注入
    static var endpointID: String {
        return getConfigValue(forKey: "EndpointIDDoubao")
    }
    
    /// 基础 URL - 豆包 API 地址
    static let baseURL: String = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    
    /// 校验配置是否可用
    static var isConfigured: Bool {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = endpointID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !endpoint.isEmpty else { return false }
        return !key.hasPrefix("$") && !endpoint.hasPrefix("$")
    }
}

// MARK: - 配置验证工具
struct ConfigValidator {
    /// 检查所有配置是否完整
    static func validateAllConfigurations() -> [String] {
        var missingConfigs: [String] = []
        
        // 检查豆包API配置
        if !AIConfig.isConfigured {
            missingConfigs.append("豆包API配置缺失 (APIKeyDoubao / EndpointIDDoubao)")
        }
        
        return missingConfigs
    }
    
    /// 打印当前配置状态（调试用，不打印实际Key值）
    static func printConfigurationStatus() {
        print("=== API 配置状态 ===")
        print("豆包API: \(AIConfig.isConfigured ? "✅ 已配置" : "❌ 未配置")")
        print("===================")
    }
}
