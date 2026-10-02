import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var profile = MemberProfile()
    @State private var error: String?
    var body: some View {
        Page {
            HStack { Image("Brand").resizable().scaledToFit().frame(width: 68, height: 68); Spacer(); Text("MEMBER APP").font(.caption.weight(.bold)).tracking(2).foregroundStyle(JFTATheme.gold) }
            Text("YOUR ROAD.\nYOUR COMMUNITY.").font(.system(.largeTitle, design: .rounded).weight(.black))
            Text("A better place for your paperwork, requests, and member resources.").foregroundStyle(JFTATheme.secondary)
            Image("RoadHero").resizable().scaledToFill().frame(height: 140).clipped().clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityHidden(true)
            Card {
                Text("Try the local beta").font(.title2.bold())
                Text("Create a profile on this device. This is not an online account; no password is collected.").font(.subheadline).foregroundStyle(JFTATheme.secondary)
                TextField("Your name", text: $profile.name).textContentType(.name).textFieldStyle(.roundedBorder).accessibilityIdentifier("welcome.name")
                TextField("Email (optional)", text: $profile.email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).accessibilityIdentifier("welcome.email")
                Button("Enter JFTA") { do { try store.saveProfile(profile) } catch { self.error = error.localizedDescription } }
                    .buttonStyle(GoldButtonStyle()).accessibilityIdentifier("welcome.enter")
                NavigationLink("Already have an account?", value: Route.resetAccess).font(.subheadline).accessibilityIdentifier("welcome.access")
            }
            LocalBetaNote()
        }.navigationTitle("Welcome").appError($error)
    }
}
struct ResetAccessView: View {
    var body: some View {
        Page {
            EmptyPanel(symbol: "lock.shield", title: "Account access", detail: "Online sign-in and password recovery are not connected in this beta.")
            Card {
                Text("No verification code will be sent").font(.headline)
                Text("Return to Welcome to create a local test profile. Existing real-world membership cannot be checked by this build.").foregroundStyle(JFTATheme.secondary)
            }
        }.navigationTitle("Reset access")
    }
}
struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Page {
            HStack(spacing: 12) {
                Image("Brand").resizable().scaledToFit().frame(width: 48, height: 48).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) { Text("GOOD TO SEE YOU").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(JFTATheme.secondary); Text(store.snapshot.profile.name).font(.title3.bold()).accessibilityIdentifier("home.name") }
                Spacer()
                NavigationLink(value: Route.notifications) { Image(systemName: "bell.badge").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel("Notifications").accessibilityIdentifier("home.notifications")
            }
            VStack(alignment: .leading, spacing: 14) {
                Image("RoadHero").resizable().scaledToFill().frame(height: 150).clipped().accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("KEEP MOVING.\nWE'RE BUILDING THE REST.").font(.system(.title, design: .rounded).weight(.black))
                    Text("Organize your next step, wherever the road takes you.").font(.subheadline).foregroundStyle(JFTATheme.secondary)
                    NavigationLink("Start a request", value: Route.request(.general)).buttonStyle(GoldButtonStyle()).accessibilityIdentifier("home.startRequest")
                }.padding(18)
            }.background(JFTATheme.surface).clipShape(RoundedRectangle(cornerRadius: 20))
            LocalBetaNote()
            SectionLabel(text: "Your workspace")
            HStack(spacing: 14) {
                stat(value: String(store.snapshot.requests.count), label: "Local drafts", icon: "folder")
                stat(value: String(store.snapshot.savedOfferIDs.count), label: "Saved offers", icon: "bookmark")
            }
            NavigationLink(value: Route.memberPass) { Card { RowLabel(title: "Member pass", detail: "View a clearly marked demo pass", symbol: "qrcode") } }.buttonStyle(.plain).accessibilityIdentifier("home.memberPass")
            SectionLabel(text: "Explore services")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach([ServiceKind.legal, .health, .financial, .benefits]) { kind in
                    NavigationLink(value: Route.service(kind)) {
                        VStack(alignment: .leading, spacing: 14) {
                            Image(systemName: kind.symbol).font(.title2).foregroundStyle(JFTATheme.gold)
                            Text(kind.rawValue).font(.headline).foregroundStyle(.white)
                            Text("Explore & prepare").font(.caption).foregroundStyle(JFTATheme.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(JFTATheme.surface).clipShape(RoundedRectangle(cornerRadius: 16))
                    }.accessibilityIdentifier("home.service.\(kind.rawValue)")
                }
            }
            if let request = store.snapshot.requests.first {
                SectionLabel(text: "Latest draft")
                NavigationLink(value: Route.caseDetail(request.id)) { Card { RowLabel(title: request.title, detail: request.statusLabel, symbol: request.service.symbol) } }.buttonStyle(.plain)
            }
            NavigationLink(value: Route.documents) { Card { RowLabel(title: "Document vault", detail: "Keep sample files on this device", symbol: "doc.on.doc") } }.buttonStyle(.plain)
        }.navigationTitle("JFTA").navigationBarTitleDisplayMode(.inline)
    }
    private func stat(value: String, label: String, icon: String) -> some View {
        Card { Image(systemName: icon).foregroundStyle(JFTATheme.gold); Text(value).font(.largeTitle.bold()); Text(label).font(.caption).foregroundStyle(JFTATheme.secondary) }
    }
}
struct MemberPassView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Page {
            SectionLabel(text: "Your road. Your identity.")
            Card {
                HStack { Image("Brand").resizable().scaledToFit().frame(width: 54, height: 54); Spacer(); Text("DEMO PASS").font(.caption.weight(.heavy)).foregroundStyle(JFTATheme.gold) }
                Text(store.snapshot.profile.name).font(.title.bold()).accessibilityIdentifier("pass.name")
                Text("Not an active membership").foregroundStyle(JFTATheme.secondary)
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 8) { Text("JFTA LOCAL BETA").font(.caption.bold()); Text(String(store.snapshot.demoPassID.uuidString.prefix(8))).font(.system(.caption, design: .monospaced)); Text("NOT VALID FOR REDEMPTION").font(.caption2.bold()).foregroundStyle(JFTATheme.gold) }
                    Spacer()
                    if let image = qrImage {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 110, height: 110).padding(8).background(.white).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityLabel("Demo QR code, not a valid credential")
                    }
                }
            }
            Text("The QR contains only a random demo identifier. It does not contain your name, email, or a valid membership token.").font(.subheadline).foregroundStyle(JFTATheme.secondary)
            ShareLink(item: "JFTA demo pass: \(store.snapshot.demoPassID.uuidString). Not a membership credential.") { Label("Share demo identifier", systemImage: "square.and.arrow.up") }.buttonStyle(GoldButtonStyle())
            LocalBetaNote()
        }.navigationTitle("Member pass")
    }
    private var qrImage: UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data("JFTA-DEMO:\(store.snapshot.demoPassID.uuidString)".utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }
}
struct ServiceView: View {
    let kind: ServiceKind
    var body: some View {
        Page {
            Image(systemName: kind.symbol).font(.system(size: 48, weight: .light)).foregroundStyle(JFTATheme.gold).padding(.top, 14)
            Text(headline).font(.system(.largeTitle, design: .rounded).weight(.black))
            Text("Prepare a local draft and keep the relevant information together.").foregroundStyle(JFTATheme.secondary)
            NavigationLink("Start \(kind.rawValue.lowercased()) draft", value: Route.request(kind)).buttonStyle(GoldButtonStyle()).accessibilityIdentifier("service.start")
            if kind == .health || kind == .financial {
                NavigationLink(value: Route.consultation(kind)) { Card { RowLabel(title: kind == .health ? "Consultation request" : "Financial consultation", detail: "Prepare preferences only; no booking is made", symbol: "calendar") } }.buttonStyle(.plain).accessibilityIdentifier("service.consultation")
            }
            Card {
                Text("Service connection pending").font(.headline)
                Text("This build does not connect you to a lawyer, doctor, financial advisor, or benefit provider. No professional availability, coverage, or response time is promised.").font(.subheadline).foregroundStyle(JFTATheme.secondary)
            }
            if kind == .health { Text("For an emergency, contact local emergency services. Do not rely on this beta for urgent care.").font(.footnote).foregroundStyle(JFTATheme.gold) }
            NavigationLink("Browse resources", value: Route.resources)
        }.navigationTitle(kind.rawValue + " support")
    }
    private var headline: String {
        switch kind {
        case .legal: return "A CLEARER\nNEXT STEP."
        case .health: return "CARE STARTS\nWITH CLARITY."
        case .financial: return "PLAN YOUR\nNEXT MOVE."
        case .benefits: return "MORE FOR\nYOUR ROAD."
        case .general: return "LET'S GET\nORGANIZED."
        }
    }
}
