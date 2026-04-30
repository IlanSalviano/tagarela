---
data: 2026-04-29
fase: 2b-2
branch: fase-2b2
testes: 145 verdes (115 + 30 da fase 2b-2)
commits: 19 sobre main
---

# Snapshot — módulos pós-Fase 2b-2

Estado dos módulos do app após implementação completa da Fase 2b-2. Sucessor de [`03-modulos-fase2b1.md`](./03-modulos-fase2b1.md).

## Sumário

A Fase 2b-2 entregou: visualizador de histórico embutido em Preferências > Histórico (com clear-all), submenu "Recentes" na status bar com re-injeção, sistema de toasts (`ToastCenter` + `ToastView` acima do indicator), 3 novas variações de indicator (Orb, Vertical, HUD) com picker visual em Preferências > Geral, novos `PipelineEvent` de sinalização (refinerFellBack, injectionFailed, historySaveFailed, permissionDenied), e fechamento do cleanup #2 da Fase 2a (fallback Identity surfaceiado).

## Módulos novos (Fase 2b-2)

### Toast

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `Toast` | `UI/Toast/Toast.swift` | Struct `Identifiable` `Sendable` com `id: UUID`, `kind: ToastKind`, `createdAt: Date`. |
| `ToastKind` | `UI/Toast/ToastKind.swift` | Enum: `.refinerFellBack(reason:)`, `.injectionFailed`, `.historySaveFailed`, `.permissionDenied(kind:)`. Computed `displayMessage`, `iconSystemName`, `tintColor`. Mensagens curtas (≤ ~52 chars) pra caber no card sem truncar. |
| `RefinerFallbackReason` | mesmo arquivo | Enum 8 cases: `.networkOffline, .timeout, .serverError(Int), .keyInvalid, .modelMissing, .ollamaUnreachable, .malformedResponse, .identityForced`. Init `init?(refinerError:)` mapeia `RefinerError` → reason; `.cancelled` retorna `nil` quando user-cancel real, mas `PipelineCoordinator` distingue (ver bullet abaixo). |
| `ToastCenter` | `UI/Toast/ToastCenter.swift` | `@MainActor ObservableObject` com `@Published var current: Toast?`. `show(_:)`, `dismiss()`, e auto-dismiss 4s via `Task` com `dismissIfStill(id:)` race-protection (ignora se outro toast tomou o slot). |
| `ToastView` | `UI/Toast/ToastView.swift` | SwiftUI render do toast (icon + message + tinted left bar). MaxWidth 380, padding 12×8, dsShadowPop. Tap = onDismiss. |
| `PermissionKind` | `Permissions/PermissionKind.swift` | Enum 3 cases (`.microphone, .accessibility, .inputMonitoring`) usado por `ToastKind.permissionDenied` e `PipelineEvent.permissionDenied`. |

### Indicator

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `IndicatorView` | `UI/Indicator/IndicatorView.swift` | Protocol `View` com init `(state: PipelineState, onCancel: @escaping () -> Void)`. Implementado por `IndicatorPill` (A, default), `IndicatorOrb` (B), `IndicatorVertical` (C), `IndicatorHUD` (D). |
| `IndicatorVariant` | `Preferences/IndicatorVariant.swift` | Enum 4 cases (`.pill .orb .vertical .hud`). `displayName` (localizado), `isDarkOnly` (true só em `.hud` — fundo preto). Persistido em `PreferencesStore.indicatorVariant`. |
| `IndicatorOrb` | `UI/Indicator/IndicatorOrb.swift` | Variação B — orb radial 92×92. Dot pulsante carmim, ring com waveform circular reagindo ao audio level, timer mono abaixo. |
| `IndicatorVertical` | `UI/Indicator/IndicatorVertical.swift` | Variação C — barra vertical 32×160. Dot pulsante topo, 8 barrinhas threshold-crescente (volume meter), timer rotacionado -90°. |
| `IndicatorHUD` | `UI/Indicator/IndicatorHUD.swift` | Variação D — HUD style Siri 300×80, dark only. Background preto 0.85, dot + waveform grande horizontal, label de estado, timer alinhado à direita. |

### Histórico (UI)

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `HistoryListView` | `Preferences/UI/History/HistoryListView.swift` | Lista paginada (limite = `prefs.historyMaxItems`). Reativa via `.onChange(of: limitProvider())`. Botão "Limpar tudo" com NSAlert confirm; chama `historyStore.clearAll()`. Estado vazio com mensagem. |
| `HistoryEntryView` | `Preferences/UI/History/HistoryEntryView.swift` | Card de entry: timestamp relativo, raw text, refined text, badge do `refinerKind` (cor por backend). |
| `RecentTranscriptionsProvider` | `History/RecentTranscriptionsProvider.swift` | `@MainActor` observer que mantém `@Published var recent: [Transcription]` com top-N most-recent (default N=5). Refresh via `reload()` + auto-refresh quando `historyStore` notifica mudança. |
| `RecentTranscriptionsSubmenu` | `UI/MenuBar/RecentTranscriptionsSubmenu.swift` | Submenu da status bar "Recentes ▶". Lista 5 entries (truncadas), tap injeta refined text via `injector.injectInForegroundApp`. Empty state mostra item disabled "Nenhuma recente". |

### Picker visual

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `IndicatorPicker` | `Preferences/UI/Sections/IndicatorPicker.swift` | LazyVGrid de 4 cards (1 por variant) — preview live com `previewState = .recording(8s, 0.5)`. Card = scaled-down indicator + label + checkmark se selecionado. Tap muda `prefs.indicatorVariant`. Botão "Visualizar selecionado por 3s" chama `indicatorPanel.showPreview`. Tamanho visual normalizado por variante (`previewVisualSize`) pra alinhar centros visuais. |

## Módulos modificados (Fase 2b-2)

| Módulo | Mudança |
|---|---|
| `PipelineEvent` | 4 novos cases: `.refinerFellBack(reason: RefinerFallbackReason)`, `.injectionFailed`, `.historySaveFailed`, `.permissionDenied(kind: PermissionKind)`. |
| `PipelineCoordinator` | `catch` do refine emite `.refinerFellBack(reason:)` antes de cair no `IdentityRefiner`. Distinção crítica: `catch RefinerError.cancelled where cancelled` é user-cancel real (Esc, sem fallback); `catch RefinerError.cancelled` sem a flag vira `RefinerFallbackReason.networkOffline` (cobre URLSession -999 quando remote termina conexão abruptamente, ex: `pkill ollama`). Erros de inject/history viram events `injectionFailed`/`historySaveFailed`. |
| `HistoryStore` (protocol) | Novo `clearAll() async throws`. Impl `Live` faz fetch all + `delete` + save; `Noop` no-op. |
| `FloatingIndicatorPanel` | Rebuild: `show(state:variant:toast:onCancel:onToastDismiss:)` aceita variant + toast layer; `showPreview(variant:state:durationSec:)` força mostrar X variant por N segundos (usado pelo picker); `static @ViewBuilder indicator(for:state:onCancel:)` resolve variant → IndicatorView. Toast renderiza acima do indicator pill com offset; tap dismissa. |
| `AppContainer` | `let toastCenter = ToastCenter()`. `wirePipelineToAppState` consome novos events: `.refinerFellBack(reason:)` → `toastCenter.show(.refinerFellBack(reason:))`; `.injectionFailed` → `toastCenter.show(.injectionFailed)`; `.historySaveFailed` → `toastCenter.show(.historySaveFailed)`; `.permissionDenied(kind:)` → `toastCenter.show(.permissionDenied(kind:))`. `refreshIndicator` considera `toastCenter.current` ao decidir mostrar/esconder o panel. `recentProvider: RecentTranscriptionsProvider` injetado no `MenuBarContent`. |
| `PreferencesStore` | Novo `@Published var indicatorVariant: IndicatorVariant`. Default `.pill`. |
| `PreferencesDefaults` | `indicatorVariant = .pill`. |
| `GeneralView` | Adicionada section "Indicador" com `IndicatorPicker`. |
| `HistoryView` (Preferences section) | Embute `HistoryListView` abaixo dos sliders de retenção (`historyMaxItems`/`historyMaxDays`). |
| `MenuBarContent` | Recebe `recentProvider`. Submenu "Recentes ▶" antes do "Estilo ▶". |
| `Localizable.strings` | +~22 keys novas (toasts, indicator variants, history viewer, recent submenu). |

## Cobertura de testes

| Suite | Testes | Notas |
|---|---|---|
| Pré-existentes (Fases 1+2a+2b-1) | 115 | sem mudanças funcionais |
| Adições Fase 2b-2 | +30 | ToastKind(2), ToastCenter(4), RefinerFallbackReason(3), PipelineCoordinator extensões(4: cancel-vs-network, refinerFellBack emit, identityForced, injectionFailed), HistoryStore.clearAll(2), HistoryListView(2), RecentTranscriptionsProvider(3), IndicatorVariant(2), FloatingIndicatorPanel.showPreview(2), AppContainer wirePipelineToAppState(4), LocalizableKeys 2b-2(2) |
| Total | **145 verdes** | |

## Cleanups da Fase 2a — status

- ✅ #1 Default Ollama thinking model — fechado em 2026-04-29 antes da 2b-1.
- ✅ #2 Fallback Identity silencioso — **fechado pela Fase 2b-2** (event + toast).
- ✅ #3 OpenAI conversacional em raw curto — fechado pela T2 da 2b-1.
- ✅ #4 Logs em stderr — fechado em 2026-04-29 antes da 2b-1.
- ⏳ #5 Cancel não cancela HTTP — empurrado pra 2b-3.

## Cleanups da Fase 2b-1 — status

- ✅ #1 Janela atrás do popover — fechado em 2026-04-29.
- ✅ #2 Custom style sem rewriter discipline — fechado em 2026-04-29.
- ✅ #3 Visualizador de histórico — **fechado pela Fase 2b-2**.
- ⏳ #4 Esc não cancela HTTP em vôo — referência ao cleanup #5 da 2a (2b-3).

## Não implementados (vão pra próximas sub-fases)

**2b-3 (Onboarding + Polimento):**
- Onboarding novo (LLM scan, key prompt no fluxo guiado).
- Re-bind real da hotkey, captura L/R Option.
- Cleanup #5 da 2a (cancel HTTP real via `Task.cancel()`).
- Tuning fino dos prompts dos built-in styles.

**Fora de escopo (sem fase definida):**
- Custom styles importáveis/exportáveis.
- Edição em batch / drag-drop reorder.

## Achados do aceite manual da 2b-2

Ver [`fase2b2-manual.md`](../03-funcionalidades/checklists/fase2b2-manual.md). Todos os 8 blocos verdes após fixes aplicados durante o aceite. Nenhum item ficou aberto pra cleanup.

Fixes nascidos do aceite (commitados em 2b-2):
- `99d174e` — `RefinerError.cancelled` sem user-cancel-flag = network drop, vira `networkOffline` (descoberto matando `ollama serve` durante refine).
- `22e0c2d` — `HistoryListView.onChange(of: limitProvider())` reativo a mudança de `historyMaxItems`.
- `53500aa` — bugs visuais do Bloco 6.5: toasts encurtadas, indicator picker com tamanho visual normalizado, IndicatorVertical com barras altura fixa, IndicatorHUD width 300, header explícito "Indicador" em GeneralView.
