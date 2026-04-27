---
data: 2026-04-27
status: aprovado para implementação
fase: 2a de 3 (Fase 2 dividida em 2a + 2b)
goal: ditado refinado por LLM funcionando end-to-end, configurável sem `defaults write`, com persistência durável
---

# tagarela v1 — Fase 2a: Persistência + LLM funcionando

Spec da primeira metade da Fase 2. Resultado do brainstorming de 2026-04-27, que decompôs a Fase 2 monolítica do design v1 em duas sub-fases sequenciais. A 2b cobre tela de Preferências, menu "últimos 5", indicadores B/C/D, toasts e migração total de Localizable; será objeto de brainstorming separado depois da 2a estar mergeada.

> Regras de processo: ver [`/CLAUDE.md`](../../CLAUDE.md). Nada é implementado sem ler a doc; nada é dado como pronto sem atualizar a doc.
>
> **Design v1 base:** [`2026-04-26-tagarela-v1-design.md`](./2026-04-26-tagarela-v1-design.md). Esta spec é uma especialização: onde uma decisão diverge do design v1 ela está marcada explicitamente; onde repete, é pra completude.
>
> **Estado da Fase 1:** [`02-arquitetura/01-modulos-fase1.md`](../02-arquitetura/01-modulos-fase1.md). Módulos atuais e cobertura de testes (16 verdes em 2026-04-27).

---

## 1. Visão e escopo

### 1.1 Goal

Construir a infraestrutura de persistência (`PreferencesStore`, `HistoryStore`, `KeychainService`) e os três refiners do design v1 (`OpenAIRefiner`, `OllamaRefiner`, `IdentityRefiner` polido) atrás do protocolo `TextRefiner`, com mínima UI funcional na status bar para tornar a Fase 2a usável sem editar `UserDefaults` ou `Keychain` pelo CLI.

### 1.2 Exit criteria (pronto para Fase 2b)

1. Apertar `right ⌥`, falar, apertar de novo → texto **refinado por LLM** (Ollama ou OpenAI) é colado no app em foco.
2. Trocar entre **Ollama / OpenAI / Sem LLM** e entre os 4 estilos é feito pelos submenus da status bar, em 2 cliques cada.
3. API key da OpenAI configurada via modal acionada pelo submenu — sem CLI.
4. Histórico de transcrições persiste entre sessões com retenção 200/30, sem UI ainda — base estável.
5. Refinador falha → fallback `IdentityRefiner` silencioso, texto cru entregue, log estruturado.
6. Suite XCTest verde com ~40-45 testes (16 atuais + 25-30 novos).
7. Cleanups [#2](../04-decisoes/cleanup-fase1.md#2-initialprompt--prompttokens-no-whisperkittranscriber) e [#4](../04-decisoes/cleanup-fase1.md#4-software-gain-hardcoded-no-audiocapturelive) fechados.
8. Doc `tagarela_docs/02-arquitetura/01-modulos-fase1.md` evoluiu para refletir 2a (renomear ou superseder).

### 1.3 Não-objetivos da 2a (vão para 2b)

- Tela de Preferências (qualquer aba). Configuração avançada (`technicalVocabulary` edit, `audioBoostMaxGain` slider, `historyMaxItems`/`historyMaxDays` custom, `ollamaModel` editável, etc) só via `defaults write`.
- Menu "últimos 5" da status bar.
- Indicadores B/C/D.
- Toasts.
- Estados visuais "permissão faltando" no menu.
- Migração total de strings da Fase 1 para Localizable (a 2a só cria a infra para strings novas).
- Custom styles (criar/editar). Só os 4 built-in.
- Endpoints custom da OpenAI (Azure, OpenRouter, LM Studio).
- Onboarding novo (LLM scan, key prompt no fluxo guiado) — vai para 2b junto da Preferences UI.
- Cleanup [#3](../04-decisoes/cleanup-fase1.md#3-stderr-instrumentation-deve-virar-loggertagarelainfo) (stderr → Logger). Fica como está.

### 1.4 Decisões nucleares (do brainstorming 2026-04-27)

| # | Decisão | Alternativas consideradas |
|---|---|---|
| F2a-1 | Fase 2 dividida em 2a (este doc) + 2b (futuro) | Plano único monolítico; 3 sub-fases |
| F2a-2 | Cleanups [#2](../04-decisoes/cleanup-fase1.md#2-initialprompt--prompttokens-no-whisperkittranscriber) e [#4](../04-decisoes/cleanup-fase1.md#4-software-gain-hardcoded-no-audiocapturelive) entram explicitamente na 2a | Não fazer; dividir por sub-fase |
| F2a-3 | OpenAI implementado **antes** de Ollama; Identity polido no fim | Ollama primeiro; em paralelo; só Ollama na 2a |
| F2a-4 | OpenAI default `gpt-5.4-mini`, baseURL fixo `https://api.openai.com/v1` (custom = v2) | Outro modelo; sem default; endpoint custom já na 2a |
| F2a-5 | 4 presets built-in **hardcoded**, sem mecanismo de custom style ainda | Built-ins + estrutura custom já persistida; hardcode total sem `Style` Codable |
| F2a-6 | **Submenu de estilos** na status bar já na 2a (radio com 4 built-ins) | `defaults write` only; cycle de estilo via tecla extra |
| F2a-7 | **Submenu de backend** na status bar já na 2a (radio Ollama/OpenAI/Sem LLM) | Default `.none` com `defaults write`; default `.ollama` temporário |
| F2a-8 | Health check Ollama (timeout 2s, cache 30s) **completo**; fallback silencioso | Sem health check (chamar /chat direto); health check + indicador visual mínimo |
| F2a-9 | Retenção do `HistoryStore` aplicada **a cada `save()`** | Só no boot; só a cada N saves |
| F2a-10 | API key OpenAI configurada via **modal `NSPanel`** acionada pelo submenu | CLI auxiliar; env var `TAGARELA_OPENAI_KEY` |
| F2a-11 | Cobertura ampla de testes (~25-30 novos) | Mínima (~10); só checklist manual |
| F2a-12 | Trunca-com-marcador para context window (conforme design v1 §5) | Sem trunca, fallback direto; sem detecção proativa |
| F2a-13 | Localizable.strings criado na 2a só para strings **novas** da 2a | Esperar 2b; migrar Fase 1 inteira na 2a |
| F2a-14 | Cleanup #2 entra na 2a com **checklist A/B** (env var `TAGARELA_DISABLE_PROMPT=1`) | Implementar e confiar; não implementar (decisão (a) do cleanup) |
| F2a-15 | Vocab inicial: ~30-50 termos **hardcoded** em `DefaultVocabulary.swift` como default da chave `technicalVocabulary` | Vazio; arquivo `.txt` mutável em Application Support |
| F2a-16 | Cleanup #4: chave única `audioBoostMaxGain: Float` (default 20, range 1-50). `targetPeak: 0.6` continua hardcoded | Duas chaves (`targetPeak` + `maxGain`); enum `audioBoostMode`; trocar por AGC RMS |

---

## 2. Arquitetura

### 2.1 Princípios herdados da Fase 1

- Boundaries via protocolos. `RefinerFactory` e `HistoryStore` continuam essa linha.
- Tudo Swift. Nenhuma SPM nova prevista.
- SwiftUI quando dá; AppKit cirúrgico (modal `NSPanel`).
- Offline-first. Default da 2a entrega texto cru se LLM falha.

### 2.2 Módulos novos

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `PreferencesStore` | `Preferences/PreferencesStore.swift` | Wrapper de `UserDefaults.standard` com properties `@Published` (Combine). Defaults centralizados em `Preferences+Defaults.swift`. |
| `KeychainService` | `Preferences/KeychainService.swift` (protocol) + `KeychainServiceLive.swift` | `Security.framework` wrapper minimal; só `account: "openai-api-key"` no service `com.tagarela`. |
| `Style` | `Refiner/Style.swift` | `struct Codable Identifiable Hashable Sendable` conforme design v1 §4.4. |
| `BuiltInStyles` | `Refiner/BuiltInStyles.swift` | Os 4 system prompts (`conversa informal`, `e-mail profissional`, `notas técnicas`, `cru — sem reescrita`) com cláusula code-switching anexada (exceto cru). UUIDs hardcoded estáveis. |
| `RefinerError` | `Refiner/RefinerError.swift` | Enum semântico: `.networkOffline`, `.unauthorized`, `.timedOut`, `.serverError(Int)`, `.rateLimited`, `.contextExceeded`, `.modelNotFound(String)`, `.malformedResponse`. |
| `RefinerErrorMapper` | `Refiner/RefinerErrorMapper.swift` | `URLError` + HTTP status + body text → `RefinerError`. |
| `TokenCounter` | `Refiner/TokenCounter.swift` | Estimativa simples (~`chars / 4`) para decidir trunca. Sem tokenizer real. |
| `RemoteRefinerConfig` | `Refiner/RemoteRefinerConfig.swift` | Tabela `[modeloName: contextWindowTokens]` (com fallback conservador 8000 para desconhecidos). |
| `BaseRemoteRefiner` | `Refiner/BaseRemoteRefiner.swift` | Helper compartilhado entre OpenAI e Ollama: trunca-com-marcador, retry de 1× ao exceder context, error mapping. |
| `OpenAIRefiner` | `Refiner/OpenAIRefiner.swift` | `TextRefiner` impl. URLSession, lê API key do Keychain, monta prompt do `Style`, formato chat completions. |
| `OllamaRefiner` | `Refiner/OllamaRefiner.swift` | `TextRefiner` impl. URLSession, formato `/api/chat`. Usa `OllamaHealthChecker`. |
| `OllamaHealthChecker` | `Refiner/OllamaHealthChecker.swift` | `GET /api/tags` com timeout 2s e cache de 30s. Invalidado quando `prefs.refinerKind` muda. |
| `RefinerFactory` | `Refiner/RefinerFactory.swift` | Lê `prefs.refinerKind` + `prefs.selectedStyleID` e devolve a impl correta com style aplicado. Encapsula a decisão de qual refiner usar. |
| `Transcription` (model) | `History/Transcription.swift` | `@Model` SwiftData conforme design v1 §4.1. |
| `HistoryStore` | `History/HistoryStore.swift` (protocol) + `HistoryStoreLive.swift` + `HistoryStoreNoop.swift` | SwiftData container, `save`, `recent(limit:)`, retenção a cada save. Noop fallback se container falha. |
| `OpenAIKeyPromptWindow` | `UI/Onboarding/OpenAIKeyPromptWindow.swift` | `NSPanel` standalone com `SecureField`, salva no Keychain. |
| `BackendSubmenu` | `UI/MenuBar/BackendSubmenu.swift` | Submenu radio (Ollama / OpenAI / Sem LLM) + item "Configurar API key…". |
| `StyleSubmenu` | `UI/MenuBar/StyleSubmenu.swift` | Submenu radio com 4 built-ins. |
| `DefaultVocabulary` | `Resources/DefaultVocabulary.swift` | Array hardcoded de ~30-50 termos. |

### 2.3 Módulos modificados

- `WhisperKitTranscriber.swift` — usar `WhisperKit.tokenizer` para converter `initialPrompt: String` em `promptTokens: [Int]` quando env `TAGARELA_DISABLE_PROMPT != "1"`. Cleanup [#2](../04-decisoes/cleanup-fase1.md#2-initialprompt--prompttokens-no-whisperkittranscriber).
- `AudioCaptureLive.swift` — `boostPeakNormalize` lê `audioBoostMaxGain` (Float) injetado via init/closure. Não acessa `PreferencesStore` direto — mantém isolável para teste. Cleanup [#4](../04-decisoes/cleanup-fase1.md#4-software-gain-hardcoded-no-audiocapturelive).
- `AppContainer.swift` — wire-up de `PreferencesStore`, `KeychainService`, `RefinerFactory`, `HistoryStore`. `PipelineCoordinator.init` agora recebe `() -> TextRefiner` (closure que consulta o factory) ao invés de instância fixa, para permitir trocar refiner sem recriar coordinator.
- `PipelineCoordinator.swift` — após `injector.inject`, chamar `historyStore.save(...)` com a `Transcription` completa. Capturar `actualRefinerKind` que **de fato** rodou (se fallback ocorreu, é `"none"`).
- `MenuBarContent.swift` — incorpora 2 submenus + cabeçalho mostrando backend/estilo ativos.

### 2.4 Diagrama de dependências (delta sobre Fase 1)

```
                AppContainer
                     │
        ┌────────────┼─────────────┬──────────────┐
        ▼            ▼             ▼              ▼
  PreferencesStore  KeychainSvc  HistoryStore   RefinerFactory
        │            │              │              │
        │            │              │      ┌───────┼───────┐
        │            │              │      ▼       ▼       ▼
        │            │              │  Identity OpenAI  Ollama
        │            │              │            │       │
        │            └──────────────┼────────────┘       │
        │                           │                    │
        └───────────────────────────┼────────────────────┘
                                    ▼
                          PipelineCoordinator
                              (consome via closures)
```

`MenuBarContent` observa `PreferencesStore` via Combine `@Published` e expõe os submenus.

---

## 3. Fluxo principal (delta sobre Fase 1)

Cada `right ⌥` toggle entra no fluxo abaixo. Passos **(R1)–(R5)** são novos; persistência em **(P1)** é nova.

```
[1] right ⌥ down → HotkeyService → PipelineCoordinator
[2] state: idle → recording, audio.start()
       (audioLevel ticka via AsyncStream a 12 Hz)
[3] right ⌥ down → state: recording → processing
[4] audio.stop() → AudioBuffer 16kHz mono (boost com prefs.audioBoostMaxGain)
[5] guard duração ≥ 0.5s
[6] WhisperKitTranscriber.transcribe(buffer, language="pt", initialPrompt)
       initialPrompt agora vira promptTokens (cleanup #2)
       (env TAGARELA_DISABLE_PROMPT=1 força nil para A/B)
[7] state: processing → refining
       rawText em mãos
   ┌─── (R1) RefinerFactory.current(style:) lê prefs.refinerKind
   │           Se prefs.selectedStyleID == cruSemReescrita → IdentityRefiner direto
   ├─── (R2) caso .none           → IdentityRefiner (síncrono, instantâneo)
   ├─── (R3) caso .openai         → OpenAIRefiner
   │            (a) lê API key Keychain. Vazio → .unauthorized + fallback Identity
   │            (b) BaseRemoteRefiner: estima tokens; se > limit → trunca-com-marcador
   │            (c) HTTP POST /v1/chat/completions, timeout prefs.refinerTimeoutSec
   │            (d) RefinerErrorMapper aplica → fallback Identity
   ├─── (R4) caso .ollama         → OllamaRefiner
   │            (a) OllamaHealthChecker.isAvailable
   │            (b) offline → fallback Identity (sem chamar /api/chat)
   │            (c) online + (b)/(c)/(d) iguais ao OpenAI mas em /api/chat
   │            (d) erro → fallback Identity
   └─── (R5) refinedText em mãos
                + actualRefinerKind = "openai" | "ollama" | "none"
                  ("none" se fallback ocorreu, mesmo que prefs.refinerKind era ollama|openai)
[8] state: refining → injecting (transição interna; UI mostra "refining")
[9] Injector: clipboard → ⌘V → restore (Fase 1, sem mudança)
[P1] HistoryStore.save(Transcription{...})
     → applyRetention() em seguida
       delete WHERE createdAt < now - prefs.historyMaxDays
       OR keep top prefs.historyMaxItems by createdAt desc
[10] state: → idle, FloatingIndicator.hide()
```

**Decisões implícitas:**

- **Fallback semântico:** `actualRefinerKind` é o que de fato rodou. Histórico marca `"none"` quando fallback aconteceu — base honesta para análise futura ("quantas vezes Ollama caiu?").
- **Health check do Ollama** é a única chamada cacheada (TTL 30s). Cache invalida quando `prefs.refinerKind` muda OU `prefs.ollamaBaseURL` muda OU 30s expiram. Refiner em si não cacheia respostas.
- **Style cru pula `.refining`:** quando `selectedStyle == cruSemReescrita`, o coordinator transita `processing → injecting` direto, sem entrar em `.refining`. Não adiciona estado novo na máquina; só pula um estado existente.
- **Cancel** durante `.refining`: `cancelRecordingTasks()` propaga `Task.cancel()` → `URLSessionTask.cancel()`. Histórico não é salvo.
- **Trunca-com-marcador** mora dentro do refiner concreto (via `BaseRemoteRefiner`), não no coordinator. Coordinator não sabe de tokens.
- **Style resolução:** cada refiner concreto recebe `(rawText, style)` e monta `system + user` ele próprio. Sem builder central.

---

## 4. Modelo de dados

### 4.1 SwiftData — `Transcription`

```swift
@Model
final class Transcription {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var durationSeconds: Double
    var rawText: String
    var refinedText: String
    var refinerKind: String       // "openai" | "ollama" | "none"
    var llmModelName: String?     // ex: "gpt-5.4-mini"; nil quando refinerKind == "none"
    var whisperModelName: String  // ex: "large-v3"
    var styleName: String         // string crua, não FK — built-in evolui sem migration
    var frontmostAppBundleID: String?
}
```

**Container:** `~/Library/Application Support/com.tagarela.Tagarela/History.store` via `ModelConfiguration(url:)`. Para testes: `ModelConfiguration(isStoredInMemoryOnly: true)`. Sem versionamento explícito de schema na 2a (primeira release); comentário inline sinaliza que mudanças futuras precisam de `Schema(versionedSchema:)`.

### 4.2 `PreferencesStore` — chaves novas/relevantes para 2a

Tudo persistido em `UserDefaults.standard` sob namespace `com.tagarela.preferences.<chave>`. `PreferencesStore` é `ObservableObject` com properties `@Published`; cada setter escreve em UserDefaults imediatamente.

```
refinerKind            : enum    (default .none)                   ★ publisher
selectedStyleID        : UUID    (default = id de "conversa informal") ★ publisher
openAIModel            : String  (default "gpt-5.4-mini")
ollamaBaseURL          : String  (default "http://localhost:11434")
ollamaModel            : String  (default "qwen3.5:9b-nvfp4")
refinerTimeoutSec      : Double  (default 30)
technicalVocabulary    : [String] (default = DefaultVocabulary.terms)
historyMaxItems        : Int     (default 200)
historyMaxDays         : Int     (default 30)
audioBoostMaxGain      : Float   (default 20.0, range 1-50)        ← cleanup #4
```

★ marca os que precisam de Combine publisher (status bar reage à mudança via SwiftUI).

**Defaults da Fase 1 mantidos** sem alteração: `hotkey`, `whisperModel`, `whisperMinDurationSec`, `whisperMaxDurationSec`, `cancelarComEsc`, `showFloatingIndicator`, `theme`, `logLevel`. As chaves `indicatorVariant`, `beepOnStartStop`, `launchAtLogin` continuam não-implementadas — entram quando UI da 2b for construída.

**Codable:** `refinerKind` salvo como string raw (`"none"`, `"openai"`, `"ollama"`); `selectedStyleID` salvo como UUID string; `technicalVocabulary` salvo como `[String]` nativo de UserDefaults.

### 4.3 Keychain

```
service: "com.tagarela"
account: "openai-api-key"
class:   kSecClassGenericPassword
data:    UTF-8 da API key bruta
access:  kSecAttrAccessibleAfterFirstUnlock
```

`KeychainService` protocol:

```swift
protocol KeychainService: Sendable {
    func openAIKey() throws -> String?
    func setOpenAIKey(_ key: String?) throws // nil deleta
}
```

Erro tipado: `KeychainError.osStatus(OSStatus)`. **API key nunca entra em log, telemetria ou histórico.**

### 4.4 `Style` e built-ins

```swift
struct Style: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let systemPrompt: String       // já com cláusula code-switching anexada (exceto cru)
    let preserveOrality: Bool
    let isBuiltIn: Bool
}
```

Os 4 built-ins têm UUIDs hardcoded literais — assim `selectedStyleID` salvo na 1ª run continua válido em rebuilds. `BuiltInStyles.all: [Style]` ordenado para apresentação:

1. `conversa informal` (default)
2. `e-mail profissional`
3. `notas técnicas`
4. `cru — sem reescrita`

Cláusula code-switching, anexada ao final de cada `systemPrompt` exceto `cru — sem reescrita`:

> "Preserve termos técnicos em inglês conforme o uso comum em desenvolvimento de software brasileiro (ex: cloud, deploy, pool, pattern, mutex). Corrija fonetizações óbvias do Whisper (ex: 'loquei' → 'log it', 'diploiei' → 'deployei'). Se preservar oralidade está ativo, mantenha contrações orais ('tô', 'pra', 'cê')."

`cru — sem reescrita.systemPrompt` é uma string vazia/no-op. **Quando esse style está ativo, o pipeline pula o passo do refiner inteiro** (atalho de performance e clareza): `selectedStyle == cruSemReescrita` ⟹ `actualRefinerKind = "none"` independente de `prefs.refinerKind`.

### 4.5 `DefaultVocabulary`

Lista hardcoded em `Resources/DefaultVocabulary.swift`. Sem ordenação significativa. Cobertura inicial sugerida (~30-50 termos):

```
Postgres, Kubernetes, Docker, Slack, Linear, Notion, GitHub, GitLab, Jira,
deploy, deployei, commit, commitei, push, pull request, merge, rebase,
bug, feature flag, endpoint, payload, request, response, header, body,
cache, queue, mutex, actor, async, await, closure, struct, enum,
cloud, pool, pattern, hook, lifecycle, refactor, lint, build,
webhook, websocket, gRPC, REST, GraphQL, JSON, YAML,
log it, logei, deployei, scopei, runei, pushei
```

A lista final é responsabilidade da implementação ajustar a partir do uso real do autor; revisar no fim da 2a antes de fechar.

---

## 5. Tratamento de erros e fallbacks

Atalho mental: **o usuário nunca fica sem texto colado**. Erros pós-transcrição degradam para `IdentityRefiner`; o cru é entregue.

### 5.1 Mapa de erros do refiner

| Cenário | Detecção | RefinerError | Comportamento na 2a |
|---|---|---|---|
| OpenAI sem rede | `URLError.notConnectedToInternet` | `.networkOffline` | log + fallback Identity |
| OpenAI 5xx | HTTP 500-599 | `.serverError(status)` | log + fallback Identity |
| OpenAI timeout | `URLError.timedOut` | `.timedOut` | log + fallback Identity |
| OpenAI 401 / API key inválida | HTTP 401 | `.unauthorized` | log + fallback Identity (toast em 2b vai abrir modal de re-key) |
| OpenAI 429 | HTTP 429 | `.rateLimited` | log + fallback Identity |
| OpenAI key vazia | Keychain devolve `nil` antes de sair | `.unauthorized` | mesmo caminho |
| OpenAI/Ollama context window | HTTP 400 com body indicando context_length, OU detecção proativa via `TokenCounter` | `.contextExceeded` | retry 1× com texto truncado; falha persistente → fallback Identity |
| OpenAI/Ollama payload malformado | JSON decode failed ou faltando `choices`/`message`/`response` | `.malformedResponse` | log + fallback Identity |
| Ollama offline | health check timeout/erro | `.networkOffline` | fallback Identity **sem chamar /api/chat** |
| Ollama modelo não baixado | HTTP 404 ou body com `model not found` | `.modelNotFound(name)` | log + fallback Identity |

`actualRefinerKind` em todos os casos de fallback = `"none"`. `Transcription.refinedText` = `Transcription.rawText` literal.

### 5.2 Trunca-com-marcador

Implementado em `BaseRemoteRefiner`. Algoritmo:

1. Estimar tokens do `system + user` via `TokenCounter` (~`chars / 4`).
2. Se `estimated <= modelContextWindow * 0.8` → manda direto.
3. Se excede → manter primeiros 40% dos chars do `rawText`, marcador `[…texto cortado…]`, últimos 40%. Retry 1×.
4. Se a 1 retry ainda excede ou volta com `.contextExceeded` → fallback Identity.

`modelContextWindow` em tabela hardcoded (`RemoteRefinerConfig.swift`):

| modelo | janela aproximada |
|---|---|
| `gpt-5.4-mini` | 200_000 |
| `gpt-5.4` | 200_000 |
| `qwen3.5:*` | 32_768 |
| `llama3.2:*` | 128_000 |
| desconhecido | 8_000 (conservador) |

### 5.3 Cancelamento durante `.refining`

- O `Task` que segura a chamada do refiner é registrado em `recordingTasks`.
- `cancelRecordingTasks()` propaga `Task.cancel()` → `URLSessionTask.cancel()` aborta HTTP imediatamente.
- Histórico **não** é salvo. State volta `.idle`.

### 5.4 Erros de `HistoryStore`

| Cenário | Comportamento |
|---|---|
| SwiftData write falha (disco cheio, corrupção) | log error, paste já aconteceu, transcription perdida (não bloqueia o pipeline). |
| Container falha ao abrir no boot | log error, app sobe com `HistoryStoreNoop` (no-op que aceita save sem persistir). Próxima sessão tenta de novo. |
| Retenção falha (delete throws) | log error, save anterior fica aceito; próxima save tenta de novo. |

### 5.5 Erros de Keychain

| Cenário | Comportamento |
|---|---|
| `setOpenAIKey` falha | modal mostra inline error "não foi possível salvar — tente de novo". Modal não fecha. |
| `openAIKey()` falha | tratada igual a "key vazia" (`.unauthorized`). Refiner cai para Identity. |

### 5.6 Logs

Toda essa instrumentação passa por `Logger(subsystem: "com.tagarela", category: <nome>)`. **Sem dados sensíveis:** nada de API key, texto cru, texto refinado. Permitido: refiner kind, modelo, status code, duração da chamada, error case.

> Cleanup [#3](../04-decisoes/cleanup-fase1.md#3-stderr-instrumentation-deve-virar-loggertagarelainfo) (stderr → Logger) **não é escopo da 2a**.

---

## 6. UI mínima da 2a

Tudo aqui é **funcional permanente** (vai para release final), não temporária.

### 6.1 Status bar — `MenuBarContent`

```
┌───────────────────────────────────────┐
│  Tagarela                             │  ← cabeçalho (Fase 1)
│  ────────────────────────────────     │
│  ▸ ocioso                             │  ← StateRow (Fase 1)
│  ────────────────────────────────     │
│  Backend ▸ Ollama                     │  ← novo: submenu
│  Estilo ▸ conversa informal           │  ← novo: submenu
│  ────────────────────────────────     │
│  Permissões ▸ tudo ok                 │  ← Fase 1 (resumido)
│  ────────────────────────────────     │
│  Sair                                 │  ← Fase 1
└───────────────────────────────────────┘
```

**Submenu `Backend`:**

```
☐ Sem LLM
☑ Ollama
☐ OpenAI
────────────────────────────
Configurar API key da OpenAI…
```

- Tap em "Sem LLM" / "Ollama" → atualiza `prefs.refinerKind` direto.
- Tap em "OpenAI": se Keychain tem key → atualiza prefs; se vazio → atualiza prefs **e** abre `OpenAIKeyPromptWindow` automaticamente. Cancelar a modal reverte `refinerKind` para o valor anterior.
- Tap em "Configurar API key da OpenAI…" → abre `OpenAIKeyPromptWindow` sempre (caso de troca).

**Submenu `Estilo`** (radio com 4 opções, ordem fixa):

```
☑ conversa informal
☐ e-mail profissional
☐ notas técnicas
☐ cru — sem reescrita
```

- Tap → atualiza `prefs.selectedStyleID`. Sem confirmação. Próxima captura usa o novo style.

**Reatividade:** `MenuBarContent` observa `PreferencesStore.refinerKindPublisher` e `selectedStyleIDPublisher` via `@StateObject`/`@Published`. Mudança em prefs → refresh imediato dos checkmarks e do label dos submenus.

### 6.2 Modal `OpenAIKeyPromptWindow`

`NSPanel` standalone, layout vertical compacto, ~360×220 pt.

```
┌──────────────────────────────────────────┐
│ API key da OpenAI                        │
│                                          │
│ A key fica no Keychain do macOS, no      │
│ serviço com.tagarela. Nunca aparece em   │
│ logs nem é enviada para outros lugares.  │
│                                          │
│ ┌──────────────────────────────────┐     │
│ │ sk-…                             │     │  ← SecureField
│ └──────────────────────────────────┘     │
│                                          │
│ ⚠︎ ____________________________           │  ← inline error slot
│                                          │
│         [Cancelar]   [Salvar]            │
└──────────────────────────────────────────┘
```

**Comportamento:**

- Abre como `NSPanel` floating mas chama `NSApp.activate(ignoringOtherApps: true)` antes de `panel.makeKeyAndOrderFront` — sem isso o `SecureField` não aceita digitação quando vem do submenu da status bar.
- Validação cliente: regex `^sk-[A-Za-z0-9_\-]{20,}$`. Avisa se parece inválido (slot inline) mas permite salvar mesmo assim.
- "Salvar" → `keychain.setOpenAIKey(text)` → fecha. Erro → mostra no slot inline, modal não fecha.
- "Cancelar" → fecha sem mexer no Keychain. Se foi triggada por mudança de `refinerKind` para `.openai` com Keychain vazio, reverte `refinerKind`.
- ESC fecha como Cancelar. ⌘V no SecureField cola normalmente.
- Identidade visual: usa tokens de [`DesignSystem.swift`](../../app/Tagarela/Design/DesignSystem.swift) da Fase 1.

### 6.3 Visual e copy

- Submenus seguem estilo nativo de `MenuBarExtra`. Sem custom rendering — checkmark é nativo do macOS.
- Strings dos submenus em pt-BR conforme [`05-design`](../05-design/README.md). Strings novas vão para `Localizable.strings` (decisão F2a-13).
- Ícone da status bar: sem mudança (Fase 1 preserva).

### 6.4 O que NÃO está nesta UI

- Janela de Preferências/Settings de qualquer espécie.
- Status visual sobre Ollama estar offline.
- Aviso de "key inválida" no menu (só log + Identity silencioso).
- Exposição de `historyMaxItems`/`audioBoostMaxGain`/`technicalVocabulary` na UI (só `defaults write`).
- Listagem de transcrições. "Últimos 5" é 2b.

---

## 7. Estratégia de testes

Meta: ~25-30 testes XCTest novos. Total no fim da 2a: ~40-45.

### 7.1 Refiners (URLProtocol mock)

Helper compartilhado `MockURLProtocol` em `TagarelaTests/Helpers/`. Cada teste registra responder `(URLRequest) -> (HTTPURLResponse, Data)` ou `Error`.

**`OpenAIRefinerTests`** (~10): success, 401, 5xx, timeout, 429, malformed JSON, missing choices field, contextExceeded com retry sucesso, contextExceeded duas vezes, empty key.

**`OllamaRefinerTests`** (~8): healthCheck offline (skip /chat), healthCheck online proceeds, healthCheck cache 30s evita double-call, model not found 404, success, 5xx, timeout, malformed.

**`RefinerErrorMapperTests`** (~5): URLError casos, HTTP 401/429/500, body com context_length_exceeded, malformed JSON.

**`TokenCounterTests`** (~3): contagem aproximada bate margem, vazia → 0, decisão de truncar dispara no limite.

**`PipelineCoordinatorTests` (adições)** (~3): refiner throws → fallback Identity + history kind=none, style cru pula refiner + history kind=none, cancel during refining cancela HTTP + sem history.

### 7.2 HistoryStore (SwiftData in-memory)

**`HistoryStoreTests`** (~6): save persiste, recent newest first, retention by count keeps top N, retention by days purges old, intersection de ambos limites, save aplica retention imediatamente.

### 7.3 PreferencesStore

**`PreferencesStoreTests`** (~4): defaults bate design v1, setRefinerKind persiste e publisha, setSelectedStyleID persiste e publisha, audioBoostMaxGain clamped 1-50.

### 7.4 Keychain

**`KeychainServiceTests`** com **fake** (sem tocar Keychain real): set→get, set nil deleta, get absent → nil. Mais um **smoke test** marcado para tocar Keychain real e limpar no `tearDown` — guardrail mínimo.

### 7.5 Style + BuiltInStyles

**`StyleTests`** (~3): 4 built-ins têm IDs distintos, systemPrompt inclui cláusula code-switching (exceto cru), cru pula refiner (cross-check com PipelineCoordinator).

### 7.6 Manual (versionado)

**`fase2a-manual.md`** — checklist novo em `tagarela_docs/03-funcionalidades/checklists/`:
- Trocar backend pelo submenu mantém escolha entre rebuilds
- Trocar estilo pelo submenu altera resultado da próxima captura
- API key OpenAI: 1ª captura sem key → modal aparece via menu; salvar funciona; revogar → nada vaza em log
- Ollama desligado durante captura → texto cru chega ao destino, log mostra fallback, histórico marca `"none"`
- 5 capturas + retention configurada para 3 → base mantém só 3 entries
- ⌘V cola texto refinado em TextEdit, Notes, Slack, VS Code, Terminal
- Cancel via Esc durante refining aborta sem salvar histórico

**`fase2-validacao-prompt.md`** — checklist do A/B do cleanup #2 (decisão F2a-14):
- 8 frases-teste com termos técnicos (`Postgres`, `Kubernetes`, `Slack`, `deploy`, `commitei`)
- Gravar duas vezes: `TAGARELA_DISABLE_PROMPT=1 open …` e sem env var
- Comparar texto cru das duas runs
- Decisão: prompt fica ON / OFF / inconcluso → registra ADR

### 7.7 O que não testamos automaticamente

- UI dos submenus (visual e click-through → checklist manual).
- Modal da API key (visual no checklist; lógica de salvar/cancelar no `KeychainServiceTests`).
- Integração real com OpenAI/Ollama (não vale custo/instabilidade de CI tocar API real; só `MockURLProtocol`).

---

## 8. Riscos, dependências e ordem de entrega

### 8.1 Riscos técnicos

| Risco | Impacto | Mitigação |
|---|---|---|
| `WhisperKit.tokenizer` API mudou entre versões | promptTokens não funciona | Validar com WhisperKit 0.18.0 atual antes de implementar; se instável, fechar #2 com decisão (a) |
| SwiftData `@Model` + Swift strict concurrency | warnings/erros de Sendable | `HistoryStoreLive` é `@unchecked Sendable` com `ModelContainer` confinado; queries via `MainActor` ou explicit context |
| Modal `NSPanel` não recebe foco quando aberta de submenu fechado | impossível digitar API key | `NSApp.activate(ignoringOtherApps: true)` antes de `panel.makeKeyAndOrderFront`; documentar |
| Cache de health check 30s mascara reconexão recente | usuário acabou de subir Ollama mas pipeline cai para Identity | Cache invalida quando `prefs.refinerKind` muda OU quando 30s expira; aceito |
| Trunca-com-marcador piora resultado em casos raros | usuário recebe texto pior | Fallback Identity em 2ª falha; logs mostram quando truncou |
| API key vazia na 1ª seleção do backend confunde | usuário não entende fallback silencioso | Modal abre automaticamente quando seleciona OpenAI sem key (§6.1) |
| Default `qwen3.5:9b-nvfp4` pode não rodar no Apple Silicon | Ollama 404 → fallback Identity | Documentado no design v1 §4.2; usuário troca via `defaults write` |

### 8.2 Dependências externas

- **WhisperKit 0.18.0** — já usado na Fase 1; cleanup #2 toca `tokenizer`.
- **SwiftData (macOS 14+)** — já no target; primeiro uso no projeto.
- **Security.framework** — primeiro uso productivo (já tocado no debug TCC).
- **URLSession** — sem novidade.
- **Sem novas SPM** previstas.

### 8.3 Ordem de entrega (esboço — vira plan no writing-plans)

A ordem otimiza para PRs pequenos shippable e risco técnico cedo. Cada item é um commit (ou alguns commits relacionados). Milestones marcados são pontos onde dá para parar e usar o app real.

```
1. PreferencesStore (struct + @Published, defaults, codable enums) + tests
2. KeychainService (protocol + Live + fake) + tests
3. RefinerError + RefinerErrorMapper + TokenCounter + tests
4. Style + BuiltInStyles + DefaultVocabulary + tests
5. OpenAIRefiner (URLProtocol mock, BaseRemoteRefiner) + tests
   ── milestone: pipeline com OpenAI funcionando (configurado por defaults write) ──
6. OllamaRefiner + OllamaHealthChecker + tests
   ── milestone: pipeline com Ollama funcionando (configurado por defaults write) ──
7. RefinerFactory + wire-up no AppContainer + PipelineCoordinatorTests adições
8. cleanup #2 — promptTokens via WhisperKit.tokenizer + checklist A/B
9. cleanup #4 — audioBoostMaxGain → AudioCaptureLive
10. HistoryStore (SwiftData) + retenção + tests + wire-up no Pipeline
    ── milestone: histórico persistente, ainda sem UI ──
11. MenuBarContent: Backend submenu
12. OpenAIKeyPromptWindow modal + integração com Backend submenu
    ── milestone: trocar backend e configurar API key sem CLI ──
13. MenuBarContent: Estilo submenu + cabeçalho mostrando ativo
    ── milestone: ergonomia da 2a completa ──
14. Localizable.strings infra + migração das strings novas da 2a
15. Checklist manual fase2a-manual.md + execução completa
16. Atualização docs (modulos-fase1 → modulos-fase2a, README, ADRs novos)
    ── exit Fase 2a, pronto para brainstorming Fase 2b ──
```

### 8.4 Cronograma rough

Fase 1 levou ~30 tarefas em sessões concentradas. A 2a tem **menos risco arquitetural** mas **mais surface** (3 refiners + persistência + UI mínima). Estimativa: ~16 itens de planejamento que viram ~25-35 commits. Sem prazo absoluto — a Fase 2b só começa após 2a estar mergeada e checklist manual passar.

---

## 9. Próximos passos

1. Esta spec é revisada pelo usuário.
2. Após aprovação, `superpowers:writing-plans` produz o plano de implementação detalhado, salvo em `tagarela_docs/specs/2026-04-27-tagarela-v1-fase2a-plan.md`.
3. Implementação segue o plano, com cada passo atualizando `tagarela_docs/` antes de ser declarado pronto (per [`/CLAUDE.md`](../../CLAUDE.md)).
