---
data: 2026-04-29
fase: 2b-1
branch: fase-2b1
testes: 115 verdes (114 + 1 LocalizableKeysTests)
commits: 24 sobre main (47257ec..e7ed6ca)
---

# Snapshot — módulos pós-Fase 2b-1

Estado dos módulos do app após implementação completa da Fase 2b-1. Sucessor de [`02-stack-tecnica.md`](./02-stack-tecnica.md) e referência cumulativa do código atual.

## Sumário

A Fase 2b-1 entregou a janela de Preferências completa, custom styles via SwiftData, endpoints custom OpenAI, modelo Ollama com scan dinâmico, migração total de strings user-facing pra `Localizable.strings`, e bonus do cleanup #3 da Fase 2a (guard de raw curto no `OpenAIRefiner`).

## Módulos novos (Fase 2b-1)

### Refiner

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `OpenAIEndpoint` | `Refiner/OpenAIEndpoint.swift` | Struct `Codable, Hashable, Sendable` com `provider: OpenAIProvider, baseURL: URL`. Persistido em `UserDefaults` via `PreferencesStore.openAIEndpoint`. |
| `OpenAIProvider` | mesmo arquivo | Enum `String, CaseIterable`: `.official, .openrouter, .lmstudio, .custom`. |
| `OpenAIEndpointDefaults` | mesmo arquivo | Tabela `defaultURL(for:)` com baseURLs hardcoded por provider (custom retorna nil). |
| `OllamaModelLister` | `Refiner/OllamaModelLister.swift` | Actor que faz `GET /api/tags` (timeout 4s) e devolve lista parsed de modelos. Erros: `.offline`, `.malformedResponse`. Sem cache — refresh é manual. |
| `CustomStyle` | `Refiner/CustomStyle.swift` | `@Model` SwiftData (`id` `@Attribute(.unique)`, `name`, `systemPrompt`, `appendCodeSwitching`, `createdAt`, `updatedAt`). Método `asStyle()` converte pra `Style` consumível pelos refiners. |
| `CustomStyleStore` | `Refiner/CustomStyleStore.swift` | `@MainActor protocol` com CRUD (`reload`, `create`, `update`, `delete`). Typealias `OnStyleDeleted = @MainActor (UUID) -> Void` pro callback pós-delete. Erros: `.invalidInput`, `.persistenceFailed`. |
| `CustomStyleStoreLive` | `Refiner/CustomStyleStoreLive.swift` | Impl SwiftData. `@Published private(set) var styles`. Trim+validate em `create`. Callback de delete recebe ID pra caller (AppContainer) resetar `prefs.selectedStyleID`. |
| `CustomStyleStoreNoop` | `Refiner/CustomStyleStoreNoop.swift` | Fallback se `ModelContainer` falha; lista vazia, writes lançam `.persistenceFailed`. |
| `StyleProvider` | `Refiner/StyleProvider.swift` | `@MainActor` final class. Mescla `BuiltInStyles.all` + `customStore.styles.map(asStyle)` em lista única ordenada por nome (case-insensitive). Lookup em built-ins primeiro, depois custom. `styleOrDefault` cai pra `BuiltInStyles.conversaInformal`. |

### Preferences UI

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `PrefsSection` | `Preferences/UI/PrefsSection.swift` | Enum hierárquico (9 cases) com `label: String` localizado. |
| `PreferencesRoot` | `Preferences/UI/PreferencesRoot.swift` | View raiz com `NavigationSplitView`. Sidebar + detail switch sobre 9 sections. Recebe todas as dependencies via init. |
| `GeneralView` | `Preferences/UI/Sections/GeneralView.swift` | Read-only versão + build do bundle. |
| `RefinerGeneralView` | `Preferences/UI/Sections/RefinerGeneralView.swift` | Backend picker (radio Ollama/OpenAI/Sem LLM) + timeout. |
| `RefinerOllamaView` | `Preferences/UI/Sections/RefinerOllamaView.swift` | BaseURL + scan dinâmico (loading/error/picker states), refresh button, free-text fallback. Cancela `Task` inflight em onChange e refresh. |
| `RefinerOpenAIView` | `Preferences/UI/Sections/RefinerOpenAIView.swift` | Provider segmented picker (auto-fill baseURL via `OpenAIEndpointDefaults`), URL editável, modelo free-text, key masked + "Alterar…" reabre `OpenAIKeyPromptWindow`. |
| `StylesView` | `Preferences/UI/Sections/StylesView.swift` | LazyVGrid de cards. Built-ins read-only com badge "PRONTO", custom com botão ✎ + contextMenu Apagar (NSAlert), addCard dashed. Tap seleciona; CRUD via sheet. |
| `AudioView` | `Preferences/UI/Sections/AudioView.swift` | Slider clampado pra `audioBoostMaxGain` (1-50, step 1). |
| `HistoryView` | `Preferences/UI/Sections/HistoryView.swift` | Inputs numéricos `historyMaxItems`/`historyMaxDays` rotam por `setHistoryMaxItems/Days` (clamp >= 1). |
| `VocabularyView` | `Preferences/UI/Sections/VocabularyView.swift` | TextEditor multi-linha, split + trim por linha + filter empty no onChange. |
| `ShortcutsView` | `Preferences/UI/Sections/ShortcutsView.swift` | Read-only display: `⌥ direito` (toggle) + `Esc` (cancel). |
| `CustomStyleEditSheet` | `Preferences/UI/Sheets/CustomStyleEditSheet.swift` | Modal CRUD. Mode `.create` ou `.edit(CustomStyle)`. Form name+prompt+codeSwitching. Save disabled em whitespace-only. |
| `PreferencesWindow` | `App/PreferencesWindow.swift` | `@MainActor final class` que gerencia o `NSWindow`. `setFrameAutosaveName("PreferencesWindow")` (last-call ordering preservado). Min 600×400, default 720×520. |

### Tools

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `audit_strings.swift` | `tools/audit_strings.swift` | One-shot Swift script que grep'a hits potenciais de strings hardcoded. Apoia auditorias futuras de Localizable. |

## Módulos modificados (Fase 2b-1)

| Módulo | Mudança |
|---|---|
| `PreferencesStore` | Novo `@Published openAIEndpoint`. Setters clampados `setHistoryMaxItems/Days` (mirror de `setAudioBoostMaxGain`). |
| `PreferencesDefaults` | `openAIEndpoint` default = official + `https://api.openai.com/v1`. |
| `OpenAIRefiner` | `init` aceita `baseURL: URL` (não mais hardcoded). Adicionado `private static let minRawLengthToRefine = 8` + guard no início de `refine` que retorna `trimmed` se `< 8` chars (cleanup #3 da 2a). |
| `RefinerFactory` | `init` aceita `styleProvider: StyleProvider` como segundo param. `current()` consulta `styleProvider.styleOrDefault(for:)` em vez de `BuiltInStyles` direto. |
| `HistoryStoreLive` | Novo `init(container:)` non-throwing. Extension `static func sharedContainer() throws -> ModelContainer` com schema `[Transcription, CustomStyle]` na mesma URL `History.store`. `init() throws` agora delega pra `sharedContainer()`. |
| `AppContainer` | Cria `sharedContainer` SwiftData; ambos os stores caem em Noop se falha. Cria `customStyleStore` + `customStyleStoreLive` (downcast pra UI) + `styleProvider`. Closure de delete callback reseta `prefs.selectedStyleID`. Property `preferencesWindow` + `@MainActor func openPreferences()`. |
| `TagarelaApp` | `.commands { CommandGroup(replacing: .appSettings) { Button("Preferências…").keyboardShortcut(",") } }`. `MenuBarContent` recebe `customStore`, `styleProvider`, `onOpenPreferences`. |
| `MenuBarContent` | Novos params `customStore: CustomStyleStoreLive?`, `styleProvider: StyleProvider`, `onOpenPreferences`. Botão "Preferências…" antes do "sair" (entry point primário em accessory app). |
| `StyleSubmenu` | Consome `styleProvider.all`, observa `customStore` via `@ObservedObject` pra reactivity. `.id(stylesFingerprint)` força refresh do Menu cacheado. `StyleSubmenuStaticFallback` cobre o caso degenerado (sem customStore). |
| Strings em todos os UI files (Fases 1+2a+2b-1) | Migração mecânica: `Text("...")` → `String(localized: "key", defaultValue: "...")`. ~30 strings novas adicionadas a `Localizable.strings`; total ~112 keys. |

## Container SwiftData (single)

```
ModelContainer (em ~/Library/Application Support/com.tagarela.Tagarela/History.store)
 ├─ Transcription   (Fase 2a — history)
 └─ CustomStyle     (Fase 2b-1)
```

Single `init` no `AppContainer.init`. Falha → `HistoryStoreNoop` + `CustomStyleStoreNoop`.

## Cobertura de testes

| Suite | Testes | Notas |
|---|---|---|
| Pré-existentes (Fases 1+2a) | 81 | sem mudanças funcionais |
| Adições Fase 2b-1 | +34 | OpenAIEndpoint(3), OpenAIRefiner extensões(5: 3 base + 2 boundary), RefinerFactory extensão(1), OllamaModelLister(4), CustomStyle(4), CustomStyleStore(7), StyleProvider(6), PreferencesStore extensões(4: openAIEndpoint + clamps history), LocalizableKeysTests(1) |
| Total | **115 verdes** | |

## Cleanups da Fase 2a — status

- ✅ #1 Default Ollama thinking model — fechado em 2026-04-29 antes da 2b-1.
- ⏳ #2 Fallback Identity silencioso — empurrado pra 2b-2 (depende de toasts).
- ✅ #3 OpenAI conversacional em raw curto — **fechado pela T2 da 2b-1**.
- ✅ #4 Logs em stderr — fechado em 2026-04-29 antes da 2b-1.
- ⏳ #5 Cancel não cancela HTTP — empurrado pra 2b-3.

## Não implementados (vão pra próximas sub-fases)

**2b-2 (Histórico visível + Indicadores + Toasts):**
- Visualizador de histórico, menu "últimos 5", indicadores B/C/D, toasts, estados de permissão.
- Cleanup #2 da 2a (fallback Identity surfaceiado).

**2b-3 (Onboarding + Polimento):**
- Onboarding novo (LLM scan, key prompt no fluxo guiado).
- Re-bind real da hotkey, captura L/R Option.
- Cleanup #5 da 2a (cancel HTTP real via `Task.cancel()`).
- Tuning fino dos prompts dos built-in styles.

**Fora de escopo (sem fase definida):**
- Custom styles importáveis/exportáveis (JSON drag-drop).
- Edição em batch / drag-drop reorder.
- Provider Azure first-class.
- Modelo OpenAI com combobox curado.

## Limitações conhecidas (documentadas em 2b-1-design §5)

1. Azure entra via "URL custom" — sem lógica condicional Azure-específica.
2. Modelo OpenAI free-text (sem combobox curado).
3. Hotkey re-bind continua não-implementado.
4. NSAlert bloqueante em vez de toast (toasts vão pra 2b-2).
5. Cleanups #2 e #5 da 2a permanecem abertos.
