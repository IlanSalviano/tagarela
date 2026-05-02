import SwiftUI

struct AboutView: View {
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
                    Button(action: openLogsInConsole) {
                        Text(String(localized: "about.logs.open",
                                     defaultValue: "Abrir logs no Console"))
                            .font(DS.Font.mono(11))
                            .foregroundStyle(DS.Color.paper)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    Text(String(localized: "about.logs.help",
                                 defaultValue: "Filtre por subsystem == com.tagarela na barra de busca."))
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.ink3)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func openLogsInConsole() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Console.app", "--args",
                          "--predicate", "subsystem == 'com.tagarela'"]
        try? task.run()
    }
}
