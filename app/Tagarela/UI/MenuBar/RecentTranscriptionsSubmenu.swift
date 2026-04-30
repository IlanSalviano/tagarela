import SwiftUI
import AppKit

@MainActor
struct RecentTranscriptionsSubmenu: View {
    @ObservedObject var provider: RecentTranscriptionsProvider
    let injector: Injecting

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(NSLocalizedString("menubar.recent.label",
                                       value: "Últimos", comment: ""))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink2)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)

            if provider.recents.isEmpty {
                HStack {
                    Text(NSLocalizedString("menubar.recent.empty",
                                           value: "nenhum item ainda", comment: ""))
                        .font(.caption).foregroundStyle(DS.Color.ink3)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            } else {
                ForEach(provider.recents) { entry in
                    Button(action: { reinject(entry) }) {
                        HStack(spacing: 6) {
                            Text(displayApp(entry))
                                .font(DS.Font.mono(10))
                                .bold()
                                .foregroundStyle(DS.Color.ink2)
                            Text("·").foregroundStyle(DS.Color.ink3)
                            Text(entry.refinedText.prefix(50) +
                                  (entry.refinedText.count > 50 ? "…" : ""))
                                .font(.caption)
                                .foregroundStyle(DS.Color.ink3)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task { await provider.reload() }
    }

    private func displayApp(_ entry: Transcription) -> String {
        guard let bundleID = entry.frontmostAppBundleID else { return "—" }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return bundleID
    }

    private func reinject(_ entry: Transcription) {
        Task { try? await injector.inject(text: entry.refinedText) }
    }
}
