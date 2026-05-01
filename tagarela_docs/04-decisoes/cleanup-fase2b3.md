---
data: 2026-04-30
status: aberto
revisitar_em: 2026-05-15
---

# Cleanup pós-Fase 2b-3

Achados levantados durante o aceite manual da Fase 2b-3 (ver [`fase2b3-manual.md`](../03-funcionalidades/checklists/fase2b3-manual.md)). Não bloqueiam o fechamento da fase — código está funcional. São polish.

## 1. Pill flicker quando Esc é apertado muito rápido após `.refining` — segue aberto

**Status (2026-05-01, Fase 2c-cleanup):** ⚠️ tentativa de fix revertida junto com cleanup #8 da Fase 1 (mesmo root cause comum, mesma refatoração). Ver detalhes em [`cleanup-fase1.md` item #8](./cleanup-fase1.md#8-indicatorpill-recria-nshostingcontroller-a-cada-level-update--segue-aberto).



**Arquivo:** [`app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift`](../../app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift) (provavelmente; não confirmado).

**Sintoma observado:** durante o aceite manual da 2b-3 (Bloco 1 e Bloco 3), quando o user aperta Esc < 100ms após o pill virar amarelo (`.refining`), a tela do pill desaparece, reaparece e some de novo muito rápido — flicker visível.

**Hipótese:** o caminho `.refining → .idle` agora é mais agressivo (Task.cancel() propaga, URLSession aborta sub-200ms). A animação de show/hide do `FloatingIndicatorPanel` pode estar reativando o panel pra refresh de estado intermediário (ex: re-show com state .refining → re-hide imediato com .idle) em vez de simplesmente esconder. Pode ser pré-existente exacerbado pela velocidade do cancel da 2b-3.

**Não-issue funcional:** estado final é correto (idle, sem inject). Apenas polish visual.

**Proposta:** investigar se `FloatingIndicatorPanel.show(state:)` faz `orderOut` + `orderFront` ou similar entre transições de estado próximas. Trocar por update in-place quando o panel já está visível, ou debounce de animação.

## 2. Issues minor levantados pelo code reviewer da T6 (snapshot pra investigação futura)

Levantados durante o code review da Tarefa 6 mas não bloqueantes. Coletados aqui pra revisitação:

### 2a. Sizing dinâmico vs `.frame(width: 520, height: 460)` fixo na sheet de edição

**Arquivo:** [`app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift`](../../app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift).

Frame fixo 520×460 acomoda o warning condicional sem clipping na configuração atual. Mas tradução futura mais longa, ou conteúdo extra, pode estourar. Caminho mais robusto: `.frame(minWidth: 520, minHeight: 460)` ou auto-sizing via SwiftUI. Não causou problema no aceite.

### 2b. Acessibilidade do warning laranja

`Image(systemName: "exclamationmark.triangle.fill") + Text` em laranja `.font(.caption)`. Cego pra cor distingue mal "vermelho/laranja/marrom" em texto pequeno. Ícone carrega significado por shape, mitiga. Pra WCAG AA stricter: avaliar contraste laranja sistêmico, considerar `accessibilityLabel("Aviso")` no `Image`.

### 2c. Caption sempre visível + warning condicional: redundância visual leve

Quando bypass está ON, sheet mostra caption "Refinador prefixa proteção..." em cinza + warning "Modo livre: sem proteção..." em laranja. Cognitivamente: user em modo livre lê "Refinador prefixa proteção" e pode ficar confuso ("mas eu desliguei?"). Possível esconder caption quando `bypassDiscipline == true` (warning carrega a mensagem) ou neutralizar copy do caption.

Nenhuma dessas reclamações apareceu no aceite — registro pra rever se houver feedback.

### 2d. Cobertura de teste de UI pra sheet

`CustomStyleEditSheet` não tem snapshot test nem XCUITest. Lógica de `populate()` / `save()` hoje só é testada via aceite manual. ViewInspector ou XCUITest entraria como cleanup futuro.

## 3. Issues minor levantados pelo code reviewer da T2

### 3a. DRY entre os 3 testes de cancel-during-refining

**Arquivo:** [`app/TagarelaTests/PipelineCoordinatorTests.swift`](../../app/TagarelaTests/PipelineCoordinatorTests.swift).

Os testes `test_cancelDuringRefining_cancelsRefinerTask`, `test_cancelDuringRefining_doesNotInject` e `test_cancelDuringRefining_doesNotSaveHistory` compartilham 5 linhas de setup (toggle, toggle, sleep 100ms, cancel, sleep 200ms). Vale extrair `runUntilRefiningThenCancel(_:)` se um quarto teste com mesmo padrão aparecer.

### 3b. `FakeCustomStore` duplicado entre `StyleProviderTests.swift` e `RefinerFactoryTests.swift`

Já documentado em [`cleanup-fase2b1.md` item #5](./cleanup-fase2b1.md#5-achados-secundários-do-code-review-do-branch-informacional). A 2b-3 tornou o duplicate marginalmente mais doloroso (precisou adaptar 2 stubs em vez de 1 quando o protocol mudou). Não passou da threshold ainda — mantém deferrred. Se uma terceira aparição surgir, extrair pra `app/TagarelaTests/Helpers/FakeCustomStyleStore.swift`.

### 3c. Sleeps fixos em testes de cancel são timing-sensitive

`try? await Task.sleep(nanoseconds: 100_000_000)` pra "esperar entrar em .refining" é heurística. Em CI lento pode flakear. Substituir por observação determinística do `events` AsyncStream (await `.stateChanged(.refining)`) seria mais robusto. Baixa prioridade — testes passaram em todas as iterações locais.

### 3d. `makeCoordinator` não aceita `transcriber:` parametrizado

Forçou `test_cancelDuringProcessing_doesNotCallRefiner` e `test_pipelineTask_clearedAfterCompletion` a instanciarem `PipelineCoordinator` direto. Polish ergonômico.

## Status

Todos não-bloqueantes. Revisitar **2026-05-15** ou quando alguma virar dor real.
