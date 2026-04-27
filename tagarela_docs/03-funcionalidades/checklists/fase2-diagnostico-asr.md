---
data: 2026-04-27
status: concluído (2026-04-27)
escopo: diagnóstico pré-Fase 2
---

# Diagnóstico ASR — inversão de sentido na transcrição

> **Resultado (2026-04-27):** sintoma era bug de embaralhamento no downmix do `AudioCaptureLive` (não modelo, não áudio, não prompt). Detalhes em [`cleanup-fase1.md` item 5](../../04-decisoes/cleanup-fase1.md). Após o fix, 5/5 frases-teste saíram fiéis. Achado secundário: Whisper formaliza orality ("tá"→"está", "pra"→"para") na ausência de `initialPrompt` — endereçar via cleanup #2 ou via cláusula `preserveOrality` no `TextRefiner` da Fase 2.
>
> **Instrumentação revertida** após conclusão (mesma data): `app/Tagarela/Diagnostics/` removido, chamadas `DiagnosticRecorder.*` retiradas de `AudioCaptureLive` e `PipelineCoordinator`, samples em `~/Library/Logs/tagarela/diag/` apagados. Pra re-rodar este diagnóstico, restaurar via `git show HEAD~1`.

Sessão curta antes do brainstorming da Fase 2 pra isolar a causa do sintoma observado: "o app inverte o sentido das frases que falo".

Hipóteses em ordem de probabilidade:

1. **Áudio fraco/ruidoso** — peak ~0.07 antes do boost 20× amplifica ruído junto com voz; Whisper alucina frases curtas no sentido oposto.
2. **`initialPrompt` descartado** — sem viés de domínio, modelo escolhe interpretação mais comum em qualquer idioma; veja [`cleanup-fase1.md` item 2](../../04-decisoes/cleanup-fase1.md#2-initialprompt--prompttokens-no-whisperkittranscriber).
3. **Modelo (`large-v3`)** — improvável, é o maior que cabe localmente.

`TextRefiner` (Ollama/OpenAI da Fase 2) **não conserta inversão de sentido** — opera em cima do texto cru. ASR ruim → refiner pole o erro.

## Como rodar

A instrumentação já está ligada por padrão (env var `TAGARELA_DIAG=0` desativa).

Cada captura escreve dois arquivos em `~/Library/Logs/tagarela/diag/`:

- `<timestamp>.wav` — PCM 16-bit mono 16 kHz, exatamente o que o Whisper recebeu (já com peak-normalize aplicado)
- `<timestamp>.txt` — metadados + texto cru transcrito

Metadados no `.txt`:

```
timestamp: 2026-04-27T15-12-04
source_sample_rate: 48000 Hz
source_channels: 2
peak_before_boost: 0.0712
peak_after_boost: 0.6000
boost_gain: 8.43x
duration_seconds: 3.42
buffer_samples: 54720
whisper_model: openai_whisper-large-v3
language: pt
initial_prompt: <nil>
--- raw text ---
não quero ir pra reunião amanhã
```

## Frases-teste

Falar cada uma **com clareza, ritmo natural, distância normal do mic**. Apertar `right ⌥` antes e depois. Não emendar uma na outra — uma captura por frase pra isolar.

| # | Frase | Sentido esperado | Observação |
|---|---|---|---|
| 1 | não quero ir pra reunião amanhã | negativo (recusa) | inversão = "quero ir" |
| 2 | isso aqui não tá funcionando direito | negativo (queixa) | inversão = "tá funcionando" |
| 3 | a gente nunca testou esse caso | nunca | inversão = "sempre testou" |
| 4 | esse deploy não vai pra produção hoje | bloqueio | inversão = "vai pra produção" |
| 5 | eu não consegui reproduzir o bug | falha | inversão = "consegui reproduzir" |

## Resultado

Para cada arquivo gerado, marcar:

- [ ] **Frase 1** — texto cru: `___` — fiel? ☐ sim ☐ inverteu sentido ☐ outro erro: `___`
- [ ] **Frase 2** — texto cru: `___` — fiel? ☐ sim ☐ inverteu sentido ☐ outro erro: `___`
- [ ] **Frase 3** — texto cru: `___` — fiel? ☐ sim ☐ inverteu sentido ☐ outro erro: `___`
- [ ] **Frase 4** — texto cru: `___` — fiel? ☐ sim ☐ inverteu sentido ☐ outro erro: `___`
- [ ] **Frase 5** — texto cru: `___` — fiel? ☐ sim ☐ inverteu sentido ☐ outro erro: `___`

Para cada `.wav`, dar play e classificar a qualidade do sinal:

- [ ] Áudio nítido, voz clara, ruído baixo (5/5)
- [ ] Áudio audível mas com chiado/eco (3-4/5)
- [ ] Áudio baixo / mascarado por ruído (1-2/5)

## Análise

| Inversões | Áudio | Conclusão | Próximo passo |
|---|---|---|---|
| 4-5/5 | nítido | Modelo / falta de prompt | Tentar `promptTokens` antes de trocar modelo |
| 4-5/5 | ruim | Sinal | Reduzir gain hardcoded, melhorar mic/posicionamento |
| 1-2/5 | qualquer | Ruído estatístico esperado em PT-BR | Não bloqueia Fase 2 |
| 0/5 | qualquer | Caso isolado da sessão original | Não bloqueia Fase 2 |

## Como reverter a instrumentação

Quando o diagnóstico estiver concluído:

1. Remover `app/Tagarela/Diagnostics/DiagnosticRecorder.swift`
2. Remover chamadas `DiagnosticRecorder.*` de:
   - `app/Tagarela/Audio/AudioCaptureLive.swift`
   - `app/Tagarela/Pipeline/PipelineCoordinator.swift`
3. `xcodegen generate` + `xcodebuild test`
4. Deletar `~/Library/Logs/tagarela/diag/` (samples e textos do diagnóstico)
5. Atualizar [`02-arquitetura/01-modulos-fase1.md`](../../02-arquitetura/01-modulos-fase1.md) com o achado.

Se o diagnóstico mostrar que vale manter o dump como feature opt-in (ex: pra suporte futuro), promover pra um módulo `Diagnostics` real e gateado em `PreferencesStore` (Fase 2).
