import Foundation
import SwiftData

@MainActor
enum VisitLogDeduplicationService {
    private static let cleanupKey = AppSettingsKeys.didDeduplicateVisitLogsV1

    static func runIfNeeded(in container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: cleanupKey) == false else { return }

        let context = container.mainContext

        do {
            let logs = try context.fetch(FetchDescriptor<VisitLog>())
            let duplicates = duplicateLogs(in: logs)

            guard duplicates.isEmpty == false else {
                defaults.set(true, forKey: cleanupKey)
                return
            }

            duplicates.forEach { context.delete($0) }
            try context.save()
            defaults.set(true, forKey: cleanupKey)
        } catch {
            AppLogger.error("打卡去重失败: \(error.localizedDescription)", category: .storage)
        }
    }

    private static func duplicateLogs(in logs: [VisitLog]) -> [VisitLog] {
        var seen = Set<String>()
        var duplicates: [VisitLog] = []

        let sortedLogs = logs.sorted {
            if $0.date != $1.date {
                return $0.date < $1.date
            }
            return $0.id.uuidString < $1.id.uuidString
        }

        for log in sortedLogs {
            let signature = signature(for: log)
            if seen.contains(signature) {
                duplicates.append(log)
            } else {
                seen.insert(signature)
            }
        }

        return duplicates
    }

    private static func signature(for log: VisitLog) -> String {
        let restaurantID = log.restaurant?.id.uuidString ?? "no-restaurant"
        let timestamp = String(format: "%.3f", log.date.timeIntervalSince1970)
        let expense = String(format: "%.2f", log.expense)
        let photoSignature = log.photoFilenames.sorted().joined(separator: ",")

        return [
            restaurantID,
            timestamp,
            expense,
            String(log.peopleCount),
            log.goodDishes,
            log.badDishes,
            log.review,
            log.mood ?? "",
            photoSignature
        ].joined(separator: "|")
    }
}
