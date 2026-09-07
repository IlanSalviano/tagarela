import AppKit
import SwiftUI

struct AboutView: View {
    var health: PipelineHealth?
    var prefs: PreferencesStore?
    var loadedModelName: () -> String? = { nil }
    var modelDownloaded: () -> Bool? = { nil }

    @State private var exportedFolder: String?
    @State private var exportFailure: String?

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(String(localized: "preferences.section.about", defaultValue: "Sobre"))
                    .font(DS.Font.display(22))

                VStack(alignment: .leading, spacing: 4) {
                    Text("tagarela")
                        .font(DS.Font.display(28))
                        .foregroundStyle(DS.Color.ink)
                    Text(String(localized: "about.tagline",
                                 defaultValue: "ditado por voz local com pós-processamento por LLM"))
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.ink2)
                    Text(String(localized: "about.version",
                                 defaultValue: "Versão \(appVersion)"))
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.ink3)
                        .padding(.top, 4)
                }

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "about.author.header", defaultValue: "AUTOR"))
                        .font(DS.Font.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(DS.Color.ink3)
                    Text("Ilan Salviano")
                        .font(DS.Font.mono(13, weight: .medium))
                        .foregroundStyle(DS.Color.ink)
                    Link("ilan.salviano@gmail.com",
                         destination: URL(string: "mailto:ilan.salviano@gmail.com")!)
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.carmine)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "about.coauthor.header", defaultValue: "COAUTOR"))
                        .font(DS.Font.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(DS.Color.ink3)
                    Text("Claude (Anthropic)")
                        .font(DS.Font.mono(13, weight: .medium))
                        .foregroundStyle(DS.Color.ink)
                    Text(String(localized: "about.coauthor.note",
                                 defaultValue: "Implementação coautorada via Claude Code."))
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.ink2)
                }

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "about.logs.header", defaultValue: "LOGS"))
                        .font(DS.Font.mono(10))
                        .tracking(1.4)
                        .foregroundStyle(DS.Color.ink3)
                    HStack(spacing: 8) {
                        Button(action: openLogFile) {
                            Text(String(localized: "about.logs.open",
                                         defaultValue: "Abrir log do app"))
                                .font(DS.Font.mono(11))
                                .foregroundStyle(DS.Color.paper)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        Button(action: exportDiagnostics) {
                            Text(String(localized: "about.diagnostics.export",
                                         defaultValue: "Exportar diagnóstico…"))
                                .font(DS.Font.mono(11))
                                .foregroundStyle(DS.Color.paper)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(DS.Color.carmine, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    Text(String(localized: "about.logs.help",
                                 defaultValue: "O log fica em ~/Library/Logs/Tagarela/ e sobrevive a dias — o Console só guarda cerca de um dia."))
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.ink3)
                    if let exportedFolder {
                        Text(String(localized: "about.diagnostics.exported",
                                     defaultValue: "Salvo em \(exportedFolder)"))
                            .font(DS.Font.mono(10))
                            .foregroundStyle(DS.Color.moss)
                    }
                    if let exportFailure {
                        Text(String(localized: "about.diagnostics.failed",
                                     defaultValue: "Falhou: \(exportFailure)"))
                            .font(DS.Font.mono(10))
                            .foregroundStyle(DS.Color.carmine)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    /// Antes abria o Console filtrado por subsystem. Trocado pelo arquivo: a
    /// auditoria de 2026-09-07 mediu retenção de ~1,5 dia no log unificado, o
    /// que torna o Console inútil justamente para a falha que aparece depois de
    /// dias no ar.
    private func openLogFile() {
        let url = DiagnosticsLog.shared.fileURL(index: 0)
        if !FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([DiagnosticsLog.shared.directory])
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func exportDiagnostics() {
        exportedFolder = nil
        exportFailure = nil
        do {
            let folder = try DiagnosticsExporter.export(
                .init(health: health,
                      prefs: prefs,
                      loadedModelName: loadedModelName(),
                      modelDownloaded: modelDownloaded()))
            exportedFolder = folder.lastPathComponent
        } catch {
            exportFailure = String(describing: error)
        }
    }
}
