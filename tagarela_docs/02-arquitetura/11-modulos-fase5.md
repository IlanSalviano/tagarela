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

---

## Tarefa 8 — injeção sem perda de ditado ✅ (código; aceite Bloco D pendente)

**Ordem invertida.** `AXIsProcessTrusted()` era checado **antes** de escrever no
pasteboard, e o pipeline retornava antes do `save`. Com a Acessibilidade caída —
o TCC zumbi do `cleanup-fase3`, que já aconteceu nesta máquina — o ditado sumia
inteiro: não colava, não ficava no clipboard, não entrava no histórico (S3).
Agora o texto vai para o pasteboard **primeiro**, e o histórico foi para antes da
cola na Tarefa 4. O ditado nunca mais se perde.

**Política de restauração do clipboard** (registrada no ADR-0008). Não há como
confirmar que o app-alvo processou o ⌘V, então a regra é conservadora — na
dúvida, **o ditado fica no clipboard**:

| Regra | Por quê |
|---|---|
| Roda em `Task.detached` | O Esc do usuário cancelava a Task do pipeline, o que interrompia o `sleep` e restaurava **antes** do app-alvo consumir o ⌘V — colando o conteúdo anterior |
| Só se `changeCount` não mudou | Se alguém copiou outra coisa nesse meio-tempo, restaurar seria atropelar |
| Só se havia algo antes | Com o clipboard anteriormente vazio, restaurar significaria **apagar** o ditado |
| Delay 400 ms (era 250) | Os alvos reais deste usuário — Claude, Codex, WhatsApp — são Electron e consomem o ⌘V depois de 250 ms |

**Copy dos toasts corrigida** (fecha o item 9h de passagem). "Cola falhou —
texto na área de transferência." era **falso nos dois** caminhos de falha. Como
o histórico agora é salvo antes da cola, a frase verdadeira em todos eles é
"Cola falhou — o ditado está salvo no histórico."; e o toast de Acessibilidade
passa a dizer onde o texto está em vez de só mandar abrir Configurações.

**Divergência do plano (melhoria):** os testes usam um `NSPasteboard` **nomeado
próprio** em vez do `general`, então não precisam do gate
`TAGARELA_INTEGRATION=1` que o plano previa e não mexem no clipboard de quem
roda a suíte. Rodam sempre.

**Testes:** +4 (o tautológico de `Equatable` que a auditoria §5.5 apontou
continua, agora acompanhado de testes de verdade). Suíte **236 → 240**, verde.
**Pendente:** aceite do Bloco D.

---

## Tarefa 9 — correções pontuais confirmadas ✅ (código; aceite Bloco E pendente)

| Item | Bug | Correção |
|---|---|---|
| **9a** | `prefs.whisperModelName` só era persistido dentro de um `if` que dependia do estado **da view**: navegar para outra seção no meio do swap destruía a view, o swap terminava e ninguém persistia — o launch seguinte carregava o modelo **antigo** em silêncio | Persistência mudou para `AppContainer.swapActive`, que roda exatamente uma vez no sucesso e não depende de view alguma. A view só oferece o cleanup do modelo antigo |
| **9b** | `OllamaHealthChecker.baseURL` era fixada no init e nunca atualizada: apontar o Ollama para outra máquina deixava o ping no `localhost` antigo e todo `refine` virava "Sem rede" até relançar. Além disso, `URLError.cancelled` (Esc durante `.refining`) era cacheado como "indisponível" por 30 s | URL por chamada com cache **por URL**; cancelamento não é cacheado; TTL negativo cai para 3 s |
| **9c** | Request sem `num_ctx`: o servidor usava o default dele (2048/4096), 8 a 30× menor que a janela real. O truncamento acontecia no servidor, em silêncio, **começando pelo system prompt** — o modelo perdia a instrução "reescreva, não responda" e devolvia uma resposta ao ditado | `options.num_ctx` coerente com `RemoteRefinerConfig.contextWindow(for:)` |
| **9d** | Retenção e timeout só eram clampados nos setters. `historyMaxItems == 0` apaga inclusive o registro recém-salvo — histórico sempre vazio, sem aviso; `refinerTimeoutSec` ia do `TextField` direto para o `timeoutInterval` do URLSession, onde 0 é indefinido | Clamp na carga **e** nos setters (`≥ 1`; timeout em `5...600`) |
| **9e** | O painel da API key era `.closable` sem delegate: fechar no ⨯ nunca chamava `close(canceled:)`, o rollback de `refinerKind` não disparava e o backend ficava em OpenAI sem key — todo ditado caindo em "API key inválida". E o caminho via Preferências não resetava os callbacks, então as closures do último fluxo do menu seguiam armadas | `NSWindow.willCloseNotification` trata o ⨯ como cancelar; `show(onCancel:onSaved:)` explícito nos três callsites |
| **9f** | Sem `.fullScreenAuxiliary`, ditar num app em tela cheia não mostrava indicador nem toasts. O painel era reposicionado no cursor a cada `.stateChanged` (12–25×/s gravando), então **seguia o mouse** e desfazia qualquer arrasto. E um preview de 3 s em vôo escondia uma gravação real ao expirar | `.fullScreenAuxiliary` no `collectionBehavior`; reposiciona só na transição oculto → visível; `show()` cancela o `previewTask` |
| **9g** | Onboarding fechado no ⌘W sem concluir deixava o app "zumbi": hotkey e modelo nunca subiam e não havia como reabrir a janela | Item "Concluir configuração…" no menu enquanto o onboarding estiver pendente |
| **9h** | — | Feito na Tarefa 8, por estar acoplado à nova política de clipboard |

**Testes:** +8 (4 do health checker, 1 do `num_ctx`, 2 dos clamps, 1 da
persistência do swap). Suíte **240 → 248**, verde. **Pendente:** aceite do Bloco E.

---

## Tarefa 10 — localização: 37 chaves ausentes + teste derivado dos fontes ✅

**O arquivo não era a fonte da verdade que dizia ser.** A auditoria §5.3 recontou
185 chaves usadas no código contra 149 declaradas: **37 ausentes**, todas caindo
em silêncio no `defaultValue`. O `LocalizableKeysTests` não pegava nada disso
porque testava uma **lista manual** — e a lista, claro, só tinha chaves que
alguém lembrou de adicionar.

**Agora o teste deriva a lista dos fontes.** Varre `app/Tagarela/**/*.swift` a
partir do `#filePath` com regex sobre `String(localized:)` e
`NSLocalizedString(`, compara com o `.strings` e falha listando **arquivo por
arquivo** o que falta. Um segundo teste faz o caminho inverso e reprova chaves
declaradas sem uso.

Rodando pela primeira vez, o teste reproduziu a contagem da auditoria na mosca:
**37 ausentes e 1 sem uso** (`onboarding.model.badge.recommended`). O bloco mais
gritante: **nenhuma chave `toast.*` existia** — todos os toasts do app viviam do
`defaultValue`.

**Também nesta tarefa:**

- Strings hardcoded viraram chaves: `Button("retry")` do onboarding (estava em inglês, num app pt-BR), o prefixo `"cru: …"` do histórico, e as três mensagens de erro do swap de modelo.
- `%d` → `%lld` em `preferences.transcription.swap.downloading` — `String(localized:)` gera `%lld` para `Int`, então o `%d` era um descasamento silencioso.
- O card de **Acessibilidade** no onboarding dizia "necessário pra registrar o atalho global e simular ⌘V". Acessibilidade é só o ⌘V; o atalho global é Input Monitoring. A copy passou a dizer isso, e a distinção importa porque as duas permissões falham de formas diferentes (uma mata a cola, a outra mata a hotkey).
- "funciona offline. **fala português**." ficou datado depois da Fase 4, que tornou o idioma configurável com auto-detecção. Agora diz "entende português e inglês".

**Testes:** o teste de lista manual foi substituído por dois derivados.
Suíte **248 → 249**, verde. Arquivo: 149 → 200 chaves.

---

## Tarefa 11 — scripts de release: ordem segura do appcast ✅ (smoke test pendente)

**A ordem estava invertida e isso quebrava clientes.** O `appcast.sh` commitava
o `appcast.xml` e o `release.sh` dava `git push --follow-tags` **antes** do
`gh release create` subir o DMG. Como o feed do Sparkle é o raw do `main`,
qualquer falha do `gh` (auth, rede) — ou só a janela entre push e upload —
deixava **todo cliente** vendo um item novo e tomando **404 a cada checagem de
update**, até alguém consertar à mão. E o rerun travava, porque tag e commit já
existiam.

Ordem nova:

```
bump → build → sign → notarize → dmg
     → git tag -a
     → gh release create (upload do DMG)
     → curl -sSfI  (confirma HTTP 200 na URL do DMG)
     → appcast.sh + commit do appcast.xml
     → git push --follow-tags
```

O `appcast.sh` **não commita mais** — quem commita é o `release.sh`, e só depois
de o DMG estar comprovadamente acessível. Se algo falhar depois da tag, um trap
`ERR` imprime o rollback exato (`git tag -d`, `git push --delete`,
`gh release delete`) e lembra que o appcast não foi commitado, logo nenhum
cliente viu item apontando para binário inexistente.

| Item | Bug | Correção |
|---|---|---|
| **11b** | `sign_update` era procurado só no DerivedData do **IDE**, mas o `build.sh` resolve o SPM em `build/release/derived`. Numa máquina limpa o passo falhava **depois** de notarizar | Procura primeiro no derived do release, com o do IDE como fallback |
| **11c** | Commit de bump acontecia antes de build/sign/notarize; qualquer falha depois deixava o bump local, e um novo `release.sh patch` bumpava de novo (1.0.4 → 1.0.5 sem release no meio) | Se o `HEAD` já é um commit de bump **sem tag correspondente**, reaproveita |
| **11d** | `date` com nomes de dia/mês do locale gerava `pubDate` inválido (RFC 822 exige inglês) num shell pt_BR | `LC_ALL=C date -u` |

**Pendente: o smoke test.** O plano pede um ensaio em branch temporária com
`gh release create --draft` e rollback. Não foi executado: cria uma release no
GitHub do usuário, precisa de rede e de autorização explícita. Fica junto do
aceite manual, antes da v1.0.4.

Todos os scripts passam `bash -n`.

---

## Achado de campo (2026-09-24) — "o app parou de funcionar" era o modelo carregando

**Não era a falha de sessão longa.** A máquina foi atualizada para **macOS 27.0**
(build 26A428) entre 7 e 24 de setembro. No **primeiro launch depois do upgrade**,
o CoreML teve de recompilar os 3 GB do modelo para a ANE e a carga levou
**94 segundos** — contra **13 segundos** num launch normal, medido logo em seguida
na mesma máquina.

Durante esses 94 s, cada acionamento da hotkey gravava ~4 segundos de fala e
devolvia **"erro no pipeline"**, sem dizer que o problema era só ser cedo demais.
O log mostra os dois ditados perdidos exatamente dentro da janela:

```
20:13:38  loadModel('large-v3_turbo') iniciando
20:13:44  toggle → gravou 3,8 s, peak 0,256 → 0,600   (fala de verdade)
20:13:48  transcribing (model loaded? NIL) → FALHOU: modelNotLoaded
20:14:44  toggle → gravou 3,5 s
20:14:48  FALHOU: modelNotLoaded
20:15:12  modelo 'large-v3_turbo' carregado            ← 94 s depois
```

É o caminho **S5** da [auditoria §3.4](./10-auditoria-2026-09-07.md), e o único dos
cinco que a Fase 5 **não** tinha fechado: o §5.3 registrava
"`whisperModelReady` nunca é setado/lido; cada hotkey vira 'erro no pipeline' por
2 s sem dica" como severidade **baixa**. Em campo custou uma noite de uso e a
conclusão razoável de que o app estava quebrado.

**Correções:**

- **Não grava sem modelo.** O toggle em `.idle` verifica `loadedModelName` antes de `audio.start()` e emite `transcriberNotReady`. Gravar 4 segundos de fala que serão descartados é pior que não gravar.
- **Toast honesto:** "Ainda carregando o reconhecedor — tente em alguns segundos." em vez de "erro no pipeline".
- **`whisperModelReady` ganhou escritor e leitor** — o menu mostra "carregando o modelo…" no lugar de "⌥ direito pra começar", que era uma mentira durante a carga.
- **Rede de segurança:** `TranscribeError.modelNotLoaded` vindo do `transcribe` (modelo descarregado por swap ou recovery no meio da gravação) também cai nesse caminho, não no erro genérico.
- **O tempo de carga vai para o log** (`carregado em 94.0s`). Sem o número, a diferença entre "lento" e "quebrado" é invisível — que é a tese inteira desta fase.

**Testes:** +1. Suíte **249 → 250**, verde.

> Nota sobre a Tarefa 5: a carga de 13 s inclui ~6 s de ida a `huggingface.co`
> mesmo com o modelo em disco. A carga local sem rede, já implementada na
> Tarefa 5, corta isso — o cold start normal deve cair para ~7 s.

### Defeito encontrado ao instalar o build (2026-09-24)

O primeiro `tail` do log de produção logo após instalar mostrou linhas que
**nunca aconteceram em uso real**: `transcribed vazio`, `recovery requested
after 2 empty`, `buffer too short`. Eram da **suíte de testes** — que roda
contra o `Diag` real e portanto escrevia em
`~/Library/Logs/Tagarela/tagarela.log`.

Numa fase inteira construída para que esse arquivo seja *a* evidência da
próxima falha, isso é grave: a investigação seguinte leria sintomas que nunca
ocorreram. `Diag` agora detecta execução sob XCTest
(`XCTestConfigurationFilePath` ou presença de `XCTestCase`) e pula a escrita em
arquivo. Verificado: o log ficou em 1966 linhas antes e depois de uma execução
completa da suíte.

### Build local instalado

Com a **chave privada** do Developer ID ausente deste keychain (o certificado
em si está no repo e é válido — ver Tarefa 12 no plano), a v1.0.4 notarizada
não pode ser gerada aqui. Para destravar o uso diário foi instalado em
`/Applications` um build **Release** da branch assinado com a *Apple
Development* local (`1.0.4-fase5`, build 5), com backup da v1.0.3 em
`~/Tagarela-backups/Tagarela-v1.0.3.zip`.

Resultados imediatos:

- **Carga do modelo: 1,3 s** (`modelo 'large-v3_turbo' já em disco — carregando sem rede`), contra **13 s** na v1.0.3, que ia a `huggingface.co` mesmo com o modelo em disco. É a Tarefa 5 medida em campo.
- **Input Monitoring precisou ser reconcedido** — assinatura diferente, designated requirement diferente. Microfone foi herdado. Esperado e avisado.

---

## Achados de campo 2 (2026-09-24) — pílula subindo e idioma errado

Dois problemas relatados assim que o build local passou a ser usado de verdade.

### A pílula subia até o topo da tela — regressão do 9f

O 9f parou de reposicionar o painel no cursor a cada `.stateChanged`, para ele não
perseguir o mouse. Mas cada `show()` ainda troca o `contentViewController` inteiro,
e esse redimensionamento **desloca a janela para cima**. O `setFrame` a cada tick
de antes mascarava a deriva; sem ele, ela se acumula 12–25 vezes por segundo até o
topo da tela.

A auditoria recomendava duas metades juntas — manter o controller **e** posicionar
só na transição oculto → visível. O 9f fez só a segunda. A primeira (reaproveitar
o `NSHostingController`) é justamente o que a 2c-cleanup tentou e reverteu por
regressão em runtime, então não foi retomada aqui.

**Teste vermelho com o sintoma exato:** `test_panelDoesNotDriftAcrossRepeatedUpdates`
mediu **643 pt de subida em 30 atualizações** (y 725 → 1368, o topo da tela).

**Conserto:** a posição que a janela tinha **antes** da troca de conteúdo é
restaurada **depois**. Anula a deriva, não persegue o mouse e não briga com o
arrasto — a posição guardada já inclui o que o usuário arrastou. O painel só vai
ao cursor quando aparece. Um segundo teste simula o arrasto e verifica que ele
gruda, e que ao reaparecer o painel volta para perto do cursor.

Esta é exatamente a regressão que o aceite do Bloco E (item E2) existia para pegar
antes do merge. Ela foi pega — em uso real, porque o build foi instalado antes do
aceite. Era o risco aceito ao instalar.

### Falei português e ele escreveu em inglês — defeito latente da Fase 4

Não é regressão desta fase: o modo Automático **nunca funcionou para português**.
O WhisperKit 0.18.0 pré-preenche o cache do decoder com `<|en|>` antes de detectar
o idioma, e a detecção lê esse cache. Detalhe completo, causa no código e decisão
revisada em [ADR-0006 — Revisão 2026-09-24](../04-decisoes/ADR-0006-multi-idioma-transcricao.md).

**Vermelho com o modelo real:** 9,6 s de português sintetizado → `fr`.
**Verde depois:** `pt`, com transcrição (não tradução).

**Sobre a preferência:** está em `auto`; a auditoria de 7/set tinha visto `pt`
explícito. **Não** foi a suíte de testes que trocou — verificado: os testes de
preferência usam o domínio `tagarela.tests.preferences`, não o do app. A troca veio
de fora (o usuário, provavelmente); com o conserto, o Automático passa a acertar.

**Testes:** +4 (2 do painel, 1 do mapeamento de idioma, 1 de integração com o
modelo real, pulado sem `TAGARELA_INTEGRATION=1`). Suíte **250 → 254**
(253 verdes + 1 pulado); declarados = executados, sem testes órfãos.

**Confirmado em campo (2026-09-25):** o usuário ditou em português no modo
Automático e o log registrou `auto=pt→pt`, logprob −0,052, 1,5 s para 6 s de
áudio, colado no Claude desktop. Detalhe e números em
[ADR-0006](../04-decisoes/ADR-0006-multi-idioma-transcricao.md).
