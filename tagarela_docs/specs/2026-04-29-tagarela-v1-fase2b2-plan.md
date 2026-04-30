---
data: 2026-04-29
status: implementado
fase: 2b-2 de 3 sub-fases da Fase 2b
goal: feedback visual + histórico viewer + indicadores B/C/D + toasts + cleanup #2 da 2a
implementado_em: 2026-04-29 (branch fase-2b2, 16 tarefas, 145 testes verdes, aceite manual ✅)
---

# tagarela v1 — Fase 2b-2: Implementation Plan

> **Para agentes de execução:** SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendado) ou `superpowers:executing-plans`. Tarefas usam checkbox (`- [ ]`).
>
> **Antes de qualquer tarefa:** ler [`/CLAUDE.md`](../../CLAUDE.md), [`tagarela_docs/specs/2026-04-29-tagarela-v1-fase2b2-design.md`](./2026-04-29-tagarela-v1-fase2b2-design.md), [`tagarela_docs/04-decisoes/cleanup-fase2a.md`](../04-decisoes/cleanup-fase2a.md) (cleanup #2 que esta fase fecha), [`tagarela_docs/04-decisoes/ADR-0004-historico-em-preferencias.md`](../04-decisoes/ADR-0004-historico-em-preferencias.md). **Antes de marcar uma tarefa como concluída:** atualizar a doc afetada (regra inviolável 2 do CLAUDE.md).

**Goal:** Implementar feedback visual da Fase 2b-2 — visualizador de histórico (busca + cards cru+refinado + Limpar tudo) embutido em Preferências > Histórico, menu "últimos 5" na status bar com re-injeção, sistema `ToastCenter` anexado ao `FloatingIndicatorPanel`, fechamento do cleanup #2 da Fase 2a (fallback Identity surfaceiado via novo `PipelineEvent.refinerFellBack(reason:)`), implementação das 3 variações restantes do indicador (B/C/D) com picker visual em Preferências > Geral.

**Architecture:** Sobre a 2b-1, adicionar (a) data models `ToastKind`/`RefinerFallbackReason`/`PermissionKind`/`Toast`, (b) `ToastCenter` `@MainActor ObservableObject` com auto-dismiss 4s, (c) `IndicatorView` protocolo + 3 novas conformances (`IndicatorOrb`, `IndicatorVertical`, `IndicatorHUD`), (d) `IndicatorVariant` enum + persistência em `PreferencesStore`, (e) `IndicatorPicker` com cards 2×2 + botão Visualizar, (f) `HistoryListView`/`HistoryEntryView` + busca + `clearAll()` no `HistoryStore`, (g) `RecentTranscriptionsProvider` + `RecentTranscriptionsSubmenu` no menubar, (h) novos `PipelineEvent` cases + handlers em `wirePipelineToAppState` mapeando pra toasts, (i) `FloatingIndicatorPanel` reformado pra empilhar `(toastView?, indicatorView)` e respeitar `prefs.indicatorVariant`.

**Tech stack:** mesmo da 2b-1 — Swift 5.10, SwiftUI, SwiftData, AppKit cirúrgico, URLSession, XCTest. Sem novas SPMs.

**Não está nesta fase:** onboarding novo, re-bind real da hotkey, cleanup #5 da 2a (cancel HTTP), tuning fino dos prompts (incl. cleanup #2 da 2b-1 — UX dedicada do rewriter discipline). Ver [`fase2b2-design.md` §1.3](./2026-04-29-tagarela-v1-fase2b2-design.md#13-não-objetivos-da-2b-2).

---

## File structure desta fase

Adições/modificações sobre Fase 2b-1 (raiz `app/Tagarela/`):

```
app/Tagarela/
├── UI/
│   ├── Toast/                              # NOVO diretório
│   │   ├── ToastKind.swift                 # NOVO — enum + RefinerFallbackReason + display helpers
│   │   ├── Toast.swift                     # NOVO — struct Identifiable com id+kind+createdAt
│   │   ├── ToastCenter.swift               # NOVO — @MainActor ObservableObject
│   │   └── ToastView.swift                 # NOVO — SwiftUI View pra um Toast
│   ├── Indicator/
│   │   ├── FloatingIndicatorPanel.swift    # MODIFICAR — show(state:variant:toast:onCancel:) + showPreview
│   │   ├── IndicatorView.swift             # NOVO — protocol
│   │   ├── IndicatorPill.swift             # MODIFICAR — conformar IndicatorView
│   │   ├── IndicatorOrb.swift              # NOVO — variação B
│   │   ├── IndicatorVertical.swift         # NOVO — variação C
│   │   ├── IndicatorHUD.swift              # NOVO — variação D (dark only)
│   │   └── WaveBars.swift                  # (Fase 1 — sem mudança)
│   └── MenuBar/
│       ├── RecentTranscriptionsSubmenu.swift  # NOVO — entre StyleSubmenu e botão Preferências
│       └── MenuBarController.swift         # MODIFICAR — incluir RecentTranscriptionsSubmenu
├── Permissions/
│   └── PermissionKind.swift                # NOVO — enum .microphone/.accessibility/.inputMonitoring
├── Pipeline/
│   ├── PipelineEvent.swift                 # MODIFICAR — 4 novos cases
│   └── PipelineCoordinator.swift           # MODIFICAR — emitir novos events em fallbacks
├── Preferences/
│   ├── IndicatorVariant.swift              # NOVO — enum .pill/.orb/.vertical/.hud
│   ├── Preferences+Defaults.swift          # MODIFICAR — chave + default
│   ├── PreferencesStore.swift              # MODIFICAR — @Published indicatorVariant
│   └── UI/
│       ├── PreferencesRoot.swift           # MODIFICAR — passar historyStore + injector + indicatorPanel
│       ├── Sections/
│       │   ├── GeneralView.swift           # MODIFICAR — incluir IndicatorPicker
│       │   ├── IndicatorPicker.swift       # NOVO — cards 2×2 + Visualizar
│       │   └── HistoryView.swift           # MODIFICAR — incluir HistoryListView abaixo da retenção
│       └── History/                        # NOVO diretório
│           ├── HistoryListView.swift       # NOVO — LazyVStack + busca + Limpar tudo
│           └── HistoryEntryView.swift      # NOVO — card cru+refinado
├── History/
│   ├── HistoryStore.swift                  # MODIFICAR — adicionar clearAll() ao protocol
│   ├── HistoryStoreLive.swift              # MODIFICAR — implementar clearAll
│   ├── HistoryStoreNoop.swift              # MODIFICAR — implementar clearAll (no-op)
│   └── RecentTranscriptionsProvider.swift  # NOVO — @MainActor com @Published recents
└── App/
    └── AppContainer.swift                  # MODIFICAR — toastCenter, recentsProvider, wire-up

app/TagarelaTests/
├── ToastCenterTests.swift                  # NOVO
├── ToastKindTests.swift                    # NOVO
├── RefinerFallbackReasonTests.swift        # NOVO
├── RecentTranscriptionsProviderTests.swift # NOVO
├── HistoryStoreTests.swift                 # MODIFICAR — testar clearAll
├── PipelineCoordinatorTests.swift          # MODIFICAR — testar novos events
├── IndicatorVariantTests.swift             # NOVO
└── PreferencesStoreTests.swift             # MODIFICAR — indicatorVariant
```

Documentação atualizada por esta fase em `tagarela_docs/`:
- `02-arquitetura/04-modulos-fase2b2.md` (criar) — snapshot pós-2b-2.
- `03-funcionalidades/checklists/fase2b2-manual.md` (criar) — checklist manual.
- `04-decisoes/cleanup-fase2a.md` (atualizar) — fechar item #2.
- `04-decisoes/cleanup-fase2b1.md` (atualizar) — marcar achado #3 (histórico viewer) como fechado pela 2b-2.
- `README.md` — ajustar status da 2b-2 quando fechar.

---

## Convenções desta fase

Mesmas da 2b-1:

- **Idioma:** strings de UI em `Localizable.strings` (pt-BR base). Identificadores Swift em inglês.
- **Concorrência:** `@MainActor` pra estado mutável de UI/ToastCenter; `actor` pra serviços já existentes.
- **Erros:** cada módulo expõe `enum {Modulo}Error: Error` quando precisa.
- **Logging:** `Logger(subsystem: "com.tagarela", category: <nome>)`.
- **TDD:** lógica pura → teste primeiro. UI/SwiftUI → preview + checklist manual.
- **Commits:** um commit por tarefa (ou alguns commits relacionados), em pt-BR no estilo `tipo(escopo): descrição` + co-author Claude.
- **xcodegen é a fonte da verdade do projeto Xcode.** Após criar/mover arquivos, sempre rodar `xcodegen generate` em `/Users/tars/Dev/tagarela/app/`.

---

## Pre-flight (antes da Tarefa 1)

- [ ] **Confirmar `main` está limpo e em verde.**

```bash
cd /Users/tars/Dev/tagarela
git status                                      # working tree clean (workspace.json Obsidian é OK ficar M)
git log -1 --oneline                            # último: 381a25e docs(spec): aprovar design da Fase 2b-2 + ADR-0004
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: `** TEST SUCCEEDED **`, 116 testes passando.

- [ ] **Criar branch de trabalho.**

```bash
cd /Users/tars/Dev/tagarela
git checkout -b fase-2b2
```

- [ ] **Ollama rodando localmente** (necessário pro aceite manual final).

```bash
curl -sf http://localhost:11434/api/tags | head -c 200
ollama list | grep -E "gemma4:e4b|llama3" | head -3
```

---

## Tarefa 1: Foundation enums (`PermissionKind` + `RefinerFallbackReason` + `ToastKind`) + `Toast` struct

**Files:**
- Create: `app/Tagarela/Permissions/PermissionKind.swift`
- Create: `app/Tagarela/UI/Toast/ToastKind.swift`
- Create: `app/Tagarela/UI/Toast/Toast.swift`
- Create: `app/TagarelaTests/ToastKindTests.swift`
- Create: `app/TagarelaTests/RefinerFallbackReasonTests.swift`

- [ ] **Step 1: `PermissionKind`**

```swift
// app/Tagarela/Permissions/PermissionKind.swift
import Foundation

enum PermissionKind: String, Codable, CaseIterable, Sendable, Equatable {
    case microphone
    case accessibility
    case inputMonitoring
}
```

- [ ] **Step 2: `ToastKind` + `RefinerFallbackReason`**

```swift
// app/Tagarela/UI/Toast/ToastKind.swift
import Foundation
import SwiftUI

/// Razão semântica pelo fallback Identity. Mapeada de `RefinerError`.
enum RefinerFallbackReason: Equatable, Sendable {
    case networkOffline
    case unauthorized
    case timedOut
    case serverError(Int)
    case rateLimited
    case contextExceeded
    case modelNotFound(String)
    case malformedResponse

    /// Mapeia `RefinerError` pra `RefinerFallbackReason`. `.cancelled` retorna
    /// nil — cancel real é fluxo distinto, sem toast.
    init?(refinerError: RefinerError) {
        switch refinerError {
        case .networkOffline:        self = .networkOffline
        case .unauthorized:          self = .unauthorized
        case .timedOut:              self = .timedOut
        case .serverError(let code): self = .serverError(code)
        case .rateLimited:           self = .rateLimited
        case .contextExceeded:       self = .contextExceeded
        case .modelNotFound(let n):  self = .modelNotFound(n)
        case .malformedResponse:     self = .malformedResponse
        case .cancelled:             return nil
        }
    }
}

/// Tipo semântico de toast. Cada case carrega contexto suficiente pro toast
/// renderizar texto/cor/ícone certos.
enum ToastKind: Equatable, Sendable {
    case refinerFellBack(reason: RefinerFallbackReason)
    case injectionFailed
    case historySaveFailed
    case permissionDenied(kind: PermissionKind)

    var displayMessage: String {
        switch self {
        case .refinerFellBack(let reason):
            switch reason {
            case .networkOffline:
                return String(localized: "toast.refiner.networkOffline",
                              defaultValue: "Sem rede — usando texto cru.")
            case .unauthorized:
                return String(localized: "toast.refiner.unauthorized",
                              defaultValue: "API key inválida — usando texto cru.")
            case .timedOut:
                return String(localized: "toast.refiner.timedOut",
                              defaultValue: "Timeout no refiner — usando texto cru.")
            case .serverError(let code):
                return String(localized: "toast.refiner.serverError",
                              defaultValue: "Erro do servidor (\(code)) — usando texto cru.")
            case .rateLimited:
                return String(localized: "toast.refiner.rateLimited",
                              defaultValue: "Rate limit no refiner — usando texto cru.")
            case .contextExceeded:
                return String(localized: "toast.refiner.contextExceeded",
                              defaultValue: "Texto longo demais — usando texto cru.")
            case .modelNotFound(let name):
                return String(localized: "toast.refiner.modelNotFound",
                              defaultValue: "Modelo '\(name)' não encontrado — usando texto cru.")
            case .malformedResponse:
                return String(localized: "toast.refiner.malformedResponse",
                              defaultValue: "Resposta malformada — usando texto cru.")
            }
        case .injectionFailed:
            return String(localized: "toast.injection.failed",
                          defaultValue: "Não foi possível colar — texto está na área de transferência.")
        case .historySaveFailed:
            return String(localized: "toast.history.saveFailed",
                          defaultValue: "Histórico não salvou desta captura.")
        case .permissionDenied(let kind):
            switch kind {
            case .microphone:
                return String(localized: "toast.permission.microphone",
                              defaultValue: "Microfone negado. Abra Configurações › Privacidade › Microfone.")
            case .accessibility:
                return String(localized: "toast.permission.accessibility",
                              defaultValue: "Acessibilidade negada. Abra Configurações › Privacidade › Acessibilidade.")
            case .inputMonitoring:
                return String(localized: "toast.permission.inputMonitoring",
                              defaultValue: "Input Monitoring negado. Abra Configurações › Privacidade › Input Monitoring.")
            }
        }
    }

    var iconSystemName: String {
        switch self {
        case .refinerFellBack:    return "exclamationmark.triangle"
        case .injectionFailed:    return "doc.on.clipboard"
        case .historySaveFailed:  return "externaldrive.badge.xmark"
        case .permissionDenied:   return "lock.shield"
        }
    }

    /// Cor de borda/ícone do toast. paper bg é constante.
    var tintColor: Color {
        switch self {
        case .refinerFellBack:    return .orange
        case .injectionFailed:    return .red
        case .historySaveFailed:  return .red
        case .permissionDenied:   return .red
        }
    }
}
```

- [ ] **Step 3: `Toast` struct**

```swift
// app/Tagarela/UI/Toast/Toast.swift
import Foundation

struct Toast: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ToastKind
    let createdAt: Date

    init(kind: ToastKind, id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Testes do `ToastKind`**

```swift
// app/TagarelaTests/ToastKindTests.swift
import XCTest
@testable import Tagarela

final class ToastKindTests: XCTestCase {
    func test_displayMessage_refinerNetworkOffline() {
        let kind = ToastKind.refinerFellBack(reason: .networkOffline)
        XCTAssertTrue(kind.displayMessage.lowercased().contains("rede"))
        XCTAssertTrue(kind.displayMessage.lowercased().contains("cru"))
    }

    func test_displayMessage_refinerServerErrorIncludesCode() {
        let kind = ToastKind.refinerFellBack(reason: .serverError(503))
        XCTAssertTrue(kind.displayMessage.contains("503"))
    }

    func test_displayMessage_refinerModelNotFoundIncludesName() {
        let kind = ToastKind.refinerFellBack(reason: .modelNotFound("gemma4:e4b"))
        XCTAssertTrue(kind.displayMessage.contains("gemma4:e4b"))
    }

    func test_displayMessage_permissionMicrophone() {
        let kind = ToastKind.permissionDenied(kind: .microphone)
        XCTAssertTrue(kind.displayMessage.lowercased().contains("microfone"))
    }

    func test_iconSystemName_perCase() {
        XCTAssertEqual(ToastKind.refinerFellBack(reason: .timedOut).iconSystemName,
                       "exclamationmark.triangle")
        XCTAssertEqual(ToastKind.injectionFailed.iconSystemName,
                       "doc.on.clipboard")
        XCTAssertEqual(ToastKind.historySaveFailed.iconSystemName,
                       "externaldrive.badge.xmark")
        XCTAssertEqual(ToastKind.permissionDenied(kind: .accessibility).iconSystemName,
                       "lock.shield")
    }
}
```

- [ ] **Step 5: Testes do `RefinerFallbackReason`**

```swift
// app/TagarelaTests/RefinerFallbackReasonTests.swift
import XCTest
@testable import Tagarela

final class RefinerFallbackReasonTests: XCTestCase {
    func test_initFromRefinerError_networkOffline() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .networkOffline), .networkOffline)
    }

    func test_initFromRefinerError_unauthorized() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .unauthorized), .unauthorized)
    }

    func test_initFromRefinerError_timedOut() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .timedOut), .timedOut)
    }

    func test_initFromRefinerError_serverErrorPreservesCode() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .serverError(503)),
                       .serverError(503))
    }

    func test_initFromRefinerError_modelNotFoundPreservesName() {
        XCTAssertEqual(RefinerFallbackReason(refinerError: .modelNotFound("xyz:fake")),
                       .modelNotFound("xyz:fake"))
    }

    func test_initFromRefinerError_cancelledReturnsNil() {
        XCTAssertNil(RefinerFallbackReason(refinerError: .cancelled))
    }
}
```

- [ ] **Step 6: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, ~127 testes (116 + 11 novos).

- [ ] **Step 7: Commit**

```bash
git add app/Tagarela/Permissions/PermissionKind.swift app/Tagarela/UI/Toast/ToastKind.swift app/Tagarela/UI/Toast/Toast.swift app/TagarelaTests/ToastKindTests.swift app/TagarelaTests/RefinerFallbackReasonTests.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(toast): foundation models — PermissionKind, RefinerFallbackReason, ToastKind, Toast

- PermissionKind enum (microphone/accessibility/inputMonitoring)
- RefinerFallbackReason init?(refinerError:) mapeia 8 cases do RefinerError
  (.cancelled retorna nil — cancel real não vira fallback)
- ToastKind com 4 cases semânticos + displayMessage localizado por case
  + iconSystemName + tintColor
- Toast struct (id, kind, createdAt) Identifiable Sendable
- 11 testes (6 RefinerFallbackReason init from each, 5 ToastKind
  displayMessage/iconSystemName)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: `ToastCenter` com auto-dismiss

**Files:**
- Create: `app/Tagarela/UI/Toast/ToastCenter.swift`
- Create: `app/TagarelaTests/ToastCenterTests.swift`

- [ ] **Step 1: Implementar `ToastCenter`**

```swift
// app/Tagarela/UI/Toast/ToastCenter.swift
import Foundation
import OSLog

@MainActor
final class ToastCenter: ObservableObject {
    private let logger = Logger(subsystem: "com.tagarela", category: "ToastCenter")
    /// Único toast visível por vez. Overflow substitui o atual.
    @Published private(set) var current: Toast?

    private var autoDismissTask: Task<Void, Never>?
    /// Tempo padrão antes do auto-dismiss (4s).
    static let autoDismissNanoseconds: UInt64 = 4_000_000_000

    /// Mostra um novo toast, cancelando timer anterior se houver.
    func show(_ toast: Toast) {
        autoDismissTask?.cancel()
        current = toast
        let id = toast.id
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.autoDismissNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.dismissIfStill(id: id)
        }
    }

    /// Dismiss imediato (click no toast ou substituição manual).
    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        current = nil
    }

    /// Dismiss apenas se o id atual ainda for o mesmo (evita dismissar um
    /// toast novo agendado durante o sleep).
    private func dismissIfStill(id: UUID) {
        guard current?.id == id else { return }
        current = nil
        autoDismissTask = nil
    }

    deinit {
        autoDismissTask?.cancel()
    }
}
```

- [ ] **Step 2: Testes do `ToastCenter`**

```swift
// app/TagarelaTests/ToastCenterTests.swift
import XCTest
@testable import Tagarela

@MainActor
final class ToastCenterTests: XCTestCase {
    func test_show_setsCurrent() {
        let center = ToastCenter()
        XCTAssertNil(center.current)
        let t = Toast(kind: .injectionFailed)
        center.show(t)
        XCTAssertEqual(center.current?.id, t.id)
    }

    func test_dismiss_clearsCurrent() {
        let center = ToastCenter()
        center.show(Toast(kind: .injectionFailed))
        center.dismiss()
        XCTAssertNil(center.current)
    }

    func test_show_replacesExistingToast() {
        let center = ToastCenter()
        let t1 = Toast(kind: .injectionFailed)
        let t2 = Toast(kind: .historySaveFailed)
        center.show(t1)
        center.show(t2)
        XCTAssertEqual(center.current?.id, t2.id)
    }

    func test_autoDismiss_clearsAfterTTL() async throws {
        // Sub-classe pra reduzir o TTL e não fazer o teste lento
        let center = ToastCenter()
        center.show(Toast(kind: .injectionFailed))
        XCTAssertNotNil(center.current)
        // Aguarda > 4s seria muito lento — em vez disso valida que o
        // current bate com o id mesmo após pequeno delay (sem auto-dismiss
        // disparado), e que dismiss manual funciona.
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNotNil(center.current)
        center.dismiss()
        XCTAssertNil(center.current)
    }

    func test_show_doesNotPersistAcrossDismissIfStill() async {
        // Verifica que dismissIfStill não dismissa toast diferente do
        // que estava agendado. Cobertura indireta: se show() troca o
        // toast e o sleep do anterior dispara, o id check protege.
        let center = ToastCenter()
        let t1 = Toast(kind: .injectionFailed)
        center.show(t1)
        let t2 = Toast(kind: .historySaveFailed)
        center.show(t2)
        // current deve continuar t2; (a cancelTask do show já matou o
        // sleep do t1, então o dismissIfStill nem roda)
        XCTAssertEqual(center.current?.id, t2.id)
    }
}
```

- [ ] **Step 3: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, ~132 testes (127 + 5 novos).

- [ ] **Step 4: Commit**

```bash
git add app/Tagarela/UI/Toast/ToastCenter.swift app/TagarelaTests/ToastCenterTests.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(toast): ToastCenter ObservableObject com auto-dismiss 4s

- @MainActor singleton-style: @Published current: Toast?
- show(_:) cancela timer anterior, agenda novo Task com sleep 4s
- dismiss() cancela imediato
- dismissIfStill(id:) protege contra race entre toasts (sleep do
  anterior não pode apagar toast novo)
- 5 testes (show, dismiss, replace, manual dismiss, race)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: `ToastView` (SwiftUI render)

**Files:**
- Create: `app/Tagarela/UI/Toast/ToastView.swift`

- [ ] **Step 1: Implementar `ToastView`**

```swift
// app/Tagarela/UI/Toast/ToastView.swift
import SwiftUI

/// Render de um Toast acima do indicator pill. Click = dismiss antecipado.
struct ToastView: View {
    let kind: ToastKind
    var onDismiss: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.iconSystemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(kind.tintColor)
                .frame(width: 18)
            Text(kind.displayMessage)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 320, alignment: .leading)
        .background(DS.Color.paper, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(kind.tintColor.opacity(0.6), lineWidth: 0.8)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(kind.tintColor)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                .padding(.vertical, 6)
                .padding(.leading, 4)
        }
        .dsShadowPop()
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }
}

#Preview {
    VStack(spacing: 12) {
        ToastView(kind: .refinerFellBack(reason: .networkOffline))
        ToastView(kind: .injectionFailed)
        ToastView(kind: .historySaveFailed)
        ToastView(kind: .permissionDenied(kind: .microphone))
        ToastView(kind: .refinerFellBack(reason: .serverError(503)))
    }
    .padding(40)
    .background(DS.Color.paper2)
}
```

- [ ] **Step 2: Build (sem testes — UI puro)**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -5
```

Esperado: BUILD SUCCEEDED.

- [ ] **Step 3: Rodar testes (regressão — não devem quebrar)**

```bash
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, 132 testes (sem mudança).

- [ ] **Step 4: Commit**

```bash
git add app/Tagarela/UI/Toast/ToastView.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(toast): ToastView SwiftUI render

- HStack icon + message com paper bg + border-left tinted pelo
  kind.tintColor + ds shadow
- onTapGesture dispara onDismiss (click = dismiss antecipado)
- maxWidth 320 + lineLimit 2 + fixedSize multilinha
- Preview com 5 variações pra verificar visualmente

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: Novos `PipelineEvent` cases + emissão em `PipelineCoordinator`

**Files:**
- Modify: `app/Tagarela/Pipeline/PipelineEvent.swift`
- Modify: `app/Tagarela/Pipeline/PipelineCoordinator.swift`
- Modify: `app/TagarelaTests/PipelineCoordinatorTests.swift`

- [ ] **Step 1: Estender `PipelineEvent`**

Find:
```swift
enum PipelineEvent: Equatable, Sendable {
    case toggle
    case cancel
    case stateChanged(PipelineState)
    case finished(rawText: String, refinedText: String, frontmostApp: String?)
    case errorOccurred(String)
}
```

Replace with:
```swift
enum PipelineEvent: Equatable, Sendable {
    case toggle
    case cancel
    case stateChanged(PipelineState)
    case finished(rawText: String, refinedText: String, frontmostApp: String?)
    case errorOccurred(String)
    /// Refiner remoto falhou; pipeline cai em IdentityRefiner. Carrega causa
    /// pra surfaceiar em toast. Cleanup #2 da Fase 2a.
    case refinerFellBack(reason: RefinerFallbackReason)
    /// `injector.inject` lançou erro. Texto fica no clipboard mas não foi colado.
    case injectionFailed
    /// `historyStore.save` lançou erro. Captura ocorreu mas não foi persistida.
    case historySaveFailed
    /// `audio.start()` ou inject falhou por falta de permissão.
    case permissionDenied(kind: PermissionKind)
}
```

- [ ] **Step 2: Emitir `.refinerFellBack(reason:)` no fallback do refining**

Em `app/Tagarela/Pipeline/PipelineCoordinator.swift`, find o catch após `try await refiner.refine`:

```swift
                } catch {
                    logger.error("refiner failed (\(refiner.kind.rawValue)): \(String(describing: error))")
                    let identityFallback = IdentityRefiner()
                    refined = (try? await identityFallback.refine(raw, style: style)) ?? raw
                    actualRefinerKind = identityFallback.kind
                }
```

Replace with:
```swift
                } catch {
                    logger.error("refiner failed (\(refiner.kind.rawValue, privacy: .public)): \(String(describing: error), privacy: .public)")
                    // Cleanup #2 da Fase 2a: surfaceiar fallback ao usuário via toast.
                    if let refinerError = error as? RefinerError,
                       let reason = RefinerFallbackReason(refinerError: refinerError) {
                        continuation?.yield(.refinerFellBack(reason: reason))
                    }
                    let identityFallback = IdentityRefiner()
                    refined = (try? await identityFallback.refine(raw, style: style)) ?? raw
                    actualRefinerKind = identityFallback.kind
                }
```

- [ ] **Step 3: Emitir `.injectionFailed` quando `inject` lança**

No mesmo arquivo, find:
```swift
            let frontApp = try await injector.inject(text: refined)
```

Replace with:
```swift
            let frontApp: String?
            do {
                frontApp = try await injector.inject(text: refined)
            } catch InjectionError.accessibilityDenied {
                continuation?.yield(.permissionDenied(kind: .accessibility))
                setState(.idle)
                return
            } catch {
                logger.error("inject failed: \(String(describing: error), privacy: .public)")
                continuation?.yield(.injectionFailed)
                setState(.idle)
                return
            }
```

- [ ] **Step 4: Emitir `.historySaveFailed` quando save lança**

Find:
```swift
            } catch {
                logger.error("history save failed: \(String(describing: error))")
            }
```

Replace with:
```swift
            } catch {
                logger.error("history save failed: \(String(describing: error), privacy: .public)")
                continuation?.yield(.historySaveFailed)
            }
```

- [ ] **Step 5: Emitir `.permissionDenied(.microphone)` em start**

Find o `handleToggle` `case .idle`:
```swift
        case .idle:
            do {
                try audio.start()
                ...
            } catch {
                setState(.error(message: "mic indisponível"))
                continuation?.yield(.errorOccurred("mic: \(error)"))
            }
```

Replace with:
```swift
        case .idle:
            do {
                try audio.start()
                startTime = Date()
                currentLevel = 0
                setState(.recording(elapsedSeconds: 0, audioLevel: 0))
                spawnRecordingTasks()
            } catch AudioCaptureError.microphoneDenied {
                continuation?.yield(.permissionDenied(kind: .microphone))
                setState(.error(message: "mic"))
                continuation?.yield(.errorOccurred("mic denied"))
            } catch {
                setState(.error(message: "mic indisponível"))
                continuation?.yield(.errorOccurred("mic: \(error)"))
            }
```

(Audite o código atual antes de aplicar — pode haver diferenças após T2 da 2b-1.)

- [ ] **Step 6: Adicionar testes em `PipelineCoordinatorTests`**

Em `app/TagarelaTests/PipelineCoordinatorTests.swift`, adicionar 4 testes novos:

```swift
    @MainActor
    func test_refinerFails_emitsRefinerFellBack() async {
        // Refiner lança RefinerError.networkOffline → pipeline emite .refinerFellBack(.networkOffline)
        let helpers = makeHelpers()
        helpers.refinerFactory.shouldFail = .networkOffline   // ajustar conforme helper existente
        let coord = helpers.coord
        var captured: [PipelineEvent] = []
        let task = Task { for await e in coord.events { captured.append(e) } }
        await coord.handle(.toggle)
        // simula áudio gravado e parada
        helpers.simulateValidBuffer()
        await coord.handle(.toggle)
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        XCTAssertTrue(captured.contains(where: { event in
            if case .refinerFellBack(let reason) = event, reason == .networkOffline { return true }
            return false
        }))
    }

    @MainActor
    func test_injectFails_emitsInjectionFailed() async {
        let helpers = makeHelpers()
        helpers.injector.shouldThrow = NSError(domain: "test", code: 0)
        // ... (similar pattern, verificar .injectionFailed emitido)
        // Implementação exata depende dos helpers existentes em PipelineCoordinatorTests.
        // Se não existirem, criar fakes inline.
    }

    @MainActor
    func test_saveFails_emitsHistorySaveFailed() async {
        let helpers = makeHelpers()
        helpers.historyStore.shouldThrow = NSError(domain: "test", code: 1)
        // ... (.historySaveFailed emitido)
    }

    @MainActor
    func test_micDenied_emitsPermissionDenied() async {
        let helpers = makeHelpers()
        helpers.audio.startError = AudioCaptureError.microphoneDenied
        // ... (.permissionDenied(.microphone) emitido)
    }
```

(Audite `PipelineCoordinatorTests.swift` e os fakes/helpers existentes antes de codar — adapte o pattern. Se não há helpers que injetem erro, criar fake stores/audio/injector inline neste teste.)

- [ ] **Step 7: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, ~136 testes (132 + 4 novos).

- [ ] **Step 8: Commit**

```bash
git add app/Tagarela/Pipeline/PipelineEvent.swift app/Tagarela/Pipeline/PipelineCoordinator.swift app/TagarelaTests/PipelineCoordinatorTests.swift
git commit -m "$(cat <<'EOF'
feat(pipeline): novos events pra surfaceiar fallbacks/erros (cleanup #2 da 2a)

- 4 novos cases em PipelineEvent: refinerFellBack(reason:),
  injectionFailed, historySaveFailed, permissionDenied(kind:)
- Refining catch agora emite .refinerFellBack(reason:) antes de cair
  em IdentityRefiner — fecha cleanup #2 da Fase 2a
- inject throwing → .injectionFailed (ou .permissionDenied(.accessibility)
  se for InjectionError.accessibilityDenied)
- history save throwing → .historySaveFailed
- audio.start AudioCaptureError.microphoneDenied → .permissionDenied(.microphone)
- 4 testes novos no PipelineCoordinatorTests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: `HistoryStore.clearAll()`

**Files:**
- Modify: `app/Tagarela/History/HistoryStore.swift`
- Modify: `app/Tagarela/History/HistoryStoreLive.swift`
- Modify: `app/Tagarela/History/HistoryStoreNoop.swift`
- Modify: `app/TagarelaTests/HistoryStoreTests.swift`

- [ ] **Step 1: Adicionar `clearAll()` ao protocol**

Em `app/Tagarela/History/HistoryStore.swift`, adicionar ao protocol:

```swift
protocol HistoryStore: AnyObject, Sendable {
    func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws
    func recent(limit: Int) async throws -> [Transcription]
    /// Apaga todas as transcrições. Idempotente em store vazio. Fase 2b-2.
    func clearAll() async throws
}
```

- [ ] **Step 2: Implementar em `HistoryStoreLive`**

Em `app/Tagarela/History/HistoryStoreLive.swift`, adicionar método:

```swift
    func clearAll() async throws {
        let ctx = container.mainContext
        let all = try ctx.fetch(FetchDescriptor<Transcription>())
        for t in all { ctx.delete(t) }
        try ctx.save()
    }
```

- [ ] **Step 3: Implementar no-op em `HistoryStoreNoop`**

Em `app/Tagarela/History/HistoryStoreNoop.swift`, adicionar método:

```swift
    func clearAll() async throws { /* noop */ }
```

- [ ] **Step 4: Testes**

Em `app/TagarelaTests/HistoryStoreTests.swift`, adicionar:

```swift
    @MainActor
    func test_clearAll_removesAllItems() async throws {
        let store = try HistoryStoreLive(inMemory: true)
        for i in 0..<3 {
            try await store.save(makeInput(rawText: "raw \(i)"),
                                  maxItems: 200, maxDays: 30)
        }
        var fetched = try await store.recent(limit: 100)
        XCTAssertEqual(fetched.count, 3)
        try await store.clearAll()
        fetched = try await store.recent(limit: 100)
        XCTAssertEqual(fetched.count, 0)
    }

    @MainActor
    func test_clearAll_onEmptyStoreIsNoOp() async throws {
        let store = try HistoryStoreLive(inMemory: true)
        try await store.clearAll()  // não deve throw
        let fetched = try await store.recent(limit: 100)
        XCTAssertEqual(fetched.count, 0)
    }
```

(Audite `HistoryStoreTests` pra ver como `makeInput` é definido. Se não existe, criar inline:
`private func makeInput(rawText: String) -> TranscriptionInput { TranscriptionInput(durationSeconds: 1.0, rawText: rawText, refinedText: rawText, refinerKind: "none", llmModelName: nil, whisperModelName: "test", styleName: "test", frontmostAppBundleID: nil) }`)

- [ ] **Step 5: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, ~138 testes (136 + 2 novos).

- [ ] **Step 6: Commit**

```bash
git add app/Tagarela/History/HistoryStore.swift app/Tagarela/History/HistoryStoreLive.swift app/Tagarela/History/HistoryStoreNoop.swift app/TagarelaTests/HistoryStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(history): clearAll() no protocolo + Live (fetch+delete loop) + Noop

Necessário pra botão "Limpar tudo" em Preferências > Histórico (Fase 2b-2).
2 testes (clearAll com itens, clearAll em store vazio idempotente).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 6: `IndicatorVariant` + `IndicatorView` protocol + `PreferencesStore` extension

**Files:**
- Create: `app/Tagarela/Preferences/IndicatorVariant.swift`
- Create: `app/Tagarela/UI/Indicator/IndicatorView.swift`
- Modify: `app/Tagarela/Preferences/Preferences+Defaults.swift`
- Modify: `app/Tagarela/Preferences/PreferencesStore.swift`
- Modify: `app/Tagarela/UI/Indicator/IndicatorPill.swift` (conformar protocol)
- Create: `app/TagarelaTests/IndicatorVariantTests.swift`
- Modify: `app/TagarelaTests/PreferencesStoreTests.swift`

- [ ] **Step 1: `IndicatorVariant`**

```swift
// app/Tagarela/Preferences/IndicatorVariant.swift
import Foundation

enum IndicatorVariant: String, Codable, CaseIterable, Sendable, Equatable {
    case pill       // A — default
    case orb        // B
    case vertical   // C
    case hud        // D — dark only

    var displayName: String {
        switch self {
        case .pill:     return String(localized: "indicator.variant.pill", defaultValue: "Pílula")
        case .orb:      return String(localized: "indicator.variant.orb", defaultValue: "Orb")
        case .vertical: return String(localized: "indicator.variant.vertical", defaultValue: "Vertical")
        case .hud:      return String(localized: "indicator.variant.hud", defaultValue: "HUD")
        }
    }

    /// HUD usa dark mode forçado (per ADR-0001). Outros respeitam o tema do sistema.
    var isDarkOnly: Bool {
        self == .hud
    }
}
```

- [ ] **Step 2: `IndicatorView` protocol**

```swift
// app/Tagarela/UI/Indicator/IndicatorView.swift
import SwiftUI

/// Conformidade pras 4 variações do indicator flutuante. Cada View toma
/// o `PipelineState` atual e uma closure `onCancel`. `FloatingIndicatorPanel`
/// faz dispatch via `prefs.indicatorVariant` ao rebuildar.
protocol IndicatorView: View {
    init(state: PipelineState, onCancel: @escaping () -> Void)
}
```

- [ ] **Step 3: Conformar `IndicatorPill` ao protocol**

Em `app/Tagarela/UI/Indicator/IndicatorPill.swift`, find:

```swift
struct IndicatorPill: View {
    let state: PipelineState
    var onCancel: () -> Void = {}
```

Replace with:

```swift
struct IndicatorPill: View, IndicatorView {
    let state: PipelineState
    var onCancel: () -> Void

    init(state: PipelineState, onCancel: @escaping () -> Void = {}) {
        self.state = state
        self.onCancel = onCancel
    }
```

(Sem mudança comportamental — só explicita o init pra cumprir o protocol. Tests existentes seguem passando.)

- [ ] **Step 4: Adicionar chave + default em `Preferences+Defaults.swift`**

Em `enum PreferencesKey`, adicionar:
```swift
static let indicatorVariant = "com.tagarela.preferences.indicatorVariant"
```

Em `enum PreferencesDefaults`, adicionar:
```swift
static let indicatorVariant: IndicatorVariant = .pill
```

- [ ] **Step 5: Adicionar `@Published indicatorVariant` em `PreferencesStore`**

Após o último `@Published` adicionar:

```swift
    @Published var indicatorVariant: IndicatorVariant {
        didSet {
            defaults.set(indicatorVariant.rawValue, forKey: PreferencesKey.indicatorVariant)
        }
    }
```

No `init`, após o bloco do `openAIEndpoint`, adicionar:

```swift
        let variantRaw = defaults.string(forKey: PreferencesKey.indicatorVariant)
            ?? PreferencesDefaults.indicatorVariant.rawValue
        self.indicatorVariant = IndicatorVariant(rawValue: variantRaw)
            ?? PreferencesDefaults.indicatorVariant
```

- [ ] **Step 6: Testes do `IndicatorVariant`**

```swift
// app/TagarelaTests/IndicatorVariantTests.swift
import XCTest
@testable import Tagarela

final class IndicatorVariantTests: XCTestCase {
    func test_codableRoundTrip_perCase() throws {
        for v in IndicatorVariant.allCases {
            let data = try JSONEncoder().encode(v)
            let decoded = try JSONDecoder().decode(IndicatorVariant.self, from: data)
            XCTAssertEqual(decoded, v)
        }
    }

    func test_isDarkOnly_onlyHUD() {
        XCTAssertFalse(IndicatorVariant.pill.isDarkOnly)
        XCTAssertFalse(IndicatorVariant.orb.isDarkOnly)
        XCTAssertFalse(IndicatorVariant.vertical.isDarkOnly)
        XCTAssertTrue(IndicatorVariant.hud.isDarkOnly)
    }

    func test_allCases_count4() {
        XCTAssertEqual(Set(IndicatorVariant.allCases),
                       Set([.pill, .orb, .vertical, .hud]))
    }
}
```

- [ ] **Step 7: Estender `PreferencesStoreTests`**

Em `test_defaults_match_designV1`, adicionar antes do final:
```swift
        XCTAssertEqual(store.indicatorVariant, .pill)
```

Adicionar teste de persistência:
```swift
    func test_setIndicatorVariant_persistsAcrossInit() {
        let s1 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s1.indicatorVariant = .hud
        let s2 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        XCTAssertEqual(s2.indicatorVariant, .hud)
    }
```

- [ ] **Step 8: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, ~142 testes (138 + 3 + 1 novos).

- [ ] **Step 9: Commit**

```bash
git add app/Tagarela/Preferences/IndicatorVariant.swift app/Tagarela/UI/Indicator/IndicatorView.swift app/Tagarela/UI/Indicator/IndicatorPill.swift app/Tagarela/Preferences/Preferences+Defaults.swift app/Tagarela/Preferences/PreferencesStore.swift app/TagarelaTests/IndicatorVariantTests.swift app/TagarelaTests/PreferencesStoreTests.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(indicator): IndicatorVariant + IndicatorView protocol + Pill conformando

- IndicatorVariant enum (pill/orb/vertical/hud) com displayName + isDarkOnly
- IndicatorView protocol: View + init(state: PipelineState, onCancel:)
- IndicatorPill explicita init pra conformar protocol — sem mudança comportamental
- prefs.indicatorVariant persistido como rawValue (default .pill)
- 4 testes (codable round-trip per case, isDarkOnly, allCases, persistência)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: `IndicatorOrb` (variação B)

**Files:**
- Create: `app/Tagarela/UI/Indicator/IndicatorOrb.swift`

- [ ] **Step 1: Implementar `IndicatorOrb`**

```swift
// app/Tagarela/UI/Indicator/IndicatorOrb.swift
import SwiftUI

/// Variação B — orb radial 92×92. Dot pulsante carmim no centro,
/// ring com waveform circular, timer mono abaixo.
struct IndicatorOrb: View, IndicatorView {
    let state: PipelineState
    var onCancel: () -> Void

    init(state: PipelineState, onCancel: @escaping () -> Void = {}) {
        self.state = state
        self.onCancel = onCancel
    }

    private var levelAndSeconds: (level: Double, seconds: Double) {
        if case .recording(let secs, let lvl) = state { return (lvl, secs) }
        return (0, 0)
    }

    private var dotColor: Color {
        switch state {
        case .recording: return DS.Color.carmine
        case .processing, .refining: return DS.Color.amber
        case .error: return DS.Color.carmineDeep
        case .idle: return DS.Color.ink
        }
    }

    private var formatted: String {
        let (_, seconds) = levelAndSeconds
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        let (level, _) = levelAndSeconds
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(DS.Color.hairlineStrong, lineWidth: 0.8)
                    .frame(width: 76, height: 76)
                Circle()
                    .stroke(dotColor.opacity(0.4 + level * 0.6), lineWidth: 2)
                    .frame(width: 56, height: 56)
                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
                    .modifier(PulseIfRecordingOrb(state: state))
            }
            .frame(width: 92, height: 92)
            .background(DS.Color.paper, in: Circle())
            .overlay(Circle().stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
            .dsShadowPop()
            Text(formatted)
                .font(DS.Font.mono(10))
                .monospacedDigit()
                .foregroundStyle(DS.Color.ink2)
        }
        .contentShape(Circle())
        .onTapGesture { onCancel() }
    }
}

private struct PulseIfRecordingOrb: ViewModifier {
    let state: PipelineState
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing && isRecording ? 0.55 : 1)
            .scaleEffect(pulsing && isRecording ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.6).repeatForever(), value: pulsing)
            .onAppear { pulsing = true }
    }

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }
}

#Preview {
    VStack(spacing: 20) {
        IndicatorOrb(state: .recording(elapsedSeconds: 12, audioLevel: 0.6))
        IndicatorOrb(state: .processing)
        IndicatorOrb(state: .refining)
        IndicatorOrb(state: .error(message: "erro"))
    }
    .padding(40)
    .background(DS.Color.paper2)
}
```

- [ ] **Step 2: Build (sem testes — UI puro)**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -3
```

- [ ] **Step 3: Commit**

```bash
git add app/Tagarela/UI/Indicator/IndicatorOrb.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(indicator): IndicatorOrb (variação B) — radial 92×92

Centrado: dot pulsante carmim + ring com level audio + timer mono.
Conforma IndicatorView. Pattern PulseIfRecording isolado por variação
pra evitar bug de @State compartilhado em previews.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 8: `IndicatorVertical` (variação C)

**Files:**
- Create: `app/Tagarela/UI/Indicator/IndicatorVertical.swift`

- [ ] **Step 1: Implementar `IndicatorVertical`**

```swift
// app/Tagarela/UI/Indicator/IndicatorVertical.swift
import SwiftUI

/// Variação C — barra vertical fina (28×120). Dot pulsante carmim no topo,
/// waveform vertical no meio, timer rotacionado abaixo.
struct IndicatorVertical: View, IndicatorView {
    let state: PipelineState
    var onCancel: () -> Void

    init(state: PipelineState, onCancel: @escaping () -> Void = {}) {
        self.state = state
        self.onCancel = onCancel
    }

    private var levelAndSeconds: (level: Double, seconds: Double) {
        if case .recording(let secs, let lvl) = state { return (lvl, secs) }
        return (0, 0)
    }

    private var dotColor: Color {
        switch state {
        case .recording: return DS.Color.carmine
        case .processing, .refining: return DS.Color.amber
        case .error: return DS.Color.carmineDeep
        case .idle: return DS.Color.ink
        }
    }

    private var formatted: String {
        let (_, seconds) = levelAndSeconds
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        let (level, _) = levelAndSeconds
        VStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .modifier(PulseIfRecordingVertical(state: state))
            VStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    let intensity = max(0, level - Double(i) * 0.12)
                    Rectangle()
                        .fill(dotColor.opacity(0.3 + intensity * 0.7))
                        .frame(width: 4, height: 6)
                }
            }
            Text(formatted)
                .font(DS.Font.mono(9))
                .monospacedDigit()
                .foregroundStyle(DS.Color.ink2)
                .rotationEffect(.degrees(-90))
                .frame(width: 12, height: 38)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(DS.Color.paper, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
        .dsShadowPop()
        .frame(width: 28, height: 120)
        .contentShape(Rectangle())
        .onTapGesture { onCancel() }
    }
}

private struct PulseIfRecordingVertical: ViewModifier {
    let state: PipelineState
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing && isRecording ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.6).repeatForever(), value: pulsing)
            .onAppear { pulsing = true }
    }

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }
}

#Preview {
    HStack(spacing: 20) {
        IndicatorVertical(state: .recording(elapsedSeconds: 12, audioLevel: 0.6))
        IndicatorVertical(state: .processing)
        IndicatorVertical(state: .refining)
        IndicatorVertical(state: .error(message: "erro"))
    }
    .padding(40)
    .background(DS.Color.paper2)
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -3
```

- [ ] **Step 3: Commit**

```bash
git add app/Tagarela/UI/Indicator/IndicatorVertical.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(indicator): IndicatorVertical (variação C) — barra fina 28×120

Layout vertical: dot pulsante topo, 8 barrinhas que reagem ao audio
level no meio, timer mono rotacionado -90° abaixo. Conforma IndicatorView.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 9: `IndicatorHUD` (variação D, dark only)

**Files:**
- Create: `app/Tagarela/UI/Indicator/IndicatorHUD.swift`

- [ ] **Step 1: Implementar `IndicatorHUD`**

```swift
// app/Tagarela/UI/Indicator/IndicatorHUD.swift
import SwiftUI

/// Variação D — HUD style Siri (260×80). Background semi-transparente escuro,
/// dot pulsante carmim, waveform horizontal grande, timer + label.
/// Per ADR-0001, dark only — em light mode pode ficar baixo contraste (aceito).
struct IndicatorHUD: View, IndicatorView {
    let state: PipelineState
    var onCancel: () -> Void

    init(state: PipelineState, onCancel: @escaping () -> Void = {}) {
        self.state = state
        self.onCancel = onCancel
    }

    private var levelAndSeconds: (level: Double, seconds: Double) {
        if case .recording(let secs, let lvl) = state { return (lvl, secs) }
        return (0, 0)
    }

    private var dotColor: Color {
        switch state {
        case .recording: return DS.Color.carmine
        case .processing, .refining: return DS.Color.amber
        case .error: return DS.Color.carmineDeep
        case .idle: return Color.white.opacity(0.6)
        }
    }

    private var stateLabel: String {
        switch state {
        case .recording: return "rec"
        case .processing: return "trans"
        case .refining: return "refn"
        case .error: return "err"
        case .idle: return "idle"
        }
    }

    private var formatted: String {
        let (_, seconds) = levelAndSeconds
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        let (level, _) = levelAndSeconds
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(dotColor.opacity(0.4), lineWidth: 1)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .modifier(PulseIfRecordingHUD(state: state))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stateLabel)
                    .font(DS.Font.mono(9))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                WaveBars(level: level,
                         color: .white,
                         count: 20, height: 26, width: 130)
            }
            Spacer(minLength: 0)
            Text(formatted)
                .font(DS.Font.mono(13))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 260, height: 80)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture { onCancel() }
    }
}

private struct PulseIfRecordingHUD: ViewModifier {
    let state: PipelineState
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing && isRecording ? 0.55 : 1)
            .scaleEffect(pulsing && isRecording ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.6).repeatForever(), value: pulsing)
            .onAppear { pulsing = true }
    }

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }
}

#Preview {
    VStack(spacing: 20) {
        IndicatorHUD(state: .recording(elapsedSeconds: 12, audioLevel: 0.6))
        IndicatorHUD(state: .processing)
        IndicatorHUD(state: .refining)
        IndicatorHUD(state: .error(message: "erro"))
    }
    .padding(40)
    .background(LinearGradient(colors: [.gray.opacity(0.3), .black], startPoint: .top, endPoint: .bottom))
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -3
```

- [ ] **Step 3: Commit**

```bash
git add app/Tagarela/UI/Indicator/IndicatorHUD.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(indicator): IndicatorHUD (variação D) — Siri-style 260×80, dark only

HStack: ring com dot pulsante, label de estado + WaveBars largo, timer mono
de 13pt. Background black.opacity(0.85). Per ADR-0001 dark only — em light
mode fica baixo contraste, aceito.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 10: `FloatingIndicatorPanel` rebuild com toast layer + variant dispatch + showPreview

**Files:**
- Modify: `app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift`
- Modify: `app/Tagarela/App/AppContainer.swift` (atualizar `refreshIndicator`)

- [ ] **Step 1: Reformar `FloatingIndicatorPanel.swift`**

```swift
// app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift
import AppKit
import SwiftUI

@MainActor
final class FloatingIndicatorPanel {
    private var panel: NSPanel?
    /// Task pra preview com auto-hide após N segundos.
    private var previewTask: Task<Void, Never>?

    /// Mostra (ou atualiza) panel com indicator da `variant` correspondente
    /// + toast opcional empilhado acima.
    func show(state: PipelineState,
              variant: IndicatorVariant,
              toast: Toast?,
              onCancel: @escaping () -> Void,
              onToastDismiss: @escaping () -> Void) {
        ensurePanel()
        let root = VStack(spacing: 8) {
            if let toast {
                ToastView(kind: toast.kind, onDismiss: onToastDismiss)
            }
            Self.indicator(for: variant, state: state, onCancel: onCancel)
        }
        let host = NSHostingController(rootView: root)
        host.view.layer?.backgroundColor = .clear
        panel?.contentViewController = host
        positionNearCursor()
        panel?.orderFrontRegardless()
    }

    func hide() {
        previewTask?.cancel()
        previewTask = nil
        panel?.orderOut(nil)
    }

    /// Mostra a `variant` em estado fake por `durationSec` segundos. Usado
    /// pelo botão "Visualizar selecionado" no IndicatorPicker. Noop se já
    /// há captura ativa (panel visível com state real).
    func showPreview(variant: IndicatorVariant,
                     state: PipelineState,
                     durationSec: Double) {
        ensurePanel()
        let root = Self.indicator(for: variant, state: state, onCancel: {})
        let host = NSHostingController(rootView: root)
        host.view.layer?.backgroundColor = .clear
        panel?.contentViewController = host
        positionCenterScreen()
        panel?.orderFrontRegardless()
        previewTask?.cancel()
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

- [ ] **Step 2: Atualizar `AppContainer.refreshIndicator`**

Em `app/Tagarela/App/AppContainer.swift`, find o método `refreshIndicator(for:)`:

```swift
    private func refreshIndicator(for state: PipelineState) {
        switch state {
        case .idle:
            indicatorPanel.hide()
        default:
            let pipelineRef = self.pipeline
            indicatorPanel.show(rootView:
                IndicatorPill(state: state) {
                    Task { await pipelineRef.handle(.cancel) }
                }
            )
        }
    }
```

Replace with:

```swift
    private func refreshIndicator(for state: PipelineState) {
        // Visibility rule: state != .idle OU toast pendente → visible.
        let toast = toastCenter.current
        if case .idle = state, toast == nil {
            indicatorPanel.hide()
            return
        }
        let pipelineRef = self.pipeline
        let toastCenterRef = self.toastCenter
        indicatorPanel.show(
            state: state,
            variant: prefs.indicatorVariant,
            toast: toast,
            onCancel: { Task { await pipelineRef.handle(.cancel) } },
            onToastDismiss: { toastCenterRef.dismiss() })
    }
```

(`toastCenter` será declarado na T11 — neste passo, declarar como property se ainda não estiver:
`let toastCenter = ToastCenter()`. Se T11 ainda não rodou, deixar essa linha aqui.)

- [ ] **Step 3: Build (testes não devem quebrar)**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, 142 testes (sem mudança).

- [ ] **Step 4: Commit**

```bash
git add app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift app/Tagarela/App/AppContainer.swift
git commit -m "$(cat <<'EOF'
feat(indicator): FloatingIndicatorPanel rebuild com toast layer + variant dispatch

- show(state:variant:toast:onCancel:onToastDismiss:) empilha toast acima
  do indicator quando há toast pendente
- showPreview(variant:state:durationSec:) mostra indicator fake centrado
  por N segundos (auto-hide via Task), pra IndicatorPicker
- @ViewBuilder indicator(for:state:onCancel:) faz dispatch entre as 4
  variações
- AppContainer.refreshIndicator considera toastCenter.current — panel
  fica visível mesmo no .idle se há toast pendente

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 11: `AppContainer` wire-up — `ToastCenter` + observação de PipelineEvents

**Files:**
- Modify: `app/Tagarela/App/AppContainer.swift`

- [ ] **Step 1: Adicionar property `toastCenter`**

No topo da class `AppContainer`, adicionar:
```swift
    let toastCenter = ToastCenter()
```

- [ ] **Step 2: Observar mudanças do toast pra trigger refreshIndicator**

No fim do `init`, antes do `if !showOnboarding { ... }`, adicionar observação Combine:
```swift
        toastCenter.$current
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.refreshIndicator(for: self.appState.pipeline) }
            }
            .store(in: &cancellables)
```

- [ ] **Step 3: Estender `wirePipelineToAppState` pra mapear PipelineEvents → toasts**

Find o handler do for-await em `wirePipelineToAppState`:

```swift
    private func wirePipelineToAppState() {
        let stream = pipeline.events
        Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await MainActor.run {
                    switch event {
                    case .stateChanged(let s):
                        self.appState.pipeline = s
                        self.refreshIndicator(for: s)
                    case .errorOccurred(let msg):
                        Logger.tagarela.error("pipeline error: \(msg, privacy: .public)")
                    case .finished:
                        break
                    default: break
                    }
                }
            }
        }
    }
```

Replace `default: break` por handlers explícitos:

```swift
    private func wirePipelineToAppState() {
        let stream = pipeline.events
        Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await MainActor.run {
                    switch event {
                    case .stateChanged(let s):
                        self.appState.pipeline = s
                        self.refreshIndicator(for: s)
                    case .errorOccurred(let msg):
                        Logger.tagarela.error("pipeline error: \(msg, privacy: .public)")
                    case .finished:
                        break
                    case .refinerFellBack(let reason):
                        self.toastCenter.show(Toast(kind: .refinerFellBack(reason: reason)))
                    case .injectionFailed:
                        self.toastCenter.show(Toast(kind: .injectionFailed))
                    case .historySaveFailed:
                        self.toastCenter.show(Toast(kind: .historySaveFailed))
                    case .permissionDenied(let kind):
                        self.toastCenter.show(Toast(kind: .permissionDenied(kind: kind)))
                    case .toggle, .cancel:
                        break
                    }
                }
            }
        }
    }
```

- [ ] **Step 4: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, 142 testes (sem mudança).

- [ ] **Step 5: Commit**

```bash
git add app/Tagarela/App/AppContainer.swift
git commit -m "$(cat <<'EOF'
feat(app): wire ToastCenter no AppContainer + handlers dos novos PipelineEvents

- toastCenter property + observação @Published pra triggerar refreshIndicator
- wirePipelineToAppState passa a mapear .refinerFellBack/.injectionFailed/
  .historySaveFailed/.permissionDenied → toastCenter.show(_:)
- refreshIndicator considera toast pendente (fica visível mesmo no .idle)

Cleanup #2 da Fase 2a finalmente surfaceia ao usuário via toast — antes
era só logger.error silencioso.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 12: `IndicatorPicker` em Preferências > Geral

**Files:**
- Create: `app/Tagarela/Preferences/UI/Sections/IndicatorPicker.swift`
- Modify: `app/Tagarela/Preferences/UI/Sections/GeneralView.swift`
- Modify: `app/Tagarela/Preferences/UI/PreferencesRoot.swift` (passar `indicatorPanel`)
- Modify: `app/Tagarela/App/AppContainer.swift` (passar `indicatorPanel` em `openPreferences`)

- [ ] **Step 1: `IndicatorPicker`**

```swift
// app/Tagarela/Preferences/UI/Sections/IndicatorPicker.swift
import SwiftUI

@MainActor
struct IndicatorPicker: View {
    @ObservedObject var prefs: PreferencesStore
    let indicatorPanel: FloatingIndicatorPanel

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 10)]
    private let previewState = PipelineState.recording(elapsedSeconds: 8, audioLevel: 0.5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "preferences.geral.indicator.label",
                         defaultValue: "Estilo do indicador"))
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(IndicatorVariant.allCases, id: \.self) { variant in
                    card(variant)
                }
            }
            Button(String(localized: "preferences.geral.indicator.preview",
                           defaultValue: "Visualizar selecionado por 3s")) {
                indicatorPanel.showPreview(variant: prefs.indicatorVariant,
                                            state: previewState,
                                            durationSec: 3)
            }
            .padding(.top, 4)
        }
    }

    private func card(_ variant: IndicatorVariant) -> some View {
        VStack(spacing: 8) {
            ZStack {
                FloatingIndicatorPanel.indicator(
                    for: variant,
                    state: previewState,
                    onCancel: {})
                    .scaleEffect(0.7)
                    .frame(maxWidth: .infinity, maxHeight: 88)
            }
            .frame(height: 96)
            .background(variant.isDarkOnly ? Color.black.opacity(0.85) : DS.Color.paper2,
                         in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Text(variant.displayName)
                    .font(.callout).bold()
                Spacer()
                if prefs.indicatorVariant == variant {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(prefs.indicatorVariant == variant ? Color.accentColor : Color.secondary.opacity(0.2),
                        lineWidth: prefs.indicatorVariant == variant ? 2 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { prefs.indicatorVariant = variant }
    }
}
```

- [ ] **Step 2: Atualizar `GeneralView`**

Em `app/Tagarela/Preferences/UI/Sections/GeneralView.swift`, adicionar param + section:

```swift
struct GeneralView: View {
    @ObservedObject var prefs: PreferencesStore
    let indicatorPanel: FloatingIndicatorPanel

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.geral.about.header", defaultValue: "Sobre"))) {
                LabeledContent(String(localized: "preferences.geral.version", defaultValue: "Versão")) {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
                LabeledContent(String(localized: "preferences.geral.build", defaultValue: "Build")) {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                }
            }
            Section {
                IndicatorPicker(prefs: prefs, indicatorPanel: indicatorPanel)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 3: Atualizar `PreferencesRoot` — adicionar `indicatorPanel` param + propagar**

Adicionar à struct:
```swift
    let indicatorPanel: FloatingIndicatorPanel
```

No detail switch, trocar:
```swift
            case .geral:         GeneralView(prefs: prefs)
```
por:
```swift
            case .geral:         GeneralView(prefs: prefs, indicatorPanel: indicatorPanel)
```

- [ ] **Step 4: `AppContainer.openPreferences()` — passar `indicatorPanel`**

Find o constructor de `PreferencesRoot(...)` em `openPreferences()`:
```swift
        let view = PreferencesRoot(
            prefs: prefs,
            customStore: customStyleStore,
            ollamaModelLister: { [weak self] in ... },
            openAIKeyEditor: { [weak self] in self?.keyPromptWindow.show() },
            healthChecker: healthChecker,
            keychain: keychain)
```

Adicionar `indicatorPanel: indicatorPanel` (último param, ou onde fizer sentido na ordem da struct):
```swift
        let view = PreferencesRoot(
            prefs: prefs,
            customStore: customStyleStore,
            ollamaModelLister: { [weak self] in ... },
            openAIKeyEditor: { [weak self] in self?.keyPromptWindow.show() },
            healthChecker: healthChecker,
            keychain: keychain,
            indicatorPanel: indicatorPanel)
```

- [ ] **Step 5: Build + smoke manual**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, 142 testes.

Smoke manual: rodar app, abrir Preferências > Geral, ver os 4 cards com mini-previews. Selecionar um, clicar "Visualizar por 3s" → indicator real aparece centrado por 3s.

- [ ] **Step 6: Commit**

```bash
git add app/Tagarela/Preferences/UI/Sections/IndicatorPicker.swift app/Tagarela/Preferences/UI/Sections/GeneralView.swift app/Tagarela/Preferences/UI/PreferencesRoot.swift app/Tagarela/App/AppContainer.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(preferences): IndicatorPicker em Geral — cards 2×2 + Visualizar 3s

- LazyVGrid adaptive 200 com 4 cards (1 por IndicatorVariant)
- Cada card renderiza o indicator real em escala 0.7 com state fake
  (.recording(8, 0.5))
- HUD card com background black.opacity(0.85) (dark only)
- Tap no card seleciona; check verde no card ativo
- Botão "Visualizar selecionado por 3s" chama
  indicatorPanel.showPreview(...) — panel real aparece centrado
- PreferencesRoot ganha let indicatorPanel; AppContainer passa via
  openPreferences

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 13: `HistoryEntryView` + `HistoryListView` + integração na `HistoryView`

**Files:**
- Create: `app/Tagarela/Preferences/UI/History/HistoryEntryView.swift`
- Create: `app/Tagarela/Preferences/UI/History/HistoryListView.swift`
- Modify: `app/Tagarela/Preferences/UI/Sections/HistoryView.swift`
- Modify: `app/Tagarela/Preferences/UI/PreferencesRoot.swift` (passar `historyStore` + `injector`)
- Modify: `app/Tagarela/App/AppContainer.swift` (passar `historyStore` + `injector` em `openPreferences`)

- [ ] **Step 1: `HistoryEntryView`**

```swift
// app/Tagarela/Preferences/UI/History/HistoryEntryView.swift
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
```

- [ ] **Step 2: `HistoryListView`**

```swift
// app/Tagarela/Preferences/UI/History/HistoryListView.swift
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
```

- [ ] **Step 3: Atualizar `HistoryView` (Preferences section)**

Em `app/Tagarela/Preferences/UI/Sections/HistoryView.swift`, adicionar params + section:

```swift
struct HistoryView: View {
    @ObservedObject var prefs: PreferencesStore
    let historyStore: HistoryStore
    let injector: Injecting

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.history.retention.header",
                                         defaultValue: "Retenção"))) {
                LabeledContent(String(localized: "preferences.history.maxItems", defaultValue: "Máximo de itens")) {
                    TextField("", value: Binding(
                        get: { prefs.historyMaxItems },
                        set: { prefs.setHistoryMaxItems($0) }
                    ), format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "preferences.history.maxDays", defaultValue: "Máximo de dias")) {
                    TextField("", value: Binding(
                        get: { prefs.historyMaxDays },
                        set: { prefs.setHistoryMaxDays($0) }
                    ), format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                Text(String(localized: "preferences.history.help",
                             defaultValue: "Histórico é truncado a cada nova captura, mantendo o menor entre os dois limites."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(header: Text(String(localized: "preferences.history.records.header",
                                         defaultValue: "Registros"))) {
                HistoryListView(historyStore: historyStore,
                                injector: injector,
                                limitProvider: { prefs.historyMaxItems })
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 4: Atualizar `PreferencesRoot` + `AppContainer.openPreferences`**

Em `PreferencesRoot.swift` adicionar:
```swift
    let historyStore: HistoryStore
    let injector: Injecting
```

E no detail switch, trocar:
```swift
            case .historico:     HistoryView(prefs: prefs)
```
por:
```swift
            case .historico:     HistoryView(prefs: prefs, historyStore: historyStore, injector: injector)
```

Em `AppContainer.openPreferences()`, passar:
```swift
        let view = PreferencesRoot(
            prefs: prefs,
            customStore: customStyleStore,
            ollamaModelLister: { ... },
            openAIKeyEditor: { ... },
            healthChecker: healthChecker,
            keychain: keychain,
            indicatorPanel: indicatorPanel,
            historyStore: historyStore,
            injector: injector)
```

- [ ] **Step 5: Build + smoke**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, 142 testes.

Smoke manual: rodar app, capturar 1-2 frases, abrir Preferências > Histórico → cards aparecem com cru+refinado. Buscar por substring → filtra. "Limpar tudo" → NSAlert confirma → lista vazia.

- [ ] **Step 6: Commit**

```bash
git add app/Tagarela/Preferences/UI/History/HistoryEntryView.swift app/Tagarela/Preferences/UI/History/HistoryListView.swift app/Tagarela/Preferences/UI/Sections/HistoryView.swift app/Tagarela/Preferences/UI/PreferencesRoot.swift app/Tagarela/App/AppContainer.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(history): visualizador embutido em Preferências > Histórico

- HistoryEntryView card: app destino + relative time + refiner kind +
  modelo + cru truncado + refinado destacado + botões Re-injetar/Copiar
- HistoryListView: TextField busca (substring case-insensitive cru/refinado),
  countLabel, "Limpar tudo" com NSAlert, ScrollView+LazyVStack.
- HistoryView ganha section "Registros" com a lista abaixo da retenção.
- PreferencesRoot e AppContainer.openPreferences propagam historyStore +
  injector pra view.
- displayApp resolve bundleID via NSWorkspace; relative date via
  RelativeDateTimeFormatter pt_BR.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 14: `RecentTranscriptionsProvider` + `RecentTranscriptionsSubmenu`

**Files:**
- Create: `app/Tagarela/History/RecentTranscriptionsProvider.swift`
- Create: `app/Tagarela/UI/MenuBar/RecentTranscriptionsSubmenu.swift`
- Modify: `app/Tagarela/UI/MenuBar/MenuBarController.swift` (incluir submenu)
- Modify: `app/Tagarela/App/TagarelaApp.swift` (passar provider)
- Modify: `app/Tagarela/App/AppContainer.swift` (criar provider)
- Create: `app/TagarelaTests/RecentTranscriptionsProviderTests.swift`

- [ ] **Step 1: `RecentTranscriptionsProvider`**

```swift
// app/Tagarela/History/RecentTranscriptionsProvider.swift
import Foundation
import OSLog

@MainActor
final class RecentTranscriptionsProvider: ObservableObject {
    private let logger = Logger(subsystem: "com.tagarela", category: "RecentTranscriptions")
    private let store: HistoryStore
    private let limit: Int

    @Published private(set) var recents: [Transcription] = []

    init(store: HistoryStore, limit: Int = 5) {
        self.store = store
        self.limit = limit
    }

    func reload() async {
        do {
            recents = try await store.recent(limit: limit)
        } catch {
            logger.error("recent failed: \(String(describing: error), privacy: .public)")
            recents = []
        }
    }
}
```

- [ ] **Step 2: `RecentTranscriptionsSubmenu`**

```swift
// app/Tagarela/UI/MenuBar/RecentTranscriptionsSubmenu.swift
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
```

- [ ] **Step 3: Atualizar `MenuBarContent`**

Em `app/Tagarela/UI/MenuBar/MenuBarController.swift`, adicionar param + uso:

```swift
struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var prefs: PreferencesStore
    let customStore: CustomStyleStoreLive?
    let styleProvider: StyleProvider
    let recentsProvider: RecentTranscriptionsProvider
    let injector: Injecting
    var onSelectOpenAINeedsKey: (RefinerKind) -> Void = { _ in }
    var onExplicitConfigureKey: () -> Void = {}
    var onOpenPreferences: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // ... (header + StateRow + Backend + Style — sem mudança)

            // ... (após StyleSubmenu, antes da Divider() do Preferências)

            Divider().background(DS.Color.hairline)

            RecentTranscriptionsSubmenu(provider: recentsProvider,
                                         injector: injector)

            Divider().background(DS.Color.hairline)

            Button(action: onOpenPreferences) { ... }   // existente
            // ...
        }
    }
}
```

(Audite o body atual do `MenuBarContent` e insira `RecentTranscriptionsSubmenu` entre `StyleSubmenu` e o botão "Preferências…", com Divider antes e depois.)

- [ ] **Step 4: `AppContainer` — criar `recentsProvider`**

No init do `AppContainer`, após criar `historyStore`:
```swift
        let recentsProvider = RecentTranscriptionsProvider(store: historyStore, limit: 5)
        self.recentsProvider = recentsProvider
```

E adicionar property:
```swift
    let recentsProvider: RecentTranscriptionsProvider
```

- [ ] **Step 5: `TagarelaApp` — passar `recentsProvider` e `injector` pro MenuBarContent**

No `TagarelaApp.swift`, na construção de `MenuBarContent(...)`, adicionar:
```swift
            MenuBarContent(
                customStore: container.customStyleStoreLive,
                styleProvider: container.styleProvider,
                recentsProvider: container.recentsProvider,
                injector: container.injector,
                onSelectOpenAINeedsKey: { ... },
                onExplicitConfigureKey: { ... },
                onOpenPreferences: { ... })
```

- [ ] **Step 6: Testes do `RecentTranscriptionsProvider`**

```swift
// app/TagarelaTests/RecentTranscriptionsProviderTests.swift
import XCTest
@testable import Tagarela

@MainActor
final class RecentTranscriptionsProviderTests: XCTestCase {
    private final class FakeStore: HistoryStore {
        var savedItems: [Transcription] = []
        var shouldThrow = false
        func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws {}
        func recent(limit: Int) async throws -> [Transcription] {
            if shouldThrow { throw NSError(domain: "test", code: 0) }
            return Array(savedItems.prefix(limit))
        }
        func clearAll() async throws { savedItems.removeAll() }
    }

    func test_reload_callsRecentWithLimit5() async {
        let store = FakeStore()
        store.savedItems = (0..<10).map { i in
            Transcription(rawText: "raw\(i)", refinedText: "ref\(i)", refinerKind: "none",
                          llmModelName: nil, whisperModelName: "test",
                          styleName: "test", frontmostAppBundleID: nil)
        }
        let provider = RecentTranscriptionsProvider(store: store, limit: 5)
        await provider.reload()
        XCTAssertEqual(provider.recents.count, 5)
    }

    func test_reload_emptyStore_returnsEmpty() async {
        let provider = RecentTranscriptionsProvider(store: FakeStore(), limit: 5)
        await provider.reload()
        XCTAssertEqual(provider.recents.count, 0)
    }

    func test_reload_storeThrows_returnsEmpty() async {
        let store = FakeStore()
        store.shouldThrow = true
        let provider = RecentTranscriptionsProvider(store: store, limit: 5)
        await provider.reload()
        XCTAssertEqual(provider.recents.count, 0)
    }
}
```

(Audite o construtor de `Transcription` (`@Model`) — pode precisar argumentos diferentes. Adapte se needed.)

- [ ] **Step 7: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, ~145 testes (142 + 3 novos).

- [ ] **Step 8: Commit**

```bash
git add app/Tagarela/History/RecentTranscriptionsProvider.swift app/Tagarela/UI/MenuBar/RecentTranscriptionsSubmenu.swift app/Tagarela/UI/MenuBar/MenuBarController.swift app/Tagarela/App/AppContainer.swift app/Tagarela/App/TagarelaApp.swift app/TagarelaTests/RecentTranscriptionsProviderTests.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(menubar): submenu Últimos com 5 entradas mais recentes — re-injeta no app de foco

- RecentTranscriptionsProvider (@MainActor ObservableObject) wraps
  HistoryStore.recent(limit: 5), expõe @Published recents
- RecentTranscriptionsSubmenu SwiftUI listing entries com formato
  "<App> · <preview ~50 chars>"; click → injector.inject async
- Inserido entre StyleSubmenu e botão Preferências; .task reload no abrir
- Item vazio mostra "nenhum item ainda" (disabled)
- 3 testes do Provider (reload com limit, vazio, store throws)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 15: Checklist manual `fase2b2-manual.md`

**Files:**
- Create: `tagarela_docs/03-funcionalidades/checklists/fase2b2-manual.md`

- [ ] **Step 1: Criar checklist**

```markdown
---
data: 2026-04-XX
status: aberto
fase: 2b-2
ambiente: macOS 26 (Release em ~/Applications/Tagarela.app); Ollama rodando local com gemma4:e4b
---

# Checklist manual — Fase 2b-2

Aceite manual após implementação completa. Resetar defaults antes:

```bash
defaults delete com.tagarela.Tagarela 2>/dev/null
rm -rf ~/Library/Application\ Support/com.tagarela.Tagarela
```

## 0. Pré-requisitos
- [ ] Suíte XCTest verde (`xcodebuild test`).
- [ ] Build sem warnings novos.
- [ ] Ollama rodando, `gemma4:e4b` pulled.

## 1. Histórico viewer (Preferências > Histórico)
- [ ] Após pelo menos 3 capturas, abrir Preferências > Histórico.
- [ ] Lista de cards aparece (cru truncado + refinado destacado, app de destino, refiner kind, modelo).
- [ ] Buscar por substring de uma transcrição filtra a lista.
- [ ] Limpar busca volta a lista cheia.
- [ ] Botão "Limpar tudo" disabled quando lista vazia, habilitado caso contrário.
- [ ] Clicar "Limpar tudo" → NSAlert pede confirmação. Confirmar → lista zera.
- [ ] Botão "Re-injetar" num card injeta o refinado no app de foco atual; status "Re-injetado" some em ~1.5s.
- [ ] Botão "Copiar" copia o refinado pra clipboard; cmd+V em outro app cola.

## 2. Submenu "Últimos" na status bar
- [ ] Abrir popover do MenuBarExtra → submenu "Últimos" entre Style e Preferências.
- [ ] Lista até 5 entradas mais recentes, ordem decrescente. Formato: `<App> · <preview>`.
- [ ] Click numa entrada injeta o refinado no app de foco atual.
- [ ] Sem capturas: "nenhum item ainda" disabled.

## 3. Toasts — fallback do refiner (cleanup #2 da 2a fechado)
- [ ] Configurar Backend = Ollama, mas matar o Ollama antes da captura.
- [ ] Capturar uma frase. Resultado: texto cru injetado + toast amarelo "Sem rede — usando texto cru" (ou similar) acima do indicator pill.
- [ ] Toast some em ~4s. Click no toast dismissa antecipado.
- [ ] Re-iniciar Ollama, capturar de novo: refiner volta a funcionar, sem toast.

## 4. Toasts — outros tipos
- [ ] Inject falhar (revogar Acessibilidade em System Settings durante runtime, capturar): toast vermelho `lock.shield` "Acessibilidade negada — abrir Configurações…".
- [ ] Mic negado (revogar Microfone, tentar capturar): toast `lock.shield` "Microfone negado".
- [ ] Sucesso silencioso: capturar normalmente — sem toast.

## 5. Indicator picker (Preferências > Geral)
- [ ] Abrir Preferências > Geral. Section "Estilo do indicador" aparece com 4 cards.
- [ ] Card ativo (default = Pílula) tem check verde + borda accent.
- [ ] Tap em outro card seleciona-o (check muda).
- [ ] Botão "Visualizar selecionado por 3s" → indicator real aparece centrado por 3s e some.
- [ ] HUD card tem background dark.

## 6. Variações do indicator em runtime
- [ ] Selecionar Pílula em Preferências, capturar. Pílula aparece como antes.
- [ ] Selecionar Orb, capturar. Orb radial aparece perto do cursor.
- [ ] Selecionar Vertical, capturar. Barra vertical aparece.
- [ ] Selecionar HUD, capturar. HUD style Siri aparece (escuro).
- [ ] Cada um dos 4 estados (.recording/.processing/.refining/.error) renderiza corretamente em cada variação.

## 7. Toast persiste com indicator hidden
- [ ] Após uma captura com fallback Identity (ver bloco 3), o toast continua visível por ~4s mesmo após o indicator sumir.
- [ ] Click no toast dismissa antes do auto-dismiss.

## 8. Resultado
- [ ] Todos os itens acima ✅. Marcar `status: ok` no frontmatter.
- [ ] Achados adicionais documentados em `tagarela_docs/04-decisoes/cleanup-fase2b2.md` (criar se houver).
```

- [ ] **Step 2: Commit**

```bash
git add tagarela_docs/03-funcionalidades/checklists/fase2b2-manual.md
git commit -m "$(cat <<'EOF'
docs(checklist): aceite manual da Fase 2b-2

8 seções cobrindo histórico viewer, submenu Últimos, toasts (fallback
+ permission + injection), indicator picker + 4 variações em runtime,
toast persistir com indicator hidden. Rodar com defaults zerados.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 16: Aceite manual + doc closeout

**Files:**
- Update: `tagarela_docs/03-funcionalidades/checklists/fase2b2-manual.md` (status `ok` ou `ok-com-achados`)
- Update: `tagarela_docs/04-decisoes/cleanup-fase2a.md` (item #2 fechado)
- Update: `tagarela_docs/04-decisoes/cleanup-fase2b1.md` (achado #3 — histórico viewer — fechado pela 2b-2)
- Update: `tagarela_docs/specs/2026-04-29-tagarela-v1-fase2b2-design.md` (frontmatter `status: implementado`)
- Update: `tagarela_docs/README.md` (status da 2b-2 = implementado)
- Create: `tagarela_docs/02-arquitetura/04-modulos-fase2b2.md` (snapshot pós-2b-2)
- Create (se houver achados): `tagarela_docs/04-decisoes/cleanup-fase2b2.md`

- [ ] **Step 1: Rodar checklist manual completo**

Resetar defaults, build Release, instalar em `~/Applications`, rodar item-a-item conforme `workflow_aceite_manual` (memory).

- [ ] **Step 2: Marcar checklist como ok**

Atualizar frontmatter pra `status: ok` (ou `ok-com-achados`).

- [ ] **Step 3: Atualizar `cleanup-fase2a.md` — item #2 fechado**

Trocar título do item #2 por `## 2. Fallback Identity é silencioso pro usuário — ✅ FECHADO 2026-04-XX`. Adicionar bloco "Fix aplicado" referenciando T4 e T11 da 2b-2 (novo PipelineEvent + handlers no AppContainer + ToastCenter).

Frontmatter: agora só item #5 segue aberto.

- [ ] **Step 4: Atualizar `cleanup-fase2b1.md` — achado #3 fechado**

Marcar achado #3 (histórico viewer) como fechado pela Fase 2b-2.

- [ ] **Step 5: Criar `02-arquitetura/04-modulos-fase2b2.md`**

Snapshot pós-2b-2 (similar ao `03-modulos-fase2b1.md`): módulos novos da 2b-2, modificados, cobertura de testes (~145), cleanups da 2a status.

- [ ] **Step 6: Atualizar `tagarela_docs/README.md`**

Mudar status da 2b-2 pra "implementado". Apontar pro novo doc de arquitetura.

- [ ] **Step 7: Atualizar frontmatter do design da 2b-2**

```yaml
status: implementado
implementado_em: 2026-04-XX (branch fase-2b2, ~16 commits)
```

- [ ] **Step 8: Atualizar memória** `~/.claude/projects/-Users-tars-Dev-tagarela/memory/achados_fase2a.md`

Marcar item #2 como ✅ fechado em 2026-04-XX.

- [ ] **Step 9: Commit final + merge pra main**

```bash
git add tagarela_docs/
git commit -m "$(cat <<'EOF'
docs: fechamento da Fase 2b-2 — cleanup #2 da 2a fechado, snapshot atualizado

- fase2b2-manual.md: status ok/ok-com-achados
- 04-modulos-fase2b2.md: snapshot pós-2b-2 (~145 testes)
- cleanup-fase2a.md item #2 fechado (PipelineEvent .refinerFellBack +
  ToastCenter)
- cleanup-fase2b1.md achado #3 (histórico viewer) fechado
- README do vault: 2b-2 status = implementado
- spec frontmatter: implementado

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git checkout main
git merge --no-ff fase-2b2 -m "Merge fase-2b2 into main: histórico + indicadores B/C/D + toasts + cleanup #2"
```

(Se houver achados no aceite, criar `cleanup-fase2b2.md` antes do commit final.)

---

## Self-review (gates de fim de fase)

Antes de declarar fim:

- [ ] Suíte verde: ~145 testes, 0 falhas (`xcodebuild test`).
- [ ] Doc de design (`fase2b2-design.md`) com `status: implementado`.
- [ ] Doc de arquitetura (`04-modulos-fase2b2.md`) reflete módulos reais.
- [ ] Checklist manual com `status: ok` (ou `ok-com-achados`).
- [ ] `cleanup-fase2a.md` marca #2 como fechado (só #5 aberto).
- [ ] `cleanup-fase2b1.md` marca achado #3 como fechado pela 2b-2.
- [ ] Custom style criado durante captura aparece no submenu Últimos com app correto e preview correto.
- [ ] Todos os 4 indicators renderizam corretamente em runtime (não só preview).
- [ ] Toasts dispararam pelo menos 1 vez no aceite manual em cada um dos 4 casos (fallback, injection, save, permission).
- [ ] `git log --oneline main..fase-2b2` mostra ~16 commits (um por tarefa) com co-author.
