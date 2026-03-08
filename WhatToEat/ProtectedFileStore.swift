import Foundation

enum ProtectedFileStoreError: LocalizedError {
    case baseDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .baseDirectoryUnavailable:
            return "无法定位受保护文件存储目录"
        }
    }
}

enum ProtectedFileStore {
    private static let directoryName = "ProtectedStorage"

    static func write(_ data: Data, fileName: String) throws {
        let url = try fileURL(for: fileName)
        try ensureDirectory()
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    static func read(fileName: String) throws -> Data? {
        let url = try fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try Data(contentsOf: url)
    }

    static func delete(fileName: String) throws {
        let url = try fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try FileManager.default.removeItem(at: url)
    }

    private static func ensureDirectory() throws {
        let directoryURL = try baseDirectoryURL()
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: directoryURL.path
        )
    }

    private static func fileURL(for fileName: String) throws -> URL {
        try baseDirectoryURL().appendingPathComponent(fileName)
    }

    private static func baseDirectoryURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ProtectedFileStoreError.baseDirectoryUnavailable
        }
        return appSupport.appendingPathComponent(directoryName, isDirectory: true)
    }
}
