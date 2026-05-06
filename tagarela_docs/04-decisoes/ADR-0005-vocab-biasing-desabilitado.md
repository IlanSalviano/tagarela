---
data: 2026-05-06
status: aceita
revisitar_em: 2026-06-15
---

# ADR-0005 — Vocab biasing (`promptTokens`) desabilitado temporariamente

## Contexto

A Fase 2a (Tarefa 8, abril/2026) ativou o vocab biasing do Whisper passando `promptTokens` no `DecodingOptions`, montados via `InitialPromptBuilder.build(vocab:)` + `WhisperKit.tokenizer.encode(prompt)`. A intenção era melhorar a transcrição de termos técnicos (`Postgres`, `Kubernetes`, `deploy`, …) cadastrados em `prefs.technicalVocabulary`.

Em 2026-05-05/06, investigando bug reportado como "ditado longo não injeta", descobrimos que **a causa não era injeção** — era WhisperKit retornando `transcribed: ''`. A injeção colava string vazia.

A investigação 2026-05-06 isolou:

- `noSpeechThreshold` default `0.6` suprimia janelas em fala quieta. Setado pra `nil` resolveu essa supressão (`noSpeechProb=0.000`), mas o sintoma persistiu.
- Hipótese inicial "tamanho do prompt" (177 tokens > limite Whisper) caiu: prompt reduzido pra 72 tokens ainda quebrava.
- Hipótese "interação com chunked decode" (audio > 30s) caiu: bug se reproduziu em audio de 16.9s single-chunk.
- Padrão final observado: **qualquer `promptTokens` não-nulo causa o decoder a bail imediatamente** após o prefill, gerando só `<|endoftext|>`. Métricas zeradas (`avgLogprob=0.000`, `compRatio=0.00`) confirmam que o modelo não decodificou conteúdo. Wall time ~1.8s pra 16s de audio (vs ~3-10s normal) confirma o short-circuit.
- Validação cruzada: `TAGARELA_DISABLE_PROMPT=1` (drop completo do prompt) retorna transcrição íntegra em todos os tamanhos testados.

Causa-raiz exata **não identificada**. Suspeita: interação entre `usePrefillPrompt: true` + `withoutTimestamps: true` + `promptTokens` no WhisperKit 0.9 atual. Possíveis investigações futuras:

- Testar `usePrefillPrompt: false` quando há `promptTokens`.
- Testar `withoutTimestamps: false` (com timestamps) + `promptTokens`.
- Reduzir `initialPrompt` pra apenas vocab cru (sem a frase base "Transcrição em português brasileiro de desenvolvedor de software.") — talvez o meta-text seja interpretado como "já transcrevi tudo".
- Auditar issues do WhisperKit pra problemas conhecidos de prompt + decode.

## Decisão

`WhisperKitTranscriber.transcribe` passa **sempre** `promptTokens: nil`, ignorando o `initialPrompt` recebido como parâmetro. Em código:

```swift
// promptTokens (vocab biasing) está desabilitado: qualquer prompt
// envenena o prefill, decoder bail e gera só `<|endoftext|>`. (...)
_ = initialPrompt

let opts = DecodingOptions(
    // ...
    promptTokens: nil,
    noSpeechThreshold: nil
)
```

O parâmetro `initialPrompt: String?` continua no protocolo `Transcribing` pra preservar compat de testes e permitir reintrodução futura sem alterar callsites.

A infraestrutura de vocab continua viva:
- `PreferencesStore.technicalVocabulary` ainda persiste a lista.
- A UI em Preferências > Transcrição ainda permite editar.
- `InitialPromptBuilder` ainda existe (com guard token-aware adicionado em 2026-05-06: `maxTokens = 80`, fallback char-based pessimista).
- `AppContainer` ainda passa o `initialPromptProvider` pro `PipelineCoordinator`.

Tudo isso fica como infraestrutura morta no caminho do Whisper, prontoa pra reativação.

## Consequências

### Positivas

- Confiabilidade: ditado de qualquer duração com qualquer perfil de áudio agora transcreve corretamente.
- Bug "ditado longo volta vazio" — relatado originalmente como bug de injeção — fechado.
- `noSpeechThreshold: nil` (introduzido na investigação) fica como bônus permanente: evita supressão de fala quieta.

### Negativas

- Vocab biasing perdido: termos técnicos, especialmente palavras inglesas em meio a fala pt-BR (ex: "deploy", "Kubernetes"), podem ser transcritos foneticamente errado mais frequentemente. **Não medido empiricamente quanto** — Tarefa 8 da Fase 2a marcou A/B como pendente, e não chegou a rodar.
- Infra morta: ~30 linhas em `InitialPromptBuilder`, `AppContainer.initialPromptProvider`, e o param `initialPrompt` no protocolo. Optamos por não remover pra facilitar reintrodução.

### Neutras

- Env var `TAGARELA_DISABLE_PROMPT=1` agora é redundante (default já é equivalente). Mantida no código pra debug histórico — desligá-la não muda comportamento atual.

## Alternativas consideradas

1. **Truncar prompt em N tokens.** Implementado e descartado — bug se reproduziu com 72 tokens, abaixo de qualquer limite plausível.
2. **Drop prompt apenas em chunked decode (audio > 30s).** Implementado e descartado — bug se reproduziu em audio de 16.9s single-chunk.
3. **Drop prompt apenas se `prefs.technicalVocabulary` vazia.** Não atacaria a causa: a frase base "Transcrição em português..." sozinha pode ser suficiente pra envenenar.
4. **Testar `usePrefillPrompt: false`.** Cogitado mas não testado — cada rebuild custa ~1min + retoggle de TCC. Adiado pra investigação dedicada.

A decisão atual (drop total) prioriza confiabilidade sobre vocab; alternativas 1–4 reduzem mas não eliminam o risco enquanto a causa-raiz for desconhecida.

## Como revisitar

Item 2 do [`cleanup-fase1.md`](./cleanup-fase1.md) segue aberto. Quando alguém retomar:

1. Rodar testes A/B em [`checklists/fase2-validacao-prompt.md`](../03-funcionalidades/checklists/fase2-validacao-prompt.md) **com vs sem prompt** pra quantificar o ganho potencial — se for marginal, considerar remover toda a infra de vocab.
2. Se o ganho for material, investigar as suspeitas listadas em "Contexto" acima, uma por vez, com instrumentação dos segments (mesmas DIAG removidas em 2026-05-06 — git history em `WhisperKitTranscriber.swift`).
3. Quando reativar, atualizar este ADR com status "superada por ADR-XXXX" e fechar item 2 do cleanup-fase1.
