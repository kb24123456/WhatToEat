import Foundation

enum AppEnvironment {
    private nonisolated static func stringValue(forKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$") else {
            return nil
        }
        return trimmed
    }

    nonisolated static var backendBaseURL: URL? {
        guard let rawValue = stringValue(forKey: "BackendBaseURL") else {
            return nil
        }
        return URL(string: rawValue)
    }

    nonisolated static var backendProxyToken: String? {
        stringValue(forKey: "BackendProxyToken")
    }

    nonisolated static func backendURL(
        pathKey: String,
        defaultPath: String
    ) -> URL? {
        guard let baseURL = backendBaseURL else {
            return nil
        }
        let customPath = stringValue(forKey: pathKey) ?? defaultPath
        return baseURL.appending(path: customPath.hasPrefix("/") ? String(customPath.dropFirst()) : customPath)
    }
}

struct AIConfig {
    nonisolated static var generateFortuneURL: URL? {
        AppEnvironment.backendURL(
            pathKey: "BackendAIFortunePath",
            defaultPath: "/v1/food-fortune/generate"
        )
    }

    nonisolated static var isConfigured: Bool {
        generateFortuneURL != nil
    }
}

// MARK: - 配置验证工具
struct ConfigValidator {
    /// 检查所有配置是否完整
    static func validateAllConfigurations() -> [String] {
        var missingConfigs: [String] = []
        
        // 检查后端代理配置
        if !AIConfig.isConfigured {
            missingConfigs.append("AI 后端代理配置缺失 (BackendBaseURL / BackendAIFortunePath)")
        }
        
        return missingConfigs
    }
    
    /// 打印当前配置状态（调试用，不打印敏感值）
    static func printConfigurationStatus() {
        AppLogger.info("AI 后端代理: \(AIConfig.isConfigured ? "已配置" : "未配置")", category: .network)
    }
}
