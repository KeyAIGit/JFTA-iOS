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
