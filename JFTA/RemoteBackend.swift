import Foundation
import Supabase

enum JFTARemoteConfig {
    static let url = URL(string: "https://rygeosaqkllnbocaxiea.supabase.co")!
    static let publishableKey = "sb_publishable_mkiHWz_vCA5X91wvyH8rYA_nyBFU8AG"
    static let documentsBucket = "request-documents"
}

@MainActor
final class RemoteBackend: ObservableObject {
    static let shared = RemoteBackend()
    let client = SupabaseClient(
        supabaseURL: JFTARemoteConfig.url,
        supabaseKey: JFTARemoteConfig.publishableKey
    )
    @Published private(set) var userID: UUID?
    @Published private(set) var email: String?
    @Published private(set) var busy = false
    @Published private(set) var lastMessage: String?

    private init() {
        Task { await refreshSession() }
    }

    func refreshSession() async {
        do {
            let session = try await client.auth.session
            userID = session.user.id
            email = session.user.email
        } catch {
            userID = nil
            email = nil
        }
    }
    func signUp(email: String, password: String) async throws -> String {
        busy = true
        defer { busy = false }
        let response = try await client.auth.signUp(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
        userID = response.user.id
        self.email = response.user.email
        if response.session == nil {
            lastMessage = "Check your email to confirm the account, then sign in."
            return lastMessage!
        }
        lastMessage = "Account created and signed in."
        return lastMessage!
    }

    func signIn(email: String, password: String) async throws {
        busy = true
        defer { busy = false }
        let session = try await client.auth.signIn(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
        userID = session.user.id
        self.email = session.user.email
        lastMessage = "Signed in."
    }

    func signOut() async throws {
        busy = true
        defer { busy = false }
        try await client.auth.signOut()
        userID = nil
        email = nil
        lastMessage = "Signed out. Local data remains on this device."
    }

    func syncProfile(_ profile: MemberProfile) async throws {
        guard let id = userID else { throw RemoteBackendError.notSignedIn }
        let row = RemoteProfile(
            id: id,
            displayName: profile.name,
            phone: profile.phone,
            homeState: profile.state,
            driverType: profile.driverType,
            preferredLanguage: profile.language,
            preferredPlan: profile.preferredPlan,
            localNotifications: profile.localNotifications
        )
        try await client.from("profiles").upsert(row).execute()
    }
    func syncDrafts(_ requests: [ServiceRequest]) async throws {
        guard let id = userID else { throw RemoteBackendError.notSignedIn }
        for request in requests {
            let row = RemoteRequest(
                id: request.id,
                userID: id,
                service: request.service.rawValue,
                title: request.title,
                details: request.details,
                location: request.state,
                incidentDate: Self.day.string(from: request.incidentDate),
                status: "draft"
            )
            try await client.from("requests").upsert(row).execute()
        }
    }

    func syncPosts(_ posts: [CommunityPost]) async throws {
        guard let id = userID else { throw RemoteBackendError.notSignedIn }
        for post in posts {
            let row = RemotePost(id: post.id, userID: id, title: post.title, body: post.body, visibility: "private")
            try await client.from("posts").upsert(row).execute()
            for reply in post.replies {
                let replyRow = RemoteReply(id: reply.id, postID: post.id, userID: id, body: reply.body)
                try await client.from("replies").upsert(replyRow).execute()
            }
        }
    }

    func syncSavedOffers(_ ids: Set<String>) async throws {
        guard let id = userID else { throw RemoteBackendError.notSignedIn }
        try await client.from("user_saves").delete().eq("user_id", value: id).eq("kind", value: "offer").execute()
        if !ids.isEmpty {
            let rows = ids.sorted().map { RemoteSave(userID: id, kind: "offer", itemID: $0) }
            try await client.from("user_saves").insert(rows).execute()
        }
    }

    func syncSnapshot(_ snapshot: AppSnapshot) async throws {
        try await syncProfile(snapshot.profile)
        try await syncDrafts(snapshot.requests)
        try await syncPosts(snapshot.posts)
        try await syncSavedOffers(snapshot.savedOfferIDs)
        lastMessage = "Local profile, drafts, private discussions and saved offers synced."
    }

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
enum RemoteBackendError: LocalizedError {
    case notSignedIn
    var errorDescription: String? {
        "Sign in before syncing. Your local data has not been changed."
    }
}

private struct RemoteProfile: Encodable {
    let id: UUID
    let displayName, phone, homeState, driverType, preferredLanguage, preferredPlan: String
    let localNotifications: Bool
    enum CodingKeys: String, CodingKey {
        case id, phone
        case displayName = "display_name"
        case homeState = "home_state"
        case driverType = "driver_type"
        case preferredLanguage = "preferred_language"
        case preferredPlan = "preferred_plan"
        case localNotifications = "local_notifications"
    }
}

private struct RemoteRequest: Encodable {
    let id, userID: UUID
    let service, title, details, location, incidentDate, status: String
    enum CodingKeys: String, CodingKey {
        case id, service, title, details, location, status
        case userID = "user_id"
        case incidentDate = "incident_date"
    }
}
private struct RemotePost: Encodable {
    let id, userID: UUID
    let title, body, visibility: String
    enum CodingKeys: String, CodingKey {
        case id, title, body, visibility
        case userID = "user_id"
    }
}

private struct RemoteReply: Encodable {
    let id, postID, userID: UUID
    let body: String
    enum CodingKeys: String, CodingKey {
        case id, body
        case postID = "post_id"
        case userID = "user_id"
    }
}

private struct RemoteSave: Encodable {
    let userID: UUID
    let kind, itemID: String
    enum CodingKeys: String, CodingKey {
        case kind
        case userID = "user_id"
        case itemID = "item_id"
    }
}
