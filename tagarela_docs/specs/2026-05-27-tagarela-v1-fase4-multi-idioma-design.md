---
data: 2026-05-27
status: em-implementação
fase: 4 (multi-idioma)
---

# Tagarela v1 — Fase 4: idioma de transcrição configurável (multi-idioma)

## Problema

Até a v1.0.2 o tagarela transcreve **só em português**. O `language` está fixado em
`"pt"` no `PipelineCoordinator` (init) e nunca é sobrescrito no `AppContainer`. Falar
inglês força o Whisper a decodificar como pt-BR, "aportuguesando" a saída — uso não
suportado.

O pedido do usuário: **poder transcrever inglês**.

## Decisões

Tomadas via brainstorming dirigido (perguntas respondidas em 2026-05-27):

1. **Mecanismo: auto-detecção de idioma.** O Whisper detecta o idioma falado por si.
2. **Default: `Automático`** — inclusive para instalações existentes (migração implícita
   pelo default, sem chave persistida). Mudança de comportamento consciente; quem quiser
   pt fixo seleciona "Português" no picker.
3. **Exposição: só em Preferências > Transcrição.** Sem picker no onboarding.
4. **Idiomas explícitos: pt + en** (além de Automático). Picker:
   **Automático · Português · English**.

### Viabilidade (WhisperKit)

`DecodingOptions.language` é `String?` e existe `detectLanguage: Bool`. A auto-detecção
dispara em `TranscribeTask.run` quando: modelo multilíngue **E** `language == nil` **E**
`detectLanguage == true`. O default `large-v3_turbo` é multilíngue → funciona. O
`initialPrompt` já é `nil` (ADR-0005), então não há acoplamento idioma↔prompt a desfazer.

## Escopo

- Novo enum `TranscriptionLanguage { auto, pt, en }` com `whisperCode: String?`
  (`nil` para auto).
- Preferência persistida `transcriptionLanguage` (default `.auto`), padrão `whisperModelName`.
- Protocolo `Transcribing.transcribe` muda `language: String` → `language: String?`.
- `WhisperKitTranscriber`: gating defensivo — `detectLanguage: language == nil`. Idioma
  explícito mantém o path atual (zero regressão).
- `PipelineCoordinator`: `language` fixo vira `languageProvider: () -> String?` (padrão dos
  demais providers). Idioma é stateless → **sem** coordinator de swap.
- `AppContainer`: injeta o provider lendo `prefs.transcriptionLanguage.whisperCode`.
- Picker visual `TranscriptionLanguagePicker` (padrão `WhisperModelPicker`) em
  `TranscriptionView`. Troca vale na próxima transcrição, sem reload de modelo.
- Strings pt-BR e testes (pref + propagação do provider).

## Não-objetivos

- Picker de idioma no onboarding.
- Catálogo amplo de idiomas (só pt/en/auto agora; o enum é extensível).
- Reintroduzir vocab biasing (segue desabilitado por ADR-0005).
- UI em outros idiomas — a UI continua pt-BR; idioma de transcrição é eixo ortogonal.

## Trade-offs aceitos

- Default `Automático` adiciona uma passada de detecção por transcrição (custo de latência,
  contra o esforço de velocidade da Fase 2d) e pode errar em ditados muito curtos. Aceito
  conscientemente em troca da conveniência de não precisar trocar de idioma manualmente.
  Registrado no ADR-0006.

## Verificação

Testes unitários (suíte atual verde + novos) e checklist de aceite manual
`03-funcionalidades/checklists/fase4-manual.md` (pt explícito sem regressão; en explícito;
auto pt; auto en; frase curta no auto; troca sem reiniciar).
