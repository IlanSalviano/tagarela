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
- [`00-setup-dev.md`](./02-arquitetura/00-setup-dev.md) — onboard de um Mac novo pra dev: builds Debug, permissões TCC, build pipeline de release.
- [`01-modulos-fase1.md`](./02-arquitetura/01-modulos-fase1.md) — snapshot dos módulos implementados na Fase 1, divergências do plano, cobertura de testes, escopo das próximas fases.
- [`02-stack-tecnica.md`](./02-arquitetura/02-stack-tecnica.md) — versões reais (Xcode/Swift/macOS), uso de xcodegen como fonte da verdade do projeto, dependências SPM (WhisperKit), fontes empacotadas, capabilities.
- [`03-modulos-fase2b1.md`](./02-arquitetura/03-modulos-fase2b1.md) — snapshot pós-Fase 2b-1: módulos novos (Preferências UI, custom styles, endpoints custom OpenAI), modificados (factory consulta StyleProvider, container SwiftData compartilhado), cleanups da 2a fechados (#1, #3, #4) e abertos (#2, #5).
- [`04-modulos-fase2b2.md`](./02-arquitetura/04-modulos-fase2b2.md) — snapshot pós-Fase 2b-2: toasts (`ToastCenter`), 3 novas variações de indicator (Orb/Vertical/HUD) com picker visual, visualizador de histórico embutido em Preferências, submenu "Recentes" na status bar, novos `PipelineEvent` (refinerFellBack/injectionFailed/historySaveFailed/permissionDenied). Fecha cleanup #2 da 2a e cleanup #3 da 2b-1.
- [`05-modulos-fase2b3.md`](./02-arquitetura/05-modulos-fase2b3.md) — snapshot pós-Fase 2b-3 (encerra a Fase 2b): `PipelineCoordinator` com `pipelineTask` Task armazenada + helper `aborted()` (cancel HTTP em vôo via `Task.cancel()`), `CustomStyle` com campo `bypassDiscipline` + `asStyle()` condicional, `CustomStyleEditSheet` com toggle "Modo refinador" + warning inline. Fecha cleanup #5 da 2a e cleanups #2 follow-up + #4 da 2b-1.
- [`06-modulos-fase2c-cleanup.md`](./02-arquitetura/06-modulos-fase2c-cleanup.md) — snapshot pós-Fase 2c-cleanup. Tentou 4 itens; só 2 entregaram código líquido (cleanup #1 da Fase 1 fechado, #3 retroativo). Refactor `IndicatorViewModel` (cleanups #8 da Fase 1 + #1 da 2b-3) e WhisperKit `downloadBase` (cleanup #9 da Fase 1) revertidos após regressão runtime detectada no aceite manual. Lição: spec compliance + code review não cobre regressão funcional — rodar aceite em build local **antes** do merge. **Fix posterior (mesmo dia):** sombra `dsShadowPop` removida dos 4 indicators (criava halo retangular em fundo claro).
- [`07-modulos-fase2d.md`](./02-arquitetura/07-modulos-fase2d.md) — snapshot pós-Fase 2d (velocidade): default Whisper agora é `large-v3_turbo` (underscore — nome real do repo `argmaxinc/whisperkit-coreml`), picker funcional em Onboarding e em Preferências > Transcrição, knobs ANE+prewarm no `WhisperKitConfig`, instrumentação de timing via `Logger.tagarela`, `WhisperModelSwapCoordinator` orquestrando swap em runtime sem interromper hotkey, migration que preserva modelo já em disco em users existentes. Fecha bug latente dos radios decorativos do Onboarding. Suíte 155 → 181.
- [`08-modulos-fase3.md`](./02-arquitetura/08-modulos-fase3.md) — snapshot pós-Fase 3 (release engineering): Developer ID Application + entitlements completos + notarization + DMG + Sparkle minimal + 7 scripts modulares + setup-dev. v1.0.0, v1.0.1 e v1.0.2 publicadas em GitHub Releases (v1.0.2 carrega o fix do prefill poisoning — ADR-0005). Cleanup #6 da Fase 1 (TCC manual via SQL) **fechado** — popups nativos voltaram pós Developer ID.
- [`09-modulos-fase4.md`](./02-arquitetura/09-modulos-fase4.md) — snapshot pós-Fase 4 (multi-idioma): idioma de transcrição configurável (`TranscriptionLanguage` + picker Automático/Português/English em Preferências), default **Automático** via auto-detecção do WhisperKit (`detectLanguage: language == nil`). `language` no `PipelineCoordinator` passa de valor fixo `"pt"` a `languageProvider: () -> String?`; protocolo `Transcribing` muda pra `language: String?`. ADR-0006. Suíte 181 → 186.

### 03 — Funcionalidades
- [`checklists/fase1-manual.md`](./03-funcionalidades/checklists/fase1-manual.md) — checklist manual de aceite da Fase 1 (onboarding, status bar, pipeline, apps de injeção, edge cases, performance).
- [`checklists/fase2-diagnostico-asr.md`](./03-funcionalidades/checklists/fase2-diagnostico-asr.md) — diagnóstico ASR pré-Fase 2: dump WAV+TXT por captura, 5 frases-teste pra isolar inversão de sentido (sinal vs modelo vs prompt).
- [`checklists/fase2a-manual.md`](./03-funcionalidades/checklists/fase2a-manual.md) — aceite manual da Fase 2a (backend submenu, style submenu, modal API key, fallback Identity, retenção do history, injeção em apps reais).
- [`checklists/fase2c-cleanup-manual.md`](./03-funcionalidades/checklists/fase2c-cleanup-manual.md) — aceite manual da Fase 2c-cleanup (apenas Blocos D + E após reverts). Status `ok-com-achados`: Bloco E (L/R Option) ✅, Bloco D (downloadBase) ❌.
- [`checklists/fase2d-manual.md`](./03-funcionalidades/checklists/fase2d-manual.md) — aceite manual da Fase 2d (9 blocos: onboarding picker, swap fluxo feliz, erro/retry, migration, não-regressão, bench oficial). Status `ok`. Bench: turbo é só ~8% mais rápido que large-v3 neste hardware (esperado eram 5–8×). Variants quantizadas + ditado longo ficaram em [`cleanup-fase2d.md`](./04-decisoes/cleanup-fase2d.md).
- [`checklists/fase3-manual.md`](./03-funcionalidades/checklists/fase3-manual.md) — aceite manual da Fase 3 (5 blocos: release end-to-end, Gatekeeper, TCC nativo, Sparkle, botão Console). Status `ok`. 3 bugs do pipeline pegos no aceite (todos fechados); v1.0.0 + v1.0.1 publicadas via `release.sh`.
- [`checklists/fase4-manual.md`](./03-funcionalidades/checklists/fase4-manual.md) — aceite manual da Fase 4 (5 blocos: pt explícito sem regressão, en explícito, Automático pt/en, frase curta no auto, troca em runtime + migração). Status `ok-parcial` (auto-detecção en confirmada em runtime pelo usuário em 2026-05-27).
- [`troubleshooting-runtime.md`](./03-funcionalidades/troubleshooting-runtime.md) — sintomas observados em uso real (v1.0.x) com remediação. Entrada inicial: `transcribed: ''` após horas + churn de Accessibility, resolvido com `Cmd+Q` total + relaunch.

### 04 — Decisões (ADRs)
- [`ADR-0001-sistema-visual.md`](./04-decisoes/ADR-0001-sistema-visual.md) — sistema visual, identidade, indicador default da v1, mudanças de escopo aceitas/recusadas. **Revisado parcialmente pelo ADR-0004** (histórico viewer entra na 2b-2).
- [`ADR-0003-pipeline-2a.md`](./04-decisoes/ADR-0003-pipeline-2a.md) — pipeline da Fase 2a: 16 decisões nucleares (refiners, persistência, UI mínima, cleanups #2 e #4).
- [`ADR-0004-historico-em-preferencias.md`](./04-decisoes/ADR-0004-historico-em-preferencias.md) — histórico viewer mora dentro de Preferências > Histórico (revisa ADR-0001).
- [`ADR-0005-vocab-biasing-desabilitado.md`](./04-decisoes/ADR-0005-vocab-biasing-desabilitado.md) — `promptTokens` (vocab biasing) sempre `nil` no `WhisperKitTranscriber` após bug crítico de 2026-05-06: qualquer prompt envenenava o decoder e produzia `transcribed: ''`. Causa-raiz não identificada; vocab continua na infra/UI esperando reintrodução.
- [`ADR-0006-multi-idioma-transcricao.md`](./04-decisoes/ADR-0006-multi-idioma-transcricao.md) — idioma de transcrição configurável (`TranscriptionLanguage { auto, pt, en }`), default **Automático** via auto-detecção do WhisperKit, inclusive pra users existentes (migração implícita). Trade-offs: latência da passada de detecção + risco de misdetect em ditado curto, aceitos em troca da conveniência. UI continua pt-BR (eixo ortogonal).
- [`cleanup-fase1.md`](./04-decisoes/cleanup-fase1.md) — TODOs deixados na Fase 1 (L/R Option, promptTokens, drift visual). Revisitar em 2026-05-11.
- [`cleanup-fase2a.md`](./04-decisoes/cleanup-fase2a.md) — achados do aceite manual da Fase 2a. **Todos os 5 itens fechados** (1-4 em 2026-04-29, item 5 fechado pela 2b-3 em 2026-04-30).
- [`cleanup-fase1.md`](./04-decisoes/cleanup-fase1.md) — atualizado pela 2c-cleanup em 2026-05-01: itens #1 e #3 fechados; itens #8 e #9 revertidos com hipóteses pra próxima tentativa; #2/#5/#6/#7 seguem bloqueados pelas razões originais.
- [`cleanup-fase2b1.md`](./04-decisoes/cleanup-fase2b1.md) — achados do aceite manual da Fase 2b-1. **Todos os 4 itens acionáveis fechados** (1-3 em 2026-04-29, item 2 follow-up + #4 fechados pela 2b-3 em 2026-04-30). Item 5 segue como grupo informacional.
- [`cleanup-fase2b3.md`](./04-decisoes/cleanup-fase2b3.md) — achados do aceite manual da Fase 2b-3. 1 funcional (pill flicker no Esc rápido — **tentado e revertido na 2c-cleanup**) + 8 polish minor. Revisitar 2026-05-15.
- [`cleanup-fase2d.md`](./04-decisoes/cleanup-fase2d.md) — backlog de performance da Fase 2d. Turbo entregou só ~8% sobre large-v3; explorar variants quantizadas (`_954MB`, `_632MB`), ditado longo, e `temperatureFallbackCount=0` quando velocidade voltar a ser dor.
- [`cleanup-fase3.md`](./04-decisoes/cleanup-fase3.md) — TCC zumbi por coexistência de builds locais + release Sparkle. Item 1 remediado em 2026-05-02 (`tccutil reset` revelou 4 registros stale por serviço). Follow-up de código opcional: banner Accessibility ausente + detector de duplicatas no startup.

### 05 — [Sistema visual](./05-design/README.md)
Identidade, tokens, tipografia, cores, copy pt-BR, catálogo de componentes e bundle do Claude Design (`05-design/bundle/`). Fonte da verdade visual.

### specs/
- [`2026-04-26-tagarela-v1-design.md`](./specs/2026-04-26-tagarela-v1-design.md) — design consolidado da v1 (incorporando decisões visuais).
- [`2026-04-26-tagarela-v1-fase1-plan.md`](./specs/2026-04-26-tagarela-v1-fase1-plan.md) — plano de implementação da Fase 1 (esqueleto end-to-end "ditado puro"; 30 tarefas).
- [`2026-04-27-tagarela-v1-fase2a-design.md`](./specs/2026-04-27-tagarela-v1-fase2a-design.md) — design da Fase 2a. **Status: implementado** (2026-04-27).
- [`2026-04-27-tagarela-v1-fase2a-plan.md`](./specs/2026-04-27-tagarela-v1-fase2a-plan.md) — plano executado da Fase 2a (16 tarefas, 81 testes verdes ao fim).
- [`2026-04-29-tagarela-v1-fase2b1-design.md`](./specs/2026-04-29-tagarela-v1-fase2b1-design.md) — design da Fase 2b-1 (Preferências + Custom styles + Endpoints custom OpenAI + Localizable total). **Status: implementado** (branch `fase-2b1`, 115 testes verdes; aceite manual pendente).
- [`2026-04-29-tagarela-v1-fase2b1-plan.md`](./specs/2026-04-29-tagarela-v1-fase2b1-plan.md) — plano de implementação da Fase 2b-1 (14 tarefas, +34 testes, suíte 115).
- [`2026-04-29-tagarela-v1-fase2b2-design.md`](./specs/2026-04-29-tagarela-v1-fase2b2-design.md) — design da Fase 2b-2 (Histórico visível + Indicadores B/C/D + Toasts + Cleanup #2 da 2a + estados de permissão + menu "últimos 5"). **Status: implementado** (branch `fase-2b2`, 145 testes verdes; aceite manual ✅).
- [`2026-04-29-tagarela-v1-fase2b2-plan.md`](./specs/2026-04-29-tagarela-v1-fase2b2-plan.md) — plano executado da Fase 2b-2 (16 tarefas, +30 testes, suíte 145).
- [`2026-04-30-tagarela-v1-fase2b3-design.md`](./specs/2026-04-30-tagarela-v1-fase2b3-design.md) — design da Fase 2b-3 (cancel HTTP em vôo via `Task.cancel()` + UX modo refinador/livre pros custom styles). **Status: implementado** (branch `fase-2b3`, 8 commits, 155 testes verdes, aceite manual ok-com-achados). Fecha cleanup #5 da 2a e cleanups #2 (follow-up) e #4 da 2b-1.
- [`2026-04-30-tagarela-v1-fase2b3-plan.md`](./specs/2026-04-30-tagarela-v1-fase2b3-plan.md) — plano executado da Fase 2b-3 (8 tarefas, +10 testes, suíte 155).
- [`2026-05-01-tagarela-v1-fase2c-cleanup-design.md`](./specs/2026-05-01-tagarela-v1-fase2c-cleanup-design.md) — design da Fase 2c-cleanup (bundle de manutenção pós-Fase 2b). **Status: parcialmente implementado** — Itens 1 (refactor `IndicatorViewModel`) e 4 (WhisperKit `downloadBase`) revertidos após regressão runtime; Itens 2 (cleanup #3 retroativo) e 3 (validação L/R Option) entregues.
- [`2026-05-01-tagarela-v1-fase2c-cleanup-plan.md`](./specs/2026-05-01-tagarela-v1-fase2c-cleanup-plan.md) — plano da Fase 2c-cleanup. Histórico do que foi tentado; ver design pro status real.
- [`2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-design.md`](./specs/2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-design.md) — design da Fase 2d (velocidade da transcrição: trocar default pra `large-v3_turbo`, picker funcional em Onboarding/Preferências, knobs ANE+prewarm, instrumentação de timing). **Status: implementado** (branch `fase-2d`, 11 commits, 181 testes verdes, aceite manual `ok` com bench oficial pendente).
- [`2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-plan.md`](./specs/2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-plan.md) — plano executado da Fase 2d (12 tarefas, +26 testes, suíte 181).
- [`2026-05-01-tagarela-v1-fase3-release-design.md`](./specs/2026-05-01-tagarela-v1-fase3-release-design.md) — design da Fase 3 (release engineering: Developer ID + notarization + DMG + Sparkle minimal + entitlements + setup-dev + validação cleanup #6 da Fase 1). **Status: implementado** (v1.0.0 e v1.0.1 publicadas em GitHub Releases).
- [`2026-05-01-tagarela-v1-fase3-release-plan.md`](./specs/2026-05-01-tagarela-v1-fase3-release-plan.md) — plano executado da Fase 3 (15 tarefas, 7 scripts em `scripts/`, +0 testes unitários, suíte 181).
- [`2026-05-27-tagarela-v1-fase4-multi-idioma-design.md`](./specs/2026-05-27-tagarela-v1-fase4-multi-idioma-design.md) — design da Fase 4 (idioma de transcrição configurável + auto-detecção default). **Status: implementado** (suíte 186 verde; aceite manual pendente). Decisão em ADR-0006.

---

## Convenções

- **Idioma:** português brasileiro nas notas e na UI; inglês em código.
- **Datas:** ISO `YYYY-MM-DD`.
- **Links:** preferir wikilinks Obsidian (`[[nota]]`) entre notas internas; markdown links (`[texto](path)`) para arquivos fora do vault.
- **ADRs:** numerados sequencialmente (`ADR-0001-titulo.md`), com seções **Contexto / Decisão / Consequências / Alternativas**.
