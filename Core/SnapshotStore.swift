import Foundation

struct SnapshotStore: Sendable {
    let file: URL
    static let maximumBytes = 4 * 1024 * 1024
    enum Failure: LocalizedError {
        case version, oversized, unsafePath
        var errorDescription: String? {
            switch self {
            case .version: return "This data was saved by an unsupported app version. The original file has been preserved."
            case .oversized: return "The local data file exceeds the beta storage limit."
            case .unsafePath: return "The local data path is not a regular file."
            }
        }
    }
    func load() throws -> AppSnapshot {
        guard FileManager.default.fileExists(atPath: file.path) else { return AppSnapshot() }
        let attributes = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else { throw Failure.unsafePath }
        guard (attributes.fileSize ?? 0) <= Self.maximumBytes else { throw Failure.oversized }
        let snapshot = try JSONDecoder().decode(AppSnapshot.self, from: Data(contentsOf: file))
        guard snapshot.schemaVersion == 1 else { throw Failure.version }
        return snapshot
    }
    func save(_ snapshot: AppSnapshot) throws {
        guard snapshot.schemaVersion == 1 else { throw Failure.version }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        guard data.count <= Self.maximumBytes else { throw Failure.oversized }
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        var folder = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: file, options: .atomic)
        #endif
    }
}
