import SwiftUI
import UniformTypeIdentifiers
import QuickLook

actor DocumentVault {
    private let store: LocalDocumentStore
    init(directory: URL) { store = LocalDocumentStore(directory: directory) }
    func list() throws -> [LocalDocument] { try store.list() }
    func importURL(_ url: URL) throws -> LocalDocument {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<LocalDocument, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            result = Result { try store.importFile(from: coordinated) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }
    func delete(_ document: LocalDocument) throws { try store.delete(document) }
    func addTestSample() throws -> LocalDocument {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("jfta-sample-\(UUID().uuidString).txt")
        try Data("JFTA non-sensitive UI test sample. No upload occurred.".utf8).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }
        return try store.importFile(from: temp)
    }
}
struct DocumentsView: View {
    @EnvironmentObject private var store: AppStore
    var requestID: UUID? = nil
    @State private var vault: DocumentVault?
    @State private var documents: [LocalDocument] = []
    @State private var search = ""
    @State private var importing = false
    @State private var busy = false
    @State private var error: String?
    @State private var previewURL: URL?
    @State private var pendingDelete: LocalDocument?
    @State private var notice = ""
    private var filtered: [LocalDocument] { documents.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        List {
            Section {
                LocalBetaNote(text: "Local copies only. Not uploaded, not backed up to JFTA. Use sample files while testing.")
                Text("PDF, images, or text. Up to 25 MiB per file; 100 files / 200 MiB total.").font(.caption).foregroundStyle(JFTATheme.secondary)
                if !notice.isEmpty { Text(notice).font(.caption).foregroundStyle(JFTATheme.gold).accessibilityIdentifier("documents.notice") }
            }
            if busy { ProgressView("Working with local files...") }
            if filtered.isEmpty && !busy {
                EmptyPanel(symbol: "doc.on.doc", title: "Your local document vault", detail: "Import a sample file to preview, share, or attach it to a draft.").listRowBackground(Color.clear)
            }
            ForEach(filtered) { document in
                HStack {
                    Button { previewURL = document.url } label: {
                        HStack { Image(systemName: "doc.text").foregroundStyle(JFTATheme.gold); Text(document.name).font(.subheadline).foregroundStyle(.white).lineLimit(2); Spacer() }
                    }.buttonStyle(.plain).accessibilityIdentifier("document.preview")
                    if let requestID {
                        let selected = store.snapshot.requests.first(where: { $0.id == requestID })?.documentIDs.contains(document.id) == true
                        Button { toggle(document.id, requestID: requestID) } label: { Image(systemName: selected ? "checkmark.circle.fill" : "circle").frame(width: 44, height: 44) }
                            .accessibilityLabel(selected ? "Detach document" : "Attach document")
                    }
                    Menu {
                        ShareLink(item: document.url) { Label("Share local copy", systemImage: "square.and.arrow.up") }
                        Button("Delete local copy", role: .destructive) { pendingDelete = document }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel("Document actions")
                }.disabled(busy)
            }
            #if DEBUG
            if store.isTesting {
                Button("Import test sample") { importSample() }.accessibilityIdentifier("documents.testSample")
            }
            #endif
        }.appForm().navigationTitle(requestID == nil ? "Documents" : "Attach documents")
            .searchable(text: $search, prompt: "Search local files")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { importing = true } label: { Label("Import", systemImage: "plus") }.disabled(busy).accessibilityIdentifier("documents.import") } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .png, .jpeg, .heic, .heif, .plainText], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): importFiles(urls)
                case .failure(let failure): error = failure.localizedDescription
                }
            }
            .quickLookPreview($previewURL)
            .task { if vault == nil { vault = DocumentVault(directory: store.documentsDirectory) }; await refresh() }
            .confirmationDialog("Delete only this local copy?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Delete local copy", role: .destructive) { removePending() }
            }.appError($error)
    }
    private func refresh() async { do { documents = try await vault?.list() ?? [] } catch { self.error = error.localizedDescription } }
    private func importFiles(_ urls: [URL]) {
        guard let vault else { return }; busy = true; notice = ""
        Task {
            var successes = 0
            var failures: [String] = []
            for url in urls {
                do { let document = try await vault.importURL(url); successes += 1; if let requestID { attach(document.id, requestID: requestID) } }
                catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
            }
            await refresh(); busy = false
            notice = "\(successes) local file(s) imported. Nothing was uploaded."
            if !failures.isEmpty { error = failures.joined(separator: "\n") }
        }
    }
    private func importSample() {
        guard let vault else { return }; busy = true
        Task {
            do { let doc = try await vault.addTestSample(); if let requestID { attach(doc.id, requestID: requestID) }; notice = "Test sample imported locally." }
            catch { self.error = error.localizedDescription }
            await refresh(); busy = false
        }
    }
    private func attach(_ id: String, requestID: UUID) {
        let ids = store.snapshot.requests.first(where: { $0.id == requestID })?.documentIDs ?? []
        do { try store.setDocumentIDs(ids + [id], requestID: requestID) } catch { self.error = error.localizedDescription }
    }
    private func toggle(_ id: String, requestID: UUID) {
        var ids = store.snapshot.requests.first(where: { $0.id == requestID })?.documentIDs ?? []
        if ids.contains(id) { ids.removeAll { $0 == id } } else { ids.append(id) }
        do { try store.setDocumentIDs(ids, requestID: requestID) } catch { self.error = error.localizedDescription }
    }
    private func removePending() {
        guard let doc = pendingDelete, let vault else { return }; pendingDelete = nil; busy = true
        Task {
            do {
                try await vault.delete(doc)
                for request in store.snapshot.requests where request.documentIDs.contains(doc.id) {
                    try store.setDocumentIDs(request.documentIDs.filter { $0 != doc.id }, requestID: request.id)
                }
                notice = "Local copy deleted. The original file was not changed."
            } catch { self.error = error.localizedDescription }
            await refresh(); busy = false
        }
    }
}
