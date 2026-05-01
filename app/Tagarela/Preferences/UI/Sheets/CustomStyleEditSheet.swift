import SwiftUI

@MainActor
struct CustomStyleEditSheet: View {
    enum Mode { case create, edit(CustomStyle) }
    let mode: Mode
    let customStore: CustomStyleStore
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var systemPrompt: String = ""
    @State private var appendCodeSwitching: Bool = true
    @State private var bypassDiscipline: Bool = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleLabel).font(.title2).bold()
            Form {
                LabeledContent(String(localized: "styles.edit.name", defaultValue: "Nome")) {
                    TextField("", text: $name).textFieldStyle(.roundedBorder)
                }
                Text(String(localized: "styles.edit.prompt", defaultValue: "System prompt")).font(.caption)
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 140)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
                Toggle(String(localized: "styles.edit.codeswitch",
                               defaultValue: "Anexar cláusula de code-switching"),
                       isOn: $appendCodeSwitching)
                Toggle(String(localized: "styles.edit.discipline.toggle",
                               defaultValue: "Modo refinador (recomendado)"),
                       isOn: Binding(get: { !bypassDiscipline },
                                     set: { bypassDiscipline = !$0 }))
                Text(String(localized: "styles.edit.discipline.help",
                            defaultValue: "Refinador prefixa proteção contra o LLM responder à fala em vez de transcrever."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if bypassDiscipline {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(String(localized: "styles.edit.discipline.warning",
                                    defaultValue: "Modo livre: sem proteção. O LLM pode responder à fala em vez de transcrever."))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            if let err = saveError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            HStack {
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancelar")) { onClose() }
                Button(String(localized: "common.save", defaultValue: "Salvar")) { Task { await save() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty || trimmedPrompt.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 460)
        .onAppear { populate() }
    }

    private var titleLabel: String {
        switch mode {
        case .create: return String(localized: "styles.edit.title.create", defaultValue: "Novo estilo custom")
        case .edit:   return String(localized: "styles.edit.title.edit", defaultValue: "Editar estilo")
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var trimmedPrompt: String {
        systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func populate() {
        if case .edit(let s) = mode {
            name = s.name
            systemPrompt = s.systemPrompt
            appendCodeSwitching = s.appendCodeSwitching
            bypassDiscipline = s.bypassDiscipline
        }
    }

    private func save() async {
        do {
            switch mode {
            case .create:
                _ = try await customStore.create(name: trimmedName,
                                                  systemPrompt: trimmedPrompt,
                                                  appendCodeSwitching: appendCodeSwitching,
                                                  bypassDiscipline: bypassDiscipline)
            case .edit(let s):
                // Trim antes de mutar — store.update não revalida (only create faz).
                // Mantém edit consistente com create: whitespace-only não passa.
                s.name = trimmedName
                s.systemPrompt = trimmedPrompt
                s.appendCodeSwitching = appendCodeSwitching
                s.bypassDiscipline = bypassDiscipline
                try await customStore.update(s)
            }
            onClose()
        } catch {
            saveError = String(localized: "styles.edit.save.failed",
                                defaultValue: "Não foi possível salvar: ") + String(describing: error)
        }
    }
}
