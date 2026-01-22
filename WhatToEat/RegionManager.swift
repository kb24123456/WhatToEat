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
        // 从Bundle读取并解析regions.json文件
        do {
            if let fileURL = Bundle.main.url(forResource: "regions", withExtension: "json") {
                let data = try Data(contentsOf: fileURL)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String]] {
                    cityDistricts = json
                    return
                }
            }
            // 如果读取失败，使用默认空字典
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
