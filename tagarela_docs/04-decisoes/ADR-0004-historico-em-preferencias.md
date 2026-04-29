---
status: aceita
data: 2026-04-29
revisa: ADR-0001
---

# ADR-0004 — Histórico viewer dentro de Preferências (revisa ADR-0001)

## Contexto

[ADR-0001](./ADR-0001-sistema-visual.md) (Fase 1) listou a "aba Histórico rica nas Preferências" entre as **mudanças de escopo recusadas**: cru + refinado lado a lado, busca, limpar tudo. A justificativa de então era manter a v1 enxuta — Fase 1 entregaria só esqueleto end-to-end, sem visualizador.

A Fase 2b-1 (2026-04-29) entregou a janela de Preferências completa com 9 sections, incluindo `Histórico` apenas com retenção (`historyMaxItems`/`Days`). O aceite manual da 2b-1 confirmou que o `HistoryStore` SwiftData popula corretamente a cada captura, mas **não há visualizador** — sintoma 12.1 do checklist.

A Fase 2b-2 precisa entregar o visualizador. O brainstorming considerou três opções (registradas em `2026-04-29-tagarela-v1-fase2b2-design.md` decisão F2b2-2):

- A) Janela própria com lista única (`Tagarela > Histórico…` + ⌘H).
- B) Janela própria com lista + detail panel (Mail-style).
- C) Expandir a seção `Histórico` das Preferências com lista debaixo da retenção.

## Decisão

**Adotada: C — histórico mora dentro de Preferências > Histórico**, expandindo a seção atual com:

- Busca por substring case-insensitive (cru OU refinado).
- Lista de cards renderizada em `LazyVStack` (cru + refinado sempre visíveis, sem expansão).
- Botão "Limpar tudo" com NSAlert de confirmação.
- Sem filtros (refiner kind, app, data) na 2b-2.

## Consequências

### Positivas

- Sem janela nova — zero código de window management adicional, zero menu wiring novo.
- Tudo de histórico (settings + dados) num lugar só. Reduz superfície mental do user.
- Reusa a infraestrutura de Preferências da 2b-1 (`PreferencesRoot`, `NavigationSplitView`, dependências já passadas).
- Lazy render via `LazyVStack` cobre os 200 itens da retenção máxima sem custo perceptível.

### Negativas / custo

- Mistura "settings" e "data" numa mesma seção — quebra a expectativa de Preferências serem só configuração. Aceito como trade-off pra simplicidade.
- Refresh não-live: nova captura não atualiza a `HistoryView` aberta; user reabre ou roda busca de novo. Documentado como limitação na §5 da spec.
- Cresce mal se a retenção máxima subir muito (e.g., `historyMaxItems = 5000`). Aceito (default é 200).
- Sem `⌘H` ou item de menu dedicado pro histórico. Acesso via `⌘,` → Histórico (1 clique extra).

## Mudança vs ADR-0001

ADR-0001 §"Mudanças de escopo recusadas (ficam pra v2)" listava:

> - Aba "Histórico" rica nas Preferências (cru + refinado lado a lado, busca, limpar tudo).

**A 2b-2 incorpora parcialmente esse escopo**, mantendo as 3 features (cru+refinado, busca, limpar tudo). Não vira "aba" separada — fica embutida na seção `Histórico` que já existe (que tinha só retenção). Sem detail panel separado (rejeitada opção B). Sem janela própria (rejeitada opção A).

Esse ADR sobrescreve a parte do ADR-0001 que rejeitava o histórico rico.

## Alternativas consideradas

- **Janela própria com lista única (A)** — idiomático macOS (estilo Things "Logbook", Bear "Archive"). Rejeitado por adicionar mais uma window infra (frame autosave, ⌘ menu wiring, NSWindowController) sem benefício suficiente pro caso de uso individual.
- **Janela própria com lista + detail panel (B)** — Mail-style. Rejeitado: split view dobra o código de UI, default detail vazio é ruim, e o caso "ver cru+refinado lado a lado" é coberto pelo card-like layout escolhido.
- **Manter rejeição do ADR-0001** — empurrar histórico viewer pra v2. Rejeitado: aceite manual da 2b-1 confirmou que esse é um buraco real de UX (user confiou que "histórico está sendo persistido" mas não tinha como conferir).

## Referências

- Spec da 2b-2: [`2026-04-29-tagarela-v1-fase2b2-design.md`](../specs/2026-04-29-tagarela-v1-fase2b2-design.md) §1.5, F2b2-2, F2b2-3, F2b2-4.
- ADR-0001 (revisado): [`ADR-0001-sistema-visual.md`](./ADR-0001-sistema-visual.md).
- Checklist 2b-1 que surfaceou o gap: [`fase2b1-manual.md`](../03-funcionalidades/checklists/fase2b1-manual.md) item 12.1.
