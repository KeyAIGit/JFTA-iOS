import Foundation

/// A local beta store. No networking, account, or server upload is implemented.
/// A fresh UUID prefix prevents an import from overwriting an earlier document.
struct LocalDocument: Identifiable, Equatable, Sendable {
    let url: URL
    var id: String { url.lastPathComponent }
    var name: String { String(url.lastPathComponent.dropFirst(37)) }
}

struct LocalDocumentStore: Sendable {
    let directory: URL
    let maximumBytes: Int
    private static let allowedExtensions: Set<String> = ["pdf", "png", "jpg", "jpeg", "heic", "heif", "txt"]

    init(directory: URL, maximumBytes: Int = 25 * 1024 * 1024) {
        self.directory = directory.standardizedFileURL
        self.maximumBytes = maximumBytes
    }

    static func applicationStore() throws -> LocalDocumentStore {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StoreError.storageUnavailable
        }
        return LocalDocumentStore(directory: documents.appendingPathComponent("JFTAImports", isDirectory: true))
    }

    func importFile(from source: URL) throws -> LocalDocument {
        guard maximumBytes > 0, maximumBytes < Int.max else { throw StoreError.invalidConfiguration }
        _ = try directoryExists()
        guard source.isFileURL,
              Self.allowedExtensions.contains(source.pathExtension.lowercased()) else {
            throw StoreError.unsupportedType
        }
        // Reject aliases/symbolic links instead of silently following an unexpected target.
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw StoreError.notRegularFile
        }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        var bytes = Data()
        while true {
            let remaining = maximumBytes + 1 - bytes.count
            guard remaining > 0 else { throw StoreError.tooLarge }
            let chunk = try input.read(upToCount: min(64 * 1024, remaining)) ?? Data()
            if chunk.isEmpty { break }
            bytes.append(chunk)
            guard bytes.count <= maximumBytes else { throw StoreError.tooLarge }
        }
        guard !bytes.isEmpty else { throw StoreError.emptyFile }
        try prepareDirectory()
        let existing = try list()
        guard existing.count < 100 else { throw StoreError.capacity }
        let existingBytes = try existing.reduce(0) { count, document in
            count + (try document.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        guard existingBytes + bytes.count <= 200 * 1024 * 1024 else { throw StoreError.capacity }
        let destination = directory.appendingPathComponent(UUID().uuidString + "_" + source.lastPathComponent)
        do {
            #if os(iOS)
            try bytes.write(to: destination, options: [.atomic, .completeFileProtection])
            #else
            try bytes.write(to: destination, options: .atomic)
            #endif
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return LocalDocument(url: destination)
    }

    func list() throws -> [LocalDocument] {
        guard try directoryExists() else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]).compactMap { url in
                guard isOwnedURL(url) else { return nil }
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
                return LocalDocument(url: url)
            }.sorted { a, b in
                a.name == b.name ? a.id < b.id : a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }

    func delete(_ document: LocalDocument) throws {
        guard try directoryExists(), isOwnedURL(document.url) else { throw StoreError.outsideStore }
        let attributes = try FileManager.default.attributesOfItem(atPath: document.url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else { throw StoreError.notRegularFile }
        try FileManager.default.removeItem(at: document.url)
    }

    private func directoryExists() throws -> Bool {
        guard directory.isFileURL else { throw StoreError.outsideStore }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
            guard attributes[.type] as? FileAttributeType == .typeDirectory else { throw StoreError.unsafeDirectory }
            return true
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile { return false }
    }
    private func prepareDirectory() throws {
        _ = try directoryExists()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try directoryExists()
        #if os(iOS)
        // Sample documents in this beta should not be included in an iCloud backup.
        var folder = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        #endif
    }

    private func isOwnedURL(_ url: URL) -> Bool {
        guard url.isFileURL,
              url.standardizedFileURL.deletingLastPathComponent().path == directory.path,
              url.resolvingSymlinksInPath().deletingLastPathComponent().path == directory.resolvingSymlinksInPath().path else { return false }
        let name = url.lastPathComponent
        return name.count > 37 && UUID(uuidString: String(name.prefix(36))) != nil
            && name[name.index(name.startIndex, offsetBy: 36)] == "_"
    }

    enum StoreError: LocalizedError {
        case storageUnavailable, unsupportedType, notRegularFile, tooLarge, emptyFile, outsideStore, capacity, unsafeDirectory, invalidConfiguration
        var errorDescription: String? {
            switch self {
            case .unsafeDirectory: return "The local vault path is not a regular directory. No files were changed."
            case .invalidConfiguration: return "The local vault's import limit is invalid. Nothing was saved."
            case .capacity: return "The local vault limit is 100 files or 200 MiB."
            case .storageUnavailable: return "The local Documents directory is unavailable."
            case .unsupportedType: return "Choose a PDF, PNG, JPEG, HEIC, HEIF, or plain text file."
            case .notRegularFile: return "Choose a regular file, not a folder or symbolic link."
            case .tooLarge: return "This file exceeds the local vault's import size limit (25 MiB in the app)."
            case .emptyFile: return "The selected file is empty. Nothing was saved."
            case .outsideStore: return "This document does not belong to the local vault's local store."
            }
        }
    }
}
