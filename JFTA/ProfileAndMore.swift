import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.profile) {
                    HStack(spacing: 14) {
                        Text(String(store.snapshot.profile.name.prefix(1)).uppercased()).font(.title2.bold()).foregroundStyle(.black).frame(width: 48, height: 48).background(JFTATheme.gold).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 5) { Text(store.snapshot.profile.name).font(.headline); Text("Local profile / Edit details").font(.caption).foregroundStyle(JFTATheme.secondary) }
                    }.padding(.vertical, 8)
                }.accessibilityIdentifier("more.profile")
            }
            Section("Your workspace") {
                entry("Member pass", "Demo credential", "qrcode", .memberPass, "memberPass")
                entry("Documents", "Files stored on this device", "doc.on.doc", .documents, "documents")
                entry("Notifications", "Local activity only", "bell", .notifications, "notifications")
            }
            Section("Explore") {
                entry("Resources", "Guides for this beta", "book", .resources, "resources")
                entry("Community", "Local discussion drafts", "bubble.left.and.bubble.right", .community, "community")
                entry("Marketplace", "Sample listings", "truck.box", .marketplace, "marketplace")
            }
            Section("Membership & support") {
                entry("Membership & billing", "No active subscription", "creditcard", .membership, "membership")
                entry("Refer a driver", "Share a beta introduction", "person.badge.plus", .referral, "referral")
                entry("Help & support", "How the local beta works", "questionmark.circle", .help, "help")
            }
            Section { Text("JFTA 0.2.1 / Native local beta\nOnline services are not connected.").font(.caption).foregroundStyle(JFTATheme.secondary) }
        }.appForm().navigationTitle("More")
    }
    private func entry(_ title: String, _ detail: String, _ icon: String, _ route: Route, _ identifier: String) -> some View {
        NavigationLink(value: route) { RowLabel(title: title, detail: detail, symbol: icon) }.accessibilityIdentifier("more.\(identifier)")
    }
}
struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var profile = MemberProfile()
    @State private var loaded = false
    @State private var error: String?
    @State private var saved = false
    var body: some View {
        Form {
            Section("Personal information") {
                TextField("Full name", text: $profile.name).textContentType(.name).accessibilityIdentifier("profile.name")
                TextField("Email (optional)", text: $profile.email).textContentType(.emailAddress).keyboardType(.emailAddress).autocorrectionDisabled().textInputAutocapitalization(.never).accessibilityIdentifier("profile.email")
                TextField("Phone (optional)", text: $profile.phone).textContentType(.telephoneNumber).keyboardType(.phonePad)
                TextField("Home state (optional)", text: $profile.state)
            }
            Section("Driver information") {
                Picker("Driver type", selection: $profile.driverType) { ForEach(["Company driver", "Owner-operator", "Fleet owner", "Other"], id: \.self) { Text($0) } }
                Picker("Preferred contact language", selection: $profile.language) { ForEach(["English", "Russian", "Spanish", "Other"], id: \.self) { Text($0) } }
                Text("This preference is stored locally; it does not change the interface language.").font(.caption).foregroundStyle(JFTATheme.secondary)
            }
            Section("Local preferences") { Toggle("Record local activity notices", isOn: $profile.localNotifications) }
            Section { LocalBetaNote(text: "No online account, password, verified membership, or push-notification service is created.") }
        }.appForm().navigationTitle("Profile & settings")
            .onAppear { if !loaded { profile = store.snapshot.profile; loaded = true } }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") { do { try store.saveProfile(profile); saved = true } catch { self.error = error.localizedDescription } }.fontWeight(.bold).accessibilityIdentifier("profile.save") } }
            .appError($error).alert("Profile saved", isPresented: $saved) { Button("OK", role: .cancel) {} } message: { Text("Your profile was saved on this device.") }
    }
}
struct NotificationsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var error: String?
    var body: some View {
        List {
            if store.snapshot.notices.isEmpty { EmptyPanel(symbol: "bell", title: "You're all caught up", detail: "Saving a draft creates a local activity notice. No server notifications are connected.").listRowBackground(Color.clear) }
            ForEach(store.snapshot.notices) { notice in
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(notice.read ? Color.clear : JFTATheme.gold).frame(width: 7, height: 7).padding(.top, 7)
                    VStack(alignment: .leading, spacing: 7) { Text(notice.title).font(.headline); Text(notice.detail).font(.subheadline).foregroundStyle(JFTATheme.secondary); Text(notice.createdAt, style: .date).font(.caption).foregroundStyle(JFTATheme.secondary) }
                }.padding(.vertical, 5)
            }
        }.appForm().navigationTitle("Notifications")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Read all") { do { try store.markNoticesRead() } catch { self.error = error.localizedDescription } }.disabled(store.snapshot.notices.isEmpty).accessibilityIdentifier("notifications.readAll") } }.appError($error)
    }
}
struct MembershipView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = "Standard Plus"
    @State private var error: String?
    @State private var saved = false
    var body: some View {
        Page {
            SectionLabel(text: "Membership preview")
            Text("BUILT AROUND\nYOUR ROAD.").font(.system(.largeTitle, design: .rounded).weight(.black))
            Card {
                Label("No active subscription", systemImage: "creditcard").font(.headline).foregroundStyle(JFTATheme.gold)
                Text("There is no payment method, charge, billing history, or auto-renewal in this build.").foregroundStyle(JFTATheme.secondary)
            }
            Card {
                Text("Explore a plan preference").font(.headline)
                Picker("Preferred plan", selection: $selection) { Text("Standard").tag("Standard"); Text("Standard Plus").tag("Standard Plus") }.pickerStyle(.segmented)
                Text("Pricing and included services are not configured. Saving a preference does not enroll you.").font(.subheadline).foregroundStyle(JFTATheme.secondary)
                Button("Save preference") { do { try store.savePlan(selection); saved = true } catch { self.error = error.localizedDescription } }.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("membership.save")
            }
            LocalBetaNote()
        }.navigationTitle("Membership & billing").onAppear { selection = store.snapshot.preferredPlan }.appError($error)
            .alert("Preference saved", isPresented: $saved) { Button("OK", role: .cancel) {} } message: { Text("No subscription was created and no payment was taken.") }
    }
}
struct ReferralView: View {
    var body: some View {
        Page {
            Image(systemName: "person.2.wave.2").font(.system(size: 54, weight: .light)).foregroundStyle(JFTATheme.gold).padding(.vertical, 14)
            Text("GOOD ROADS\nARE BETTER TOGETHER.").font(.system(.largeTitle, design: .rounded).weight(.black))
            Text("Share an introduction to the app you are testing.").foregroundStyle(JFTATheme.secondary)
            ShareLink(item: "I'm testing the JFTA member app for truck drivers. It is currently a local beta, with no active memberships or connected services.") { Label("Share introduction", systemImage: "square.and.arrow.up") }.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("referral.share")
            Card { Text("No referral tracking yet").font(.headline); Text("The beta does not create referral links, credits, commissions, or rewards. Your contacts are not accessed.").font(.subheadline).foregroundStyle(JFTATheme.secondary) }
        }.navigationTitle("Refer a driver")
    }
}
struct HelpView: View {
    var body: some View {
        List {
            Section {
                Text("HOW CAN\nWE HELP?").font(.system(.largeTitle, design: .rounded).weight(.black)).padding(.vertical, 10)
                LocalBetaNote(text: "No live support operator is connected to this build.")
                NavigationLink("Prepare a support draft", value: Route.request(.general)).foregroundStyle(JFTATheme.gold).accessibilityIdentifier("help.draft")
            }
            Section("About this beta") {
                DisclosureGroup("Are my requests sent?") { Text("No. Requests are local drafts. Saving does not open a case with a provider or promise a response.") }
                DisclosureGroup("Where are documents stored?") { Text("Copies are stored inside this app on the current device. They are not uploaded or backed up to JFTA. Keep your original files separately.") }
                DisclosureGroup("Is the member QR valid?") { Text("No. The QR is a clearly marked demo identifier, not proof of membership and not a redeemable benefit.") }
                DisclosureGroup("Can I make payments?") { Text("No. No card details, purchase, subscription, or auto-renewal are enabled.") }
                DisclosureGroup("What happens if I delete the app?") { Text("Local data can be lost when the app is deleted. Export any test drafts or files you want to retain before deleting it.") }
            }
            Section { Text("For emergencies, use local emergency services. This beta is not an emergency, legal, medical, financial, or dispatch service.").font(.footnote).foregroundStyle(JFTATheme.secondary) }
        }.appForm().navigationTitle("Help & support")
    }
}
