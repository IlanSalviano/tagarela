---
data: 2026-04-30
fase: 2b-3 (encerra a Fase 2b)
status: implementado
---

# Módulos pós-Fase 2b-3

Snapshot dos módulos após a Fase 2b-3 — fase cirúrgica de fechamento de débitos. Sem novos módulos; mudanças em arquivos existentes.

A Fase 2b-3 fecha:
- [Cleanup #5 da Fase 2a](../04-decisoes/cleanup-fase2a.md) — cancel HTTP via `Task.cancel()`.
- [Cleanup #2 follow-up + #4 da Fase 2b-1](../04-decisoes/cleanup-fase2b1.md) — UX dedicada do `rewriterDiscipline` + cancel HTTP.

Toda a Fase 2b está fechada após a 2b-3.

## Módulos modificados

### `Pipeline/PipelineCoordinator.swift`

- Novo campo `internal private(set) var pipelineTask: Task<Void, Never>?` armazena handle cancelável da pipeline durante `.processing`/`.refining`. Visibility relaxada pra permitir verificação em tests via `@testable`.
- `handleToggle` em `.recording` envolve `runTranscribeAndInject()` numa `Task` armazenada com cleanup automático (`clearPipelineTask`).
- `handleCancel` em `.processing/.refining` agora chama `pipelineTask?.cancel()` além de setar `cancelled = true`. Ordem é load-bearing — flag setada ANTES do `cancel()` pra preservar a distinção user-cancel real vs network-drop disfarçado (commit `99d174e`).
- Novo helper `aborted() -> Bool` agrega `cancelled || Task.isCancelled`. Substitui as 3 checagens isoladas de `if cancelled` nos checkpoints internos do `runTranscribeAndInject` (pós-transcribe, pós-refine, pós-inject).
- Lógica `catch RefinerError.cancelled where cancelled` (commit `99d174e`) preservada byte-for-byte — flag `cancelled` continua existindo paralela ao `Task.isCancelled`.
- URLSession honra `Task.cancel()` nativamente: Esc durante refine remoto aborta o request HTTP em vôo. WhisperKit é best-effort.

### `Refiner/CustomStyle.swift`

- `@Model CustomStyle` ganha campo `var bypassDiscipline: Bool` (default `false` no init). Lightweight migration SwiftData (rows antigos lêem como `false` automaticamente — validado implicitamente no aceite Bloco 7).
- `asStyle()` consulta o campo: `false` (modo refinador, default) prefixa `rewriterDiscipline`; `true` (modo livre) usa `systemPrompt` puro.
- `appendCodeSwitching` continua ortogonal (anexa clause em ambos os modos).

### `Refiner/CustomStyleStore.swift` + `CustomStyleStoreLive.swift` + `CustomStyleStoreNoop.swift`

- `create(name:systemPrompt:appendCodeSwitching:bypassDiscipline:)` — protocol assinatura ganha o novo param **sem default no protocol** (decisão F2b3-7: call sites passam explícito pra evitar esquecimento silencioso).
- `Live` propaga pro `CustomStyle.init`. `Noop` adapta a assinatura mantendo throw no-op.

### `Preferences/UI/Sheets/CustomStyleEditSheet.swift`

- Novo `@State private var bypassDiscipline: Bool = false`.
- Novo Toggle "Modo refinador (recomendado)" abaixo do toggle de code-switching, ligado a `!bypassDiscipline` via Binding invertido.
- Caption sempre visível em `.foregroundStyle(.secondary)`: "Refinador prefixa proteção contra o LLM responder à fala em vez de transcrever."
- Warning inline laranja (`Image(systemName: "exclamationmark.triangle.fill")` + `.foregroundStyle(.orange)`) condicional ao modo livre, abaixo do caption.
- `populate()` lê `bypassDiscipline` do model em edit.
- `save()` propaga em create / atribui em edit.
- Frame height 420 → 460 pra acomodar warning sem clipping. TextEditor minHeight 160 → 140.

### `Localization/pt-BR.lproj/Localizable.strings`

- 3 chaves novas no namespace `styles.edit.discipline.*`:
  - `styles.edit.discipline.toggle` = "Modo refinador (recomendado)"
  - `styles.edit.discipline.help` (caption sempre visível)
  - `styles.edit.discipline.warning` (warning condicional)

## Módulos modificados (test-only)

- `app/TagarelaTests/PipelineCoordinatorTests.swift` — +5 testes (cancel HTTP via Task armazenada) + helpers `FakeRefinerSlow`, `FakeTranscriberSlow`, `CountingRefiner`, `ActorInt` (todos `private`).
- `app/TagarelaTests/CustomStyleTests.swift` — +3 testes (modo livre).
- `app/TagarelaTests/CustomStyleStoreTests.swift` — +2 testes (bypassDiscipline persiste); 7 call sites existentes atualizados pra incluir `bypassDiscipline: false`.
- `app/TagarelaTests/StyleProviderTests.swift` + `RefinerFactoryTests.swift` — `FakeCustomStore` stubs adaptados mecanicamente à nova assinatura. Não bloqueante mas reforça o débito pendente do [`cleanup-fase2b1.md` item #5](../04-decisoes/cleanup-fase2b1.md#5-achados-secundários-do-code-review-do-branch-informacional) (extrair `FakeCustomStore` pra helper compartilhado se uma terceira aparição surgir).
- `app/TagarelaTests/LocalizableKeysTests.swift` — +3 chaves no smoke test.

## Cobertura de testes

Suíte **155 testes** (de 145 da 2b-2):

- +5 testes em `PipelineCoordinatorTests` (item 1 — cancel HTTP)
- +3 testes em `CustomStyleTests` (item 2 — modo livre)
- +2 testes em `CustomStyleStoreTests` (item 2 — persistência)
- +3 chaves no smoke de `LocalizableKeysTests`

Spec original previa +12 testes; chegamos a +10 — `test_network_drop_without_user_cancel_falls_back` proposto no spec já existia como `test_cancelledError_withoutUserCancelFlag_treatedAsNetworkDrop` em `PipelineCoordinatorTests.swift:40` (regression do commit `99d174e`).

## Cleanups da Fase 2a/2b-1 fechados pela 2b-3

- [`cleanup-fase2a.md` item #5](../04-decisoes/cleanup-fase2a.md#5-cancelamento-durante-refiner-não-interrompe-a-request-http--fechado-2026-04-30) — cancel HTTP via `Task.cancel()`.
- [`cleanup-fase2b1.md` item #2 follow-up](../04-decisoes/cleanup-fase2b1.md#2-custom-style-fazia-llm-responder-à-frase-em-vez-de-transcrever--fechado-2026-04-29) — UX dedicada do `rewriterDiscipline`.
- [`cleanup-fase2b1.md` item #4](../04-decisoes/cleanup-fase2b1.md#4-esc-não-cancela-injeção-http-em-vôo---fechado-2026-04-30-fase-2b-3) — mesmo fix do cleanup #5 da 2a.

## Cleanups novos da 2b-3

- [`cleanup-fase2b3.md`](../04-decisoes/cleanup-fase2b3.md) — 1 achado funcional (pill flicker no Esc rápido) + 8 polish minor coletados das reviews. Revisitar 2026-05-15.

## Decisões nucleares (referência)

Ver [`tagarela_docs/specs/2026-04-30-tagarela-v1-fase2b3-design.md` §1.4](../specs/2026-04-30-tagarela-v1-fase2b3-design.md#14-decisões-nucleares-do-brainstorming-2026-04-30) — 8 decisões F2b3-1 a F2b3-8.

## Próxima fase

Toda a Fase 2b está fechada. Próximas grandes em discussão:
- Onboarding novo (LLM scan + key prompt no fluxo guiado).
- Re-bind real da hotkey, captura L/R Option.
- Tuning fino dos prompts dos built-in styles (escopo conhecido, sem fase definida).
- `VersionedSchema` baseline pro SwiftData ([`cleanup-fase2b1.md` item #5](../04-decisoes/cleanup-fase2b1.md#5-achados-secundários-do-code-review-do-branch-informacional)).
