import Foundation

// MARK: - AI 配置
// 用于配置豆包 API 的相关参数
struct AIConfig {
    /// API Key - 请在本地手动填入
    static let apiKey: String = ""
    
    /// 接入点 ID - 请在本地手动填入
    static let endpointID: String = ""
    
    /// 基础 URL - 豆包 API 地址
    static let baseURL: String = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
}
