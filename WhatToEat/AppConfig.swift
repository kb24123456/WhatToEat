import Foundation

// MARK: - AI 配置
// 用于配置豆包 API 的相关参数
struct AIConfig {
    /// API Key - 请在本地手动填入
    static let apiKey: String = "57f57b30-fec5-487e-a160-7c619701e38e"
    
    /// 接入点 ID - 请在本地手动填入
    static let endpointID: String = "ep-20260210035323-jgptr"
    
    /// 基础 URL - 豆包 API 地址
    static let baseURL: String = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
}
