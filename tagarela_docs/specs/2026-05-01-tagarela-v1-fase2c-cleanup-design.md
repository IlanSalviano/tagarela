---
data: 2026-05-01
fase: 2c-cleanup
status: parcialmente implementado (2 de 4 itens — Itens 1 e 4 revertidos em runtime)
predecessor: ../04-decisoes/cleanup-fase1.md, ../04-decisoes/cleanup-fase2b3.md
---

> **Status real (2026-05-01):**
> - **Item 1 (refactor `FloatingIndicatorPanel` → ViewModel):** ❌ implementado, revertido. Build verde + 160 testes verde + spec/code review aprovaram, mas regressão runtime detectada no aceite manual (pílula não transita pra `.refining`, texto não injeta). Commits `15b4630`, `1d90915`, `ba25fd9` revertidos. Cleanups #8 da Fase 1 e #1 da 2b-3 seguem abertos.
> - **Item 2 (cleanup #3 fechado retroativo):** ✅ atualizado em `cleanup-fase1.md`.
> - **Item 3 (validação L/R Option):** ✅ Bloco E passou; TODO removido em `HotkeyServiceLive.swift:99`, commit `51c0d00`. Cleanup #1 fechado.
> - **Item 4 (WhisperKit `downloadBase`):** ❌ implementado, revertido. Build verde + 160 testes verde + spec/code review aprovaram, mas no aceite (Bloco D) o diretório foi criado vazio e o download não rolou (mesma sintomatologia do Item 1). Commit `37a9552` revertido em `d4ff1e7`. Cleanup #9 segue aberto.
>
> **Lição:** spec compliance + code review sem aceite runtime ANTES do merge não cobre regressão funcional. Próximas sessões com refactor de UI ou IO devem fazer aceite manual em build local **entre** o commit e o merge, não depois.


# Fase 2c-cleanup — design

Bundle de cleanups acionáveis pós-Fase 2b. Não é uma "fase de feature" — é manutenção. Agrupada porque os itens compartilham contexto e cabem em uma sessão curta.

## Escopo

| Item | Origem | Critério de aceite |
|---|---|---|
| 1. Refatoração `FloatingIndicatorPanel` → ViewModel | [`cleanup-fase1.md` #8](../04-decisoes/cleanup-fase1.md) + [`cleanup-fase2b3.md` #1](../04-decisoes/cleanup-fase2b3.md) | `NSHostingController` instanciado 1× por vida do panel; flicker no Esc rápido sumido. |
| 2. Marcar `cleanup-fase1.md` #3 (stderr → Logger) como ✅ | doc desatualizado vs código | Header e item ajustados; data de fechamento registrada. |
| 3. Validar L/R Option empiricamente | [`cleanup-fase1.md` #1](../04-decisoes/cleanup-fase1.md) | Aceite manual: 0 hits de `keyCode=61` no Console.app filtrado por `com.tagarela` ao apertar L Option. |
| 4. WhisperKit `downloadBase` | [`cleanup-fase1.md` #9](../04-decisoes/cleanup-fase1.md) | Cold start fresh baixa pra `Application Support`; `kTCCServiceSystemPolicyDocumentsFolder` não dispara. |

Fora de escopo: itens #2, #5, #6, #7 da Fase 1 (bloqueados por validação manual longa, hardware ou Fase 3).

---

## Item 1 — `FloatingIndicatorPanel` em torno de `IndicatorViewModel`

### Problema

`PipelineCoordinator` ticka `audioLevel` a cada 80ms durante recording. Cada tick muda `PipelineState.recording(elapsedSeconds:audioLevel:)`, propaga via `events → AppState.pipeline → AppContainer.refreshIndicator → indicatorPanel.show(...)`. Hoje [`FloatingIndicatorPanel.show()`](../../app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift) faz:

```swift
let host = NSHostingController(rootView: root)
host.view.layer?.backgroundColor = .clear
panel?.contentViewController = host
```

Em **toda chamada**. Resultado: ~12 lifecycles de `NSHostingController` por segundo enquanto grava. Em transições rápidas (`.refining → .idle` em <100ms via cancel agressivo da 2b-3) o swap de hostingController é visualmente percebido como flicker.

### Solução

Indireção via `IndicatorViewModel: ObservableObject`. Hosting controller criado uma vez quando o panel é setado; updates passam por `@Published`.

#### Novos arquivos

**`app/Tagarela/UI/Indicator/IndicatorViewModel.swift`** (novo):

```swift
@MainActor
final class IndicatorViewModel: ObservableObject {
    @Published var state: PipelineState = .idle
    @Published var variant: IndicatorVariant = .pill
    @Published var toast: Toast? = nil

    var onCancel: () -> Void = {}
    var onToastDismiss: () -> Void = {}
}
```

`onCancel` e `onToastDismiss` ficam como `var` simples (não `@Published`): SwiftUI lê o valor mais recente no momento do click; observers não precisam reagir a mudança de closure.

**`app/Tagarela/UI/Indicator/IndicatorRootView.swift`** (novo):

```swift
struct IndicatorRootView: View {
    @ObservedObject var viewModel: IndicatorViewModel

    var body: some View {
        VStack(spacing: 8) {
            if let toast = viewModel.toast {
                ToastView(kind: toast.kind, onDismiss: { viewModel.onToastDismiss() })
            }
            FloatingIndicatorPanel.indicator(
                for: viewModel.variant,
                state: viewModel.state,
                onCancel: { viewModel.onCancel() }
            )
        }
    }
}
```

`indicator(for:state:onCancel:)` segue como helper estático em `FloatingIndicatorPanel` (assinatura inalterada). `IndicatorRootView` chama o vm pelos closures pra que mudanças de callback após o `show` valham sem rebuild.

#### `FloatingIndicatorPanel` (refactor)

```swift
@MainActor
final class FloatingIndicatorPanel {
    private var panel: NSPanel?
    private let viewModel = IndicatorViewModel()
    private var previewTask: Task<Void, Never>?

    func show(state:, variant:, toast:, onCancel:, onToastDismiss:) {
        previewTask?.cancel()
        previewTask = nil
        ensurePanel()
        viewModel.onCancel = onCancel
        viewModel.onToastDismiss = onToastDismiss
        viewModel.state = state
        viewModel.variant = variant
        viewModel.toast = toast
        positionNearCursor()
        panel?.orderFrontRegardless()
    }

    func hide() {
        previewTask?.cancel()
        previewTask = nil
        panel?.orderOut(nil)
    }

    func showPreview(variant:, state:, durationSec:) {
        ensurePanel()
        previewTask?.cancel()
        viewModel.onCancel = {}
        viewModel.onToastDismiss = {}
        viewModel.state = state
        viewModel.variant = variant
        viewModel.toast = nil
        positionCenterScreen()
        panel?.orderFrontRegardless()
        previewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(durationSec * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.hide()
        }
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let p = NSPanel(...)  // mesma config de hoje
        let host = NSHostingController(rootView: IndicatorRootView(viewModel: viewModel))
        host.view.layer?.backgroundColor = .clear
        p.contentViewController = host
        self.panel = p
    }
}
```

#### Por que vm compartilhado entre live e preview

`showPreview` é cold path (user clica "Visualizar" em Preferences quando não está ditando). Se hotkey dispara durante preview, o `show(...)` chamado por `refreshIndicator` cancela `previewTask` e sobrescreve vm — comportamento idêntico ao atual. Sem flag `isPreview`, sem vm secundário.

### Testes

- **Novo:** `IndicatorViewModelTests.swift` — verifica que mudanças em `state/variant/toast` disparam `objectWillChange` (1 teste por @Published) + closures `onCancel/onToastDismiss` são invocáveis e mutáveis.
- **Manual:** seção do aceite cobrindo o flicker — Bloco "Esc rápido após `.refining`" repetido 5×, esperado: pill some limpo.
- **Manual:** medir `NSHostingController` lifecycle via Instruments durante 30s de gravação. Aceite: 1 instância pra todo o ciclo.

---

## Item 2 — Atualizar `cleanup-fase1.md` #3

`grep FileHandle.standardError` em `app/Tagarela/` retorna vazio. Migração pra `Logger(subsystem: "com.tagarela")` aconteceu (provavelmente durante 2b-1 quando logs ganharam Logger, conforme item #4 dos achados da 2a). Doc apenas marcando ✅ retroativo, sem mudança de código.

Edição:
- Header `status: parcial` → `status: ✅ fechado em 2026-05-01`.
- Nota inline na seção #3: "Verificado em 2026-05-01: zero ocorrências de `FileHandle.standardError.write` no source."

---

## Item 3 — L/R Option (validação manual)

Hipótese de cleanup-fase1.md #1: filtro por `keyCode == 0x3D` em `flagsChanged` já é equivalente a "só Right Option" no macOS atual.

### Procedimento

1. Build release-ish (`Cmd+R` no Xcode ou `xcodebuild build`).
2. Tu abres `Console.app`, filtra por `subsystem == "com.tagarela"` + categoria `Hotkey`.
3. Apertas **Left Option** 10× lentamente.
4. Apertas **Right Option** 10× lentamente.

### Aceite

- **Esperado:** logs de `flagsChanged keyCode=61` aparecem só no passo 4. Zero no passo 3.
- Se confirmado: marcar `cleanup-fase1.md` #1 como ✅ + nota "validado empiricamente em 2026-05-01, sem código novo".
- Se Right Option no passo 3 disparar: distinguir bits via `event.modifierFlags.rawValue & NX_DEVICERCTLKEYMASK` (ou equivalente). Vira sub-tarefa.

---

## Item 4 — WhisperKit `downloadBase`

### Mudança

[`WhisperKitTranscriber.swift`](../../app/Tagarela/Transcription/WhisperKitTranscriber.swift) — onde hoje cria `WhisperKitConfig` (ou equivalente), setar `downloadBase` pra:

```swift
FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    .first!.appendingPathComponent("com.tagarela.Tagarela/Models", isDirectory: true)
```

Garantir que diretório existe via `createDirectory(at:withIntermediateDirectories: true)` antes de iniciar download.

### Validação

1. Backup ou delete de `~/Documents/huggingface/` (se ainda houver).
2. Cold start tagarela com modelo não-baixado.
3. Conferir que download foi pra `~/Library/Application Support/com.tagarela.Tagarela/Models/`.
4. Conferir em System Settings → Privacy & Security → Files and Folders que `kTCCServiceSystemPolicyDocumentsFolder` não está listado pra Tagarela (ou que o popup não dispara).

### Risco

Se WhisperKit hardcoda parte do path interno, `downloadBase` pode não bater com onde ele procura. Smoke test: confirmar que `WhisperKit.init(model:downloadBase:)` (ou equivalente) **lê** do mesmo path em runtime.

---

## Plano de execução (ordem)

1. **Item 1** primeiro — maior superfície, é o mais arriscado, libera o aceite manual do flicker.
2. **Item 2** — edição de doc só. 5 min.
3. **Item 4** — código pequeno, mas precisa cold start fresh pra validar.
4. **Item 3** — sessão de validação manual no fim, com tu apertando teclas.

Cada item gera commit separado. Suíte verde entre commits (`xcodebuild test`).

## Riscos & rollback

- **Item 1:** se SwiftUI re-render via `@Published` causar quebra visual em alguma variant que depende de re-criação (improvável, mas todos os 4 indicators são SwiftUI puros), rollback é git revert do refactor isolado.
- **Item 4:** se WhisperKit não respeitar `downloadBase` da forma esperada, rollback simples: remover override.
- **Itens 2 e 3:** sem código, sem risco.

## Doc updates pós-execução

- [`cleanup-fase1.md`](../04-decisoes/cleanup-fase1.md) — itens #1, #3, #8, #9 ✅.
- [`cleanup-fase2b3.md`](../04-decisoes/cleanup-fase2b3.md) — item #1 ✅.
- [`README.md`](../README.md) — entrada nova: `2026-05-01-tagarela-v1-fase2c-cleanup-design.md` + plan correspondente.
- ADR? Não. Nenhuma decisão de arquitetura nova; apenas execução de critérios já documentados.
