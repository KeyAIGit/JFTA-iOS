import SwiftUI

struct AccountSyncView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var remote = RemoteBackend.shared
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var message: String?

    var body: some View {
        Form {
            Section("JFTA cloud beta") {
                if let signedIn = remote.email {
                    Label(signedIn, systemImage: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(JFTATheme.gold)
                    Text("Cloud sync is optional. Local data remains the working copy on this device.")
                        .font(.caption).foregroundStyle(JFTATheme.secondary)
                } else {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("account.email")
                    SecureField("Password (12+ characters)", text: $password)
                        .textContentType(.password)
                        .accessibilityIdentifier("account.password")
                }
            }

            if remote.userID == nil {
                Section {
                    Button("Sign in") { Task { await signIn() } }
                        .disabled(remote.busy || email.isEmpty || password.count < 12)
                        .accessibilityIdentifier("account.signIn")
                    Button("Create account") { Task { await signUp() } }
                        .disabled(remote.busy || email.isEmpty || password.count < 12)
                        .accessibilityIdentifier("account.signUp")
                }
            } else {
                Section("Sync") {
                    Button("Sync local workspace now") {
                        Task { await sync() }
                    }
                    .disabled(remote.busy)
                    .accessibilityIdentifier("account.sync")
                    Text("Sync currently covers your profile, request drafts, private discussion drafts/replies, and saved offers. Documents remain local until their upload flow is enabled and tested.")
                        .font(.caption).foregroundStyle(JFTATheme.secondary)
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await signOut() }
                    }
                    .disabled(remote.busy)
                    .accessibilityIdentifier("account.signOut")
                }
            }

            if remote.busy {
                Section { ProgressView("Working securely…") }
            }
            Section {
                LocalBetaNote(text: "This is a beta account. Do not upload medical, legal, identity, payment, or other sensitive documents. JFTA has not enabled a HIPAA-compliant document workflow.")
            }
        }
        .appForm()
        .navigationTitle("Account & sync")
        .task { await remote.refreshSession() }
        .appError($error)
        .alert("JFTA cloud", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }
    @MainActor private func signIn() async {
        do {
            try await remote.signIn(email: email, password: password)
            password = ""
            message = "Signed in. Nothing is synced until you choose Sync local workspace now."
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor private func signUp() async {
        do {
            message = try await remote.signUp(email: email, password: password)
            password = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor private func sync() async {
        do {
            try await remote.syncSnapshot(store.snapshot)
            message = remote.lastMessage
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor private func signOut() async {
        do {
            try await remote.signOut()
            message = "Signed out. Your local workspace remains on this device."
        } catch {
            self.error = error.localizedDescription
        }
    }
}
