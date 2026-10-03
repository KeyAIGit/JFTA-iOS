import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    private var posts: [CommunityPost] { store.snapshot.posts.filter { search.isEmpty || ($0.title + " " + $0.body).localizedCaseInsensitiveContains(search) } }
    var body: some View {
        List {
            Section { LocalBetaNote(text: "A local discussion workspace. Posts and replies are not published or shared with other drivers.") }
            if posts.isEmpty { EmptyPanel(symbol: "bubble.left.and.bubble.right", title: "Start a conversation draft", detail: "Write a sample post to test discussions. Only you can see it on this device.").listRowBackground(Color.clear) }
            ForEach(posts) { post in
                NavigationLink(value: Route.thread(post.id)) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(post.author).font(.caption.bold()).foregroundStyle(JFTATheme.gold)
                        Text(post.title).font(.headline)
                        Text(post.body).font(.subheadline).foregroundStyle(JFTATheme.secondary).lineLimit(3)
                        Label("\(post.replies.count) local replies", systemImage: "bubble.right").font(.caption).foregroundStyle(JFTATheme.secondary)
                    }.padding(.vertical, 8)
                }.accessibilityIdentifier("post.\(post.title)")
            }
        }.appForm().searchable(text: $search, prompt: "Search local discussions").navigationTitle("Community")
            .toolbar { ToolbarItem(placement: .primaryAction) { NavigationLink(value: Route.composePost) { Label("Write", systemImage: "square.and.pencil") }.accessibilityIdentifier("community.compose") } }
    }
}
struct ComposePostView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var editingID: UUID? = nil
    @State private var loaded = false
    @State private var originalTitle = ""
    @State private var originalText = ""
    @State private var title = ""
    @State private var text = ""
    @State private var error: String?
    var body: some View {
        Form {
            Section { LocalBetaNote(text: "This post will be saved locally. It will not be published.") }
            Section("Discussion draft") {
                TextField("Title", text: $title).accessibilityIdentifier("post.title")
                TextEditor(text: $text).frame(minHeight: 200).accessibilityLabel("Post body").accessibilityIdentifier("post.body")
            }
        }.appForm().navigationTitle(editingID == nil ? "Write a post" : "Edit post")
            .guardUnsavedChanges(title != originalTitle || text != originalText, identifier: "post")
            .onAppear {
                guard !loaded else { return }; loaded = true
                if let id = editingID, let post = store.snapshot.posts.first(where: { $0.id == id }) { title = post.title; text = post.body }
                originalTitle = title; originalText = text
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") { do { try store.createPost(title: title, body: text, editingID: editingID); JFTATheme.dismissKeyboard(); dismiss() } catch { self.error = error.localizedDescription } }.accessibilityIdentifier("post.save") } }.appError($error)
    }
}
struct ThreadView: View {
    @EnvironmentObject private var store: AppStore
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var reply = ""
    @State private var error: String?
    var body: some View {
        Page {
            if let post = store.snapshot.posts.first(where: { $0.id == id }) {
                SectionLabel(text: "Local discussion")
                Text(post.title).font(.largeTitle.bold()).accessibilityIdentifier("thread.title")
                Text(post.author).font(.caption).foregroundStyle(JFTATheme.gold)
                Text(post.body).textSelection(.enabled)
                Divider()
                ForEach(post.replies) { item in Card { Text(item.author).font(.caption.bold()).foregroundStyle(JFTATheme.gold); Text(item.text) } }
                Card {
                    TextField("Write a local reply", text: $reply, axis: .vertical).lineLimit(2...6).accessibilityIdentifier("thread.reply")
                    Button("Save reply") { do { try store.reply(postID: id, text: reply); reply = ""; JFTATheme.dismissKeyboard() } catch { self.error = error.localizedDescription } }.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("thread.saveReply")
                }
                NavigationLink("Edit post", value: Route.editPost(id)).buttonStyle(GoldButtonStyle()).accessibilityIdentifier("thread.edit")
                ShareLink(item: post.title + "\n\n" + post.body + "\n\nJFTA local discussion draft. Not published.") { Label("Export post text", systemImage: "square.and.arrow.up") }.accessibilityIdentifier("thread.share")
                Button("Delete local discussion", role: .destructive) { JFTATheme.dismissKeyboard(); confirmDelete = true }.accessibilityIdentifier("thread.delete")
                LocalBetaNote(text: "Replies are stored only here, not sent to a community server.")
            }
        }.navigationTitle("Discussion").appError($error)
            .alert("Delete local discussion?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { do { try store.deletePost(id); dismiss() } catch { self.error = error.localizedDescription } }.accessibilityIdentifier("thread.confirmDelete")
            } message: { Text("This removes the local post and its replies from this device. It cannot be undone.") }
    }
}
struct MarketplaceView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var savedOnly = false
    private var listings: [MarketListing] { MarketListing.samples.filter { (!savedOnly || store.snapshot.savedListingIDs.contains($0.id)) && (search.isEmpty || ($0.title + " " + $0.category).localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        List {
            Section { LocalBetaNote(text: "Sample listings only. No seller, transaction, or reservation is connected."); Toggle("Saved listings only", isOn: $savedOnly) }
            ForEach(listings) { listing in
                NavigationLink(value: Route.listing(listing.id)) { RowLabel(title: listing.title, detail: listing.category + " / Sample", symbol: listing.symbol) }.accessibilityIdentifier("listing.\(listing.id)")
            }
            if listings.isEmpty { EmptyPanel(symbol: "truck.box", title: "No matching listings", detail: "Try another search or filter.").listRowBackground(Color.clear) }
        }.appForm().searchable(text: $search, prompt: "Search sample listings").navigationTitle("Marketplace")
    }
}
struct ListingView: View {
    @EnvironmentObject private var store: AppStore
    let id: String
    @State private var error: String?
    var body: some View {
        Page {
            if let listing = MarketListing.samples.first(where: { $0.id == id }) {
                Image(systemName: listing.symbol).font(.system(size: 80, weight: .ultraLight)).foregroundStyle(JFTATheme.gold).frame(maxWidth: .infinity).padding(.vertical, 35).background(JFTATheme.surface).clipShape(RoundedRectangle(cornerRadius: 20))
                SectionLabel(text: listing.category + " / Sample listing")
                Text(listing.title).font(.largeTitle.bold())
                Text(listing.description).foregroundStyle(JFTATheme.secondary)
                Button {
                    do { try store.toggleListing(id) } catch { self.error = error.localizedDescription }
                } label: { Label(store.snapshot.savedListingIDs.contains(id) ? "Remove from saved" : "Save listing", systemImage: "bookmark") }.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("listing.save")
                Card { Text("Seller not connected").font(.headline); Text("The local beta does not make contact, take payments, or verify equipment. Sample listings must not be treated as real offers.").font(.subheadline).foregroundStyle(JFTATheme.secondary) }
            }
        }.navigationTitle("Listing details").appError($error)
    }
}
