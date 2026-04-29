import SwiftUI
import AppKit

@MainActor
struct HistoryEntryView: View {
    let entry: Transcription
    let injector: Injecting

    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(displayApp).bold()
                Text("·").foregroundStyle(.secondary)
                Text(relative).foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                Text(entry.refinerKind).foregroundStyle(.secondary)
                if let llm = entry.llmModelName, !llm.isEmpty {
                    Text("·").foregroundStyle(.secondary)
                    Text(llm).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .font(.caption)

            if !entry.rawText.isEmpty && entry.rawText != entry.refinedText {
                Text("cru: \(entry.rawText.prefix(200))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(entry.refinedText)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                if let status {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Button(String(localized: "history.entry.reinject", defaultValue: "Re-injetar")) {
                    Task { await reinject() }
                }
                Button(String(localized: "history.entry.copy", defaultValue: "Copiar")) {
                    copyToClipboard()
                }
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor),
                     in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2)))
    }

    private var displayApp: String {
        guard let bundleID = entry.frontmostAppBundleID else { return "—" }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return bundleID
    }

    private var relative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: entry.createdAt, relativeTo: .now)
    }

    private func reinject() async {
        do {
            _ = try await injector.inject(text: entry.refinedText)
            status = String(localized: "history.entry.reinjected", defaultValue: "Re-injetado")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            status = nil
        } catch {
            status = String(localized: "history.entry.reinjectFailed", defaultValue: "Falhou — colar manual")
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.refinedText, forType: .string)
        status = String(localized: "history.entry.copied", defaultValue: "Copiado")
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            status = nil
        }
    }
}
