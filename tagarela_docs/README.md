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

### 03 — Funcionalidades
- [`checklists/fase1-manual.md`](./03-funcionalidades/checklists/fase1-manual.md) — checklist manual de aceite da Fase 1 (onboarding, status bar, pipeline, apps de injeção, edge cases, performance).

### 04 — Decisões (ADRs)
- [`ADR-0001-sistema-visual.md`](./04-decisoes/ADR-0001-sistema-visual.md) — sistema visual, identidade, indicador default da v1, mudanças de escopo aceitas/recusadas.
- [`cleanup-fase1.md`](./04-decisoes/cleanup-fase1.md) — TODOs deixados na Fase 1 (L/R Option, promptTokens, drift visual). Revisitar em 2026-05-11.

### 05 — [Sistema visual](./05-design/README.md)
Identidade, tokens, tipografia, cores, copy pt-BR, catálogo de componentes e bundle do Claude Design (`05-design/bundle/`). Fonte da verdade visual.

### specs/
- [`2026-04-26-tagarela-v1-design.md`](./specs/2026-04-26-tagarela-v1-design.md) — design consolidado da v1 (incorporando decisões visuais).
- [`2026-04-26-tagarela-v1-fase1-plan.md`](./specs/2026-04-26-tagarela-v1-fase1-plan.md) — plano de implementação da Fase 1 (esqueleto end-to-end "ditado puro"; 30 tarefas).

---

## Convenções

- **Idioma:** português brasileiro nas notas e na UI; inglês em código.
- **Datas:** ISO `YYYY-MM-DD`.
- **Links:** preferir wikilinks Obsidian (`[[nota]]`) entre notas internas; markdown links (`[texto](path)`) para arquivos fora do vault.
- **ADRs:** numerados sequencialmente (`ADR-0001-titulo.md`), com seções **Contexto / Decisão / Consequências / Alternativas**.
