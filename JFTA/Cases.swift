import SwiftUI

struct CasesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var deleteID: UUID?
    @State private var error: String?
    private var requests: [ServiceRequest] {
        store.snapshot.requests.filter { search.isEmpty || ($0.title + " " + $0.details + " " + $0.service.rawValue).localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        List {
            Section {
                NavigationLink("Start a request", value: Route.request(.general)).font(.headline).foregroundStyle(JFTATheme.gold).accessibilityIdentifier("cases.startRequest")
                LocalBetaNote(text: "All items here are local drafts. They have not been submitted.")
            }
            if requests.isEmpty {
                EmptyPanel(symbol: "folder", title: search.isEmpty ? "A clear road ahead" : "No matching drafts", detail: search.isEmpty ? "Create your first draft to organize a question or request." : "Try another title or category.").listRowBackground(Color.clear)
            } else {
                Section("Your drafts") {
                    ForEach(requests) { request in
                        NavigationLink(value: Route.caseDetail(request.id)) {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack { Label(request.service.rawValue, systemImage: request.service.symbol).foregroundStyle(JFTATheme.gold); Spacer(); Text(request.statusLabel).foregroundStyle(JFTATheme.secondary) }.font(.caption)
                                Text(request.title).font(.headline)
                                Text(request.updatedAt, style: .date).font(.caption).foregroundStyle(JFTATheme.secondary)
                            }.padding(.vertical, 6)
                        }.accessibilityIdentifier("case.\(request.title)")
                        .swipeActions { Button("Delete", role: .destructive) { deleteID = request.id } }
                    }
                }
            }
        }.appForm().searchable(text: $search, prompt: "Search drafts").navigationTitle("Cases")
            .confirmationDialog("Delete this local draft?", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } }), titleVisibility: .visible) {
                Button("Delete draft", role: .destructive) {
                    guard let id = deleteID else { return }
                    do { try store.deleteRequest(id) } catch { self.error = error.localizedDescription }; deleteID = nil
                }
            }.appError($error)
    }
}
private struct RequestFormValues: Equatable {
    let service: ServiceKind
    let title: String
    let details: String
    let state: String
    let date: Date
}
struct RequestFormView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var service: ServiceKind = .general
    var editingID: UUID? = nil
    var consultation = false
    @State private var title = ""
    @State private var details = ""
    @State private var state = ""
    @State private var date = Date()
    @State private var initialized = false
    @State private var error: String?
    @State private var saved = false
    @State private var originalValues: RequestFormValues?
    @State private var confirmDiscard = false
    private var currentValues: RequestFormValues { .init(service: service, title: title, details: details, state: state, date: date) }
    private var hasUnsavedChanges: Bool { originalValues.map { $0 != currentValues } ?? false }
    var body: some View {
        Form {
            Section { LocalBetaNote(text: consultation ? "This saves a consultation preference, not an appointment. No professional will be contacted." : "Save a local draft. No request will be sent to a professional.") }
            Section("What do you need help with?") {
                Picker("Category", selection: $service) { ForEach(ServiceKind.allCases) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("request.service")
                TextField("Request title", text: $title).accessibilityIdentifier("request.title")
                ZStack(alignment: .topLeading) {
                    if details.isEmpty { Text("Describe your request").foregroundStyle(.secondary).padding(.top, 8).padding(.leading, 4).allowsHitTesting(false) }
                    TextEditor(text: $details).frame(minHeight: 140).accessibilityLabel("Describe your request").accessibilityIdentifier("request.details")
                }
                Text("\(details.count) / 3,000 characters").font(.caption).foregroundStyle(JFTATheme.secondary)
            }
            Section(consultation ? "Your preference" : "Details") {
                TextField("State or location (optional)", text: $state).accessibilityIdentifier("request.location")
                DatePicker(consultation ? "Preferred date" : "Event date", selection: $date, displayedComponents: .date)
            }
            Section { Text("You can attach sample documents after saving the draft. Do not enter sensitive personal, medical, or legal information in this beta.").font(.footnote).foregroundStyle(JFTATheme.secondary) }
        }.appForm().navigationTitle(consultation ? "Consultation draft" : (editingID == nil ? "Start a request" : "Edit draft"))
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { JFTATheme.dismissKeyboard(); if hasUnsavedChanges { confirmDiscard = true } else { dismiss() } } label: { Label("Back", systemImage: "chevron.left") }
                        .accessibilityIdentifier("request.back")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.fontWeight(.bold).accessibilityIdentifier("request.save") }
            }
            .confirmationDialog("Discard unsaved changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                // A cancel-role action is hidden in the iOS popover presentation. Keep this explicit choice visible.
                Button("Keep editing") { confirmDiscard = false }.accessibilityIdentifier("request.keepEditing")
                Button("Discard changes", role: .destructive) { confirmDiscard = false; dismiss() }.accessibilityIdentifier("request.discard")
            } message: { Text("Your changes have not been saved. The previously saved draft, if any, will remain unchanged.") }
            .onAppear {
                guard !initialized else { return }; initialized = true
                if let id = editingID, let request = store.snapshot.requests.first(where: { $0.id == id }) {
                    service = request.service; title = request.title; details = request.details; state = request.state; date = request.incidentDate
                }
                originalValues = currentValues
            }
            .appError($error)
            .alert("Draft saved", isPresented: $saved) { Button("Done") { dismiss() } } message: { Text("Saved on this device only. Nothing has been sent or booked.") }
    }
    private func save() {
        do { try store.saveRequest(service: service, title: title, details: details, state: state, date: date, editingID: editingID); JFTATheme.dismissKeyboard(); saved = true }
        catch { self.error = error.localizedDescription }
    }
}
struct CaseDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var error: String?
    let id: UUID
    var body: some View {
        Page {
            if let request = store.snapshot.requests.first(where: { $0.id == id }) {
                SectionLabel(text: request.reference)
                Text(request.title).font(.largeTitle.bold()).accessibilityIdentifier("caseDetail.title")
                Label(request.statusLabel, systemImage: "pencil.circle").font(.subheadline.bold()).foregroundStyle(JFTATheme.gold)
                Card {
                    LabeledContent("Category", value: request.service.rawValue)
                    LabeledContent("Location", value: request.state.isEmpty ? "Not specified" : request.state)
                    LabeledContent("Date", value: request.incidentDate.formatted(date: .abbreviated, time: .omitted))
                    Divider()
                    Text(request.details).textSelection(.enabled)
                }
                NavigationLink("Edit draft", value: Route.editRequest(id)).buttonStyle(GoldButtonStyle()).accessibilityIdentifier("caseDetail.edit")
                NavigationLink(value: Route.caseDocuments(id)) { Card { RowLabel(title: "Attach sample documents", detail: "\(request.documentIDs.count) local reference(s)", symbol: "paperclip") } }.buttonStyle(.plain).accessibilityIdentifier("caseDetail.documents")
                ShareLink(item: request.exportText) { Label("Export draft text", systemImage: "square.and.arrow.up") }.accessibilityIdentifier("caseDetail.share")
                Button("Delete local draft", role: .destructive) { confirmDelete = true }.accessibilityIdentifier("caseDetail.delete")
                LocalBetaNote(text: "No case has been opened with a provider. No response is pending. You control whether to export this draft.")
            } else { EmptyPanel(symbol: "folder.badge.questionmark", title: "Draft not found", detail: "The local draft may have been deleted.") }
        }.navigationTitle("Draft details").appError($error)
            .alert("Delete local draft?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { do { try store.deleteRequest(id); dismiss() } catch { self.error = error.localizedDescription } }.accessibilityIdentifier("caseDetail.confirmDelete")
            } message: { Text("This removes the draft. Documents remain in the local vault and original files are not changed.") }
    }
}
