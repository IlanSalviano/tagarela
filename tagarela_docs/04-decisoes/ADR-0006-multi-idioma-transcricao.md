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
