---
data: 2026-05-01
status: aberto
revisitar_em: quando bench da Fase 3 ou ativo de UX disser que velocidade voltou a ser dor
---

# Cleanup pós-Fase 2d — backlog de performance

A Fase 2d entregou a infraestrutura de swap de modelo + picker + migration, mas o ganho de velocidade real do turbo (`large-v3_turbo`) ficou em **~8%** sobre `large-v3` neste hardware (não os 5–8× prometidos pela doc). Bench oficial em [`fase2d-manual.md` Bloco 5](../03-funcionalidades/checklists/fase2d-manual.md#bloco-5--bench-oficial-) e [`07-modulos-fase2d.md` § Bench](../02-arquitetura/07-modulos-fase2d.md#bench).

## 1. Investigar variants quantizadas do turbo — segue aberto

**Hipótese:** o repo `argmaxinc/whisperkit-coreml` tem variants pré-quantizadas que podem render ganho real maior:

- `openai_whisper-large-v3_turbo_954MB` — quantizado pesado.
- `openai_whisper-large-v3-v20240930_turbo_632MB` — versão "v20240930" do turbo + quantização agressiva.

**Hipótese complementar:** Whisper sempre processa janela de 30s. Pra ditado de ~3s o overhead fixo da janela domina. Bench em ditado mais longo (10–30s) pode mostrar ganho proporcional maior — decoder do turbo (4 layers vs 32) tem mais peso quando há mais tokens a gerar.

**Caminho proposto:**
1. Adicionar variant quantizada ao `WhisperModelCatalog` (com label tipo "turbo (rápido)" ou similar).
2. Bench: 5×3s + 5×15s em cada variant (large-v3, turbo full, turbo quantizado, e também `distil-large-v3` que ficou de fora do caminho conservador da v1).
3. Se algum variant der ganho real ≥ 3×, virar default. Senão, manter `large-v3_turbo` full-precision e desistir desse vetor.

**Bloqueado por:** disponibilidade de tempo + decisão sobre se velocidade volta a ser prioridade. A v1 atual é usável e foi aceita pelo user com o ganho de 8%.

## 2. `DecodingOptions` mais agressivo — não explorado

`temperatureFallbackCount` (default 5) controla quantas vezes o decoder retenta com temperatura maior se confidence cair. Setar `0` desliga e pode dar 2–3× em casos médios, com risco de alucinação em áudio difícil. Caminho conservador da v1 deixou de fora; revisitar quando turbo full estiver "esgotado" como vetor.

## Status

Backlog informativo. Não bloqueia release da Fase 3 (release engineering) — turbo entrega o pequeno ganho que tem, e infra de swap está pronta caso uma futura investigação destrave ganho real.
