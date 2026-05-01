---
data: 2026-05-01
fase: 2d-velocidade-transcribe
status: implementado
---

# Snapshot pós-Fase 2d

A Fase 2d troca o default Whisper de `large-v3` pra `large-v3_turbo` e adiciona escolha runtime via Preferências. Inclui knobs ANE/prewarm, instrumentação de timing e migration que preserva modelo já em disco em users existentes.

## Módulos novos

- [`Transcription/WhisperModelCatalog.swift`](../../app/Tagarela/Transcription/WhisperModelCatalog.swift) — metadata estática dos 3 modelos (`large-v3_turbo` recom., `large-v3`, `medium`). Fonte da verdade pro picker.
- [`Transcription/WhisperModelStore.swift`](../../app/Tagarela/Transcription/WhisperModelStore.swift) + [`WhisperModelStoreLive.swift`](../../app/Tagarela/Transcription/WhisperModelStoreLive.swift) — `isDownloaded` / `sizeOnDisk` / `delete` no cache do WhisperKit (`~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-<name>/`). `delete()` roda `Task.detached` (multi-GB sem bloquear MainActor). `sizeOnDisk` enumera recursivamente (WhisperKit usa subdirs `*.mlmodelc/`).
- [`Transcription/WhisperModelSwapCoordinator.swift`](../../app/Tagarela/Transcription/WhisperModelSwapCoordinator.swift) — máquina de estado `@MainActor`: `idle → downloading → swapping → idle` (happy), com `failed → retry/dismissError/pivot` no error path. Hotkey continua aceitando durante `.downloading`; bloqueia em `.swapping`. `requestSwap` aceita pivot direto de `.failed` pra outro target. Defesa em profundidade: se `transcribe` rewrap-ar `CancellationError`, `Task.isCancelled` no catch ainda redireciona pra `.idle`.
- [`Preferences/UI/Components/WhisperModelPicker.swift`](../../app/Tagarela/Preferences/UI/Components/WhisperModelPicker.swift) — picker compartilhado entre Onboarding e Preferências. `.contentShape(Rectangle())` garante que toda a área da linha responde a clique (não só o texto).
- [`Preferences/UI/Sections/TranscriptionView.swift`](../../app/Tagarela/Preferences/UI/Sections/TranscriptionView.swift) — section "Transcrição" em Preferências. Renderiza picker, status dinâmico (`downloading` com barra + cancelar; `swapping` com label), alerta de confirmação antes do swap, alerta de cleanup após swap, sheet modal de erro.
- [`Preferences/UI/Sheets/SwapErrorSheet.swift`](../../app/Tagarela/Preferences/UI/Sheets/SwapErrorSheet.swift) — sheet modal com mensagem de erro + botões "Fechar"/"Tentar de novo".

## Módulos modificados

- [`Transcription/WhisperKitTranscriber.swift`](../../app/Tagarela/Transcription/WhisperKitTranscriber.swift):
  - `WhisperKitConfig` ganha `prewarm: true` e `computeOptions = ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine)`. Força ANE no Apple Silicon; Intel ignora gracioso.
  - `transcribe()` instrumentado: `ContinuousClock` (monotônico, imune a NTP step) → `wallMs`. Log `notice` `transcribe model=... audio=...s wall=...ms` via `Logger.tagarela` (categoria `Transcribe`).
  - Novo `unloadModel()` libera `pipe` e `loadedModelName`.
  - `loadModel` e `transcribe` propagam `CancellationError` limpo (não rewrap-am pra evitar mascarar cancel em camadas acima).
- [`Transcription/Transcribing.swift`](../../app/Tagarela/Transcription/Transcribing.swift) — protocol ganha `unloadModel()`.
- [`Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift) — `transcriber: Transcribing` virou `transcriberProvider: @MainActor @Sendable () -> Transcribing`. Permite que swap em runtime troque o ponteiro sem quebrar a pipeline.
- [`Preferences/PreferencesStore.swift`](../../app/Tagarela/Preferences/PreferencesStore.swift) + [`Preferences+Defaults.swift`](../../app/Tagarela/Preferences/Preferences+Defaults.swift) — campo `@Published whisperModelName: String` (default `"large-v3_turbo"`).
- [`Preferences/UI/PrefsSection.swift`](../../app/Tagarela/Preferences/UI/PrefsSection.swift) + [`PreferencesRoot.swift`](../../app/Tagarela/Preferences/UI/PreferencesRoot.swift) — case `.transcricao` + wiring com `swapCoordinator` e `modelStore`.
- [`UI/Onboarding/OnboardModel.swift`](../../app/Tagarela/UI/Onboarding/OnboardModel.swift) + [`OnboardingWindow.swift`](../../app/Tagarela/UI/Onboarding/OnboardingWindow.swift) + [`OnboardingCoordinator.swift`](../../app/Tagarela/UI/Onboarding/OnboardingCoordinator.swift) — radios viraram `WhisperModelPicker` real. Trocar de modelo durante onboarding cancela e re-baixa. Erro inline com botão retry. Modelo escolhido grava em `prefs.whisperModelName`.
- [`App/AppContainer.swift`](../../app/Tagarela/App/AppContainer.swift):
  - `transcriber: var Transcribing` (era `let`) — swap em runtime troca o ponteiro.
  - **Migration:** se `whisperModelName` ausente em UserDefaults E modelo já em disco, preserva o que está em disco (sem download surpresa). Roda antes de `PreferencesStore.init`.
  - 2× `loadModelLogging("large-v3")` hardcoded → `loadModelLogging(prefs.whisperModelName)`.
  - `WhisperModelSwapCoordinator` instanciado com `swapActive` real que troca `self.transcriber` + atualiza `TranscriberRef.current` (pipeline lê via provider).
  - `wireHotkeyToPipeline` skip eventos quando `swapCoordinator.state == .swapping`.

## Bug latente fechado

Onboarding mostrava 3 radios decorativos (`large-v3`, `medium`, `small`) que ignoravam seleção e sempre baixavam `large-v3`. Agora a escolha do user é honrada e gravada em UserDefaults.

## Bench

Medido via `os_log` no Console.app, filtrando `subsystem:com.tagarela category:Transcribe`. (Bench oficial pendente — atualizar com mediana de 5×3s por modelo após validação manual.)

| Modelo | Wall ms (amostra) | Real-time multiplier |
|---|---|---|
| large-v3 | 8305 ms (audio 4.3s) | ~1.9× |
| large-v3_turbo | 5623 ms (audio 3.4s, momento do swap) | ~1.7× |

Números preliminares — turbo demonstrou ganho menor que esperado neste hardware. Bench formal com 5 ditados de ~3s por modelo deve ser registrado aqui após a Tarefa 11 do plan.

## Decisões nucleares

- `large-v3_turbo` (underscore — nome real no repo `argmaxinc/whisperkit-coreml`).
- Picker oferece também `large-v3` (qualidade máxima) e `medium` (caso o user queira economizar disco). `small` ficou de fora — caminho conservador.
- Migration silenciosa: novos installs ganham turbo; users existentes mantêm o modelo em disco.
- Cleanup de modelo antigo é opcional (alerta após swap; user decide).

## Testes

Suíte: 155 → 181 testes verdes (+26).
- `WhisperModelCatalogTests` (7) — listagem + lookup.
- `WhisperModelStoreTests` (7) — presence/size/delete + recursão em subdirs.
- `WhisperModelSwapCoordinatorTests` (10) — happy path, error path, retry, cancel, dismissError, pivot from `.failed`, defesa contra rewrap de CancellationError.
- `PreferencesStoreTests` (+2) — default + persistência.
- `PipelineCoordinatorTests` — refatorado pra `transcriberProvider`.

## Lição operacional aplicada

Fase 2c-cleanup ensinou que spec compliance + code review estática não substitui aceite runtime. Aplicado durante a 2d:
- Cada tarefa que tocou AppKit/SwiftUI/IO (T4, T6, T7, T8, T9) teve aceite manual em build local antes do commit.
- Bugs encontrados pelo aceite que não pegaram nos reviews: nome técnico do modelo (`-` vs `_`), hit-test do picker (Spacer não responde sem `.contentShape`), Console.app não mostra `.info` por default (precisou subir pra `.notice`).
