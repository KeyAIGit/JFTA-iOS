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
        try Validation.request(title: title, details: details)
        var result = UUID()
        try change { snapshot in
            if let id = editingID, let index = snapshot.requests.firstIndex(where: { $0.id == id }) {
                snapshot.requests[index].service = service; snapshot.requests[index].title = Validation.trimmed(title)
                snapshot.requests[index].details = Validation.trimmed(details); snapshot.requests[index].state = state
                snapshot.requests[index].incidentDate = date; snapshot.requests[index].updatedAt = Date(); result = id
            } else {
                guard snapshot.requests.count < 500 else { throw InputError.tooManyItems }
                let request = ServiceRequest(service: service, title: Validation.trimmed(title), details: Validation.trimmed(details), state: state, incidentDate: date)
                result = request.id; snapshot.requests.insert(request, at: 0)
            }
            if snapshot.profile.localNotifications {
                snapshot.notices.insert(.init(title: "Draft saved", detail: "\(Validation.trimmed(title)) is saved only on this device. Nothing has been sent."), at: 0)
                snapshot.notices = Array(snapshot.notices.prefix(100))
            }
        }
        return result
    }
    func deleteRequest(_ id: UUID) throws { try change { $0.requests.removeAll { $0.id == id } } }
    func setDocumentIDs(_ ids: [String], requestID: UUID) throws {
        try change { snapshot in
            guard let index = snapshot.requests.firstIndex(where: { $0.id == requestID }) else { return }
            snapshot.requests[index].documentIDs = Array(Set(ids)).sorted()
        }
    }
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
        try Validation.message(text)
        try change { state in
            guard let index = state.posts.firstIndex(where: { $0.id == postID }) else { return }
            guard state.posts[index].replies.count < 100 else { throw InputError.tooManyItems }
            state.posts[index].replies.append(.init(text: Validation.trimmed(text), author: state.profile.name))
        }
    }
}
