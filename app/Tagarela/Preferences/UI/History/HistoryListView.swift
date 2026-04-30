import SwiftUI
import AppKit

@MainActor
struct HistoryListView: View {
    let historyStore: HistoryStore
    let injector: Injecting
    let limitProvider: () -> Int

    @State private var items: [Transcription] = []
    @State private var query: String = ""
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(String(localized: "history.search.placeholder",
                                  defaultValue: "Buscar no cru ou refinado…"),
                          text: $query)
                    .textFieldStyle(.roundedBorder)
                Button(String(localized: "history.clearAll",
                                defaultValue: "Limpar tudo"), role: .destructive) {
                    confirmAndClear()
                }
                .disabled(items.isEmpty)
            }
            HStack {
                Text(countLabel)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            if let err = loadError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filtered) { entry in
                        HistoryEntryView(entry: entry, injector: injector)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 200)
        }
        .task { await reload() }
        // Reage a mudança em historyMaxItems (Retenção section acima): se user
        // sobe ou diminui o limite com a aba aberta, lista re-fetch.
        .onChange(of: limitProvider()) { _, _ in
            Task { await reload() }
        }
    }

    private var filtered: [Transcription] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter {
            $0.rawText.lowercased().contains(q) || $0.refinedText.lowercased().contains(q)
        }
    }

    private var countLabel: String {
        if !query.isEmpty {
            return String(localized: "history.count.filtered",
                          defaultValue: "\(filtered.count) de \(items.count)")
        }
        return String(localized: "history.count.total",
                      defaultValue: "\(items.count) registros")
    }

    private func reload() async {
        do {
            items = try await historyStore.recent(limit: limitProvider())
            loadError = nil
        } catch {
            loadError = String(localized: "history.loadFailed",
                                defaultValue: "Não foi possível carregar.")
        }
    }

    private func confirmAndClear() {
        let alert = NSAlert()
        alert.messageText = String(localized: "history.clearAll.confirm.title",
                                    defaultValue: "Apagar todo o histórico?")
        alert.informativeText = String(localized: "history.clearAll.confirm.info",
                                        defaultValue: "Esta ação não pode ser desfeita.")
        alert.addButton(withTitle: String(localized: "common.delete", defaultValue: "Apagar"))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancelar"))
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                try? await historyStore.clearAll()
                await reload()
            }
        }
    }
}
