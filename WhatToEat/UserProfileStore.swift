import Foundation

private struct StoredUserProfile: Codable {
    let nickname: String
    let bio: String
    let avatarFileName: String?
}

private struct LegacyStoredUserProfile: Codable {
    let nickname: String
    let bio: String
    let avatarData: Data?
}

enum UserProfileStore {
    private static let profileFileName = "user-profile.json"
    private static let avatarFileName = "user-profile-avatar.jpg"
    private static let legacyDefaultsKey = "userProfile"

    static func load(defaultProfile: UserProfile) -> UserProfile {
        if let profile = loadProtectedProfile() {
            removeLegacyProfileIfNeeded()
            return profile
        }

        if let migratedProfile = migrateLegacyProfileIfNeeded(defaultProfile: defaultProfile) {
            return migratedProfile
        }

        return defaultProfile
    }

    static func save(_ profile: UserProfile) {
        do {
            let avatarFileName = try persistAvatarData(profile.avatarData)
            let storedProfile = StoredUserProfile(
                nickname: profile.nickname,
                bio: profile.bio,
                avatarFileName: avatarFileName
            )
            let data = try JSONEncoder().encode(storedProfile)
            try ProtectedFileStore.write(data, fileName: profileFileName)
            removeLegacyProfileIfNeeded()
        } catch {
            AppLogger.error("保存用户资料失败: \(error.localizedDescription)", category: .storage)
        }
    }

    private static func loadProtectedProfile() -> UserProfile? {
        guard
            let data = try? ProtectedFileStore.read(fileName: profileFileName),
            let storedProfile = try? JSONDecoder().decode(StoredUserProfile.self, from: data)
        else {
            return nil
        }

        let avatarData: Data?
        if let avatarFileName = storedProfile.avatarFileName {
            avatarData = try? ProtectedFileStore.read(fileName: avatarFileName) ?? nil
        } else {
            avatarData = nil
        }

        return UserProfile(
            nickname: storedProfile.nickname,
            bio: storedProfile.bio,
            avatarData: avatarData
        )
    }

    private static func migrateLegacyProfileIfNeeded(defaultProfile: UserProfile) -> UserProfile? {
        guard
            let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
            let legacyProfile = try? JSONDecoder().decode(LegacyStoredUserProfile.self, from: data)
        else {
            return nil
        }

        let migratedProfile = UserProfile(
            nickname: legacyProfile.nickname,
            bio: legacyProfile.bio,
            avatarData: legacyProfile.avatarData
        )
        save(migratedProfile)
        removeLegacyProfileIfNeeded()
        return migratedProfile
    }

    private static func persistAvatarData(_ avatarData: Data?) throws -> String? {
        guard let avatarData else {
            try? ProtectedFileStore.delete(fileName: avatarFileName)
            return nil
        }

        try ProtectedFileStore.write(avatarData, fileName: avatarFileName)
        return avatarFileName
    }

    private static func removeLegacyProfileIfNeeded() {
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
    }
}
