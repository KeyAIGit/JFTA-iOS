import SwiftUI

struct BenefitsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var savedOnly = false
    private var offers: [Offer] {
        Offer.samples.filter { (!savedOnly || store.snapshot.savedOfferIDs.contains($0.id)) && (search.isEmpty || ($0.title + " " + $0.category).localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        List {
            Section {
                Text("MORE FOR\nYOUR ROAD.").font(.system(.title, design: .rounded).weight(.black)).padding(.vertical, 8)
                Text("Explore sample benefits. No discounts can be redeemed yet.").font(.subheadline).foregroundStyle(JFTATheme.secondary)
                Toggle("Saved offers only", isOn: $savedOnly).accessibilityIdentifier("benefits.savedOnly")
            }
            if offers.isEmpty { EmptyPanel(symbol: "bookmark", title: "No offers here yet", detail: "Change your search or save a sample offer.").listRowBackground(Color.clear) }
            ForEach(offers) { offer in
                NavigationLink(value: Route.offer(offer.id)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: offer.symbol).font(.title2).foregroundStyle(JFTATheme.gold); Spacer(); Text("SAMPLE").font(.caption2.bold()).foregroundStyle(JFTATheme.secondary) }
                        Text(offer.title).font(.title3.bold())
                        HStack { Text(offer.category).font(.caption); Spacer(); if store.snapshot.savedOfferIDs.contains(offer.id) { Image(systemName: "bookmark.fill").foregroundStyle(JFTATheme.gold) } }
                    }.padding(.vertical, 10)
                }.accessibilityIdentifier("offer.\(offer.id)")
            }
        }.appForm().searchable(text: $search, prompt: "Search benefits").navigationTitle("Benefits")
    }
}
struct OfferDetailView: View {
    @EnvironmentObject private var store: AppStore
    let id: String
    @State private var error: String?
    var body: some View {
        Page {
            if let offer = Offer.samples.first(where: { $0.id == id }) {
                Image(systemName: offer.symbol).font(.system(size: 64, weight: .light)).foregroundStyle(JFTATheme.gold).padding(.top, 16)
                SectionLabel(text: "Sample offer / " + offer.category)
                Text(offer.title).font(.largeTitle.bold())
                Text(offer.detail).foregroundStyle(JFTATheme.secondary)
                Button {
                    do { try store.toggleOffer(id) } catch { self.error = error.localizedDescription }
                } label: {
                    Label(store.snapshot.savedOfferIDs.contains(id) ? "Remove from saved" : "Save offer", systemImage: store.snapshot.savedOfferIDs.contains(id) ? "bookmark.fill" : "bookmark")
                }.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("offer.save")
                Card {
                    Text("Redemption is not available").font(.headline)
                    Text("A real offer must show verified provider details, eligibility, dates, and terms before it can be used. This sample has no redeemable QR or coupon.").font(.subheadline).foregroundStyle(JFTATheme.secondary)
                }
                NavigationLink("View demo member pass", value: Route.memberPass)
            } else { EmptyPanel(symbol: "tag", title: "Offer not found", detail: "This sample is no longer in the local catalog.") }
        }.navigationTitle("Offer details").appError($error)
    }
}
struct ResourcesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var savedOnly = false
    private var articles: [Article] { Article.samples.filter { (!savedOnly || store.snapshot.savedArticleIDs.contains($0.id)) && (search.isEmpty || ($0.title + " " + $0.category).localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        List {
            Section { Toggle("Saved resources only", isOn: $savedOnly) }
            ForEach(articles) { article in
                NavigationLink(value: Route.article(article.id)) { RowLabel(title: article.title, detail: article.category, symbol: article.symbol) }.accessibilityIdentifier("article.\(article.id)")
            }
            if articles.isEmpty { EmptyPanel(symbol: "book.closed", title: "No matching resources", detail: "Try another search or turn off the saved filter.").listRowBackground(Color.clear) }
        }.appForm().searchable(text: $search, prompt: "Search resources").navigationTitle("Resources")
    }
}
struct ArticleView: View {
    @EnvironmentObject private var store: AppStore
    let id: String
    @State private var error: String?
    var body: some View {
        Page {
            if let article = Article.samples.first(where: { $0.id == id }) {
                SectionLabel(text: article.category)
                Text(article.title).font(.largeTitle.bold())
                ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { item in Text(item.element).font(.body).lineSpacing(5).textSelection(.enabled) }
                Button {
                    do { try store.toggleArticle(id) } catch { self.error = error.localizedDescription }
                } label: { Label(store.snapshot.savedArticleIDs.contains(id) ? "Saved for later" : "Save for later", systemImage: "bookmark") }.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("article.save")
                ShareLink(item: article.title + "\n\n" + article.paragraphs.joined(separator: "\n\n")) { Label("Share article text", systemImage: "square.and.arrow.up") }
            }
        }.navigationTitle("Resource").appError($error)
    }
}
