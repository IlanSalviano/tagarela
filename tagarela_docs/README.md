# tagarela — documentação

Vault de documentação do projeto **tagarela** (codinome). Clone do Wispr Flow para uso individual em macOS, com LLM local (Ollama), OpenAI API ou sem LLM.

> Regras de trabalho: ver [`/CLAUDE.md`](../CLAUDE.md) na raiz do repositório.

---

## Índice

### 00 — Visão
_(a preencher)_ — objetivos, escopo, não-objetivos, persona alvo.

### 01 — Pesquisa
_(a preencher)_ — análise do Wispr Flow, alternativas, decisões de paridade.

### 02 — Arquitetura
- [`01-modulos-fase1.md`](./02-arquitetura/01-modulos-fase1.md) — snapshot dos módulos implementados na Fase 1, divergências do plano, cobertura de testes, escopo das próximas fases.
- [`02-stack-tecnica.md`](./02-arquitetura/02-stack-tecnica.md) — versões reais (Xcode/Swift/macOS), uso de xcodegen como fonte da verdade do projeto, dependências SPM (WhisperKit), fontes empacotadas, capabilities.
- [`03-modulos-fase2b1.md`](./02-arquitetura/03-modulos-fase2b1.md) — snapshot pós-Fase 2b-1: módulos novos (Preferências UI, custom styles, endpoints custom OpenAI), modificados (factory consulta StyleProvider, container SwiftData compartilhado), cleanups da 2a fechados (#1, #3, #4) e abertos (#2, #5).

### 03 — Funcionalidades
- [`checklists/fase1-manual.md`](./03-funcionalidades/checklists/fase1-manual.md) — checklist manual de aceite da Fase 1 (onboarding, status bar, pipeline, apps de injeção, edge cases, performance).
- [`checklists/fase2-diagnostico-asr.md`](./03-funcionalidades/checklists/fase2-diagnostico-asr.md) — diagnóstico ASR pré-Fase 2: dump WAV+TXT por captura, 5 frases-teste pra isolar inversão de sentido (sinal vs modelo vs prompt).
- [`checklists/fase2a-manual.md`](./03-funcionalidades/checklists/fase2a-manual.md) — aceite manual da Fase 2a (backend submenu, style submenu, modal API key, fallback Identity, retenção do history, injeção em apps reais).

### 04 — Decisões (ADRs)
- [`ADR-0001-sistema-visual.md`](./04-decisoes/ADR-0001-sistema-visual.md) — sistema visual, identidade, indicador default da v1, mudanças de escopo aceitas/recusadas.
- [`ADR-0003-pipeline-2a.md`](./04-decisoes/ADR-0003-pipeline-2a.md) — pipeline da Fase 2a: 16 decisões nucleares (refiners, persistência, UI mínima, cleanups #2 e #4).
- [`cleanup-fase1.md`](./04-decisoes/cleanup-fase1.md) — TODOs deixados na Fase 1 (L/R Option, promptTokens, drift visual). Revisitar em 2026-05-11.
- [`cleanup-fase2a.md`](./04-decisoes/cleanup-fase2a.md) — achados do aceite manual da Fase 2a. Itens 1, 3 e 4 fechados em 2026-04-29. Itens 2 e 5 empurrados pra 2b-2 e 2b-3. Revisitar em 2026-05-12.
- [`cleanup-fase2b1.md`](./04-decisoes/cleanup-fase2b1.md) — achados do aceite manual da Fase 2b-1 em 2026-04-29. 2 fixes aplicados durante o aceite (z-order popover, rewriter discipline pra custom styles); 2 conhecidos (histórico viewer = 2b-2, cancel HTTP = 2b-3). Revisitar em 2026-05-13.

### 05 — [Sistema visual](./05-design/README.md)
Identidade, tokens, tipografia, cores, copy pt-BR, catálogo de componentes e bundle do Claude Design (`05-design/bundle/`). Fonte da verdade visual.

### specs/
- [`2026-04-26-tagarela-v1-design.md`](./specs/2026-04-26-tagarela-v1-design.md) — design consolidado da v1 (incorporando decisões visuais).
- [`2026-04-26-tagarela-v1-fase1-plan.md`](./specs/2026-04-26-tagarela-v1-fase1-plan.md) — plano de implementação da Fase 1 (esqueleto end-to-end "ditado puro"; 30 tarefas).
- [`2026-04-27-tagarela-v1-fase2a-design.md`](./specs/2026-04-27-tagarela-v1-fase2a-design.md) — design da Fase 2a. **Status: implementado** (2026-04-27).
- [`2026-04-27-tagarela-v1-fase2a-plan.md`](./specs/2026-04-27-tagarela-v1-fase2a-plan.md) — plano executado da Fase 2a (16 tarefas, 81 testes verdes ao fim).
- [`2026-04-29-tagarela-v1-fase2b1-design.md`](./specs/2026-04-29-tagarela-v1-fase2b1-design.md) — design da Fase 2b-1 (Preferências + Custom styles + Endpoints custom OpenAI + Localizable total). **Status: implementado** (branch `fase-2b1`, 115 testes verdes; aceite manual pendente).
- [`2026-04-29-tagarela-v1-fase2b1-plan.md`](./specs/2026-04-29-tagarela-v1-fase2b1-plan.md) — plano de implementação da Fase 2b-1 (14 tarefas, +34 testes, suíte 115).

---

## Convenções

- **Idioma:** português brasileiro nas notas e na UI; inglês em código.
- **Datas:** ISO `YYYY-MM-DD`.
- **Links:** preferir wikilinks Obsidian (`[[nota]]`) entre notas internas; markdown links (`[texto](path)`) para arquivos fora do vault.
- **ADRs:** numerados sequencialmente (`ADR-0001-titulo.md`), com seções **Contexto / Decisão / Consequências / Alternativas**.
