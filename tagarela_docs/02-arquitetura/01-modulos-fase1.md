# Módulos implementados na Fase 1

Snapshot do que existe no código ao fim da Fase 1. Atualizar conforme drift acontece.

## Implementados

| Módulo | Arquivo principal | Responsabilidade |
|---|---|---|
| AppState | `App/AppState.swift` | ObservableObject com PipelineState (5 estados) |
| AppContainer | `App/AppContainer.swift` | Composition root + wire-up + gating de onboarding |
| DesignSystem | `Design/DesignSystem.swift` | Color/Font/Radius/Shadow tokens |
| Wordmark, Glyph | `Design/{Wordmark,Glyph}.swift` | Identity views |
| PermissionService | `Permissions/` | mic / accessibility / input monitoring (poll 1s) |
| HotkeyService | `Hotkey/` | CGEventTap p/ Option (toggle) + Esc (cancel) |
| AudioCapturing | `Audio/` | AVAudioEngine 16kHz mono float32 + RMS levels |
| Transcribing (WhisperKit) | `Transcription/` | load model + transcribe pt-BR via WhisperKit 0.18.0 |
| InitialPromptBuilder | `Transcription/` | monta initialPrompt com vocab + truncamento (não usado no transcribe ainda — ver cleanup-fase1) |
| TextRefiner (Identity) | `Refiner/` | passa texto cru direto |
| Injecting | `Injection/` | clipboard save → ⌘V → restore (250ms) |
| PipelineCoordinator | `Pipeline/` | actor com 5 estados |
| MenuBarContent + StateRow | `UI/MenuBar/` | dropdown da status bar |
| FloatingIndicatorPanel + IndicatorPill (A) + WaveBars | `UI/Indicator/` | indicador flutuante variação A |
| Onboarding (Welcome + Perms + Model) | `UI/Onboarding/` | primeira execução |

## Divergências do plano original

Anotadas em commits e [`cleanup-fase1.md`](../04-decisoes/cleanup-fase1.md):

- **Geração do projeto via xcodegen** (vs Xcode UI) — `app/project.yml` é fonte da verdade. Documentado em [`02-stack-tecnica.md`](./02-stack-tecnica.md).
- **WhisperKit 0.18.0 API mudou** — `WhisperKit.download(variant:progressCallback:)` static + init com `WhisperKitConfig(modelFolder:load:)`.
- **Detecção L/R do Option simplificada** — qualquer Option dispara hoje. TODO em `cleanup-fase1` item 1.
- **`initialPrompt` ainda não vira `promptTokens`** — string construída mas descartada; só `usePrefillPrompt: true` é setado. TODO em `cleanup-fase1` item 2.
- **Protocols Audio/Transcribing/Refiner/Injecting marcados Sendable** — necessário pra `actor PipelineCoordinator` chamar métodos deles em Swift 5.10 com strict concurrency complete.
- **`AppContainer: ObservableObject` adiantado** — plano colocava na Task 29, antecipei pra Task 11 pra suportar `@StateObject` no `TagarelaApp`.
- **Fontes via `type: folder` no xcodegen** — pra preservar `Resources/Fonts/` no bundle (ATSApplicationFontsPath = "Fonts").

## Cobertura de testes (XCTest)

13 testes verdes:

- **HotkeyTests** — default, codable, virtualKeyCode, displayLabel (4)
- **PermissionServiceTests** — allGranted true/false, status codable (3)
- **InitialPromptBuilderTests** — empty vocab, with vocab, truncation (3)
- **IdentityRefinerTests** — passthrough, kind (2)
- **InjectorTests** — error equatable (1)
- **PipelineCoordinatorTests** — idle→toggle→recording, recording→toggle→idle, recording→cancel→idle (3 — usando fakes Sendable)

UI/visual fica no [`fase1-manual.md`](../03-funcionalidades/checklists/fase1-manual.md).

## Não implementados (vão pra Fase 2)

- TextRefiner: Ollama, OpenAI
- Keychain (API key OpenAI)
- PreferencesStore + tela de Preferências
- HistoryStore (SwiftData)
- Menu da status bar com "últimos 5"
- Indicador variações B / C / D
- Toasts de erro
- Estados visuais de "permissão faltando" no menu
- Localizable.strings completo (strings hardcoded por enquanto)

## Não implementados (vão pra Fase 3)

- Code signing Developer ID
- Notarization
- DMG build
- Sparkle / auto-update
- Homebrew Cask
- Logging em arquivo
