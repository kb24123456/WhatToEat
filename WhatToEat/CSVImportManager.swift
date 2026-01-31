//
//  CSVImportManager.swift
//  WhatToEat
//
//  CSV 导入管理器 - 专门适配"馋嘴虎与好吃狗"餐厅清单
//

import Foundation
import SwiftData
import CoreLocation

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
        let allCities = RegionManager.shared.allCities
        var recognizedCity = defaultCity
        var finalDistrict = district
        
        // 1. 优先从地址中匹配城市
        for city in allCities {
            if address.contains(city) {
                recognizedCity = city
                break
            }
        }
        
        // 2. 特殊处理：永川区属于重庆
        if address.contains("永川") || district.contains("永川") {
            recognizedCity = "重庆"
            if district.contains("永川") {
                finalDistrict = "永川"
            } else if address.contains("永川区") {
                finalDistrict = "永川"
            }
        }
        
        // 3. 其他特殊处理可以在这里添加
        // 例如：涪陵区、万州区等都属于重庆
        let chongqingDistricts = ["涪陵", "万州", "合川", "江津", "南川", "綦江", "大足", "璧山", "铜梁", "潼南", "荣昌", "开州", "梁平", "武隆"]
        for d in chongqingDistricts {
            if address.contains(d) || district.contains(d) {
                recognizedCity = "重庆"
                if district.contains(d) {
                    finalDistrict = d
                }
                break
            }
        }
        
        return (recognizedCity, finalDistrict)
    }
}

// MARK: - 地理编码管理器
class GeocodingManager: ObservableObject {
    static let shared = GeocodingManager()
    
    private let geocoder = CLGeocoder()
    private var isProcessing = false
    private var queue: [Restaurant] = []
    
    @Published var totalCount: Int = 0
    @Published var completedCount: Int = 0
    @Published var isRunning = false
    
    private init() {}
    
    /// 开始批量地理编码
    func startBatchGeocoding(restaurants: [Restaurant], interval: TimeInterval = 1.5) {
        guard !isRunning else { return }
        
        // 筛选出需要补全坐标的餐厅
        queue = restaurants.filter { $0.latitude == 0 && $0.longitude == 0 }
        totalCount = queue.count
        completedCount = 0
        isRunning = true
        
        processNext(interval: interval)
    }
    
    /// 处理队列中的下一个
    private func processNext(interval: TimeInterval) {
        guard !queue.isEmpty else {
            isRunning = false
            return
        }
        
        let restaurant = queue.removeFirst()
        
        geocodeAddress(restaurant: restaurant) { [weak self] success in
            guard let self = self else { return }
            
            self.completedCount += 1
            
            if success {
                print("GeocodingManager: 成功获取 '\(restaurant.name)' 的坐标")
            } else {
                print("GeocodingManager: 无法获取 '\(restaurant.name)' 的坐标")
            }
            
            // 延迟处理下一个（遵守苹果频率限制）
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                self.processNext(interval: interval)
            }
        }
    }
    
    /// 单个地址地理编码
    private func geocodeAddress(restaurant: Restaurant, completion: @escaping (Bool) -> Void) {
        let address = restaurant.address
        
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("Geocoding error for '\(restaurant.name)': \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                completion(false)
                return
            }
            
            // 更新餐厅坐标
            restaurant.latitude = location.coordinate.latitude
            restaurant.longitude = location.coordinate.longitude
            
            completion(true)
        }
    }
    
    /// 取消所有任务
    func cancel() {
        queue.removeAll()
        geocoder.cancelGeocode()
        isRunning = false
    }
}

// MARK: - CSV 导入管理器
class CSVImportManager: ObservableObject {
    static let shared = CSVImportManager()
    
    @Published var importPhase: ImportPhase = .idle
    @Published var importedCount: Int = 0
    @Published var geocodingProgress: (completed: Int, total: Int) = (0, 0)
    @Published var errorMessage: String?
    
    private var cityRecognizer = CityRecognizer()
    private var cancellable: Any?
    
    private init() {
        // 监听地理编码进度
        cancellable = GeocodingManager.shared.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.geocodingProgress = (
                    GeocodingManager.shared.completedCount,
                    GeocodingManager.shared.totalCount
                )
            }
        }
    }
    
    /// 导入 CSV 文件
    func importCSV(from url: URL, modelContext: ModelContext, defaultCity: String = "重庆") async throws -> Int {
        // 阶段一：读取和解析
        await MainActor.run {
            self.importPhase = .parsing
            self.errorMessage = nil
        }
        
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
        await MainActor.run {
            self.importPhase = .importingText
        }
        
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
        
        await MainActor.run {
            self.importedCount = importedRestaurants.count
            self.importPhase = .geocoding
        }
        
        // 阶段三：异步补全坐标
        GeocodingManager.shared.startBatchGeocoding(
            restaurants: importedRestaurants,
            interval: 1.5
        )
        
        return importedRestaurants.count
    }
    
    /// 重置状态
    func reset() {
        importPhase = .idle
        importedCount = 0
        geocodingProgress = (0, 0)
        errorMessage = nil
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
            print("CSVImportManager: 检测到并移除了 UTF-8 BOM")
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

// MARK: - Combine 支持
import Combine

extension GeocodingManager {
    var objectWillChange: ObservableObjectPublisher {
        // 手动触发更新
        let publisher = ObservableObjectPublisher()
        // 在 completedCount 改变时调用 publisher.send()
        return publisher
    }
}
