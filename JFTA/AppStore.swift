import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var snapshot: AppSnapshot
    @Published var storageError: String?
    private let disk: SnapshotStore
    let isTesting: Bool
    let documentsDirectory: URL
    var canWrite: Bool { storageError == nil }

    init() {
        let args = ProcessInfo.processInfo.arguments
        #if DEBUG
        isTesting = args.contains("--uitesting")
        #else
        isTesting = false
        #endif
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(isTesting ? "JFTA-UITesting" : "JFTA", isDirectory: true)
        documentsDirectory = base.appendingPathComponent("Documents", isDirectory: true)
        disk = SnapshotStore(file: base.appendingPathComponent("state.json"))
        var initial = AppSnapshot()
        var failureMessage: String?
        do {
            if isTesting && args.contains("--reset") && FileManager.default.fileExists(atPath: base.path) {
                try FileManager.default.removeItem(at: base)
            }
            initial = try disk.load()
            if isTesting && !args.contains("--welcome") && !initial.profile.hasCompletedOnboarding {
                initial.profile.name = "Test Driver"
                try disk.save(initial)
            }
        } catch { failureMessage = "Local storage could not be opened. No data was replaced. \(error.localizedDescription)" }
        snapshot = initial
        storageError = failureMessage
    }
    private func change(_ edit: (inout AppSnapshot) throws -> Void) throws {
        guard canWrite else { throw NSError(domain: "JFTA", code: 1, userInfo: [NSLocalizedDescriptionKey: "Storage is unavailable. Existing data has been preserved."]) }
        var next = snapshot
        try edit(&next)
        try disk.save(next)
        snapshot = next
    }
    func saveProfile(_ profile: MemberProfile) throws {
        try Validation.profile(profile)
        var cleaned = profile
        cleaned.name = Validation.trimmed(profile.name); cleaned.email = Validation.trimmed(profile.email)
        try change { $0.profile = cleaned }
    }
    @discardableResult
    func saveRequest(service: ServiceKind, title: String, details: String, state: String, date: Date, editingID: UUID? = nil) throws -> UUID {
        var result = UUID()
        try change { snapshot in
            result = try snapshot.storeRequest(service: service, title: title, details: details, state: state, date: date, editingID: editingID)
        }
        return result
    }
    func deleteRequest(_ id: UUID) throws { try change { $0.requests.removeAll { $0.id == id } } }
    func setDocumentIDs(_ ids: [String], requestID: UUID) throws { try change { try $0.setDocuments(ids, requestID: requestID) } }
    func toggleOffer(_ id: String) throws { try change { if !$0.savedOfferIDs.insert(id).inserted { $0.savedOfferIDs.remove(id) } } }
    func toggleArticle(_ id: String) throws { try change { if !$0.savedArticleIDs.insert(id).inserted { $0.savedArticleIDs.remove(id) } } }
    func toggleListing(_ id: String) throws { try change { if !$0.savedListingIDs.insert(id).inserted { $0.savedListingIDs.remove(id) } } }
    func markNoticesRead() throws { try change { state in for i in state.notices.indices { state.notices[i].read = true } } }
    func savePlan(_ name: String) throws { try change { $0.preferredPlan = name } }
    func createPost(title: String, body: String) throws {
        try Validation.request(title: title, details: body)
        try change { state in
            guard state.posts.count < 200 else { throw InputError.tooManyItems }
            state.posts.insert(.init(title: Validation.trimmed(title), body: Validation.trimmed(body), author: state.profile.name), at: 0)
        }
    }
    func reply(postID: UUID, text: String) throws {
        try change { try $0.appendReply(postID: postID, text: text) }
    }
}
