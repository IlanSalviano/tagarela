---
data: 2026-05-01
fase: 2d-velocidade-transcribe
status: design
---

# Fase 2d — Velocidade da transcrição

Bundle pré-Fase 3 (release). Objetivo: reduzir o tempo wall-clock de transcrição em ditados curtos, sem comprometer qualidade em PT.

## Contexto

Hoje o app carrega `large-v3` hardcoded em 3 lugares ([`OnboardingWindow.swift:33`](../../app/Tagarela/UI/Onboarding/OnboardingWindow.swift), [`AppContainer.swift:177`](../../app/Tagarela/App/AppContainer.swift), [`AppContainer.swift:267`](../../app/Tagarela/App/AppContainer.swift)). Em uso real, ditado de ~3s leva ~10s pra transcrever. Whisper sempre processa janela de 30s mesmo em áudio curto, então o custo fixo do modelo grande domina.

Bug latente: o Onboarding mostra 3 radio buttons ([`OnboardModel.swift:19-24`](../../app/Tagarela/UI/Onboarding/OnboardModel.swift)) que parecem dar escolha, mas o código ignora a seleção e sempre baixa `large-v3`. Esta fase resolve o bug com UX completa.

## Princípio orientador

**Conservador:** trocar pra `large-v3-turbo` (mesma família, qualidade muito próxima, 5–8× mais rápido). Não considerar `distil-large-v3` ou modelos menores como default. Picker oferece também `large-v3` (qualidade máxima) e `medium` (caso o user queira economizar disco).

## Decisões nucleares

| # | Decisão | Razão |
|---|---------|-------|
| 1 | Default da v1: `large-v3-turbo` | Qualidade próxima de large-v3, 5–8× mais rápido, 815 MB. |
| 2 | Picker funcional no Onboarding e em Preferências | Resolve o bug dos radios decorativos e dá controle ao user. |
| 3 | Modelos no picker: `large-v3-turbo`, `large-v3`, `medium` | `small` removido (caminho conservador). |
| 4 | `WhisperKitConfig.prewarmModels = true` | Primeira transcrição da sessão fica mais rápida. Risco baixo. |
| 5 | `computeOptions = ModelComputeOptions(.cpuAndNeuralEngine, .cpuAndNeuralEngine)` | Força ANE no Apple Silicon. Intel ignora gracioso. |
| 6 | `DecodingOptions` não muda (sem mexer em `temperatureFallbackCount`) | Conservador. Reduzir fallbacks aumenta risco de alucinação. |
| 7 | Instrumentação: `os_log` simples em `transcribe()` (modelo, audioSec, wallMs) | Suficiente pra medir antes/depois via Console.app. |
| 8 | Troca runtime em Preferências: imediata com confirmação, download em background, mantém modelo antigo até novo carregar | UX moderna; hotkey continua aceitando durante download. |
| 9 | Cleanup de disco: alerta após troca bem-sucedida pergunta se apaga o modelo antigo | Libera espaço sem decidir pelo user. |
| 10 | Falha de download/load: sheet modal com mensagem + botão "Tentar de novo" | Erro raro mas explícito. |
| 11 | Storage da escolha: `Preferences.whisperModelName` em UserDefaults | Padrão dos outros prefs. |

## Componentes

### Modificados

#### `WhisperKitTranscriber.swift`
- `WhisperKitConfig` ganha `prewarmModels: true` e `computeOptions = ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine)`.
- `transcribe()` ganha medição: `start = Date()` antes da chamada; `wallMs = Int(Date().timeIntervalSince(start) * 1000)` depois; log via `Logger.tagarela.info("transcribe model=... audio=...s wall=...ms")`.
- Novo método `unloadModel()` — libera `pipe = nil` e `loadedModelName = nil`. Usado pelo swap coordinator antes de carregar novo.

#### `Preferences` (existente)
- Novo campo `whisperModelName: String` (default `"large-v3-turbo"`). Storage: UserDefaults via wrapper existente.
- `PreferencesDefaults.whisperModelName = "large-v3-turbo"`.

#### `OnboardModel.swift`
- Radios viram funcionais. State `@Binding var selected: String`.
- Modelos exibidos: `large-v3-turbo` (recom.), `large-v3`, `medium`.
- "começar →" passa `selected` pra `coordinator.loadModel(selected)` e grava em `prefs.whisperModelName`.

#### `OnboardingCoordinator.swift` / `OnboardingWindow.swift`
- `loadModel(_:)` aceita o nome dinâmico em vez de hardcoded.
- Erro inline na tela de onboarding ("falha: <razão> · tentar de novo") — sem sheet modal nessa fase.

#### `AppContainer.swift`
- Remove os 2 `loadModelLogging("large-v3")` hardcoded; substitui por `loadModelLogging(prefs.whisperModelName)`.
- Wiring do `WhisperModelSwapCoordinator` (instância + injeção em PreferencesViewModel).
- Hotkey desabilita durante `.swapping` (janela curta).

### Novos

#### `Transcription/WhisperModelCatalog.swift`
Struct estática com metadata dos 3 modelos (nome técnico, label UI, tamanho MB, RAM mínima recomendada, "recomendado" boolean). Fonte da verdade pra picker.

```swift
struct WhisperModelInfo {
    let name: String          // "large-v3-turbo"
    let displaySize: String   // "815 MB"
    let displayRAM: String    // "≥ 4 GB"
    let recommended: Bool
}

enum WhisperModelCatalog {
    static let all: [WhisperModelInfo] = [...]
    static func info(for name: String) -> WhisperModelInfo?
}
```

#### `Transcription/WhisperModelStore.swift` + `WhisperModelStoreLive.swift`
Protocol + implementação. Sabe (a) caminho local de cada modelo via `WhisperKit` cache convention, (b) `isDownloaded(name:) -> Bool`, (c) `delete(name:) async throws -> Void` removendo a pasta do modelo.

```swift
protocol WhisperModelStore {
    func isDownloaded(_ name: String) -> Bool
    func sizeOnDisk(_ name: String) -> Int64?
    func delete(_ name: String) async throws
}
```

#### `Transcription/WhisperModelSwapCoordinator.swift`
Máquina de estado que orquestra trocas em runtime. Estados:

```swift
enum SwapState {
    case idle(active: String)
    case downloading(active: String, target: String, progress: Double)
    case swapping(active: String, target: String)
    case failed(active: String, target: String, error: SwapError)
}

enum SwapError {
    case downloadFailed(String)
    case loadFailed(String)
    case diskFull
    case cancelled
}
```

API pública:
- `requestSwap(target: String)` — aceita `.idle` (troca normal) e `.failed` (pivot direto pra outro target após erro, sem precisar dismissError + nova chamada).
- `retry()` — reinicia swap após `.failed` mantendo o mesmo target.
- `cancel()` — cancela download/load em curso. Volta pra `.idle(active: <antigo>)`.
- `dismissError()` — sai de `.failed` voltando pra `.idle(active: <antigo>)`. Chamado pelo botão "Fechar" da SwapErrorSheet.
- `@Published var state: SwapState`

**Robustez de cancelamento:** se o transcriber rewrap-ar `CancellationError` em outro tipo (regressão potencial em `WhisperKit`), o coordinator detecta `Task.isCancelled` nos `catch` de `modelDownloadFailed`/erro genérico e ainda volta pra `.idle` (não `.failed`). `WhisperKitTranscriber` também propaga `CancellationError` limpo (não rewrap-a) — defesa em profundidade.

Coordinator instancia um `WhisperKitTranscriber` separado pro download/load do target. Após sucesso, troca o ponteiro `transcriber` no AppContainer atomicamente via callback `@MainActor`.

#### `Preferences/UI/Sections/TranscriptionSection.swift`
Nova section em Preferências. Mostra:
- Modelo ativo (nome + tamanho).
- Picker dos 3 modelos via `WhisperModelPicker`.
- Estado dinâmico baseado em `swapCoordinator.state`: idle (picker editável), downloading (barra de progresso + botão cancelar), swapping (label "trocando…"), failed (sheet modal aberta).

#### `Preferences/UI/Components/WhisperModelPicker.swift`
Componente compartilhado entre Onboarding e Preferências. Renderiza linha por modelo (radio + nome + tamanho + RAM + badge "recom.").

```swift
struct WhisperModelPicker: View {
    @Binding var selected: String
    let enabled: Bool
    // ...
}
```

#### `Preferences/UI/Sheets/SwapErrorSheet.swift`
Sheet modal com mensagem de erro + botão "Tentar de novo" + botão "Fechar".

#### `Preferences/UI/Sheets/DeletePreviousModelAlert.swift`
Alerta após swap bem-sucedido: "Apagar `<modelo antigo>` do disco? (libera X MB)" `[Manter]` `[Apagar]`.

#### `Localization/pt-BR.lproj/Localizable.strings`
Strings novas:
- `preferences.transcription.title` → "Transcrição"
- `preferences.transcription.activeModel` → "Modelo ativo: %@"
- `preferences.transcription.swapConfirm.title` → "Trocar pra %@?"
- `preferences.transcription.swapConfirm.body` → "Vai baixar %@. Você pode continuar usando o app durante o download."
- `preferences.transcription.swap.downloading` → "Baixando %@ — %d%%"
- `preferences.transcription.swap.swapping` → "Trocando modelo…"
- `preferences.transcription.swap.error.title` → "Falha ao trocar"
- `preferences.transcription.swap.error.retry` → "Tentar de novo"
- `preferences.transcription.deletePrevious.title` → "Apagar %@?"
- `preferences.transcription.deletePrevious.body` → "Libera %@ de espaço."
- `onboarding.model.error` → "Falha: %@ · tentar de novo"

## Data flow do swap em Preferências

### Fluxo feliz

1. User abre Preferências > Transcrição. Picker mostra `active = whisperModelName` selecionado.
2. User clica em outro modelo. Alerta: "Trocar pra `<target>`? Vai baixar `<size>`. Você pode continuar usando o app durante o download." `[Cancelar]` `[Trocar]`.
3. Confirma → `coordinator.requestSwap(target:)` → `state = .downloading(active, target, 0)`.
4. Coordinator instancia `WhisperKitTranscriber` separado e chama `WhisperKit.download(variant:progressCallback:)`. Progresso atualiza `state.progress`. UI mostra barra.
5. Hotkey continua funcionando — usa o `transcriber` ativo (antigo).
6. Download conclui → `state = .swapping(active, target)`. Coordinator chama `loadModel(target)` no novo transcriber. Hotkey desabilita durante essa janela curta.
7. `loadModel` conclui → coordinator troca o ponteiro `transcriber` no AppContainer via callback. Antigo é desreferenciado mas modelo continua em disco.
8. `Preferences.whisperModelName = target`. Hotkey re-habilita.
9. Alerta: "Apagar `<antigo>` do disco? (libera `<size>` MB)". User responde → coordinator volta pra `.idle(active: target)`.

### Fluxo de erro (download falha)

1. Coordinator → `.failed(active: <antigo>, target, error: .downloadFailed(razão))`.
2. `SwapErrorSheet` abre. CTAs: `[Fechar]` `[Tentar de novo]`.
3. Tentar de novo → reinicia download.
4. Fechar → `.idle(active: <antigo>)`. Picker re-marca antigo. Modelo ativo nunca mudou.

### Cancelamento

User clica em outro modelo durante download (ou em botão "cancelar"): coordinator cancela `Task` do download. Estado volta pra `.idle(active: <antigo>)`.

### Concorrência hotkey × swap

| Estado coordinator | Hotkey aceita? | Modelo usado |
|---|---|---|
| `.idle(active)` | sim | active |
| `.downloading(active, target, p)` | sim | active |
| `.swapping(active, target)` | **não** (toast: "trocando modelo…") | n/a |
| `.failed(active, target, error)` | sim | active |

Janela `.swapping` é curta (segundos pra `loadModel` do modelo já em disco). Aceitável bloquear hotkey nela.

### Pico de memória durante swap

Durante `.swapping`, dois transcribers ficam vivos por uma janela curta. Pico = memória do antigo + do novo. Pior caso: `large-v3` (≈ 3 GB RAM) + `large-v3-turbo` (≈ 1 GB) ≈ 4 GB. Aceitável em Macs com ≥ 8 GB; arriscado em 4 GB. Sequência do coordinator: (1) `load` do novo, (2) troca atômica do ponteiro `transcriber` no AppContainer, (3) `unload` do antigo via `unloadModel()`. Se (1) falhar por memória, cai pra `.failed(.loadFailed)` sem comprometer o antigo (que continua carregado). Erro registrado no log.

## Onboarding flow

1. Step 3 mostra picker funcional. Default selecionado: `large-v3-turbo`.
2. User troca seleção livre. "começar →" só fica habilitado após download concluído.
3. Click em "começar →" inicia download. Barra de progresso. Erro inline se falhar.
4. Sucesso → `prefs.whisperModelName = selected`, onboarding fecha.

## Instrumentação

```swift
let start = Date()
let results = try await pipe.transcribe(audioArray: buffer.samples, decodeOptions: opts)
let wallMs = Int(Date().timeIntervalSince(start) * 1000)
let audioSec = String(format: "%.1f", buffer.durationSeconds)
logger.info("transcribe model=\(self.loadedModelName ?? "?", privacy: .public) audio=\(audioSec, privacy: .public)s wall=\(wallMs, privacy: .public)ms")
```

Filtragem no Console.app: `subsystem:com.tagarela category:Transcribe`.

## Testes

### Unit (novos)
- `WhisperModelCatalogTests` — listagem, lookup por nome.
- `WhisperModelStoreTests` — `isDownloaded`, `sizeOnDisk`, `delete` com FileManager fake.
- `WhisperModelSwapCoordinatorTests` — transições happy + error paths + cancel + retry. Usa `FakeWhisperModelStore` + `FakeTranscribing`.
- `PreferencesTests` — caso novo pro `whisperModelName` (default + persist).

Casos críticos no swap coordinator:
- `idle → downloading → swapping → idle (delete prompt seguinte)` — happy path
- `idle → downloading → failed (downloadFailed) → idle` (retry/close)
- `idle → downloading → swapping → failed (loadFailed) → idle` — download ok mas load quebra
- `idle → downloading → cancelled → idle` — user cancela mid-download
- `failed → downloading → swapping → idle` — retry success

### Manuais

- **Bench antes/depois**: 5 ditados de ~3s no `large-v3` vs `large-v3-turbo`. Registrar `wall_ms` no Console. Esperado: redução ≥ 5×.
- **Onboarding**: instalação limpa, escolher cada um dos 3 modelos, validar download + load + arranque do app.
- **Preferências fluxo feliz**: trocar de turbo → large-v3 → medium → turbo, validar prompt de cleanup em cada passo.
- **Preferências erro**: simular offline durante download (Wi-Fi off), validar sheet modal + retry.
- **Concorrência**: durante download, disparar hotkey, validar que transcribe acontece com modelo antigo.
- **Cleanup**: aceitar e recusar prompt de cleanup; validar disco em ambos casos.

Suíte projetada: 155 → ~165 testes.

## Não-objetivos

- Não considerar modelos `distil-*` ou `small`/`base` (caminho conservador).
- Não mexer em `DecodingOptions.temperatureFallbackCount` (risco de alucinação).
- Não persistir histórico de timing em SwiftData (escopo enxuto; log é suficiente).
- Não construir lista de "todos modelos baixados" em Preferências com botão deletar individual (escopo da v1: apenas oferta de cleanup após swap).
- Não suportar download paralelo de múltiplos modelos (um swap de cada vez).

## Migração

Usuário existente que abre o app após update:
- Detectamos via `UserDefaults`: se a chave `whisperModelName` ainda não existe E há um modelo já em disco (qualquer), gravamos `whisperModelName = <modelo em disco>` e seguimos com ele. Sem swap automático, sem surpresa.
- Novo install ou user que apaga manualmente o modelo: default `"large-v3-turbo"` aplica.
- Pra migrar pro turbo, user existente abre Preferências > Transcrição e troca manualmente. UI ganha um banner discreto na primeira abertura da section ("modelo mais rápido disponível: large-v3-turbo · 5–8× mais rápido"). Banner some após o user dispensar.

## Riscos

| Risco | Mitigação |
|---|---|
| `large-v3-turbo` qualidade pior que esperado em PT | Picker permite voltar pra large-v3 sem reinstalar. |
| `computeOptions = .cpuAndNeuralEngine` regride em hardware específico | WhisperKit ignora gracioso em Intel; aceitar e medir via log. |
| Lição da 2c-cleanup: aceite runtime obrigatório | Plano vai explicitar checkpoint manual antes de cada merge de tarefa que toca AppKit/SwiftUI/IO. |
| Race entre swap atômico e hotkey | Hotkey desabilita durante `.swapping` (janela curta documentada). |
| Migração automática surpreende user existente | Toast informativo + "Cancelar" reverte. |

## Próximos passos

1. Esta spec é revisada pelo user.
2. Após aprovação, `superpowers:writing-plans` produz o plano de implementação detalhado, salvo em `tagarela_docs/specs/2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-plan.md`.
3. Implementação segue o plano, com aceite manual em build local antes de cada merge (lição 2c-cleanup).
