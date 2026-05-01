---
data: 2026-05-01
fase: 3-release
status: design
---

# Fase 3 — Release engineering

Sair de "build de Debug rodando do Xcode" pra "DMG distribuível, assinado, notarizado, com auto-update". Sem refactor de código de produto — apenas configuração + scripts + integração Sparkle.

## Contexto

A v1 está funcional (Fases 1, 2a, 2b-1/2/3, 2c-cleanup, 2d) mas só roda como build de Debug local. Pra o user distribuir pra ele mesmo + alguns conhecidos (~5 pessoas), precisa:

- Cert `Developer ID Application` (cert atual `Apple Development` só funciona em Macs do dev).
- Notarization (Gatekeeper bloqueia binário não-notarizado em Mac de outra pessoa).
- DMG empacotado.
- Auto-update via Sparkle (evita user manual baixar DMG novo a cada bump).
- Validação de que popups TCC nativos voltam a funcionar (cleanup #6 da Fase 1 está bloqueado por isso).

Itens enumerados em [`02-arquitetura/01-modulos-fase1.md:132`](../02-arquitetura/01-modulos-fase1.md) como "não implementados (vão pra Fase 3)" — esta fase entrega todos exceto Homebrew Cask (pós-v1) e logging em arquivo (substituído por botão "Abrir Console.app filtrado").

## Princípios

- **Solo + amigos**: zero infra hospedada além do GitHub. Repo público; appcast em raw URL; DMG em GitHub Releases.
- **Scripts modulares > script único**: cada etapa do pipeline isolada e debugável (`bump`, `build`, `sign`, `notarize`, `dmg`, `appcast`, orquestrados por `release.sh`).
- **Conservador em UI**: Sparkle minimal (auto-check no launch, sem UI manual). Botão "Abrir Console.app filtrado" em Preferências > Sobre como atalho de debug.

## Decisões nucleares

| # | Decisão | Razão |
|---|---------|-------|
| 1 | Distribuição: solo + ~5 conhecidos via DMG no GitHub Releases (repo público) | YAGNI — sem servidor próprio, sem CDN, sem MAS. |
| 2 | Cert `Developer ID Application` novo (coexiste com `Apple Development` atual) | Required pra notarization + Gatekeeper aceitar binário em Macs de terceiros. |
| 3 | Sparkle minimal (auto-check no launch + sheet nativa quando há update) | Zero UI custom; sem botão "Verificar atualizações". Sparkle desenha tudo. |
| 4 | Logging: botão "Abrir Console.app" em Preferências > Sobre | `os_log` já existe; arquivo persistido é over-engineering pra solo. |
| 5 | Versionamento manual via `bump.sh patch\|minor\|major` | Bump é decisão deliberada; script garante consistência (project.yml + xcodegen + git tag). |
| 6 | Pipeline = scripts modulares em bash | Debugabilidade > monolítico. Cada um chamável isolado. |
| 7 | Secrets em `~/.tagarela-release.env` (chmod 600, gitignored) | Plain-text local em Mac solo é OK. Promover pra Keychain depois se virar dor. |
| 8 | Entitlements completos (audio-input, automation, disable-library-validation) | Required pra Hardened Runtime + WhisperKit dylibs + AX injection. |
| 9 | Validar cleanup #6 (TCC manual) no aceite via `tccutil reset` | Teoria do doc é "popups voltam pós-Developer ID" — testar antes de declarar fechado. |
| 10 | Sparkle EdDSA keypair gerado uma vez; private key em `~/.tagarela-release/sparkle_ed_private.key` (chmod 600) | Sparkle exige assinatura EdDSA por update; perder private key = perder canal de update (hard fork de Sparkle pra recuperar). |
| 11 | `appcast.xml` versionado no repo (`main` branch); URL `raw.githubusercontent.com/<user>/tagarela/main/appcast.xml` | Sem hosting extra. Sparkle suporta nativamente. |

## Arquitetura

### Componentes novos

- **Cert pipeline (Apple Developer portal)** — gerar `Developer ID Application` cert, instalar localmente, anotar SHA-1.
- **`Tagarela.entitlements` preenchido** — claims abaixo.
- **Sparkle SPM** (`https://github.com/sparkle-project/Sparkle`, from `2.6.0`) — adicionado em `app/project.yml`.
- **`SPUStandardUpdaterController`** instanciado em `AppContainer.swift` (`startingUpdater: true`).
- **`appcast.xml`** no root do repo — initial empty channel; `appcast.sh` adiciona `<item>` por release.
- **6 scripts em `scripts/`**:
  - `bump.sh patch|minor|major` — edita `project.yml`, roda `xcodegen`, cria git tag, commit.
  - `build.sh` — `xcodebuild -configuration Release` → `build/release/Tagarela.app`.
  - `sign.sh` — `codesign --deep --options runtime --sign <SHA-1> --entitlements <path>`.
  - `notarize.sh` — zip → `xcrun notarytool submit --wait` → `xcrun stapler staple`.
  - `dmg.sh` — cria `Tagarela-<version>.dmg` (com fundo + symlink `/Applications`); re-codesign + staple no DMG.
  - `appcast.sh` — gera `<item>` (length, EdDSA signature via `sign_update`); commit no `appcast.xml`.
- **`release.sh`** — orquestra os 6 acima + `gh release create` + `git push --follow-tags`.
- **Botão "Abrir logs no Console"** em [`AboutView.swift`](../../app/Tagarela/Preferences/UI/Sections/AboutView.swift) — abre `Console.app` (idealmente com `--predicate "subsystem == 'com.tagarela'"`; fallback: abre sem filtro).
- **`tagarela_docs/02-arquitetura/00-setup-dev.md`** — setup pra outra máquina dev (cert Apple Development, popup TCC nativo, Accessibility manual, secrets pro release pipeline).

### Componentes modificados

#### `app/Tagarela/Resources/Tagarela.entitlements`

Hoje vazio. Passa a conter:

```xml
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
```

- `audio-input` — TCC entrega popup nativo de mic na primeira `AVCaptureSession`.
- `automation.apple-events` — `osascript` que `InjectorLive` usa pra digitar via AX.
- `disable-library-validation` — WhisperKit/SwiftPM trazem dylibs/frameworks que não são Apple-signed; sem isso, Hardened Runtime bloqueia load em Release.

#### `app/project.yml`

Adicionar Sparkle ao `packages` + `dependencies` do target `Tagarela`.

Split de `CODE_SIGN_IDENTITY` por configuração (Debug = Apple Development, Release = Developer ID Application). Se xcodegen não suportar split nativo via `configs:`, hardcodar Release SHA-1 num `xcconfig` separado e referenciar.

`Info.plist` (gerado a partir de `Tagarela/Resources/Info.plist`) ganha:

- `SUFeedURL` = `https://raw.githubusercontent.com/<user>/tagarela/main/appcast.xml`
- `SUEnableAutomaticChecks` = `true`
- `SUScheduledCheckInterval` = `86400`
- `SUPublicEDKey` = `<base64 da public key gerada>`
- `LSApplicationCategoryType` = `public.app-category.utilities`

#### `app/Tagarela/App/AppContainer.swift`

Após init das outras propriedades:

```swift
import Sparkle
// ...
let updaterController: SPUStandardUpdaterController

init() {
    // ...
    self.updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    // ...
}
```

`startingUpdater: true` faz auto-check no launch + a cada `SUScheduledCheckInterval` (1 dia). Sparkle desenha sheet nativa quando detecta nova versão.

#### `app/Tagarela/Preferences/UI/Sections/AboutView.swift`

Antes do `Spacer` final, adicionar botão "Abrir logs no Console" que:

1. Tenta `Process` com `/usr/bin/open`, args `["-a", "Console.app", "--args", "--predicate", "subsystem == 'com.tagarela'"]`. Se Console.app aceitar `--predicate` por argv (a confirmar empiricamente), filtro pré-aplicado.
2. Fallback: `NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))` — abre sem filtro; instrução curta no botão ("e filtre por `com.tagarela`").

Decidir caminho na implementação após teste local; documentar no PR/snapshot qual venceu.

#### `tagarela_docs/04-decisoes/cleanup-fase1.md` (item #6)

Se cleanup #6 validar (popup TCC nativo aparece pós-Developer ID): item #6 marcado fechado e referenciado em `00-setup-dev.md`.
Se NÃO validar: item #6 fica aberto, anomalia registrada com hipóteses pra investigação futura.

## Pipeline de release

### Pré-requisitos (uma vez)

```
~/.tagarela-release.env (chmod 600, gitignored):
APPLE_ID=ilan.salviano@gmail.com
APPLE_TEAM_ID=BCM26K6YNA
APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
SPARKLE_ED_PRIVATE_KEY_PATH=$HOME/.tagarela-release/sparkle_ed_private.key
DEVELOPER_ID_APP_SHA1=<SHA-1 do cert novo>
```

E:
- Cert `Developer ID Application` instalado no Keychain.
- Sparkle keypair gerado: public em `Info.plist`, private em `~/.tagarela-release/sparkle_ed_private.key`.
- `gh` CLI autenticado (`gh auth login`).

### Output do pipeline

```
build/release/
├── Tagarela.app           # build.sh
├── Tagarela.zip           # notarize.sh (input do notarytool)
├── Tagarela-1.0.1.dmg     # dmg.sh
└── notarization.log       # transcript notarytool
```

### Primeiro release (v1.0.0)

`MARKETING_VERSION` já está em `1.0.0` no `project.yml`. **Primeiro release pula `bump.sh`** — `release.sh` aceita flag `--no-bump` (ou explicitamente `release.sh initial`) que entra direto em `build.sh`. Tag criada `v1.0.0` no fim do pipeline. Releases subsequentes usam `bump.sh patch|minor|major`.

### Fluxo `./scripts/release.sh patch` (releases subsequentes)

1. **bump.sh patch** — `1.0.0 → 1.0.1`. Edita `MARKETING_VERSION` + bumpa `CURRENT_PROJECT_VERSION`. `xcodegen generate`. `git commit`. `git tag v1.0.1`.
2. **build.sh** — `xcodebuild -scheme Tagarela -configuration Release -derivedDataPath build/release/derived clean build`. Copia `.app` pra `build/release/`.
3. **sign.sh** — `codesign --deep --force --options runtime --timestamp --sign $DEVELOPER_ID_APP_SHA1 --entitlements <path>` no `.app`.
4. **notarize.sh** — zip → `xcrun notarytool submit Tagarela.zip --apple-id $APPLE_ID --team-id $APPLE_TEAM_ID --password $APPLE_APP_SPECIFIC_PASSWORD --wait`. `xcrun stapler staple Tagarela.app`. Logs em `notarization.log`.
5. **dmg.sh** — `hdiutil` cria DMG com fundo + alias pra `/Applications`. Sign + staple no DMG.
6. **appcast.sh** — calcula length do DMG, assina via `sign_update <dmg> <private_key>` (binário do Sparkle SPM em `build/release/derived/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update`). Adiciona `<item>` ao `appcast.xml`. `git commit`.
7. **gh release create v1.0.1** com DMG anexado, `--generate-notes`.
8. **git push --follow-tags**.

Cada script faz fail-fast (`set -euo pipefail`) e pode rodar isolado pra debug.

## Aceite manual

Checklist em [`tagarela_docs/03-funcionalidades/checklists/fase3-manual.md`](../03-funcionalidades/checklists/fase3-manual.md) (a criar).

### Bloco A — primeiro release end-to-end (v1.0.0)
- [ ] Cert "Developer ID Application" instalado, SHA-1 em `project.yml` Release config.
- [ ] `~/.tagarela-release.env` preenchido + chmod 600.
- [ ] Sparkle SPM resolvido; keypair gerado; public key em `Info.plist`.
- [ ] `./scripts/release.sh initial` (ou `--no-bump`) executa sem erro.
- [ ] `Tagarela-1.0.0.dmg` criado e assinado.
- [ ] `notarization.log` mostra `status: Accepted`.
- [ ] `xcrun stapler validate Tagarela.app && xcrun stapler validate Tagarela-1.0.0.dmg` passa.
- [ ] `appcast.xml` atualizado e commitado.
- [ ] `gh release create v1.0.0` criado, DMG anexado.

### Bloco B — Gatekeeper em máquina limpa (após v1.0.0)
- [ ] Em outro Mac (ou após reset local: `xattr -cr ~/Applications/Tagarela.app && rm -rf`), baixar DMG do GitHub.
- [ ] Abrir DMG → arrastar pra Applications.
- [ ] Primeira abertura: popup esperado é **só** "App baixado da internet — abrir?". NÃO o "desenvolvedor não-identificado".
- [ ] App roda; pílula aparece; injeção funciona.

### Bloco C — TCC nativo (cleanup #6)
- [ ] `tccutil reset Microphone com.tagarela.Tagarela`
- [ ] `tccutil reset Accessibility com.tagarela.Tagarela`
- [ ] `tccutil reset ListenEvent com.tagarela.Tagarela` (Input Monitoring)
- [ ] Reabrir Tagarela.app.
- [ ] Disparar hotkey → popup nativo de Microphone aparece. Aceitar.
- [ ] Disparar hotkey de novo → popup ou redirect pra Settings (Accessibility / Input Monitoring). Aceitar.
- [ ] Hotkey + transcribe + inject funcionam fim-a-fim.
- [ ] Se passar: cleanup #6 fechado, item deletado.

### Bloco D — Sparkle (após v1.0.1)
- [ ] Estando em v1.0.0 instalado, `release.sh patch` → v1.0.1 sai.
- [ ] Abrir v1.0.0; Sparkle detecta v1.0.1 no auto-check (forçar via `defaults write com.tagarela.Tagarela SULastCheckTime -string 'never'` se necessário).
- [ ] Sheet nativa de update aparece. Aceitar → app baixa, valida EdDSA, instala, reabre.
- [ ] Versão pós-update = 1.0.1.

### Bloco E — botão Console
- [ ] Preferências → Sobre → "Abrir logs no Console".
- [ ] Console.app abre. Aceito: com filtro `subsystem == com.tagarela` aplicado, ou (fallback) sem filtro.

## Riscos

| Risco | Mitigação |
|---|---|
| Notarization falha (entitlements faltando, dylib não-signed) | `notarytool` retorna log detalhado; iterar até passar. |
| Cleanup #6 NÃO valida (popup nativo continua não aparecendo) | Documentar como anomalia + investigar. App ainda funciona via Settings manual. Não bloqueia release. |
| Sparkle EdDSA private key perdida | Hard fork: gerar nova keypair, atualizar `Info.plist` + `appcast.xml`, push novo release. Users na versão antiga atualizam manual baixando DMG. **Backup da private key em local seguro (1Password, etc.) é mandatório.** |
| `Console.app --predicate` por argv não funciona | Fallback documentado; experiência levemente pior. |
| Repo público expõe código antes do release | OK — design é open por intent (clone Wispr Flow individual, sem segredos comerciais). |
| Sparkle desabilita-se em sandbox/Hardened Runtime | Sparkle 2.x suporta ambos com config padrão; testar no aceite Bloco D. |

## Não-objetivos

- UI manual de "Verificar atualizações" (Sparkle minimal — só auto-check).
- Logging persistido em arquivo (substituído pelo botão Console).
- Crash reports / telemetria (alinhado com privacy do design v1).
- Homebrew Cask (pós-Fase 3).
- Auto-bump via tags / CI (pós-Fase 3).
- MAS / Mac App Store distribution (incompatível com features do app por design).
- Logging em arquivo separado de `os_log` (rotação, OSLogStore export, etc.).

## Próximos passos

1. Esta spec é revisada pelo user.
2. Após aprovação, `superpowers:writing-plans` produz o plano de implementação detalhado em `tagarela_docs/specs/2026-05-01-tagarela-v1-fase3-release-plan.md`.
3. Implementação segue o plano. Aceite manual em build local antes de cada merge de tarefa que toca codesign/notarize/Sparkle (lição 2c-cleanup).
