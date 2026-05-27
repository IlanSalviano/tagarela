---
data: 2026-05-27
fase: 4 (multi-idioma)
---

# Snapshot pós-Fase 4 — idioma de transcrição configurável

Fase 4 torna o idioma da transcrição configurável, com **auto-detecção como default**.
Decisão e trade-offs em [ADR-0006](../04-decisoes/ADR-0006-multi-idioma-transcricao.md);
design em [`specs/2026-05-27-…-fase4-multi-idioma-design.md`](../specs/2026-05-27-tagarela-v1-fase4-multi-idioma-design.md).

## Antes

`language` fixo em `"pt"` no `PipelineCoordinator.init`, nunca sobrescrito no `AppContainer`.
Falar inglês saía "aportuguesado".

## Depois

Picker **Automático · Português · English** em Preferências > Transcrição, default
`Automático` (inclusive migração implícita pra users existentes).

## Módulos novos

- `Preferences/TranscriptionLanguage.swift` — enum `{ auto, pt, en }`, `displayName`
  localizado, `whisperCode: String?` (`nil` = auto).
- `Preferences/UI/Components/TranscriptionLanguagePicker.swift` — picker visual no padrão
  do `WhisperModelPicker` (radio custom + binding), sem badge.

## Módulos modificados

- `Preferences/Preferences+Defaults.swift` — `PreferencesKey.transcriptionLanguage` +
  `PreferencesDefaults.transcriptionLanguage = .auto`.
- `Preferences/PreferencesStore.swift` — `@Published var transcriptionLanguage` (persiste
  `rawValue`, padrão `whisperModelName`).
- `Transcription/Transcribing.swift` — `transcribe(language:)` muda `String` → `String?`
  (`nil` = auto-detect). **Breaking** pros mocks de teste.
- `Transcription/WhisperKitTranscriber.swift` — `DecodingOptions(detectLanguage: language == nil)`.
  Idioma explícito mantém `detectLanguage: false` → path pt-only inalterado.
- `Pipeline/PipelineCoordinator.swift` — `language: String` fixo → `languageProvider:
  () -> String?` (padrão dos demais providers). Idioma é stateless: **sem** coordinator de
  swap como o do modelo Whisper.
- `App/AppContainer.swift` — injeta `languageProvider` lendo
  `prefs.transcriptionLanguage.whisperCode`.
- `Preferences/UI/Sections/TranscriptionView.swift` — seção "IDIOMA" com o picker + hint
  abaixo do picker de modelo.
- `Localization/pt-BR.lproj/Localizable.strings` — `transcription.language.{header,hint,auto,pt,en}`.

## Como o WhisperKit auto-detecta

`TranscribeTask.run` detecta o idioma quando: modelo multilíngue **E** `language == nil`
**E** `detectLanguage == true`. O default `large-v3_turbo` é multilíngue. Por isso o
`WhisperKitTranscriber` liga `detectLanguage` exatamente quando `language == nil`.

## Testes

Suíte 181 → 186. Novos: default `.auto` + persistência cross-init + `whisperCode` mapping
(`PreferencesStoreTests`); propagação do `languageProvider` (`en` e `nil`) até o transcriber
via `LanguageCapturingTranscriber` (`PipelineCoordinatorTests`). Mocks de transcriber
atualizados pra `language: String?` em `PipelineCoordinatorTests` e
`WhisperModelSwapCoordinatorTests`.

Aceite manual: [`checklists/fase4-manual.md`](../03-funcionalidades/checklists/fase4-manual.md).
