---
data: 2026-05-01
fase: 3-release
status: implementado
---

# Snapshot pós-Fase 3

A Fase 3 entregou o pipeline de release: cert Developer ID Application, entitlements completos, notarization, DMG, Sparkle minimal. Sem refactor de código de produto. v1.0.0 e v1.0.1 publicadas em GitHub Releases via `scripts/release.sh`.

## Mudanças no app

### `app/Tagarela/Resources/Tagarela.entitlements`
- 3 claims: `audio-input`, `automation.apple-events`, `cs.disable-library-validation`. Antes: vazio.

### `app/project.yml`
- `targets.Tagarela.settings.configs` split de `CODE_SIGN_IDENTITY` + `DEVELOPMENT_TEAM` por configuração:
  - Debug = Apple Development (`78C7C6.../BCM26K6YNA`).
  - Release = Developer ID Application (`E42EE7.../22CZXFP6W7`). As duas Apple accounts têm Team IDs diferentes — split foi necessário pros dois.
- `packages.Sparkle` adicionado (from `2.6.0`, resolvido pra `2.9.1`); `dependencies` do target ganha `Sparkle`.

### `app/Tagarela/Resources/Info.plist`
- `CFBundleShortVersionString` e `CFBundleVersion` viraram `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` (lidas do project.yml).
- 5 chaves novas Sparkle: `SUFeedURL`, `SUEnableAutomaticChecks`, `SUScheduledCheckInterval` (86400), `SUPublicEDKey`, `LSApplicationCategoryType` (utilities).

### `app/Tagarela/App/AppContainer.swift`
- `import Sparkle`. Stored property `let updaterController: SPUStandardUpdaterController`. Init com `startingUpdater: true` — auto-check no launch + a cada 24h. Sem UI manual.

### `app/Tagarela/Preferences/UI/Sections/AboutView.swift`
- Section "LOGS" + botão "Abrir logs no Console". Versão B do plano: Console.app não honra `--predicate` por argv, então copy guia o user a filtrar manual.

## Pipeline de release (`scripts/`)

7 scripts modulares + secrets em `~/.tagarela-release.env` (template em `.tagarela-release.env.example` na root).

- `bump.sh patch|minor|major` — edita project.yml + xcodegen + commit.
- `build.sh` — xcodebuild Release → build/release/Tagarela.app.
- `sign.sh` — codesign --deep com Developer ID + entitlements.
- `notarize.sh` — zip → notarytool submit --wait → staple no .app.
- `dmg.sh` — hdiutil + sign + **notarize separado** + staple no DMG. (Ticket é por arquivo; .app stapled não cobre o DMG.)
- `appcast.sh` — gera `<item>` no appcast.xml com `sign_update` EdDSA. Find direto do binário, evita acoplar à estrutura interna do SPM artifacts dir.
- `release.sh initial|patch|minor|major` — orquestrador + git tag + gh release create + push robusto (fallback pra `--set-upstream` se branch não tem tracking).

`appcast.xml` versionado no repo, raw URL em `Info.plist`. DMGs hospedados em GitHub Releases.

## Cleanup #6 da Fase 1: ✅ fechado

Workaround SQL no `TCC.db` não é mais necessário. Pós-Developer ID + notarization, popup nativo de Microphone aparece na primeira execução. Accessibility e Input Monitoring continuam exigindo add manual via System Settings — comportamento padrão do macOS, documentado em [`00-setup-dev.md`](./00-setup-dev.md).

## Decisões nucleares

- Distribuição: solo + alguns conhecidos via DMG no GitHub Releases (repo público).
- Sparkle minimal: auto-check no launch, sem UI manual.
- Logging: botão "Abrir Console.app" — sem arquivo persistido.
- Versionamento: bump.sh manual (semver explicit).
- Secrets: `~/.tagarela-release.env` plain text + chmod 600 + gitignored.

## Releases publicadas

| Versão | DMG | Notarization |
|---|---|---|
| v1.0.0 | https://github.com/IlanSalviano/tagarela/releases/tag/v1.0.0 | Accepted |
| v1.0.1 | https://github.com/IlanSalviano/tagarela/releases/tag/v1.0.1 | Accepted |

v1.0.1 é uma "version bump only" — release pra validar o caminho `release.sh patch` + Sparkle update no aceite Bloco D.

## Bugs do pipeline encontrados durante aceite (todos fechados)

1. `dmg.sh` original tentava staple sem notarização separada do DMG → erro 65. Fix: notarizar DMG antes do staple.
2. `appcast.sh` find adivinhava estrutura SPM (`extract/sparkle/...`). Fix: find direto por nome do binário, filtrando `old_dsa_scripts/` legacy.
3. `release.sh` push falhava sem upstream tracking. Fix: fallback pra `--set-upstream` + push da tag separado.

## Lição operacional aplicada

Cada tarefa que tocou codesign/notarize/Sparkle (T1, T3, T4) teve aceite manual em build local antes do commit. Bloco A (release end-to-end) e Blocos B-E só puderam ser validados após o pipeline completo — fizeram parte da Tarefa 14 (aceite manual extensivo). Os 3 bugs acima foram pegos durante aceite — confirmando o valor da regra "aceite manual antes do merge" pós 2c-cleanup.

## Suíte

181 testes verdes (Fase 3 não adiciona testes unitários — pipeline é tudo build/distribuição). Smoke test do `bump.sh` foi feito em branch temporária (`_bump-smoke`) durante implementação, com rollback limpo.
