---
data: 2026-09-07
status: em execução (branch `fase-5-robustez`)
fase: 5-robustez-sessao-longa
origem: specs/2026-09-07-tagarela-v1-fase5-robustez-sessao-longa-plan.md
design: 02-arquitetura/10-auditoria-2026-09-07.md
---

# Snapshot pós-Fase 5 — robustez em sessão longa

Snapshot vivo: cada tarefa do plano acrescenta sua seção aqui quando fecha. O
"design" desta fase é a [auditoria de 2026-09-07](./10-auditoria-2026-09-07.md);
não existe design doc separado.

**Problema que a fase ataca:** depois de muitos dias no ar o app para de fazer
STT, sem crash; relaunch resolve. A auditoria não fechou a causa-raiz porque
todos os caminhos de falha candidatos são silenciosos por construção e o log
`.info` não persiste (retenção efetiva de ~1,5 dia para o processo do app nesta
máquina).

---

## Ambiente de build desta fase

Builds e testes usam DerivedData fixo fora do repo
(`~/Library/Developer/Xcode/DerivedData/Tagarela-fase5`) e o `.app` gerado
**nunca** é aberto — a release v1.0.3 está instalada em `/Applications` e em uso,
e uma cópia rival do mesmo bundle id derruba as permissões dela
([`cleanup-fase3.md`](../04-decisoes/cleanup-fase3.md)). Ao fim de cada sessão de
testes o host é desregistrado com `lsregister -u`.

Nesta máquina (`/Volumes/Brain`) o `project.yml` fixa Debug/Tests num certificado
que só existe na outra máquina (team `BCM26K6YNA`, achado §5.5 da auditoria —
unificar os Team IDs está **fora do escopo** desta fase). A identidade local é
passada por linha de comando, sem alterar arquivo commitado; o comando completo e
a justificativa da escolha estão na seção **Comando padrão nesta máquina** do
[plano](../specs/2026-09-07-tagarela-v1-fase5-robustez-sessao-longa-plan.md).

**Baseline (2026-09-07):** suíte 186 testes verdes; release v1.0.3 build 4 rodando
há 9d13h com footprint 166 MB e event tap `enabled=YES` — iguais aos da auditoria.

---

## Tarefa 1 — `Diag` + `DiagnosticsLog`: diagnóstico persistido ✅

**Módulos novos** (`app/Tagarela/App/Diagnostics/`):

| Arquivo | O que é |
|---|---|
| `DiagnosticsLog.swift` | Log em arquivo texto rotativo (`~/Library/Logs/Tagarela/tagarela.log`, 5 MB × 3), escrito de qualquer thread. Estado (`FileHandle`, tamanho, formatter ISO-8601) protegido por `OSAllocatedUnfairLock`; rotação por rename; `contents(limit:)` atravessa os arquivos rotacionados. Falha de escrita nunca propaga — diagnóstico não pode derrubar o app. |
| `Diag.swift` | Fachada. `Diag.notice/error/info(_ category:, _ message:)`. `.notice` e `.error` vão para o log unificado **e** para o arquivo; `.info` só para o unificado (onde praticamente não persiste — é para ruído de bancada). `Category` (`audio, pipeline, transcribe, hotkey, inject, permissions, app, health`) mapeia para as categorias que os `Logger` já usavam, então os predicados de `/usr/bin/log` da auditoria continuam valendo. |

**Por que arquivo e não só o log unificado:** a auditoria mediu retenção efetiva
de ~1,5 dia para o processo do app, com `.info` não chegando ao disco. O botão
"Abrir logs no Console" é inútil para uma falha de dias atrás. O arquivo é a
metade durável.

**Marcos promovidos** — todo `Logger` do caminho quente passou a `Diag`
(`AudioCaptureLive`, `PipelineCoordinator`, `WhisperKitTranscriber`,
`HotkeyServiceLive`, `InjectorLive`, `AppContainer`; a extensão morta
`Logger.tagarela` foi removida). Passam a persistir:

- `.notice`: `start in=…Hz/…ch device='…'`, `stop raw=… buffers=… in=… → 16k=… peak …→… wall=…s`, `toggle in state=…`, `buffer duration=… wall=…s`, `transcribed chars=N`, `injected to <bundle> chars=N`, `pasted to <bundle>`, `clipboard restored`, `transcribe model=… wall=…ms detLang=…`, `started for ⌥ direito`.
- `.error` (cada um explica um "não fez o STT"): `raw=0` com o wall-clock e o device default; `buffer too short` quando a gravação durou ≥ 1 s (separa toque acidental de falha real); `transcribed vazio`; `engine.start() falhou`; `inputNode sem formato`; `event tap estava desabilitado`; `AXIsProcessTrusted == false`; `inject failed`; `history save failed`; `loadModel FALHOU`.

**Instrumentação nova no `AudioCaptureLive`:** contador `buffersSeen` e
`startedAt`, para que o `stop()` possa contrastar duração capturada × wall-clock
e detectar `raw=0`. Também loga o **nome do device de entrada default** via
CoreAudio — a lista de devices muda várias vezes por dia nesta máquina, que é o
gatilho plausível da hipótese H1.

**Privacidade — nunca o texto ditado.** A linha `transcribed: '\(raw)'`, que até
aqui mandava **todo ditado** para o log, virou `transcribed chars=N`. Como as
linhas agora também vão para arquivo, o vazamento seria permanente. O teste
`DiagnosticsLogTests.test_noDictatedTextInSources` varre os fontes do app a
partir do `#filePath` e falha apontando arquivo:linha se alguma chamada `Diag.*`
interpolar `raw`, `refined`, `text`, `clipboard`, `apiKey`, `prompt` &c. inteiros
— `\(raw.count)` e `\(rawPeak)` passam, `\(raw)` não. Foi verificado em vermelho
injetando uma violação de mentira antes de fechar a tarefa.

**Divergências do plano** (fecham em tarefas posteriores, por dependência):

- `transcribed vazio` é logado sempre que o texto vem vazio, não só com "pico pós-boost ≥ 0,3": o pico só chega ao coordinator com o `CaptureStats` da Tarefa 3.
- `restore skipped` ainda não existe — a restauração condicional do clipboard é a Tarefa 8.
- `buffersSeen`/`channelBuffers` seguem sem lock, como já estavam; a Tarefa 3 põe os dois sob `OSAllocatedUnfairLock`.

**Testes:** +7 (`DiagnosticsLogTests`: formato ISO-8601, criação do diretório,
rotação com teto de arquivos, 50 escritores concorrentes sem linha interleaved,
`contents(limit:)` no arquivo corrente e atravessando rotacionados, privacidade).
Suíte **186 → 193**, verde.

---

## Tarefa 2 — `PipelineHealth` + "Exportar diagnóstico" ✅

**Módulos novos** (`app/Tagarela/App/Diagnostics/`):

| Arquivo | O que é |
|---|---|
| `PipelineHealth.swift` | `@MainActor ObservableObject` com contadores desde o launch: `recordings`, `discardedShort`, `emptyTranscriptions`, `injectionFailures`, `recoveries`, `consecutiveEmpty`, `lastSuccessAt`, `uptime`. `launchedAt` e o relógio são injetáveis (testes determinísticos). `summaryLine` = `12 ditados · 0 vazios · 0 curtos · 3d 4h`. |
| `DiagnosticsExporter.swift` | Monta `~/Desktop/tagarela-diagnostico-<data>/` com o log rotativo, `snapshot.txt` e `vmmap.txt`, e revela no Finder. |

**Por que contadores:** a degradação desta fase é silenciosa — o usuário só
descobre quando tenta ditar. Com `vazios`/`curtos`/`recuperações` no menu, a
resposta a "o app tá bem?" leva 10 segundos.

**Detalhe que valia um teste:** `recordings` conta a **transição** para
`.recording`, não cada `.stateChanged`. O estado é republicado 12–25×/s enquanto
grava; contar por evento multiplicaria o número por cem.

**`snapshot.txt`** reúne o que a auditoria teve de coletar à mão: versão/build,
macOS, pid, uptime e contadores, modelo carregado e presente em disco,
preferências **sem segredos**, formato do `inputNode` e nome do device de entrada
default, `AXIsProcessTrusted`, `IOHIDCheckAccess`, status do microfone, e os
event taps **do próprio processo** (responde "a hotkey ainda está viva?" sem
expor os taps de outros apps). A API key mora no Keychain e não é lida.

**Menu (`StateRow`)** ganha a linha de saúde abaixo do sub-label, só depois do
primeiro ditado da sessão. De passagem, os sub-labels que a auditoria §5.3
apontou como mentirosos foram corrigidos:

| Estado | Antes | Agora |
|---|---|---|
| `.idle` | "right ⌥ pra começar" (metade em inglês) | "⌥ direito pra começar" |
| `.processing` | "whisper large-v3" fixo | nome do modelo realmente carregado |
| `.refining` | "identity (sem llm)" — justamente o caso em que `.refining` nem acontece | `ollama · <modelo>` / `openai · <modelo>` |

**Preferências › Sobre:** botão **"Exportar diagnóstico…"** ao lado de
**"Abrir log do app"** — que deixou de abrir o Console filtrado por subsystem e
passa a abrir `~/Library/Logs/Tagarela/tagarela.log`, pelo motivo de sempre: o
Console não alcança uma falha de dias atrás.

**Divergências do plano:**

- O plano cita `UI/MenuBar/MenuBarContent.swift`; o arquivo não existe — a view `MenuBarContent` mora em `MenuBarController.swift`, e foi lá que a mudança entrou.
- O plano manda alimentar `PipelineHealth` também com `.captureFailed`, `.emptyTranscription` e `.transcriberRecoveryRequested`. Esses eventos só nascem na Tarefa 4; por ora estão ligados `.stateChanged` (gravações), `.finished` (sucesso) e `.injectionFailed`. A Tarefa 4 fecha o resto — o próprio plano já prevê isso no Step 4 dela.
- Fora do plano: `DiagnosticsExporterTests` afirma que a exportação escreve log + snapshot, que o snapshot traz as seções esperadas e que não vaza segredo. O plano deixava isso para aceite manual; um teste é mais barato e não depende de alguém olhar.

**Testes:** +10 (9 de `PipelineHealth`, 1 de exportação). Suíte **193 → 203**, verde.

---

## Tarefa 3 — captura de áudio self-healing ✅ (aceite `ok-parcial`)

**Módulo novo:** `Audio/AudioMath.swift` — `downmix`, `resampleLinear`,
`peakNormalize`, `peak`, puros e testáveis sem microfone. A qualidade do ASR
depende inteiramente destas três operações e **nenhuma tinha teste** antes.

**Bug corrigido no downmix.** Usava o **menor** canal (`min`), então um canal
vazio zerava a gravação inteira — que virava "buffer curto" descartado em
silêncio, o caminho S1 da auditoria §3.4. Agora usa o **maior** com zero-fill e
devolve `channelMismatch`, que vira `.error` no log.

**`AudioCaptureLive` reescrito:**

| Antes | Agora |
|---|---|
| `engine` era `let`, criado uma vez e reusado para sempre | `AVAudioEngine` **novo a cada `start()`** — custa milissegundos e elimina a classe inteira de "o engine envelheceu ao longo de dias" (hipótese H1) |
| Sem observer de configuração | `AVAudioEngineConfigurationChange` observado por gravação; a mudança vira `.error` no log e entra no `CaptureStats` |
| Nenhuma verificação de que buffers chegaram | **Watchdog de 1 s**: sem buffer, derruba e recria o engine e tenta de novo; se a segunda tentativa também não entregar nada, o `stop()` **lança** `noAudioDelivered` em vez de devolver silêncio |
| `channelBuffers` escrito na thread de render e lido no `stop()` sem sincronização | Tudo sob `OSAllocatedUnfairLock`, junto com o contador de buffers |
| `engine.start()` falhando deixava o tap instalado → o `start()` seguinte fazia `installTap` no mesmo bus → `NSException` | `removeTap` no `catch` |
| Nenhuma métrica exposta | `lastStats: CaptureStats` — frames, buffers, formato de entrada, pico antes/depois, wall-clock, mismatch de canal, se o engine foi recriado, se a configuração mudou |

**O bug dos níveis (auditoria §5.1), com teste de regressão.** `levels` era um
único `AsyncStream` criado no init; `cancelRecordingTasks()` cancelava a Task
consumidora, e cancelar o consumidor **termina** o stream (provado em
`tools/diag/asyncstream_cancel_test.swift`). Da segunda gravação em diante
nenhum nível chegava — os 4 indicadores animavam com `audioLevel = 0` para
sempre, em toda sessão, desde a Fase 1.

A correção tem duas metades: o `AudioCaptureLive` cria um stream **por
gravação** (finalizado no `stop()`), e o `PipelineCoordinator` deixa de cancelar
a Task de níveis — só o ticker de 80 ms é cancelado; a de níveis termina sozinha
quando o stream fecha.

> **Honestidade sobre o teste:** `test_levels_arrive_in_second_recording` foi
> escrito primeiro contra um fake que espelhava a forma **de então** do
> `AudioCaptureLive` (um stream no init) e ficou **vermelho** na segunda
> gravação, como previsto. A correção mudou o *contrato* de
> `AudioCapturing.levels` (agora documentado como "por gravação"), e o fake foi
> atualizado para espelhá-lo. O teste portanto prova que o **coordinator**
> consome corretamente um stream por gravação ao longo de várias gravações; que
> a **implementação real** honra o contrato é o que o Bloco A do aceite manual
> verifica, olhando as ondas animarem nos três ditados.

**Testes:** +12 (11 de `AudioMath`, 1 de regressão dos níveis).
Suíte **203 → 215**, verde.

**Aceite manual (Bloco A, 2026-09-07): `ok-parcial`.** O usuário confirmou **A1**
— três ditados seguidos com as ondas animando nos três, que é a prova em runtime
de que o `AudioCaptureLive` real honra o contrato de stream por gravação — e
**A6** (o log traz a sequência completa por ditado, sem o texto ditado). **A2–A5
não foram exercitados**: troca/reconexão de device, mic tomado por outro app e
ditado de 60 s seguem abertos para a Tarefa 12. Ou seja: o watchdog e a recriação
do engine estão corretos por construção e cobertos por teste, mas **ainda não
foram vistos disparando em campo** — é exatamente o que a Tarefa 13 (validação
em campo) existe para fechar.

---

## Tarefa 4 — pipeline com falhas visíveis, recuperação e corridas ✅

**Eventos novos** (`PipelineEvent`): `captureFailed(reason:)` com
`CaptureFailureReason { noAudio, tooShort }`, `emptyTranscription`,
`transcriberRecoveryRequested`, `transcriberRecovered`. Toasts correspondentes
em `ToastKind` — as três chaves entraram no `Localizable.strings`.

> Achado de passagem: **não existia nenhuma chave `toast.*` no arquivo**. Todos
> os toasts do app viviam do `defaultValue`. É parte do achado §5.3 (37 chaves
> ausentes); a Tarefa 10 fecha o conjunto com teste derivado dos fontes.

**Os dois caminhos mudos da auditoria deixaram de ser mudos:**

| Caminho | Antes | Agora |
|---|---|---|
| **S1** — gravação sem áudio utilizável | descartada em `.info`, sem evento, toast, histórico ou log de erro | `.captureFailed(.noAudio)` quando o `stop()` lança, `.captureFailed(.tooShort)` quando veio áudio curto demais numa gravação de **≥ 1 s de wall-clock** — com toast e `.error` no log |
| **S2** — Whisper devolve `''` | injetava string vazia no app-alvo e salvava histórico vazio | não injeta, não salva, emite `.emptyTranscription` com toast |

O limiar de wall-clock é o que separa **falha real** de **toque acidental na
hotkey**: abaixo de 1 s o descarte continua silencioso, e há teste para os dois
lados (`test_tooShortAfterLongRecording_emitsCaptureFailed` e
`test_tooShortAfterTapRecording_isSilent`).

**Recuperação do decoder (hipótese H2).** Dois vazios seguidos emitem
`transcriberRecoveryRequested`; o `AppContainer` recria o transcriber em
background e devolve `transcriberRecovered` pelo mesmo stream de eventos (via
`PipelineCoordinator.noteTranscriberRecovered()`), o que mantém toast e
contadores num caminho só. Um sucesso no meio zera a sequência. A recriação
hoje passa por `unloadModel` + `loadModel`, que **ainda toca a rede** — a
Tarefa 5 troca por um `reload()` que lê só do disco.

**Três corridas fechadas:**

1. `.error → sleep 2 s → .idle` era incondicional. Um toggle dentro desses 2 s já tinha começado outra gravação e o `.idle` atrasado derrubava o `.recording`: o painel sumia, o engine seguia gravando, e o toggle seguinte fazia `installTap` duplo — `NSException`. Agora só volta a `.idle` se ainda estiver em `.error`.
2. Esc durante "transcrevendo" deixava um `transcribe()` em vôo (WhisperKit só checa cancelamento entre etapas) e um toggle imediato começava outro **na mesma instância**. Agora o toggle espera a pipeline anterior, com teto de 3 s.
3. **Ordem `save` → `inject`.** Com a Acessibilidade caída, o `inject` lançava antes do `save` e o ditado sumia inteiro — não colava, não ficava no clipboard, não entrava no histórico (S3). Agora o histórico é gravado primeiro, e o app-alvo é lido antes pelo novo `Injecting.frontmostBundleID()`.

**Relógio injetável no `PipelineCoordinator`** (`now: () -> Date`, default
`Date()`): sem isso os testes do limiar de wall-clock precisariam dormir
segundos de verdade, e a auditoria §5.5 já reclamava dos sleeps fixos da suíte.

**Testes:** +9, todos escritos antes da implementação do Step 3 — mas sem run
vermelho registrado em separado, porque os eventos novos precisavam existir para
o arquivo compilar. A exigência de prova em vermelho vale para as Tarefas 3 e 6,
e a da Tarefa 3 está registrada acima. Suíte **215 → 224**, verde.

---

## Tarefa 5 — transcriber: métricas, carga local sem rede, `reload()` ✅ (código; aceite Bloco B pendente)

**`TranscriptionOutcome`** substitui a `String` crua devolvida pelo
`transcribe`: texto, idioma detectado, `avgLogprob`, `compressionRatio`,
`noSpeechProb`, `wallMs` e número de segmentos. As métricas já eram produzidas
pelo WhisperKit e o app **jogava fora** — sem elas, um `''` era indistinguível
entre "o usuário não falou" e "o decoder degradou" (H1 × H2). `metricsLine`
formata tudo para o log e, por construção, **nunca inclui o texto** (há teste).

Com isso a divergência que a Tarefa 1 deixou em aberto fechou: a linha de erro
de transcrição vazia agora traz o **pico pós-boost** (via `audio.lastStats`) ao
lado das métricas do decoder — que é exatamente o par de números que separa as
duas hipóteses.

**Carga sem rede.** `WhisperKit.download` chama `HubApi.getFilenames` — HTTP
incondicional a `huggingface.co` — **antes** do snapshot, mesmo com o modelo já
em disco. Consequências: launch sem internet deixava o modelo sem carregar e
todo ditado virava "erro no pipeline" até relançar com rede; e um app
"local-first" fazia requisição de rede a cada abertura. Agora
`WhisperModelStore.modelFolderURL(for:)` decide: pasta local → instancia direto;
ausente → baixa. O `downloader` é injetável, então a decisão tem teste sem tocar
a rede.

**`reload()`** descarrega e reinstancia **a partir do disco**, guardando a pasta
usada na carga. É a recuperação disparada por dois vazios seguidos — e importa
que seja de disco: o app está degradado justamente quando não se quer depender
de um serviço externo estar de pé. O `AppContainer.recoverTranscriber()` passou
a usá-lo no lugar do `unloadModel` + `loadModel` provisório da Tarefa 4.

**Testes:** +5 (escolha disco × download com spy, `reload` sem modelo carregado,
privacidade do `metricsLine`, `modelFolderURL`). Suíte **224 → 229**, verde.

**Pendente:** aceite manual do Bloco B.

---

## Tarefa 6 — `PermissionService.snapshots` multicast ✅

**O bug, com teste vermelho antes.** `snapshots` era um único `AsyncStream`
iterado por **dois** consumidores — o `AppContainer` e o `OnboardingCoordinator`,
este criado em todo launch. `AsyncStream` é single-consumer: os elementos são
**divididos** entre quem itera, não duplicados. O checklist do onboarding perdia
cerca de metade das transições de permissão.

O teste `test_makeSnapshots_deliversEveryUpdateToEverySubscriber` reproduziu
exatamente isso antes da correção — com quatro transições, o assinante A recebeu
3 e o B recebeu 2:

```
assinante A perdeu PermissionsSnapshot(…accessibility: .granted…); recebeu 3
assinante B perdeu PermissionsSnapshot(…inputMonitoring: .granted…); recebeu 2
```

**Correção:** `makeSnapshots()` cria um stream **por assinante**; o poller faz
broadcast para todos sob `OSAllocatedUnfairLock`, e quem assina depois recebe
imediatamente o último snapshot conhecido — senão o onboarding só reagiria à
transição seguinte. `onTermination` remove o assinante. `snapshots` continua
existindo como compat, agora derivado de `makeSnapshots()`.

**Vazamento fechado.** O `guard let self` ficava **fora** do laço de polling,
mantendo o serviço vivo pela vida da Task: o `deinit` nunca rodava e o poll de
1 s com 3 IPCs seguia para sempre (visível no log da auditoria como
`TCCAccessRequest() IPC` contínuo). Agora `self` é resolvido por iteração e sai
de escopo antes do sleep. Mesmo tratamento no `OnboardingCoordinator`.

**`permissionsAllGranted` ganhou leitor.** O campo existia em `AppState` e
**ninguém lia**. Agora vira aviso no menu — "permissões pendentes — abra
Preferências" — o que importa porque sem Acessibilidade a cola morre e sem Input
Monitoring a hotkey morre, e as duas falham em silêncio.

**Injeção para teste:** `PermissionServiceLive(probe:pollIntervalNs:)` permite
sondagem falsa e poll de 10 ms, sem depender do estado real de TCC da máquina.

**Testes:** +1 (o de multicast). Suíte **229 → 230**, verde.

---

## Tarefa 7 — hotkey: `start()` idempotente, watchdog, re-start ao reconceder ✅ (código; aceite Bloco C pendente)

**`start()` idempotente.** Antes, um segundo `start()` sobrescrevia `eventTap`
sem invalidar o anterior nem remover a source do run loop — sobravam taps órfãos.
Agora derruba o anterior (`tapEnable(false)` + `CFMachPortInvalidate` + remoção
da source) antes de criar outro. Isso é o que torna o re-start seguro.

**Watchdog de 30 s.** O callback só reabilita o tap quando o macOS avisa
(`tapDisabledByTimeout` / `tapDisabledByUserInput`). Um tap **invalidado** —
revogar e reconceder Input Monitoring, o mesmo churn da entrada #1 do
troubleshooting — não avisa ninguém: a hotkey simplesmente morre e o usuário só
vê "não faz nada" (S4). O watchdog checa `isTapEnabled` e reabilita.

**Re-start ao reconceder.** O `AppContainer` observa as transições de permissão
(agora confiáveis, graças ao multicast da Tarefa 6) e chama `start()` quando
`inputMonitoring` volta a `.granted`.

**Flag de device do Right Option (`0x40`, `NX_DEVICERALTKEYMASK`).** O filtro
aceitava `.maskAlternate` agregado: com o Left Option segurado, o *release* do
Right Option ainda trazia `.maskAlternate` ligado e gerava um segundo `.toggle`
— que virava uma gravação de milissegundos, descartada em silêncio. Agora exige
a flag do device direito, e há teste para os dois lados.

**Testes do callback com `CGEvent` sintético.** O callback é uma função C
estática que recebe `self` via `refcon`, então dá para chamá-la direto — sem tap
real do sistema e sem Input Monitoring. Não havia teste nenhum aqui até agora.

**Testes:** +6. Suíte **230 → 236**, verde. **Pendente:** aceite do Bloco C.
