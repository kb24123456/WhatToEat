//
//  RegionManager.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/23.
//

import Foundation

/// 区域管理中心，用于管理城市和行政区的层级关系
/// 优化版：支持全国333个地级市，使用 CityData 作为数据源
class RegionManager {
    // 单例实例
    static let shared = RegionManager()
    
    // 城市-行政区数据结构（从JSON加载）
    private let cityDistricts: [String: [String]]
    
    // 私有初始化方法，防止外部创建实例
    private init() {
        var loadedData: [String: [String]] = [:]
        var loadSuccess = false
        var lastError: String = ""
        
        // 方式1: 使用 Bundle.main.url 加载（适用于已添加到 Copy Bundle Resources 的文件）
        if let url = Bundle.main.url(forResource: "regions", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String]] {
                    loadedData = json
                    loadSuccess = true
                    print("RegionManager: Loaded \(json.count) cities from main bundle")
                }
            } catch {
                lastError = "Bundle URL error: \(error.localizedDescription)"
            }
        } else {
            lastError = "regions.json not found in bundle resources"
        }
        
        // 方式2: 备用 - 从应用项目目录直接读取
        if !loadSuccess {
            let projectPath = Bundle.main.path(forResource: "regions", ofType: "json", inDirectory: nil)
            if let path = projectPath,
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
                loadedData = json
                loadSuccess = true
                print("RegionManager: Loaded \(json.count) cities from project directory")
            }
        }
        
        // 方式3: 备用 - 从 AppSupport 目录加载
        if !loadSuccess {
            do {
                if let appSupportDir = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first {
                    let appDirectory = appSupportDir.appendingPathComponent("WhatToEat")
                    let fileURL = appDirectory.appendingPathComponent("regions.json")
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let data = try Data(contentsOf: fileURL)
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String]] {
                            loadedData = json
                            loadSuccess = true
                            print("RegionManager: Loaded \(json.count) cities from AppSupport")
                        }
                    }
                }
            } catch {
                lastError = "AppSupport error: \(error.localizedDescription)"
            }
        }
        
        if !loadSuccess {
            print("RegionManager: Failed to load regions.json - \(lastError)")
        }
        
        cityDistricts = loadedData
    }
    
    // MARK: - 城市列表（使用 CityData）
    
    /// 获取所有城市列表（333个地级市）
    var allCities: [String] {
        return CityData.getCities()
    }
    
    /// 获取热门城市列表
    var hotCities: [String] {
        return CityData.hotCities
    }
    
    /// 搜索城市（支持中文、拼音、首字母）
    func searchCities(query: String) -> [String] {
        return CityData.searchCities(query: query)
    }
    
    /// 检查城市是否有效
    func isValidCity(_ city: String) -> Bool {
        return CityData.isValidCity(city)
    }
    
    // MARK: - 行政区查询（保持兼容）
    
    /// 根据城市名获取对应的行政区列表
    /// - Parameter city: 城市名称
    /// - Returns: 该城市的行政区列表，如果城市不存在则返回 ["其他"]
    func getDistricts(for city: String) -> [String] {
        // 1. 先从 JSON 加载的 districts 中查找
        if let districts = cityDistricts[city], !districts.isEmpty {
            return districts
        }
        
        // 2. 如果找不到，返回默认值
        return ["其他"]
    }
}
