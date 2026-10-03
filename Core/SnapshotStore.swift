import Foundation

/// Atomic local state with bounded reads. Refuse explicit linked storage paths;
/// this is not a general defense against a process that can concurrently mutate the sandbox.
struct SnapshotStore: Sendable {
    let file: URL
    static let maximumBytes = 4 * 1024 * 1024
    enum Failure: LocalizedError {
        case version, oversized, unsafePath
        var errorDescription: String? {
            switch self {
            case .version: return "This data was saved by an unsupported app version. The original file has been preserved."
            case .oversized: return "The local data file exceeds the beta storage limit."
            case .unsafePath: return "The local data path is not a regular file in a regular directory. Nothing was replaced."
            }
        }
    }
    private func attributes(_ url: URL) throws -> [FileAttributeKey: Any]? {
        do { return try FileManager.default.attributesOfItem(atPath: url.path) }
        catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile { return nil }
    }
    private func validatePath() throws -> [FileAttributeKey: Any]? {
        guard file.isFileURL else { throw Failure.unsafePath }
        if let parent = try attributes(file.deletingLastPathComponent()),
           parent[.type] as? FileAttributeType != .typeDirectory { throw Failure.unsafePath }
        let item = try attributes(file)
        if let item, item[.type] as? FileAttributeType != .typeRegular { throw Failure.unsafePath }
        return item
    }
    func load() throws -> AppSnapshot {
        guard let item = try validatePath() else { return AppSnapshot() }
        guard ((item[.size] as? NSNumber)?.intValue ?? Int.max) <= Self.maximumBytes else { throw Failure.oversized }
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        var data = Data()
        while true {
            let remaining = Self.maximumBytes + 1 - data.count
            guard remaining > 0 else { throw Failure.oversized }
            let chunk = try input.read(upToCount: min(64 * 1024, remaining)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
            guard data.count <= Self.maximumBytes else { throw Failure.oversized }
        }
        let snapshot = try JSONDecoder().decode(AppSnapshot.self, from: data)
        guard snapshot.schemaVersion == 1 else { throw Failure.version }
        return snapshot
    }
    func save(_ snapshot: AppSnapshot) throws {
        guard snapshot.schemaVersion == 1 else { throw Failure.version }
        _ = try validatePath()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        guard data.count <= Self.maximumBytes else { throw Failure.oversized }
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try validatePath()
        #if os(iOS)
        var folder = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: file, options: .atomic)
        #endif
    }
}
