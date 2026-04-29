# Módulos implementados na Fase 1

Snapshot do que existe no código ao fim da Fase 1. Atualizar conforme drift acontece.

## Implementados

| Módulo | Arquivo principal | Responsabilidade |
|---|---|---|
| AppState | `App/AppState.swift` | ObservableObject com PipelineState (5 estados) |
| AppContainer | `App/AppContainer.swift` | Composition root + wire-up + gating de onboarding + ensureMicPermission (multi-fallback) |
| DesignSystem | `Design/DesignSystem.swift` | Color/Font/Radius/Shadow tokens |
| Wordmark, Glyph | `Design/{Wordmark,Glyph}.swift` | Identity views (Glyph não é mais usado na status bar — substituído por Image asset) |
| StatusBar icon | `Resources/Assets.xcassets/StatusBar{Template,Recording}.imageset` | PDF vetorial do bundle Quote (template + colored recording state) |
| PermissionService | `Permissions/` | mic / accessibility / input monitoring (poll 1s) |
| HotkeyService | `Hotkey/` | CGEventTap p/ Option (toggle) + Esc (cancel); só checa Input Monitoring (Accessibility é validado no Injector) |
| AudioCapturing | `Audio/` | AVAudioEngine no formato nativo do device + downmix/resample manual no stop + peak-normalize boost (até 20×) |
| Transcribing (WhisperKit) | `Transcription/` | load model + transcribe pt-BR via WhisperKit 0.18.0 |
| InitialPromptBuilder | `Transcription/` | monta initialPrompt com vocab + truncamento (não usado no transcribe ainda — ver cleanup-fase1) |
| TextRefiner (Identity) | `Refiner/` | passa texto cru direto |
| Injecting | `Injection/` | clipboard save → ⌘V → restore (250ms); checa Accessibility |
| PipelineCoordinator | `Pipeline/` | actor com 5 estados; ticka audioLevel + elapsedSeconds a cada 80ms enquanto recording; recovery automática de .error → .idle no próximo toggle |
| MenuBarContent + StateRow | `UI/MenuBar/` | dropdown da status bar |
| FloatingIndicatorPanel + IndicatorPill (A) + WaveBars | `UI/Indicator/` | indicador flutuante variação A |
| Onboarding (Welcome + Perms + Model) | `UI/Onboarding/` | primeira execução |

## Divergências do plano original

Anotadas em commits e [`cleanup-fase1.md`](../04-decisoes/cleanup-fase1.md):

- **Geração do projeto via xcodegen** (vs Xcode UI) — `app/project.yml` é fonte da verdade. Documentado em [`02-stack-tecnica.md`](./02-stack-tecnica.md).
- **WhisperKit 0.18.0 API mudou** — `WhisperKit.download(variant:progressCallback:)` static + init com `WhisperKitConfig(modelFolder:load:)`.
- **Detecção L/R do Option** — filtro pelo keyCode 0x3D já restringe ao Right Option na prática (validar empiricamente em sessão de teste — cleanup-fase1 item 1).
- **`initialPrompt` ainda não vira `promptTokens`** — string construída mas descartada; só `usePrefillPrompt: true` é setado. TODO em `cleanup-fase1` item 2.
- **Protocols Audio/Transcribing/Refiner/Injecting marcados Sendable** — necessário pra `actor PipelineCoordinator` chamar métodos deles em Swift 5.10 com strict concurrency complete.
- **`AppContainer: ObservableObject` adiantado** — plano colocava na Task 29, antecipei pra Task 11 pra suportar `@StateObject` no `TagarelaApp`.
- **Fontes via `type: folder` no xcodegen** — pra preservar `Resources/Fonts/` no bundle (ATSApplicationFontsPath = "Fonts").
- **`Glyph` da status bar substituído por PDF vetorial** — bundle Quote do Claude Design (StatusBarTemplate.imageset com `template-rendering-intent` + StatusBarRecording colored). Glyph SwiftUI Canvas continua no código mas não é mais referenciado na MenuBarExtra.
- **Code signing manual com Apple Development cert estável** — `CODE_SIGN_STYLE: Manual` + `CODE_SIGN_IDENTITY` com SHA1 do cert Mac Development. Evita CDHash mudar a cada rebuild (que invalidava TCC silenciosamente). Aplicado tanto ao app quanto ao test target.
- **AX gate removido do `HotkeyService.start()`** — `CGEvent.tapCreate(.listenOnly)` precisa só de Input Monitoring; AX é validado quando o Injector tenta postar `⌘V`. Permite hotkey funcionar mesmo enquanto user ainda não concedeu Accessibility.
- **Audio capture sem `AVAudioConverter` streaming** — converter engasgava após 1 buffer no setup C920 + macOS 26. Tap acumula samples por canal em `channelBuffers: [[Float]]`; downmix + resample acontecem em batch no `stop()`. Detalhes no item 5 do `cleanup-fase1`. Bug de embaralhamento na versão `[Float]` linear inicial corrigido em 2026-04-27 (mesmo item).
- **Software peak-normalize gain (até 20×)** — C920 entrega peak ~0.07 em fala normal; sem boost, Whisper transcreve como `...`. Aplicado depois do resample. Item 4 do `cleanup-fase1`.
- **Stderr instrumentation em runtime** — `FileHandle.standardError.write(...)` em vários módulos foi crítico durante o stress test. Deve virar `Logger.tagarela` antes da Fase 2 (cleanup-fase1 item 3).
- **TCC permissions injetadas via SQL** — popups nativos de Mic/Camera nunca apareceram pra Tagarela com signing Apple Development + LSUIElement + USB-only mic (C920). Workaround: `INSERT INTO ~/Library/.../TCC.db SELECT ... csreq FROM access WHERE client = 'com.tagarela.Tagarela'`, clonando o BLOB de assinatura de uma entry pré-existente. Detalhes no item 6 do cleanup-fase1.
- **NSCameraUsageDescription adicionado** ao Info.plist mesmo o app não usar câmera — porque webcams USB combinadas (C920) podem exigir Camera grant pra liberar o áudio.

## Cobertura de testes (XCTest)

81 testes verdes (último run: 2026-04-27, após Fase 2a Tarefa 10):

- **HotkeyTests** — default, codable, virtualKeyCode, displayLabel (4)
- **PermissionServiceTests** — allGranted true/false, status codable (3)
- **InitialPromptBuilderTests** — empty vocab, with vocab, truncation (3)
- **IdentityRefinerTests** — passthrough, kind (2)
- **InjectorTests** — error equatable (1)
- **PipelineCoordinatorTests** — idle→toggle→recording, recording→toggle→idle, recording→cancel→idle, refiner fails→identity fallback, cancel error→no finished, identity→skip refining, success saves history, cancel não salva history (8 — usando fakes Sendable)
- **PreferencesStoreTests** — (Fase 2a Tarefa 1)
- **KeychainServiceTests** — (Fase 2a Tarefa 2)
- **StyleTests** — (Fase 2a Tarefa 3)
- **RefinerErrorMapperTests** — (Fase 2a Tarefa 4)
- **TokenCounterTests** — (Fase 2a Tarefa 4)
- **OpenAIRefinerTests** — (Fase 2a Tarefa 5)
- **OllamaRefinerTests** — (Fase 2a Tarefa 6)
- **RefinerFactoryTests** — (Fase 2a Tarefa 8)
- **RemoteRefinerConfigTests** — (Fase 2a Tarefa 4)
- **HistoryStoreTests** — save persiste, recent newest-first, retention by count, retention by days (escopo do store), retention ambos limites, retention imediato (6 — Fase 2a Tarefa 10)

UI/visual fica no [`fase1-manual.md`](../03-funcionalidades/checklists/fase1-manual.md).

## Validação end-to-end (sessão 2026-04-27)

Pipeline completo confirmado funcionando em Mac mini M4 + Logitech C920:

```
[hotkey] flagsChanged keyCode=61 (Right Option)        ← user aperta ⌥
[pipeline] toggle in state=idle
[audio] start: mic auth=3                              ← granted
[audio] inFormat sampleRate=48000.0 channels=2        ← C920 detectado
[audio] engine started successfully
... 8.9s de fala ...
[hotkey] flagsChanged keyCode=61 (Right Option)        ← user aperta ⌥ de novo
[audio] stop: raw=854400 samples (48kHz 2ch) → resampled=142400 (16kHz mono) peak before=0.07 after=0.6
[pipeline] transcribed: 'Que eu vou dar ele de dar isso. Vai.'
[pipeline] injected to com.google.antigravity         ← texto colou no app destino
```

Qualidade de transcrição depende de input volume + ambiente — peak normalize ajuda mas não substitui condições adequadas.

## Implementado na Fase 2a (até Tarefa 10)

| Módulo | Arquivo principal | Responsabilidade |
|---|---|---|
| PreferencesStore | `Preferences/PreferencesStore.swift` | UserDefaults wrapper com @Published pra Combine |
| Preferences+Defaults | `Preferences/Preferences+Defaults.swift` | Defaults centralizados (historyMaxItems=200, historyMaxDays=30, etc.) |
| KeychainService | `Preferences/KeychainService.swift` + `KeychainServiceLive.swift` | Protocol + Security.framework wrapper pra API key |
| Style + BuiltInStyles | `Refiner/Style.swift` + `BuiltInStyles.swift` | 4 estilos built-in (cru, conversa informal, texto formal, notas técnicas) |
| RefinerError | `Refiner/RefinerError.swift` | Enum semântico de erros de refiner |
| RefinerErrorMapper | `Refiner/RefinerErrorMapper.swift` | URLError + HTTP status → RefinerError |
| TokenCounter | `Refiner/TokenCounter.swift` | Estimativa chars/4 |
| RemoteRefinerConfig | `Refiner/RemoteRefinerConfig.swift` | Tabela de context window por modelo |
| BaseRemoteRefiner | `Refiner/BaseRemoteRefiner.swift` | Truncamento com marcador + retry |
| OpenAIRefiner | `Refiner/OpenAIRefiner.swift` | HTTP refiner via OpenAI API |
| OllamaRefiner | `Refiner/OllamaRefiner.swift` | HTTP refiner via Ollama local |
| OllamaHealthChecker | `Refiner/OllamaHealthChecker.swift` | GET /api/tags + cache 30s |
| RefinerFactory | `Refiner/RefinerFactory.swift` | Lê prefs e devolve impl correto |
| HistoryStore | `History/HistoryStore.swift` | Protocol + TranscriptionInput struct |
| HistoryStoreLive | `History/HistoryStoreLive.swift` | SwiftData impl (~/Library/Application Support/com.tagarela.Tagarela/History.store) |
| HistoryStoreNoop | `History/HistoryStoreNoop.swift` | Fallback quando ModelContainer falha ao abrir |
| Transcription | `History/Transcription.swift` | @Model SwiftData (10 campos: id, createdAt, duração, rawText, refinedText, refinerKind, llmModelName, whisperModelName, styleName, frontmostAppBundleID) |
| BackendSubmenu | `UI/MenuBar/BackendSubmenu.swift` | Submenu "Backend ▸" na status bar (Sem LLM / Ollama / OpenAI) com trigger de modal de key |
| StyleSubmenu | `UI/MenuBar/StyleSubmenu.swift` | Submenu "Estilo ▸" na status bar com os 4 estilos built-in |
| OpenAIKeyPromptWindow | `UI/OpenAIKeyPromptWindow.swift` | NSPanel modal pra cadastro/troca da API key da OpenAI |
| DefaultVocabulary | `Transcription/DefaultVocabulary.swift` | ~50 termos hardcoded (nomes técnicos, regionalismos) passados como initialPrompt pra Whisper |

### HistoryStore — comportamento de retenção

Aplicado a cada `save()`:
1. Deleta entradas com `createdAt < now - maxDays * 86400`
2. Mantém os top `maxItems` mais recentes (por `createdAt` desc)

Falha de save é logada sem bloquear pipeline. Container indisponível → HistoryStoreNoop.

## Não implementados (vão pra Fase 2b ou posterior)

- Menu da status bar com "últimos 5"
- Tela de Preferências
- Indicador variações B / C / D
- Toasts de erro
- Estados visuais de "permissão faltando" no menu
- Localizable.strings completo (strings hardcoded por enquanto)
- Retenção por dias com clock injetável (TODO para cobertura de teste completa do retention-by-days)

## Não implementados (vão pra Fase 3)

- Code signing Developer ID
- Notarization
- DMG build
- Sparkle / auto-update
- Homebrew Cask
- Logging em arquivo
