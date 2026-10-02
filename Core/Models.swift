import Foundation

enum ServiceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case legal = "Legal", health = "Health", financial = "Financial", benefits = "Benefits", general = "General"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .legal: return "scalemass"
        case .health: return "heart.text.square"
        case .financial: return "dollarsign.circle"
        case .benefits: return "tag"
        case .general: return "questionmark.bubble"
        }
    }
}
struct MemberProfile: Codable, Equatable, Sendable {
    var name = ""
    var email = ""
    var phone = ""
    var state = ""
    var driverType = "Company driver"
    var language = "English"
    var localNotifications = true
    var hasCompletedOnboarding: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
struct ServiceRequest: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var service: ServiceKind
    var title: String
    var details: String
    var state: String
    var incidentDate: Date
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var documentIDs: [String] = []
    // A request cannot be submitted in the local beta. No invented server status.
    var statusLabel: String { "Local draft" }
    var reference: String { "DRAFT-" + id.uuidString.prefix(8) }
}
struct CommunityPost: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var author: String
    var createdAt: Date = Date()
    var replies: [CommunityReply] = []
}
struct CommunityReply: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var text: String
    var author: String
    var createdAt: Date = Date()
}
struct LocalNotice: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var read = false
    var createdAt: Date = Date()
}
struct AppSnapshot: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var profile = MemberProfile()
    var requests: [ServiceRequest] = []
    var savedOfferIDs: Set<String> = []
    var savedArticleIDs: Set<String> = []
    var savedListingIDs: Set<String> = []
    var posts: [CommunityPost] = []
    var notices: [LocalNotice] = []
    var demoPassID: UUID = UUID()
    var preferredPlan = "Standard Plus"
}
enum InputError: LocalizedError, Equatable {
    case name, email, title, details, message, tooManyItems
    var errorDescription: String? {
        switch self {
        case .name: return "Enter a name between 2 and 80 characters."
        case .email: return "Enter a valid email address, or leave it empty for a local profile."
        case .title: return "Enter a title between 3 and 100 characters."
        case .details: return "Enter details between 10 and 3,000 characters."
        case .message: return "Enter a message between 1 and 2,000 characters."
        case .tooManyItems: return "This local beta has reached its item limit."
        }
    }
}
enum Validation {
    static func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func profile(_ profile: MemberProfile) throws {
        guard (2...80).contains(trimmed(profile.name).count) else { throw InputError.name }
        let email = trimmed(profile.email)
        if !email.isEmpty {
            guard email.count <= 254, email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else { throw InputError.email }
        }
    }
    static func request(title: String, details: String) throws {
        guard (3...100).contains(trimmed(title).count) else { throw InputError.title }
        guard (10...3000).contains(trimmed(details).count) else { throw InputError.details }
    }
    static func message(_ text: String) throws {
        guard (1...2000).contains(trimmed(text).count) else { throw InputError.message }
    }
}
struct Offer: Identifiable, Hashable, Sendable {
    let id: String; let title: String; let category: String; let symbol: String; let detail: String
    static let samples: [Offer] = [
        .init(id: "fuel", title: "Fuel savings", category: "Fuel", symbol: "fuelpump", detail: "Preview how a fuel offer will appear. No fuel partner, discount, or redemption is active in this beta."),
        .init(id: "service", title: "Truck service", category: "Maintenance", symbol: "wrench.and.screwdriver", detail: "Save this sample offer to test your benefits list. Provider terms will be shown when a real partner is connected."),
        .init(id: "stay", title: "Rest on the road", category: "Travel", symbol: "bed.double", detail: "A sample travel-benefit card. This is not a hotel reservation or a redeemable rate."),
        .init(id: "wellness", title: "Driver wellness", category: "Health", symbol: "heart", detail: "An example of a future wellness benefit. No health coverage or healthcare service is included.")
    ]
}
struct Article: Identifiable, Hashable, Sendable {
    let id: String; let title: String; let category: String; let symbol: String; let paragraphs: [String]
    static let samples: [Article] = [
        .init(id: "documents", title: "Keep your paperwork together", category: "Organization", symbol: "doc.text", paragraphs: ["Use the Documents tab to import a sample file, view it, share it, and remove the local copy.", "Keep your original files elsewhere. This beta stores copies only on this device and does not back them up to a JFTA account.", "Do not use this test build as the only storage for important paperwork. Use non-sensitive sample files while testing."]),
        .init(id: "request", title: "Prepare a clear request", category: "Getting started", symbol: "square.and.pencil", paragraphs: ["Choose a category, give your request a short title, and describe what you want help with.", "Include a date and location when relevant. You can attach sample documents to a local draft.", "Saving a draft does not contact a specialist. No requests are submitted to JFTA from this beta."]),
        .init(id: "beta", title: "What works in this beta", category: "App guide", symbol: "iphone", paragraphs: ["The interface uses native controls, not screenshots. Try editing your profile, creating a draft, saving offers, and writing a local discussion.", "Your changes should remain after closing and reopening the app on the same device.", "Accounts, payments, live professionals, membership verification, and community synchronization are not connected."])
    ]
}
struct MarketListing: Identifiable, Hashable, Sendable {
    let id: String; let title: String; let category: String; let symbol: String; let description: String
    static let samples: [MarketListing] = [
        .init(id: "trailer", title: "Flatbed trailer", category: "Equipment", symbol: "truck.box", description: "Sample listing for interface testing. No item is offered for sale and no seller is connected."),
        .init(id: "inspection", title: "Pre-purchase inspection", category: "Services", symbol: "checkmark.shield", description: "Sample service listing. Provider identity, availability, pricing, and terms are not configured."),
        .init(id: "parking", title: "Truck parking", category: "Parking", symbol: "parkingsign.circle", description: "Sample parking listing. No space is reserved and no payment is taken.")
    ]
}
