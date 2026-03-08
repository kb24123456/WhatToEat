import Foundation
import SwiftData

@MainActor
enum VisitLogMoodMigrationService {
    private static let migrationKey = AppSettingsKeys.didMigrateVisitLogMoodV2

    static func runIfNeeded(in container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: migrationKey) == false else { return }

        let context = container.mainContext

        do {
            let logs = try context.fetch(FetchDescriptor<VisitLog>())
            var hasChanges = false

            for log in logs {
                let normalizedMood = MoodType.normalizedStoredValue(from: log.mood)
                guard normalizedMood != log.mood else { continue }
                log.mood = normalizedMood
                hasChanges = true
            }

            if hasChanges {
                try context.save()
            }

            defaults.set(true, forKey: migrationKey)
        } catch {
            AppLogger.error("打卡感受迁移失败: \(error.localizedDescription)", category: .storage)
        }
    }
}
