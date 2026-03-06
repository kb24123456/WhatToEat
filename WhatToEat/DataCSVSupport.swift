import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 用于 fileExporter 的 CSV 文档封装（UTF-8 BOM，兼容 Excel/WPS/飞书）。
struct CSVTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    private let data: Data

    init(text: String) {
        let withBOM = "\u{FEFF}" + text
        self.data = Data(withBOM.utf8)
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum DataCSVSupport {
    nonisolated static let restaurantImportVersion = "WTE-RESTAURANT-CSV-v1"
    nonisolated static let consumptionExportVersion = "WTE-CONSUMPTION-CSV-v1"

    nonisolated static func makeRestaurantTemplateCSV(defaultCity: String = "重庆") -> String {
        let headers = [
            "name",
            "type",
            "rating",
            "district",
            "address",
            "review",
            "schema_version",
            "city",
            "average_price",
            "tags",
            "latitude",
            "longitude",
            "created_at"
        ]

        let nowString = filenameSafeDateFormatter.string(from: Date())
        let rows: [[String]] = [
            headers,
            [
                "示例餐厅A",
                "火锅",
                "4.5",
                "渝中区",
                "解放碑示例路 88 号",
                "食材新鲜，环境不错",
                restaurantImportVersion,
                defaultCity,
                "98.00",
                "聚会|二刷",
                "29.563010",
                "106.551557",
                nowString
            ],
            [
                "示例餐厅B",
                "川菜",
                "4.2",
                "两江新区",
                "金开大道示例段 66 号",
                "出餐快，性价比高",
                restaurantImportVersion,
                defaultCity,
                "62.00",
                "工作餐|回头客",
                "29.613700",
                "106.510300",
                nowString
            ]
        ]

        return rows.map(csvLine).joined(separator: "\r\n")
    }

    nonisolated static func makeRestaurantCSV(restaurants: [Restaurant]) -> String {
        let headers = [
            "name",
            "type",
            "rating",
            "district",
            "address",
            "review",
            "schema_version",
            "city",
            "average_price",
            "tags",
            "latitude",
            "longitude",
            "created_at"
        ]

        var rows: [[String]] = [headers]
        let dateFormatter = Self.filenameSafeDateFormatter

        for restaurant in restaurants.sorted(by: { $0.createdAt < $1.createdAt }) {
            rows.append([
                restaurant.name,
                restaurant.type,
                String(format: "%.1f", restaurant.rating),
                restaurant.district,
                restaurant.address,
                restaurant.review,
                restaurantImportVersion,
                restaurant.city,
                String(format: "%.2f", restaurant.averagePrice),
                restaurant.tags.joined(separator: "|"),
                String(format: "%.6f", restaurant.latitude),
                String(format: "%.6f", restaurant.longitude),
                dateFormatter.string(from: restaurant.createdAt)
            ])
        }

        return rows.map(csvLine).joined(separator: "\r\n")
    }

    nonisolated static func makeConsumptionCSV(logs: [VisitLog]) -> String {
        let headers = [
            "schema_version",
            "visit_date",
            "expense",
            "people_count",
            "per_person_price",
            "mood",
            "good_dishes",
            "bad_dishes",
            "review",
            "photo_filenames",
            "restaurant_name",
            "restaurant_type",
            "restaurant_city",
            "restaurant_district",
            "restaurant_address",
            "visit_id",
            "restaurant_id"
        ]

        var rows: [[String]] = [headers]
        let dateFormatter = Self.filenameSafeDateFormatter

        for log in logs.sorted(by: { $0.date > $1.date }) {
            let restaurant = log.restaurant
            rows.append([
                consumptionExportVersion,
                dateFormatter.string(from: log.date),
                String(format: "%.2f", log.expense),
                String(log.peopleCount),
                String(format: "%.2f", log.perPersonPrice),
                log.mood ?? "",
                log.goodDishes,
                log.badDishes,
                log.review,
                log.photoFilenames.joined(separator: "|"),
                restaurant?.name ?? "",
                restaurant?.type ?? "",
                restaurant?.city ?? "",
                restaurant?.district ?? "",
                restaurant?.address ?? "",
                log.id.uuidString,
                restaurant?.id.uuidString ?? ""
            ])
        }

        return rows.map(csvLine).joined(separator: "\r\n")
    }

    nonisolated static func makeExportFilename(prefix: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "\(prefix)_\(formatter.string(from: Date()))"
    }

    nonisolated private static func csvLine(_ columns: [String]) -> String {
        columns.map(csvCell).joined(separator: ",")
    }

    nonisolated private static func csvCell(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    nonisolated private static let filenameSafeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
