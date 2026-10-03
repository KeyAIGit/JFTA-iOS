import XCTest
import Foundation
#if SWIFT_PACKAGE
@testable import JFTACore
#else
@testable import JFTA
#endif

final class CoreTests: XCTestCase {
    private var temp: URL!
    override func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent("JFTATests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { if let temp { try FileManager.default.removeItem(at: temp) } }
    private var disk: SnapshotStore { SnapshotStore(file: temp.appendingPathComponent("state/state.json")) }
    private var vault: LocalDocumentStore { LocalDocumentStore(directory: temp.appendingPathComponent("vault")) }
    private func source(_ name: String = "sample.txt", bytes: Data = Data("Sample file content".utf8)) throws -> URL {
        let path = temp.appendingPathComponent(name); try bytes.write(to: path); return path
    }
    func testEmptyStoreCreatesCleanState() throws { let state = try disk.load(); XCTAssertTrue(state.requests.isEmpty); XCTAssertFalse(state.profile.hasCompletedOnboarding); XCTAssertEqual(state.schemaVersion, 1) }
    func testNewProfileIsNotOnboarded() { XCTAssertFalse(MemberProfile().hasCompletedOnboarding) }
    func testWhitespaceProfileNotOnboarded() { var p = MemberProfile(); p.name = " \n "; XCTAssertFalse(p.hasCompletedOnboarding) }
    func testValidProfile() throws { var p = MemberProfile(); p.name = "Test Driver"; p.email = "test@example.com"; XCTAssertNoThrow(try Validation.profile(p)) }
    func testOptionalEmail() { var p = MemberProfile(); p.name = "Test Driver"; XCTAssertNoThrow(try Validation.profile(p)) }
    func testInvalidEmail() { var p = MemberProfile(); p.name = "Test Driver"; p.email = "a@b"; XCTAssertThrowsError(try Validation.profile(p)) }
    func testEmptyNameRejected() { XCTAssertThrowsError(try Validation.profile(MemberProfile())) }
    func testOversizedNameRejected() { var p = MemberProfile(); p.name = String(repeating: "a", count: 81); XCTAssertThrowsError(try Validation.profile(p)) }
    func testRequestValidation() { XCTAssertNoThrow(try Validation.request(title: "Brake inspection", details: "Please review this sample document.")) }
    func testShortRequestRejected() { XCTAssertThrowsError(try Validation.request(title: "A", details: "Missing")) }
    func testLongRequestRejected() { XCTAssertThrowsError(try Validation.request(title: "Test", details: String(repeating: "x", count: 3001))) }
    func testBlankReplyRejected() { XCTAssertThrowsError(try Validation.message("  \n")) }
    func testValidReply() { XCTAssertNoThrow(try Validation.message("Thank you.")) }
    func testReplyLimit() { XCTAssertThrowsError(try Validation.message(String(repeating: "x", count: 2001))) }
    func testSnapshotRoundTripAllFields() throws {
        var state = AppSnapshot(); state.profile.name = "Test Driver"; state.profile.email = "test@example.com"
        state.requests = [.init(service: .legal, title: "Sample draft", details: "This is a sample request.", state: "CA", incidentDate: Date(timeIntervalSince1970: 100))]
        state.savedOfferIDs = ["fuel"]; state.savedArticleIDs = ["beta"]; state.savedListingIDs = ["trailer"]
        state.posts = [.init(title: "Sample post", body: "This post stays local.", author: "Test Driver", replies: [.init(text: "Local reply", author: "Test Driver")])]
        state.notices = [.init(title: "Saved", detail: "Local only")]; state.preferredPlan = "Standard"
        try disk.save(state); XCTAssertEqual(try disk.load(), state)
    }
    func testOverwriteReplacesStateNotDuplicates() throws { var state = AppSnapshot(); try disk.save(state); state.profile.name = "Updated"; try disk.save(state); XCTAssertEqual(try disk.load().profile.name, "Updated") }
    func testCorruptDataIsNotOverwrittenByLoad() throws {
        let file = disk.file; try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data("not valid JSON".utf8); try data.write(to: file)
        XCTAssertThrowsError(try disk.load()); XCTAssertEqual(try Data(contentsOf: file), data)
    }
    func testUnsupportedVersionFails() throws { var state = AppSnapshot(); state.schemaVersion = 99; let data = try JSONEncoder().encode(state); try FileManager.default.createDirectory(at: disk.file.deletingLastPathComponent(), withIntermediateDirectories: true); try data.write(to: disk.file); XCTAssertThrowsError(try disk.load()) }
    func testUnsupportedVersionNotSaved() throws { var state = AppSnapshot(); state.schemaVersion = 99; XCTAssertThrowsError(try disk.save(state)) }
    func testOversizedStateFails() throws { var state = AppSnapshot(); state.profile.name = String(repeating: "x", count: SnapshotStore.maximumBytes + 1); XCTAssertThrowsError(try disk.save(state)) }
    func testNoSubmittedStatus() { let r = ServiceRequest(service: .general, title: "Sample", details: "Local only", state: "", incidentDate: Date()); XCTAssertEqual(r.statusLabel, "Local draft"); XCTAssertTrue(r.reference.hasPrefix("DRAFT-")) }
    func testCatalogIDsUnique() { XCTAssertEqual(Set(Offer.samples.map(\.id)).count, Offer.samples.count); XCTAssertEqual(Set(Article.samples.map(\.id)).count, Article.samples.count); XCTAssertEqual(Set(MarketListing.samples.map(\.id)).count, MarketListing.samples.count) }
    func testImportPreservesBytes() throws { let bytes = Data("Original unchanged".utf8); let src = try source(bytes: bytes); let doc = try vault.importFile(from: src); XCTAssertEqual(try Data(contentsOf: doc.url), bytes); XCTAssertEqual(try Data(contentsOf: src), bytes) }
    func testDuplicateNamesDoNotOverwrite() throws { let src = try source(); let a = try vault.importFile(from: src); let b = try vault.importFile(from: src); XCTAssertNotEqual(a.id, b.id); XCTAssertEqual(try vault.list().count, 2) }
    func testVaultPersistsAcrossInstances() throws { let src = try source(); _ = try vault.importFile(from: src); let reopened = LocalDocumentStore(directory: vault.directory); XCTAssertEqual(try reopened.list().count, 1) }
    func testEmptyFileRejected() throws { let src = try source(bytes: Data()); XCTAssertThrowsError(try vault.importFile(from: src)); XCTAssertTrue(try vault.list().isEmpty) }
    func testUnsupportedExtensionRejected() throws { let src = try source("sample.exe"); XCTAssertThrowsError(try vault.importFile(from: src)) }
    func testOversizedDocumentRejected() throws { let small = LocalDocumentStore(directory: vault.directory, maximumBytes: 8); let src = try source(bytes: Data(repeating: 65, count: 9)); XCTAssertThrowsError(try small.importFile(from: src)); XCTAssertTrue(try small.list().isEmpty) }
    func testDirectoryRejected() throws { let dir = temp.appendingPathComponent("folder.txt"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true); XCTAssertThrowsError(try vault.importFile(from: dir)) }
    func testSymbolicLinkRejected() throws { let src = try source(); let link = temp.appendingPathComponent("link.txt"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: src); XCTAssertThrowsError(try vault.importFile(from: link)) }
    func testDeleteDoesNotTouchSource() throws { let src = try source(); let doc = try vault.importFile(from: src); try vault.delete(doc); XCTAssertTrue(FileManager.default.fileExists(atPath: src.path)); XCTAssertTrue(try vault.list().isEmpty) }
    func testDeleteOutsideVaultRejected() throws { let src = try source(); XCTAssertThrowsError(try vault.delete(LocalDocument(url: src))); XCTAssertTrue(FileManager.default.fileExists(atPath: src.path)) }
    func testMissingSourceFails() { XCTAssertThrowsError(try vault.importFile(from: temp.appendingPathComponent("missing.txt"))) }
    func testUnicodeFilenamePreserved() throws { let src = try source("Образец.txt"); let doc = try vault.importFile(from: src); XCTAssertEqual(doc.name, "Образец.txt") }
    func testForeignVaultFileNotListed() throws { try FileManager.default.createDirectory(at: vault.directory, withIntermediateDirectories: true); try Data("foreign".utf8).write(to: vault.directory.appendingPathComponent("unowned.txt")); XCTAssertTrue(try vault.list().isEmpty) }
    func testSnapshotRejectsSymlink() throws { let original = try source("original.json", bytes: try JSONEncoder().encode(AppSnapshot())); try FileManager.default.createDirectory(at: disk.file.deletingLastPathComponent(), withIntermediateDirectories: true); try FileManager.default.createSymbolicLink(at: disk.file, withDestinationURL: original); XCTAssertThrowsError(try disk.load()) }
    func testFileCountLimit() throws { let src = try source(); for _ in 0..<100 { _ = try vault.importFile(from: src) }; XCTAssertThrowsError(try vault.importFile(from: src)); XCTAssertEqual(try vault.list().count, 100) }
}


extension CoreTests {
    private func exampleDraft() -> ServiceRequest { .init(service: .general, title: "Original draft", details: "Original sample details.", state: "CA", incidentDate: Date(timeIntervalSince1970: 100)) }
    func testEditingMissingDraftDoesNotCreateAnother() { var s = AppSnapshot(); let before = s; XCTAssertThrowsError(try s.storeRequest(service: .legal, title: "Updated draft", details: "New sample details.", state: "", date: Date(), editingID: UUID())); XCTAssertEqual(s, before) }
    func testEditingDraftPreservesIdentityAndDocuments() throws { var s = AppSnapshot(); var draft = exampleDraft(); draft.documentIDs = ["sample-id"]; s.requests = [draft]; let id = try s.storeRequest(service: .legal, title: "  Edited draft  ", details: "  Edited sample details.  ", state: "  NV ", date: Date(), editingID: draft.id); XCTAssertEqual(id, draft.id); XCTAssertEqual(s.requests.count, 1); XCTAssertEqual(s.requests[0].createdAt, draft.createdAt); XCTAssertEqual(s.requests[0].documentIDs, ["sample-id"]); XCTAssertEqual(s.requests[0].title, "Edited draft"); XCTAssertEqual(s.requests[0].state, "NV") }
    func testInvalidEditPreservesExistingDraft() { var s = AppSnapshot(); s.requests = [exampleDraft()]; let before = s; XCTAssertThrowsError(try s.storeRequest(service: .general, title: "x", details: "too short", state: "", date: Date(), editingID: s.requests[0].id)); XCTAssertEqual(s, before) }
    func testNewDraftTrimsFieldsAndCreatesNotice() throws { var s = AppSnapshot(); let id = try s.storeRequest(service: .general, title: "  New draft ", details: " Local sample details. ", state: " CA ", date: Date()); XCTAssertEqual(s.requests.first?.id, id); XCTAssertEqual(s.requests.first?.title, "New draft"); XCTAssertEqual(s.requests.first?.state, "CA"); XCTAssertEqual(s.notices.count, 1) }
    func testDraftRespectsActivityOptOut() throws { var s = AppSnapshot(); s.profile.localNotifications = false; _ = try s.storeRequest(service: .general, title: "New draft", details: "Local sample details.", state: "", date: Date()); XCTAssertTrue(s.notices.isEmpty) }
    func testAttachmentUpdateDeduplicatesAndPersists() throws { var s = AppSnapshot(); s.requests = [exampleDraft()]; try s.setDocuments(["b", "a", "b"], requestID: s.requests[0].id); try disk.save(s); XCTAssertEqual(try disk.load().requests[0].documentIDs, ["a", "b"]) }
    func testAttachingToMissingDraftDoesNotReportSuccess() { var s = AppSnapshot(); let before = s; XCTAssertThrowsError(try s.setDocuments(["sample"], requestID: UUID())); XCTAssertEqual(s, before) }
    func testReplyToMissingDiscussionDoesNotReportSuccess() { var s = AppSnapshot(); let before = s; XCTAssertThrowsError(try s.appendReply(postID: UUID(), text: "Local sample reply")); XCTAssertEqual(s, before) }
    func testReplyIsTrimmedAndPersists() throws { var s = AppSnapshot(); s.profile.name = "Test Driver"; s.posts = [.init(title: "Test post", body: "Local sample body", author: "Test Driver")]; try s.appendReply(postID: s.posts[0].id, text: "  Local reply  "); try disk.save(s); XCTAssertEqual(try disk.load().posts[0].replies[0].text, "Local reply") }
    func testActivityListIsBounded() throws { var s = AppSnapshot(); s.notices = (0..<100).map { .init(title: "Notice \($0)", detail: "Sample") }; _ = try s.storeRequest(service: .general, title: "New draft", details: "Local sample details.", state: "", date: Date()); XCTAssertEqual(s.notices.count, 100); XCTAssertEqual(s.notices.first?.title, "Draft saved") }
}


extension CoreTests {
    func testSnapshotSaveRefusesSymbolicTargetAndPreservesOriginal() throws {
        let data = try JSONEncoder().encode(AppSnapshot())
        let target = try source("protected.json", bytes: data)
        try FileManager.default.createDirectory(at: disk.file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: disk.file, withDestinationURL: target)
        XCTAssertThrowsError(try disk.save(AppSnapshot()))
        XCTAssertEqual(try Data(contentsOf: target), data)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: disk.file.path)[.type] as? FileAttributeType, .typeSymbolicLink)
    }
    func testDanglingSnapshotLinkDoesNotBecomeEmptyState() throws {
        try FileManager.default.createDirectory(at: disk.file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: disk.file, withDestinationURL: temp.appendingPathComponent("absent.json"))
        XCTAssertThrowsError(try disk.load())
        XCTAssertThrowsError(try disk.save(AppSnapshot()))
    }
    func testSnapshotRefusesSymlinkedParent() throws {
        let target = temp.appendingPathComponent("other-state")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: disk.file.deletingLastPathComponent(), withDestinationURL: target)
        XCTAssertThrowsError(try disk.load())
        XCTAssertThrowsError(try disk.save(AppSnapshot()))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty)
    }
    func testVaultRefusesSymlinkedRootWithoutWritingToTarget() throws {
        let target = temp.appendingPathComponent("other-vault")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: vault.directory, withDestinationURL: target)
        XCTAssertThrowsError(try vault.list())
        let src = try source()
        XCTAssertThrowsError(try vault.importFile(from: src))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty)
    }
    func testVaultDeletionRefusesDirectoryAndPreservesContents() throws {
        let folder = vault.directory.appendingPathComponent(UUID().uuidString + "_folder.txt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let child = folder.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: child)
        XCTAssertThrowsError(try vault.delete(.init(url: folder)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: child.path))
    }
    func testVaultDeletionRefusesLinkToAnotherOwnedFile() throws {
        let src = try source()
        let original = try vault.importFile(from: src)
        let link = vault.directory.appendingPathComponent(UUID().uuidString + "_alias.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original.url)
        XCTAssertThrowsError(try vault.delete(.init(url: link)))
        XCTAssertEqual(try Data(contentsOf: original.url), try Data(contentsOf: src))
    }
    func testDocumentLimitRejectsInvalidConfigurationWithoutOverflow() throws {
        let src = try source()
        for limit in [0, -1, Int.max] {
            let invalid = LocalDocumentStore(directory: vault.directory, maximumBytes: limit)
            XCTAssertThrowsError(try invalid.importFile(from: src))
        }
        XCTAssertTrue(try vault.list().isEmpty)
    }
    func testOversizedOnDiskSnapshotIsPreserved() throws {
        try FileManager.default.createDirectory(at: disk.file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(repeating: 65, count: SnapshotStore.maximumBytes + 1)
        try data.write(to: disk.file)
        XCTAssertThrowsError(try disk.load())
        XCTAssertEqual(try Data(contentsOf: disk.file), data)
    }
}
