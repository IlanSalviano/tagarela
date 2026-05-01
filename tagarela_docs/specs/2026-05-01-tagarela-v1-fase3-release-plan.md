---
data: 2026-05-01
status: planejado
fase: 3-release
goal: cert Developer ID + entitlements + notarization + DMG + Sparkle minimal + scripts modulares de release + setup-dev doc + validação cleanup #6
---

# tagarela v1 — Fase 3: Implementation Plan

> **Para agentes de execução:** SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendado) ou `superpowers:executing-plans`. Tarefas usam checkbox (`- [ ]`).
>
> **Antes de qualquer tarefa:** ler [`/CLAUDE.md`](../../CLAUDE.md) e [`tagarela_docs/specs/2026-05-01-tagarela-v1-fase3-release-design.md`](./2026-05-01-tagarela-v1-fase3-release-design.md). **Antes de marcar uma tarefa como concluída:** atualizar a doc afetada (regra inviolável 2 do CLAUDE.md). **Antes de mergear cada tarefa que toca codesign/notarize/Sparkle (Tarefas 1, 3, 4, 8, 9, 10, 11, 12, 14):** rodar aceite manual em build local — lição 2c-cleanup.

**Goal:** Sair de "build de Debug rodando do Xcode" pra "DMG distribuível, assinado, notarizado, com auto-update via Sparkle". Sem refactor de código de produto — apenas configuração + entitlements + Sparkle SPM + 7 scripts em `scripts/`.

**Architecture:** (a) cert `Developer ID Application` novo coexiste com `Apple Development` atual via split de `CODE_SIGN_IDENTITY` por configuração no `project.yml`. (b) Entitlements ganha 3 claims (audio-input, automation.apple-events, disable-library-validation). (c) Sparkle SPM + `SPUStandardUpdaterController(startingUpdater: true)` no `AppContainer` — auto-check no launch, sheet nativa quando há update; sem UI manual. (d) 7 scripts modulares (`bump`, `build`, `sign`, `notarize`, `dmg`, `appcast`, orquestrador `release`) em `scripts/`. (e) Secrets em `~/.tagarela-release.env` (gitignored). (f) `appcast.xml` versionado no repo, raw URL em `Info.plist`. (g) Botão "Abrir logs no Console" em `AboutView`. (h) `00-setup-dev.md` doc novo. (i) Validação do cleanup #6 da Fase 1 via `tccutil reset`.

**Tech stack:** macOS 14, Swift 5.10, SwiftUI, Sparkle 2.6+, bash (`set -euo pipefail`), `xcodebuild`, `codesign`, `xcrun notarytool`, `xcrun stapler`, `hdiutil`, `gh` CLI.

**Não está nesta fase:** UI manual de "Verificar atualizações" (Sparkle minimal); logging em arquivo persistido; crash reports / telemetria; Homebrew Cask; auto-bump via tags / CI; MAS distribution. Ver [`fase3-design.md` § Não-objetivos](./2026-05-01-tagarela-v1-fase3-release-design.md#não-objetivos).

---

## File structure desta fase

```
app/
├── project.yml                                    # MODIFICAR — Sparkle SPM + split CODE_SIGN_IDENTITY Debug/Release
└── Tagarela/
    ├── Resources/
    │   ├── Info.plist                             # MODIFICAR — usar $(MARKETING_VERSION)/$(CURRENT_PROJECT_VERSION) + chaves Sparkle
    │   └── Tagarela.entitlements                  # MODIFICAR — adicionar 3 claims
    ├── App/
    │   └── AppContainer.swift                     # MODIFICAR — instanciar SPUStandardUpdaterController
    └── Preferences/UI/Sections/
        └── AboutView.swift                        # MODIFICAR — botão "Abrir logs no Console"

scripts/                                            # CRIAR (diretório novo)
├── release.sh                                     # CRIAR — orquestrador
├── bump.sh                                        # CRIAR — semver bump
├── build.sh                                       # CRIAR — xcodebuild Release
├── sign.sh                                        # CRIAR — codesign
├── notarize.sh                                    # CRIAR — notarytool + staple
├── dmg.sh                                         # CRIAR — hdiutil + sign + staple
└── appcast.sh                                     # CRIAR — gera <item> + sign_update

appcast.xml                                         # CRIAR (root do repo, channel vazio)
.tagarela-release.env.example                       # CRIAR (template; user copia pra ~/.tagarela-release.env)
.gitignore                                          # MODIFICAR — adicionar build/release/, *.dmg, sparkle private key local

tagarela_docs/
├── 02-arquitetura/
│   └── 00-setup-dev.md                            # CRIAR — onboard de outra máquina dev
├── 03-funcionalidades/checklists/
│   └── fase3-manual.md                            # CRIAR — checklist de aceite (5 blocos)
└── 04-decisoes/
    └── cleanup-fase1.md                           # MODIFICAR — atualizar item #6 (fechado ou anomalia)
```

---

## Convenções desta fase

- **Idioma:** strings de UI em `Localizable.strings` pt-BR. Identificadores em inglês.
- **Bash:** todo script começa com `#!/bin/bash` + `set -euo pipefail`. Falha cedo. Lê secrets de `~/.tagarela-release.env` via `source`. Cada script chamável isolado pra debug.
- **Swift:** Swift 5.10, `SWIFT_STRICT_CONCURRENCY: complete`, deployment target macOS 14.0.
- **Commits:** um commit por tarefa (ou alguns relacionados), em pt-BR `tipo(escopo): descrição` + co-author Claude.
- **xcodegen é fonte da verdade do projeto Xcode.** Esta fase modifica `project.yml` em T2 (split signing) e em T3 (Sparkle SPM). Sempre rodar `xcodegen generate` em `app/` após mudar `project.yml`.
- **Aceite manual:** lição 2c-cleanup. Tarefas que tocam codesign/notarize/Sparkle/UI têm aceite manual explícito antes do commit.
- **Sem TDD pra shell scripts.** Aceite manual via execução isolada (`./scripts/<script>.sh ...`) cobre.

---

## Pre-flight (antes da Tarefa 1)

- [ ] **Confirmar `main` está limpo e em verde.**

```bash
cd /Users/tars/Dev/tagarela
git status                                                         # working tree clean
git log -1 --oneline                                               # último: a274685 docs: design da Fase 3
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -3
```

Esperado: `** TEST SUCCEEDED **`, 181 testes.

- [ ] **Criar branch de trabalho.**

```bash
cd /Users/tars/Dev/tagarela
git checkout -b fase-3
```

- [ ] **Gerar e instalar cert "Developer ID Application" no Apple Developer portal.**

  Passos manuais (one-time, fora do código):
  1. Abrir https://developer.apple.com/account → Certificates, Identifiers & Profiles → Certificates → "+".
  2. Selecionar "Developer ID Application" (NÃO "Developer ID Installer").
  3. Gerar CSR via Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority. Salvar `.certSigningRequest`.
  4. Upload o CSR no portal. Download o `.cer` resultante.
  5. Duplo-clique no `.cer` pra instalar no Keychain (login).
  6. Anotar o SHA-1 do cert novo:
     ```bash
     security find-identity -v -p codesigning | grep "Developer ID Application"
     ```
     Output esperado: 1 linha com `<SHA-1> "Developer ID Application: Ilan Salviano (BCM26K6YNA)"`. **Anotar esse SHA-1.**

- [ ] **Gerar app-specific password pro notarytool.**

  Em https://appleid.apple.com → Sign-In and Security → App-Specific Passwords → "+" → label "tagarela-notarize". Anotar a senha gerada (formato `xxxx-xxxx-xxxx-xxxx`).

- [ ] **Confirmar `gh` CLI instalado e autenticado.**

```bash
which gh                       # /opt/homebrew/bin/gh
gh auth status                 # logado
```

Se faltar: `brew install gh && gh auth login`.

---

## Tarefa 1: Entitlements completo

Objetivo: preencher `Tagarela.entitlements` com 3 claims (audio-input, automation.apple-events, disable-library-validation) que app já usa em runtime mas estão omissos no entitlements file. Sem isso, Hardened Runtime + Gatekeeper bloqueariam o app em Release.

**Files:**
- Modify: `app/Tagarela/Resources/Tagarela.entitlements`

- [ ] **Step 1: Substituir conteúdo do `Tagarela.entitlements`**

```bash
cat > /Users/tars/Dev/tagarela/app/Tagarela/Resources/Tagarela.entitlements <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF
```

- [ ] **Step 2: Build Debug pra verificar que não regrediu**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
```

Esperado: `** BUILD SUCCEEDED **`. (Em Debug, `Apple Development` cert + entitlements permissivos = sem regressão esperada.)

- [ ] **Step 3: Suíte verde**

```bash
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Esperado: 181 testes verdes.

- [ ] **Step 4: ACEITE MANUAL — instalar e validar no-regressão**

```bash
cd /Users/tars/Dev/tagarela
pkill -x Tagarela 2>/dev/null
sleep 1
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Library/Developer/Xcode/DerivedData/Tagarela-*/Build/Products/Debug/Tagarela.app /Users/tars/Applications/Tagarela.app
open /Users/tars/Applications/Tagarela.app
```

Validar:
1. App abre sem crash.
2. Hotkey funciona (Right Option).
3. Transcribe roda; texto é injetado.
4. Preferências abre.

Pedir confirmação ao user antes de seguir.

- [ ] **Step 5: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Resources/Tagarela.entitlements
git commit -m "$(cat <<'EOF'
feat(release): entitlements com 3 claims pra Hardened Runtime

- com.apple.security.device.audio-input — TCC popup nativo de mic.
- com.apple.security.automation.apple-events — osascript usado pelo
  InjectorLive pra digitar via AX.
- com.apple.security.cs.disable-library-validation — WhisperKit
  trazerá dylibs não-Apple-signed; sem isso Hardened Runtime bloqueia.

Pré-requisito da Fase 3 (release engineering). Sem regressão em Debug.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: `project.yml` split de signing + `Info.plist` usando variáveis

Objetivo: (a) Debug builds usam `Apple Development` (atual SHA-1 `78C7C6...`); Release builds usam `Developer ID Application` (SHA-1 do cert novo). (b) `Info.plist` `CFBundleShortVersionString` e `CFBundleVersion` passam a usar `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` pra `bump.sh` da T6 conseguir editar só o `project.yml`.

**Files:**
- Modify: `app/project.yml`
- Modify: `app/Tagarela/Resources/Info.plist`

- [ ] **Step 1: Adicionar SHA-1 do Developer ID em variável de ambiente local**

Confirmar SHA-1 do cert (Pre-flight passo 3):
```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

Anotar o SHA-1 pra usar nos próximos passos.

- [ ] **Step 2: Modificar `project.yml` — split signing por configuração**

Abrir `app/project.yml` em editor. Localizar o bloco do target `Tagarela` (linha ~32). Substituir o bloco `settings.base` do target por `settings` com sub-keys `base` + `configs.Debug` + `configs.Release`:

Antes:
```yaml
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.tagarela.Tagarela
        INFOPLIST_FILE: Tagarela/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: Tagarela/Resources/Tagarela.entitlements
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "78C7C6375957D553AD632832D0821B446F53D0F3"
        DEVELOPMENT_TEAM: BCM26K6YNA
        PROVISIONING_PROFILE_SPECIFIER: ""
        COMBINE_HIDPI_IMAGES: YES
        ENABLE_PREVIEWS: YES
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/../Frameworks"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

Depois (substitua `<DEVELOPER_ID_APP_SHA1>` pelo SHA-1 do cert "Developer ID Application"):
```yaml
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.tagarela.Tagarela
        INFOPLIST_FILE: Tagarela/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: Tagarela/Resources/Tagarela.entitlements
        CODE_SIGN_STYLE: Manual
        DEVELOPMENT_TEAM: BCM26K6YNA
        PROVISIONING_PROFILE_SPECIFIER: ""
        COMBINE_HIDPI_IMAGES: YES
        ENABLE_PREVIEWS: YES
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/../Frameworks"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
      configs:
        Debug:
          CODE_SIGN_IDENTITY: "78C7C6375957D553AD632832D0821B446F53D0F3"
        Release:
          CODE_SIGN_IDENTITY: "<DEVELOPER_ID_APP_SHA1>"
```

(Note: o `TagarelaTests` target mantém `CODE_SIGN_IDENTITY` em `base` apontando pro Apple Development — só roda em Debug.)

- [ ] **Step 3: Modificar `Info.plist` pra usar variáveis Xcode**

Editar `app/Tagarela/Resources/Info.plist`. Trocar:

```xml
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
```

Por:

```xml
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
```

Resto do `Info.plist` fica como está.

- [ ] **Step 4: Regenerar projeto + build Debug**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
```

Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Build Release pra confirmar que cert novo é encontrado**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -configuration Release -destination 'platform=macOS' build 2>&1 | tail -10
```

Esperado: `** BUILD SUCCEEDED **`. Se falhar com "no signing certificate found", revisar SHA-1 colado no `project.yml`.

- [ ] **Step 6: Verificar versão no `.app` Debug builda corretamente**

```bash
plutil -p /Users/tars/Library/Developer/Xcode/DerivedData/Tagarela-*/Build/Products/Debug/Tagarela.app/Contents/Info.plist | grep -E "CFBundleShortVersionString|CFBundleVersion"
```

Esperado: `"CFBundleShortVersionString" => "1.0.0"`, `"CFBundleVersion" => "1"`.

- [ ] **Step 7: Suíte verde**

```bash
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Esperado: 181 testes verdes.

- [ ] **Step 8: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/project.yml app/Tagarela/Resources/Info.plist app/Tagarela.xcodeproj
git commit -m "$(cat <<'EOF'
feat(release): split CODE_SIGN_IDENTITY Debug/Release + Info.plist via vars

- project.yml: configs.Debug usa Apple Development (atual);
  configs.Release usa Developer ID Application (cert novo).
- Info.plist agora referencia \$(MARKETING_VERSION) e
  \$(CURRENT_PROJECT_VERSION) pra bump.sh editar só o project.yml.

Build Debug e Release ambos verdes; 181 testes verdes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: Sparkle SPM + EdDSA keypair + Info.plist + AppContainer init

Objetivo: adicionar Sparkle como dependência, gerar keypair EdDSA (uma vez), embedar public key no Info.plist, e instanciar `SPUStandardUpdaterController` no `AppContainer`. Resultado: app abre, Sparkle é ativado silenciosamente, sem feed válido (`appcast.xml` ainda não existe) — sem regressão.

**Files:**
- Modify: `app/project.yml` (adiciona Sparkle SPM + dependency)
- Modify: `app/Tagarela/Resources/Info.plist` (chaves Sparkle)
- Modify: `app/Tagarela/App/AppContainer.swift` (init SPUStandardUpdaterController)
- Create: `~/.tagarela-release/sparkle_ed_private.key` (FORA do repo; chmod 600)

**Aceite manual obrigatório antes do commit** (toca Sparkle init).

- [ ] **Step 1: Adicionar Sparkle ao `project.yml`**

Em `app/project.yml`, no bloco `packages` (linha ~26):

Antes:
```yaml
packages:
  WhisperKit:
    url: https://github.com/argmaxinc/WhisperKit
    from: 0.9.0
```

Depois:
```yaml
packages:
  WhisperKit:
    url: https://github.com/argmaxinc/WhisperKit
    from: 0.9.0
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: 2.6.0
```

E em `targets.Tagarela.dependencies`:
```yaml
    dependencies:
      - package: WhisperKit
      - package: Sparkle
```

- [ ] **Step 2: Regenerar projeto + resolver SPM**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -scheme Tagarela -resolvePackageDependencies 2>&1 | tail -5
```

Esperado: Sparkle resolvido. Pasta `~/Library/Developer/Xcode/DerivedData/Tagarela-*/SourcePackages/checkouts/Sparkle/` aparece.

- [ ] **Step 3: Localizar binários do Sparkle (`generate_keys`, `sign_update`)**

```bash
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData/Tagarela-*/SourcePackages/artifacts -type d -name "Sparkle" 2>/dev/null | head -1)
echo "$SPARKLE_BIN"
ls "$SPARKLE_BIN/bin/" 2>/dev/null || ls "$SPARKLE_BIN/Sparkle/bin/" 2>/dev/null
```

Esperado: lista contém `generate_keys` e `sign_update`. Anotar o path real (vai variar entre `Sparkle/bin/` e direto).

- [ ] **Step 4: Gerar EdDSA keypair**

```bash
mkdir -p ~/.tagarela-release
chmod 700 ~/.tagarela-release

# Substitua <SPARKLE_BIN_PATH> pelo path encontrado no Step 3.
<SPARKLE_BIN_PATH>/generate_keys
```

`generate_keys` armazena a private key no Keychain (login) e imprime a public key no stdout. Output esperado:
```
A key has been generated and saved in your keychain.
Public key:
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
```

**Anotar a public key (linha base64).** Vai pro Info.plist no Step 6.

Pra exportar a private key pra arquivo (precisamos pro `appcast.sh` em ambientes onde Keychain não está disponível ou precisamos backup):

```bash
<SPARKLE_BIN_PATH>/generate_keys -x ~/.tagarela-release/sparkle_ed_private.key
chmod 600 ~/.tagarela-release/sparkle_ed_private.key
```

(`-x` exporta a key existente do Keychain pra um arquivo. Se o flag não existir nesta versão, abrir Keychain Access → Buscar "Sparkle" → Exportar manualmente.)

**FAZER BACKUP DESTA PRIVATE KEY** em local seguro (1Password, etc.). Perda = perda do canal de update (forçar users na versão antiga a baixar manualmente o DMG novo).

- [ ] **Step 5: Adicionar `~/.tagarela-release/` e build/release/ ao `.gitignore`**

```bash
cd /Users/tars/Dev/tagarela
# Verificar se .gitignore existe
ls -la .gitignore 2>/dev/null || touch .gitignore
```

Adicionar ao `.gitignore` (criar se não existir; se existir, append sem duplicar):
```
# Fase 3 — release pipeline
build/release/
*.dmg
.tagarela-release.env
```

- [ ] **Step 6: Adicionar chaves Sparkle ao `Info.plist`**

Em `app/Tagarela/Resources/Info.plist`, **antes do `</dict>` final**, inserir (substituir `<PUBLIC_KEY_BASE64>` pela public key do Step 4 e `<GITHUB_USER>` pelo seu username GitHub):

```xml
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/<GITHUB_USER>/tagarela/main/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
    <key>SUPublicEDKey</key>
    <string><PUBLIC_KEY_BASE64></string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
```

- [ ] **Step 7: Modificar `AppContainer.swift` pra instanciar `SPUStandardUpdaterController`**

Em `app/Tagarela/App/AppContainer.swift`:

(a) Adicionar `import Sparkle` no topo (após os outros imports):
```swift
import SwiftUI
import AppKit
import AVFoundation
import Combine
import OSLog
import SwiftData
import Sparkle
```

(b) Adicionar stored property logo após `let toastCenter = ToastCenter()` (~linha 34):
```swift
    let updaterController: SPUStandardUpdaterController
```

(c) No `init()`, antes do `wireHotkeyToPipeline()`, instanciar (logo antes da linha `wireHotkeyToPipeline()`):
```swift
        // Sparkle minimal: auto-check no launch + a cada SUScheduledCheckInterval (24h).
        // Sheet nativa de update aparece quando feed lista versão > atual.
        // Sem UI manual de "Verificar atualizações" nesta fase.
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
```

- [ ] **Step 8: Build + suíte**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' test 2>&1 | grep -E "Executed|FAIL|TEST|error:" | tail -8
```

Esperado: 181 testes verdes. `** TEST SUCCEEDED **`. Build não regrediu.

- [ ] **Step 9: ACEITE MANUAL — instalar app e confirmar boot ok com Sparkle ativo**

```bash
pkill -x Tagarela 2>/dev/null
sleep 1
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Library/Developer/Xcode/DerivedData/Tagarela-*/Build/Products/Debug/Tagarela.app /Users/tars/Applications/Tagarela.app
open /Users/tars/Applications/Tagarela.app
```

Validar:
1. App abre sem crash.
2. Hotkey funciona; transcribe + inject normais.
3. No Console.app filtrando `subsystem == 'com.tagarela'` ou (broader) `process == Tagarela`, há linhas começando com `Sparkle` (auto-check tentou bater no `appcast.xml` que ainda não existe — provavelmente loga erro 404, esperado).
4. Sem regressão em Preferências (Sobre, Transcrição, etc).

Pedir confirmação ao user antes de seguir.

- [ ] **Step 10: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/project.yml app/Tagarela/Resources/Info.plist app/Tagarela/App/AppContainer.swift app/Tagarela.xcodeproj .gitignore
git commit -m "$(cat <<'EOF'
feat(release): Sparkle SPM + auto-check no launch

- Sparkle 2.6+ adicionado em project.yml + dependencies do target.
- Info.plist: SUFeedURL, SUEnableAutomaticChecks, SUScheduledCheckInterval
  (24h), SUPublicEDKey (EdDSA), LSApplicationCategoryType.
- AppContainer instancia SPUStandardUpdaterController(startingUpdater: true)
  — auto-check no launch + a cada 24h, sheet nativa quando há update.
- Sem UI manual de "Verificar atualizações" (Sparkle minimal).
- .gitignore: build/release/, *.dmg, .tagarela-release.env.

Aceite manual ok: app abre sem regressão; Sparkle silencioso (appcast.xml
ainda não existe — vem na T11).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: Botão "Abrir logs no Console" em `AboutView`

Objetivo: adicionar botão pequeno em Preferências > Sobre que tenta abrir Console.app filtrado por `subsystem == 'com.tagarela'`. Plan-time decisão: testar empiricamente se Console.app aceita `--predicate` por argv. Caso não, fallback abre Console.app sem filtro.

**Files:**
- Modify: `app/Tagarela/Preferences/UI/Sections/AboutView.swift`
- Modify: `app/Tagarela/Localization/pt-BR.lproj/Localizable.strings` (chaves novas)
- Modify: `app/TagarelaTests/LocalizableKeysTests.swift` (smoke)

**Aceite manual obrigatório** (toca SwiftUI + IO).

- [ ] **Step 1: Testar empiricamente se Console.app aceita `--predicate` por argv**

```bash
open -a Console.app --args --predicate "subsystem == 'com.tagarela'" 2>&1
sleep 2
osascript -e 'tell application "Console" to quit' 2>/dev/null
```

Verificar visualmente: Console.app abriu com filtro `com.tagarela` aplicado? Se SIM, usar abordagem `--predicate` no Step 2. Se NÃO (filtro vazio/diferente), usar fallback `NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))` no Step 2 e ajustar copy.

(`open -a Console.app --args` injeta argv pro Console; `--predicate` é flag interna do Console — pode ou não ser honrada.)

**Se `--predicate` funcionar**, prosseguir Step 2 com versão A (com filtro). **Se não funcionar**, prosseguir Step 2 com versão B (sem filtro + instrução pra user filtrar).

- [ ] **Step 2 (versão A — `--predicate` funcionou): Modificar `AboutView.swift`**

Em `app/Tagarela/Preferences/UI/Sections/AboutView.swift`, antes do `Spacer(minLength: 0)`, adicionar (4 linhas dentro do `VStack` principal):

```swift
                Divider().padding(.vertical, 4)

                Button(action: openLogsInConsole) {
                    Text(String(localized: "about.logs.open",
                                 defaultValue: "Abrir logs no Console"))
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                Text(String(localized: "about.logs.help",
                             defaultValue: "Filtra por subsystem == com.tagarela"))
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.ink3)
```

E adicionar o método privado `openLogsInConsole` ao final do struct (antes da `}`):
```swift
    private func openLogsInConsole() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Console.app", "--args",
                          "--predicate", "subsystem == 'com.tagarela'"]
        try? task.run()
    }
```

- [ ] **Step 2 (versão B — fallback sem filtro): Modificar `AboutView.swift`**

Mesma estrutura do Step 2 versão A, mas:

(a) Trocar a help string (chave `about.logs.help`) pra:
```
"Filtre por subsystem == com.tagarela na barra de busca."
```

(b) Trocar o método privado por:
```swift
    private func openLogsInConsole() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
    }
```

- [ ] **Step 3: Adicionar chaves novas ao `Localizable.strings`**

Em `app/Tagarela/Localization/pt-BR.lproj/Localizable.strings`, no fim do arquivo (após o último bloco de Fase 2d):

```
// Fase 3 — Sobre logs
"about.logs.open" = "Abrir logs no Console";
"about.logs.help" = "Filtra por subsystem == com.tagarela";
```

(Se versão B foi escolhida no Step 2, ajustar `about.logs.help` pro texto da versão B.)

- [ ] **Step 4: Adicionar chaves ao smoke test**

Em `app/TagarelaTests/LocalizableKeysTests.swift`, na lista `keys`, adicionar antes do `]`:
```swift
            // Fase 3
            "about.logs.open",
            "about.logs.help",
```

- [ ] **Step 5: Build + suíte**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|FAIL|TEST" | tail -3
```

Esperado: 181 testes verdes.

- [ ] **Step 6: ACEITE MANUAL — abrir Preferências > Sobre, clicar botão**

```bash
pkill -x Tagarela 2>/dev/null
sleep 1
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Library/Developer/Xcode/DerivedData/Tagarela-*/Build/Products/Debug/Tagarela.app /Users/tars/Applications/Tagarela.app
open /Users/tars/Applications/Tagarela.app
```

Validar:
1. Preferências (`⌘ ,`) → Sobre → botão "Abrir logs no Console" aparece.
2. Clicar abre Console.app.
3. (Versão A) Filtro `com.tagarela` aplicado. (Versão B) Console.app abre, user filtra manual.
4. Disparar hotkey, ditar; logs aparecem em tempo real.

Pedir confirmação ao user antes de seguir.

- [ ] **Step 7: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Preferences/UI/Sections/AboutView.swift \
        app/Tagarela/Localization/pt-BR.lproj/Localizable.strings \
        app/TagarelaTests/LocalizableKeysTests.swift
git commit -m "$(cat <<'EOF'
feat(prefs/about): botão "Abrir logs no Console"

Atalho em Preferências > Sobre pra abrir Console.app filtrando logs do
app por subsystem == com.tagarela. Substitui logging em arquivo
persistido (que ficou fora do escopo da Fase 3 por YAGNI).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: Estrutura `scripts/` + secrets template + appcast.xml inicial

Objetivo: criar diretório `scripts/`, arquivo `.tagarela-release.env.example` na root pra copiar pra `~/.tagarela-release.env`, e `appcast.xml` inicial vazio (com channel) na root do repo.

**Files:**
- Create: `scripts/` (diretório)
- Create: `.tagarela-release.env.example` (root do repo)
- Create: `appcast.xml` (root do repo)

- [ ] **Step 1: Criar diretório `scripts/`**

```bash
cd /Users/tars/Dev/tagarela
mkdir -p scripts
```

- [ ] **Step 2: Criar `.tagarela-release.env.example`**

```bash
cat > /Users/tars/Dev/tagarela/.tagarela-release.env.example <<'EOF'
# Pipeline de release — secrets de assinatura e notarization.
# Copie este arquivo pra ~/.tagarela-release.env e preencha:
#   cp .tagarela-release.env.example ~/.tagarela-release.env
#   chmod 600 ~/.tagarela-release.env
#
# Os scripts em scripts/ fazem `source ~/.tagarela-release.env` e
# falham fast se alguma var estiver faltando.

# Apple ID da conta dev (email).
APPLE_ID=

# Team ID da Apple Developer Program. Você pode ver em
# https://developer.apple.com/account/#MembershipDetailsCard.
APPLE_TEAM_ID=BCM26K6YNA

# App-specific password gerado em https://appleid.apple.com →
# Sign-In and Security → App-Specific Passwords. Formato xxxx-xxxx-xxxx-xxxx.
APPLE_APP_SPECIFIC_PASSWORD=

# Path absoluto pra private EdDSA key do Sparkle (gerada via
# `generate_keys` do Sparkle SPM, exportada pra arquivo).
SPARKLE_ED_PRIVATE_KEY_PATH=$HOME/.tagarela-release/sparkle_ed_private.key

# SHA-1 do cert "Developer ID Application" (instalado no Keychain).
# Veja com:
#   security find-identity -v -p codesigning | grep "Developer ID Application"
DEVELOPER_ID_APP_SHA1=

# (Opcional) URL base do appcast — útil pra preview/staging. Em produção,
# o Info.plist já aponta pra raw.githubusercontent.com.
# APPCAST_URL=https://raw.githubusercontent.com/<user>/tagarela/main/appcast.xml
EOF
```

- [ ] **Step 3: Criar `appcast.xml` inicial (channel vazio)**

```bash
cat > /Users/tars/Dev/tagarela/appcast.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>tagarela</title>
    <description>Updates do tagarela</description>
    <language>pt-BR</language>
    <!-- Items adicionados por scripts/appcast.sh a cada release -->
  </channel>
</rss>
EOF
```

- [ ] **Step 4: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add scripts/ .tagarela-release.env.example appcast.xml
git commit -m "$(cat <<'EOF'
feat(release): estrutura scripts/ + secrets template + appcast.xml inicial

- scripts/ vazio (será preenchido pelas próximas tarefas T6-T12).
- .tagarela-release.env.example: template documentado pra user copiar pra
  ~/.tagarela-release.env e preencher com secrets locais.
- appcast.xml: channel vazio versionado no repo. scripts/appcast.sh adiciona
  <item> por release.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 6: `scripts/bump.sh`

Objetivo: script que bumpa `MARKETING_VERSION` (semver: major/minor/patch) e `CURRENT_PROJECT_VERSION` (build int) no `project.yml`, regenera projeto via xcodegen, cria git commit, e cria git tag `v<MARKETING_VERSION>`. Usado por `release.sh` em releases subsequentes (após v1.0.0).

**Files:**
- Create: `scripts/bump.sh`

- [ ] **Step 1: Criar `scripts/bump.sh`**

```bash
cat > /Users/tars/Dev/tagarela/scripts/bump.sh <<'BUMPSH'
#!/bin/bash
#
# bump.sh patch|minor|major
#
# Lê MARKETING_VERSION + CURRENT_PROJECT_VERSION em app/project.yml,
# calcula próximo, edita o arquivo, regenera projeto Xcode, commita.
# NÃO cria tag (a tag é criada por release.sh após o build/sign/notarize).

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "uso: bump.sh patch|minor|major"
    exit 64
fi

case "$1" in
    patch|minor|major) ;;
    *) echo "erro: arg inválido '$1' (esperado: patch|minor|major)"; exit 64 ;;
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="$REPO_ROOT/app/project.yml"

current_version=$(grep -E '^\s*MARKETING_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
current_build=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$current_version" ] || [ -z "$current_build" ]; then
    echo "erro: não consegui ler MARKETING_VERSION ou CURRENT_PROJECT_VERSION em $PROJECT_YML"
    exit 1
fi

IFS='.' read -r major minor patch <<< "$current_version"

case "$1" in
    patch) new_version="$major.$minor.$((patch + 1))" ;;
    minor) new_version="$major.$((minor + 1)).0" ;;
    major) new_version="$((major + 1)).0.0" ;;
esac

new_build=$((current_build + 1))

echo "bump: $current_version ($current_build) → $new_version ($new_build)"

# Edita project.yml in-place. sed -i '' precisa de empty string como sufixo de backup no macOS.
sed -i '' -E "s/(MARKETING_VERSION:\s+)\"$current_version\"/\1\"$new_version\"/" "$PROJECT_YML"
sed -i '' -E "s/(CURRENT_PROJECT_VERSION:\s+)\"$current_build\"/\1\"$new_build\"/" "$PROJECT_YML"

# Verificar que a edição funcionou
verify_version=$(grep -E '^\s*MARKETING_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
verify_build=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$verify_version" != "$new_version" ] || [ "$verify_build" != "$new_build" ]; then
    echo "erro: edição do project.yml falhou (esperado $new_version/$new_build, lido $verify_version/$verify_build)"
    exit 1
fi

# Regenerar projeto Xcode
cd "$REPO_ROOT/app"
xcodegen generate

# Commit (sem tag — tag é criada por release.sh)
cd "$REPO_ROOT"
git add app/project.yml app/Tagarela.xcodeproj
git commit -m "chore(release): bump $current_version → $new_version"

echo ""
echo "bump.sh: ok ($new_version)"
echo "BUMP_NEW_VERSION=$new_version"
echo "BUMP_NEW_BUILD=$new_build"
BUMPSH
chmod +x /Users/tars/Dev/tagarela/scripts/bump.sh
```

- [ ] **Step 2: Smoke test em dry-run (criar branch temporário, rodar, verificar, descartar)**

```bash
cd /Users/tars/Dev/tagarela
git checkout -b _bump-smoke
./scripts/bump.sh patch
grep MARKETING_VERSION app/project.yml | head -1
git log -1 --oneline
git checkout fase-3
git branch -D _bump-smoke
# Restaurar versão original já que o bump foi descartado
```

Esperado: na branch temporária, `MARKETING_VERSION: "1.0.1"`, commit `chore(release): bump 1.0.0 → 1.0.1`. Após `checkout fase-3` + `branch -D`, voltamos a `MARKETING_VERSION: "1.0.0"`.

- [ ] **Step 3: Commit do script**

```bash
cd /Users/tars/Dev/tagarela
git add scripts/bump.sh
git commit -m "$(cat <<'EOF'
feat(release): scripts/bump.sh patch|minor|major

Edita MARKETING_VERSION + CURRENT_PROJECT_VERSION em app/project.yml,
regenera projeto via xcodegen, commita. Tag é criada depois por
release.sh (após build/sign/notarize concluírem com sucesso).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: `scripts/build.sh`

Objetivo: script que limpa `build/release/`, roda `xcodebuild -configuration Release`, copia `.app` resultante pra `build/release/Tagarela.app`. Não assina nem notariza (separado em sign.sh / notarize.sh).

**Files:**
- Create: `scripts/build.sh`

- [ ] **Step 1: Criar `scripts/build.sh`**

```bash
cat > /Users/tars/Dev/tagarela/scripts/build.sh <<'BUILDSH'
#!/bin/bash
#
# build.sh
#
# xcodebuild -configuration Release → build/release/Tagarela.app
# Sem signing além do que o build do Xcode aplica (cert do Release config
# do project.yml). Notarization e DMG vêm depois.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$REPO_ROOT/build/release"
DERIVED_DATA="$RELEASE_DIR/derived"

echo "build.sh: limpando $RELEASE_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

cd "$REPO_ROOT/app"

echo "build.sh: rodando xcodebuild -configuration Release"
xcodebuild \
    -scheme Tagarela \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    clean build 2>&1 | tail -20

BUILT_APP="$DERIVED_DATA/Build/Products/Release/Tagarela.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "erro: $BUILT_APP não existe após xcodebuild"
    exit 1
fi

echo "build.sh: copiando .app pra $RELEASE_DIR/Tagarela.app"
cp -R "$BUILT_APP" "$RELEASE_DIR/Tagarela.app"

# Validar versão no Info.plist do .app copiado
version=$(plutil -p "$RELEASE_DIR/Tagarela.app/Contents/Info.plist" | grep CFBundleShortVersionString | sed -E 's/.*=> "([^"]+)".*/\1/')
echo ""
echo "build.sh: ok"
echo "BUILD_APP_PATH=$RELEASE_DIR/Tagarela.app"
echo "BUILD_VERSION=$version"
BUILDSH
chmod +x /Users/tars/Dev/tagarela/scripts/build.sh
```

- [ ] **Step 2: Smoke test**

```bash
cd /Users/tars/Dev/tagarela
./scripts/build.sh 2>&1 | tail -10
ls -la build/release/Tagarela.app | head -3
plutil -p build/release/Tagarela.app/Contents/Info.plist | grep -E "CFBundleShortVersionString|CFBundleVersion"
```

Esperado: `Tagarela.app` em `build/release/`, versão `1.0.0` build `1`. (Cert Release pode ainda não estar instalado se Pre-flight passo 3 não foi concluído — neste caso, build vai falhar com "No signing certificate found"; pular smoke test até o cert estar instalado.)

- [ ] **Step 3: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add scripts/build.sh
git commit -m "$(cat <<'EOF'
feat(release): scripts/build.sh — xcodebuild Release → build/release/

Limpa build/release/ e roda xcodebuild -configuration Release. Copia
Tagarela.app resultante pra build/release/Tagarela.app. Cert do Release
config (Developer ID Application) é aplicado pelo próprio Xcode; sign.sh
re-assina --deep com entitlements explícitos depois.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 8: `scripts/sign.sh`

Objetivo: script que re-assina `build/release/Tagarela.app` com `Developer ID Application` SHA-1 lido de `~/.tagarela-release.env`, hardened runtime, timestamp, e entitlements explícitos. Validar com `codesign --verify --strict`.

**Files:**
- Create: `scripts/sign.sh`

**Aceite manual obrigatório** (toca codesign).

- [ ] **Step 1: Criar `scripts/sign.sh`**

```bash
cat > /Users/tars/Dev/tagarela/scripts/sign.sh <<'SIGNSH'
#!/bin/bash
#
# sign.sh
#
# Re-assina build/release/Tagarela.app com cert Developer ID Application,
# hardened runtime, timestamp, e entitlements explícitos. Verifica.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$REPO_ROOT/build/release/Tagarela.app"
ENTITLEMENTS="$REPO_ROOT/app/Tagarela/Resources/Tagarela.entitlements"

# Carrega secrets
ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe (copiar de .tagarela-release.env.example)"
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [ -z "${DEVELOPER_ID_APP_SHA1:-}" ]; then
    echo "erro: DEVELOPER_ID_APP_SHA1 não setado em $ENV_FILE"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "erro: $APP_PATH não existe (rodar build.sh primeiro)"
    exit 1
fi

if [ ! -f "$ENTITLEMENTS" ]; then
    echo "erro: $ENTITLEMENTS não existe"
    exit 1
fi

echo "sign.sh: assinando $APP_PATH"
echo "        identity: $DEVELOPER_ID_APP_SHA1"

codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID_APP_SHA1" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_PATH"

echo "sign.sh: verificando assinatura"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tail -10

echo ""
echo "sign.sh: ok"
SIGNSH
chmod +x /Users/tars/Dev/tagarela/scripts/sign.sh
```

- [ ] **Step 2: Smoke test (requer cert Developer ID e ~/.tagarela-release.env preenchido)**

Pré-requisitos:
- Cert "Developer ID Application" instalado no Keychain (Pre-flight passo 3).
- `~/.tagarela-release.env` preenchido (com pelo menos `DEVELOPER_ID_APP_SHA1`).
- `./scripts/build.sh` já rodou com sucesso.

```bash
cd /Users/tars/Dev/tagarela
./scripts/sign.sh 2>&1 | tail -15
codesign -dv --verbose=4 build/release/Tagarela.app 2>&1 | grep -E "Identifier|Authority|TeamIdentifier"
```

Esperado:
- `Authority=Developer ID Application: Ilan Salviano (BCM26K6YNA)` (não mais `Apple Development`).
- `TeamIdentifier=BCM26K6YNA`.
- `sign.sh: ok`.

- [ ] **Step 3: ACEITE MANUAL — abrir o `.app` assinado e validar que app roda**

```bash
pkill -x Tagarela 2>/dev/null
sleep 1
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Dev/tagarela/build/release/Tagarela.app /Users/tars/Applications/Tagarela.app
open /Users/tars/Applications/Tagarela.app
```

Validar:
1. App abre (Gatekeeper local pode mostrar prompt "App de desenvolvedor não-identificado" — esperado neste passo; só some pós-notarization).
2. Hotkey funciona, transcribe + inject funcionam.

Se o macOS bloquear: System Settings → Privacy & Security → "Open Anyway" pra Tagarela.

Pedir confirmação ao user antes de seguir.

- [ ] **Step 4: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add scripts/sign.sh
git commit -m "$(cat <<'EOF'
feat(release): scripts/sign.sh — codesign --deep com Developer ID

Re-assina build/release/Tagarela.app com cert Developer ID Application
(SHA-1 lido de ~/.tagarela-release.env), hardened runtime, timestamp,
entitlements explícitos. Verifica via codesign --verify --strict.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 9: `scripts/notarize.sh`

Objetivo: script que zip o `.app`, submete pro `xcrun notarytool`, espera resposta da Apple, e staple o ticket no `.app`. Logs vão pra `build/release/notarization.log`.

**Files:**
- Create: `scripts/notarize.sh`

**Aceite manual obrigatório** (toca notarytool).

- [ ] **Step 1: Criar `scripts/notarize.sh`**

```bash
cat > /Users/tars/Dev/tagarela/scripts/notarize.sh <<'NOTARIZESH'
#!/bin/bash
#
# notarize.sh
#
# zip build/release/Tagarela.app → notarytool submit --wait → staple
# no .app. Logs em build/release/notarization.log.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$REPO_ROOT/build/release/Tagarela.app"
ZIP_PATH="$REPO_ROOT/build/release/Tagarela.zip"
LOG_PATH="$REPO_ROOT/build/release/notarization.log"

ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe"
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

for var in APPLE_ID APPLE_TEAM_ID APPLE_APP_SPECIFIC_PASSWORD; do
    if [ -z "${!var:-}" ]; then
        echo "erro: $var não setado em $ENV_FILE"
        exit 1
    fi
done

if [ ! -d "$APP_PATH" ]; then
    echo "erro: $APP_PATH não existe (rodar build.sh + sign.sh primeiro)"
    exit 1
fi

echo "notarize.sh: criando $ZIP_PATH"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "notarize.sh: submetendo pro notarytool (vai esperar resposta — pode levar 1-5 minutos)"
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait \
    --output-format plist 2>&1 | tee "$LOG_PATH"

# Verificar status
status=$(grep -A1 "<key>status</key>" "$LOG_PATH" | tail -1 | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
if [ "$status" != "Accepted" ]; then
    echo ""
    echo "erro: notarization status='$status' (esperado 'Accepted')"
    echo "      log completo em $LOG_PATH"
    echo "      consultar log detalhado:"
    submission_id=$(grep -A1 "<key>id</key>" "$LOG_PATH" | head -2 | tail -1 | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
    echo "      xcrun notarytool log $submission_id --apple-id $APPLE_ID --team-id $APPLE_TEAM_ID --password \$APPLE_APP_SPECIFIC_PASSWORD"
    exit 1
fi

echo ""
echo "notarize.sh: notarization aceita; staplando ticket no .app"
xcrun stapler staple "$APP_PATH"

echo "notarize.sh: validando staple"
xcrun stapler validate "$APP_PATH"

echo ""
echo "notarize.sh: ok"
NOTARIZESH
chmod +x /Users/tars/Dev/tagarela/scripts/notarize.sh
```

- [ ] **Step 2: Smoke test (requer build.sh + sign.sh + secrets completos)**

```bash
cd /Users/tars/Dev/tagarela
./scripts/notarize.sh 2>&1 | tail -20
xcrun stapler validate build/release/Tagarela.app
```

Esperado:
- Output inclui `status: Accepted`.
- `xcrun stapler validate` retorna `The validate action worked!`.
- Tempo total: 1-5 minutos.

- [ ] **Step 3: ACEITE MANUAL — abrir `.app` notarizado num Mac (ou após reset Gatekeeper)**

```bash
# Reset Gatekeeper "downloaded from internet" attribute
xattr -cr /Users/tars/Dev/tagarela/build/release/Tagarela.app

# Marcar como vindo de download (simula download de outra máquina)
xattr -w com.apple.quarantine "0083;65500000;Safari;F10ED0EE-50CA-4DC8-A5A0-39CCBC59D9D4" /Users/tars/Dev/tagarela/build/release/Tagarela.app 2>/dev/null || true

pkill -x Tagarela 2>/dev/null
sleep 1
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Dev/tagarela/build/release/Tagarela.app /Users/tars/Applications/Tagarela.app

# Re-aplicar quarantine no instalado
xattr -w com.apple.quarantine "0083;65500000;Safari;F10ED0EE-50CA-4DC8-A5A0-39CCBC59D9D4" /Users/tars/Applications/Tagarela.app 2>/dev/null || true

open /Users/tars/Applications/Tagarela.app
```

Validar:
1. macOS mostra apenas popup `"App baixado da internet — abrir?"` (1× só, primeira abertura).
2. NÃO mostra `"Não é possível verificar o desenvolvedor"` ou similar.
3. App roda; hotkey + transcribe + inject ok.

Se popup de "desenvolvedor não-identificado" aparecer mesmo após notarization: investigar (cert errado, entitlements faltando, dylib não-signed).

Pedir confirmação ao user antes de seguir.

- [ ] **Step 4: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add scripts/notarize.sh
git commit -m "$(cat <<'EOF'
feat(release): scripts/notarize.sh — notarytool submit + staple

Zip do .app → xcrun notarytool submit --wait → xcrun stapler staple no
.app. Lê APPLE_ID/APPLE_TEAM_ID/APPLE_APP_SPECIFIC_PASSWORD de
~/.tagarela-release.env. Logs em build/release/notarization.log.
Falha fast se status != Accepted.

Aceite manual ok: app notarizado abre em máquina limpa (Gatekeeper
mostra só "baixado da internet", não "desenvolvedor não-identificado").

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 10: `scripts/dmg.sh`

Objetivo: script que cria `Tagarela-<version>.dmg` com layout vertical (`.app` + symlink pra `/Applications`), assina o DMG, staple notarization no DMG. Versão lida do Info.plist do `.app`.

**Files:**
- Create: `scripts/dmg.sh`

**Aceite manual obrigatório** (toca codesign + DMG).

- [ ] **Step 1: Criar `scripts/dmg.sh`**

```bash
cat > /Users/tars/Dev/tagarela/scripts/dmg.sh <<'DMGSH'
#!/bin/bash
#
# dmg.sh
#
# Cria Tagarela-<version>.dmg com .app + symlink /Applications, assina,
# staple. Versão lida do Info.plist do .app já notarizado.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$REPO_ROOT/build/release/Tagarela.app"
RELEASE_DIR="$REPO_ROOT/build/release"

ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe"
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [ -z "${DEVELOPER_ID_APP_SHA1:-}" ]; then
    echo "erro: DEVELOPER_ID_APP_SHA1 não setado em $ENV_FILE"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "erro: $APP_PATH não existe (rodar build.sh + sign.sh + notarize.sh primeiro)"
    exit 1
fi

# Lê versão do Info.plist
version=$(plutil -p "$APP_PATH/Contents/Info.plist" | grep CFBundleShortVersionString | sed -E 's/.*=> "([^"]+)".*/\1/')
if [ -z "$version" ]; then
    echo "erro: não consegui ler CFBundleShortVersionString"
    exit 1
fi

DMG_PATH="$RELEASE_DIR/Tagarela-$version.dmg"
STAGING_DIR="$RELEASE_DIR/dmg-staging"

echo "dmg.sh: criando $DMG_PATH (versão $version)"

# Limpa e prepara staging dir
rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copia .app + cria symlink pra /Applications
cp -R "$APP_PATH" "$STAGING_DIR/Tagarela.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Cria DMG (formato UDZO comprimido)
hdiutil create \
    -volname "Tagarela $version" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "dmg.sh: assinando DMG"
codesign \
    --force \
    --sign "$DEVELOPER_ID_APP_SHA1" \
    --timestamp \
    "$DMG_PATH"

echo "dmg.sh: staplando ticket no DMG"
xcrun stapler staple "$DMG_PATH"

echo "dmg.sh: validando staple"
xcrun stapler validate "$DMG_PATH"

# Limpa staging
rm -rf "$STAGING_DIR"

echo ""
echo "dmg.sh: ok"
echo "DMG_PATH=$DMG_PATH"
echo "DMG_VERSION=$version"
DMGSH
chmod +x /Users/tars/Dev/tagarela/scripts/dmg.sh
```

- [ ] **Step 2: Smoke test (requer build + sign + notarize concluídos)**

```bash
cd /Users/tars/Dev/tagarela
./scripts/dmg.sh 2>&1 | tail -10
ls -la build/release/Tagarela-*.dmg
xcrun stapler validate build/release/Tagarela-*.dmg
```

Esperado: `Tagarela-1.0.0.dmg` criado e stapled.

- [ ] **Step 3: ACEITE MANUAL — abrir o DMG, validar layout**

```bash
open /Users/tars/Dev/tagarela/build/release/Tagarela-*.dmg
```

Validar visualmente:
1. DMG monta (volume `Tagarela 1.0.0` aparece em Finder).
2. Conteúdo: `Tagarela.app` + symlink `Applications` (apontando pra `/Applications`).
3. Arrastar `Tagarela.app` pro symlink `Applications` instala.
4. Após desmontar, testar abrir o app de `~/Applications` — funciona.

Pedir confirmação ao user antes de seguir.

- [ ] **Step 4: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add scripts/dmg.sh
git commit -m "$(cat <<'EOF'
feat(release): scripts/dmg.sh — DMG + sign + staple

Cria Tagarela-<version>.dmg com .app + symlink /Applications via hdiutil
UDZO. Assina o DMG com Developer ID + timestamp. Staple ticket de
notarization no DMG. Versão lida do CFBundleShortVersionString do .app.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 11: `scripts/appcast.sh`

Objetivo: script que adiciona um novo `<item>` ao `appcast.xml` apontando pro DMG do release atual. Usa `sign_update` (binário do Sparkle SPM) pra gerar a assinatura EdDSA. Calcula `length` do arquivo. Commita o `appcast.xml`.

**Files:**
- Create: `scripts/appcast.sh`

**Aceite manual obrigatório** (toca Sparkle).

- [ ] **Step 1: Criar `scripts/appcast.sh`**

```bash
cat > /Users/tars/Dev/tagarela/scripts/appcast.sh <<'APPCASTSH'
#!/bin/bash
#
# appcast.sh
#
# Adiciona <item> ao appcast.xml apontando pro DMG do release atual.
# Usa sign_update (Sparkle) pra gerar EdDSA signature do DMG.
# GitHub Releases URL é construída a partir da versão.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$REPO_ROOT/build/release"
APPCAST_PATH="$REPO_ROOT/appcast.xml"

ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe"
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [ -z "${SPARKLE_ED_PRIVATE_KEY_PATH:-}" ]; then
    echo "erro: SPARKLE_ED_PRIVATE_KEY_PATH não setado"
    exit 1
fi
if [ ! -f "$SPARKLE_ED_PRIVATE_KEY_PATH" ]; then
    echo "erro: $SPARKLE_ED_PRIVATE_KEY_PATH não existe (gerar com Sparkle generate_keys -x)"
    exit 1
fi

# Detectar GITHUB_USER do remote
GITHUB_USER=$(cd "$REPO_ROOT" && git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+)/.*|\1|' || echo "")
if [ -z "$GITHUB_USER" ]; then
    echo "erro: não consegui detectar GITHUB_USER do remote 'origin'"
    echo "      configurar com: git remote add origin git@github.com:<user>/tagarela.git"
    exit 1
fi

# Encontrar o DMG mais recente em build/release/
DMG_PATH=$(ls -t "$RELEASE_DIR"/Tagarela-*.dmg 2>/dev/null | head -1)
if [ -z "$DMG_PATH" ] || [ ! -f "$DMG_PATH" ]; then
    echo "erro: nenhum DMG encontrado em $RELEASE_DIR (rodar dmg.sh primeiro)"
    exit 1
fi

DMG_NAME=$(basename "$DMG_PATH")
version=$(echo "$DMG_NAME" | sed -E 's/Tagarela-([0-9.]+)\.dmg/\1/')
length=$(stat -f %z "$DMG_PATH")

# Localizar sign_update (binário do Sparkle SPM)
SPARKLE_ARTIFACTS=$(find ~/Library/Developer/Xcode/DerivedData/Tagarela-*/SourcePackages/artifacts -type d -name "Sparkle" 2>/dev/null | head -1)
SIGN_UPDATE=""
for candidate in "$SPARKLE_ARTIFACTS/bin/sign_update" "$SPARKLE_ARTIFACTS/Sparkle/bin/sign_update"; do
    if [ -x "$candidate" ]; then
        SIGN_UPDATE="$candidate"
        break
    fi
done
if [ -z "$SIGN_UPDATE" ]; then
    echo "erro: sign_update não encontrado em $SPARKLE_ARTIFACTS/{bin,Sparkle/bin}"
    exit 1
fi

echo "appcast.sh: assinando $DMG_NAME"
SIGNATURE_OUTPUT=$("$SIGN_UPDATE" -f "$SPARKLE_ED_PRIVATE_KEY_PATH" "$DMG_PATH")
# Output do sign_update: 'sparkle:edSignature="..." length="..."'
ed_signature=$(echo "$SIGNATURE_OUTPUT" | sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/')
if [ -z "$ed_signature" ] || [ "$ed_signature" = "$SIGNATURE_OUTPUT" ]; then
    echo "erro: não consegui extrair edSignature do output do sign_update"
    echo "      output: $SIGNATURE_OUTPUT"
    exit 1
fi

dmg_url="https://github.com/$GITHUB_USER/tagarela/releases/download/v$version/$DMG_NAME"
pub_date=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

# Construir o novo <item>
new_item=$(cat <<EOF
    <item>
      <title>Versão $version</title>
      <pubDate>$pub_date</pubDate>
      <sparkle:version>$version</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <enclosure
        url="$dmg_url"
        sparkle:edSignature="$ed_signature"
        length="$length"
        type="application/octet-stream" />
    </item>
EOF
)

# Inserir o item logo após <!-- Items adicionados por scripts/appcast.sh a cada release -->
# Usar Python pra manipular XML preservando formato (sed XML é frágil).
python3 - "$APPCAST_PATH" "$new_item" <<'PYEOF'
import sys, re

path = sys.argv[1]
new_item = sys.argv[2]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Inserir o novo item logo após o comentário marker, ou logo antes de </channel>
marker = "<!-- Items adicionados por scripts/appcast.sh a cada release -->"
if marker in content:
    content = content.replace(marker, marker + "\n" + new_item, 1)
else:
    content = content.replace("</channel>", new_item + "\n  </channel>", 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"appcast.sh: <item> v{sys.argv[2].split('Versão ')[1].split('<')[0] if 'Versão' in sys.argv[2] else '?'} inserido em {path}")
PYEOF

# Commit do appcast.xml
cd "$REPO_ROOT"
git add appcast.xml
git commit -m "chore(release): appcast.xml v$version"

echo ""
echo "appcast.sh: ok"
echo "APPCAST_VERSION=$version"
echo "APPCAST_DMG_URL=$dmg_url"
APPCASTSH
chmod +x /Users/tars/Dev/tagarela/scripts/appcast.sh
```

- [ ] **Step 2: Smoke test (requer dmg.sh concluído + private key + remote origin)**

```bash
cd /Users/tars/Dev/tagarela
git remote get-url origin 2>&1 | head -1   # confirmar que remote existe
./scripts/appcast.sh 2>&1 | tail -10
cat appcast.xml | head -30
```

Esperado: `appcast.xml` ganha um `<item>` com `<sparkle:version>1.0.0</sparkle:version>` + `edSignature` + `length` + URL do DMG no GitHub.

- [ ] **Step 3: ACEITE MANUAL — validar XML está bem formado**

```bash
xmllint --noout /Users/tars/Dev/tagarela/appcast.xml && echo "XML válido"
```

Esperado: `XML válido` (sem erros). Se errar, investigar e corrigir antes de seguir.

- [ ] **Step 4: Reverter o commit do smoke test (não queremos appcast com URL fake)**

```bash
cd /Users/tars/Dev/tagarela
git reset --hard HEAD~1
```

(O commit do `appcast.sh` em si já foi feito antes; estamos só desfazendo o `chore(release): appcast.xml v1.0.0` do smoke. Confirmar que `appcast.xml` voltou pro channel vazio.)

```bash
cat appcast.xml | head -10
```

Esperado: channel sem `<item>`.

- [ ] **Step 5: Commit do script (sem o appcast modificado)**

```bash
cd /Users/tars/Dev/tagarela
git add scripts/appcast.sh
git commit -m "$(cat <<'EOF'
feat(release): scripts/appcast.sh — gera <item> + sign_update EdDSA

Adiciona <item> ao appcast.xml apontando pro DMG mais recente em
build/release/. Usa sign_update do Sparkle SPM pra assinar EdDSA.
URL do DMG construída automaticamente pra
github.com/<user>/tagarela/releases/download/v<version>/<dmg>.
Detecta GITHUB_USER do remote 'origin'.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 12: `scripts/release.sh` (orquestrador)

Objetivo: chama os 6 scripts em sequência, faz `gh release create` no final, e `git push --follow-tags`. Aceita `initial` (pula bump.sh — pra v1.0.0) ou `patch|minor|major` (chama bump.sh primeiro).

**Files:**
- Create: `scripts/release.sh`

**Aceite manual obrigatório** (orquestra signing/notarization/Sparkle/release).

- [ ] **Step 1: Criar `scripts/release.sh`**

```bash
cat > /Users/tars/Dev/tagarela/scripts/release.sh <<'RELEASESH'
#!/bin/bash
#
# release.sh initial|patch|minor|major
#
# Orquestrador: bump (se não-initial) → build → sign → notarize → dmg →
#               appcast → gh release create → git push --follow-tags
#
# initial: pula bump.sh (pra v1.0.0 onde MARKETING_VERSION já está
#          editado em project.yml).
# patch/minor/major: chama bump.sh primeiro.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "uso: release.sh initial|patch|minor|major"
    exit 64
fi

case "$1" in
    initial|patch|minor|major) ;;
    *) echo "erro: arg inválido '$1'"; exit 64 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$REPO_ROOT/scripts"

ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe (copiar de .tagarela-release.env.example)"
    exit 1
fi

# Confirma working tree limpa
cd "$REPO_ROOT"
if [ -n "$(git status --porcelain)" ]; then
    echo "erro: working tree não está limpa"
    git status --short
    exit 1
fi

# Confirma estamos em main (ou avisa)
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "main" ]; then
    echo "aviso: não está em main (current: $current_branch). Continuar? (y/N)"
    read -r confirm
    if [ "$confirm" != "y" ]; then
        echo "cancelado."
        exit 0
    fi
fi

# 1. Bump (se aplicável)
if [ "$1" != "initial" ]; then
    echo "===== 1/7 bump ====="
    "$SCRIPTS/bump.sh" "$1"
fi

# 2. Build
echo "===== 2/7 build ====="
"$SCRIPTS/build.sh"

# 3. Sign
echo "===== 3/7 sign ====="
"$SCRIPTS/sign.sh"

# 4. Notarize
echo "===== 4/7 notarize ====="
"$SCRIPTS/notarize.sh"

# 5. DMG
echo "===== 5/7 dmg ====="
"$SCRIPTS/dmg.sh"

# 6. Appcast
echo "===== 6/7 appcast ====="
"$SCRIPTS/appcast.sh"

# Lê versão atual
version=$(grep -E '^\s*MARKETING_VERSION:' "$REPO_ROOT/app/project.yml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
DMG_PATH="$REPO_ROOT/build/release/Tagarela-$version.dmg"

# Cria git tag
echo "===== 7/7 tag + push + gh release ====="
git tag "v$version"

# Push commits + tags
git push --follow-tags

# gh release create
gh release create "v$version" "$DMG_PATH" \
    --title "tagarela $version" \
    --generate-notes

echo ""
echo "release.sh: v$version publicado"
echo "  DMG: $DMG_PATH"
echo "  GitHub: $(gh release view v$version --json url -q .url)"
RELEASESH
chmod +x /Users/tars/Dev/tagarela/scripts/release.sh
```

- [ ] **Step 2: Commit do script**

```bash
cd /Users/tars/Dev/tagarela
git add scripts/release.sh
git commit -m "$(cat <<'EOF'
feat(release): scripts/release.sh orquestrador

initial|patch|minor|major: encadeia bump (se não-initial) → build →
sign → notarize → dmg → appcast → git tag → git push --follow-tags
→ gh release create. Falha fast se working tree suja ou env file
faltando.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

(Aceite manual deste script combina com Bloco A da T14.)

---

## Tarefa 13: Setup-dev doc + atualização cleanup-fase1 #6

Objetivo: criar `00-setup-dev.md` documentando o onboarding pra outra máquina dev (instalar certs, popups TCC, secrets do release pipeline). Atualizar item #6 do `cleanup-fase1.md` apontando pro setup-dev e sinalizando pendência de validação na T14.

**Files:**
- Create: `tagarela_docs/02-arquitetura/00-setup-dev.md`
- Modify: `tagarela_docs/04-decisoes/cleanup-fase1.md` (item #6)
- Modify: `tagarela_docs/README.md` (adicionar entry)

- [ ] **Step 1: Criar `00-setup-dev.md`**

```bash
cat > /Users/tars/Dev/tagarela/tagarela_docs/02-arquitetura/00-setup-dev.md <<'EOF'
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

1. Buildar e abrir Tagarela.app a partir de `~/Applications` (NÃO direto do Xcode build; o popup TCC nativo pode falhar).
2. Disparar hotkey (Right Option) — popup nativo de Microphone aparece. Aceitar.
3. System Settings → Privacy & Security → Accessibility, adicionar Tagarela.app manualmente (clicar `+`).
4. System Settings → Privacy & Security → Input Monitoring, adicionar Tagarela.app manualmente.
5. Reabrir o app. Hotkey deve transcrever + injetar texto em outro app.

> **Nota:** o cleanup #6 da Fase 1 documentava workaround via SQL no TCC.db pra esses popups não aparecerem antes do Developer ID. Pós-Fase 3, popups nativos voltam — workaround SQL não é mais necessário.

## Builds Release (gerar DMG distribuível)

Pra rodar o pipeline de release localmente, precisa do cert "Developer ID Application" instalado e dos secrets em `~/.tagarela-release.env`.

1. Apple Developer portal → Certificates → Developer ID Application → gerar e instalar.
2. SHA-1 do cert vai em `app/project.yml` configs.Release.
3. App-specific password em https://appleid.apple.com → Sign-In and Security.
4. Sparkle EdDSA private key — gerar via `generate_keys` do Sparkle SPM, exportar pra arquivo (`-x`), salvar em `~/.tagarela-release/sparkle_ed_private.key` (chmod 600). **Backup em local seguro** (1Password etc.).
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
EOF
```

- [ ] **Step 2: Atualizar item #6 de `cleanup-fase1.md`**

Em `tagarela_docs/04-decisoes/cleanup-fase1.md`, localizar a seção "## 6. Permissões TCC injetadas manualmente via SQLite" (`grep -n "## 6" tagarela_docs/04-decisoes/cleanup-fase1.md` retorna a linha). No início dessa seção, adicionar nota:

```markdown
**Status (2026-05-01):** validação executada na Fase 3 — ver Bloco C do checklist `tagarela_docs/03-funcionalidades/checklists/fase3-manual.md`. Setup atualizado em `tagarela_docs/02-arquitetura/00-setup-dev.md`.
```

(Texto definitivo do status — "fechado" ou "anomalia" — só na T14 após Bloco C ser executado.)

- [ ] **Step 3: Atualizar `tagarela_docs/README.md`**

Adicionar entry na seção `### 02 — Arquitetura` (logo após a entry de `01-modulos-fase1.md` ou antes — escolher posição clara):

```markdown
- [`00-setup-dev.md`](./02-arquitetura/00-setup-dev.md) — onboard de um Mac novo pra dev: builds Debug, permissões TCC, build pipeline de release.
```

- [ ] **Step 4: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add tagarela_docs/02-arquitetura/00-setup-dev.md \
        tagarela_docs/04-decisoes/cleanup-fase1.md \
        tagarela_docs/README.md
git commit -m "$(cat <<'EOF'
docs: 00-setup-dev.md + cleanup-fase1 #6 com pointer pra Fase 3

- 00-setup-dev.md (novo): onboard de outra máquina dev (builds Debug,
  TCC, build pipeline de release).
- cleanup-fase1.md item #6: status apontando pra checklist Bloco C +
  setup-dev. Texto definitivo (fechado ou anomalia) entra na T14.
- README do vault: entry pro setup-dev.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 14: Aceite manual end-to-end (Blocos A-E) + checklist + docs finais

Objetivo: rodar os 5 blocos do checklist de aceite (A-E), preencher resultados em `fase3-manual.md`, fechar ou anotar cleanup #6, criar snapshot pós-Fase 3, atualizar índice.

**Files:**
- Create: `tagarela_docs/03-funcionalidades/checklists/fase3-manual.md`
- Create: `tagarela_docs/02-arquitetura/08-modulos-fase3.md`
- Modify: `tagarela_docs/04-decisoes/cleanup-fase1.md` (status definitivo do #6)
- Modify: `tagarela_docs/README.md` (entries finais + status implementado)

**Aceite manual extensivo.** Esta tarefa é a fonte da verdade do "v1 distribuível funciona".

- [ ] **Step 1: Criar checklist `fase3-manual.md`**

```bash
cat > /Users/tars/Dev/tagarela/tagarela_docs/03-funcionalidades/checklists/fase3-manual.md <<'EOF'
---
data: 2026-05-01
fase: 3-release
status: aberto
---

# Aceite manual — Fase 3 (release engineering)

## Bloco A — primeiro release end-to-end (v1.0.0)

Pré: cert Developer ID Application instalado, ~/.tagarela-release.env preenchido + chmod 600, Sparkle SPM resolvido + keypair gerado + public key em Info.plist, gh CLI logado, remote 'origin' configurado pro repo.

- [ ] `./scripts/release.sh initial` executa sem erro.
- [ ] `Tagarela-1.0.0.dmg` em `build/release/`.
- [ ] `notarization.log` com `status: Accepted`.
- [ ] `xcrun stapler validate Tagarela.app && xcrun stapler validate Tagarela-1.0.0.dmg` passa.
- [ ] `appcast.xml` atualizado com 1 `<item>`, commitado.
- [ ] `git tag v1.0.0` criada.
- [ ] `gh release view v1.0.0` mostra DMG anexado.
- [ ] `git push --follow-tags` enviou main + tag.

## Bloco B — Gatekeeper em máquina limpa

- [ ] Em outro Mac (ou após `xattr -cr` + reset Gatekeeper), baixar DMG do GitHub via curl/Safari.
- [ ] Abrir DMG → arrastar pra Applications.
- [ ] Primeira abertura: popup "App baixado da internet — abrir?" (1×). NÃO `"Não é possível verificar o desenvolvedor"`.
- [ ] App roda; pílula aparece; injeção funciona.

## Bloco C — TCC nativo (cleanup #6 da Fase 1)

- [ ] `tccutil reset Microphone com.tagarela.Tagarela`
- [ ] `tccutil reset Accessibility com.tagarela.Tagarela`
- [ ] `tccutil reset ListenEvent com.tagarela.Tagarela`  (Input Monitoring)
- [ ] Reabrir Tagarela.app.
- [ ] Disparar hotkey → popup nativo de Microphone aparece. Aceitar.
- [ ] Disparar hotkey de novo → popup ou redirect pra Settings (Accessibility / Input Monitoring). Aceitar.
- [ ] Hotkey + transcribe + inject funcionam fim-a-fim.
- [ ] **Resultado:** popups nativos apareceram? (sim → cleanup #6 fechado; não → registrar anomalia).

## Bloco D — Sparkle (após v1.0.1)

Pré: v1.0.0 instalada via DMG (Bloco A/B). Roda `./scripts/release.sh patch` pra subir v1.0.1.

- [ ] `release.sh patch` executa sem erro. v1.0.1 publicada.
- [ ] Abrir v1.0.0 instalada. Forçar Sparkle a checar (se necessário, `defaults write com.tagarela.Tagarela SULastCheckTime -string 'never'` antes de abrir).
- [ ] Sheet nativa de update aparece em até alguns minutos.
- [ ] Aceitar update → app baixa, valida EdDSA, instala, reabre como v1.0.1.
- [ ] `defaults read com.tagarela.Tagarela CFBundleShortVersionString` ou versão exibida em Preferências > Sobre = 1.0.1.

## Bloco E — botão Console em Preferências > Sobre

- [ ] Preferências (⌘ ,) → Sobre → botão "Abrir logs no Console".
- [ ] Console.app abre.
- [ ] (Versão A) Filtro `subsystem == com.tagarela` aplicado. Logs do app visíveis em tempo real.
- [ ] (Versão B fallback) Console.app abre sem filtro; user filtra manual; ainda dá pra ler logs.

---

Status final: ok | ok-com-achados | bloqueado.

Eventuais achados vão pra `tagarela_docs/04-decisoes/cleanup-fase3.md`.
EOF
```

- [ ] **Step 2: Executar Bloco A — primeiro release v1.0.0**

```bash
cd /Users/tars/Dev/tagarela
./scripts/release.sh initial 2>&1 | tee /tmp/release-1.0.0.log | tail -40
```

Verificar cada linha do Bloco A no checklist. Se algum passo falhar, parar e investigar logs (`build/release/notarization.log`, `/tmp/release-1.0.0.log`).

- [ ] **Step 3: Executar Bloco B — Gatekeeper máquina limpa**

```bash
cd /Users/tars/Dev/tagarela
# Reset local pra simular máquina limpa
xattr -cr build/release/Tagarela-*.dmg
rm -rf /Users/tars/Applications/Tagarela.app
# Abrir o DMG
open build/release/Tagarela-*.dmg
```

User instala manualmente arrastando pra Applications. Tenta abrir. Marca cada item.

- [ ] **Step 4: Executar Bloco C — TCC nativo**

```bash
tccutil reset Microphone com.tagarela.Tagarela
tccutil reset Accessibility com.tagarela.Tagarela
tccutil reset ListenEvent com.tagarela.Tagarela
pkill -x Tagarela 2>/dev/null
sleep 1
open /Users/tars/Applications/Tagarela.app
```

User dispara hotkey 2-3× e marca cada popup nativo que aparece.

**Resultado do Bloco C** determina o status do cleanup #6 da Fase 1:
- Se popups nativos aparecerem: cleanup #6 **fechado**.
- Se NÃO aparecerem: cleanup #6 segue **aberto** como anomalia documentada (workaround SQL ainda necessário).

- [ ] **Step 5: Executar Bloco D — Sparkle**

```bash
cd /Users/tars/Dev/tagarela
./scripts/release.sh patch 2>&1 | tee /tmp/release-1.0.1.log | tail -40
# v1.0.1 publicada. Forçar Sparkle a checar:
defaults write com.tagarela.Tagarela SULastCheckTime -string 'never'
pkill -x Tagarela 2>/dev/null
sleep 1
open /Users/tars/Applications/Tagarela.app
```

User aguarda alguns minutos pelo prompt de update do Sparkle. Marca cada item.

- [ ] **Step 6: Executar Bloco E — botão Console**

User abre Preferências > Sobre > botão. Marca.

- [ ] **Step 7: Atualizar `cleanup-fase1.md` item #6 com status definitivo**

Em `tagarela_docs/04-decisoes/cleanup-fase1.md` item #6, substituir o "Status (2026-05-01)" pela conclusão do Bloco C:

Se popups nativos apareceram, substituir pela linha:
```markdown
**Status (2026-05-01): ✅ fechado.** Validação Bloco C da Fase 3 — popups TCC nativos voltaram a funcionar pós Developer ID + notarization. Workaround SQL não é mais necessário; setup atualizado em `00-setup-dev.md`.
```

Se NÃO apareceram:
```markdown
**Status (2026-05-01): ❌ aberto (anomalia).** Validação Bloco C da Fase 3 — popups TCC NÃO apareceram mesmo pós Developer ID + notarization. Workaround SQL segue necessário pra novos devs. Hipóteses: <preencher após investigação>. Documentar em ADR.
```

- [ ] **Step 8: Criar snapshot `08-modulos-fase3.md`**

```bash
cat > /Users/tars/Dev/tagarela/tagarela_docs/02-arquitetura/08-modulos-fase3.md <<'EOF'
---
data: 2026-05-01
fase: 3-release
status: implementado
---

# Snapshot pós-Fase 3

A Fase 3 entregou o pipeline de release: cert Developer ID Application, entitlements completos, notarization, DMG, Sparkle minimal. Sem refactor de código de produto.

## Mudanças no app

### `app/Tagarela/Resources/Tagarela.entitlements`
- 3 claims: `audio-input`, `automation.apple-events`, `cs.disable-library-validation`. Antes: vazio.

### `app/project.yml`
- `targets.Tagarela.settings.configs` split de `CODE_SIGN_IDENTITY` por configuração: Debug = Apple Development, Release = Developer ID Application.
- `packages.Sparkle` adicionado (from `2.6.0`); `dependencies` do target ganha `Sparkle`.

### `app/Tagarela/Resources/Info.plist`
- `CFBundleShortVersionString` e `CFBundleVersion` viraram `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` (lidas do project.yml).
- 5 chaves novas Sparkle: `SUFeedURL`, `SUEnableAutomaticChecks`, `SUScheduledCheckInterval` (86400), `SUPublicEDKey`, `LSApplicationCategoryType` (utilities).

### `app/Tagarela/App/AppContainer.swift`
- `import Sparkle`. Stored property `let updaterController: SPUStandardUpdaterController`. Init com `startingUpdater: true` — auto-check no launch + a cada 24h. Sem UI manual.

### `app/Tagarela/Preferences/UI/Sections/AboutView.swift`
- Botão "Abrir logs no Console". (Versão A: `--predicate` por argv funcionou. | Versão B: fallback sem filtro.) — preencher com qual venceu.

## Pipeline de release (`scripts/`)

7 scripts modulares + secrets em `~/.tagarela-release.env` (template em `.tagarela-release.env.example` na root).

- `bump.sh patch|minor|major` — edita project.yml + xcodegen + commit.
- `build.sh` — xcodebuild Release → build/release/Tagarela.app.
- `sign.sh` — codesign --deep com Developer ID + entitlements.
- `notarize.sh` — zip → notarytool submit --wait → staple.
- `dmg.sh` — hdiutil + sign + staple no DMG.
- `appcast.sh` — gera <item> no appcast.xml com sign_update EdDSA.
- `release.sh initial|patch|minor|major` — orquestrador + git tag + gh release create + git push --follow-tags.

`appcast.xml` versionado no repo, raw URL em `Info.plist`. DMGs hospedados em GitHub Releases.

## Cleanup #6 da Fase 1

(preencher após Bloco C: popups nativos apareceram → fechado; não apareceram → anomalia)

## Decisões nucleares

- Distribuição: solo + alguns conhecidos via DMG no GitHub Releases (repo público).
- Sparkle minimal: auto-check no launch, sem UI manual.
- Logging: botão "Abrir Console.app" — sem arquivo persistido.
- Versionamento: bump.sh manual (semver explicit).
- Secrets: `~/.tagarela-release.env` plain text + chmod 600 + gitignored.

## Bench (release time)

(opcional — preencher se medir)

| Step | Tempo médio |
|---|---|
| build.sh | ~? min |
| notarize.sh | 1-5 min (Apple) |
| Total release.sh patch | ~? min |

## Lição operacional aplicada

Cada tarefa que tocou codesign/notarize/Sparkle (T1, T3, T4, T8, T9, T10) teve aceite manual em build local antes do commit. Bloco A (release end-to-end) e Bloco D (Sparkle update) só puderam ser validados após o pipeline completo — fizeram parte da Tarefa 14 (aceite manual extensivo).
EOF
```

- [ ] **Step 9: Atualizar `tagarela_docs/README.md`**

Adicionar entries:

Na seção `### 02 — Arquitetura`:
```markdown
- [`08-modulos-fase3.md`](./02-arquitetura/08-modulos-fase3.md) — snapshot pós-Fase 3 (release engineering): Developer ID + entitlements + notarization + DMG + Sparkle minimal + 7 scripts modulares + setup-dev. <complete o resto após T14>
```

Na seção `### 03 — Funcionalidades`:
```markdown
- [`checklists/fase3-manual.md`](./03-funcionalidades/checklists/fase3-manual.md) — aceite manual da Fase 3 (5 blocos: release end-to-end, Gatekeeper, TCC nativo, Sparkle, botão Console). Status: <preencher após T14>.
```

Atualizar entry do design da Fase 3 pra **Status: implementado** (com SHA do merge — preencher após T15).

E adicionar entry do plan:
```markdown
- [`2026-05-01-tagarela-v1-fase3-release-plan.md`](./specs/2026-05-01-tagarela-v1-fase3-release-plan.md) — plano executado da Fase 3 (15 tarefas, 7 scripts, +0 testes unitários, suíte 181).
```

- [ ] **Step 10: Commit final dos docs**

```bash
cd /Users/tars/Dev/tagarela
git add tagarela_docs/
git commit -m "$(cat <<'EOF'
docs: snapshot pós-Fase 3 + checklist manual + status #6

- 08-modulos-fase3.md (novo): entrega da fase, módulos novos/modificados,
  pipeline de release, decisão sobre cleanup #6.
- 03-funcionalidades/checklists/fase3-manual.md (novo): 5 blocos de aceite
  rodados na T14.
- cleanup-fase1.md item #6: status definitivo.
- README do vault: entries pros 2 docs novos + status implementado da
  Fase 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 15: Merge `fase-3` → `main`

Objetivo: integrar `fase-3` em `main`. Sem push de force; tags já foram pushadas pela `release.sh`.

- [ ] **Step 1: Confirmar suíte verde + clean tree em `fase-3`**

```bash
cd /Users/tars/Dev/tagarela
git status                                  # nothing to commit, working tree clean
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Esperado: 181 testes verdes.

- [ ] **Step 2: Trocar pra main e mergear**

```bash
git checkout main
git pull --ff-only origin main 2>/dev/null || true   # se algo foi pushado durante a fase
git merge --no-ff fase-3 -m "$(cat <<'EOF'
Merge fase-3 into main: release engineering

- Cert Developer ID Application + split Debug/Release no project.yml.
- Entitlements completos (audio-input, automation, disable-library-validation).
- Sparkle 2.6+ minimal: auto-check no launch + sheet nativa.
- 7 scripts modulares em scripts/ (bump/build/sign/notarize/dmg/appcast/release).
- appcast.xml + raw GitHub URL.
- Botão "Abrir logs no Console" em Preferências > Sobre.
- 00-setup-dev.md doc.
- Cleanup #6 da Fase 1: <fechado | anomalia> via Bloco C.

Suíte 181 verde (sem testes novos — Fase 3 é tudo build/distribuição).
v1.0.0 e v1.0.1 publicadas em GitHub Releases via release.sh.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Re-rodar suíte em main**

```bash
cd /Users/tars/Dev/tagarela
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|TEST" | tail -3
```

Esperado: 181 testes, `** TEST SUCCEEDED **`.

- [ ] **Step 4: Push merge commit**

```bash
git push origin main
```

(Tags `v1.0.0` e `v1.0.1` já foram pushadas pela `release.sh` durante a T14.)

- [ ] **Step 5: Smoke final**

```bash
gh release list | head -5
gh release view v1.0.0 --json url -q .url
gh release view v1.0.1 --json url -q .url
```

Esperado: 2 releases listadas com DMGs anexados.

---

## Self-review

**Spec coverage:**
- §1 Arquitetura geral → cobertura distribuída em todas as 15 tarefas ✓
- §Decisões nucleares 1-11 → cada uma materializada em uma tarefa específica ✓
- §Componentes novos → T3 Sparkle, T4 botão Console, T5-T12 scripts, T13 setup-dev ✓
- §Componentes modificados → T1 entitlements, T2 project.yml + Info.plist, T3 AppContainer, T4 AboutView ✓
- §Pipeline de release → T6-T12 (7 scripts) ✓
- §Aceite manual Blocos A-E → T14 ✓
- §Cleanup #6 validação → T14 Bloco C + T13/T14 update doc ✓
- §Riscos: notarization falha (mitigado em T9 fail-fast), cleanup #6 não valida (mitigado em T14 step 7 com texto alternativo), Sparkle key perdida (mitigado em T3 Step 4 com aviso de backup), Console.app --predicate (mitigado em T4 step 1 testando empiricamente) ✓

**Placeholder scan:**
- T13 Step 2: "Texto definitivo do status — fechado ou anomalia — só na T14 após Bloco C ser executado." → intencional (placeholder vai ser substituído na T14 step 7 que tem o texto definitivo) ✓
- T14 Step 8: "preencher após Bloco C" e "preencher se medir" no snapshot. Aceitável — são placeholders pra dados que só existem após execução. ✓
- T14 Step 9: "<complete o resto após T14>" e "<preencher após T14>" — análogo. Aceitável. ✓
- T15 Step 2: "<fechado | anomalia>" no commit message — análogo. ✓

**Type consistency:**
- `DEVELOPER_ID_APP_SHA1` referenciado em T2 (project.yml), T8 (sign.sh), T10 (dmg.sh) — mesmo nome ✓
- `SPARKLE_ED_PRIVATE_KEY_PATH` em T3 (gerado), T11 (appcast.sh consome) — mesmo nome ✓
- `~/.tagarela-release.env` consistente em todas as tarefas ✓
- `build/release/` consistente ✓
- `Tagarela-<version>.dmg` consistente entre T10 (gerado), T11 (assinado), T12 (gh release) ✓
- `appcast.xml` na root do repo: T5 (cria), T11 (atualiza), T12 (orquestra) — mesma localização ✓

Sem gaps detectados.
