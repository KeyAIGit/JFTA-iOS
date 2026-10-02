import SwiftUI
import UIKit

@main
struct JFTAApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).preferredColorScheme(.dark).tint(JFTATheme.gold)
        }
    }
}
enum Route: Hashable {
    case resetAccess, memberPass, request(ServiceKind), caseDetail(UUID), editRequest(UUID), caseDocuments(UUID)
    case service(ServiceKind), consultation(ServiceKind), offer(String), resources, article(String)
    case community, thread(UUID), composePost, marketplace, listing(String), notifications, documents
    case profile, membership, referral, help
}
struct RootView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Group {
            if let error = store.storageError {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                    Text("Local storage unavailable").font(.title2.bold())
                    Text(error).multilineTextAlignment(.center)
                    Text("Close and reopen the app after the device is unlocked. Your original data has not been replaced.").font(.footnote)
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(JFTATheme.background)
            } else if store.snapshot.profile.hasCompletedOnboarding {
                TabView {
                    AppNavigation { HomeView() }.tabItem { Label("Home", systemImage: "house") }.accessibilityIdentifier("tab.home")
                    AppNavigation { CasesView() }.tabItem { Label("Cases", systemImage: "folder") }.accessibilityIdentifier("tab.cases")
                    AppNavigation { BenefitsView() }.tabItem { Label("Benefits", systemImage: "tag") }.accessibilityIdentifier("tab.benefits")
                    AppNavigation { MoreView() }.tabItem { Label("More", systemImage: "ellipsis") }.accessibilityIdentifier("tab.more")
                }
            } else {
                AppNavigation { WelcomeView() }
            }
        }
    }
}
struct AppNavigation<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack {
            content.navigationDestination(for: Route.self) { route in DestinationView(route: route) }
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.accessibilityIdentifier("keyboard.done") } }
                .toolbarBackground(JFTATheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
struct DestinationView: View {
    let route: Route
    var body: some View {
        Group {
            switch route {
            case .resetAccess: ResetAccessView()
            case .memberPass: MemberPassView()
            case .request(let service): RequestFormView(service: service)
            case .caseDetail(let id): CaseDetailView(id: id)
            case .editRequest(let id): RequestFormView(editingID: id)
            case .caseDocuments(let id): DocumentsView(requestID: id)
            case .service(let kind): ServiceView(kind: kind)
            case .consultation(let kind): RequestFormView(service: kind, consultation: true)
            case .offer(let id): OfferDetailView(id: id)
            case .resources: ResourcesView()
            case .article(let id): ArticleView(id: id)
            case .community: CommunityView()
            case .thread(let id): ThreadView(id: id)
            case .composePost: ComposePostView()
            case .marketplace: MarketplaceView()
            case .listing(let id): ListingView(id: id)
            case .notifications: NotificationsView()
            case .documents: DocumentsView()
            case .profile: ProfileView()
            case .membership: MembershipView()
            case .referral: ReferralView()
            case .help: HelpView()
            }
        }.navigationBarTitleDisplayMode(.inline)
    }
}
