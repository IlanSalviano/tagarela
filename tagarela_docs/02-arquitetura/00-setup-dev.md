---
data: 2026-05-01
status: vivo
---

# Setup dev — primeira máquina

Onboard de um novo Mac pra trabalhar no tagarela. Pra usar o app empacotado, basta o DMG do GitHub Releases (não precisa nada disto).

## Builds locais (Debug)

1. Clonar o repo + abrir `app/Tagarela.xcodeproj` no Xcode 15.4+.
2. Cert "Apple Development" instalado no Keychain (parte da Apple Developer Program). SHA-1 atual está em `app/project.yml` configs.Debug — se o cert na máquina nova tiver SHA-1 diferente, atualizar lá.
3. `xcodegen generate` (instalar via `brew install xcodegen` se faltar).
4. Build no Xcode (`⌘ B`) ou linha de comando: `cd app && xcodebuild -scheme Tagarela -destination 'platform=macOS' build`.

## Permissões TCC (primeira execução)

1. Buildar e abrir Tagarela.app a partir de `/Applications` (NÃO direto do Xcode build; o popup TCC nativo pode falhar).
2. Disparar hotkey (Right Option) — popup nativo de Microphone aparece. Aceitar.
3. System Settings → Privacy & Security → Accessibility, adicionar Tagarela.app manualmente (clicar `+`).
4. System Settings → Privacy & Security → Input Monitoring, adicionar Tagarela.app manualmente.
5. Reabrir o app. Hotkey deve transcrever + injetar texto em outro app.

> **Nota:** o cleanup #6 da Fase 1 documentava workaround via SQL no TCC.db pra esses popups não aparecerem antes do Developer ID. Pós-Fase 3, o esperado é que popups nativos voltem — workaround SQL não seria mais necessário. Validação no Bloco C do `fase3-manual.md`.

## ⚠️ Coexistência de builds — NÃO FAZER

**Nunca abrir builds locais (`build/release/*`, `app/build/`, DerivedData) enquanto a release oficial estiver em `/Applications/Tagarela.app`.** Mesmo bundle id (`com.tagarela.Tagarela`) com Designated Requirements distintos (Apple Development vs Developer ID, ou re-assinaturas diferentes) cria registros TCC fantasma. Sintoma: a cada launch o macOS pede mic + Documents de novo, e Accessibility é revogada (paste para de funcionar).

Se acontecer, ver remediação completa em [`../04-decisoes/cleanup-fase3.md`](../04-decisoes/cleanup-fase3.md): `tccutil reset All com.tagarela.Tagarela` + `lsregister -u <path>` por cada cópia rival + reabrir só a `/Applications/Tagarela.app` + reconceder Accessibility/Input Monitoring.

Regra prática: depois de rodar `scripts/build.sh` ou `scripts/release.sh`, **não dar `open` no .app gerado** — copiar pra `/Applications/` e abrir de lá, ou apagar os artifacts locais (`rm -rf build/ app/build/`).

## Builds Release (gerar DMG distribuível)

Pra rodar o pipeline de release localmente, precisa do cert "Developer ID Application" instalado e dos secrets em `~/.tagarela-release.env`.

1. Apple Developer portal → Certificates → Developer ID Application → gerar e instalar.
2. SHA-1 do cert vai em `app/project.yml` configs.Release.
3. App-specific password em https://appleid.apple.com → Sign-In and Security.
4. Sparkle EdDSA private key — gerar via `generate_keys` do Sparkle SPM, exportar pra arquivo (`-x`), salvar em `~/.tagarela-release/sparkle_ed_private.key` (chmod 600). **Backup em local seguro** (1Password etc.) — perda da private key = perda do canal de update Sparkle.
5. Copiar `.tagarela-release.env.example` (root do repo) pra `~/.tagarela-release.env`, preencher e `chmod 600`.

Rodar primeiro release: `./scripts/release.sh initial`. Releases subsequentes: `./scripts/release.sh patch|minor|major`.

## Onde está cada coisa

- Vault de docs: `tagarela_docs/`.
- Código Swift: `app/Tagarela/`.
- Tests: `app/TagarelaTests/`.
- Scripts de release: `scripts/`.
- Project Xcode: gerado por `xcodegen` — `app/project.yml` é fonte da verdade.
- Secrets de release: `~/.tagarela-release.env` (nunca commitado).
- Sparkle EdDSA private: `~/.tagarela-release/sparkle_ed_private.key`.
