import Foundation

// MARK: - AI 配置模板
// 使用说明：
// 1. 复制此文件为 AppConfig.swift
// 2. 填入你的豆包 API Key 和 Endpoint ID
// 3. 确保 AppConfig.swift 已被添加到 .gitignore，不要提交到 Git

struct AIConfig {
    /// API Key - 从火山引擎控制台获取
    /// 获取方式：登录 https://console.volcengine.com/ → 方舟 → API Key 管理
    static let apiKey: String = "YOUR_API_KEY_HERE"
    
    /// 接入点 ID - 从火山引擎控制台获取
    /// 获取方式：登录 https://console.volcengine.com/ → 方舟 → 接入点管理
    static let endpointID: String = "YOUR_ENDPOINT_ID_HERE"
    
    /// 基础 URL - 豆包 API 地址（无需修改）
    static let baseURL: String = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
}
