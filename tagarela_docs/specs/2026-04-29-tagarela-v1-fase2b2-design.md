---
data: 2026-04-29
status: aprovado para implementação
fase: 2b-2 de 3 sub-fases da Fase 2b
goal: histórico visível + indicadores B/C/D + toasts + cleanup #2 da 2a + estados de permissão + menu "últimos 5"
---

# tagarela v1 — Fase 2b-2: Feedback visual + Histórico + Indicadores

Spec da segunda sub-fase da Fase 2b. Brainstorming de 2026-04-29 (mesma data da 2b-1, executada em sequência após o aceite manual da 2b-1).

> Regras de processo: ver [`/CLAUDE.md`](../../CLAUDE.md). Nada implementado sem ler doc; nada pronto sem doc atualizada.
>
> **Sub-fase antecessora:** [`2026-04-29-tagarela-v1-fase2b1-design.md`](./2026-04-29-tagarela-v1-fase2b1-design.md). 2b-1 entregou janela de Preferências completa, custom styles CRUD, endpoints custom OpenAI, modelo Ollama dinâmico, Localizable migration. Aceite manual fechou ok-com-achados ([`fase2b1-manual.md`](../03-funcionalidades/checklists/fase2b1-manual.md), [`cleanup-fase2b1.md`](../04-decisoes/cleanup-fase2b1.md)).
>
> **Estado pós-2b-1:** suíte de 116 testes verde; cleanups #1, #3, #4 da 2a fechados.

---

## 1. Visão e escopo

### 1.1 Goal

Dar ao usuário o feedback visual que falta na Fase 2b-1: visualizador de histórico (dentro de Preferências), menu "últimos 5" na status bar com re-injeção no app de foco, sistema de toasts anexado ao `FloatingIndicatorPanel`, fechamento do cleanup #2 da Fase 2a (fallback Identity surfaceiado), e implementação das 3 variações restantes do indicador (B/C/D) com picker visual em Preferências > Geral.

### 1.2 Exit criteria (pronto pra Fase 2b-3)

1. **Preferências > Histórico expandida**: retenção em cima + busca + lista de **cards** (cru + refinado sempre visíveis) + botão "Limpar tudo" com NSAlert. Lazy render via `LazyVStack`.
2. **Status bar popover ganha submenu "Últimos"** entre Style e Preferências. Cada item formato `<App> · <preview ~50 chars do refinado>`. Click re-injeta o `refinedText` no app de foco via `Injector` existente. **5 itens fixos.**
3. **Sistema `ToastCenter`** (`@MainActor` ObservableObject) emite toasts anexados ao `FloatingIndicatorPanel` (acima do pill). 4 types semânticos: `.refinerFellBack(reason:)`, `.injectionFailed`, `.historySaveFailed`, `.permissionDenied(kind:)`. Auto-dismiss 4s. Click dismissa antecipado. Sucesso silencioso.
4. **`PipelineCoordinator` emite eventos novos** pra disparar toasts:
   - `.refinerFellBack(reason:)` quando refiner remoto falha (cleanup #2 da 2a)
   - `.injectionFailed` quando `injector.inject` lança erro
   - `.historySaveFailed` quando store throwing
   - `.permissionDenied(kind:)` quando `audio.start()` ou `injector.inject` lança erro de permissão
5. **Indicadores B/C/D implementados** como protocolo `IndicatorView`. `IndicatorPill` (existente) já conforma. Novos: `IndicatorOrb`, `IndicatorVertical`, `IndicatorHUD`.
6. **`Preferences > Geral > Estilo do indicador`** mostra grid 2×2 de cards com mini-previews (usa `IndicatorView` real com state fake `.recording(3, 0.4)`) + botão **"Visualizar selecionado por 3s"** que dispara o panel real.
7. **Nova chave `prefs.indicatorVariant: IndicatorVariant`** (.pill default, .orb, .vertical, .hud). `FloatingIndicatorPanel` consulta prefs ao rebuildar.
8. **Cleanup #2 da 2a fechado**: pipeline emite `.refinerFellBack(reason:)` ANTES de cair em `IdentityRefiner`; toast aparece no pill durante refining/finish.
9. Suíte XCTest verde com **~22-32 testes novos** (total ~138-148).
10. Aceite manual via `tagarela_docs/03-funcionalidades/checklists/fase2b2-manual.md`.

### 1.3 Não-objetivos da 2b-2

Vão pra **2b-3**:
- Onboarding novo (LLM scan + key prompt no fluxo guiado).
- Re-bind real da hotkey, captura L/R Option.
- [Cleanup #5 da 2a](../04-decisoes/cleanup-fase2a.md#5-cancelamento-durante-refiner-não-interrompe-a-request-http) (cancel HTTP via `Task.cancel()`).
- Tuning fino dos prompts dos built-in styles.
- UX dedicada pro rewriter discipline (cleanup #2 da 2b-1) — toggle ou modo na sheet de edição.

**Sem fase definida:**
- Toast tappable com action automática (abrir System Settings/Preferências). 2b-2 ship com texto informativo apenas; click só dismissa.
- Indicador HUD (D) em light mode (ADR-0001 marcou como dark only).
- Refresh live do histórico viewer (nova captura atualizando a `HistoryView` aberta) — usuário precisa reabrir Preferências.

### 1.4 Decisões nucleares (do brainstorming 2026-04-29)

| # | Decisão | Alternativas consideradas |
|---|---|---|
| F2b2-1 | **Escopo monolítico** — 6 itens em uma sub-fase | Decompor em 2b-2a/2b-2b; 3 sub-fases |
| F2b2-2 | Histórico mora **dentro de Preferências > Histórico** (expande seção) | Janela própria lista única; janela própria lista+detail Mail-style |
| F2b2-3 | Linha do histórico = **card-like** (cru + refinado sempre visíveis) | Linha compacta + DisclosureGroup expansível; linha compacta + sheet modal |
| F2b2-4 | Histórico features = **busca + Limpar tudo + lazy render**, sem filtros | Tudo (busca+filtros+limpar); só lazy+limpar; outras combinações |
| F2b2-5 | Menu "últimos 5" click → **re-injeta no app de foco** | Copia pra clipboard; abre Preferências; submenu por item com 3 ações |
| F2b2-6 | Submenu "Últimos" entre Style e Preferências; formato `<App> · <preview>`; **5 fixo** | Configurável (1-10); sem app no formato |
| F2b2-7 | Toasts **anexados ao indicator pill** reusando FloatingIndicatorPanel | Stack flutuante no canto BR; banner persistente no popover |
| F2b2-8 | Toast scope = **silencioso na sucess**, toast só pra erros/fallbacks | Sucesso também tem toast; híbrido com captura curta inline |
| F2b2-9 | Indicator picker = **cards 2×2 com mini-previews + botão Visualizar** | Radio simples; radio + botão Visualizar (compromisso) |
| F2b2-10 | Permissão revogada runtime = **toast reativo na falha de captura** | Banner persistente no popover; ícone status bar muda + banner |
| F2b2-11 | Implementação das **4 variações do indicador já na 2b-2** (per ADR-0001) | Apenas Pill+Orb; deixar B/C/D pra v2 |
| F2b2-12 | `IndicatorView` é **protocol** com 4 conformances; `FloatingIndicatorPanel` faz switch via `prefs.indicatorVariant` | Enum-based dispatch; 4 NSPanels separados |
| F2b2-13 | Cleanup #2 da 2a fechado **via novo PipelineEvent `.refinerFellBack(reason:)`** | Modificar logger.error pra emitir toast; canal Combine separado |

### 1.5 Revisão parcial do ADR-0001

ADR-0001 da Fase 1 incluiu na lista de "mudanças de escopo recusadas" a aba **"Histórico" rica nas Preferências** (cru + refinado lado a lado). Aquela rejeição valia pra v1 enxuta da Fase 1.

**A 2b-2 reverte parcialmente**: ganha lista compacta (busca + cards cru+refinado + Limpar tudo) dentro da seção `Preferências > Histórico`. Não vira janela própria — fica embutida na seção que já existe (retenção). Decisão F2b2-2 + F2b2-3.

Registrar como nova ADR-0004 ("Histórico viewer dentro de Preferências") quando o spec for commitado.

---

## 2. Arquitetura

### 2.1 Princípios herdados

- Boundaries via protocolos. UI consome `ToastCenter` e `HistoryStore` (já protocolos).
- SwiftUI + AppKit cirúrgico. Toast vive **dentro do `FloatingIndicatorPanel`** (sem novo NSWindow).
- Strings novas em `Localizable.strings`. Convenção de chaves: `toast.*`, `history.*`, `preferences.geral.indicator.*`, `menubar.recent.*`.
- Sem novas SPMs.

### 2.2 Módulos novos

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `ToastKind` | `UI/Toast/ToastKind.swift` | Enum semântico: `.refinerFellBack(reason: RefinerFallbackReason)`, `.injectionFailed`, `.historySaveFailed`, `.permissionDenied(kind: PermissionKind)`. Inclui `displayMessage`, `iconSystemName`, `tintColor` por case. |
| `RefinerFallbackReason` | mesmo arquivo | Enum mapeado de `RefinerError` (existente): `.networkOffline`, `.unauthorized`, `.timedOut`, `.serverError(Int)`, `.malformedResponse`, `.modelNotFound(String)`, `.rateLimited`, `.contextExceeded`. (`RefinerError.cancelled` **não** entra — cancel real é fluxo distinto, sem toast.) |
| `PermissionKind` | `Permissions/PermissionKind.swift` | Enum novo: `.microphone`, `.accessibility`, `.inputMonitoring`. (`PermissionsSnapshot` existente usa fields nomeados; este enum é a versão "case" pra payload em `PipelineEvent.permissionDenied(kind:)` e `ToastKind.permissionDenied(kind:)`.) |
| `Toast` | `UI/Toast/Toast.swift` | `struct Identifiable Hashable` com `id: UUID`, `kind: ToastKind`, `createdAt: Date`. |
| `ToastCenter` | `UI/Toast/ToastCenter.swift` | `@MainActor ObservableObject`. `@Published var current: Toast?`. Métodos: `show(_:)` (substitui current, agenda auto-dismiss em 4s), `dismiss()`. Apenas 1 toast visível — overflow simplesmente substitui. |
| `ToastView` | `UI/Toast/ToastView.swift` | SwiftUI View pra um `Toast`. Estilo: paper bg + border-left tinted pelo `kind.tintColor`. Ícone systemName + texto + close button. |
| `HistoryEntryView` | `Preferences/UI/History/HistoryEntryView.swift` | Card pra um `Transcription`: app destino, timestamp relativo, refiner kind+modelo, cru pequeno + refinado destacado. Botões "Re-injetar" e "Copiar". |
| `HistoryListView` | `Preferences/UI/History/HistoryListView.swift` | `LazyVStack` consumindo `HistoryStore.recent(limit:)`. `@State query` filtra substring case-insensitive. Botão "Limpar tudo" + NSAlert. |
| `RecentTranscriptionsProvider` | `History/RecentTranscriptionsProvider.swift` | `@MainActor` final class. Wraps `HistoryStore.recent(limit: 5)`, expõe `@Published var recents`. Reload via `.task` do submenu. |
| `RecentTranscriptionsSubmenu` | `UI/MenuBar/RecentTranscriptionsSubmenu.swift` | SwiftUI submenu listando até 5 entries. Item formato `<frontmostAppDisplayName> · <previewRefinado>`. Click → `injector.inject(text:)`. |
| `IndicatorVariant` | `Preferences/IndicatorVariant.swift` | Enum `String, CaseIterable, Codable, Sendable`: `.pill`, `.orb`, `.vertical`, `.hud`. Inclui `displayName`, `isDarkOnly`. |
| `IndicatorView` | `UI/Indicator/IndicatorView.swift` | Protocol — `View` conforming + `init(state: PipelineState, onCancel: @escaping () -> Void)`. |
| `IndicatorOrb` | `UI/Indicator/IndicatorOrb.swift` | Variação B (radial 92×92). Nova. |
| `IndicatorVertical` | `UI/Indicator/IndicatorVertical.swift` | Variação C (barra vertical fina). Nova. |
| `IndicatorHUD` | `UI/Indicator/IndicatorHUD.swift` | Variação D (HUD style Siri, dark only). Nova. |
| `IndicatorPicker` | `Preferences/UI/Sections/IndicatorPicker.swift` | Sub-component da `GeneralView`. Grid 2×2 de cards (renderiza `IndicatorView` real com state fake). Botão "Visualizar por 3s" dispara `FloatingIndicatorPanel.showPreview(...)`. |

### 2.3 Módulos modificados

| Módulo | Mudança |
|---|---|
| `PreferencesStore` | Nova chave `@Published var indicatorVariant: IndicatorVariant`. JSON-encoded em UserDefaults (mesmo pattern de `openAIEndpoint`). |
| `PreferencesDefaults` | `indicatorVariant: IndicatorVariant = .pill`. |
| `PipelineEvent` | Novos cases: `.refinerFellBack(reason: RefinerFallbackReason)`, `.injectionFailed`, `.historySaveFailed`, `.permissionDenied(kind: PermissionKind)`. |
| `PipelineCoordinator` | Onde hoje cai em `IdentityRefiner` silencioso, agora também emite `.refinerFellBack(reason:)`. Onde `injector.inject` throwing, emite `.injectionFailed`. Onde `historyStore.save` throwing, emite `.historySaveFailed`. Permission denied detectado via tipos de erro (`AudioCaptureError.microphoneDenied`, equivalente do injector) → emite `.permissionDenied(kind:)`. |
| `AppContainer.wirePipelineToAppState` | Novo handler que mapeia eventos de erro/fallback do pipeline pro `ToastCenter.show(_:)`. |
| `FloatingIndicatorPanel` | Recebe `IndicatorVariant` + `ToastCenter` no rebuild. Renderiza `(toastView?, indicatorView)` empilhados. Visibility rule: `state != .idle` ou `toast != nil` → visible; ambos zerados → hide. |
| `MenuBarContent` | Adiciona `RecentTranscriptionsSubmenu(...)` entre `StyleSubmenu` e o botão "Preferências…". |
| `GeneralView` (Preferences) | Ganha sub-component `IndicatorPicker(prefs:, indicatorPanel:)`. Versão+Build continuam. |
| `HistoryView` (Preferences) | Expande pra incluir `HistoryListView` abaixo da retenção. Recebe `historyStore`, `injector`. |
| `HistoryStore` (protocol) | Novo método `clearAll() async throws`. Live implementa via fetch+delete loop. Noop ignora. |
| `PreferencesRoot` | Passa `historyStore`, `injector`, `indicatorPanel` pra views relevantes. |

### 2.4 Container de toasts (single instance)

`AppContainer` cria `let toastCenter = ToastCenter()` e injeta:
- Em `wirePipelineToAppState` pra observar PipelineEvents → `toastCenter.show(...)`
- Em `FloatingIndicatorPanel` pra renderizar
- Em `IndicatorPicker` indiretamente via `indicatorPanel.showPreview(...)`

---

## 3. Data flow

### 3.1 Histórico viewer

```
HistoryView(prefs:, historyStore:, injector:)
  └─ Section "Retenção" (existente — historyMaxItems/Days)
  └─ Search TextField (@State query)
  └─ HStack { count info | "Limpar tudo" } (NSAlert confirm → store.clearAll())
  └─ HistoryListView(historyStore:, injector:, query:)
       └─ .task { items = try await store.recent(limit: prefs.historyMaxItems) }
       └─ filtered = items.filter { $0.matches(query) }
       └─ LazyVStack { HistoryEntryView($0, injector:) }
```

`HistoryEntryView` card mostra (de cima pra baixo):
- Linha 1: `<App de destino>` · `<timestamp relativo>` · `<refiner kind>` · `<modelo se !cru>`
- Linha 2: `cru: <texto cru truncado em 200 chars>`
- Linha 3: `<refinado completo, multiline>` (destaque)
- Footer direita: botões `Re-injetar` (chama `injector.inject(text: refinedText)`) e `Copiar` (NSPasteboard)

Refresh: `HistoryListView` re-fetch quando `prefs.historyMaxItems` muda OU quando `query` muda. Nova captura **não** dispara refresh automático na view aberta — aceitável (limitação documentada §5).

### 3.2 Menu "últimos 5"

```
RecentTranscriptionsSubmenu(provider:, prefs:, injector:)
  └─ .task { provider.reload() }   // dispara HistoryStore.recent(limit: 5)
  └─ ForEach(provider.recents) { entry in
       Button(action: inject(entry)) {
         HStack {
           Text(entry.frontmostAppDisplayName).bold()
           Text(" · ")
           Text(entry.refinedTextPreview)   // ~50 chars
         }
       }
     }
  └─ se vazio: Text("nenhum item ainda").disabled(true)
```

Reload no `.task` re-fires no reabrir do popover. Stale entre reaberturas — aceito.

`inject(entry)` em Task. Erro → `.injectionFailed` no toast (mesmo path do pipeline normal). Sucesso silencioso.

### 3.3 ToastCenter pipeline

```
PipelineCoordinator.runTranscribeAndInject (trecho do refining):
  do {
      refined = try await refiner.refine(raw, style: style)
      actualRefinerKind = refiner.kind
  } catch RefinerError.cancelled {
      // cancelamento real, sem toast
  } catch {
      let reason = RefinerFallbackReason(refinerError: error)
      continuation?.yield(.refinerFellBack(reason: reason))    // NEW EVENT — fecha cleanup #2 da 2a
      logger.error("refiner failed (\(refiner.kind.rawValue)): \(error)")
      let identityFallback = IdentityRefiner()
      refined = (try? await identityFallback.refine(raw, style: style)) ?? raw
      actualRefinerKind = identityFallback.kind
  }
```

`AppContainer.wirePipelineToAppState` (handler novo):
```swift
case .refinerFellBack(let reason):
    toastCenter.show(Toast(kind: .refinerFellBack(reason: reason)))
case .injectionFailed:
    toastCenter.show(Toast(kind: .injectionFailed))
case .historySaveFailed:
    toastCenter.show(Toast(kind: .historySaveFailed))
case .permissionDenied(let kind):
    toastCenter.show(Toast(kind: .permissionDenied(kind: kind)))
```

`ToastCenter.show(_:)`:
```swift
func show(_ toast: Toast) {
    autoDismissTask?.cancel()
    current = toast
    autoDismissTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        guard !Task.isCancelled else { return }
        await self?.dismissIfStill(id: toast.id)
    }
}
```

### 3.4 FloatingIndicatorPanel render

```
FloatingIndicatorPanel.show(state:, variant:, toast:, onCancel:):
  let indicator = makeIndicator(variant: variant, state: state, onCancel: onCancel)
  let combined = VStack(spacing: 8) {
      if let toast { ToastView(kind: toast.kind, onDismiss: { toastCenter.dismiss() }) }
      indicator
  }
```

Visibility rule: `state != .idle` OU `toast != nil` → panel visível. Ambos zerados → hide. Quando state vai pra `.idle` mas toast pendente, panel fica visível mostrando só o toast até auto-dismiss.

`AppContainer.refreshIndicator` agora observa duas signals: `appState.pipeline` e `toastCenter.$current`.

### 3.5 IndicatorVariant + Picker

`prefs.indicatorVariant` controla a variação. `FloatingIndicatorPanel.makeIndicator`:

```swift
@ViewBuilder
func makeIndicator(variant: IndicatorVariant, state: PipelineState, onCancel: @escaping () -> Void) -> some View {
    switch variant {
    case .pill:     IndicatorPill(state: state, onCancel: onCancel)
    case .orb:      IndicatorOrb(state: state, onCancel: onCancel)
    case .vertical: IndicatorVertical(state: state, onCancel: onCancel)
    case .hud:      IndicatorHUD(state: state, onCancel: onCancel)
    }
}
```

**Visualizar selecionado por 3s** (botão no IndicatorPicker):
```swift
private func previewIndicator() {
    indicatorPanel.showPreview(variant: prefs.indicatorVariant,
                                state: .recording(elapsedSeconds: 3, audioLevel: 0.4),
                                durationSec: 3)
}
```

`FloatingIndicatorPanel.showPreview(variant:state:durationSec:)` é método novo — mostra o panel por N segundos com state fake e auto-hide. Guard: se `pipeline.state != .idle`, preview é noop (não interfere com captura real).

### 3.6 Permission denied — toast reativo

Quando `audio.start()` ou `injector.inject(...)` falha com erro de permissão, `PipelineCoordinator` detecta o tipo de erro e emite `.permissionDenied(kind:)`:

```swift
case .recording:
    do { try audio.start() }
    catch AudioCaptureError.microphoneDenied {
        continuation?.yield(.permissionDenied(kind: .microphone))
        setState(.error(message: "mic"))
    }
```

Toast `.permissionDenied(.microphone)`:
> ⚠️ Microfone negado. Abra Configurações do Sistema › Privacidade › Microfone.

Texto informativo. Click dismissa antecipado. Action automática (abrir System Settings) fica fora de escopo.

---

## 4. Estratégia de testes

### 4.1 Princípio (herdado)

XCTest puro, sem UI test runner. Lógica testável passa por seams. Views SwiftUI não são unit-tested — checklist manual.

### 4.2 Testes novos esperados (~22-32)

| Suite | Cobertura | Estimativa |
|---|---|---|
| `ToastCenterTests` | show substitui current; dismiss limpa; auto-dismiss em 4s; sequência rápida cancela timer anterior | 5-6 |
| `ToastKindTests` | displayMessage por case; iconSystemName; init from RefinerError | 4-5 |
| `RefinerFallbackReasonTests` | init from cada case do `RefinerError` (8 cases mapeados, `.cancelled` retorna nil) | 5-6 |
| `RecentTranscriptionsProviderTests` | reload chama recent(limit: 5); publishes via @Published; vazio quando store vazio | 3-4 |
| `HistoryStoreTests` (extensão) | `clearAll()` apaga todos; chamada em store vazio é no-op | 2 |
| `PipelineCoordinatorTests` (extensão) | refiner falha → emite `.refinerFellBack(reason:)`; inject throwing → `.injectionFailed`; save throwing → `.historySaveFailed`; mic denied → `.permissionDenied(.microphone)` | 4-5 |
| `IndicatorVariantTests` | Codable round-trip; isDarkOnly só em .hud; CaseIterable count = 4 | 3 |
| `PreferencesStoreTests` (extensão) | `indicatorVariant` default = .pill; persist round-trip | 1-2 |

**Total ~27-32.** Soma com 116 atuais → ~143-148. Critério: tudo verde antes de fechar.

### 4.3 Não testado em XCTest (manual via checklist)

- Layout do `HistoryEntryView`, `LazyVStack` virtualization com 200 itens, busca filtrando.
- "Limpar tudo" + NSAlert.
- `RecentTranscriptionsSubmenu` no popover (formato, ordem, click re-injeta).
- `IndicatorPicker` cards 2×2, "Visualizar por 3s" mostra indicator real.
- Cada uma das 4 indicators renderiza nos 4 states.
- Toast aparecendo acima do pill, posição, auto-dismiss em 4s, click dismissa.
- Toast persistir com indicator hidden (state .idle, toast pendente).
- Toast permissão aparece quando user revoga em System Settings durante runtime.

### 4.4 Regressão (rodar antes/depois)

Suíte completa pós-2b-1 deve continuar verde. Em particular:
- `PipelineCoordinatorTests.*` — adaptar pra novos events emit.
- `PreferencesStoreTests.test_defaults_match_designV1` — adicionar `indicatorVariant` assertion.

---

## 5. Limitações conhecidas e débitos abertos

1. **Toast tappable com action automática** — clicar não abre Preferências/System Settings. Texto informativo. Action automática fica pra futuro.
2. **HUD (D) é dark-only** (per ADR-0001). Em light mode pode ficar baixo contraste — aceito.
3. **Refresh do histórico viewer não é live**: nova captura não atualiza a `HistoryView` aberta. User reabre Preferências.
4. **Recents stale no menubar** se popover ficar aberto por muito tempo — `.task` re-fires no reabrir.
5. **Cleanup #5 da 2a** (cancel HTTP via `Task.cancel()`) segue aberto — fica pra 2b-3.
6. **Cleanup #2 da 2b-1** (rewriter discipline UX dedicada) segue aberto — fica pra 2b-3.
7. **Toast rate limiting / debounce** — não implementado. Captura que falha 5x em sequência mostra 5 toasts substituindo um ao outro. Aceito (raro na prática).

---

## 6. Roadmap pós-2b-2

- **2b-3** — Onboarding completo + Re-bind hotkey + Cleanup #5 + Tuning fino dos prompts (incluindo evolução do rewriter discipline pra UX dedicada).
- **3** (futuro) — features extras do design v1 ainda não destrinchadas (multi-idioma, profiles, backups, etc).
