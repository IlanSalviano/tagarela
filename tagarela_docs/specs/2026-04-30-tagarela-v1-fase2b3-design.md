---
data: 2026-04-30
status: implementado
fase: 2b-3 de 3 sub-fases da Fase 2b
goal: cancel HTTP em vôo + UX modo refinador/livre pros custom styles
implementado_em: 2026-04-30 (branch fase-2b3, 8 commits, 155 testes verdes, aceite manual ok-com-achados)
---

# tagarela v1 — Fase 2b-3: Cancel HTTP + Modo refinador/livre

Spec da terceira (e última) sub-fase da Fase 2b. Brainstorming de 2026-04-30.

> Regras de processo: ver [`/CLAUDE.md`](../../CLAUDE.md). Nada implementado sem ler doc; nada pronto sem doc atualizada.
>
> **Sub-fase antecessora:** [`2026-04-29-tagarela-v1-fase2b2-design.md`](./2026-04-29-tagarela-v1-fase2b2-design.md). 2b-2 entregou histórico viewer em Preferências, submenu "Recentes" na status bar, sistema de toasts, indicadores B/C/D + picker, fechamento do cleanup #2 da 2a. Aceite manual passou ✅.
>
> **Estado pós-2b-2:** suíte de 145 testes verde; cleanups #1, #2, #3, #4 da 2a fechados; cleanups #1, #2, #3 da 2b-1 fechados.
>
> **Itens carimbados pra esta fase** (do roadmap das fases anteriores):
> 1. [Cleanup #5 da 2a](../04-decisoes/cleanup-fase2a.md#5-cancelamento-durante-refiner-não-interrompe-a-request-http) = [Cleanup #4 da 2b-1](../04-decisoes/cleanup-fase2b1.md#4-esc-não-cancela-injeção-http-em-vôo--referência-ao-cleanup-5-da-fase-2a) — cancel HTTP via `Task.cancel()`.
> 2. [Cleanup #2 da 2b-1, follow-up](../04-decisoes/cleanup-fase2b1.md#2-custom-style-fazia-llm-responder-à-frase-em-vez-de-transcrever--fechado-2026-04-29) — UX dedicada pro `rewriterDiscipline` (toggle modo refinador / modo livre).
>
> **Itens explicitamente excluídos** (decisão do user nesta sessão): tuning fino dos prompts dos built-in styles. Empurrado pra fora da 2b-3 — built-ins ficam como estão.

---

## 1. Visão e escopo

### 1.1 Goal

Fechar dois débitos técnicos remanescentes:

1. **Esc realmente aborta o request HTTP em vôo.** Hoje, durante `.processing`/`.refining`, Esc seta uma flag interna que impede inject/save mas o request HTTP continua rolando até completar — gasta tokens (OpenAI) ou segura GPU (Ollama). A 2b-3 envolve `runTranscribeAndInject` em `Task` armazenada e cancela ela no Esc; URLSession honra cancellation nativamente. Whisper local recebe sinal via `Task.isCancelled` (best-effort: WhisperKit pode ou não honrar).
2. **Custom styles ganham modo livre.** Hoje `CustomStyle.asStyle()` sempre prefixa `rewriterDiscipline` (proteção contra LLM responder à fala em vez de transcrever) — fix da 2b-1, commit `855b416`. Fica embutido sem o user saber. A 2b-3 expõe um Toggle "Modo refinador" (default ON, comportamento atual) na sheet de edição. Off = modo livre, sem prefixo, com warning inline.

### 1.2 Exit criteria (pronto pra encerrar a Fase 2b)

1. **Cancel HTTP funcional**: durante `.processing`/`.refining`, Esc aborta o request HTTP da `URLSession` em < 200ms. Verificável via instrumentação ad-hoc no aceite (Activity Monitor / `nvidia-smi` pra Ollama).
2. **`PipelineCoordinator` armazena `pipelineTask: Task<Void, Never>?`**. `handleToggle` na transição `.recording → .processing` envolve `runTranscribeAndInject` em Task armazenada. `handleCancel` `.processing/.refining` chama `pipelineTask?.cancel()` antes de `setState(.idle)` + mantém `cancelled = true`.
3. **Helper `aborted()`** consolida `cancelled || Task.isCancelled` nos 3 checkpoints existentes (pós-transcribe, pós-refine, pós-inject).
4. **Lógica preservada (regression)**: `catch RefinerError.cancelled where cancelled` continua distinguindo user-cancel real (Esc) de network-drop disfarçado (commit `99d174e`). Cancel real → aborta sem fallback nem inject; sem flag → `RefinerFallbackReason.networkOffline` + toast + identity fallback.
5. **`@Model CustomStyle` ganha campo `bypassDiscipline: Bool`** (default `false`). Init com default mantém retrocompat de call sites. Lightweight migration valida em store real do user no aceite manual.
6. **`CustomStyle.asStyle()` consulta `bypassDiscipline`**: se `true`, retorna `Style` com `systemPrompt` puro (+ code-switching opcional). Se `false`, prefixo `rewriterDiscipline` (comportamento atual).
7. **`CustomStyleEditSheet` ganha toggle "Modo refinador" + caption + warning inline condicional** (SF Symbol `exclamationmark.triangle.fill` em laranja) quando livre.
8. **Suíte XCTest verde com +12 testes novos** (~6 cancel + ~6 modo livre); total ~157 partindo de 145.
9. **Aceite manual via `tagarela_docs/03-funcionalidades/checklists/fase2b3-manual.md`** — 8 blocos, condução tradicional bloco-a-bloco.
10. **Cleanups fechados**: cleanup-fase2a.md item 5 e cleanup-fase2b1.md itens 2 (follow-up) e 4.

### 1.3 Não-objetivos da 2b-3

- **Tuning fino dos prompts dos built-in styles** — explicitamente excluído pelo user. Built-ins ficam como estão.
- **Onboarding novo, re-bind real da hotkey, captura L/R Option** — fora de toda a Fase 2b.
- **Badge "LIVRE" no card de estilos custom em [`StylesView`](../../app/Tagarela/Preferences/UI/Sections/StylesView.swift)** — decisão F2b3-5: warning fica só na sheet, sem indicação na grid. Ajustar se virar dor real no aceite.
- **Cancel granular dentro do WhisperKit** — best-effort via `Task.cancel()` propagando pra dentro. Sem instrumentação custom.
- **Estabelecer `VersionedSchema` baseline pro SwiftData** — segue como follow-up listado no [cleanup-fase2b1.md item 5](../04-decisoes/cleanup-fase2b1.md#5-achados-secundários-do-code-review-do-branch-informacional). Lightweight migration deve cobrir o `Bool` desta fase.
- **Cancel durante `.recording`** — caminho separado em `handleCancel`, sem mudança nesta fase.
- **Toast de sucesso ou de "request cancelado"** — Esc é gesto deliberado; pill+toast muito barulhento. Idle silencioso é o desejado.

### 1.4 Decisões nucleares (do brainstorming 2026-04-30)

| # | Decisão | Alternativas consideradas |
|---|---|---|
| F2b3-1 | **Escopo monolítico de 2 itens** (cancel HTTP + UX modo livre) | Decompor em 2b-3a/2b-3b; expandir pra incluir tuning de built-ins |
| F2b3-2 | Cancel via `Task.cancel()` envolvendo todo o `runTranscribeAndInject` (escopo total: transcribe + refine + inject + save) | Cancelar só o HTTP do refiner; preservar transcribe (não desperdiçar áudio gravado) |
| F2b3-3 | **Manter flag `cancelled: Bool`** coexistindo com `Task.isCancelled` — flag preserva distinção user-cancel vs network-drop disfarçado (commit `99d174e`) | Substituir flag por `Task.isCancelled` puro (perderia a distinção) |
| F2b3-4 | Helper `aborted() -> Bool` agrega `cancelled || Task.isCancelled` nos 3 checkpoints | Inline `if cancelled || Task.isCancelled` em cada checkpoint (mais ruidoso) |
| F2b3-5 | UX modo livre = **Toggle simples** "Modo refinador" (default ON), paralelo ao toggle de code-switching | Segmented control "Refinador / Livre"; modo único sem opção (status quo); modo via campo "tom" estruturado |
| F2b3-6 | **Warning inline** (SF Symbol + texto curto laranja) embaixo do toggle, condicional ao modo livre | NSAlert de confirmação ao marcar livre; badge "LIVRE" no card da grid; A+C combinados |
| F2b3-7 | Persistência via novo campo **`bypassDiscipline: Bool`** (default `false`) no `@Model CustomStyle` | Enum `RefinerMode { .refiner, .livre }`; campo global em `PreferencesStore` |
| F2b3-8 | **SwiftData lightweight migration** (Bool com default) — sem `VersionedSchema` baseline nesta fase | Estabelecer `VersionedSchema` como pré-requisito (ampliaria escopo); campo `Bool?` opcional |

---

## 2. Arquitetura

### 2.1 Princípios herdados

- **Boundaries via protocolos** mantidas: `CustomStyleStore` (protocol), `Injecting`, `Transcribing`, `TextRefiner` — nenhum protocolo muda assinatura. Apenas `CustomStyleStore.create(...)` ganha parâmetro opcional com default.
- **SwiftUI + AppKit cirúrgico**: warning inline é pure SwiftUI dentro do `Form` existente. Sem novos NSWindow/NSPanel.
- **Strings em `Localizable.strings`**: 3 chaves novas no namespace `styles.edit.discipline.*`.
- **Sem novas SPMs.**
- **Idioma**: pt-BR em UI; inglês em código (identifiers, comentários técnicos).

### 2.2 Módulos novos

Nenhum. A fase é cirúrgica em arquivos existentes — diferente das fases anteriores que introduziram módulos novos (toasts, indicadores B/C/D, history viewer).

### 2.3 Módulos modificados

| Módulo | Mudança |
|---|---|
| [`PipelineCoordinator`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift) | `+ private var pipelineTask: Task<Void, Never>?`. `handleToggle` na transição `.recording` envolve `runTranscribeAndInject` em Task armazenada. `handleCancel` `.processing/.refining` faz `pipelineTask?.cancel()` antes de `setState(.idle)`. Novo helper `aborted() -> Bool`. Cleanup `pipelineTask = nil` ao fim de `runTranscribeAndInject`. |
| [`CustomStyle`](../../app/Tagarela/Refiner/CustomStyle.swift) | `+ var bypassDiscipline: Bool` (default `false`). Init ganha param opcional. `asStyle()` condiciona o prefixo de `rewriterDiscipline`. |
| [`CustomStyleStore`](../../app/Tagarela/Refiner/CustomStyleStore.swift) (protocol) | `create(name:systemPrompt:appendCodeSwitching:bypassDiscipline:)` ganha o novo parâmetro **sem default no protocol** — todos os call sites passam explicitamente (ver §4.3 pra rationale). Retrocompat de testes / migration cuidada pelo default em `CustomStyle.init`. |
| [`CustomStyleStoreLive`](../../app/Tagarela/Refiner/CustomStyleStoreLive.swift) | Implementação do `create` propaga `bypassDiscipline` pra `CustomStyle.init`. `update` não muda — recebe model inteiro. |
| [`CustomStyleStoreNoop`](../../app/Tagarela/Refiner/CustomStyleStoreNoop.swift) | Mesma assinatura nova; ignora valor (mantém comportamento no-op). |
| [`CustomStyleEditSheet`](../../app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift) | `+ @State private var bypassDiscipline: Bool = false`. Novo Toggle "Modo refinador" (ligado a `!bypassDiscipline`) + caption help text + warning inline condicional. `populate()` lê do model em edit; `save()` propaga em create/update. |
| `Localizable.strings` | 3 chaves novas: `styles.edit.discipline.toggle`, `styles.edit.discipline.help`, `styles.edit.discipline.warning`. |

### 2.4 O que **não** muda

- `BuiltInStyles` — built-ins têm proteção embutida no próprio `systemPrompt`; modo refinador/livre é exclusivo de custom styles.
- `RefinerFactory`, `StyleProvider` — leem o `Style` final via `asStyle()`, sem precisar saber se veio de modo refinador ou livre.
- `RefinerError`, `RefinerErrorMapper`, `RefinerFallbackReason`, `ToastCenter` — toda infra de fallback da 2b-2 fica intacta. O cancel via `Task.cancel()` apenas faz `URLSession` lançar `URLError.cancelled` que já é mapeado pra `RefinerError.cancelled`, e o `where cancelled` no catch decide o ramo.
- `OpenAIRefiner`, `OllamaRefiner` — sem mudança. URLSession já honra `Task.cancel()` nativamente.
- Submenu "Recentes" na status bar, history viewer, indicador picker — sem mudança.

---

## 3. Item 1 — Cancel HTTP em vôo

### 3.1 Estado atual e problema

`PipelineCoordinator` é `actor`. Hoje:

- `runTranscribeAndInject()` é chamado direto de `handleToggle()` quando `state == .recording`. **Não está em Task armazenada.**
- `handleCancel()` durante `.processing`/`.refining` apenas seta `cancelled = true`. A flag é checada após cada `await` no `runTranscribeAndInject`, abortando antes de inject/save.
- Limitação: o `await session.data(for:)` dentro de `OpenAIRefiner.chat`/`OllamaRefiner.chat` continua rolando até completar — gasta tokens (OpenAI) ou segura GPU (Ollama).
- Lógica fina existente (commit `99d174e`) que **não pode quebrar**: `catch RefinerError.cancelled where cancelled` em [`PipelineCoordinator.swift:184-205`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift#L184) distingue user-cancel real (Esc) de network-drop disfarçado.

### 3.2 Mudanças no `PipelineCoordinator`

**Novo campo:**

```swift
private var pipelineTask: Task<Void, Never>?
```

**`handleToggle` na transição `.recording`:**

```swift
case .recording:
    cancelRecordingTasks()
    pipelineTask = Task { [weak self] in
        await self?.runTranscribeAndInject()
    }
```

`runTranscribeAndInject` continua sendo método isolado do actor; a Task só serve como handle cancelável.

**`handleCancel` durante `.processing`/`.refining`:**

```swift
case .processing, .refining:
    cancelled = true
    pipelineTask?.cancel()   // novo — propaga pra URLSession
    setState(.idle)
```

`setState(.idle)` mantém o behavior atual: UI vai pra idle imediato. A Task continua rolando até o próximo `await` abortar — mas agora aborta de verdade no request HTTP.

**Helper `aborted()`:**

```swift
private func aborted() -> Bool {
    cancelled || Task.isCancelled
}
```

Substitui as 3 ocorrências atuais de `if cancelled` no `runTranscribeAndInject` por `if aborted()`.

**Cleanup ao fim:**

`runTranscribeAndInject` fica wrappeado em `defer { pipelineTask = nil }` no caller (a Task em `handleToggle`), ou cleanup explícito no fim do método. Implementação preferida: cleanup no callsite via Task wrapper:

```swift
pipelineTask = Task { [weak self] in
    await self?.runTranscribeAndInject()
    await self?.clearPipelineTask()
}

private func clearPipelineTask() { pipelineTask = nil }
```

Alternativa equivalente: `defer { pipelineTask = nil }` dentro do método se a sintaxe permitir referência ao actor self (ela permite — defer dentro de método de actor isolada ao próprio actor).

### 3.3 Como o cancel se propaga

| Camada | Comportamento sob `Task.cancel()` |
|---|---|
| `audio.stop()` | Já completou antes do cancel ser possível (cancel só vale em `.processing`/`.refining`). |
| `transcriber.transcribe(...)` (WhisperKit) | Recebe sinal via `Task.isCancelled`. **Best-effort**: WhisperKit pode ou não honrar. Se completar, `if aborted()` no checkpoint pós-transcribe aborta antes de chamar refiner. |
| `refiner.refine(...)` → `URLSession.data(for:)` | URLSession honra cancellation nativamente. Lança `URLError.cancelled` → `RefinerErrorMapper.from(_:)` → `RefinerError.cancelled`. |
| `injector.inject(...)` | Não chega lá: `if aborted()` antes do inject aborta. |
| `historyStore.save(...)` | Não chega lá. |

### 3.4 Lógica `RefinerError.cancelled` preservada

O bloco existente em [`PipelineCoordinator.swift:184-205`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift#L184) **não muda**. Cenários:

**User aperta Esc durante refine:**
1. `handleCancel` seta `cancelled = true` + chama `pipelineTask?.cancel()`.
2. URLSession aborta → `RefinerError.cancelled` é lançado.
3. `catch RefinerError.cancelled where cancelled` casa → aborta sem fallback nem inject. ✅

**Network-drop sem Esc** (ex: `pkill ollama` durante refine):
1. URLSession lança `URLError.cancelled` (-999) sem que `cancelled` esteja `true`.
2. `RefinerError.cancelled` é lançado, mas `where cancelled` **não** casa.
3. Cai no `catch` genérico → mapeado pra `RefinerFallbackReason.networkOffline` → toast `.refinerFellBack(.networkOffline)` + identity fallback + inject do texto cru. ✅ (Regression do fix `99d174e`.)

### 3.5 Edge cases

| Edge | Comportamento |
|---|---|
| Esc 100ms após começar refine | `pipelineTask?.cancel()` chamado, URLSession aborta cedo, `RefinerError.cancelled where cancelled` casa, idle limpo. |
| Esc após `await transcriber.transcribe` retornar mas antes de refine começar | `if aborted()` no checkpoint pós-transcribe pega → idle sem refinar. |
| Esc múltiplo (clica Esc duas vezes seguidas durante refine) | Segundo `pipelineTask?.cancel()` em Task já cancelada é no-op. `cancelled` já é `true`. State já é `.idle`. Tudo idempotente. |
| `pipelineTask?.cancel()` chamado depois da Task já ter completado | No-op — `Task.cancel()` em Task finalizada é seguro. Cleanup de `pipelineTask = nil` previne reuso da referência. |
| Cancel durante `audio.stop()` (transição `.recording → .processing` antes da Task começar) | Não-issue: `handleCancel` em `.recording` segue caminho separado (cancela tasks de gravação, não toca `pipelineTask` que ainda nem existe). |
| Whisper não honra cancel e completa em `.processing` | `if aborted()` pós-transcribe aborta. Áudio já gravado vira nada — aceitável (Esc é gesto deliberado de descarte). |
| OpenAI key inválida + Esc rápido | Race: `RefinerError.unauthorized` chega antes ou depois do `cancelled = true`. Se antes: cai em fallback Identity + toast `.refinerFellBack(.unauthorized)` (comportamento atual). Se depois: `where cancelled` casa, idle limpo. Ambos aceitáveis. |

---

## 4. Item 2 — Modo refinador / modo livre

### 4.1 Estado atual

[`CustomStyle`](../../app/Tagarela/Refiner/CustomStyle.swift) `@Model` SwiftData hoje:

```swift
@Attribute(.unique) var id: UUID
var name: String
var systemPrompt: String
var appendCodeSwitching: Bool
var createdAt: Date
var updatedAt: Date
```

`asStyle()` sempre prefixa `rewriterDiscipline`:

```swift
var prompt = CustomStyle.rewriterDiscipline + systemPrompt
if appendCodeSwitching { prompt += codeSwitchingClause }
```

[`CustomStyleEditSheet`](../../app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift) hoje tem 3 campos: `name`, `systemPrompt`, `appendCodeSwitching`.

### 4.2 Mudança no model

Novo campo:

```swift
var bypassDiscipline: Bool   // default false → mantém comportamento atual
```

Init com default:

```swift
init(id: UUID = UUID(),
     name: String,
     systemPrompt: String,
     appendCodeSwitching: Bool,
     bypassDiscipline: Bool = false,
     createdAt: Date = .now,
     updatedAt: Date = .now)
```

`asStyle()` condicionado:

```swift
var prompt = bypassDiscipline ? systemPrompt : (CustomStyle.rewriterDiscipline + systemPrompt)
if appendCodeSwitching { prompt += codeSwitchingClause }
```

Code-switching segue ortogonal ao modo: pode estar on em ambos os modos.

### 4.3 Mudança no protocol e Live store

`CustomStyleStore.create(...)` ganha parâmetro:

```swift
func create(name: String,
            systemPrompt: String,
            appendCodeSwitching: Bool,
            bypassDiscipline: Bool) async throws -> CustomStyle
```

Decisão: **sem default no protocol** — todos os call sites passam o valor explicitamente. Isso evita esquecimentos silenciosos quando alguém chamar a partir de um caminho novo. (Default no `CustomStyle.init` cuida do retrocompat de testes / migration.)

`CustomStyleStoreLive.create` repassa pra `CustomStyle.init`. `CustomStyleStoreNoop.create` adapta a assinatura, ignora o valor.

`update(_ style: CustomStyle)` não muda — recebe o model inteiro.

### 4.4 Mudança na sheet

`CustomStyleEditSheet` ganha:

```swift
@State private var bypassDiscipline: Bool = false
```

Novo Toggle no `Form`, posicionado logo abaixo do toggle de code-switching:

```swift
Toggle(String(localized: "styles.edit.discipline.toggle",
              defaultValue: "Modo refinador (recomendado)"),
       isOn: Binding(get: { !bypassDiscipline },
                     set: { bypassDiscipline = !$0 }))
Text(String(localized: "styles.edit.discipline.help",
            defaultValue: "Refinador prefixa proteção contra o LLM responder à fala em vez de transcrever."))
    .font(.caption)
    .foregroundStyle(.secondary)
if bypassDiscipline {
    HStack(alignment: .top, spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
        Text(String(localized: "styles.edit.discipline.warning",
                    defaultValue: "Modo livre: sem proteção. O LLM pode responder à fala em vez de transcrever."))
            .font(.caption)
            .foregroundStyle(.orange)
    }
}
```

`populate()` lê `bypassDiscipline = s.bypassDiscipline` no edit.

`save()` propaga em create (passa parâmetro) e em edit (atribui no model antes do `update`).

A altura da sheet (`.frame(width: 520, height: 420)`) precisa de margem extra pro warning condicional sem causar clipping. Ajustar pra `height: 460` ou trocar pra `idealHeight` + sizing dinâmico — decisão final no momento da implementação.

### 4.5 Migration SwiftData

**Plano A (default):** lightweight migration automática.
- `@Model CustomStyle` ganha o novo campo `Bool` com default `false` no init.
- SwiftData detecta o schema novo, faz migration automática preenchendo `false` em rows antigos.
- Validar no aceite manual (Bloco 7) com store real do user em `~/Library/Application Support/com.tagarela.Tagarela/`.

**Plano B (fallback se A quebrar):** declarar `@Attribute` opcional.
- Trocar `var bypassDiscipline: Bool` por `var bypassDiscipline: Bool?`.
- `asStyle()` trata `nil` como `false` (modo refinador).
- Sheet trata `nil` como `false` em populate.
- Decisão: **só ativar Plano B se Plano A falhar empiricamente no aceite**. Não pré-otimizar.

**Por que não estabelecer `VersionedSchema` agora:**
- Item conhecido do [cleanup-fase2b1.md item 5](../04-decisoes/cleanup-fase2b1.md#5-achados-secundários-do-code-review-do-branch-informacional). Estabelecer `VersionedSchema` é mudança estrutural que ampliaria escopo da 2b-3 substancialmente.
- Lightweight para Bool com default é o caso mais simples — alta probabilidade de funcionar.
- Se falhar, Plano B é hotfix dentro da própria fase.
- `VersionedSchema` baseline pode entrar como fase técnica isolada futura.

### 4.6 Localizable strings

Novas chaves em `Localizable.strings`:

```
"styles.edit.discipline.toggle"  = "Modo refinador (recomendado)";
"styles.edit.discipline.help"    = "Refinador prefixa proteção contra o LLM responder à fala em vez de transcrever.";
"styles.edit.discipline.warning" = "Modo livre: sem proteção. O LLM pode responder à fala em vez de transcrever.";
```

Sem English — o app é pt-BR-only por convenção do projeto.

### 4.7 Edge cases

| Edge | Comportamento |
|---|---|
| Custom style criado na 2b-2 (sem o campo) abre na 2b-3 | Lightweight migration preenche `false` → toggle na sheet vem como "modo refinador" ON, comportamento idêntico ao anterior. |
| User cria style em modo livre + code-switching ON | `asStyle()` retorna `systemPrompt + codeSwitchingClause`, sem `rewriterDiscipline`. Modos ortogonais. |
| User troca pra livre, salva, volta pra refinador, salva | Toggle alterna; `update()` persiste; reload reflete. |
| User edita mesma sheet várias vezes alternando | Sem state corrompido — toggle é `@State` re-populado em cada `onAppear`. |
| Default style do app (`BuiltInStyles.defaultStyleID`) | Built-in, não é `CustomStyle`. Mudança não afeta. |

---

## 5. Testes

Suíte alvo: ~157 testes (de 145 + ~12 novos).

### 5.1 Testes do item 1 (cancel HTTP) — em `PipelineCoordinatorTests.swift`

| Teste | Cenário |
|---|---|
| `test_cancel_during_refining_cancels_url_session` | Refiner mock que faz `try await Task.sleep` longo + lança `RefinerError.cancelled` quando cancelado. Cancel via `.cancel` event → assert `state == .idle`, refiner foi efetivamente cancelado (não retornou texto). |
| `test_cancel_during_processing_aborts_before_refine` | Transcriber mock com sleep + retorna; cancel ANTES de refine ser chamado → assert `refiner.refineCallCount == 0`. |
| `test_cancel_during_refining_does_not_inject` | Cancel durante refine → `injector.injectCallCount == 0`. |
| `test_cancel_during_refining_does_not_save_history` | Same → `historyStore.saveCallCount == 0`. |
| `test_network_drop_without_user_cancel_falls_back` | Refiner lança `RefinerError.cancelled` SEM evento Esc → fallback Identity acionado, evento `refinerFellBack(.networkOffline)` emitido, inject acontece com texto cru. (Regression do `99d174e`.) |
| `test_pipelineTask_cleared_after_completion` | Após `runTranscribeAndInject` terminar (sucesso ou cancel), `pipelineTask` volta a `nil`. (Verificável via método helper de teste no actor.) |

### 5.2 Testes do item 2 (modo livre) — em `CustomStyleTests.swift` + `CustomStyleStoreLiveTests.swift`

| Teste | Cenário |
|---|---|
| `test_asStyle_refiner_mode_prefixes_discipline` | `bypassDiscipline = false` → `Style.systemPrompt` começa com `CustomStyle.rewriterDiscipline`. |
| `test_asStyle_free_mode_omits_discipline` | `bypassDiscipline = true` → `Style.systemPrompt` é exatamente o `systemPrompt` do user (+ code-switching opcional). |
| `test_asStyle_free_mode_with_codeswitching` | `bypassDiscipline = true && appendCodeSwitching = true` → prompt = `systemPrompt + codeSwitchingClause`, sem discipline. |
| `test_existing_init_defaults_to_refiner_mode` | `CustomStyle(name:, systemPrompt:, appendCodeSwitching:)` (init sem o novo param) → `bypassDiscipline == false`. |
| `test_store_create_with_bypassDiscipline_persists` | `customStore.create(... bypassDiscipline: true)` → reload, valor persistido. |
| `test_store_update_toggles_bypassDiscipline` | Cria com `false`, update pra `true`, reload → valor atualizado. |

---

## 6. Aceite manual

Checklist em `tagarela_docs/03-funcionalidades/checklists/fase2b3-manual.md`. Estrutura — 8 blocos em condução tradicional bloco-a-bloco.

### Bloco 1 — Cancel HTTP (OpenAI)

**Setup:** backend OpenAI, key válida, modelo `gpt-5.4-mini`.

1. Hotkey, fala "isso é um teste muito longo de cancelamento que deve ser interrompido", solta hotkey.
2. Durante `.refining` (pill amarelo) aperta Esc.

**Esperado:** state vai pra idle dentro de < 200ms, **nada injetado**, request da API terminou abortado. Verificável por timing entre Esc e idle e por ausência de cobrança no dashboard OpenAI da request.

**Edge:** Esc 100ms após começar refine — assert idle limpo, sem race.

### Bloco 2 — Cancel HTTP (Ollama)

**Setup:** backend Ollama local, modelo grande (`gemma2:e9b` ou similar), `ollama serve` rodando.

1. Hotkey, frase técnica longa, solta.
2. Durante `.refining`, `nvidia-smi -l 1` ou Activity Monitor monitorando GPU/CPU.
3. Esc.

**Esperado:** Ollama-side: GPU/CPU caindo dentro de ~1s (request abortado). Ollama process não fica em loop processando.

### Bloco 3 — Cancel durante transcribe (whisper)

1. Frase longa (10s+), Esc durante `.processing` (não chega em `.refining`).

**Esperado:** idle limpo, sem inject. Whisper pode completar fisicamente — não é falha do bloco; o critério é não-injeção e UI limpa.

### Bloco 4 — Network-drop sem cancel (regression `99d174e`)

**Setup:** backend Ollama.

1. Capturar frase, durante refine `pkill ollama` (sem apertar Esc).

**Esperado:** toast "Refiner falhou — usando texto bruto" + texto cru injetado. (Garante que `99d174e` segue valendo após o refactor.)

### Bloco 5 — Modo refinador (default)

1. Criar custom style novo na sheet, deixar toggle "Modo refinador" default ON. Salvar.
2. Selecionar o style.
3. Ditar uma pergunta literal: "qual a capital da França".

**Esperado:** custom style transcreve a pergunta ("qual a capital da França" ou similar), **não** responde "Paris".

### Bloco 6 — Modo livre

1. Editar mesmo style do bloco 5, desligar toggle "Modo refinador" → modo livre.
2. Verificar que warning laranja com triângulo aparece inline embaixo do toggle.
3. Salvar.
4. Ditar mesma pergunta "qual a capital da França".

**Esperado:** custom style agora pode responder "Paris" (LLM livre, sem proteção). Confirma que toggle muda comportamento real.

### Bloco 7 — Migration de styles existentes

**Setup:** ANTES do build novo, criar pelo menos 1 custom style na 2b-2 (build atual em `~/Applications/Tagarela.app`). Confirmar que o store já existe em `~/Library/Application Support/com.tagarela.Tagarela/`.

1. Build novo da 2b-3, instalar via reciclo padrão (`pkill -f Tagarela.app && rm -rf ~/Applications/Tagarela.app && cp -R …`).
2. Abrir app → Preferências → Estilos → editar style criado na 2b-2.

**Esperado:** style abre normal, toggle vem em "Modo refinador" ON, sem warning. Comportamento de transcrição idêntico ao anterior. Sem crash de SwiftData migration.

**Se quebrar:** ativar Plano B (campo `Bool?` opcional).

### Bloco 8 — Persistência do toggle

1. Marcar style em livre, salvar.
2. Fechar Preferências, reabrir.
3. Editar mesmo style.

**Esperado:** toggle vem em livre, warning visível.

### Convenções do aceite

- Build em Release + instalar em `~/Applications/Tagarela.app` (não rodar do Xcode). Ver [memory: ambiente_macos](file:///Users/tars/.claude/projects/-Users-tars-Dev-tagarela/memory/ambiente_macos.md).
- Condução bloco-a-bloco, marcando `[x]` conforme passa. Ver [memory: workflow_aceite_manual](file:///Users/tars/.claude/projects/-Users-tars-Dev-tagarela/memory/workflow_aceite_manual.md).
- Achados que não bloqueiam viram `tagarela_docs/04-decisoes/cleanup-fase2b3.md` ao fim.

---

## 7. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| SwiftData lightweight migration não preencher `false` em rows antigos → crash ao abrir store existente | Aceite manual Bloco 7 valida com store real. Se quebrar, hotfix Plano B (campo `Bool?` opcional) dentro da própria fase. |
| WhisperKit não honrar `Task.cancel()` → transcribe continua até completar | Aceitável: best-effort declarado. Checkpoint pós-transcribe (`if aborted()`) impede progressão. Cancel HTTP do refiner é o ganho principal e está garantido. |
| Cancel durante `audio.stop()` (transição) | Não-issue: `handleCancel` em `.recording` segue caminho separado, não toca `pipelineTask`. |
| `pipelineTask?.cancel()` em Task já completada | No-op seguro. Cleanup `pipelineTask = nil` previne reuso da referência. |
| User em modo livre ainda tem `appendCodeSwitching` apenso → confusão sobre o que é prefixado | Aceitável: code-switching é assist técnico (preserva inglês), não proteção contra desvio do LLM. Modos ortogonais. Caption + warning explicam. |
| User cria custom style "tipo chat" em modo livre e usa como ditado por engano | Warning persistente na sheet é o sinal. Sem badge no card por decisão F2b3-6. Se virar dor real no aceite, abrir débito pra v2 (badge). |
| Race entre `cancelled = true` e `RefinerError` retornando antes do cancel se propagar | Coberto pela ordem em `handleCancel`: flag setada ANTES de `pipelineTask?.cancel()`. Cenário coberto pelo teste `test_network_drop_without_user_cancel_falls_back`. |
| `actor` re-entrancy: `handleCancel` rodando enquanto `runTranscribeAndInject` está num await | Actors serializam métodos isolados; flag `cancelled` é setada atomicamente do ponto de vista do actor. Cancel da Task é externo (não isolated), funciona via `URLSession`. |
| Sheet cresce com warning condicional → clipping em altura fixa | Ajustar `.frame(... height: 460)` ou trocar pra sizing dinâmico. Decisão na implementação. |

---

## 8. Plano de execução

Plan companion em `tagarela_docs/specs/2026-04-30-tagarela-v1-fase2b3-plan.md` (gerado via skill `superpowers:writing-plans` após approval deste design).

Ordem proposta de tarefas (alta granularidade):

1. **Item 1 estrutural** — `pipelineTask` armazenada + `aborted()` helper + `handleCancel` propaga `Task.cancel()`.
2. **Item 1 testes** — 6 testes novos em `PipelineCoordinatorTests`.
3. **Item 2 model** — `bypassDiscipline` no `@Model CustomStyle` + `asStyle()` condicional.
4. **Item 2 store** — `CustomStyleStore.create(...)` ganha param; Live + Noop atualizados.
5. **Item 2 testes model+store** — 6 testes novos.
6. **Item 2 sheet** — Toggle + caption + warning + populate/save.
7. **Localizable** — 3 chaves novas + verificação visual.
8. **Aceite manual** — checklist em `fase2b3-manual.md`, condução bloco-a-bloco.
9. **Cleanups e doc updates** — fechar itens nos `cleanup-fase2a.md` e `cleanup-fase2b1.md`; atualizar `tagarela_docs/02-arquitetura/05-modulos-fase2b3.md` (snapshot novo); atualizar `tagarela_docs/README.md`.

---

## 9. Cleanups esperados pós-fase

Após aceite manual ✅:

- **`cleanup-fase2a.md` item 5** → fechado (cancel HTTP via `Task.cancel()` implementado).
- **`cleanup-fase2b1.md` item 2 (follow-up)** → fechado (UX modo refinador/livre implementada).
- **`cleanup-fase2b1.md` item 4** → fechado (mesmo item que cleanup-fase2a.md #5).
- **Novo `cleanup-fase2b3.md`** → criado se aceite levantar achados secundários.

Ao fim da 2b-3, toda a Fase 2b está fechada. Próxima fase grande: ainda em discussão — possivelmente onboarding novo, re-bind de hotkey, ou tuning fino de built-ins.
