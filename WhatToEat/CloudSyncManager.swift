import Foundation
import SwiftData

final class CloudSyncManager {
    static let shared = CloudSyncManager()
    private let migrationPayloadFileName = "icloud-migration-payload"

    private init() {
        migrateLegacyPayloadIfNeeded()
    }

    static func isICloudSyncEnabled() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: AppSettingsKeys.iCloudSyncEnabled) != nil else {
            return true
        }
        return defaults.bool(forKey: AppSettingsKeys.iCloudSyncEnabled)
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: AppSettingsKeys.iCloudSyncEnabled)
    }

    func prepareMigrationPayloadIfNeeded(restaurants: [Restaurant], logs: [VisitLog]) {
        guard !restaurants.isEmpty || !logs.isEmpty else { return }
        guard (try? ProtectedFileStore.read(fileName: migrationPayloadFileName)) == nil else { return }

        let restaurantDTOs = restaurants.map {
            RestaurantMigrationDTO(
                legacyID: $0.id.uuidString,
                name: $0.name,
                type: $0.type,
                district: $0.district,
                city: $0.city,
                rating: $0.rating,
                address: $0.address,
                latitude: $0.latitude,
                longitude: $0.longitude,
                coverPhotoFilename: $0.coverPhotoFilename,
                review: $0.review,
                tags: $0.tags,
                averagePrice: $0.averagePrice,
                createdAt: $0.createdAt
            )
        }
        let logDTOs = logs.map {
            VisitLogMigrationDTO(
                id: $0.id.uuidString,
                date: $0.date,
                expense: $0.expense,
                peopleCount: $0.peopleCount,
                goodDishes: $0.goodDishes,
                badDishes: $0.badDishes,
                review: $0.review,
                mood: $0.mood,
                photoFilenames: $0.photoFilenames,
                restaurantLegacyID: $0.restaurant?.id.uuidString
            )
        }
        let payload = MigrationPayload(restaurants: restaurantDTOs, logs: logDTOs)

        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? ProtectedFileStore.write(data, fileName: migrationPayloadFileName)
    }

    @MainActor
    func runPendingMigrationIfNeeded(modelContext: ModelContext) async {
        guard Self.isICloudSyncEnabled() else { return }
        guard !UserDefaults.standard.bool(forKey: AppSettingsKeys.didMigrateToICloud) else { return }
        guard let payloadData = try? ProtectedFileStore.read(fileName: migrationPayloadFileName),
              let payload = try? JSONDecoder().decode(MigrationPayload.self, from: payloadData)
        else {
            return
        }

        do {
            let existingRestaurants = try modelContext.fetch(FetchDescriptor<Restaurant>())
            var mapByLegacyID: [String: Restaurant] = [:]
            var mapBySignature: [String: Restaurant] = [:]

            for restaurant in existingRestaurants {
                let signature = "\(restaurant.name)|\(restaurant.address)|\(restaurant.city)|\(restaurant.district)"
                mapBySignature[signature] = restaurant
            }

            for dto in payload.restaurants {
                let signature = "\(dto.name)|\(dto.address)|\(dto.city)|\(dto.district)"
                if let existing = mapBySignature[signature] {
                    mapByLegacyID[dto.legacyID] = existing
                    continue
                }

                let created = Restaurant(
                    name: dto.name,
                    type: dto.type,
                    district: dto.district,
                    city: dto.city,
                    rating: dto.rating,
                    address: dto.address,
                    latitude: dto.latitude,
                    longitude: dto.longitude,
                    coverPhotoFilename: dto.coverPhotoFilename,
                    review: dto.review,
                    tags: dto.tags,
                    averagePrice: dto.averagePrice
                )
                created.createdAt = dto.createdAt
                modelContext.insert(created)
                mapByLegacyID[dto.legacyID] = created
                mapBySignature[signature] = created
            }

            let existingLogs = try modelContext.fetch(FetchDescriptor<VisitLog>())
            var logSignatures = Set(existingLogs.map { "\($0.date.timeIntervalSince1970)|\($0.expense)|\($0.peopleCount)|\($0.restaurant?.name ?? "")" })

            for dto in payload.logs {
                let signature = "\(dto.date.timeIntervalSince1970)|\(dto.expense)|\(dto.peopleCount)|\(dto.restaurantLegacyID ?? "")"
                guard !logSignatures.contains(signature) else { continue }

                let restaurant = dto.restaurantLegacyID.flatMap { mapByLegacyID[$0] }
                let log = VisitLog(
                    date: dto.date,
                    expense: dto.expense,
                    peopleCount: dto.peopleCount,
                    goodDishes: dto.goodDishes,
                    badDishes: dto.badDishes,
                    review: dto.review,
                    mood: dto.mood,
                    photoFilenames: dto.photoFilenames,
                    restaurant: restaurant
                )
                modelContext.insert(log)
                logSignatures.insert(signature)
            }

            try modelContext.save()
            UserDefaults.standard.set(true, forKey: AppSettingsKeys.didMigrateToICloud)
            try? ProtectedFileStore.delete(fileName: migrationPayloadFileName)
        } catch {
            AppLogger.error("iCloud 迁移失败: \(error.localizedDescription)", category: .storage)
        }
    }

    private func migrateLegacyPayloadIfNeeded() {
        let defaults = UserDefaults.standard
        guard let rawPayload = defaults.string(forKey: "iCloudMigrationPayload"),
              let payloadData = Data(base64Encoded: rawPayload)
        else {
            return
        }

        do {
            try ProtectedFileStore.write(payloadData, fileName: migrationPayloadFileName)
            defaults.removeObject(forKey: "iCloudMigrationPayload")
        } catch {
            AppLogger.error("迁移旧版 iCloud 载荷失败: \(error.localizedDescription)", category: .storage)
        }
    }
}

private struct MigrationPayload: Codable {
    let restaurants: [RestaurantMigrationDTO]
    let logs: [VisitLogMigrationDTO]
}

private struct RestaurantMigrationDTO: Codable {
    let legacyID: String
    let name: String
    let type: String
    let district: String
    let city: String
    let rating: Double
    let address: String
    let latitude: Double
    let longitude: Double
    let coverPhotoFilename: String?
    let review: String
    let tags: [String]
    let averagePrice: Double
    let createdAt: Date
}

private struct VisitLogMigrationDTO: Codable {
    let id: String
    let date: Date
    let expense: Double
    let peopleCount: Int
    let goodDishes: String
    let badDishes: String
    let review: String
    let mood: String?
    let photoFilenames: [String]
    let restaurantLegacyID: String?
}
