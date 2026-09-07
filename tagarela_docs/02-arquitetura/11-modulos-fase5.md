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
