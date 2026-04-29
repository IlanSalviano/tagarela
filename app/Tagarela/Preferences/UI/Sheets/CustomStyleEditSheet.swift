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
                    .frame(minHeight: 160)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
                Toggle(String(localized: "styles.edit.codeswitch",
                               defaultValue: "Anexar cláusula de code-switching"),
                       isOn: $appendCodeSwitching)
            }
            if let err = saveError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            HStack {
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancelar")) { onClose() }
                Button(String(localized: "common.save", defaultValue: "Salvar")) { Task { await save() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || systemPrompt.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 420)
        .onAppear { populate() }
    }

    private var titleLabel: String {
        switch mode {
        case .create: return String(localized: "styles.edit.title.create", defaultValue: "Novo estilo custom")
        case .edit:   return String(localized: "styles.edit.title.edit", defaultValue: "Editar estilo")
        }
    }

    private func populate() {
        if case .edit(let s) = mode {
            name = s.name
            systemPrompt = s.systemPrompt
            appendCodeSwitching = s.appendCodeSwitching
        }
    }

    private func save() async {
        do {
            switch mode {
            case .create:
                _ = try await customStore.create(name: name,
                                                  systemPrompt: systemPrompt,
                                                  appendCodeSwitching: appendCodeSwitching)
            case .edit(let s):
                s.name = name
                s.systemPrompt = systemPrompt
                s.appendCodeSwitching = appendCodeSwitching
                try await customStore.update(s)
            }
            onClose()
        } catch {
            saveError = String(localized: "styles.edit.save.failed",
                                defaultValue: "Não foi possível salvar: ") + String(describing: error)
        }
    }
}
