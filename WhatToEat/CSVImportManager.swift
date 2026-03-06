//
//  CSVImportManager.swift
//  WhatToEat
//
//  CSV 导入管理器 - 专门适配"馋嘴虎与好吃狗"餐厅清单
//

import Foundation
import SwiftData
import CoreLocation
import MapKit
import Combine

// MARK: - CSV 餐厅数据模型
struct CSVRestaurantRecord {
    let name: String
    let type: String
    let rating: Double
    let district: String
    let address: String
    let review: String
    
    /// 从 CSV 行解析
    static func from(csvRow: [String]) -> CSVRestaurantRecord? {
        guard csvRow.count >= 6 else { return nil }
        
        // 字段映射：餐厅名称,分类,味道评价,区域,地理位置,一句话锐评
        let name = csvRow[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let type = csvRow[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let ratingString = csvRow[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let district = csvRow[3].trimmingCharacters(in: .whitespacesAndNewlines)
        let address = csvRow[4].trimmingCharacters(in: .whitespacesAndNewlines)
        let review = csvRow[5].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 解析评分（支持 "4.5" 或 "4.5分" 格式）
        let rating = parseRating(ratingString)
        
        return CSVRestaurantRecord(
            name: name,
            type: type,
            rating: rating,
            district: district,
            address: address,
            review: review
        )
    }
    
    /// 解析评分字符串
    private static func parseRating(_ string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: "分", with: "")
            .replacingOccurrences(of: "★", with: "")
            .replacingOccurrences(of: "☆", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 3.0
    }
}

// MARK: - CSV 解析器
class CSVParser {
    
    /// 解析 CSV 文件内容
    static func parse(content: String) -> [CSVRestaurantRecord] {
        var records: [CSVRestaurantRecord] = []
        
        // 按行分割
        let lines = content.components(separatedBy: .newlines)
        
        // 跳过标题行，从第二行开始解析
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // 跳过标题行
            
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // 解析 CSV 行（处理逗号和引号）
            let columns = parseCSVLine(trimmedLine)
            
            if let record = CSVRestaurantRecord.from(csvRow: columns) {
                records.append(record)
            }
        }
        
        return records
    }
    
    /// 解析单行 CSV（处理引号和逗号）
    private static func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        var previousChar: Character?
        
        for char in line {
            if char == "\"" {
                // 处理转义引号 ("")
                if insideQuotes, let prev = previousChar, prev == "\"" {
                    currentColumn.append(char)
                } else {
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                // 逗号分隔符（不在引号内）
                columns.append(currentColumn.trimmingCharacters(in: .whitespacesAndNewlines))
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
            previousChar = char
        }
        
        // 添加最后一列
        columns.append(currentColumn.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return columns
    }
}

// MARK: - 城市识别器
class CityRecognizer {
    
    /// 默认城市（当无法识别时）
    var defaultCity: String = "重庆"
    
    /// 从地址识别城市
    func recognizeCity(from address: String, district: String) -> (city: String, district: String) {
        let normalized = RestaurantCityNormalizer.normalize(
            address: address,
            district: district,
            fallbackCity: defaultCity
        )
        return (normalized.city, normalized.district)
    }
}

// MARK: - 地理编码管理器
@MainActor
class GeocodingManager: ObservableObject {
    static let shared = GeocodingManager()
    
    private var activeRequest: MKGeocodingRequest?
    private var queue: [Restaurant] = []
    private var batchCompletion: (() -> Void)?
    
    @Published var totalCount: Int = 0
    @Published var completedCount: Int = 0
    @Published var isRunning = false
    
    private init() {}
    
    /// 开始批量地理编码
    func startBatchGeocoding(
        restaurants: [Restaurant],
        interval: TimeInterval = 1.5,
        completion: (() -> Void)? = nil
    ) {
        guard !isRunning else {
            completion?()
            return
        }

        // 筛选出需要补全坐标的餐厅
        queue = restaurants.filter { $0.latitude == 0 && $0.longitude == 0 }
        totalCount = queue.count
        completedCount = 0
        isRunning = true
        batchCompletion = completion

        guard !queue.isEmpty else {
            isRunning = false
            batchCompletion?()
            batchCompletion = nil
            return
        }
        
        processNext(interval: interval)
    }
    
    /// 处理队列中的下一个
    private func processNext(interval: TimeInterval) {
        guard !queue.isEmpty else {
            isRunning = false
            batchCompletion?()
            batchCompletion = nil
            return
        }
        
        let restaurant = queue.removeFirst()
        
        geocodeAddress(restaurant: restaurant) { [weak self] _ in
            guard let self = self else { return }
            
            self.completedCount += 1
            
            // 延迟处理下一个（遵守苹果频率限制）
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                self.processNext(interval: interval)
            }
        }
    }
    
    /// 单个地址地理编码
    private func geocodeAddress(restaurant: Restaurant, completion: @escaping (Bool) -> Void) {
        let address = restaurant.address

        guard let request = MKGeocodingRequest(addressString: address) else {
            completion(false)
            return
        }

        activeRequest = request
        request.getMapItems(completionHandler: { mapItems, error in
            self.activeRequest = nil

            if let error {
                print("Geocoding error for '\(restaurant.name)': \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let location = mapItems?.first?.location else {
                completion(false)
                return
            }

            // 更新餐厅坐标
            restaurant.latitude = location.coordinate.latitude
            restaurant.longitude = location.coordinate.longitude

            completion(true)
        })
    }
    
    /// 取消所有任务
    func cancel() {
        queue.removeAll()
        activeRequest?.cancel()
        activeRequest = nil
        isRunning = false
        batchCompletion = nil
    }
}

// MARK: - CSV 导入管理器
@MainActor
class CSVImportManager: ObservableObject {
    static let shared = CSVImportManager()
    
    @Published var importPhase: ImportPhase = .idle
    @Published var importedCount: Int = 0
    @Published var errorMessage: String?
    
    // 记录本次导入的餐厅 ID，用于批量删除
    @Published var lastImportedRestaurantIDs: [UUID] = []
    
    private var cityRecognizer = CityRecognizer()
    
    private init() {}
    
    /// 导入 CSV 文件
    func importCSV(from url: URL, modelContext: ModelContext, defaultCity: String = "重庆") async throws -> Int {
        // 阶段一：读取和解析
        importPhase = .parsing
        errorMessage = nil
        
        // 开始安全作用域访问
        guard url.startAccessingSecurityScopedResource() else {
            throw CSVImportError.permissionDenied
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // 读取文件内容（处理 UTF-8 BOM）
        let content = try readCSVFileWithBOMHandling(url: url)
        
        // 解析 CSV
        let records = CSVParser.parse(content: content)
        
        guard !records.isEmpty else {
            throw CSVImportError.emptyFile
        }
        
        // 阶段二：导入文本数据
        importPhase = .importingText
        
        cityRecognizer.defaultCity = defaultCity
        var importedRestaurants: [Restaurant] = []
        
        for record in records {
            // 识别城市和区域
            let (city, district) = cityRecognizer.recognizeCity(
                from: record.address,
                district: record.district
            )
            
            // 创建餐厅对象
            let restaurant = Restaurant(
                name: record.name,
                type: record.type,
                district: district,
                city: city,
                rating: record.rating,
                address: record.address,
                latitude: 0.0,  // 稍后异步补全
                longitude: 0.0,
                coverPhotoFilename: nil,
                review: record.review,
                tags: [],
                averagePrice: 0.0
            )
            
            modelContext.insert(restaurant)
            importedRestaurants.append(restaurant)
        }
        
        // 保存到 SwiftData
        try modelContext.save()
        
        // 记录导入的餐厅 ID
        let importedIDs = importedRestaurants.map { $0.id }
        
        importedCount = importedRestaurants.count
        lastImportedRestaurantIDs = importedIDs
        importPhase = .geocoding
        
        // 阶段三：补全坐标并等待完成
        await withCheckedContinuation { continuation in
            GeocodingManager.shared.startBatchGeocoding(
                restaurants: importedRestaurants,
                interval: 1.5
            ) {
                continuation.resume()
            }
        }

        // 持久化地理编码后的坐标
        try modelContext.save()
        importPhase = .completed
        
        return importedRestaurants.count
    }
    
    /// 重置状态
    func reset() {
        importPhase = .idle
        importedCount = 0
        errorMessage = nil
        lastImportedRestaurantIDs = []
    }
    
    /// 批量删除上次导入的餐厅
    func deleteLastImportedRestaurants(modelContext: ModelContext) async throws -> Int {
        guard !lastImportedRestaurantIDs.isEmpty else {
            return 0
        }
        
        let idsToDelete = lastImportedRestaurantIDs
        var deletedCount = 0
        
        // 获取所有餐厅
        let descriptor = FetchDescriptor<Restaurant>()
        let allRestaurants = try modelContext.fetch(descriptor)
        
        // 删除匹配的餐厅
        for restaurant in allRestaurants {
            if idsToDelete.contains(restaurant.id) {
                modelContext.delete(restaurant)
                deletedCount += 1
            }
        }
        
        // 保存更改
        try modelContext.save()
        
        // 清空记录的 ID
        lastImportedRestaurantIDs = []
        importedCount = 0
        
        return deletedCount
    }
}

// MARK: - 导入阶段枚举
enum ImportPhase: Equatable {
    case idle
    case parsing        // 解析 CSV
    case importingText  // 导入文本数据
    case geocoding      // 补全坐标
    case completed      // 完成
    case error(String)  // 错误
}

// MARK: - 导入错误
enum CSVImportError: Error, LocalizedError {
    case emptyFile
    case invalidFormat
    case saveFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "CSV 文件为空或没有有效数据"
        case .invalidFormat:
            return "CSV 格式不正确"
        case .saveFailed:
            return "保存数据失败"
        case .permissionDenied:
            return "无法访问文件，请检查文件权限"
        }
    }
}

// MARK: - 文件读取辅助函数
/// 读取 CSV 文件并处理 UTF-8 BOM
private func readCSVFileWithBOMHandling(url: URL) throws -> String {
    // 读取原始数据
    let data = try Data(contentsOf: url)
    
    // 检查并移除 UTF-8 BOM (EF BB BF)
    let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
    var processedData = data
    
    if data.count >= 3 {
        let firstThreeBytes = [data[0], data[1], data[2]]
        if firstThreeBytes == bom {
            // 移除 BOM
            processedData = data.subdata(in: 3..<data.count)
        }
    }
    
    // 转换为字符串
    guard let content = String(data: processedData, encoding: .utf8) else {
        // 如果 UTF-8 失败，尝试其他编码
        if let content = String(data: processedData, encoding: .ascii) {
            return content
        }
        throw CSVImportError.invalidFormat
    }
    
    return content
}
