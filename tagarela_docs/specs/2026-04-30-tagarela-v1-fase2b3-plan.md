---
data: 2026-04-30
status: planejado
fase: 2b-3 de 3 sub-fases da Fase 2b
goal: cancel HTTP em vôo + UX modo refinador/livre pros custom styles
implementado_em: pendente
---

# tagarela v1 — Fase 2b-3: Implementation Plan

> **Para agentes de execução:** SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendado) ou `superpowers:executing-plans`. Tarefas usam checkbox (`- [ ]`).
>
> **Antes de qualquer tarefa:** ler [`/CLAUDE.md`](../../CLAUDE.md), [`tagarela_docs/specs/2026-04-30-tagarela-v1-fase2b3-design.md`](./2026-04-30-tagarela-v1-fase2b3-design.md), [`tagarela_docs/04-decisoes/cleanup-fase2a.md`](../04-decisoes/cleanup-fase2a.md) (item #5 que esta fase fecha) e [`tagarela_docs/04-decisoes/cleanup-fase2b1.md`](../04-decisoes/cleanup-fase2b1.md) (itens #2 follow-up e #4 que esta fase fecha). **Antes de marcar uma tarefa como concluída:** atualizar a doc afetada (regra inviolável 2 do CLAUDE.md).

**Goal:** Fechar dois débitos técnicos da Fase 2b-1/2a — (1) Esc durante refiner aborta de verdade o request HTTP em vôo via `Task.cancel()` envolvendo `runTranscribeAndInject`; (2) custom styles ganham toggle "Modo refinador" (default ON) na sheet de edição, com warning inline laranja quando livre.

**Architecture:** Sobre a 2b-2, mudanças cirúrgicas em arquivos existentes — sem novos módulos. (a) `PipelineCoordinator` armazena `pipelineTask: Task<Void, Never>?`; `handleToggle` em `.recording` envolve a chamada de `runTranscribeAndInject` na Task; `handleCancel` em `.processing/.refining` chama `pipelineTask?.cancel()` + mantém `cancelled = true`; novo helper `aborted() -> Bool` substitui as 3 checagens existentes de `if cancelled`. URLSession honra `Task.cancel()` nativamente; lógica `RefinerError.cancelled where cancelled` (commit `99d174e`) preservada intacta. (b) `@Model CustomStyle` ganha campo `bypassDiscipline: Bool` (default `false`); `asStyle()` consulta o campo pra decidir o prefixo de `rewriterDiscipline`; `CustomStyleStore.create(...)` ganha o parâmetro novo (sem default no protocol — call sites passam explícito); `CustomStyleEditSheet` ganha Toggle "Modo refinador" + caption + warning inline condicional.

**Tech stack:** mesmo da 2b-2 — Swift 5.10, SwiftUI, SwiftData, AppKit cirúrgico, URLSession, XCTest. Sem novas SPMs.

**Não está nesta fase:** tuning fino dos prompts dos built-in styles (excluído pelo user); onboarding novo, re-bind real da hotkey, captura L/R Option (fora de toda a Fase 2b); badge "LIVRE" no card da grid `StylesView` (decidido warning-só-na-sheet); cancel granular dentro do WhisperKit (best-effort apenas); `VersionedSchema` baseline pro SwiftData (segue como follow-up). Ver [`fase2b3-design.md` §1.3](./2026-04-30-tagarela-v1-fase2b3-design.md#13-não-objetivos-da-2b-3).

---

## File structure desta fase

Apenas modificações sobre a 2b-2 (raiz `app/Tagarela/`):

```
app/Tagarela/
├── Pipeline/
│   └── PipelineCoordinator.swift           # MODIFICAR — pipelineTask + aborted() + handleCancel propaga Task.cancel()
├── Refiner/
│   ├── CustomStyle.swift                    # MODIFICAR — campo bypassDiscipline + asStyle condicional
│   ├── CustomStyleStore.swift               # MODIFICAR — protocol create(...) ganha bypassDiscipline
│   ├── CustomStyleStoreLive.swift           # MODIFICAR — implementação propaga bypassDiscipline
│   └── CustomStyleStoreNoop.swift           # MODIFICAR — assinatura nova (no-op continua)
├── Preferences/UI/Sheets/
│   └── CustomStyleEditSheet.swift           # MODIFICAR — Toggle + warning inline + populate/save
└── Localization/pt-BR.lproj/
    └── Localizable.strings                  # MODIFICAR — 3 chaves novas styles.edit.discipline.*

app/TagarelaTests/
├── PipelineCoordinatorTests.swift           # MODIFICAR — +5 testes (cancel HTTP + cleared) + FakeRefinerSlow helper
├── CustomStyleTests.swift                   # MODIFICAR — +3 testes de modo livre
├── CustomStyleStoreTests.swift              # MODIFICAR — +2 testes bypassDiscipline persiste
└── LocalizableKeysTests.swift               # MODIFICAR — +3 chaves no smoke
```

Documentação atualizada por esta fase em `tagarela_docs/`:
- `02-arquitetura/05-modulos-fase2b3.md` (criar) — snapshot pós-2b-3.
- `03-funcionalidades/checklists/fase2b3-manual.md` (criar) — checklist manual com 8 blocos.
- `04-decisoes/cleanup-fase2a.md` (atualizar) — fechar item #5.
- `04-decisoes/cleanup-fase2b1.md` (atualizar) — fechar item #2 follow-up + item #4.
- `04-decisoes/cleanup-fase2b3.md` (criar se aceite levantar achados).
- `README.md` — ajustar status da 2b-3 quando fechar.

---

## Convenções desta fase

Mesmas da 2b-1/2b-2:

- **Idioma:** strings de UI em `Localizable.strings` (pt-BR base). Identificadores Swift em inglês.
- **Concorrência:** `actor PipelineCoordinator` mantém isolamento existente; `pipelineTask` é mutável dentro do actor.
- **Erros:** `RefinerError`, `CustomStyleStoreError` existentes — sem novos enums.
- **Logging:** `Logger(subsystem: "com.tagarela", category: "Pipeline")` já existe no `PipelineCoordinator`. Manter.
- **TDD:** lógica → teste primeiro. UI/SwiftUI → preview + checklist manual.
- **Commits:** um commit por tarefa (ou alguns commits relacionados), em pt-BR no estilo `tipo(escopo): descrição` + co-author Claude.
- **xcodegen é fonte da verdade do projeto Xcode.** Esta fase **não cria** arquivos novos no app target — só nos docs. Não precisa rodar `xcodegen generate`.

---

## Pre-flight (antes da Tarefa 1)

- [ ] **Confirmar `main` está limpo e em verde.**

```bash
cd /Users/tars/Dev/tagarela
git status                                      # working tree clean (workspace.json Obsidian é OK ficar M)
git log -1 --oneline                            # último: 44ce96a docs: design da Fase 2b-3
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: `** TEST SUCCEEDED **`, 145 testes passando.

- [ ] **Criar branch de trabalho.**

```bash
cd /Users/tars/Dev/tagarela
git checkout -b fase-2b3
```

- [ ] **Ollama rodando localmente** (necessário pro aceite manual final).

```bash
curl -sf http://localhost:11434/api/tags | head -c 200
ollama list | grep -E "gemma4:e4b|gemma2|llama3" | head -3
```

- [ ] **Confirmar store SwiftData existente** (necessário pra Bloco 7 do aceite — migration de styles).

```bash
ls -la "$HOME/Library/Application Support/com.tagarela.Tagarela/" | grep -i store
```

Esperado: pelo menos 1 arquivo `*.store` (criado durante uso da 2b-1/2b-2). Se não tiver, criar 1 custom style na 2b-2 instalada antes de começar.

---

## Tarefa 1: `PipelineCoordinator` — `pipelineTask` armazenada + `aborted()` helper + cancel propaga

Objetivo: envolver `runTranscribeAndInject` em Task armazenada cancelável. URLSession honra cancellation; cancel via Esc passa a abortar HTTP em vôo. Helper `aborted()` agrega `cancelled || Task.isCancelled`.

**Files:**
- Modify: `app/Tagarela/Pipeline/PipelineCoordinator.swift`
- Modify: `app/TagarelaTests/PipelineCoordinatorTests.swift`

- [ ] **Step 1: Adicionar helper `FakeRefinerSlow` em `PipelineCoordinatorTests.swift`**

`FakeRefinerSlow` espera 1s antes de retornar; honra cooperative cancellation. Com isso, podemos testar que `Task.cancel()` se propaga até o refiner. Adicionar no fim do arquivo, junto com os outros fakes (após `FakeHistoryStore`):

```swift
private final class FakeRefinerSlow: TextRefiner, @unchecked Sendable {
    let kind: RefinerKind
    /// Sinaliza que o sleep foi interrompido por cancellation cooperativa.
    /// Lê via @MainActor wrapper pra atravessar boundary do actor pipeline.
    let cancelledBox = ActorBool()

    init(kind: RefinerKind = .openai) { self.kind = kind }

    func refine(_ raw: String, style: Style) async throws -> String {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            return "refined"
        } catch is CancellationError {
            await cancelledBox.set(true)
            throw RefinerError.cancelled
        }
    }
}
```

(`ActorBool` já existe no arquivo — vide top do arquivo, definido linha ~225.)

- [ ] **Step 2: Escrever teste `test_cancelDuringRefining_cancelsRefinerTask`**

Adicionar no `PipelineCoordinatorTests` (perto dos outros testes de cancel):

```swift
func test_cancelDuringRefining_cancelsRefinerTask() async {
    // Refiner lento + cooperative cancel: a única forma do
    // wasCancelled virar true é se Task.cancel() se propagar
    // até o sleep do refiner. Hoje (sem pipelineTask), não propaga.
    let slow = FakeRefinerSlow(kind: .openai)
    let p = makeCoordinator(refiner: slow)
    await p.handle(.toggle)
    await p.handle(.toggle)
    // dar 100ms pra entrar em .refining
    try? await Task.sleep(nanoseconds: 100_000_000)
    await p.handle(.cancel)
    // dar 100ms pro cancellation se propagar e estado ir pra idle
    try? await Task.sleep(nanoseconds: 200_000_000)
    let s = await p.state
    XCTAssertEqual(s, .idle)
    let wasCancelled = await slow.cancelledBox.get()
    XCTAssertTrue(wasCancelled,
                  "Task.cancel() deve propagar até o refiner.refine sleep")
}
```

- [ ] **Step 3: Rodar teste — esperar FAIL**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test \
  -only-testing:TagarelaTests/PipelineCoordinatorTests/test_cancelDuringRefining_cancelsRefinerTask \
  2>&1 | tail -20
```

Esperado: teste falha. Mensagem similar a `XCTAssertTrue failed - Task.cancel() deve propagar...`. Razão: hoje `runTranscribeAndInject` não roda numa Task armazenada; `Esc` apenas seta `cancelled = true`, e `await session.data(for:)` (ou `Task.sleep` no fake) continua até completar.

- [ ] **Step 4: Implementar refactor — `pipelineTask` armazenada + `aborted()` helper**

Modificar `app/Tagarela/Pipeline/PipelineCoordinator.swift`:

**4a.** Adicionar campo após `private var cancelled = false` (linha ~27):

```swift
/// Task que envolve `runTranscribeAndInject` durante .processing/.refining.
/// `handleCancel` chama `cancel()` aqui pra abortar URLSession em vôo
/// (URLSession honra Task cancellation nativamente). Lazy: só populada
/// na transição .recording → .processing.
/// `internal private(set)` pra permitir verificação em tests via @testable.
internal private(set) var pipelineTask: Task<Void, Never>?
```

**4b.** Adicionar helper privado (junto com os outros métodos privados, antes de `runTranscribeAndInject`):

```swift
/// Agrega user-cancel via flag (Esc durante .processing/.refining) e
/// cancellation cooperativa da Task (Task.cancel() propagado externamente).
/// Substitui as checagens isoladas de `if cancelled` nos checkpoints
/// internos do `runTranscribeAndInject`.
private func aborted() -> Bool {
    cancelled || Task.isCancelled
}
```

**4c.** Modificar `handleToggle` no caso `.recording` (linha ~92):

```swift
case .recording:
    cancelRecordingTasks()
    pipelineTask = Task { [weak self] in
        await self?.runTranscribeAndInject()
        await self?.clearPipelineTask()
    }
```

**4d.** Adicionar método `clearPipelineTask` (privado, isolated do actor):

```swift
private func clearPipelineTask() {
    pipelineTask = nil
}
```

**4e.** Modificar `handleCancel` no caso `.processing, .refining` (linha ~108):

```swift
case .processing, .refining:
    // Sinaliza cancel pra runTranscribeAndInject (via flag — checkpoints
    // pós-await) E propaga Task.cancel() pra abortar URLSession em vôo.
    // URLSession honra cancellation nativamente; WhisperKit é best-effort.
    // A flag `cancelled` é setada ANTES do cancel() pra que, quando
    // RefinerError.cancelled chegar no catch do refine, o `where cancelled`
    // case (PipelineCoordinator.swift:184-205) distinga user-cancel real
    // de network-drop disfarçado (commit 99d174e).
    cancelled = true
    pipelineTask?.cancel()
    setState(.idle)
```

**4f.** Substituir as 3 ocorrências de `if cancelled` no `runTranscribeAndInject` por `if aborted()`:

- Linha ~168: `if cancelled { logger.info("cancelled after transcribe"); setState(.idle); return }` → `if aborted() { logger.info("cancelled after transcribe"); setState(.idle); return }`
- Linha ~214: `if cancelled { logger.info("cancelled after refine"); setState(.idle); return }` → `if aborted() { logger.info("cancelled after refine"); setState(.idle); return }`
- Linha ~229: `if cancelled { logger.info("cancelled after inject"); setState(.idle); return }` → `if aborted() { logger.info("cancelled after inject"); setState(.idle); return }`

**4g.** **Não mexer** no bloco `catch RefinerError.cancelled where cancelled` (linha ~184). A lógica de distinção user-cancel vs network-drop depende da flag `cancelled` ainda existir.

- [ ] **Step 5: Rodar o teste de novo — esperar PASS**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test \
  -only-testing:TagarelaTests/PipelineCoordinatorTests/test_cancelDuringRefining_cancelsRefinerTask \
  2>&1 | tail -20
```

Esperado: PASS.

- [ ] **Step 6: Rodar suíte completa pra confirmar que regressões não foram introduzidas**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -20
```

Esperado: `** TEST SUCCEEDED **`, **146 testes** passando (145 + 1 novo).

Atenção especial: `test_cancelledError_withoutUserCancelFlag_treatedAsNetworkDrop` (linha ~40 do PipelineCoordinatorTests.swift) deve continuar verde — isso é a regression do fix `99d174e` que preservamos.

- [ ] **Step 7: Commit**

```bash
git add app/Tagarela/Pipeline/PipelineCoordinator.swift app/TagarelaTests/PipelineCoordinatorTests.swift
git commit -m "$(cat <<'EOF'
feat(pipeline): cancel HTTP em vôo via Task.cancel() armazenada

PipelineCoordinator agora envolve runTranscribeAndInject numa
pipelineTask armazenada. handleCancel em .processing/.refining
chama pipelineTask?.cancel() além de setar a flag cancelled.

URLSession honra Task cancellation nativamente — Esc durante
refine remoto aborta o request HTTP em vôo. WhisperKit é
best-effort: se honrar Task.isCancelled, transcribe aborta junto;
se não, checkpoint pós-transcribe (via novo helper aborted())
impede progressão.

Lógica de RefinerError.cancelled where cancelled (commit 99d174e,
distinguindo user-cancel real de network-drop disfarçado) preservada
intacta — flag cancelled continua existindo paralela ao Task.isCancelled.

+1 teste (FakeRefinerSlow + test_cancelDuringRefining_cancelsRefinerTask).
Suíte 145 → 146.

Closes cleanup #5 da Fase 2a (parcial — falta aceite manual).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: Testes adicionais do cancel HTTP

Objetivo: cobrir os checkpoints de cancel restantes e garantir que `pipelineTask` é limpo após completion.

**Files:**
- Modify: `app/TagarelaTests/PipelineCoordinatorTests.swift`

**Nota de ordem:** o teste do Step 1 referencia `FakeTranscriberSlow` e `CountingRefiner`/`ActorInt` que ainda não existem. Os helpers entram no Step 2. Ao rodar o passo a passo, a build vai falhar até Step 2 ser feito — Step 6 é o ponto onde tudo deve estar verde. Isso é deliberado: TDD escreve teste primeiro, mesmo que a fixtura precise ser preparada em paralelo.

- [ ] **Step 1: Adicionar `test_cancelDuringProcessing_doesNotCallRefiner`**

```swift
func test_cancelDuringProcessing_doesNotCallRefiner() async {
    // FakeTranscriber atual retorna instantâneo, então cancel ANTES de
    // entrar em refine é difícil de programar deterministicamente.
    // Estratégia: refiner que conta calls; cancel logo após toggle final;
    // dar pouco tempo (50ms) — se o cancel chega antes do refine ser
    // chamado, count == 0. Se chega depois, conta 1 (test fica flaky).
    // Pra garantir: usar transcriber lento.
    let slowTranscriber = FakeTranscriberSlow()
    let counted = CountingRefiner(kind: .openai)
    let p = PipelineCoordinator(
        audio: FakeAudio(),
        transcriber: slowTranscriber,
        refinerProvider: { @MainActor in (counted, BuiltInStyles.conversaInformal) },
        injector: FakeInjector(),
        historyStore: FakeHistoryStore(),
        historyMaxItemsProvider: { @MainActor in 100 },
        historyMaxDaysProvider: { @MainActor in 30 },
        llmModelNameProvider: { @MainActor _ in nil },
        whisperModelNameProvider: { "fake" }
    )
    await p.handle(.toggle)
    await p.handle(.toggle)
    // Em .processing — cancel antes do transcribe completar
    try? await Task.sleep(nanoseconds: 100_000_000)
    await p.handle(.cancel)
    try? await Task.sleep(nanoseconds: 1_500_000_000) // > slow transcribe
    let count = await counted.callCount.get()
    XCTAssertEqual(count, 0,
                   "refiner não deve ser chamado quando cancel ocorre em .processing")
}
```

- [ ] **Step 2: Adicionar helpers `FakeTranscriberSlow` e `CountingRefiner`**

No fim do arquivo, após `FakeRefinerSlow`:

```swift
private final class FakeTranscriberSlow: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String, initialPrompt: String?) async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        return "olá mundo"
    }
}

actor ActorInt {
    private var v: Int = 0
    func inc() { v += 1 }
    func get() -> Int { v }
}

private final class CountingRefiner: TextRefiner, @unchecked Sendable {
    let kind: RefinerKind
    let callCount = ActorInt()
    init(kind: RefinerKind) { self.kind = kind }
    func refine(_ raw: String, style: Style) async throws -> String {
        await callCount.inc()
        return "refined"
    }
}
```

- [ ] **Step 3: Adicionar `test_cancelDuringRefining_doesNotInject`**

```swift
func test_cancelDuringRefining_doesNotInject() async {
    let slow = FakeRefinerSlow(kind: .openai)
    let injector = FakeInjector()
    let p = makeCoordinator(refiner: slow, injector: injector)
    await p.handle(.toggle)
    await p.handle(.toggle)
    try? await Task.sleep(nanoseconds: 100_000_000)
    await p.handle(.cancel)
    try? await Task.sleep(nanoseconds: 200_000_000)
    XCTAssertNil(injector.injected,
                 "inject não deve acontecer quando cancel ocorre em .refining")
}
```

- [ ] **Step 4: Adicionar `test_cancelDuringRefining_doesNotSaveHistory`**

```swift
func test_cancelDuringRefining_doesNotSaveHistory() async {
    let slow = FakeRefinerSlow(kind: .openai)
    let history = FakeHistoryStore()
    let p = makeCoordinator(refiner: slow, history: history)
    await p.handle(.toggle)
    await p.handle(.toggle)
    try? await Task.sleep(nanoseconds: 100_000_000)
    await p.handle(.cancel)
    try? await Task.sleep(nanoseconds: 200_000_000)
    XCTAssertEqual(history.saved.count, 0,
                   "history não deve ser salvo quando cancel ocorre em .refining")
}
```

- [ ] **Step 5: Adicionar `test_pipelineTask_clearedAfterCompletion`**

```swift
func test_pipelineTask_clearedAfterCompletion() async {
    let p = makeCoordinator(refiner: IdentityRefiner())
    await p.handle(.toggle)  // → recording
    await p.handle(.toggle)  // → processing → idle (Identity passa direto)
    try? await Task.sleep(nanoseconds: 200_000_000)
    let taskHandle = await p.pipelineTask
    XCTAssertNil(taskHandle,
                 "pipelineTask deve ser limpo após runTranscribeAndInject completar")
}
```

(O field `pipelineTask` é `internal private(set)` por design — acessível em tests via `@testable import Tagarela`.)

- [ ] **Step 6: Rodar suíte completa**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -20
```

Esperado: `** TEST SUCCEEDED **`, **150 testes** passando (146 + 4 novos).

Nota sobre cobertura: o spec listava 6 testes pro item 1; um deles (`test_network_drop_without_user_cancel_falls_back`) **já existe** no arquivo como `test_cancelledError_withoutUserCancelFlag_treatedAsNetworkDrop` (linha ~40), portanto não duplicamos. Total real desta fase pro item 1: 5 testes novos (1 da Tarefa 1 + 4 desta tarefa).

- [ ] **Step 7: Commit**

```bash
git add app/TagarelaTests/PipelineCoordinatorTests.swift
git commit -m "$(cat <<'EOF'
test(pipeline): cobertura adicional do cancel HTTP em vôo

+4 testes em PipelineCoordinatorTests + helpers (FakeTranscriberSlow,
CountingRefiner, ActorInt):

- cancelDuringProcessing_doesNotCallRefiner — refiner não é
  invocado se cancel ocorre antes do transcribe completar.
- cancelDuringRefining_doesNotInject — inject não acontece em
  cancel pendente.
- cancelDuringRefining_doesNotSaveHistory — save não acontece.
- pipelineTask_clearedAfterCompletion — handle volta a nil após
  runTranscribeAndInject completar (sucesso ou cancel).

Suíte 146 → 150.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: `CustomStyle` model — campo `bypassDiscipline` + `asStyle()` condicional

Objetivo: model ganha o novo campo (default false → mantém comportamento atual). `asStyle()` consulta o campo pra decidir se prefixa `rewriterDiscipline`.

**Files:**
- Modify: `app/Tagarela/Refiner/CustomStyle.swift`
- Modify: `app/TagarelaTests/CustomStyleTests.swift`

- [ ] **Step 1: Escrever testes novos em `CustomStyleTests.swift`**

Adicionar antes do fechamento da classe:

```swift
func test_init_bypassDisciplineDefaultsToFalse() {
    let s = CustomStyle(name: "x", systemPrompt: "y", appendCodeSwitching: false)
    XCTAssertFalse(s.bypassDiscipline,
                   "Init padrão (sem o novo param) deve manter bypassDiscipline=false (modo refinador)")
}

func test_asStyle_freeMode_omitsDiscipline() {
    let s = CustomStyle(name: "x",
                         systemPrompt: "Reescreva como mensagem de commit.",
                         appendCodeSwitching: false,
                         bypassDiscipline: true)
    let prompt = s.asStyle().systemPrompt
    XCTAssertFalse(prompt.contains("NÃO responda"),
                   "Modo livre não deve prefixar rewriterDiscipline")
    XCTAssertEqual(prompt, "Reescreva como mensagem de commit.",
                   "Modo livre + sem code-switching = systemPrompt puro")
}

func test_asStyle_freeMode_withCodeSwitching_appendsClause() {
    let s = CustomStyle(name: "x",
                         systemPrompt: "Reescreva.",
                         appendCodeSwitching: true,
                         bypassDiscipline: true)
    let prompt = s.asStyle().systemPrompt
    XCTAssertFalse(prompt.contains("NÃO responda"),
                   "Modo livre + code-switching: ainda sem rewriterDiscipline")
    XCTAssertTrue(prompt.contains("Reescreva."),
                  "Modo livre: systemPrompt do user vem inteiro")
    XCTAssertTrue(prompt.contains("termos técnicos"),
                  "code-switching clause anexada normalmente")
}
```

- [ ] **Step 2: Rodar — esperar FAIL de compilação**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -20
```

Esperado: erro de compilação `Extra argument 'bypassDiscipline' in call` ou `Value of type 'CustomStyle' has no member 'bypassDiscipline'`.

- [ ] **Step 3: Modificar `CustomStyle.swift` — adicionar campo + atualizar init + atualizar `asStyle()`**

Substituir o conteúdo do arquivo por:

```swift
import Foundation
import SwiftData

@Model
final class CustomStyle {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemPrompt: String
    var appendCodeSwitching: Bool
    /// Quando `true`, `asStyle()` NÃO prefixa `rewriterDiscipline` —
    /// o systemPrompt do user vai puro pro LLM. Default `false` (modo
    /// refinador, comportamento da Fase 2b-1). Modo livre é raro mas
    /// existe quando o user quer que o LLM faça mais que reescrever
    /// (ex: responder à fala). Decidido na Fase 2b-3, ver
    /// tagarela_docs/specs/2026-04-30-tagarela-v1-fase2b3-design.md.
    var bypassDiscipline: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         name: String,
         systemPrompt: String,
         appendCodeSwitching: Bool,
         bypassDiscipline: Bool = false,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.appendCodeSwitching = appendCodeSwitching
        self.bypassDiscipline = bypassDiscipline
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Cláusula obrigatória prefixada em custom styles em **modo refinador**
    /// (default). Built-ins têm proteção equivalente embutida em seus prompts
    /// ("Você refina ditados de voz... Não adicione informação que não estava
    /// no original"). Sem isso, custom styles se comportam como chat assistant:
    /// o LLM trata o input como pergunta e responde, em vez de reescrever.
    /// Bug 12.2 do aceite manual da Fase 2b-1.
    ///
    /// Em **modo livre** (`bypassDiscipline = true`), o user é dono total do
    /// prompt — sem proteção. Decidido na Fase 2b-3.
    static let rewriterDiscipline = """
    Você é um pós-processador de transcrição de voz em português brasileiro. \
    NÃO responda ao que foi dito; apenas reescreva o ditado seguindo as regras abaixo. \
    NÃO adicione informação além do que foi falado. NÃO faça comentários, perguntas \
    ou interpretações.

    Regras de reescrita:

    """

    /// Converte o `CustomStyle` num `Style` consumível pelo `RefinerFactory`/refiners.
    /// Anexa: (1) `rewriterDiscipline` apenas em modo refinador (`bypassDiscipline=false`),
    /// (2) cláusula de code-switching opcional via toggle (independente do modo).
    func asStyle() -> Style {
        let codeSwitchingClause = """

        Preserve termos técnicos em inglês conforme o uso comum em desenvolvimento de software brasileiro \
        (ex: cloud, deploy, pool, pattern, mutex). Corrija fonetizações óbvias do Whisper \
        (ex: 'loquei' → 'log it', 'diploiei' → 'deployei').
        """
        var prompt = bypassDiscipline ? systemPrompt : (CustomStyle.rewriterDiscipline + systemPrompt)
        if appendCodeSwitching { prompt += codeSwitchingClause }
        return Style(id: id,
                     name: name,
                     systemPrompt: prompt,
                     preserveOrality: false,
                     isBuiltIn: false)
    }
}
```

- [ ] **Step 4: Rodar testes do CustomStyle**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test \
  -only-testing:TagarelaTests/CustomStyleTests \
  2>&1 | tail -20
```

Esperado: todos os testes passam, incluindo:
- `test_asStyle_alwaysPrefixesRewriterDiscipline` (existente — verifica modo refinador default)
- `test_asStyle_withoutCodeSwitching_keepsDisciplinePrefix` (existente — modo refinador)
- `test_init_bypassDisciplineDefaultsToFalse` (novo)
- `test_asStyle_freeMode_omitsDiscipline` (novo)
- `test_asStyle_freeMode_withCodeSwitching_appendsClause` (novo)

- [ ] **Step 5: Rodar suíte completa**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -20
```

Esperado: `** TEST SUCCEEDED **`, **153 testes** passando (150 + 3 novos).

Atenção: testes em `CustomStyleStoreTests.swift` continuam verdes porque `CustomStyleStoreLive.create(...)` ainda passa apenas 3 args ao `CustomStyle.init` (o novo param tem default). Tarefa 4 vai mudar isso.

- [ ] **Step 6: Commit**

```bash
git add app/Tagarela/Refiner/CustomStyle.swift app/TagarelaTests/CustomStyleTests.swift
git commit -m "$(cat <<'EOF'
feat(custom-styles): campo bypassDiscipline + asStyle condicional

@Model CustomStyle ganha campo bypassDiscipline:Bool (default false).
asStyle() consulta o campo pra decidir se prefixa rewriterDiscipline:

- bypassDiscipline=false (default, modo refinador): comportamento da
  2b-1 mantido — sempre prefixa.
- bypassDiscipline=true (modo livre): systemPrompt vai puro pro LLM.

Init com default no novo param mantém compat de call sites e migration
SwiftData lightweight (rows antigos lêem como false).

+3 testes em CustomStyleTests. Suíte 150 → 153.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: `CustomStyleStore` — protocol + Live + Noop com `bypassDiscipline`

Objetivo: protocol `create(...)` ganha o parâmetro novo; `Live` propaga pra `CustomStyle.init`; `Noop` adapta a assinatura. Caller existente (`CustomStyleEditSheet`) ajustado pra passar `bypassDiscipline: false` por enquanto — Tarefa 6 troca pelo valor real.

**Files:**
- Modify: `app/Tagarela/Refiner/CustomStyleStore.swift`
- Modify: `app/Tagarela/Refiner/CustomStyleStoreLive.swift`
- Modify: `app/Tagarela/Refiner/CustomStyleStoreNoop.swift`
- Modify: `app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift` (apenas call site)
- Modify: `app/TagarelaTests/CustomStyleStoreTests.swift`

- [ ] **Step 1: Escrever testes novos em `CustomStyleStoreTests.swift`**

Adicionar antes do fechamento da classe:

```swift
func test_create_persistsBypassDiscipline() async throws {
    let store = makeStore(try makeContainer())
    let s = try await store.create(name: "livre",
                                    systemPrompt: "responda livre",
                                    appendCodeSwitching: false,
                                    bypassDiscipline: true)
    XCTAssertTrue(s.bypassDiscipline)
    await store.reload()
    XCTAssertEqual(store.styles.first?.bypassDiscipline, true,
                   "bypassDiscipline deve persistir após reload")
}

func test_update_togglesBypassDiscipline() async throws {
    let store = makeStore(try makeContainer())
    let s = try await store.create(name: "x",
                                    systemPrompt: "y",
                                    appendCodeSwitching: false,
                                    bypassDiscipline: false)
    XCTAssertFalse(s.bypassDiscipline)
    s.bypassDiscipline = true
    try await store.update(s)
    await store.reload()
    XCTAssertEqual(store.styles.first?.bypassDiscipline, true,
                   "update deve persistir bypassDiscipline=true após reload")
}
```

- [ ] **Step 2: Rodar — esperar FAIL de compilação**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -20
```

Esperado: erro de compilação `Extra argument 'bypassDiscipline' in call`.

- [ ] **Step 3: Modificar protocol `CustomStyleStore.swift`**

Substituir a assinatura do `create`:

```swift
import Foundation

@MainActor
protocol CustomStyleStore: AnyObject {
    var styles: [CustomStyle] { get }
    func reload() async
    func create(name: String,
                systemPrompt: String,
                appendCodeSwitching: Bool,
                bypassDiscipline: Bool) async throws -> CustomStyle
    func update(_ style: CustomStyle) async throws
    func delete(_ style: CustomStyle) async throws
}
```

(Sem default no protocol — call sites passam explícito. Decisão F2b3-7 do design §4.3.)

`OnStyleDeleted` typealias e `CustomStyleStoreError` continuam inalterados.

- [ ] **Step 4: Modificar `CustomStyleStoreLive.swift`**

Substituir a função `create`:

```swift
func create(name: String,
            systemPrompt: String,
            appendCodeSwitching: Bool,
            bypassDiscipline: Bool) async throws -> CustomStyle {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { throw CustomStyleStoreError.invalidInput("nome vazio") }
    guard !trimmedPrompt.isEmpty else {
        throw CustomStyleStoreError.invalidInput("system prompt vazio")
    }
    let style = CustomStyle(name: trimmedName,
                             systemPrompt: trimmedPrompt,
                             appendCodeSwitching: appendCodeSwitching,
                             bypassDiscipline: bypassDiscipline)
    context.insert(style)
    do {
        try context.save()
    } catch {
        throw CustomStyleStoreError.persistenceFailed(error)
    }
    await reload()
    return style
}
```

- [ ] **Step 5: Modificar `CustomStyleStoreNoop.swift`**

Substituir o `create`:

```swift
func create(name: String,
            systemPrompt: String,
            appendCodeSwitching: Bool,
            bypassDiscipline: Bool) async throws -> CustomStyle {
    throw CustomStyleStoreError.persistenceFailed(NSError(domain: "noop", code: 0))
}
```

- [ ] **Step 6: Atualizar caller em `CustomStyleEditSheet.swift` — temporário**

Em `save()`, ajustar o `customStore.create(...)` pra passar `bypassDiscipline: false`. Isso mantém build verde até Tarefa 6 introduzir o toggle real:

Trocar:
```swift
case .create:
    _ = try await customStore.create(name: trimmedName,
                                      systemPrompt: trimmedPrompt,
                                      appendCodeSwitching: appendCodeSwitching)
```

Por:
```swift
case .create:
    _ = try await customStore.create(name: trimmedName,
                                      systemPrompt: trimmedPrompt,
                                      appendCodeSwitching: appendCodeSwitching,
                                      bypassDiscipline: false)  // T6 troca pelo @State
```

- [ ] **Step 7: Atualizar testes existentes que chamam `.create(...)` — adicionar `bypassDiscipline: false`**

No `CustomStyleStoreTests.swift`, há 7 chamadas a `.create(...)` em testes existentes que precisam do novo param. Buscar todas:

```bash
grep -n "\.create(name:" app/TagarelaTests/CustomStyleStoreTests.swift
```

Adicionar `bypassDiscipline: false` em cada call site (7 ocorrências, nos testes: `test_create_emptyName_throws`, `test_create_emptyPrompt_throws`, `test_create_persists`, `test_update_changesUpdatedAt`, `test_delete_callsCallbackWithDeletedID`, `test_noop_returnsEmptyAndThrowsOnWrites`, `test_sharedContainer_storesDoNotInterfere`). Cuidado pra não duplicar com os 2 testes novos do Step 1 (que já passam o param).

- [ ] **Step 8: Rodar suíte completa**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -20
```

Esperado: `** TEST SUCCEEDED **`, **155 testes** passando (153 + 2 novos).

- [ ] **Step 9: Commit**

```bash
git add app/Tagarela/Refiner/CustomStyleStore.swift \
        app/Tagarela/Refiner/CustomStyleStoreLive.swift \
        app/Tagarela/Refiner/CustomStyleStoreNoop.swift \
        app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift \
        app/TagarelaTests/CustomStyleStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(custom-styles): protocol/Live/Noop store ganham bypassDiscipline

CustomStyleStore.create(...) ganha parâmetro bypassDiscipline:Bool
sem default no protocol — call sites passam explícito (decisão
F2b3-7 do design 2b-3 §4.3, evita esquecimento silencioso em
caminhos novos).

CustomStyleStoreLive propaga pro CustomStyle.init. Noop adapta
a assinatura (no-op continua throw).

Caller em CustomStyleEditSheet passa false temporariamente —
T6 troca pelo @State do toggle.

+2 testes (create persists / update toggles). Suíte 153 → 155.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: Localizable strings

Objetivo: adicionar 3 chaves novas em `pt-BR.lproj/Localizable.strings` e cobrir no smoke test.

**Files:**
- Modify: `app/Tagarela/Localization/pt-BR.lproj/Localizable.strings`
- Modify: `app/TagarelaTests/LocalizableKeysTests.swift`

- [ ] **Step 1: Adicionar 3 chaves em `Localizable.strings`**

Localizar a seção `// styles.edit.*` (linhas ~155-160) e adicionar logo após `"styles.edit.save.failed"`:

```
"styles.edit.discipline.toggle"  = "Modo refinador (recomendado)";
"styles.edit.discipline.help"    = "Refinador prefixa proteção contra o LLM responder à fala em vez de transcrever.";
"styles.edit.discipline.warning" = "Modo livre: sem proteção. O LLM pode responder à fala em vez de transcrever.";
```

- [ ] **Step 2: Adicionar chaves no smoke test `LocalizableKeysTests.swift`**

Modificar o array `keys` no `test_principalKeys_resolveInPtBR` pra incluir as 3 chaves novas:

```swift
let keys: [String] = [
    "preferences.section.geral",
    "preferences.section.estilos",
    "preferences.refiner.openai.provider.header",
    "preferences.audio.maxgain.label",
    "preferences.shortcuts.toggle",
    "styles.add",
    "common.cancel",
    "common.save",
    "styles.edit.discipline.toggle",
    "styles.edit.discipline.help",
    "styles.edit.discipline.warning",
]
```

- [ ] **Step 3: Rodar suíte**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -20
```

Esperado: `** TEST SUCCEEDED **`, **155 testes** passando (sem aumentar — apenas expansão do smoke).

- [ ] **Step 4: Commit**

```bash
git add app/Tagarela/Localization/pt-BR.lproj/Localizable.strings \
        app/TagarelaTests/LocalizableKeysTests.swift
git commit -m "$(cat <<'EOF'
i18n(styles): 3 chaves pro toggle Modo refinador / Livre

- styles.edit.discipline.toggle  ("Modo refinador (recomendado)")
- styles.edit.discipline.help    (caption sempre visível)
- styles.edit.discipline.warning (texto do warning condicional)

Cobertas pelo smoke test de Localizable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 6: `CustomStyleEditSheet` — Toggle "Modo refinador" + warning inline

Objetivo: introduzir o toggle real e o warning condicional na sheet. Substituir o `bypassDiscipline: false` temporário (T4) pelo valor do `@State`.

**Files:**
- Modify: `app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift`

(Esta tarefa é majoritariamente UI — sem TDD direto. Validação visual via build + preview/run no aceite. Smoke das chaves Localizable já garantida na T5.)

- [ ] **Step 1: Modificar `CustomStyleEditSheet.swift` — adicionar `@State`, Toggle, caption, warning, populate, save**

Substituir o conteúdo do arquivo por:

```swift
import SwiftUI

@MainActor
struct CustomStyleEditSheet: View {
    enum Mode { case create, edit(CustomStyle) }
    let mode: Mode
    let customStore: CustomStyleStore
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var systemPrompt: String = ""
    @State private var appendCodeSwitching: Bool = true
    @State private var bypassDiscipline: Bool = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleLabel).font(.title2).bold()
            Form {
                LabeledContent(String(localized: "styles.edit.name", defaultValue: "Nome")) {
                    TextField("", text: $name).textFieldStyle(.roundedBorder)
                }
                Text(String(localized: "styles.edit.prompt", defaultValue: "System prompt")).font(.caption)
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 140)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
                Toggle(String(localized: "styles.edit.codeswitch",
                               defaultValue: "Anexar cláusula de code-switching"),
                       isOn: $appendCodeSwitching)
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
            }
            if let err = saveError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            HStack {
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancelar")) { onClose() }
                Button(String(localized: "common.save", defaultValue: "Salvar")) { Task { await save() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty || trimmedPrompt.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 460)
        .onAppear { populate() }
    }

    private var titleLabel: String {
        switch mode {
        case .create: return String(localized: "styles.edit.title.create", defaultValue: "Novo estilo custom")
        case .edit:   return String(localized: "styles.edit.title.edit", defaultValue: "Editar estilo")
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var trimmedPrompt: String {
        systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func populate() {
        if case .edit(let s) = mode {
            name = s.name
            systemPrompt = s.systemPrompt
            appendCodeSwitching = s.appendCodeSwitching
            bypassDiscipline = s.bypassDiscipline
        }
    }

    private func save() async {
        do {
            switch mode {
            case .create:
                _ = try await customStore.create(name: trimmedName,
                                                  systemPrompt: trimmedPrompt,
                                                  appendCodeSwitching: appendCodeSwitching,
                                                  bypassDiscipline: bypassDiscipline)
            case .edit(let s):
                // Trim antes de mutar — store.update não revalida (only create faz).
                // Mantém edit consistente com create: whitespace-only não passa.
                s.name = trimmedName
                s.systemPrompt = trimmedPrompt
                s.appendCodeSwitching = appendCodeSwitching
                s.bypassDiscipline = bypassDiscipline
                try await customStore.update(s)
            }
            onClose()
        } catch {
            saveError = String(localized: "styles.edit.save.failed",
                                defaultValue: "Não foi possível salvar: ") + String(describing: error)
        }
    }
}
```

Mudanças vs original:
- `+ @State private var bypassDiscipline: Bool = false`
- TextEditor `minHeight` 160 → 140 (compensar espaço do toggle novo + caption)
- Frame height 420 → 460 (acomodar warning condicional sem clipping)
- 2 novos elementos no Form (Toggle + caption Text)
- 1 elemento condicional (warning HStack)
- `populate()` lê `bypassDiscipline`
- `save()` em `.create` passa `bypassDiscipline:`; em `.edit` atribui `s.bypassDiscipline = bypassDiscipline`

- [ ] **Step 2: Build pra confirmar compile + visual smoke**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -10
```

Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Rodar suíte completa**

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -20
```

Esperado: `** TEST SUCCEEDED **`, **155 testes** passando (sem aumentar — UI).

- [ ] **Step 4: Smoke visual rápido (opcional, mas recomendado antes do commit)**

Build em Release + reciclar app:

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -configuration Release build 2>&1 | tail -3
pkill -f Tagarela.app 2>/dev/null; sleep 1
rm -rf ~/Applications/Tagarela.app
cp -R /Users/tars/Dev/tagarela/app/build/Build/Products/Release/Tagarela.app ~/Applications/Tagarela.app
open ~/Applications/Tagarela.app
```

Abrir Preferências → Estilos → "Novo estilo custom". Confirmar:
- Toggle "Modo refinador (recomendado)" aparece, default ON.
- Caption "Refinador prefixa proteção..." aparece em cinza embaixo.
- Desligar o toggle → warning laranja com triângulo aparece embaixo do caption.
- Ligar de volta → warning some.

(Smoke completo vai no aceite manual da Tarefa 8.)

- [ ] **Step 5: Commit**

```bash
git add app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift
git commit -m "$(cat <<'EOF'
feat(styles-ui): toggle Modo refinador + warning inline na sheet

CustomStyleEditSheet ganha:
- @State bypassDiscipline default false
- Toggle "Modo refinador (recomendado)" abaixo do toggle de
  code-switching, ligado a !bypassDiscipline
- Caption sempre visível explicando o que o modo refinador faz
- Warning inline laranja (SF Symbol exclamationmark.triangle.fill)
  condicional ao modo livre, abaixo do caption
- populate() lê bypassDiscipline do model em edit
- save() passa em create / atribui no edit
- Frame height 420 → 460 pra acomodar warning sem clipping

Closes cleanup #2 follow-up da Fase 2b-1 (UX dedicada do
rewriterDiscipline) — pendente aceite manual.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: Criar checklist de aceite manual

Objetivo: criar o checklist completo da 2b-3 com 8 blocos pra condução bloco-a-bloco.

**Files:**
- Create: `tagarela_docs/03-funcionalidades/checklists/fase2b3-manual.md`

- [ ] **Step 1: Criar arquivo do checklist**

```bash
mkdir -p tagarela_docs/03-funcionalidades/checklists
```

Criar `tagarela_docs/03-funcionalidades/checklists/fase2b3-manual.md` com o conteúdo:

```markdown
---
data: pendente
status: pendente
fase: 2b-3
testado_em: pendente
build: pendente
---

# Aceite manual — Fase 2b-3

Checklist do aceite manual da Fase 2b-3. Conduzido bloco-a-bloco conforme [memory: workflow_aceite_manual](file:///Users/tars/.claude/projects/-Users-tars-Dev-tagarela/memory/workflow_aceite_manual.md).

**Setup geral:**
- Build em Release: `xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -configuration Release build`
- Instalar em `~/Applications/Tagarela.app` (não rodar do Xcode):
  ```bash
  pkill -f Tagarela.app && sleep 1 \
    && rm -rf ~/Applications/Tagarela.app \
    && cp -R /Users/tars/Dev/tagarela/app/build/Build/Products/Release/Tagarela.app ~/Applications/Tagarela.app \
    && open ~/Applications/Tagarela.app
  ```
- Domain UserDefaults: `com.tagarela.Tagarela`. Store SwiftData em `~/Library/Application Support/com.tagarela.Tagarela/`.

---

## Bloco 1 — Cancel HTTP (OpenAI)

**Setup:** backend OpenAI, key válida configurada em Preferências, modelo default (`gpt-5.4-mini`).

- [ ] Hotkey, falar "isso é um teste muito longo de cancelamento que deve ser interrompido", soltar hotkey.
- [ ] Durante `.refining` (pill amarelo) apertar Esc.
- [ ] State vai pra idle dentro de < 200ms (sensação visual).
- [ ] **Nada injetado** no app de foco (TextEdit, Notes, etc).
- [ ] Verificável por timing entre Esc e idle. Bonus: dashboard OpenAI não cobra a request abortada (verificar em https://platform.openai.com/usage após 5min).

**Edge:** Esc 100ms após começar refine — assert idle limpo, sem race nem flicker.

---

## Bloco 2 — Cancel HTTP (Ollama)

**Setup:** Ollama local rodando (`ollama serve`), modelo grande (preferencialmente algum que use GPU/CPU notavelmente — `gemma2:e9b` ou `llama3:e8b`). Selecionar como backend em Preferências.

- [ ] Abrir Activity Monitor (CPU + Memory) ou rodar `top -o cpu` numa Terminal lateral.
- [ ] Hotkey, frase técnica longa, soltar.
- [ ] Durante `.refining`, observar processo `ollama` consumindo CPU/GPU.
- [ ] Apertar Esc.
- [ ] Processo `ollama` cai pra idle dentro de ~1s. Não fica em loop processando. (Sintoma de antes do fix: GPU continuava em ~100% até completar o refine inteiro.)

---

## Bloco 3 — Cancel durante transcribe (whisper)

- [ ] Frase longa (10s+ de áudio), soltar hotkey.
- [ ] Durante `.processing` (não chega em `.refining` — pill cinza/azul, não amarelo), apertar Esc.
- [ ] State vai pra idle, sem inject.
- [ ] Whisper pode completar fisicamente (best-effort) — não é falha.
- [ ] Critério: UI limpa, sem inject, sem refine subsequente.

---

## Bloco 4 — Network-drop sem cancel (regression `99d174e`)

**Setup:** backend Ollama.

- [ ] Capturar frase, durante refine matar `ollama` em outro terminal:
      ```bash
      pkill ollama
      ```
- [ ] **Sem** apertar Esc.
- [ ] Toast "Refiner falhou — usando texto bruto" (ou similar mensagem de fallback) aparece acima do indicator pill.
- [ ] Texto cru injetado no app de foco.
- [ ] Garante que `99d174e` segue valendo após o refactor: `RefinerError.cancelled` sem flag `cancelled` cai em `RefinerFallbackReason.networkOffline` + identity fallback.

---

## Bloco 5 — Modo refinador (default)

- [ ] Preferências → Estilos → "Novo estilo custom".
- [ ] Nome: "Pergunta-teste". System prompt: "Reescreva o ditado mantendo o sentido, sem alterar nada substancial."
- [ ] Toggle "Modo refinador (recomendado)" deixa default ON.
- [ ] Caption "Refinador prefixa proteção..." visível em cinza.
- [ ] Sem warning laranja.
- [ ] Salvar.
- [ ] Selecionar o style (clicar no card).
- [ ] Ditar: "qual a capital da França".
- [ ] **Esperado:** texto injetado contém algo como "qual a capital da França" — o LLM transcreve a pergunta, **NÃO** responde "Paris".

---

## Bloco 6 — Modo livre

- [ ] Preferências → Estilos → editar o "Pergunta-teste" criado no Bloco 5.
- [ ] Desligar toggle "Modo refinador". Toggle vira OFF.
- [ ] **Warning laranja com triângulo aparece inline** logo abaixo do caption: "Modo livre: sem proteção. O LLM pode responder à fala em vez de transcrever."
- [ ] Salvar.
- [ ] Ditar: "qual a capital da França" (mesma frase do Bloco 5).
- [ ] **Esperado:** texto injetado agora pode responder "Paris" ou "A capital da França é Paris" — o LLM ficou livre, sem proteção.
- [ ] Confirma que o toggle muda comportamento real.

(Em algumas iterações o LLM pode mesmo assim transcrever — depende do prompt do user. O critério é: comportamento **muda**, não que responda determinísticamente.)

---

## Bloco 7 — Migration de styles existentes

**Pré-requisito:** ANTES do build novo da 2b-3, ter pelo menos 1 custom style criado na 2b-2 no store SwiftData. Se não tiver, criar antes:
- Reverter brevemente pro app instalado da 2b-2: `git stash; git checkout 373ae7e -- app/`, build Release, instalar, criar style "migration-teste", fechar app, e voltar:
  `git checkout main -- app/; git stash pop`
- Ou: confirmar que já existe via `ls ~/Library/Application\ Support/com.tagarela.Tagarela/`.

- [ ] Build novo da 2b-3, instalar via reciclo padrão.
- [ ] Abrir app, abrir Preferências → Estilos.
- [ ] Style "migration-teste" (ou outro existente da 2b-2) deve aparecer no card normalmente.
- [ ] Editar o style.
- [ ] Toggle "Modo refinador" vem **ON** (modo refinador, default).
- [ ] Sem warning.
- [ ] Comportamento de transcrição idêntico ao anterior (testar com hotkey).
- [ ] Sem crash de SwiftData migration ao abrir o app.

**Se Bloco 7 falhar com crash de migration:** ativar Plano B (campo `Bool?` opcional) — modificar `CustomStyle.swift` pra `var bypassDiscipline: Bool?`, ajustar `asStyle()` (`bypassDiscipline ?? false`), populate (`s.bypassDiscipline ?? false`). Hotfix dentro da própria fase.

---

## Bloco 8 — Persistência do toggle

- [ ] Editar style do Bloco 6 (ainda em modo livre), clicar Salvar de novo (sem mudanças).
- [ ] Fechar Preferências.
- [ ] Reabrir Preferências → Estilos → editar mesmo style.
- [ ] Toggle "Modo refinador" vem em OFF (livre).
- [ ] Warning laranja visível.

---

## Conclusão

- [ ] Todos os 8 blocos passaram **OU** achados não-bloqueantes documentados em `tagarela_docs/04-decisoes/cleanup-fase2b3.md`.
- [ ] Atualizar frontmatter desta nota: `status: ok` ou `status: ok-com-achados`.
- [ ] `testado_em: 2026-04-XX` e `build: <hash do commit>`.

Após aceite ✅, prosseguir com Tarefa 8 (doc closeout).
```

- [ ] **Step 2: Commit**

```bash
git add tagarela_docs/03-funcionalidades/checklists/fase2b3-manual.md
git commit -m "$(cat <<'EOF'
docs: checklist de aceite manual da Fase 2b-3

8 blocos cobrindo cancel HTTP (OpenAI + Ollama + transcribe),
network-drop regression, modo refinador default, modo livre
exposto, migration de styles existentes, persistência do toggle.

Pendente execução em ambiente Release.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 8: Aceite manual + doc closeout

**Files:**
- Update: `tagarela_docs/03-funcionalidades/checklists/fase2b3-manual.md` (status `ok` ou `ok-com-achados`)
- Update: `tagarela_docs/04-decisoes/cleanup-fase2a.md` (item #5 fechado)
- Update: `tagarela_docs/04-decisoes/cleanup-fase2b1.md` (itens #2 follow-up + #4 fechados)
- Update: `tagarela_docs/specs/2026-04-30-tagarela-v1-fase2b3-design.md` (frontmatter `status: implementado`)
- Update: `tagarela_docs/README.md` (status da 2b-3 = implementado)
- Update: `tagarela_docs/specs/2026-04-30-tagarela-v1-fase2b3-plan.md` (frontmatter `status: implementado`)
- Update: `~/.claude/projects/-Users-tars-Dev-tagarela/memory/achados_fase2a.md` (item #5 fechado)
- Create: `tagarela_docs/02-arquitetura/05-modulos-fase2b3.md` (snapshot pós-2b-3)
- Create (se houver achados): `tagarela_docs/04-decisoes/cleanup-fase2b3.md`

- [ ] **Step 1: Build Release + reciclar app**

```bash
cd /Users/tars/Dev/tagarela
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -configuration Release build 2>&1 | tail -3
pkill -f Tagarela.app && sleep 1 \
  && rm -rf ~/Applications/Tagarela.app \
  && cp -R /Users/tars/Dev/tagarela/app/build/Build/Products/Release/Tagarela.app ~/Applications/Tagarela.app \
  && open ~/Applications/Tagarela.app
```

Esperado: app abre, ícone aparece na status bar.

- [ ] **Step 2: Conduzir checklist bloco-a-bloco com o user**

Conforme `workflow_aceite_manual` (memory). Para cada bloco:
1. Listar o que fazer e o que esperar.
2. User executa, reporta em lote.
3. Marcar `[x]` no markdown conforme passa.

Bugs descobertos durante o aceite: triagem rápida (root cause + proposta), confirmar com user antes de codar, fixar, rebuild+reinstall, retestar só o que falhou. Achados não-bloqueantes viram `cleanup-fase2b3.md`.

- [ ] **Step 3: Marcar checklist como `ok` ou `ok-com-achados`**

Atualizar frontmatter de `fase2b3-manual.md`:

```yaml
data: 2026-04-XX
status: ok            # ou ok-com-achados
fase: 2b-3
testado_em: 2026-04-XX
build: <commit hash do build testado>
```

- [ ] **Step 4: Atualizar `cleanup-fase2a.md` — item #5 fechado**

Trocar título do item #5 por:

```markdown
## 5. Cancelamento durante refiner não interrompe a request HTTP — ✅ FECHADO 2026-04-XX

[manter contexto original do item — adicionar bloco abaixo]

**Fix aplicado (2026-04-XX, Fase 2b-3):** `PipelineCoordinator` agora envolve `runTranscribeAndInject` numa `pipelineTask: Task<Void, Never>?` armazenada. `handleCancel` em `.processing/.refining` chama `pipelineTask?.cancel()` além de setar `cancelled = true`. URLSession honra cancellation nativamente — Esc durante refine remoto aborta o request HTTP em vôo. WhisperKit é best-effort. Lógica de `RefinerError.cancelled where cancelled` (commit `99d174e`, distinguindo user-cancel real de network-drop disfarçado) preservada via flag `cancelled` paralela ao `Task.isCancelled`. +5 testes em `PipelineCoordinatorTests`. Verificado no aceite manual da 2b-3 (Blocos 1, 2, 3, 4).
```

Atualizar frontmatter pra refletir que todos os 5 itens estão fechados:

```yaml
status: fechado
fechados_em: 2026-04-29 (1, 2, 3, 4) + 2026-04-XX (5)
```

- [ ] **Step 5: Atualizar `cleanup-fase2b1.md` — itens #2 follow-up + #4 fechados**

**Item #2 follow-up:** dentro do bloco já existente, trocar:

> **Follow-up pra Fase 2b-3:** decidir UX dedicada [...]

por:

> **Follow-up fechado na Fase 2b-3 (2026-04-XX):** `CustomStyleEditSheet` ganha Toggle "Modo refinador (recomendado)" (default ON, paralelo ao toggle de code-switching) + caption help text + warning inline laranja (`exclamationmark.triangle.fill`) condicional ao modo livre. Persistência via novo campo `bypassDiscipline: Bool` (default `false`) em `@Model CustomStyle`. `asStyle()` consulta o campo pra decidir se prefixa `rewriterDiscipline`. SwiftData lightweight migration validada no aceite (Bloco 7). Verificado nos Blocos 5, 6, 8.

**Item #4:** trocar título por:

```markdown
## 4. Esc não cancela injeção HTTP em vôo — ✅ FECHADO 2026-04-XX (Fase 2b-3)

[manter contexto original — adicionar:]

**Fix aplicado (2026-04-XX, Fase 2b-3):** mesmo fix do [cleanup #5 da Fase 2a](./cleanup-fase2a.md#5-cancelamento-durante-refiner-não-interrompe-a-request-http). Ver lá pros detalhes técnicos. Verificado nos Blocos 1, 2 do aceite manual da 2b-3.
```

Frontmatter:

```yaml
status: fechado
fechados_em: 2026-04-29 (1, 2, 3) + 2026-04-XX (2 follow-up, 4)
```

- [ ] **Step 6: Atualizar memória `achados_fase2a.md`**

Editar `~/.claude/projects/-Users-tars-Dev-tagarela/memory/achados_fase2a.md`:

Trocar a linha do item 5:
```
5. ⏳ **Cancel não cancela request HTTP em vôo** — refactor pra `Task.cancel()` envolvendo `runTranscribeAndInject`. Empurrado pra **Fase 2b-3**.
```

Por:
```
5. ✅ **Cancel não cancela request HTTP em vôo** — fechado 2026-04-XX (Fase 2b-3): pipelineTask Task armazenada + handleCancel propaga Task.cancel(). +5 testes.
```

E atualizar o bloco final:

```
**Why:** todos os 5 itens fechados ao fim da 2b-3. Suíte ~157 testes verde. Aceite manual da 2b-3 em `tagarela_docs/03-funcionalidades/checklists/fase2b3-manual.md`.

**How to apply:** se user pedir "limpa o débito da 2a", responder que está zerado.
```

E trocar o frontmatter `description`:

```yaml
description: Pointer pros 5 cleanups levantados durante o aceite manual da 2a; todos fechados ao fim da 2b-3 (item #5 em 2026-04-XX)
```

- [ ] **Step 7: Criar `02-arquitetura/05-modulos-fase2b3.md`**

Snapshot pós-2b-3 (similar ao `04-modulos-fase2b2.md`):

```markdown
---
data: 2026-04-XX
fase: 2b-3 (encerra a Fase 2b)
status: implementado
---

# Módulos pós-Fase 2b-3

Snapshot dos módulos após a Fase 2b-3 — fase cirúrgica de fechamento de débitos. Sem novos módulos; mudanças em arquivos existentes.

## Módulos modificados

### `Pipeline/PipelineCoordinator.swift`

- Novo campo `internal private(set) var pipelineTask: Task<Void, Never>?` armazena handle cancelável da pipeline durante `.processing`/`.refining`.
- `handleToggle` em `.recording` envolve `runTranscribeAndInject()` numa `Task` armazenada com cleanup automático (`clearPipelineTask`).
- `handleCancel` em `.processing/.refining` agora chama `pipelineTask?.cancel()` além de setar `cancelled = true`. URLSession honra cancellation nativamente — request HTTP em vôo aborta.
- Novo helper `aborted() -> Bool` agrega `cancelled || Task.isCancelled`. Substitui as 3 checagens isoladas de `if cancelled` nos checkpoints internos.
- Lógica `catch RefinerError.cancelled where cancelled` (commit `99d174e`) preservada — flag `cancelled` continua existindo paralela ao `Task.isCancelled`.

### `Refiner/CustomStyle.swift`

- `@Model CustomStyle` ganha campo `var bypassDiscipline: Bool` (default `false`).
- `asStyle()` consulta o campo: `false` → prefixa `rewriterDiscipline` (modo refinador, comportamento da 2b-1); `true` → systemPrompt vai puro pro LLM (modo livre).
- Init com default no novo param mantém compat de call sites e migration SwiftData lightweight.

### `Refiner/CustomStyleStore.swift` + `CustomStyleStoreLive.swift` + `CustomStyleStoreNoop.swift`

- `create(name:systemPrompt:appendCodeSwitching:bypassDiscipline:)` — protocol assinatura ganha o novo param **sem default no protocol** (call sites passam explícito).
- `Live` propaga pro `CustomStyle.init`. `Noop` adapta a assinatura.

### `Preferences/UI/Sheets/CustomStyleEditSheet.swift`

- Novo `@State bypassDiscipline: Bool = false`.
- Novo Toggle "Modo refinador (recomendado)" abaixo do toggle de code-switching, ligado a `!bypassDiscipline`.
- Caption sempre visível: "Refinador prefixa proteção contra o LLM responder à fala em vez de transcrever."
- Warning inline laranja (`exclamationmark.triangle.fill`) condicional ao modo livre.
- `populate()` lê `bypassDiscipline` do model em edit.
- `save()` propaga em create / atribui no edit.
- Frame height 420 → 460 pra acomodar warning sem clipping.

### `Localization/pt-BR.lproj/Localizable.strings`

- 3 chaves novas: `styles.edit.discipline.toggle`, `styles.edit.discipline.help`, `styles.edit.discipline.warning`.

## Cobertura de testes

Suíte ~157 testes (de 145 da 2b-2):

- `PipelineCoordinatorTests` — +5 testes (cancel HTTP via Task armazenada).
- `CustomStyleTests` — +3 testes (modo livre).
- `CustomStyleStoreTests` — +2 testes (bypassDiscipline persiste).
- `LocalizableKeysTests` — +3 chaves no smoke.

Helpers novos em `PipelineCoordinatorTests`: `FakeRefinerSlow`, `FakeTranscriberSlow`, `CountingRefiner`, `ActorInt`.

## Cleanups fechados

- [`cleanup-fase2a.md`](../04-decisoes/cleanup-fase2a.md) item #5 — cancel HTTP via `Task.cancel()`.
- [`cleanup-fase2b1.md`](../04-decisoes/cleanup-fase2b1.md) item #2 follow-up — UX dedicada do `rewriterDiscipline`.
- [`cleanup-fase2b1.md`](../04-decisoes/cleanup-fase2b1.md) item #4 — mesmo que cleanup-fase2a.md #5.

Toda a Fase 2b está fechada após a 2b-3. Próxima fase grande ainda em discussão.

## Decisões nucleares (referência)

Ver [`tagarela_docs/specs/2026-04-30-tagarela-v1-fase2b3-design.md` §1.4](../specs/2026-04-30-tagarela-v1-fase2b3-design.md#14-decisões-nucleares-do-brainstorming-2026-04-30) — 8 decisões F2b3-1 a F2b3-8.
```

- [ ] **Step 8: Atualizar frontmatter dos specs (design + plan)**

`tagarela_docs/specs/2026-04-30-tagarela-v1-fase2b3-design.md`:
```yaml
status: implementado
implementado_em: 2026-04-XX (branch fase-2b3, ~8 commits, ~157 testes verdes, aceite manual ✅)
```

`tagarela_docs/specs/2026-04-30-tagarela-v1-fase2b3-plan.md`:
```yaml
status: implementado
implementado_em: 2026-04-XX
```

- [ ] **Step 9: Atualizar `tagarela_docs/README.md`**

Trocar a linha:
```
- [`2026-04-30-tagarela-v1-fase2b3-design.md`](./specs/2026-04-30-tagarela-v1-fase2b3-design.md) — design da Fase 2b-3 (cancel HTTP em vôo via `Task.cancel()` + UX modo refinador/livre pros custom styles). **Status: design** (plan e implementação pendentes). Fecha cleanup #5 da 2a e cleanups #2 (follow-up) e #4 da 2b-1.
```

Por (atualizar status):
```
- [`2026-04-30-tagarela-v1-fase2b3-design.md`](./specs/2026-04-30-tagarela-v1-fase2b3-design.md) — design da Fase 2b-3 (cancel HTTP em vôo + UX modo refinador/livre pros custom styles). **Status: implementado** (branch `fase-2b3`, ~157 testes verdes, aceite manual ✅). Fecha cleanup #5 da 2a e cleanups #2 (follow-up) e #4 da 2b-1.
- [`2026-04-30-tagarela-v1-fase2b3-plan.md`](./specs/2026-04-30-tagarela-v1-fase2b3-plan.md) — plano executado da Fase 2b-3 (8 tarefas, +12 testes, suíte ~157).
```

E na seção 02-arquitetura:
```
- [`05-modulos-fase2b3.md`](./02-arquitetura/05-modulos-fase2b3.md) — snapshot pós-Fase 2b-3: módulos modificados (PipelineCoordinator com pipelineTask Task armazenada, CustomStyle com bypassDiscipline, sheet com toggle Modo refinador). Encerra a Fase 2b. Cleanups #5 da 2a e #2 follow-up + #4 da 2b-1 fechados.
```

- [ ] **Step 10: Se houver achados, criar `cleanup-fase2b3.md`**

Template:

```markdown
---
data: 2026-04-XX
status: aberto
revisitar_em: 2026-05-XX (~15 dias)
---

# Cleanup pós-Fase 2b-3

Achados levantados durante o aceite manual da Fase 2b-3 (ver [`fase2b3-manual.md`](../03-funcionalidades/checklists/fase2b3-manual.md)). Não bloqueiam o fechamento.

## 1. <título>

<conteúdo>

[etc]
```

- [ ] **Step 11: Commit final + merge `--no-ff` em `main`**

```bash
git add tagarela_docs/
git commit -m "$(cat <<'EOF'
docs: fechamento da Fase 2b-3 — cleanup #5 da 2a + #2/#4 da 2b-1 fechados

- fase2b3-manual.md: status ok/ok-com-achados
- 05-modulos-fase2b3.md: snapshot pós-2b-3 (~157 testes)
- cleanup-fase2a.md item #5 fechado (cancel HTTP via Task.cancel)
- cleanup-fase2b1.md item #2 follow-up + #4 fechados
- README do vault: 2b-3 status = implementado
- spec/plan frontmatter: implementado

Encerra a Fase 2b — todos os cleanups da 2a e 2b-1 zerados.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git checkout main
git merge --no-ff fase-2b3 -m "Merge fase-2b3 into main: cancel HTTP em vôo + modo refinador/livre"
```

(Se houver achados, criar `cleanup-fase2b3.md` antes do commit final.)

---

## Self-review (gates de fim de fase)

Antes de declarar fim:

- [ ] Suíte verde: ~157 testes, 0 falhas (`xcodebuild test`).
- [ ] Doc de design (`fase2b3-design.md`) com `status: implementado`.
- [ ] Doc de plan (`fase2b3-plan.md`) com `status: implementado`.
- [ ] Doc de arquitetura (`05-modulos-fase2b3.md`) reflete módulos reais modificados.
- [ ] Checklist manual com `status: ok` (ou `ok-com-achados`).
- [ ] `cleanup-fase2a.md` marca item #5 como fechado.
- [ ] `cleanup-fase2b1.md` marca itens #2 follow-up e #4 como fechados.
- [ ] Memória `achados_fase2a.md` atualizada (item #5 ✅).
- [ ] Bloco 1 e 2 do aceite confirmaram cancel HTTP funcional (OpenAI URLSession aborta + Ollama GPU/CPU caem em ~1s).
- [ ] Bloco 4 do aceite confirmou regression `99d174e` (network-drop sem flag → fallback).
- [ ] Blocos 5 e 6 do aceite confirmaram que toggle "Modo refinador" muda comportamento real do LLM.
- [ ] Bloco 7 do aceite confirmou migration SwiftData de styles existentes (sem crash).
- [ ] `git log --oneline main..fase-2b3` mostra ~8 commits (um por tarefa) com co-author Claude.
- [ ] `git log -1` mostra merge `--no-ff` em main.

---

## Resumo das tarefas

| # | Tarefa | Arquivos | Δtestes |
|---|---|---|---|
| 1 | PipelineCoordinator — pipelineTask + aborted() + cancel propaga | 1 código + 1 teste | +1 (146) |
| 2 | Testes adicionais do cancel HTTP | 1 teste | +4 (150) |
| 3 | CustomStyle — bypassDiscipline + asStyle condicional | 1 código + 1 teste | +3 (153) |
| 4 | CustomStyleStore — protocol + Live + Noop + caller | 4 código + 1 teste | +2 (155) |
| 5 | Localizable strings | 1 código + 1 teste | 0 (155) |
| 6 | CustomStyleEditSheet — Toggle + warning | 1 código | 0 (155) |
| 7 | Checklist de aceite manual | 1 doc | 0 (155) |
| 8 | Aceite manual + doc closeout | 6+ docs | 0 (155) |

(Suíte alvo do spec era ~157; chegamos a ~155 porque um dos testes propostos no spec, `test_network_drop_without_user_cancel_falls_back`, já existia no arquivo como `test_cancelledError_withoutUserCancelFlag_treatedAsNetworkDrop`. Documentado na Tarefa 2 Step 6.)
