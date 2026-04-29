import SwiftUI
import AppKit

@MainActor
struct StylesView: View {
    @ObservedObject var prefs: PreferencesStore
    @ObservedObject var customStore: CustomStyleStoreLive

    @State private var sheetMode: CustomStyleEditSheet.Mode?
    @State private var showSheet = false

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]

    var body: some View {
        // NOTE: bypass deliberado de StyleProvider — a grid precisa de cards
        // visualmente distintos (built-ins read-only com badge "PRONTO" vs
        // custom editáveis com lápis), enquanto StyleProvider achata em uma
        // lista única ordenada (apropriado pro submenu menubar e RefinerFactory,
        // não pra esta UI). StyleProvider segue como source of truth pra
        // refiner selection + menubar; esta tela é exceção documentada.
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(BuiltInStyles.all, id: \.id) { s in
                    builtInCard(s)
                }
                ForEach(customStore.styles, id: \.id) { c in
                    customCard(c)
                }
                addCard
            }
            .padding(20)
        }
        .task { await customStore.reload() }
        .sheet(isPresented: $showSheet, onDismiss: { sheetMode = nil }) {
            if let mode = sheetMode {
                CustomStyleEditSheet(mode: mode, customStore: customStore) {
                    showSheet = false
                }
            }
        }
    }

    private func builtInCard(_ style: Style) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(style.name).font(.headline)
                Spacer()
                Text(String(localized: "styles.badge.builtin", defaultValue: "PRONTO"))
                    .font(.caption2).foregroundStyle(.tint)
            }
            Text(style.systemPrompt.prefix(120) + (style.systemPrompt.count > 120 ? "…" : ""))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(prefs.selectedStyleID == style.id ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(prefs.selectedStyleID == style.id ? Color.accentColor : Color.secondary.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { prefs.selectedStyleID = style.id }
    }

    private func customCard(_ style: CustomStyle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(style.name).font(.headline)
                Spacer()
                Button { sheetMode = .edit(style); showSheet = true } label: {
                    Image(systemName: "pencil")
                }.buttonStyle(.plain)
            }
            Text(style.systemPrompt.prefix(120) + (style.systemPrompt.count > 120 ? "…" : ""))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(prefs.selectedStyleID == style.id ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(prefs.selectedStyleID == style.id ? Color.accentColor : Color.secondary.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button(String(localized: "styles.context.delete", defaultValue: "Apagar"), role: .destructive) {
                confirmAndDelete(style)
            }
        }
        .onTapGesture { prefs.selectedStyleID = style.id }
    }

    private var addCard: some View {
        Button { sheetMode = .create; showSheet = true } label: {
            VStack {
                Image(systemName: "plus.circle").font(.title)
                Text(String(localized: "styles.add", defaultValue: "Novo estilo custom"))
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])))
        }
        .buttonStyle(.plain)
    }

    private func confirmAndDelete(_ style: CustomStyle) {
        let alert = NSAlert()
        alert.messageText = String(localized: "styles.delete.confirm.title",
                                    defaultValue: "Apagar '\(style.name)'?")
        alert.informativeText = String(localized: "styles.delete.confirm.info",
                                        defaultValue: "Esta ação não pode ser desfeita.")
        alert.addButton(withTitle: String(localized: "common.delete", defaultValue: "Apagar"))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancelar"))
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            Task { try? await customStore.delete(style) }
        }
    }
}
