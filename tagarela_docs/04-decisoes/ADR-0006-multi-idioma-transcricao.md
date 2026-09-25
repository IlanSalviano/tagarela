---
data: 2026-05-27
status: aceita
---

# ADR-0006 — Idioma de transcrição configurável com auto-detecção como default

## Contexto

Até a v1.0.2 o `language` da transcrição estava fixado em `"pt"` no `PipelineCoordinator`
e nunca era sobrescrito no `AppContainer`. O Whisper era forçado a decodificar qualquer
fala como pt-BR. Falar inglês produzia transcrição "aportuguesada" — uso não suportado.

O `DecodingOptions` do WhisperKit aceita `language: String?` e `detectLanguage: Bool`. A
auto-detecção dispara em `TranscribeTask.run` quando o modelo é multilíngue, `language ==
nil` e `detectLanguage == true`. O default `large-v3_turbo` é multilíngue. O `initialPrompt`
já é `nil` por [ADR-0005](./ADR-0005-vocab-biasing-desabilitado.md), então não há
acoplamento idioma↔prompt.

## Decisão

1. Introduzir o enum `TranscriptionLanguage { auto, pt, en }` com
   `whisperCode: String?` (`nil` para `auto`).
2. Persistir `PreferencesStore.transcriptionLanguage`, **default `.auto`**.
3. `Transcribing.transcribe` passa a receber `language: String?`. No
   `WhisperKitTranscriber`, `detectLanguage: language == nil` — idioma explícito (pt/en)
   mantém `detectLanguage: false` e o path atual inalterado.
4. `PipelineCoordinator` troca o `language` fixo por `languageProvider: () -> String?`
   (mesmo padrão dos outros providers); o `AppContainer` injeta
   `prefs.transcriptionLanguage.whisperCode`. Idioma é stateless → **sem** coordinator de
   swap (diferente do modelo Whisper).
5. UI: picker **Automático · Português · English** apenas em Preferências > Transcrição.
   Sem onboarding.

### Default = Automático, inclusive para usuários existentes

Instalações da v1.0.2 não têm a chave `transcriptionLanguage` persistida, então caem no
default `.auto` na primeira execução pós-update. É uma **mudança de comportamento
deliberada** (antes: pt fixo; depois: auto-detect). Quem quiser o comportamento antigo
seleciona "Português" no picker.

## Consequências

### Positivas
- Transcrição de inglês passa a funcionar (e de outros idiomas que o Whisper detecte, na
  prática, via auto).
- Sem reload de modelo na troca de idioma — vale na próxima transcrição.
- Idioma explícito (pt/en) preserva o path pt-only exatamente como antes — zero regressão
  quando escolhido.

### Negativas
- **Latência:** auto-detect adiciona uma passada de decode por transcrição, contra o
  esforço de velocidade da [Fase 2d](../specs/2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-design.md).
- **Misdetect em ditado curto:** frases muito curtas podem ter o idioma detectado errado.
  Trade-off aceito em troca da conveniência. Quem dita majoritariamente em um idioma pode
  fixar pt ou en pra eliminar o risco e a latência.
- Mudança de comportamento silenciosa para usuários existentes (ver acima).

### Neutras
- A UI continua pt-BR; idioma de transcrição é eixo ortogonal ao idioma da interface.

## Alternativas consideradas

1. **Seletor manual sem auto (pt/en).** Mais previsível e sem latência, mas exige trocar a
   cada mudança de idioma. Rejeitado: usuário priorizou conveniência.
2. **Seletor + Automático com default pt.** Preservaria o comportamento atual por padrão.
   Rejeitado: usuário escolheu auto como default explicitamente.
3. **Auto-detecção pura, sem opções explícitas.** Não permitiria fixar idioma pra eliminar
   misdetect/latência. Rejeitado: pt/en explícitos são baratos e úteis como override.

## Como revisitar

Se a latência ou o misdetect em ditado curto incomodar no uso real, reconsiderar o default
(auto → pt) ou expor o picker também no onboarding. Catálogo de idiomas é extensível pelo
enum `TranscriptionLanguage`.

---

## Revisão 2026-09-24 — o modo Automático nunca funcionou para português

**O que aconteceu.** Em campo, com a preferência em Automático, quatro ditados em
português foram detectados como `en`, `it`, `en` e `en` — um deles com **32
segundos**. Frase curta explica errar em 1,8 s; não explica errar em 32 s de fala
clara. Não era o trade-off de "misdetect em ditado curto" registrado acima: era
defeito.

**Causa (lida no código do WhisperKit 0.18.0).** Com `usePrefillPrompt: true` e
`usePrefillCache: true` (os dois são default), o `TranscribeTask` pré-preenche o KV
cache do decoder **antes** de detectar o idioma. Com `language == nil`, o
pré-preenchimento usa `Constants.defaultLanguageCode`, que é `"en"`:

```swift
// TextDecoder.prefillDecoderInputs
let languageTokenString = "<|\(options.language ?? Constants.defaultLanguageCode)|>"
```

A detecção roda depois, sobre esse mesmo cache já contendo `<|en|>`. O resultado
não é "sempre inglês" — é uma escolha corrompida: `en`, `it` e, no teste de
integração, **9,6 s de português sintetizado detectados como `fr`**.

Isso explica também o aceite da Fase 4 ter ficado `ok-parcial` com **só o inglês**
confirmado no Automático: o viés favorece inglês, então o caso que passou era o que
o bug deixava passar. O português nunca foi confirmado em modo Automático.

**Decisão revisada.** O `WhisperKitTranscriber` não delega mais a detecção ao
`transcribe`:

1. Em Automático, chama o `detectLangauge(audioArray:)` público, que monta o
   decoder do zero (`prepareDecoderInputs(withPrompt: [SOT])`) e portanto não herda
   o viés.
2. Resolve o resultado para o conjunto que o app oferece: **inglês se o Whisper
   disse inglês, português em qualquer outro caso.** O seletor só tem pt e en, e as
   confusões clássicas do Whisper com português são galego, espanhol, italiano e
   francês.
3. Transcreve com o idioma **explícito** e `detectLanguage: false` — exatamente o
   caminho de idioma fixo, que funcionou por meses com `pt`.

**Custo:** uma passada de encoder a mais por ditado em modo Automático. A API
pública só devolve o idioma vencedor (não a distribuição), por isso a restrição a
pt/en é por regra, não por argmax sobre as probabilidades.

**Verificado com o modelo real.** `LanguageDetectionIntegrationTests` sintetiza fala
em português com o `say` do macOS e roda o `large-v3_turbo` de verdade — vermelho
antes (`fr`), verde depois (`pt`, com a palavra "português" na transcrição, ou seja,
transcrição e não tradução). Roda só com `TAGARELA_INTEGRATION=1`, porque carrega o
modelo de 3 GB.

**O que isso muda na seção "Como revisitar".** A dúvida sobre trocar o default para
`pt` deixa de ser necessária por causa de misdetect — o Automático agora acerta o
português. Continua valendo revisitar se o encoder extra pesar na latência.
