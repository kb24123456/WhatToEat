//
//  RegionManager.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/23.
//

import Foundation

/// 区域管理中心，用于管理城市和行政区的层级关系
class RegionManager {
    // 单例实例
    static let shared = RegionManager()
    
    // 城市-行政区数据结构
    private let cityDistricts: [String: [String]]
    
    // 私有初始化方法，防止外部创建实例
    private init() {
        // 首先尝试从应用 bundle 目录直接加载文件路径
        if let bundlePath = Bundle.main.path(forResource: "regions", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
            cityDistricts = json
            print("RegionManager: Successfully loaded regions.json from bundle path, \(json.count) cities")
            return
        }
        
        // 如果 bundle 中没有，尝试从 Application Support 目录加载
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
                        cityDistricts = json
                        print("RegionManager: Successfully loaded \(json.count) cities from AppSupport")
                        return
                    }
                }
            }
            cityDistricts = [:]
        } catch {
            print("Error loading regions.json: \(error)")
            cityDistricts = [:]
        }
    }
    
    /// 获取所有城市列表
    var allCities: [String] {
        Array(cityDistricts.keys).sorted()
    }
    
    /// 根据城市名获取对应的行政区列表
    /// - Parameter city: 城市名称
    /// - Returns: 该城市的行政区列表，如果城市不存在则返回空数组
    func getDistricts(for city: String) -> [String] {
        cityDistricts[city] ?? []
    }
}
