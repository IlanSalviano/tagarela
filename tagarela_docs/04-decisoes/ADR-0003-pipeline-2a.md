---
data: 2026-04-27
status: aprovado e implementado
fase: 2a
---

# ADR-0003 — Pipeline da Fase 2a (persistência + LLM)

Snapshot das 16 decisões nucleares do brainstorming de 2026-04-27 que viraram código na Fase 2a. Confirmadas em produção após execução do plano.

## Contexto

A Fase 2 do design v1 era monolítica (~9 áreas + 2 cleanups). Brainstorming de 2026-04-27 dividiu em 2a (persistência + LLM funcionando) e 2b (UI rica + polish). Este ADR documenta as decisões da 2a; a 2b terá ADR próprio.

## Decisões

| # | Decisão |
|---|---|
| F2a-1  | Fase 2 dividida em 2a (este ADR) + 2b (futuro) |
| F2a-2  | Cleanups #2 e #4 do `cleanup-fase1.md` entram explicitamente na 2a |
| F2a-3  | OpenAI implementado **antes** de Ollama; Identity polido no fim |
| F2a-4  | OpenAI default `gpt-5.4-mini`, baseURL fixo `https://api.openai.com/v1` |
| F2a-5  | 4 presets built-in **hardcoded**, sem mecanismo custom ainda |
| F2a-6  | Submenu de estilos na status bar já na 2a |
| F2a-7  | Submenu de backend na status bar já na 2a |
| F2a-8  | Health check Ollama (timeout 2s, cache 30s) completo |
| F2a-9  | Retenção do `HistoryStore` aplicada a cada `save()` |
| F2a-10 | API key OpenAI via modal `NSPanel` acionada pelo submenu |
| F2a-11 | Cobertura ampla de testes (~25-30 novos) |
| F2a-12 | Trunca-com-marcador para context window (40%/40%/20%, retry 30%/30%) |
| F2a-13 | Localizable.strings criado na 2a só pra strings novas |
| F2a-14 | Cleanup #2 com checklist A/B (env var `TAGARELA_DISABLE_PROMPT=1`) |
| F2a-15 | Vocab inicial: ~50 termos hardcoded em `DefaultVocabulary.swift` |
| F2a-16 | Cleanup #4: chave única `audioBoostMaxGain: Float` (default 20, range 1-50) |

## Consequências

- O usuário pode trocar entre **Sem LLM / Ollama / OpenAI** e entre os 4 estilos sem CLI.
- API key da OpenAI é cadastrada via modal `NSPanel`.
- Falha de refiner remoto cai pra `IdentityRefiner` automaticamente — o usuário nunca fica sem texto colado.
- Histórico de transcrições persiste entre sessões com retenção 200/30 (default), sem UI ainda — vai entrar na 2b.
- Cleanup #2 está code-side concluído mas a decisão final (manter/remover prompt) depende do A/B do usuário humano (ADR-0002 vem depois).
- Cleanup #4 fechado: gain configurável via `defaults write com.tagarela.preferences audioBoostMaxGain -float <N>`.
- Suíte de testes saiu de 16 (Fase 1) pra 81 (fim da 2a).

## Alternativas consideradas e rejeitadas

- Plano monolítico único pra Fase 2 inteira: rejeitado (volume grande demais; risco de não shippar nada antes do fim).
- Ollama antes de OpenAI: rejeitado em F2a-3 (OpenAI é caminho HTTP mais simples; Ollama tem health check + offline detection — vale ser segundo).
- Custom styles já na 2a: rejeitado em F2a-5 (sem UI de criar/editar style na 2a — overhead sem benefício).
- Endpoints custom OpenAI (Azure/OpenRouter/LM Studio): rejeitado pra v2 do produto.
- AGC RMS-based no audio: rejeitado em F2a-16 (peak normalize é suficiente; AGC adiciona DSP complexo).

## Referências

- Design da 2a: [`specs/2026-04-27-tagarela-v1-fase2a-design.md`](../specs/2026-04-27-tagarela-v1-fase2a-design.md)
- Plano da 2a: [`specs/2026-04-27-tagarela-v1-fase2a-plan.md`](../specs/2026-04-27-tagarela-v1-fase2a-plan.md)
- Checklist manual: [`03-funcionalidades/checklists/fase2a-manual.md`](../03-funcionalidades/checklists/fase2a-manual.md)
- Checklist A/B promptTokens: [`03-funcionalidades/checklists/fase2-validacao-prompt.md`](../03-funcionalidades/checklists/fase2-validacao-prompt.md)
- Design v1 base: [`specs/2026-04-26-tagarela-v1-design.md`](../specs/2026-04-26-tagarela-v1-design.md)
- ADR-0001 sistema visual: [`ADR-0001-sistema-visual.md`](./ADR-0001-sistema-visual.md)
