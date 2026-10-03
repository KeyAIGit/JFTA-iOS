import SwiftUI
import UIKit

enum JFTATheme {
    @MainActor static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    static let background = Color(red: 0.035, green: 0.045, blue: 0.052)
    static let surface = Color(red: 0.075, green: 0.087, blue: 0.095)
    static let gold = Color(red: 1.0, green: 0.76, blue: 0.06)
    static let secondary = Color(red: 0.68, green: 0.72, blue: 0.74)
    static let border = Color.white.opacity(0.12)
}
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).foregroundStyle(.black).frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 14).background(JFTATheme.gold.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(18).background(JFTATheme.surface).clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(JFTATheme.border, lineWidth: 1))
    }
}
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) { content }.padding(20).padding(.bottom, 20) }
            .background(JFTATheme.background).scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
    }
}
struct SectionLabel: View {
    var text: String
    var body: some View { Text(text.uppercased()).font(.caption.weight(.bold)).tracking(1.7).foregroundStyle(JFTATheme.secondary).accessibilityAddTraits(.isHeader) }
}
struct RowLabel: View {
    let title: String
    var detail: String = ""
    var symbol: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(JFTATheme.gold).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.white)
                if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(JFTATheme.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(JFTATheme.secondary)
        }.frame(minHeight: 44).contentShape(Rectangle())
    }
}
struct LocalBetaNote: View {
    var text = "Local beta. No requests, payments, or documents are sent to JFTA."
    var body: some View {
        Label(text, systemImage: "iphone.and.arrow.forward")
            .font(.caption).foregroundStyle(JFTATheme.secondary).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("localBetaNotice")
    }
}
struct EmptyPanel: View {
    let symbol: String; let title: String; let detail: String
    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 36, weight: .light)).foregroundStyle(JFTATheme.gold)
            Text(title).font(.title3.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(JFTATheme.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 38).padding(.horizontal, 20)
    }
}
extension View {
    func appError(_ error: Binding<String?>) -> some View {
        alert("Could not complete action", isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } })) {
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: { Text(error.wrappedValue ?? "") }
    }
    func appForm() -> some View { scrollContentBackground(.hidden).background(JFTATheme.background).scrollDismissesKeyboard(.interactively) }
}


extension View {
    func appKeyboardToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .accessibilityIdentifier("keyboard.done")
            }
        }
    }
}

// Explicit back action protects editable forms without pretending changes were saved.
private struct UnsavedChangesGuard: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let hasChanges: Bool
    let identifier: String
    @State private var showing = false
    func body(content: Content) -> some View {
        content.navigationBarBackButtonHidden(true).toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { JFTATheme.dismissKeyboard(); if hasChanges { showing = true } else { dismiss() } }
                    label: { Label("Back", systemImage: "chevron.left") }
                    .accessibilityIdentifier(identifier + ".back")
            }
        }.alert("Discard unsaved changes?", isPresented: $showing) {
            Button("Keep editing", role: .cancel) {}.accessibilityIdentifier(identifier + ".keepEditing")
            Button("Discard changes", role: .destructive) { dismiss() }.accessibilityIdentifier(identifier + ".discard")
        } message: { Text("Only your unsaved changes will be discarded. Previously saved data will remain unchanged.") }
    }
}
extension View {
    func guardUnsavedChanges(_ hasChanges: Bool, identifier: String) -> some View {
        modifier(UnsavedChangesGuard(hasChanges: hasChanges, identifier: identifier))
    }
}
