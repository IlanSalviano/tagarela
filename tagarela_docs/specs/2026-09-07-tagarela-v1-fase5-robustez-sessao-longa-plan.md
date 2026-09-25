---
data: 2026-09-07
status: implementado — v1.0.4 publicada em 2026-09-24; validação de campo (Tarefa 13) em curso
fase: 5-robustez-sessao-longa
goal: app continua transcrevendo após semanas no ar; quando falhar, diz por quê e se recupera sozinho
origem: 02-arquitetura/10-auditoria-2026-09-07.md (§3 diagnóstico, §4 plano, §5 achados)
---

# tagarela v1 — Fase 5: robustez em sessão longa — Implementation Plan

> **Para agentes de execução:** este plano foi escrito para ser retomado em **outro chat**, sem o contexto da auditoria. Use `superpowers:executing-plans` ou `superpowers:subagent-driven-development` se disponíveis; senão, execute tarefa a tarefa marcando os checkboxes (`- [ ]`).
>
> **Antes de qualquer tarefa:** ler [`/CLAUDE.md`](../../CLAUDE.md), a [auditoria de 2026-09-07](../02-arquitetura/10-auditoria-2026-09-07.md) (é o "design" desta fase — não existe design doc separado) e a seção **Regra de coexistência de builds** abaixo. **Antes de marcar uma tarefa como concluída:** atualizar a doc afetada (regra inviolável 2). **Antes de mergear cada tarefa que toca AppKit/SwiftUI/IO (Tarefas 3, 5, 7, 8, 9):** aceite manual em build local — lição da 2c-cleanup.

**Goal:** a queixa "depois de muitos dias no ar o app para de fazer STT, sem crash; relaunch resolve" não tem causa-raiz confirmada porque todos os caminhos de falha relevantes são **silenciosos** e o log `.info` não persiste. Esta fase (a) torna cada falha visível e persistida, (b) faz o app se recuperar sozinho nos três subsistemas suspeitos (captura de áudio, hotkey, decoder), (c) corrige os bugs confirmados pela auditoria, (d) publica v1.0.4 e (e) usa a próxima ocorrência em campo para fechar a causa-raiz.

**Architecture:**

1. **Diagnóstico persistido** — `Diag` (wrapper de `Logger` que também grava em `~/Library/Logs/Tagarela/tagarela.log`, rotativo 5 MB × 3). Marcos do pipeline sobem de `.info` para `.notice`; anomalias viram `.error`. Nunca loga o texto ditado — só tamanhos, formatos, métricas.
2. **Saúde observável** — `PipelineHealth` (`@MainActor`, contadores desde o launch: gravações, descartes por buffer curto, transcrições vazias, colas falhas, recuperações, uptime) exibido no menu e incluído na exportação "Exportar diagnóstico" (Preferências › Sobre).
3. **Captura self-healing** — `AVAudioEngine` novo a cada `start()`; watchdog "nenhum buffer em 1 s" → recria e tenta uma vez → senão erro visível; `stop()` compara duração capturada × wall-clock; stream de nível **por gravação**; matemática de áudio extraída em `AudioMath` (testável).
4. **Pipeline com falhas visíveis** — eventos `captureFailed` e `emptyTranscription` com toasts; transcrição vazia **nunca** é injetada; 2 vazias seguidas → `transcriberRecoveryRequested` → `AppContainer` recarrega o WhisperKit do disco; corridas `.error→.idle` e `transcribe()` concorrente após Esc eliminadas.
5. **Transcriber** — `transcribe` devolve `TranscriptionOutcome` (texto + idioma detectado + `avgLogprob` + `compressionRatio` + `noSpeechProb` + `wallMs`); `loadModel` prefere a pasta local (sem rede); `reload()`.
6. **Hotkey e permissões** — `start()` idempotente, watchdog `CGEvent.tapIsEnabled` a cada 30 s, re-`start()` quando Input Monitoring volta a `granted`; `PermissionService.snapshots` multicast.
7. **Injeção sem perda** — histórico salvo **antes** da cola; pasteboard escrito antes de checar Accessibility; restauração do clipboard não cancelável e condicionada a `changeCount`.
8. **Correções pontuais** já confirmadas (swap não persistido, health checker do Ollama com URL congelada, 37 chaves de localização, ordem do appcast no release).

**Tech stack:** Swift 5.10 (strict concurrency complete), SwiftUI + AppKit cirúrgico, AVFoundation, CoreGraphics (`CGEvent`), OSLog, WhisperKit 0.18.0, Sparkle 2.9.1, XCTest. **Sem novas dependências SPM.**

**Não está nesta fase** (backlog em [auditoria §5](../02-arquitetura/10-auditoria-2026-09-07.md), itens P2): reamostragem com anti-aliasing, gate de silêncio antes do boost, `PermissionService` orientado a eventos, refactor do indicador (cleanup #8) além do mínimo, entitlements supérfluos, warnings Swift 6, `chunkingStrategy: .vad`, acessibilidade (VoiceOver), unificação de Team IDs Debug/Release, `notarytool --keychain-profile`, migração de `HistoryStore.recent` para snapshots `Sendable`.

---

## Regra de coexistência de builds (leia antes de rodar qualquer teste)

A release oficial v1.0.3 está instalada em `/Applications/Tagarela.app` e **em uso**. Qualquer build local com o mesmo bundle id (`com.tagarela.Tagarela`) que o macOS chegue a **lançar** registra uma cópia rival no LaunchServices/TCC e derruba as permissões da release ([`cleanup-fase3.md`](../04-decisoes/cleanup-fase3.md)). `xcodebuild test` lança o host de testes (`Tagarela.app` de Debug). Medido em 2026-09-24: o que cai na prática é o **Microfone** — o host de testes o pede no launch e fica com a concessão, e a release pede de volta no launch seguinte; Monitoramento de Entrada e Acessibilidade ficam (ver *Reincidência em 2026-09-24* no [`cleanup-fase3.md`](../04-decisoes/cleanup-fase3.md)). Portanto:

1. Sempre buildar/testar com DerivedData **fixo e fora do repo**: `-derivedDataPath ~/Library/Developer/Xcode/DerivedData/Tagarela-fase5`.
2. **Nunca** `open` o `.app` gerado. Aceite manual: parar a release (`Cmd+Q` no menu), `cp -R` do build para `/Applications/Tagarela-dev.app`? **Não** — bundle id igual. Em vez disso, o aceite manual roda a partir do DerivedData **com a release fechada**, e ao terminar: `Cmd+Q` no build de dev, reabrir `/Applications/Tagarela.app`, e se o macOS voltar a pedir Microfone/Accessibility, aplicar a remediação do `cleanup-fase3` (`tccutil reset All com.tagarela.Tagarela` + `lsregister -u <caminho do build>`).
3. Depois de cada sessão de testes: `lsregister -u ~/Library/Developer/Xcode/DerivedData/Tagarela-fase5/Build/Products/Debug/Tagarela.app`.
4. Checagem rápida de sanidade: `lsregister -dump | grep -c "com.tagarela.Tagarela"` deve voltar ao valor de antes da sessão.

Comandos padrão desta fase (`REPO` = raiz do repositório; nesta máquina `/Volumes/Brain/Dev/tagarela`, na outra `/Users/tars/Dev/tagarela` — nunca hardcodar):

```bash
cd "$REPO/app" && xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' \
  -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Tagarela-fase5 test 2>&1 | tail -8
```

### Comando padrão **nesta máquina** (`/Volumes/Brain`) — assinatura

O `project.yml` fixa Debug/Tests no certificado da outra máquina (team `BCM26K6YNA`), que aqui não existe. Unificar os Team IDs é achado §5.5 da auditoria e está **fora do escopo** desta fase, então a identidade local é passada **por linha de comando** e nenhum arquivo commitado muda:

```bash
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' \
  -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Tagarela-fase5 \
  CODE_SIGN_IDENTITY="Apple Development: Created via API (33HY58YHW4)" \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=22CZXFP6W7 PROVISIONING_PROFILE_SPECIFIER="" \
  test 2>&1 | tail -8
```

Detalhe que custou uma tentativa: o `33HY58YHW4` no *nome* do certificado é o **UID**, não o time. O Team ID real está no campo `OU` do subject (`OU=22CZXFP6W7`) e é o que o `DEVELOPMENT_TEAM` precisa casar. Com `DEVELOPMENT_TEAM=33HY58YHW4` o build falha igual ao caso do `BCM26K6YNA`.

Por que esta identidade e não ad-hoc (`CODE_SIGN_IDENTITY="-"`): o designated requirement fica ancorado no **certificado**, não no cdhash —

```
designated => identifier "com.tagarela.Tagarela" and anchor apple generic
  and certificate leaf[subject.CN] = "Apple Development: Created via API (33HY58YHW4)" ...
```

logo os grants de TCC (Microfone, Acessibilidade, Input Monitoring) do build de dev **sobrevivem a rebuilds**, o que torna os aceites manuais das Tarefas 3, 5, 7, 8 e 9 praticáveis. Com ad-hoc o DR seria o cdhash e cada rebuild exigiria reconceder tudo. Efeito colateral bem-vindo: o build local passa a ter `TeamIdentifier=22CZXFP6W7`, **o mesmo da release** — reduz (não elimina) o descasamento de designated requirement que originou o TCC zumbi do [`cleanup-fase3.md`](../04-decisoes/cleanup-fase3.md). A **Regra de coexistência acima continua valendo integralmente**: o bundle id segue igual ao da release.

Esperado ao fim da fase: `** TEST SUCCEEDED **`, ≥ 186 + novos testes.

---

## File structure desta fase

```
app/Tagarela/
├── App/
│   ├── AppContainer.swift                 # MODIFICAR — Diag, PipelineHealth, recovery do transcriber, re-start da hotkey, swap persist
│   └── Diagnostics/
│       ├── DiagnosticsLog.swift           # CRIAR — arquivo rotativo thread-safe
│       ├── Diag.swift                     # CRIAR — fachada Logger + arquivo, por categoria
│       ├── PipelineHealth.swift           # CRIAR — contadores + uptime
│       └── DiagnosticsExporter.swift      # CRIAR — monta pasta de exportação (log + snapshot)
├── Audio/
│   ├── AudioCapturing.swift               # MODIFICAR — erro noAudioDelivered; doc do `levels` por gravação; CaptureStats
│   ├── AudioCaptureLive.swift             # MODIFICAR — engine por start(), watchdog, lock, stats, levels por gravação
│   └── AudioMath.swift                    # CRIAR — downmix/resample/boost puros (extraídos)
├── Pipeline/
│   ├── PipelineCoordinator.swift          # MODIFICAR — captureFailed/emptyTranscription/recovery, corridas, ordem save→inject
│   └── PipelineEvent.swift                # MODIFICAR — eventos novos
├── Transcription/
│   ├── Transcribing.swift                 # MODIFICAR — TranscriptionOutcome, reload()
│   ├── WhisperKitTranscriber.swift        # MODIFICAR — métricas, load local, reload
│   ├── WhisperModelStore.swift            # MODIFICAR — modelFolderURL(for:)
│   └── WhisperModelStoreLive.swift        # MODIFICAR — idem
├── Hotkey/
│   ├── HotkeyService.swift                # MODIFICAR — restart(), isTapEnabled
│   └── HotkeyServiceLive.swift            # MODIFICAR — start idempotente, watchdog, flag de device
├── Permissions/
│   ├── PermissionService.swift            # MODIFICAR — makeSnapshots() por assinante
│   └── PermissionServiceLive.swift        # MODIFICAR — multicast
├── Injection/InjectorLive.swift           # MODIFICAR — ordem pasteboard/AX, restore seguro
├── Refiner/
│   ├── OllamaHealthChecker.swift          # MODIFICAR — URL por chamada, sem cache negativo em cancel
│   └── OllamaRefiner.swift                # MODIFICAR — options.num_ctx
├── Preferences/
│   ├── PreferencesStore.swift             # MODIFICAR — clamp no init
│   └── UI/Sections/{AboutView,TranscriptionView}.swift  # MODIFICAR — exportar diagnóstico; remover persist do swap
├── UI/
│   ├── Indicator/FloatingIndicatorPanel.swift  # MODIFICAR — .fullScreenAuxiliary; cancelar previewTask em show()
│   ├── MenuBar/{MenuBarContent,StateRow}.swift # MODIFICAR — linha de saúde; sub-labels corretos
│   ├── Onboarding/OpenAIKeyPromptWindow.swift  # MODIFICAR — fechar no ⨯ = cancelar
│   └── Toast/ToastKind.swift                   # MODIFICAR — captureFailed, emptyTranscription, transcriberRecovered
└── Localization/pt-BR.lproj/Localizable.strings # MODIFICAR — 37 chaves ausentes + novas

app/TagarelaTests/
├── DiagnosticsLogTests.swift              # CRIAR
├── PipelineHealthTests.swift              # CRIAR
├── AudioMathTests.swift                   # CRIAR
├── PipelineCoordinatorTests.swift         # MODIFICAR — levels em 2 gravações, captureFailed, vazio, recovery, corridas, ordem save→inject
├── WhisperKitTranscriberTests.swift       # CRIAR — só a lógica de escolha local × download (fake do store)
├── HotkeyCallbackTests.swift              # CRIAR — CGEvent sintético
├── PermissionServiceTests.swift           # MODIFICAR — multicast
├── InjectorTests.swift                    # MODIFICAR — restore condicional (pasteboard real, gated)
├── OllamaHealthCheckerTests.swift         # CRIAR
└── LocalizableKeysTests.swift             # MODIFICAR — chaves derivadas dos fontes

scripts/release.sh, scripts/appcast.sh, scripts/bump.sh   # MODIFICAR — Tarefa 11
tools/diag/*.swift                                        # já existem (auditoria)
```

Documentação produzida por esta fase em `tagarela_docs/`:
- `02-arquitetura/11-modulos-fase5.md` (criar) — snapshot pós-Fase 5.
- `03-funcionalidades/checklists/fase5-manual.md` (criar) — aceite manual (blocos abaixo, Tarefa 12).
- `04-decisoes/ADR-0008-diagnostico-persistido-e-self-healing.md` (criar) — decisões 1–4 da Architecture.
- `03-funcionalidades/troubleshooting-runtime.md` — entrada #3 quando a Tarefa 13 fechar a causa-raiz.
- `README.md` — índice.

---

## Convenções desta fase

- **Idioma:** UI em `Localizable.strings` (pt-BR). Código em inglês.
- **Privacidade nos logs:** nunca o texto ditado nem o clipboard. Só contagens, durações, formatos, métricas numéricas, bundle id do app-alvo.
- **Níveis:** `.notice` = marco normal do pipeline (persiste ~dias); `.error` = anomalia que explica um "não fez o STT"; `.info` = detalhe de depuração (não persiste, tudo bem).
- **Concorrência:** `PipelineHealth`, `Diag` fachada e exportador são `@MainActor`; `DiagnosticsLog` é `final class` com `OSAllocatedUnfairLock` (chamado de qualquer thread, inclusive tap de áudio); `AudioCaptureLive` protege `channelBuffers` com lock.
- **Erros:** novos cases em enums existentes (`AudioCaptureError.noAudioDelivered`, `PipelineEvent.captureFailed/emptyTranscription/transcriberRecoveryRequested`, `ToastKind` correspondentes). Não introduzir hierarquias novas.
- **TDD:** lógica → teste primeiro. AppKit/AVFoundation → aceite manual com checklist. Testes **não** podem depender de mic real, rede real ou Keychain real (gate por env `TAGARELA_INTEGRATION=1` quando inevitável).
- **Commits:** um por tarefa, pt-BR `tipo(escopo): descrição`, co-author Claude.
- **xcodegen é fonte da verdade.** Após criar arquivo: `cd "$REPO/app" && xcodegen generate`.

---

## Pre-flight (antes da Tarefa 1)

- [x] **`main` limpo e contendo a auditoria.** `main` em `808755e docs(auditoria)`. Ruído incidental do working tree (`.DS_Store` deletados, `graph.json` do Obsidian) restaurado com `git restore .` antes de branchar.
- [x] **Branch:** `fase-5-robustez` criada a partir de `808755e`.
- [x] **Toolchain:** xcodegen `/opt/homebrew/bin/xcodegen`; Xcode 26.6 (17F113) — mesma da auditoria. `xcodegen generate` sem drift no `.xcodeproj`.
- [x] **Baseline da suíte:** `** TEST SUCCEEDED **`, **186 testes, 0 falhas** (12,7 s). `lsregister | grep -c` = **7 antes → 11 durante → 7 depois** do `lsregister -u`; tap da release segue `enabled=YES` (id 1025202362), permissões intactas.
  - ⚠️ **Divergência do comando padrão (2026-09-07) — resolvida:** o comando padrão do plano **não builda nesta máquina**. `project.yml` fixa Debug e TagarelaTests em `CODE_SIGN_IDENTITY: 78C7C6375957D553AD632832D0821B446F53D0F3` / `DEVELOPMENT_TEAM: BCM26K6YNA` — certificado da **outra** máquina (auditoria §5.5, "Team IDs diferentes"), que aqui não existe: `No certificate for team 'BCM26K6YNA'`. Ver **Comando padrão nesta máquina** abaixo.
- [x] **Baseline em campo** (release v1.0.3 build 4, PID 1569, uptime 9d13h — mesmo processo da auditoria):
  - `event_taps`: `tap id=1025202362 pid=1569 enabled=YES options=1 point=1 mask=0x1400`.
  - `vmmap -summary`: footprint **166,0 MB**, pico **313,3 MB**, IOSurface **206 regiões / 105,8 MB**, `neural_peak` 3001 MB — idênticos aos da auditoria (§3.2), sem drift.

---

## Tarefa 1: `Diag` + `DiagnosticsLog` — diagnóstico persistido

Objetivo: toda linha que explica um "não fez o STT" sobrevive dias (arquivo) e horas (unified log em `.notice`/`.error`), sem conteúdo do ditado.

**Files:** criar `App/Diagnostics/DiagnosticsLog.swift`, `App/Diagnostics/Diag.swift`, `TagarelaTests/DiagnosticsLogTests.swift`; modificar logs em `Audio/AudioCaptureLive.swift`, `Pipeline/PipelineCoordinator.swift`, `Transcription/WhisperKitTranscriber.swift`, `Hotkey/HotkeyServiceLive.swift`, `Injection/InjectorLive.swift`, `App/AppContainer.swift`.

- [x] **Step 1 — testes de `DiagnosticsLog`** (`DiagnosticsLogTests`): escreve linha com timestamp ISO-8601 + nível + categoria + mensagem; rotaciona ao passar `maxBytes` (usar 2 KB no teste) mantendo `maxFiles` (3) — `tagarela.log`, `tagarela.1.log`, `tagarela.2.log`; é seguro sob 50 threads concorrentes (`DispatchQueue.concurrentPerform`) sem linhas interleaved; `contents(limit:)` devolve as últimas N linhas; diretório inexistente é criado.
- [x] **Step 2 — implementar `DiagnosticsLog`:** `final class DiagnosticsLog: @unchecked Sendable` com `init(directory: URL, fileName: String = "tagarela.log", maxBytes: Int = 5_000_000, maxFiles: Int = 3)`, `func append(level: String, category: String, message: String)` (lock + `FileHandle` aberto em append; `fsync` não é necessário), rotação por rename, `static let shared` apontando para `~/Library/Logs/Tagarela/`.
- [x] **Step 3 — implementar `Diag`:** fachada `enum Diag` com `static func notice(_ cat: Category, _ msg: String)`, `error`, `info` (info **não** vai ao arquivo). `Category` = `audio, pipeline, transcribe, hotkey, inject, permissions, app, health`. Cada chamada emite no `Logger(subsystem: "com.tagarela", category:)` **e** no `DiagnosticsLog.shared` (exceto `.info`). Manter os `Logger` existentes onde a mensagem é só depuração.
- [x] **Step 4 — promover marcos.** Trocar por `Diag.notice`: `AudioCaptureLive.start` (formato de entrada: `sampleRate`, `channelCount`, nome do device default), `AudioCaptureLive.stop` (`raw`, `resampled`, `peak before/after`, `wallClock`, `buffers`), `PipelineCoordinator` (`toggle in state=…`, `buffer duration=…`, `transcribed chars=N` — **não** o texto, `injecting`, `injected to <bundle>`), `WhisperKitTranscriber.transcribe` (já é `.notice`; incluir métricas da Tarefa 5), `HotkeyServiceLive` (`started`, `re-enabled`), `InjectorLive` (`pasted`, `restored`, `restore skipped`). Trocar por `Diag.error`: `buffer too short` quando wall-clock ≥ 1 s, `raw == 0`, `engine.start() falhou`, `transcribed vazio com peak ≥ 0,3`, `tap desabilitado`, `AXIsProcessTrusted == false`, `loadModel FALHOU`, `inject failed`, `history save failed`.
- [x] **Step 5 — grep de privacidade:** `grep -rn "Diag\.\(notice\|error\)" app/Tagarela | grep -iE "raw\b|refined|text:" ` não pode logar variáveis de texto. Adicionar teste `DiagnosticsLogTests.test_noDictatedTextInSources` que faz esse grep via `#filePath` e falha se encontrar `\(raw` ou `\(refined` dentro de chamadas `Diag.`.
- [x] **Step 6 — build + suíte verde.** Commit: `feat(diag): Diag + DiagnosticsLog — marcos do pipeline persistidos em arquivo e .notice`.

Aceite: após um ditado no build de dev, `tail -20 ~/Library/Logs/Tagarela/tagarela.log` mostra `start → stop → buffer → transcribed chars → injected` com números, sem texto. **Pendente** — depende de rodar o app de dev, o que só acontece no primeiro aceite manual (Tarefa 3); virou o Bloco F do checklist.

Fechada em 2026-09-07. Suíte 186 → **193** verde. Divergências (todas com fecho previsto em tarefa posterior) registradas em [`11-modulos-fase5.md`](../02-arquitetura/11-modulos-fase5.md): `transcribed vazio` ainda sem a condição de pico (depende do `CaptureStats` da Tarefa 3), `restore skipped` ainda não existe (Tarefa 8), `buffersSeen`/`channelBuffers` seguem sem lock (Tarefa 3).

---

## Tarefa 2: `PipelineHealth` + "Exportar diagnóstico"

Objetivo: o usuário (e o próximo chat) veem em 10 segundos se o app está degradado e conseguem mandar um pacote de evidência.

**Files:** criar `App/Diagnostics/PipelineHealth.swift`, `App/Diagnostics/DiagnosticsExporter.swift`, `TagarelaTests/PipelineHealthTests.swift`; modificar `App/AppContainer.swift`, `UI/MenuBar/MenuBarContent.swift`, `UI/MenuBar/StateRow.swift`, `Preferences/UI/Sections/AboutView.swift`, `Localizable.strings`.

- [x] **Step 1 — testes:** `PipelineHealth` conta `recordings`, `discardedShort`, `emptyTranscriptions`, `injectionFailures`, `recoveries`, `lastSuccessAt`, `consecutiveEmpty` (zera em sucesso); `uptime` calculado a partir de `launchedAt` injetável; `summaryLine` (ex.: `12 ditados · 0 vazios · 0 curtos · 3d 4h`).
- [x] **Step 2 — implementar** `@MainActor final class PipelineHealth: ObservableObject` com `@Published` nos contadores; `AppContainer.wirePipelineToAppState` alimenta a partir dos eventos (`.finished` → sucesso; `.captureFailed`, `.emptyTranscription`, `.injectionFailed`, `.transcriberRecoveryRequested` → respectivos).
- [x] **Step 3 — menu:** `StateRow` ganha linha `health.summaryLine` em mono 10 abaixo do sub-label (só quando `recordings > 0`). Corrigir de passagem os sub-labels errados (auditoria §5.3): `.processing` → nome do modelo carregado; `.refining` → `prefs.refinerKind`/modelo; `.idle` → "⌥ direito pra começar".
- [x] **Step 4 — `DiagnosticsExporter.export() -> URL`:** cria `~/Desktop/tagarela-diagnostico-<data>/` com `tagarela.log*` copiados, `snapshot.txt` (versão/build, uptime, `PipelineHealth`, prefs relevantes sem segredos, device de entrada default + formato via `AVAudioEngine().inputNode.outputFormat(forBus:0)`, `AXIsProcessTrusted`, `IOHIDCheckAccess`, `CGGetEventTapList` filtrado pelo próprio pid, `loadedModelName`, `modelStore.isDownloaded`) e `vmmap.txt` (`/usr/bin/vmmap -summary <pid>` via `Process`, best-effort). Revela no Finder. Botão "Exportar diagnóstico…" em `AboutView` ao lado de "Abrir logs no Console" (que passa a abrir o arquivo: `open ~/Library/Logs/Tagarela/tagarela.log`).
- [x] **Step 5 — strings** (`about.diagnostics.export`, `about.diagnostics.exported`, `menubar.health.summary` formato) + `LocalizableKeysTests`.
- [x] **Step 6 — suíte verde.** Commit: `feat(diag): PipelineHealth no menu + Exportar diagnóstico`.

Aceite manual: exportar, abrir a pasta, conferir os 3 arquivos e que `snapshot.txt` não contém API key nem texto ditado. Coberto por `DiagnosticsExporterTests` (log + snapshot + ausência de segredo); a conferência a olho vira o Bloco F do checklist.

Fechada em 2026-09-07. Suíte 193 → **203** verde. Divergências em [`11-modulos-fase5.md`](../02-arquitetura/11-modulos-fase5.md): `MenuBarContent` mora em `MenuBarController.swift` (o arquivo do plano não existe); os eventos `.captureFailed`/`.emptyTranscription`/`.transcriberRecoveryRequested` só chegam ao `PipelineHealth` na Tarefa 4, que já prevê isso.

---

## Tarefa 3: captura de áudio self-healing (`AudioCaptureLive` + `AudioMath`)

Objetivo: gravação nunca termina "sem áudio" em silêncio; engine não envelhece; níveis funcionam em toda gravação.

**Files:** criar `Audio/AudioMath.swift`, `TagarelaTests/AudioMathTests.swift`; modificar `Audio/AudioCapturing.swift`, `Audio/AudioCaptureLive.swift`, `TagarelaTests/PipelineCoordinatorTests.swift` (fake de áudio com níveis).

- [x] **Step 1 — extrair `AudioMath`** (puro, `enum AudioMath`): `downmix(perChannel: [[Float]]) -> [Float]` (usa o **maior** canal e zero-fill nos menores, devolvendo também `channelMismatch: Bool`), `resampleLinear(_:from:to:)`, `peakNormalize(_:targetPeak:maxGain:)`, `peak(_:)`. Testes: downmix de 2 canais iguais preserva; canal vazio **não** zera o resultado e marca mismatch; resample 48k→16k de um seno mantém frequência (contar cruzamentos por zero); boost respeita `maxGain`; silêncio não é boostado.
- [x] **Step 2 — `AudioCapturing`:** documentar `levels` como "stream válido para a gravação iniciada pelo último `start()`; obter **após** `start()`"; adicionar `case noAudioDelivered` em `AudioCaptureError`; adicionar `struct CaptureStats: Sendable { rawFrames, buffers, inputSampleRate, inputChannels, resampledFrames, peakBefore, peakAfter, wallClockSeconds, channelMismatch, engineRecreated }` e `var lastStats: CaptureStats? { get }`.
- [x] **Step 3 — `AudioCaptureLive.start()`:**
  ```swift
  func start() throws {
      // permissão como hoje
      engine = AVAudioEngine()                       // engine NOVO por gravação (var, não let)
      configObserver = NotificationCenter.default.addObserver(
          forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
          self?.noteConfigurationChange()            // Diag.error("audio", "configuration change during recording")
      }
      levelStream = AsyncStream.makeStream(of: Double.self)   // stream por gravação
      try installTapAndStart()                        // lê outputFormat, installTap, prepare, start; em catch: removeTap + throw engineFailedToStart
      startedAt = ContinuousClock.now
      buffersSeen = 0
      watchdog = Task { [weak self] in                 // 1 s sem buffer → recria uma vez
          try? await Task.sleep(for: .seconds(1))
          await self?.watchdogFired()
      }
  }
  ```
  `watchdogFired()`: se `buffersSeen == 0` e ainda gravando → `Diag.error(.audio, "no buffers after 1s; recreating engine")`, `stats.engineRecreated = true`, derruba tap+engine, cria engine novo, `installTapAndStart()` de novo; se **ainda** nenhum buffer após mais 1 s → marca `noAudioDelivered` para o `stop()` lançar.
- [x] **Step 4 — `stop()`:** remove tap, `engine.stop()`, remove observer, cancela watchdog, copia `channelBuffers` **sob lock** (`OSAllocatedUnfairLock`), zera, calcula via `AudioMath`, preenche `lastStats`, `Diag.notice(.audio, "stop raw=… buffers=… in=…Hz/…ch → 16k=… peak …→… wall=…s")`. Se `noAudioDelivered` ou `resampled.count == 0` com `wallClock ≥ 1 s` → `Diag.error` + `throw AudioCaptureError.noAudioDelivered`. `levelContinuation.finish()` no fim (o consumidor termina naturalmente; **não** cancelar a Task consumidora).
- [x] **Step 5 — `PipelineCoordinator.spawnRecordingTasks`:** ler `audio.levels` **depois** de `start()` (já é assim) e **não** cancelar a Task dos níveis em `cancelRecordingTasks()` — ela termina quando o stream finaliza; só o ticker de 80 ms é cancelado.
- [x] **Step 6 — teste de regressão:** `PipelineCoordinatorTests.test_levels_arrive_in_second_recording` com `FakeAudio` que cria um stream novo por `start()` e emite níveis; toggle→toggle→toggle→esperar `.recording(_, audioLevel: 0.5)` na segunda gravação. (Este teste **falha** no código atual — é a prova do bug.)
- [x] **Step 7 — build + aceite manual em build local:** Bloco A do checklist (§Tarefa 12). Commit: `fix(audio): engine por gravação + watchdog + stats + níveis por gravação; AudioMath extraído`.
  - Código commitado e suíte verde (203 → **215**). `test_levels_arrive_in_second_recording` esteve **vermelho** antes da correção (falhava na 2ª gravação) e ficou verde depois.
  - Aceite Bloco A em 2026-09-07: **`ok-parcial`**. A1 (três ditados com ondas animando nos três) e A6 (log completo, sem texto ditado) confirmados pelo usuário; **A2–A5 não exercitados** e reprogramados para a Tarefa 12. Detalhe em [`fase5-manual.md`](../03-funcionalidades/checklists/fase5-manual.md).

Risco a medir: latência do primeiro buffer com engine novo (esperado < 100 ms). Se > 300 ms perceptíveis, alternativa: manter engine mas recriar em `AVAudioEngineConfigurationChange` e após `raw == 0`.

---

## Tarefa 4: pipeline com falhas visíveis + recuperação + corridas

**Files:** `Pipeline/PipelineEvent.swift`, `Pipeline/PipelineCoordinator.swift`, `UI/Toast/ToastKind.swift`, `App/AppContainer.swift`, `TagarelaTests/PipelineCoordinatorTests.swift`, `Localizable.strings`.

- [x] **Step 1 — eventos e toasts:** `PipelineEvent.captureFailed(reason: CaptureFailureReason)` (`noAudio`, `tooShort`), `.emptyTranscription`, `.transcriberRecoveryRequested`, `.transcriberRecovered`. `ToastKind.captureFailed` ("Não captei áudio do microfone. Confira o dispositivo de entrada."), `.emptyTranscription` ("Não entendi nada — tente de novo."), `.transcriberRecovered` ("Reconhecedor reiniciado.").
- [x] **Step 2 — testes (escrever antes):**
  - `test_tooShortAfterLongRecording_emitsCaptureFailed` (fake devolve 0,2 s após 2 s de gravação simulada → evento + `.idle`); `test_tooShortAfterTapRecording_isSilent` (< 1 s de wall-clock → só `.idle`, sem evento — toque acidental na hotkey não vira toast).
  - `test_audioStopThrowsNoAudioDelivered_emitsCaptureFailed`.
  - `test_emptyTranscription_doesNotInjectNorSave_emitsEvent`.
  - `test_twoConsecutiveEmpty_requestsRecovery`; `test_successResetsConsecutiveEmpty`.
  - `test_errorAutoRecover_doesNotClobberNewRecording` (erro → toggle em < 2 s → estado permanece `.recording` após os 2 s).
  - `test_toggleAfterCancelWaitsForPreviousPipelineTask` (fake transcriber lento; Esc; toggle imediato → `audio.start()` só é chamado depois que a task anterior terminou ou após timeout de 3 s).
  - `test_historySavedEvenWhenInjectFails` (ordem save → inject).
- [x] **Step 3 — implementar:** guard de duração passa a distinguir wall-clock (`startTime`) de buffer; `raw.isEmpty` → `health`/evento e `return` sem inject/save; contador `consecutiveEmpty` no actor; recovery: emitir `.transcriberRecoveryRequested` e o `AppContainer` chama `transcriber.reload()` (Tarefa 5) numa Task, emitindo `.transcriberRecovered` ao terminar (toast); no `catch` final: `if case .error = state { setState(.idle) }` após o sleep; `handleToggle` em `.idle`: `if let previous = pipelineTask { await previous.valueWithTimeout(3 s) }` (helper `withTimeout` no arquivo); ordem `historyStore.save` **antes** de `injector.inject` (o `frontmostAppBundleID` passa a ser lido antes, via `injector.frontmostBundleID()` — adicionar ao protocolo `Injecting` com default).
- [x] **Step 4 — `AppContainer.wirePipelineToAppState`:** mapear os eventos novos para toasts e `PipelineHealth`; recovery com `Diag.error(.pipeline, "recovery requested after N empty")`.
- [x] **Step 5 — suíte verde.** Commit: `fix(pipeline): falhas de captura/transcrição visíveis, recovery do transcriber, corridas .error→.idle e transcribe concorrente`.

Fechada em 2026-09-07. Suíte 215 → **224** verde. Notas em [`11-modulos-fase5.md`](../02-arquitetura/11-modulos-fase5.md): (a) o `Localizable.strings` **não tinha chave `toast.*` nenhuma** — todos os toasts do app viviam do `defaultValue`; só as três novas entraram, o resto é da Tarefa 10; (b) a recriação do transcriber ainda passa por `loadModel` (toca a rede) até a Tarefa 5 entregar o `reload()` de disco; (c) `PipelineCoordinator` ganhou relógio injetável para testar o limiar de wall-clock sem sleeps de segundos.

---

## Tarefa 5: transcriber — métricas, carga local sem rede, `reload()`

**Files:** `Transcription/Transcribing.swift`, `Transcription/WhisperKitTranscriber.swift`, `Transcription/WhisperModelStore.swift`, `Transcription/WhisperModelStoreLive.swift`, `TagarelaTests/WhisperKitTranscriberTests.swift`, mocks em `PipelineCoordinatorTests`/`WhisperModelSwapCoordinatorTests`.

- [x] **Step 1 — protocolo:** `struct TranscriptionOutcome: Sendable { text: String; detectedLanguage: String?; avgLogprob: Float?; compressionRatio: Float?; noSpeechProb: Float?; wallMs: Int; segments: Int }`; `transcribe(...) async throws -> TranscriptionOutcome`; `func reload() async throws` (descarrega e recarrega **do disco** o `loadedModelName` atual; lança `modelNotLoaded` se nenhum). Atualizar todos os fakes.
- [x] **Step 2 — `WhisperModelStore.modelFolderURL(for:) -> URL?`** (devolve a URL se `isDownloaded`). Teste no `WhisperModelStoreTests` existente.
- [x] **Step 3 — `loadModel` sem rede:** `if let local = store.modelFolderURL(for: name) { folder = local } else { folder = try await WhisperKit.download(variant: name, …) }`. `WhisperKitTranscriber.init(store: WhisperModelStore = WhisperModelStoreLive())`. Teste: com fake store dizendo "presente", um `downloader` injetável **não** é chamado; dizendo "ausente", é chamado (extrair a chamada de download para closure `downloader: (String, @escaping (Double)->Void) async throws -> URL` injetável; default = `WhisperKit.download`).
- [x] **Step 4 — métricas:** montar `TranscriptionOutcome` a partir de `results.first?.segments.last` (`avgLogprob`, `compressionRatio`, `noSpeechProb`) e `results.first?.language`; `Diag.notice(.transcribe, "model=… audio=…s wall=…ms lang=… chars=… segs=… logprob=… cr=… nsp=…")`. Vazio → `Diag.error` com as mesmas métricas.
- [x] **Step 5 — `reload()`:** `pipe = nil` → `WhisperKit(config local)` de novo com prewarm; `Diag.notice(.transcribe, "reloaded model=…")`.
- [ ] **Step 6 — suíte verde + aceite manual:** desligar Wi-Fi/Ethernet, relançar o build de dev → modelo carrega e transcreve (Bloco B). Commit: `feat(transcribe): métricas por ditado, carga do modelo local sem rede, reload()`.
  - Código commitado, suíte 224 → **229** verde. **Aceite do Bloco B pendente** — roteiro em [`fase5-manual.md`](../03-funcionalidades/checklists/fase5-manual.md).

---

## Tarefa 6: `PermissionService.snapshots` multicast + limpeza

**Files:** `Permissions/PermissionService.swift`, `Permissions/PermissionServiceLive.swift`, `UI/Onboarding/OnboardingCoordinator.swift`, `App/AppContainer.swift`, `App/AppState.swift`, `TagarelaTests/PermissionServiceTests.swift`.

- [x] **Step 1 — teste:** dois assinantes de `makeSnapshots()` recebem **todos** os snapshots (hoje dividem — teste falha no código atual). Usar um `PermissionServiceLive(probe:)` com closure de sondagem injetável e intervalo de 10 ms.
- [x] **Step 2 — implementar:** `current: CurrentValueSubject<PermissionsSnapshot, Never>` interno; `func makeSnapshots() -> AsyncStream<PermissionsSnapshot>` cria um stream por chamada a partir do subject (`.values` de um `AsyncPublisher` ou bridge manual com `sink` + `onTermination` cancelando). Manter `snapshots` como `makeSnapshots()` para compat, marcado deprecated.
- [x] **Step 3 — consumidores:** `OnboardingCoordinator` e `AppContainer` usam `makeSnapshots()`; `AppContainer` passa a **usar** `permissionsAllGranted` (badge no `StateRow` "permissões pendentes" quando `false` após o onboarding) ou remove o campo — escolher usar (barato) e expor no `PipelineHealth.summaryLine`.
- [x] **Step 4 — `[weak self]` por iteração** em `PermissionServiceLive.startPolling` e `OnboardingCoordinator.init`.
- [x] **Step 5 — suíte verde.** Commit: `fix(permissions): snapshots multicast; onboarding deixa de perder transições`.

---


Fechada em 2026-09-07. Suíte 229 → **230** verde. O teste de multicast esteve **vermelho** antes da correção, com o sintoma exato da auditoria (A recebeu 3 de 4 snapshots, B recebeu 2). Escolhido *usar* `permissionsAllGranted` (badge no `StateRow`) em vez de remover o campo.

## Tarefa 7: hotkey — `start()` idempotente, watchdog, re-start ao reconceder

**Files:** `Hotkey/HotkeyService.swift`, `Hotkey/HotkeyServiceLive.swift`, `App/AppContainer.swift`, `TagarelaTests/HotkeyCallbackTests.swift`.

- [x] **Step 1 — testes do callback com `CGEvent` sintético** (o callback estático é chamável diretamente com `refcon` = `Unmanaged.passUnretained(service)`): `flagsChanged` keyCode 61 com `.maskAlternate` **e** flag de device `0x40` → `.toggle`; release (sem `0x40`) → nada; Esc → `.cancel`; `tapDisabledByTimeout` → `reEnableTap` chamado (contar via closure de teste injetada em `tapEnabler`).
- [x] **Step 2 — `start()` idempotente:** se `eventTap != nil`: `tapEnable(false)`, `CFMachPortInvalidate`, remover source, zerar; então criar. `stop()` idem.
- [x] **Step 3 — watchdog:** `Task` de 30 s: `if let tap, !CGEvent.tapIsEnabled(tap: tap) { Diag.error(.hotkey, "tap disabled; re-enabling"); tapEnable(true); health.recoveries += 1 }`. Expor `var isTapEnabled: Bool` no protocolo (para o snapshot do exportador).
- [x] **Step 4 — re-start ao reconceder:** `AppContainer` observa `makeSnapshots()`; transição `inputMonitoring: != .granted → .granted` → `try? hotkeyService.start()` + `Diag.notice`.
- [x] **Step 5 — flag de device** `0x40` (`NX_DEVICERALTKEYMASK`) no filtro do Right Option.
- [ ] **Step 6 — suíte verde + aceite manual** (Bloco C: desligar/ligar Input Monitoring com o app aberto → hotkey volta sem relaunch). Commit: `fix(hotkey): start idempotente, watchdog do tap, re-start ao reconceder Input Monitoring`.

---


Código fechado em 2026-09-07, suíte 230 → **236** verde. `isTapEnabled` passou a ser lido pelo próprio watchdog (em vez de virar propriedade sem uso, que é o defeito que a auditoria apontou em `permissionsAllGranted`); o snapshot do exportador já lista os event taps do processo direto do `CGGetEventTapList`, que é evidência melhor. **Aceite do Bloco C pendente.**

## Tarefa 8: injeção sem perda de ditado

**Files:** `Injection/Injecting.swift`, `Injection/InjectorLive.swift`, `UI/Toast/ToastKind.swift`, `TagarelaTests/InjectorTests.swift`, `Localizable.strings`.

- [x] **Step 1 — ordem:** escrever no pasteboard **antes** de `AXIsProcessTrusted()`; se negado, lançar `accessibilityDenied` **com o texto já no clipboard** (toast passa a dizer, verdadeiramente, "texto na área de transferência").
- [x] **Step 2 — restore seguro:** `restoreDelay` 400 ms (Electron); executar a restauração em `Task.detached` (não cancelável pelo pipeline) e **só** se `pasteboard.changeCount == changeCountAfterWrite` (ninguém mexeu) **e** a cola foi confirmada — como não há confirmação de ⌘V, adotar: restaurar o snapshot **apenas se** o snapshot anterior não era vazio; caso contrário deixar o ditado no clipboard. Registrar a decisão no ADR-0008.
- [x] **Step 3 — `frontmostBundleID()`** no protocolo (usado pela Tarefa 4 para salvar histórico antes da cola).
- [x] **Step 4 — testes** (`InjectorTests`, gated por `TAGARELA_INTEGRATION=1` porque usam `NSPasteboard.general`): texto vai ao pasteboard mesmo com AX negado (injetar `axTrusted: () -> Bool` fake); restore não acontece se `changeCount` mudou.
- [ ] **Step 5 — aceite manual** (Bloco D: colar no Claude desktop, no Codex e no WhatsApp; Esc durante a cola; revogar Accessibility e ditar → toast + texto no clipboard + entrada no histórico). Commit: `fix(inject): ditado nunca se perde — pasteboard antes do AX, histórico antes da cola, restore condicional`.

---


Código fechado em 2026-09-07, suíte 236 → **240** verde. Divergência (melhoria): os testes usam um `NSPasteboard` nomeado próprio em vez do `general`, então dispensam o gate `TAGARELA_INTEGRATION=1` e não mexem no clipboard de quem roda a suíte. O item **9h** (copy do `injectionFailed`) foi feito aqui, por estar acoplado. **Aceite do Bloco D pendente.**

## Tarefa 9: correções pontuais confirmadas

Cada item é pequeno; um commit por item ou agrupado como `fix(misc)`.

- [x] **9a — swap persiste no `AppContainer.swapActive`** (`prefs.whisperModelName = newActive.loadedModelName`); `TranscriptionView.handleStateTransition` só oferece cleanup. Teste: `WhisperModelSwapCoordinatorTests` com `swapActive` que registra a persistência.
- [x] **9b — `OllamaHealthChecker`:** `isAvailable(baseURL:)` com cache por URL; não cachear quando `Task.isCancelled` ou erro `.cancelled`; TTL negativo 3 s. `OllamaRefiner` passa sua URL. Testes com `MockURLProtocol`.
- [x] **9c — `OllamaRefiner`:** enviar `"options": {"num_ctx": RemoteRefinerConfig.contextWindow(for:)}`. Teste no `OllamaRefinerTests` (payload contém `num_ctx`).
- [x] **9d — `PreferencesStore.init`:** clampar `historyMaxItems/Days ≥ 1` e `refinerTimeoutSec` em `5…600` na carga. Testes.
- [x] **9e — `OpenAIKeyPromptWindow`:** `NSWindow.willCloseNotification` → `close(canceled: true)`; `show(onCancel:onSaved:)` explícito nos dois callsites.
- [x] **9f — `FloatingIndicatorPanel`:** `.fullScreenAuxiliary` no `collectionBehavior`; `show()` cancela `previewTask`; posicionar no cursor só na transição oculto → visível.
- [x] **9g — onboarding fechado sem concluir:** item de menu "Concluir configuração…" visível enquanto `showOnboarding == true`, que reabre a janela.
- [x] **9h — `ToastKind.injectionFailed` copy** coerente com a Tarefa 8.
- [ ] Suíte verde + aceite manual dos itens de UI (Bloco E). Commit(s).

---


Código fechado em 2026-09-07, suíte 240 → **248** verde. O item **9h** saiu junto da Tarefa 8, por estar acoplado à nova política de clipboard. **Aceite do Bloco E pendente.**

## Tarefa 10: localização — 37 chaves ausentes + teste derivado dos fontes

- [x] **Step 1 — `LocalizableKeysTests`** passa a localizar a raiz do repo via `#filePath`, varrer `app/Tagarela/**/*.swift` com regex `String\(localized: *"([^"]+)"` e `NSLocalizedString\( *"([^"]+)"`, e falhar listando chaves ausentes no `.strings` do bundle. (Deve falhar com 37 + as novas desta fase.)
- [x] **Step 2 — adicionar as chaves** (lista na auditoria §5.3; recontagem: 185 no código × 149 no arquivo) com os `defaultValue` atuais como texto; remover `onboarding.model.badge.recommended` (sem uso); corrigir `%d` → `%lld` na `:172`; atualizar `:45` ("fala português.") para refletir a Fase 4; strings hardcoded em `OnboardModel.swift:40` ("retry"), `HistoryEntryView.swift:28`, `TranscriptionView.swift:181-183`; texto do card de Acessibilidade (é para ⌘V, não para o atalho).
- [x] Suíte verde. Commit: `fix(l10n): 37 chaves ausentes + teste derivado dos fontes`.

---


Fechada em 2026-09-07. O teste derivado reproduziu a contagem da auditoria na mosca — **37 ausentes e 1 sem uso** — antes da correção. Suíte 248 → **249** verde; arquivo 149 → 200 chaves.

## Tarefa 11: scripts de release — ordem segura do appcast

**Files:** `scripts/release.sh`, `scripts/appcast.sh`, `scripts/bump.sh`.

- [x] **11a — ordem:** `appcast.sh` **não** commita mais; `release.sh` passa a: build → sign → notarize → dmg → `git tag -a` → `gh release create` (upload do DMG) → `curl -sSfI <URL do DMG>` (HTTP 200) → gerar/commitar `appcast.xml` → `git push --follow-tags`. Se qualquer passo após a tag falhar, imprimir instruções de rollback (`git tag -d`, `gh release delete`).
- [x] **11b — `sign_update`:** procurar primeiro em `build/release/derived/SourcePackages/artifacts`, depois em `~/Library/Developer/Xcode/DerivedData/Tagarela-*`.
- [x] **11c — bump idempotente:** se `HEAD` já é um commit `chore(release): bump` sem tag correspondente, `release.sh` reaproveita em vez de bumpar de novo.
- [x] **11d — `LC_ALL=C date -u` no `pubDate`.**
- [ ] Smoke test em branch temporária (`_release-smoke`) com `gh release create --draft` e rollback, como feito na Fase 3. Commit: `fix(release): appcast só depois do DMG publicado; sign_update no derived do release; bump idempotente`.

---


Código fechado em 2026-09-07; todos os scripts passam `bash -n`. **Smoke test não executado** — cria uma release no GitHub do usuário e precisa de rede e autorização explícita; fica junto do aceite manual, antes da v1.0.4.

## Tarefa 12: aceite manual + docs + merge + release v1.0.4

- [ ] **Checklist** `03-funcionalidades/checklists/fase5-manual.md` com os blocos:
  - **A — Captura:** 3 ditados seguidos com ondas animando em todos; desconectar/reconectar a C920 entre ditados; trocar o input default para outro device e voltar; ditar com o mic ocupado por outro app; ditado de 60 s; conferir `tagarela.log`.
  - **B — Modelo:** launch sem rede → transcreve; forçar 2 vazios (mic mudo/desligado no sistema) → toast "não entendi" ×2 + "reconhecedor reiniciado" + `Diag.error` no log; ditado seguinte funciona.
  - **C — Hotkey:** revogar e reconceder Input Monitoring → volta sem relaunch; `tools/diag/event_taps.swift` mostra `enabled=YES`.
  - **D — Cola:** Claude desktop, Codex, WhatsApp, Notes; Esc durante a cola; Accessibility revogada → toast + clipboard + histórico.
  - **E — UI:** tela cheia mostra indicador; fechar modal da key no ⨯ faz rollback; onboarding fechado reabre pelo menu; swap de modelo persiste após relaunch mesmo navegando de seção.
  - **F — Diagnóstico:** menu mostra saúde; Exportar diagnóstico gera a pasta; Console/arquivo mostram `.notice` de um ditado.
  - **G — Não-regressão:** blocos essenciais das Fases 2a/2d/4 (estilos, Ollama com `num_ctx`, idioma auto/pt/en).
- [ ] **Docs:** `02-arquitetura/11-modulos-fase5.md` (snapshot: módulos novos/modificados, decisões, contagem da suíte), `04-decisoes/ADR-0008-diagnostico-persistido-e-self-healing.md` (Contexto / Decisão / Consequências / Alternativas — inclui a política de restore do clipboard e "nunca injetar vazio"), `README.md` (índice + status), auditoria (`status:` → "fase 5 em execução/concluída").
- [x] **Merge** `fase-5-robustez` → `main` (`--no-ff`), suíte verde em `main`. — 2026-09-24, merge `7d1c9c0`; suíte na main mesclada: 253 verdes + 1 pulado (integração).
- [x] **Release** `./scripts/release.sh patch` → v1.0.4 (build 5). — **Publicada em 2026-09-24**: https://github.com/IlanSalviano/tagarela/releases/tag/v1.0.4. Verificado de fora: release pública com `Tagarela-1.0.4.dmg` (7,3 MB), DMG com HTTP 200, `appcast.xml` do raw da main anunciando `sparkle:version` 5. Dentro do DMG: assinado com o Developer ID novo, **DR idêntico ao da v1.0.3**, Gatekeeper `accepted · Notarized Developer ID`, staple válido, `SUPublicEDKey` novo. A primeira execução parou na etapa 6 sem publicar nada (tag precisava subir antes do `gh release create`); corrigido em `5e8569b` e a segunda execução passou inteira.
  - ⛔ **Bloqueado nesta máquina (verificado em 2026-09-24).** Correção de um registro anterior impreciso: o **certificado existe** — `developerID_application.cer` está na raiz do repo (untracked), é o `Developer ID Application: Ilan Salviano (22CZXFP6W7)`, SHA-1 `E42EE72295E4853378FBEF2E589FBC7D609884EB` (exatamente o que o `project.yml` exige no Release) e vale até 2031-05-02. O pipeline de release funcionou de verdade: as v1.0.0 a v1.0.3 estão publicadas com DMG e assinatura.

    O que falta é a **chave privada**, não o certificado. Enumerando as chaves privadas dos keychains destrancados, nenhuma tem o id `D04049B67121840BBEEFF44633931698D66C6DE2` (SHA-1 PKCS#1 da chave pública do cert, que é o formato do `kSecAttrApplicationLabel`). Sem a chave, o `.cer` sozinho não assina nada.

    | Requisito | Estado |
    |---|---|
    | Cert Developer ID (`.cer` no repo) | ✅ válido até 2031, SHA-1 confere |
    | Chave privada no keychain | ❌ ausente |
    | `~/.tagarela-release.env` | ❌ ausente |
    | Chave EdDSA do Sparkle (`~/.tagarela-release/`) | ❌ ausente |
    | `mtbflow-ci.keychain-db` | 🔒 trancado — não inspecionado |

    Caminhos: importar o `.p12` (cert + chave) exportado da máquina onde o par foi gerado; ou verificar o keychain `mtbflow-ci`, que está trancado e pode conter a chave; ou cortar a release na outra máquina. Os três secrets do `.env` (Apple ID, app-specific password, caminho da chave EdDSA) precisam ser recriados de qualquer forma.

    **Atualização 2026-09-24 — certificado resolvido, com um certificado novo.** O keychain `mtbflow-ci` foi aberto pelo usuário: contém um **Apple Distribution** (marcas `…6.1.7`/`…6.1.4`, App Store), não um Developer ID (`…6.1.13`) — não serve. Emitido então um **Developer ID Application novo**, SHA-1 `3CAA2CE08BADECE2D96068A105494273F064C7B2`, válido até 2031-09-17, chave privada `Ilan Melo Salviano` no keychain de login; CSR e `.cer` guardados em `/Volumes/Brain/Dev/.certs/`.

    O ponto que tornou isso seguro: o designated requirement da v1.0.3 **não** fixa o certificado, só o tipo e o time — `certificate leaf[field.1.2.840.113635.100.6.1.13] and certificate leaf[subject.OU] = "22CZXFP6W7"`. Um app assinado com o certificado novo foi verificado com **DR idêntico** ao da v1.0.3, então permissões de TCC e compatibilidade de assinatura do Sparkle se mantêm. O certificado antigo **não** foi revogado: os DMGs v1.0.0–v1.0.3 publicados foram assinados com ele.

    `project.yml` (Release) aponta para o hash novo; `~/.tagarela-release.env` criado (600) com `APPLE_TEAM_ID` e `DEVELOPER_ID_APP_SHA1`.

    **Ainda com o usuário** (o modo automático do agente bloqueia gravação de chave privada em keychain, e senhas não são digitadas pelo agente): gerar a chave EdDSA nova do Sparkle (`generate_keys`, e exportá-la para `~/.tagarela-release/`), preencher `APPLE_ID` e `APPLE_APP_SPECIFIC_PASSWORD` no `.env`, e exportar o backup `.p12` do Developer ID novo. Depois: `SUPublicEDKey` novo no `Info.plist`. Consequência da chave nova do Sparkle: o app instalado espera a chave antiga, então a v1.0.4 é instalada **uma vez à mão** pelo DMG; dali em diante o Sparkle volta a funcionar.

    **Atualização 2026-09-24 (2) — pré-requisitos completos.** O usuário gerou a chave EdDSA nova do Sparkle (pública `0IuxsTZnVwiBZWvwiD8Y8/z15MnCjIeoUwk2EUSFIbc=`, privada exportada em `~/.tagarela-release/sparkle_ed_private.key`, 600), preencheu as credenciais de notarização no `.env` e exportou o backup `Certificates.p12` para `/Volumes/Brain/Dev/.certs/` (permissão restringida para 600). `SUPublicEDKey` do `Info.plist` atualizado. A partir da v1.0.4 as atualizações do Sparkle são assinadas com a chave nova; quem está na v1.0.3 (ou no build local) instala a v1.0.4 uma vez à mão.

    **Correção de registro:** uma busca ampla por `.p12`/chave do Sparkle feita em 2026-09-24 começava com `timeout`, comando que não existe no macOS; o erro ficou escondido por `2>/dev/null` e a busca nunca rodou. Refeita em 2026-09-24 sem esse defeito: de fato não há `.p12`, chave do Sparkle nem `.env` de release nesta máquina. Instalar em `/Applications`, confirmar update via Sparkle a partir da v1.0.3 (ADR-0007: `sparkle:version` = 5).
- [ ] Desregistrar builds locais (`lsregister -u`), conferir permissões da release.
  - Instalação da v1.0.4 nesta máquina: pendente, pelo usuário. Não dá para testar a atualização via Sparkle a partir da v1.0.3: a chave EdDSA foi trocada, então o app instalado não aceita o item novo — instalação manual única, como registrado acima.

---

## Tarefa 13: validação em campo e fechamento da causa-raiz

Só pode ser feita com tempo de calendário: a falha original leva dias para aparecer.

- [ ] Deixar a v1.0.4 rodando ≥ 7 dias com uso normal.
  - **Janela de campo iniciada em 2026-09-24** com o build local `1.0.4-fase5.1` (mesmo código da branch, assinado com a Apple Development desta máquina — a v1.0.4 notarizada está bloqueada pela falta da chave privada do Developer ID; ver Tarefa 12). O log persistente em `~/Library/Logs/Tagarela/tagarela.log` já está gravando. Contar os 7 dias a partir daqui; se a release oficial sair no meio, a janela continua.
- [ ] A cada 2–3 dias, olhar `PipelineHealth` no menu: `vazios`, `curtos` e `recuperações` devem estar em 0. Se subirem, o app já se recuperou sozinho — abrir `~/Library/Logs/Tagarela/tagarela.log` e identificar qual `Diag.error` disparou.
- [ ] Na primeira ocorrência (ou recuperação automática): **Exportar diagnóstico**, ler a sequência `start → stop → buffer → transcribe` do ditado que falhou, classificar em S1 (captura), S2 (decoder), S3 (cola) ou S4 (hotkey) conforme [auditoria §3.4](../02-arquitetura/10-auditoria-2026-09-07.md), e escrever a entrada #3 do `troubleshooting-runtime.md` com a causa **provada** pela linha de log.
- [ ] Se a causa for S1 com `configuration change` ou `engineRecreated = true`: manter engine por gravação, fechar. Se for S2 com métricas anômalas (`noSpeechProb` alto com pico bom): abrir investigação WhisperKit/ANE (Fase 5b) com o log em mãos. Se em 14 dias nada ocorrer: registrar no snapshot que a fase resolveu por construção e fechar.
- [ ] Atualizar `10-auditoria-2026-09-07.md` (`status:` → "causa-raiz: …") e `README.md`.

---

## Self-review (antes de declarar a fase pronta)

- [ ] Nenhuma linha `Diag.notice/error` contém texto ditado, clipboard ou API key (teste da Tarefa 1 verde).
- [ ] Todo caminho que hoje é silencioso (S1–S5 da auditoria) emite evento **e** linha `.error`.
- [ ] `PipelineCoordinatorTests.test_levels_arrive_in_second_recording` e `PermissionServiceTests` multicast estavam **vermelhos** antes das correções e ficaram verdes.
- [ ] Suíte completa verde; `xcodegen` sem drift; build Release assina e notariza.
- [ ] Docs: snapshot, ADR-0008, checklist com status, README, troubleshooting — todos commitados junto do código.
- [ ] Builds locais desregistrados; release em `/Applications` com permissões intactas.
