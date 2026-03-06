import Foundation

/// 全局设置键统一定义，避免散落字符串导致的配置不一致
enum AppSettingsKeys {
    static let userSelectedCity = "UserSelectedCity"
    static let preferredMapApp = "preferredMapApp"
    static let libraryDefaultSortOption = "LibraryDefaultSortOption"
    static let appAppearanceMode = "AppAppearanceMode"
    static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
    static let iCloudMigrationPayload = "iCloudMigrationPayload"
    static let didMigrateToICloud = "didMigrateToICloud"
    static let faceIDEnabled = "faceIDEnabled"
    static let appleUserID = "appleUserID"
    static let appleUserDisplayName = "appleUserDisplayName"
    static let searchHistory = "searchHistory"
    static let categoryCorrectionMap = "categoryCorrectionMap"
}
