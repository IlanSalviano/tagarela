# Fase 2c-cleanup Implementation Plan

> **Status pós-execução (2026-05-01):** plano executado parcialmente. Ver design doc ([`2026-05-01-tagarela-v1-fase2c-cleanup-design.md`](./2026-05-01-tagarela-v1-fase2c-cleanup-design.md)) pro status real de cada item. Tasks 1, 2, 3 (refactor) e Task 5 (downloadBase) foram revertidas após regressão runtime detectada no aceite manual. Tasks 4 (checklist), 6 (L/R Option), 7 (cleanup docs) e 8 (snapshot) entregues. Esta seção do plano permanece como histórico do que foi tentado, mas **não reflete o estado final da branch**.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fechar 5 itens de cleanup pendentes pós-Fase 2b: refatoração `FloatingIndicatorPanel` → `IndicatorViewModel` (root cause comum do flicker da 2b-3 e do `NSHostingController` recriado da Fase 1), atualização retroativa do cleanup #3 da Fase 1, validação manual L/R Option e WhisperKit `downloadBase`.

**Architecture:** Indireção via `ObservableObject` no panel flutuante: `NSHostingController` instanciado uma vez, updates de estado fluem por `@Published` no `IndicatorViewModel`. Sem mudanças nos `IndicatorPill/Orb/Vertical/HUD` (assinaturas mantidas). WhisperKit ganha override de `downloadBase` apontando pra `Application Support`. Validações manuais (L/R Option e flicker) entram como passos finais com critérios objetivos.

**Tech Stack:** Swift 5/6, SwiftUI, AppKit (`NSPanel`, `NSHostingController`), `Combine` (`ObservableObject`/`@Published`), `WhisperKit` (download base), Swift Testing (XCTest).

**Spec:** [`2026-05-01-tagarela-v1-fase2c-cleanup-design.md`](./2026-05-01-tagarela-v1-fase2c-cleanup-design.md)

**Branch:** Trabalhar em `fase-2c-cleanup` cortado de `main`. Ao final, merge fast-forward.

---

## File map

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `app/Tagarela/UI/Indicator/IndicatorViewModel.swift` | criar | `ObservableObject` com `@Published` state/variant/toast + closures `onCancel`/`onToastDismiss` |
| `app/Tagarela/UI/Indicator/IndicatorRootView.swift` | criar | `View` que observa o vm e monta toast + indicator |
| `app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift` | refatorar | Hosting controller criado 1× em `ensurePanel()`; `show`/`showPreview` apenas mutam vm |
| `app/TagarelaTests/IndicatorViewModelTests.swift` | criar | Verifica `objectWillChange` em mudanças de state/variant/toast |
| `app/Tagarela/Transcription/WhisperKitTranscriber.swift` | modificar | `WhisperKit.download(variant:downloadBase:...)` aponta pra `Application Support/com.tagarela.Tagarela/Models` |
| `app/TagarelaTests/WhisperKitTranscriberTests.swift` | criar (se não existir) ou modificar | Teste do helper de URL (não toca rede) |
| `tagarela_docs/04-decisoes/cleanup-fase1.md` | editar | Marcar itens #1, #3, #8, #9 como ✅ |
| `tagarela_docs/04-decisoes/cleanup-fase2b3.md` | editar | Marcar item #1 como ✅ |
| `tagarela_docs/02-arquitetura/06-modulos-fase2c-cleanup.md` | criar | Snapshot pós-cleanup |
| `tagarela_docs/03-funcionalidades/checklists/fase2c-cleanup-manual.md` | criar | Aceite manual (flicker + L/R Option + downloadBase) |
| `tagarela_docs/README.md` | editar | Indexar design, plan e snapshot novos |

---

## Task 1: IndicatorViewModel

**Files:**
- Create: `app/Tagarela/UI/Indicator/IndicatorViewModel.swift`
- Create: `app/TagarelaTests/IndicatorViewModelTests.swift`

- [ ] **Step 1.1: Write failing test**

Escrever `app/TagarelaTests/IndicatorViewModelTests.swift`:

```swift
import XCTest
import Combine
@testable import Tagarela

@MainActor
final class IndicatorViewModelTests: XCTestCase {
    func test_publishesOnStateChange() {
        let vm = IndicatorViewModel()
        let exp = expectation(description: "objectWillChange fires on state mutation")
        let cancellable = vm.objectWillChange.sink { exp.fulfill() }
        vm.state = .recording(elapsedSeconds: 1, audioLevel: 0.5)
        wait(for: [exp], timeout: 0.1)
        cancellable.cancel()
    }

    func test_publishesOnVariantChange() {
        let vm = IndicatorViewModel()
        let exp = expectation(description: "objectWillChange fires on variant mutation")
        let cancellable = vm.objectWillChange.sink { exp.fulfill() }
        vm.variant = .orb
        wait(for: [exp], timeout: 0.1)
        cancellable.cancel()
    }

    func test_publishesOnToastChange() {
        let vm = IndicatorViewModel()
        let exp = expectation(description: "objectWillChange fires on toast mutation")
        let cancellable = vm.objectWillChange.sink { exp.fulfill() }
        vm.toast = Toast(kind: .refinerFellBack(reason: .networkOffline))
        wait(for: [exp], timeout: 0.1)
        cancellable.cancel()
    }

    func test_callbacksAreMutableAndInvocable() {
        let vm = IndicatorViewModel()
        var cancelCount = 0
        var dismissCount = 0
        vm.onCancel = { cancelCount += 1 }
        vm.onToastDismiss = { dismissCount += 1 }
        vm.onCancel()
        vm.onToastDismiss()
        XCTAssertEqual(cancelCount, 1)
        XCTAssertEqual(dismissCount, 1)
    }

    func test_defaultsAreIdleAndPill() {
        let vm = IndicatorViewModel()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.variant, .pill)
        XCTAssertNil(vm.toast)
    }
}
```

> **Nota sobre `ToastKind.refinerFellBack(reason:)`:** verificar a assinatura real lendo [`app/Tagarela/UI/Toast/ToastKind.swift`](../../app/Tagarela/UI/Toast/ToastKind.swift) antes de escrever o teste. Se o caso for diferente (ex: `.refinerFellBack(reason: .networkOffline)` vs outro construtor), ajustar o argumento. Critério: o teste só valida que `objectWillChange` dispara — qualquer `ToastKind` válido serve.

- [ ] **Step 1.2: Run failing test**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test -only-testing:TagarelaTests/IndicatorViewModelTests 2>&1 | tail -30
```

Esperado: falha de compilação (`IndicatorViewModel` não existe).

- [ ] **Step 1.3: Implement IndicatorViewModel**

Criar `app/Tagarela/UI/Indicator/IndicatorViewModel.swift`:

```swift
import Combine
import Foundation

/// State container do `FloatingIndicatorPanel`. Permite que o
/// `NSHostingController` seja instanciado uma única vez por vida do panel:
/// updates de estado fluem por `@Published`, SwiftUI re-renderiza in-place
/// sem reciclagem de host.
@MainActor
final class IndicatorViewModel: ObservableObject {
    @Published var state: PipelineState = .idle
    @Published var variant: IndicatorVariant = .pill
    @Published var toast: Toast? = nil

    /// Callbacks são `var` (não `@Published`) — SwiftUI lê o valor mais
    /// recente no momento do click; observers não precisam reagir a swap
    /// de closure.
    var onCancel: () -> Void = {}
    var onToastDismiss: () -> Void = {}
}
```

- [ ] **Step 1.4: Add file to Xcode project**

Editar `project.yml` (xcodegen) ou validar que `app/Tagarela/UI/Indicator/` é coberto por glob existente. Rodar:

```bash
cd app && xcodegen generate
```

Esperado: `Tagarela.xcodeproj` regenerado, `IndicatorViewModel.swift` incluído no target.

- [ ] **Step 1.5: Run tests — expect pass**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test -only-testing:TagarelaTests/IndicatorViewModelTests 2>&1 | tail -15
```

Esperado: 5 testes passam.

- [ ] **Step 1.6: Commit**

```bash
git add app/Tagarela/UI/Indicator/IndicatorViewModel.swift \
        app/TagarelaTests/IndicatorViewModelTests.swift \
        app/Tagarela.xcodeproj
git commit -m "feat(indicator): IndicatorViewModel para state in-place updates

Prepara terreno pro refactor do FloatingIndicatorPanel — vm separa state
de presentation, permitindo NSHostingController instanciado 1× por vida
do panel.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: IndicatorRootView

**Files:**
- Create: `app/Tagarela/UI/Indicator/IndicatorRootView.swift`

> Sem teste unitário — é uma View pura sem lógica condicional além do switch que já é testado em `IndicatorVariantTests`. Cobertura via aceite manual + smoke build.

- [ ] **Step 2.1: Implement IndicatorRootView**

Criar `app/Tagarela/UI/Indicator/IndicatorRootView.swift`:

```swift
import SwiftUI

/// Raiz observada pelo `NSHostingController` único do `FloatingIndicatorPanel`.
/// Re-renderiza in-place quando o `IndicatorViewModel` muda — sem reciclagem
/// de host entre transições de estado.
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

- [ ] **Step 2.2: Regenerate Xcode project**

```bash
cd app && xcodegen generate
```

- [ ] **Step 2.3: Build only (smoke check)**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' build 2>&1 | tail -20
```

Esperado: BUILD SUCCEEDED. Type-check valida assinatura de `FloatingIndicatorPanel.indicator(...)` ainda existe.

- [ ] **Step 2.4: Commit**

```bash
git add app/Tagarela/UI/Indicator/IndicatorRootView.swift app/Tagarela.xcodeproj
git commit -m "feat(indicator): IndicatorRootView observa IndicatorViewModel

View raiz pro hostingController único — toast empilhado acima do indicator
da variant ativa, callbacks indireccionados via vm pra permitir hot-swap
de onCancel/onToastDismiss sem rebuild.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Refatorar FloatingIndicatorPanel

**Files:**
- Modify: `app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift`

- [ ] **Step 3.1: Replace FloatingIndicatorPanel implementation**

Substituir o conteúdo de `app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift`. O ponto-chave é que `ensurePanel()` agora monta o hostingController **uma vez** e ele dura toda a vida do panel:

```swift
import AppKit
import SwiftUI

@MainActor
final class FloatingIndicatorPanel {
    private var panel: NSPanel?
    /// Single source of truth pro hostingController. Atualizar via @Published
    /// no vm — não recriar.
    private let viewModel = IndicatorViewModel()
    /// Task pra preview com auto-hide após N segundos.
    private var previewTask: Task<Void, Never>?

    /// Mostra (ou atualiza) panel com indicator da `variant` correspondente
    /// + toast opcional empilhado acima.
    func show(state: PipelineState,
              variant: IndicatorVariant,
              toast: Toast?,
              onCancel: @escaping () -> Void,
              onToastDismiss: @escaping () -> Void) {
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

    /// Mostra a `variant` em estado fake por `durationSec` segundos. Usado
    /// pelo botão "Visualizar selecionado" no IndicatorPicker. Auto-hide.
    /// Compartilha vm com `show(...)` — preview é cold path; se hotkey
    /// dispara durante preview, `show` cancela `previewTask` e sobrescreve
    /// vm, comportamento idêntico ao pré-refactor.
    func showPreview(variant: IndicatorVariant,
                     state: PipelineState,
                     durationSec: Double) {
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
        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.backgroundColor = .clear
        p.hasShadow = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let host = NSHostingController(rootView: IndicatorRootView(viewModel: viewModel))
        host.view.layer?.backgroundColor = .clear
        p.contentViewController = host
        self.panel = p
    }

    private func positionNearCursor() {
        guard let p = panel else { return }
        let cursor = NSEvent.mouseLocation
        let frame = NSRect(x: cursor.x - 110,
                           y: cursor.y - 80,
                           width: p.frame.width,
                           height: p.frame.height)
        p.setFrame(frame, display: true)
    }

    private func positionCenterScreen() {
        guard let p = panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let frame = NSRect(x: visible.midX - p.frame.width / 2,
                           y: visible.midY - p.frame.height / 2,
                           width: p.frame.width,
                           height: p.frame.height)
        p.setFrame(frame, display: true)
    }

    @ViewBuilder
    static func indicator(for variant: IndicatorVariant,
                          state: PipelineState,
                          onCancel: @escaping () -> Void) -> some View {
        switch variant {
        case .pill:     IndicatorPill(state: state, onCancel: onCancel)
        case .orb:      IndicatorOrb(state: state, onCancel: onCancel)
        case .vertical: IndicatorVertical(state: state, onCancel: onCancel)
        case .hud:      IndicatorHUD(state: state, onCancel: onCancel)
        }
    }
}
```

- [ ] **Step 3.2: Build to type-check**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' build 2>&1 | tail -20
```

Esperado: BUILD SUCCEEDED. Se algum call site tinha state baseado em `host` exposto, vai quebrar — corrigir.

- [ ] **Step 3.3: Run full test suite — regression check**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -25
```

Esperado: 155+5 = 160 testes passam (155 atuais + 5 novos da Task 1).

- [ ] **Step 3.4: Commit**

```bash
git add app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift
git commit -m "refactor(indicator): hostingController instanciado 1× por vida do panel

show()/showPreview() apenas mutam o IndicatorViewModel; SwiftUI
re-renderiza in-place via @Published. Fecha cleanup #8 da Fase 1
(NSHostingController recriado a cada level update durante recording)
e cleanup #1 da Fase 2b-3 (pill flicker no Esc rápido após .refining)
— ambos compartilham mesmo root cause.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Aceite manual do flicker (Item 1 do design)

**Files:**
- Create: `tagarela_docs/03-funcionalidades/checklists/fase2c-cleanup-manual.md`

- [ ] **Step 4.1: Build & launch app**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' build 2>&1 | tail -5
open ~/Applications/Tagarela.app
```

> Se o build sair pra DerivedData ao invés de `~/Applications/Tagarela.app`, copiar manualmente ou ajustar scheme. Padrão do user é instalar em `~/Applications/`.

- [ ] **Step 4.2: Criar checklist manual**

Escrever `tagarela_docs/03-funcionalidades/checklists/fase2c-cleanup-manual.md` com a seção do flicker:

```markdown
---
data: 2026-05-01
fase: 2c-cleanup
status: aberto
---

# Fase 2c-cleanup — aceite manual

## Bloco A — Pill flicker no Esc rápido

**Pré-requisito:** indicator variant = `pill`, refiner ativo (Ollama ou OpenAI), texto suficiente pra entrar em `.refining` (>= 9 chars no raw).

1. Hotkey ON → falar 2-3s → hotkey OFF.
2. Pill vira amarelo (`.refining`).
3. Em < 100ms, apertar Esc.
4. **Esperado:** pill some imediatamente, **sem flicker visível** (sem reaparecer-sumir).
5. Repetir 5×. Critério de aceite: 5/5 sem flicker.

## Bloco B — Recording de 30s — hostingController não-recicla

**Pré-requisito:** Instruments aberto com Allocations apontando pra processo `Tagarela`.

1. Filtrar por `NSHostingController` na timeline.
2. Hotkey ON, falar/segurar por 30s, hotkey OFF (deixar pipeline completar).
3. **Esperado:** instâncias vivas de `NSHostingController` no fim ≤ 1 nova durante o ciclo (panel + outras telas que não são alvo).
4. Comparar com baseline pré-refactor: hoje 30s × 12Hz ≈ 360 instâncias criadas.

## Bloco C — Preview no IndicatorPicker funciona

1. Abrir Preferências → Indicador.
2. Selecionar uma variant ≠ atual.
3. Clicar "Visualizar selecionado".
4. **Esperado:** indicator aparece no centro da tela com state fake; auto-hide após N segundos.
5. Repetir trocando entre as 4 variants.
```

- [ ] **Step 4.3: Conduzir aceite Bloco A com user**

User executa o procedimento; eu observo logs do `Console.app` ou screen recording. Marcar pass/fail no checklist.

- [ ] **Step 4.4: Bloco B — Instruments**

Opcional (se user tiver tempo / quiser instrumentar). Senão: skip com nota "Bloco B não-instrumentado, validado por inspeção visual + leitura do código (`ensurePanel` chamado uma vez)."

- [ ] **Step 4.5: Bloco C — preview**

User executa, eu confirmo no checklist.

- [ ] **Step 4.6: Commit checklist**

```bash
git add tagarela_docs/03-funcionalidades/checklists/fase2c-cleanup-manual.md
git commit -m "docs: checklist de aceite manual da Fase 2c-cleanup

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: WhisperKit downloadBase

**Files:**
- Modify: `app/Tagarela/Transcription/WhisperKitTranscriber.swift`

- [ ] **Step 5.1: Adicionar helper de URL + injetar em `download()`**

Editar [`app/Tagarela/Transcription/WhisperKitTranscriber.swift`](../../app/Tagarela/Transcription/WhisperKitTranscriber.swift). Substituir `loadModel(...)`:

```swift
func loadModel(_ name: String,
               onProgress: @escaping (Double) -> Void) async throws {
    do {
        let downloadBase = try Self.modelDownloadBase()
        let modelFolder = try await WhisperKit.download(
            variant: name,
            downloadBase: downloadBase
        ) { progress in
            onProgress(progress.fractionCompleted)
        }
        let config = WhisperKitConfig(modelFolder: modelFolder.path, load: true)
        let pipe = try await WhisperKit(config)
        self.pipe = pipe
        self.loadedModelName = name
        logger.info("loaded whisper model: \(name, privacy: .public) from \(modelFolder.path, privacy: .public)")
    } catch {
        throw TranscribeError.modelDownloadFailed(String(describing: error))
    }
}

/// Diretório base pros modelos baixados pelo WhisperKit. Aponta pra
/// `~/Library/Application Support/com.tagarela.Tagarela/Models/` em vez
/// do default (`~/Documents/huggingface/...`), evitando que macOS
/// dispare o popup de "Documents folder access" pra Tagarela.
static func modelDownloadBase() throws -> URL {
    let appSupport = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask, appropriateFor: nil, create: true)
    let dir = appSupport
        .appendingPathComponent("com.tagarela.Tagarela", isDirectory: true)
        .appendingPathComponent("Models", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}
```

- [ ] **Step 5.2: Build & test**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -15
```

Esperado: 160 testes passam (sem mudança no count — não estamos adicionando teste de URL helper porque hit em `FileManager` real bate em `~/Library`; smoke test pelo build basta).

- [ ] **Step 5.3: Aceite manual — cold start fresh**

Adicionar bloco ao `fase2c-cleanup-manual.md`:

```markdown
## Bloco D — WhisperKit downloadBase

**Atenção:** este bloco é destrutivo (apaga modelo baixado). Backup recomendado.

1. Confirmar localização atual: `ls ~/Documents/huggingface/ 2>/dev/null` e `ls ~/Library/Application\ Support/com.tagarela.Tagarela/Models/ 2>/dev/null`.
2. Apagar `~/Documents/huggingface/` (ou só renomear pra `huggingface.bak`).
3. Apagar `~/Library/Application\ Support/com.tagarela.Tagarela/Models/` se existir.
4. Cold start Tagarela → onboarding pede download do modelo.
5. Aguardar download completar.
6. **Esperado:** novo modelo em `~/Library/Application\ Support/com.tagarela.Tagarela/Models/`. Path antigo `~/Documents/huggingface/` não recriado.
7. Falar uma frase de teste — confirmar transcrição funciona.
8. **Esperado:** System Settings → Privacy → Files & Folders **não mostra** "Documents Folder" listado pra Tagarela (ou popup nativo não dispara).

Se popup `kTCCServiceSystemPolicyDocumentsFolder` aparecer mesmo assim:
- Verificar logs (`Console.app` filtrado por `subsystem == "com.tagarela"`) pra ver onde rola fileIO em `~/Documents`.
- Possível causa: WhisperKit faz cache adicional fora do `downloadBase`. Investigar.
```

- [ ] **Step 5.4: User executa Bloco D**

Em colaboração — user roda passos, eu confirmo paths nos comandos `ls`. Se sucesso: marcar ✅.

- [ ] **Step 5.5: Commit**

```bash
git add app/Tagarela/Transcription/WhisperKitTranscriber.swift \
        tagarela_docs/03-funcionalidades/checklists/fase2c-cleanup-manual.md
git commit -m "feat(transcribe): WhisperKit downloadBase em Application Support

Modelos baixados pra ~/Library/Application Support/com.tagarela.Tagarela/Models/
em vez de ~/Documents/huggingface/. Fecha cleanup #9 da Fase 1 — popup
de Documents folder não é mais disparado pra Tagarela.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Validação manual L/R Option

**Files:**
- Modify: `tagarela_docs/03-funcionalidades/checklists/fase2c-cleanup-manual.md`
- Modify: `app/Tagarela/Hotkey/HotkeyServiceLive.swift` (apenas se validação falhar)

- [ ] **Step 6.1: Adicionar bloco ao checklist**

Apendar em `fase2c-cleanup-manual.md`:

```markdown
## Bloco E — L/R Option distinguishing

**Pré-requisito:** Tagarela rodando (status bar visível). `Console.app` aberto, filtrado por `subsystem == "com.tagarela"` + categoria `Hotkey`.

1. Apertar **Left Option** 10× lentamente (1s entre presses).
2. Apertar **Right Option** 10× lentamente.

**Esperado:**
- Passo 1: zero linhas de `flagsChanged keyCode=61 (Right Option)` no Console.
- Passo 2: 10 linhas de `flagsChanged keyCode=61 (Right Option)` (toggle on/off — pode dobrar).

Critério de aceite: 0 hits no passo 1.

Se passo 1 também disparar: documentar caso, abrir sub-task pra distinguir bits via `event.flags.rawValue & NX_DEVICERCTLKEYMASK` em [`HotkeyServiceLive.swift:99`](../../../app/Tagarela/Hotkey/HotkeyServiceLive.swift#L99).
```

- [ ] **Step 6.2: User executa Bloco E**

User roda; eu observo Console pelo screen share / dump dos logs. Marcar resultado.

- [ ] **Step 6.3a (caminho feliz): Limpar TODO no código**

Se 0 hits no passo 1, editar [`app/Tagarela/Hotkey/HotkeyServiceLive.swift:99`](../../app/Tagarela/Hotkey/HotkeyServiceLive.swift#L99) — remover comentário TODO. Substituir:

```swift
// TODO Fase 2: distinguir L/R do Option olhando bits específicos do flag.
// Por enquanto, o filtro pelo keyCode (0x3D = Right Option) já restringe
// ao Option direito; .maskAlternate só serve pra ignorar o evento de
// release (quando flag é desligado).
```

Por:

```swift
// keyCode 0x3D (61) é exclusivo do Right Option no macOS — validado
// empiricamente em 2026-05-01. Left Option dispara keyCode diferente,
// que cai fora deste bloco. .maskAlternate ignora release events.
```

- [ ] **Step 6.3b (caminho infeliz): documentar e abrir sub-task**

Se Left Option também dispara keyCode=61, **não** mexer no código nesta fase. Apenas:
1. Atualizar `cleanup-fase1.md` #1 com nota "validação 2026-05-01: L Option também dispara keyCode=61, distinguir bits ainda necessário". Manter status aberto.
2. Não há código novo nesta sessão; sub-task fica pra próxima.

- [ ] **Step 6.4: Build & test (só se 6.3a)**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: 160 testes passam.

- [ ] **Step 6.5: Commit**

Caminho 6.3a:

```bash
git add app/Tagarela/Hotkey/HotkeyServiceLive.swift \
        tagarela_docs/03-funcionalidades/checklists/fase2c-cleanup-manual.md
git commit -m "chore(hotkey): TODO L/R Option fechado por validação empírica

Validado em 2026-05-01: keyCode=0x3D é exclusivo do Right Option no
macOS; Left Option não cai neste bloco. Comentário TODO substituído
por nota explicativa. Fecha cleanup #1 da Fase 1.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

Caminho 6.3b: commit só do checklist (sem mudança em código).

---

## Task 7: Atualizar docs de cleanup

**Files:**
- Modify: `tagarela_docs/04-decisoes/cleanup-fase1.md`
- Modify: `tagarela_docs/04-decisoes/cleanup-fase2b3.md`

- [ ] **Step 7.1: Editar `cleanup-fase1.md`**

Marcar como ✅ (data 2026-05-01):
- Item #1 (L/R Option) — pendente do resultado da Task 6.
- Item #3 (stderr → Logger) — confirmado retroativamente: `grep FileHandle.standardError` em `app/Tagarela/` retorna vazio. Adicionar nota "Verificado em 2026-05-01: zero ocorrências; migração pra `Logger(subsystem: "com.tagarela")` aconteceu durante Fase 2b-1 quando logs ganharam Logger por categoria."
- Item #8 (NSHostingController recriado) — fechado pela Task 3.
- Item #9 (Documents folder permission) — pendente do resultado do Bloco D.

- [ ] **Step 7.2: Editar `cleanup-fase2b3.md`**

Marcar Item #1 (pill flicker) como ✅, com data e referência ao commit do refactor (Task 3).

- [ ] **Step 7.3: Commit**

```bash
git add tagarela_docs/04-decisoes/cleanup-fase1.md \
        tagarela_docs/04-decisoes/cleanup-fase2b3.md
git commit -m "docs: fechamento dos cleanups #1, #3, #8, #9 da Fase 1 e #1 da 2b-3

Itens fechados pela Fase 2c-cleanup. Item #3 (stderr) já estava
fechado de fato — apenas registro retroativo. Itens #2, #5, #6, #7
seguem abertos (bloqueados por validação manual longa, hardware ou
Fase 3).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Snapshot arquitetural pós-cleanup + index do README

**Files:**
- Create: `tagarela_docs/02-arquitetura/06-modulos-fase2c-cleanup.md`
- Modify: `tagarela_docs/README.md`

- [ ] **Step 8.1: Criar snapshot**

Escrever `tagarela_docs/02-arquitetura/06-modulos-fase2c-cleanup.md`:

```markdown
---
data: 2026-05-01
fase: 2c-cleanup
status: implementado
---

# Snapshot pós-Fase 2c-cleanup

Não é uma fase de feature. Bundle de cleanups que tocaram código:

## Módulos novos
- [`app/Tagarela/UI/Indicator/IndicatorViewModel.swift`](../../app/Tagarela/UI/Indicator/IndicatorViewModel.swift) — `ObservableObject` com `@Published` state/variant/toast + closures `onCancel`/`onToastDismiss`.
- [`app/Tagarela/UI/Indicator/IndicatorRootView.swift`](../../app/Tagarela/UI/Indicator/IndicatorRootView.swift) — view raiz observada pelo `NSHostingController` único.

## Módulos modificados
- [`app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift`](../../app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift) — `ensurePanel()` instancia hosting controller 1× por vida do panel; `show`/`showPreview` apenas mutam vm.
- [`app/Tagarela/Transcription/WhisperKitTranscriber.swift`](../../app/Tagarela/Transcription/WhisperKitTranscriber.swift) — `WhisperKit.download(variant:downloadBase:...)` aponta pra Application Support; helper `modelDownloadBase()` cria diretório.
- [`app/Tagarela/Hotkey/HotkeyServiceLive.swift`](../../app/Tagarela/Hotkey/HotkeyServiceLive.swift) — TODO L/R Option substituído por nota de validação empírica (se Bloco E passou).

## Cleanups fechados
- Fase 1 #1 (L/R Option): validação empírica via Bloco E.
- Fase 1 #3 (stderr → Logger): retroativo, já fechado durante Fase 2b-1.
- Fase 1 #8 (NSHostingController recriado): refactor via IndicatorViewModel.
- Fase 1 #9 (Documents folder): downloadBase em Application Support.
- Fase 2b-3 #1 (pill flicker): mesmo refactor que #8.

## Cleanups Fase 1 ainda abertos
- #2 (`promptTokens` empírico A/B): bloqueado por coleta manual.
- #5 (`AVAudioConverter` streaming): bloqueado por hardware (testar em outro Mac/mic).
- #6 (TCC manual): bloqueado até Fase 3 (notarização).
- #7 (drift visual código vs bundle): inspeção manual demorada.

## Testes
- Suíte: 160 (155 pré + 5 novos do `IndicatorViewModelTests`).
```

- [ ] **Step 8.2: Editar `README.md`**

Adicionar entradas na seção 02 (snapshot) e em specs/. Atualizar nota dos cleanups.

- [ ] **Step 8.3: Commit**

```bash
git add tagarela_docs/02-arquitetura/06-modulos-fase2c-cleanup.md \
        tagarela_docs/README.md
git commit -m "docs: snapshot arquitetural pós-Fase 2c-cleanup + index README

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Merge para main

**Files:**
- Branch: `fase-2c-cleanup` → `main`

- [ ] **Step 9.1: Suíte completa final**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: 160 testes verdes.

- [ ] **Step 9.2: Confirmar com user antes do merge**

Pausa explícita: confirmar com user que aceite manual (Blocos A, B, C, D, E) está OK. Se algum bloco falhou, resolver antes de mergear.

- [ ] **Step 9.3: Merge fast-forward**

```bash
git checkout main
git merge --ff-only fase-2c-cleanup
git branch -d fase-2c-cleanup
```

Esperado: fast-forward limpo, sem merge commit.

- [ ] **Step 9.4: Verificar log**

```bash
git log --oneline -10
```

Esperado: ~8 commits novos no topo de main.

---

## Riscos & rollback

- **Task 3 (refactor):** se SwiftUI re-render via `@Published` causar quebra visual em alguma variant, rollback é `git revert` do commit isolado da Task 3.
- **Task 5 (downloadBase):** se WhisperKit não respeitar override, rollback simples: remover `downloadBase: downloadBase` do call.
- **Task 6 caminho 6.3b:** sem código novo; só doc. Sem risco.
- **Tasks 4, 7, 8:** docs only, zero risco.
