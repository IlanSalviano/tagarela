---
data: 2026-04-26
status: pronto pra execução
fase: 1 de 3
goal: app macOS faz ditado puro end-to-end (sem LLM)
---

# tagarela v1 — Fase 1: Esqueleto end-to-end "ditado puro"

> **Para agentes de execução:** SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendado) ou `superpowers:executing-plans`. Tarefas usam checkbox (`- [ ]`).
>
> **Antes de qualquer tarefa:** ler `/CLAUDE.md`, [`tagarela_docs/specs/2026-04-26-tagarela-v1-design.md`](./2026-04-26-tagarela-v1-design.md), [`tagarela_docs/05-design/README.md`](../05-design/README.md), [`tagarela_docs/04-decisoes/ADR-0001-sistema-visual.md`](../04-decisoes/ADR-0001-sistema-visual.md). **Antes de marcar uma tarefa como concluída:** atualizar a doc afetada.

**Goal:** Construir o esqueleto Swift/SwiftUI do tagarela com pipeline funcional ditado → transcrição → injeção, sem LLM. Ao fim, apertar `right ⌥`, falar e o texto cru do Whisper aparece colado no app em foco.

**Architecture:** App SwiftUI macOS 14+ com `MenuBarExtra` na status bar, `NSPanel` flutuante pra indicador (variação A — pílula), `PipelineCoordinator` actor orquestrando módulos atrás de protocolos. Refinamento por LLM e demais backends ficam pra Fase 2. Distribuição/notarização ficam pra Fase 3.

**Tech stack:** Swift 5.10+, SwiftUI, AppKit pontual (`NSPanel`, `CGEventTap`, `AVAudioEngine`), WhisperKit via SPM, XCTest. Xcode 15.4+. Sem CocoaPods, sem Carthage.

**Não está nesta fase:**
- LLM (Ollama / OpenAI). Apenas `IdentityRefiner` (passa texto cru direto).
- Persistência (`HistoryStore`, `PreferencesStore` ricas, SwiftData) — usa só `UserDefaults` pra duas chaves mínimas.
- Tela de Preferências (qualquer aba). Configuração só via `UserDefaults` programático.
- Variações B/C/D do indicador.
- Distribuição (assinatura, notarização, DMG).

---

## File structure desta fase

Repositório raiz: `/Users/tars/Dev/tagarela/`. O projeto Xcode entra em `/Users/tars/Dev/tagarela/app/` (junto da pasta `tagarela_docs/` que já existe).

```
app/
├── Tagarela.xcodeproj/
├── Tagarela/                          # app target
│   ├── App/
│   │   ├── TagarelaApp.swift          # @main entry point
│   │   ├── AppContainer.swift         # DI composition root
│   │   └── AppState.swift             # ObservableObject com 5 estados
│   ├── Design/
│   │   ├── DesignSystem.swift         # Color/Font extensions, semantic constants
│   │   ├── Wordmark.swift             # SwiftUI view do wordmark
│   │   └── Glyph.swift                # SwiftUI view do glyph
│   ├── Permissions/
│   │   ├── PermissionStatus.swift
│   │   ├── PermissionService.swift    # protocol
│   │   └── PermissionServiceLive.swift
│   ├── Hotkey/
│   │   ├── Hotkey.swift               # struct codable
│   │   ├── HotkeyService.swift        # protocol
│   │   └── HotkeyServiceLive.swift    # CGEventTap impl
│   ├── Audio/
│   │   ├── AudioCapturing.swift       # protocol
│   │   └── AudioCaptureLive.swift     # AVAudioEngine impl
│   ├── Transcription/
│   │   ├── Transcribing.swift         # protocol
│   │   ├── WhisperKitTranscriber.swift
│   │   └── InitialPromptBuilder.swift
│   ├── Refiner/
│   │   ├── TextRefiner.swift          # protocol
│   │   └── IdentityRefiner.swift
│   ├── Injection/
│   │   ├── Injecting.swift            # protocol
│   │   └── InjectorLive.swift
│   ├── Pipeline/
│   │   ├── PipelineCoordinator.swift  # actor
│   │   └── PipelineEvent.swift
│   ├── UI/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarController.swift
│   │   │   └── StateRow.swift
│   │   ├── Indicator/
│   │   │   ├── FloatingIndicatorPanel.swift
│   │   │   ├── IndicatorPill.swift   # variação A
│   │   │   └── WaveBars.swift
│   │   └── Onboarding/
│   │       ├── OnboardingCoordinator.swift
│   │       ├── OnboardingWindow.swift
│   │       ├── OnboardWelcome.swift
│   │       ├── OnboardPerms.swift
│   │       └── OnboardModel.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   │   ├── AppIcon.appiconset/
│   │   │   └── Colors/                # paper, ink, carmine, amber, moss (light + dark)
│   │   ├── Fonts/
│   │   │   ├── JetBrainsMono-Regular.ttf
│   │   │   ├── JetBrainsMono-Medium.ttf
│   │   │   ├── JetBrainsMono-SemiBold.ttf
│   │   │   ├── InstrumentSerif-Italic.ttf
│   │   │   ├── InterTight-Regular.ttf
│   │   │   ├── InterTight-Medium.ttf
│   │   │   └── InterTight-SemiBold.ttf
│   │   ├── Info.plist
│   │   └── Tagarela.entitlements
│   └── Localization/
│       └── pt-BR.lproj/Localizable.strings
└── TagarelaTests/
    ├── HotkeyTests.swift
    ├── PermissionServiceTests.swift
    ├── InitialPromptBuilderTests.swift
    ├── IdentityRefinerTests.swift
    ├── InjectorTests.swift
    └── PipelineCoordinatorTests.swift
```

Documentação atualizada por esta fase em `tagarela_docs/`:
- `02-arquitetura/01-modulos-fase1.md` (criar) — descrição dos módulos implementados
- `03-funcionalidades/checklists/fase1-manual.md` (criar) — checklist manual de aceite
- `02-arquitetura/02-stack-tecnica.md` (criar) — versões, dependências SPM, fontes empacotadas
- `04-decisoes/` — novos ADRs conforme aparecerem decisões técnicas

---

## Convenções desta fase

- **Idioma:** strings de UI em `Localizable.strings` (pt-BR). Identificadores Swift em inglês.
- **Concorrência:** `actor` pra qualquer estado mutável compartilhado. UI no `@MainActor`. Sem `DispatchQueue` exceto onde uma API Apple exige.
- **Erros:** cada módulo expõe `enum {Modulo}Error: Error`. Sem `Error` genérico.
- **Logging:** `Logger` (os.log) com subsystem `com.tagarela`. Sem `print`.
- **Comentários:** só onde o "porquê" não é óbvio. Não documentar o "o quê".
- **TDD:** lógica pura → teste primeiro. UI/SwiftUI → preview + checklist manual; sem ui-tests automatizados.
- **Commits:** um commit por tarefa, mensagem em pt-BR no estilo `tipo(escopo): descrição` (`feat`, `chore`, `test`, `docs`, `fix`, `refactor`).

---

## Pre-flight (antes de começar a Tarefa 1)

- [ ] **Confirmar Xcode 15.4+ instalado.** `xcodebuild -version` retorna `Xcode 15.4` ou superior.
- [ ] **Confirmar Apple Silicon Mac.** WhisperKit precisa de Metal/Neural Engine.
- [ ] **Confirmar macOS 14+ no host.** `sw_vers -productVersion`.
- [ ] **Baixar fontes** (TTFs):
  - JetBrains Mono: https://github.com/JetBrains/JetBrainsMono/releases (Regular, Medium, SemiBold)
  - Instrument Serif Italic: https://fonts.google.com/specimen/Instrument+Serif (Italic)
  - Inter Tight: https://fonts.google.com/specimen/Inter+Tight (Regular, Medium, SemiBold)
  - Salvar em `~/Downloads/tagarela-fonts/` temporariamente.

---

## Task 1: Criar projeto Xcode

**Files:**
- Create: `app/Tagarela.xcodeproj/` (via Xcode)
- Create: `app/Tagarela/App/TagarelaApp.swift` (gerado pelo template, depois reescrito)

- [ ] **Step 1.1: Criar projeto via Xcode.**

Abrir Xcode → File → New → Project → macOS → App. Configurar:
- **Product Name:** `Tagarela`
- **Team:** seu Apple ID (Developer ID em fase 3)
- **Organization Identifier:** `com.tagarela`
- **Bundle Identifier (auto):** `com.tagarela.Tagarela`
- **Interface:** SwiftUI
- **Language:** Swift
- **Storage:** None (sem Core Data nem SwiftData ainda)
- **Include Tests:** ✓
- Salvar em `/Users/tars/Dev/tagarela/app/`.

- [ ] **Step 1.2: Configurar Build Settings essenciais.**

Selecionar projeto Tagarela na sidebar → Tagarela target → Build Settings:
- **Deployment Target macOS:** `14.0`
- **Swift Language Version:** Swift 5
- **Strict Concurrency Checking:** Complete
- **Enable Hardened Runtime:** Yes (pra notarização futura)

- [ ] **Step 1.3: Criar estrutura de pastas no Finder espelhando a do plano.**

```bash
cd /Users/tars/Dev/tagarela/app/Tagarela
mkdir -p App Design Permissions Hotkey Audio Transcription Refiner Injection Pipeline UI/MenuBar UI/Indicator UI/Onboarding Resources/Fonts Localization/pt-BR.lproj
```

- [ ] **Step 1.4: Mover `TagarelaApp.swift` pra `App/`.**

No Xcode, arrastar `TagarelaApp.swift` (que ficou na raiz) pra grupo `App/`. Marcar "Create folder reference" se já não estiver na pasta certa no disco.

- [ ] **Step 1.5: Limpar `ContentView.swift`.**

Apagar `ContentView.swift` (não vamos usar). Esvaziar `TagarelaApp.swift` por enquanto:

```swift
import SwiftUI

@main
struct TagarelaApp: App {
    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 1.6: Verificar build.**

`⌘B` no Xcode. Build deve passar com warning de "no interface".

- [ ] **Step 1.7: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/
git commit -m "chore(app): criar projeto Xcode Tagarela com estrutura de pastas"
```

---

## Task 2: Info.plist + Entitlements

**Files:**
- Modify: `app/Tagarela/Info.plist`
- Create: `app/Tagarela/Tagarela.entitlements`

- [ ] **Step 2.1: Criar `Tagarela.entitlements`.**

No Xcode: target Tagarela → Signing & Capabilities → `+` → não marcar nada agora (sem sandbox conforme spec). Isso cria o arquivo `Tagarela.entitlements` em `app/Tagarela/`.

Editar pra ficar **vazio de capabilities** (sem App Sandbox):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

- [ ] **Step 2.2: Editar `Info.plist`.**

No Xcode → target Tagarela → Info. Adicionar (ou via right-click no Info.plist → Open As → Source Code):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>tagarela usa o microfone pra transcrever sua fala em texto. áudio nunca é salvo, só processado em memória.</string>

<key>LSUIElement</key>
<true/>

<key>NSHumanReadableCopyright</key>
<string>tagarela</string>
```

`LSUIElement = true` esconde o app do Dock e do app switcher — só fica na status bar (comportamento de menu bar app).

- [ ] **Step 2.3: Build pra confirmar.** `⌘B`.

- [ ] **Step 2.4: Commit.**

```bash
git add app/Tagarela/Info.plist app/Tagarela/Tagarela.entitlements
git commit -m "chore(app): Info.plist com mic usage + LSUIElement; entitlements vazios"
```

---

## Task 3: Adicionar WhisperKit via SPM

**Files:**
- Modify: `app/Tagarela.xcodeproj/project.pbxproj` (gerado pelo Xcode)

- [ ] **Step 3.1: Adicionar package.**

Xcode → File → Add Package Dependencies. URL: `https://github.com/argmaxinc/WhisperKit`. Versão: **Up to Next Major** a partir da última estável (ver releases — em 2026 usar release atual). Adicionar `WhisperKit` ao target Tagarela.

- [ ] **Step 3.2: Verificar import.**

Em `TagarelaApp.swift`, adicionar `import WhisperKit` no topo. Build (`⌘B`). Deve compilar sem erro.

- [ ] **Step 3.3: Reverter `import WhisperKit`** (vai entrar de verdade na Task 18; aqui só validamos que o package resolveu).

- [ ] **Step 3.4: Documentar dependência.**

Criar `tagarela_docs/02-arquitetura/02-stack-tecnica.md`:

```markdown
# Stack técnica — Fase 1

## Versões
- macOS deploy target: 14.0
- Swift: 5.10
- Xcode: 15.4+

## Dependências SPM
| Pacote | Versão | Uso |
|---|---|---|
| WhisperKit | latest stable | ASR local com CoreML/Neural Engine |

## Fontes empacotadas
- JetBrains Mono (Regular, Medium, SemiBold) — JetBrains, OFL
- Instrument Serif (Italic) — Instrument, OFL
- Inter Tight (Regular, Medium, SemiBold) — Rasmus Andersson, OFL
```

- [ ] **Step 3.5: Commit.**

```bash
git add app/ tagarela_docs/02-arquitetura/02-stack-tecnica.md
git commit -m "feat(app): adicionar WhisperKit via SPM + doc de stack"
```

---

## Task 4: Empacotar fontes no bundle

**Files:**
- Create: `app/Tagarela/Resources/Fonts/*.ttf`
- Modify: `app/Tagarela/Info.plist`

- [ ] **Step 4.1: Copiar TTFs pro projeto.**

```bash
cp ~/Downloads/tagarela-fonts/JetBrainsMono-Regular.ttf /Users/tars/Dev/tagarela/app/Tagarela/Resources/Fonts/
cp ~/Downloads/tagarela-fonts/JetBrainsMono-Medium.ttf /Users/tars/Dev/tagarela/app/Tagarela/Resources/Fonts/
cp ~/Downloads/tagarela-fonts/JetBrainsMono-SemiBold.ttf /Users/tars/Dev/tagarela/app/Tagarela/Resources/Fonts/
cp ~/Downloads/tagarela-fonts/InstrumentSerif-Italic.ttf /Users/tars/Dev/tagarela/app/Tagarela/Resources/Fonts/
cp ~/Downloads/tagarela-fonts/InterTight-Regular.ttf /Users/tars/Dev/tagarela/app/Tagarela/Resources/Fonts/
cp ~/Downloads/tagarela-fonts/InterTight-Medium.ttf /Users/tars/Dev/tagarela/app/Tagarela/Resources/Fonts/
cp ~/Downloads/tagarela-fonts/InterTight-SemiBold.ttf /Users/tars/Dev/tagarela/app/Tagarela/Resources/Fonts/
```

No Xcode: arrastar a pasta `Resources/Fonts/` pra sidebar do projeto. Marcar **"Copy items if needed"** desmarcado (já estão no lugar) e adicionar ao target Tagarela.

- [ ] **Step 4.2: Registrar fontes no Info.plist.**

Adicionar:

```xml
<key>ATSApplicationFontsPath</key>
<string>Fonts</string>
```

Esse valor + as fontes na pasta `Fonts/` do bundle faz o macOS registrar automaticamente sem precisar listar arquivo por arquivo.

- [ ] **Step 4.3: Verificar nomes PostScript das fontes.**

Em terminal:
```bash
for f in /Users/tars/Dev/tagarela/app/Tagarela/Resources/Fonts/*.ttf; do
  echo "$f:"
  /System/Library/Frameworks/CoreText.framework/Versions/A/Support/otfinfo -p "$f" 2>/dev/null || mdls -name kMDItemFontFamilyName "$f"
done
```

Anotar os nomes PostScript exatos (ex: `JetBrainsMono-Regular`, `InstrumentSerif-Italic`, `InterTight-Regular`) — vão ser usados em `DesignSystem.swift` na Task 6.

- [ ] **Step 4.4: Commit.**

```bash
git add app/Tagarela/Resources/Fonts/ app/Tagarela/Info.plist
git commit -m "chore(app): empacotar 7 fontes (JetBrains Mono, Instrument Serif, Inter Tight)"
```

---

## Task 5: Color assets do tema

**Files:**
- Create: `app/Tagarela/Resources/Assets.xcassets/Colors/*.colorset/`

- [ ] **Step 5.1: Criar Color Sets no Xcode.**

Asset catalog `Assets.xcassets` → click direito → New Color Set. Repetir pra cada token da seção 4 (cor) do [`05-design/README.md`](../05-design/README.md):

| Nome do Color Set | Light hex | Dark hex |
|---|---|---|
| `Paper` | `F4EDE0` | `15110D` |
| `Paper2` | `EBE2D1` | `1F1A14` |
| `Paper3` | `DDD1BA` | `2C241C` |
| `Ink` | `1A1612` | `F0E9DA` |
| `Ink2` | `3A3128` | `C8BCA6` |
| `Ink3` | `6B5D4D` | `8E8170` |
| `Ink4` | `9E8D77` | `5A4F42` |
| `Carmine` | `C8311C` | `E85A3F` |
| `CarmineDeep` | `8F1D0D` | `C8311C` |
| `Amber` | `C97A14` | `E8A040` |
| `AmberSoft` | `E8B86B` | `D49860` |
| `Moss` | `5A6B3A` | `8BA455` |

Pra cada Color Set: Appearances → "Any, Dark" → preencher Universal (Any) com light hex e Dark com dark hex. Color Space: Display P3.

Mover todos pra subpasta `Colors/` (right-click → New Folder → arrastar).

- [ ] **Step 5.2: Build pra verificar.**

`⌘B`. Não deve haver warning.

- [ ] **Step 5.3: Commit.**

```bash
git add app/Tagarela/Resources/Assets.xcassets/Colors/
git commit -m "chore(design): adicionar 12 Color Sets (paper, ink, carmine, amber, moss) com dark mode"
```

---

## Task 6: DesignSystem.swift

**Files:**
- Create: `app/Tagarela/Design/DesignSystem.swift`

- [ ] **Step 6.1: Escrever `DesignSystem.swift`.**

```swift
import SwiftUI

enum DS {
    enum Color {
        static let paper = SwiftUI.Color("Paper")
        static let paper2 = SwiftUI.Color("Paper2")
        static let paper3 = SwiftUI.Color("Paper3")
        static let ink = SwiftUI.Color("Ink")
        static let ink2 = SwiftUI.Color("Ink2")
        static let ink3 = SwiftUI.Color("Ink3")
        static let ink4 = SwiftUI.Color("Ink4")
        static let carmine = SwiftUI.Color("Carmine")
        static let carmineDeep = SwiftUI.Color("CarmineDeep")
        static let amber = SwiftUI.Color("Amber")
        static let amberSoft = SwiftUI.Color("AmberSoft")
        static let moss = SwiftUI.Color("Moss")

        static let hairline = SwiftUI.Color.black.opacity(0.10)
        static let hairlineStrong = SwiftUI.Color.black.opacity(0.18)
    }

    enum Font {
        static func mono(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            let psName: String
            switch weight {
            case .medium: psName = "JetBrainsMono-Medium"
            case .semibold, .bold: psName = "JetBrainsMono-SemiBold"
            default: psName = "JetBrainsMono-Regular"
            }
            return .custom(psName, size: size)
        }

        static func ui(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            let psName: String
            switch weight {
            case .medium: psName = "InterTight-Medium"
            case .semibold, .bold: psName = "InterTight-SemiBold"
            default: psName = "InterTight-Regular"
            }
            return .custom(psName, size: size)
        }

        static func display(_ size: CGFloat) -> SwiftUI.Font {
            .custom("InstrumentSerif-Italic", size: size)
        }
    }

    enum Radius {
        static let r1: CGFloat = 3
        static let r2: CGFloat = 6
        static let r3: CGFloat = 10
        static let pill: CGFloat = 999
    }

    enum Shadow {
        static let pop = (color: SwiftUI.Color.black.opacity(0.28), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8))
        static let lg = (color: SwiftUI.Color.black.opacity(0.18), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))
        static let md = (color: SwiftUI.Color.black.opacity(0.10), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
    }
}

extension View {
    func dsShadowPop() -> some View {
        shadow(color: DS.Shadow.pop.color, radius: DS.Shadow.pop.radius,
               x: DS.Shadow.pop.x, y: DS.Shadow.pop.y)
    }

    func dsEyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(DS.Font.mono(10))
            .tracking(1.4)
            .foregroundStyle(DS.Color.ink3)
    }
}
```

- [ ] **Step 6.2: Build.** `⌘B`. Sem erros.

- [ ] **Step 6.3: Smoke-test as fontes** com uma `Preview` rápida em `DesignSystem.swift`:

```swift
#Preview("Fonts smoke") {
    VStack(alignment: .leading, spacing: 8) {
        Text("tagarela mono regular").font(DS.Font.mono(14))
        Text("tagarela mono medium").font(DS.Font.mono(14, weight: .medium))
        Text("tagarela ui body").font(DS.Font.ui(14))
        Text("tagarela display").font(DS.Font.display(28))
    }.padding().background(DS.Color.paper)
}
```

Abrir Canvas (`⌥⌘↵`). Se aparecer Helvetica em vez das fontes empacotadas: nome PostScript errado — ajustar (ver Task 4 step 4.3).

- [ ] **Step 6.4: Commit.**

```bash
git add app/Tagarela/Design/DesignSystem.swift
git commit -m "feat(design): DesignSystem com Color/Font/Radius/Shadow + helpers de view"
```

---

## Task 7: Wordmark view

**Files:**
- Create: `app/Tagarela/Design/Wordmark.swift`

- [ ] **Step 7.1: Escrever `Wordmark.swift` com base em [`05-design/bundle/project/wordmark.jsx`](../05-design/bundle/wordmark.jsx).**

```swift
import SwiftUI

struct Wordmark: View {
    var size: CGFloat = 32
    var color: Color = DS.Color.ink
    var accent: Color = DS.Color.carmine
    var showGlyph: Bool = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("tag")
                .font(DS.Font.mono(size, weight: .medium))
                .tracking(-size * 0.02)
                .foregroundStyle(color)
            Text("a")
                .font(DS.Font.display(size * 1.18))
                .foregroundStyle(accent)
                .padding(.trailing, -size * 0.04)
            Text("rel")
                .font(DS.Font.mono(size, weight: .medium))
                .tracking(-size * 0.02)
                .foregroundStyle(color)
            ZStack(alignment: .topTrailing) {
                Text("a")
                    .font(DS.Font.mono(size, weight: .medium))
                    .tracking(-size * 0.02)
                    .foregroundStyle(color)
                if showGlyph {
                    Circle()
                        .fill(accent)
                        .frame(width: size * 0.16, height: size * 0.16)
                        .offset(x: size * 0.24, y: -size * 0.18)
                }
            }
        }
        .lineLimit(1)
    }
}

#Preview {
    VStack(spacing: 24) {
        Wordmark(size: 88)
        Wordmark(size: 48)
        Wordmark(size: 32)
        Wordmark(size: 20)
        Wordmark(size: 14, showGlyph: false)
    }
    .padding(40)
    .background(DS.Color.paper)
}
```

- [ ] **Step 7.2: Verificar Preview** — comparar visualmente com `tagarela design v1.html` aberto via `open /Users/tars/Dev/tagarela/tagarela_docs/05-design/bundle/project/tagarela\ design\ v1.html` (na seção "wordmark"). Ajustar offsets se necessário.

- [ ] **Step 7.3: Commit.**

```bash
git add app/Tagarela/Design/Wordmark.swift
git commit -m "feat(design): Wordmark view com mono + serif italic + dot carmim"
```

---

## Task 8: Glyph view (status bar)

**Files:**
- Create: `app/Tagarela/Design/Glyph.swift`

- [ ] **Step 8.1: Escrever `Glyph.swift` baseado em `wordmark.jsx`.**

```swift
import SwiftUI

struct Glyph: View {
    var size: CGFloat = 18
    var color: Color = DS.Color.ink
    var recording: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let path = Path { p in
                p.move(to: CGPoint(x: s * 4/24, y: s * 5/24))
                p.addLine(to: CGPoint(x: s * 20/24, y: s * 5/24))
                p.addLine(to: CGPoint(x: s * 20/24, y: s * 16/24))
                p.addLine(to: CGPoint(x: s * 11/24, y: s * 16/24))
                p.addLine(to: CGPoint(x: s * 6/24, y: s * 20/24))
                p.addLine(to: CGPoint(x: s * 6/24, y: s * 16/24))
                p.addLine(to: CGPoint(x: s * 4/24, y: s * 16/24))
                p.closeSubpath()
            }
            if recording {
                ctx.fill(path, with: .color(DS.Color.carmine))
            }
            ctx.stroke(path, with: .color(color), lineWidth: 1.6)

            let dotColor: GraphicsContext.Shading = recording ? .color(.white) : .color(color)
            for x in [9.0, 12.0, 15.0] {
                let dot = Path(ellipseIn: CGRect(x: s * (x - 1) / 24, y: s * 9.5 / 24,
                                                  width: s * 2/24, height: s * 2/24))
                ctx.fill(dot, with: dotColor)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        Glyph(size: 18)
        Glyph(size: 14)
        Glyph(size: 18, recording: true)
    }
    .padding()
    .background(DS.Color.paper)
}
```

- [ ] **Step 8.2: Preview e ajustes** — visualmente confere com o design.

- [ ] **Step 8.3: Commit.**

```bash
git add app/Tagarela/Design/Glyph.swift
git commit -m "feat(design): Glyph view (bolha de fala + 3 dots) com estado recording"
```

---

## Task 9: AppState (5 estados)

**Files:**
- Create: `app/Tagarela/App/AppState.swift`

- [ ] **Step 9.1: Escrever `AppState.swift`.**

```swift
import Foundation
import Combine

enum PipelineState: Equatable {
    case idle
    case recording(elapsedSeconds: Double, audioLevel: Double)
    case processing
    case refining
    case error(message: String)

    var dotColorName: String {
        switch self {
        case .idle: return "Moss"
        case .recording: return "Carmine"
        case .processing, .refining: return "Amber"
        case .error: return "CarmineDeep"
        }
    }

    var label: String {
        switch self {
        case .idle: return "pronto"
        case .recording: return "gravando"
        case .processing: return "transcrevendo"
        case .refining: return "refinando"
        case .error(let msg): return msg
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var pipeline: PipelineState = .idle
    @Published var permissionsAllGranted: Bool = false
    @Published var whisperModelReady: Bool = false
}
```

- [ ] **Step 9.2: Build.** `⌘B`.

- [ ] **Step 9.3: Commit.**

```bash
git add app/Tagarela/App/AppState.swift
git commit -m "feat(app): AppState observable + PipelineState enum (5 estados)"
```

---

## Task 10: AppContainer (composition root)

**Files:**
- Create: `app/Tagarela/App/AppContainer.swift`

- [ ] **Step 10.1: Escrever stub do `AppContainer`.**

```swift
import Foundation

@MainActor
final class AppContainer {
    let appState = AppState()
    // Serviços vão sendo injetados nas tasks 11+. Por enquanto vazio.

    init() {}
}
```

Vai crescer ao longo da fase. A intenção é ter um único ponto de wiring.

- [ ] **Step 10.2: Commit.**

```bash
git add app/Tagarela/App/AppContainer.swift
git commit -m "feat(app): AppContainer (DI composition root) — stub inicial"
```

---

## Task 11: TagarelaApp + MenuBarExtra básico

**Files:**
- Modify: `app/Tagarela/App/TagarelaApp.swift`

- [ ] **Step 11.1: Reescrever `TagarelaApp.swift`.**

```swift
import SwiftUI

@main
struct TagarelaApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Wordmark(size: 18)
                    Spacer()
                    Text("v1.0.0-fase1")
                        .font(DS.Font.mono(9))
                        .tracking(0.5)
                        .foregroundStyle(DS.Color.ink3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .overlay(Divider().background(DS.Color.hairline), alignment: .bottom)

                StatePlaceholder(state: container.appState.pipeline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                Divider().background(DS.Color.hairline)
                Button("sair") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 320)
            .background(DS.Color.paper)
            .environmentObject(container.appState)
        } label: {
            Glyph(size: 16, color: .primary,
                  recording: container.appState.pipeline == .idle ? false : true)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct StatePlaceholder: View {
    let state: PipelineState
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Color(state.dotColorName)).frame(width: 8, height: 8)
            Text(state.label).font(DS.Font.mono(13))
            Spacer()
        }
    }
}
```

- [ ] **Step 11.2: Build + run.** `⌘R`. Esperado: app aparece como ícone na status bar (Glyph). Click abre dropdown com wordmark e "pronto" (estado idle). Sem ícone no Dock (LSUIElement).

- [ ] **Step 11.3: Commit.**

```bash
git add app/Tagarela/App/TagarelaApp.swift
git commit -m "feat(app): TagarelaApp com MenuBarExtra mínimo (Glyph + Wordmark + estado)"
```

---

## Task 12: Hotkey type

**Files:**
- Create: `app/Tagarela/Hotkey/Hotkey.swift`
- Create: `app/TagarelaTests/HotkeyTests.swift`

- [ ] **Step 12.1: Escrever teste primeiro.**

`HotkeyTests.swift`:

```swift
import XCTest
@testable import Tagarela

final class HotkeyTests: XCTestCase {
    func test_default_isRightOption() {
        XCTAssertEqual(Hotkey.default, .rightOption)
    }

    func test_codable_roundTrip() throws {
        let h = Hotkey.rightOption
        let data = try JSONEncoder().encode(h)
        let decoded = try JSONDecoder().decode(Hotkey.self, from: data)
        XCTAssertEqual(decoded, h)
    }
}
```

- [ ] **Step 12.2: Rodar teste, verificar que falha** (`Hotkey` não existe). `⌘U`.

- [ ] **Step 12.3: Implementar `Hotkey.swift`.**

```swift
import Foundation

enum Hotkey: String, Codable, Equatable, Hashable {
    case rightOption

    static let `default`: Hotkey = .rightOption

    /// Virtual keycode usado por CGEventTap. Right Option = 0x3D.
    var virtualKeyCode: UInt16 {
        switch self {
        case .rightOption: return 0x3D
        }
    }

    /// Display string pra UI.
    var displayLabel: String {
        switch self {
        case .rightOption: return "right ⌥"
        }
    }
}
```

- [ ] **Step 12.4: Rodar teste, verificar passa.** `⌘U`. Ambos passam.

- [ ] **Step 12.5: Commit.**

```bash
git add app/Tagarela/Hotkey/Hotkey.swift app/TagarelaTests/HotkeyTests.swift
git commit -m "feat(hotkey): Hotkey enum (rightOption) + Codable + tests"
```

---

## Task 13: HotkeyService protocol

**Files:**
- Create: `app/Tagarela/Hotkey/HotkeyService.swift`

- [ ] **Step 13.1: Escrever `HotkeyService.swift`.**

```swift
import Foundation

enum HotkeyEvent: Equatable {
    case toggle
    case cancel
}

protocol HotkeyService: AnyObject {
    /// Stream de eventos (toggle / cancel) emitidos pela hotkey configurada
    /// e pela tecla Esc (se cancelarComEsc estiver ativo).
    var events: AsyncStream<HotkeyEvent> { get }

    /// Inicia captura. Falha se Acessibilidade ou Input Monitoring não autorizados.
    func start() throws

    func stop()
}

enum HotkeyServiceError: Error, Equatable {
    case accessibilityDenied
    case inputMonitoringDenied
    case eventTapCreationFailed
}
```

- [ ] **Step 13.2: Build.** `⌘B`.

- [ ] **Step 13.3: Commit.**

```bash
git add app/Tagarela/Hotkey/HotkeyService.swift
git commit -m "feat(hotkey): HotkeyService protocol + HotkeyEvent + erros"
```

---

## Task 14: HotkeyServiceLive impl

**Files:**
- Create: `app/Tagarela/Hotkey/HotkeyServiceLive.swift`

- [ ] **Step 14.1: Escrever impl.**

```swift
import AppKit
import OSLog

final class HotkeyServiceLive: HotkeyService {
    private let logger = Logger(subsystem: "com.tagarela", category: "Hotkey")
    private var hotkey: Hotkey
    private var cancelarComEsc: Bool

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var continuation: AsyncStream<HotkeyEvent>.Continuation?
    let events: AsyncStream<HotkeyEvent>

    init(hotkey: Hotkey = .default, cancelarComEsc: Bool = true) {
        self.hotkey = hotkey
        self.cancelarComEsc = cancelarComEsc
        var continuationRef: AsyncStream<HotkeyEvent>.Continuation!
        self.events = AsyncStream { continuation in
            continuationRef = continuation
        }
        self.continuation = continuationRef
    }

    func start() throws {
        guard AXIsProcessTrusted() else {
            throw HotkeyServiceError.accessibilityDenied
        }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let observer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: HotkeyServiceLive.callback,
            userInfo: observer
        ) else {
            throw HotkeyServiceError.eventTapCreationFailed
        }
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.runLoopSource = source
        logger.info("HotkeyService started for \(self.hotkey.displayLabel)")
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let me = Unmanaged<HotkeyServiceLive>.fromOpaque(refcon).takeUnretainedValue()

        if type == .flagsChanged {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == me.hotkey.virtualKeyCode {
                let flags = event.flags
                // Detecção de "down" (flag ligada) vs "up" (flag desligada).
                // Pra .toggle, emitimos no down apenas.
                if flags.contains(.maskAlternate) {
                    me.continuation?.yield(.toggle)
                }
            }
        } else if type == .keyDown && me.cancelarComEsc {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == 0x35 { // Esc
                me.continuation?.yield(.cancel)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    deinit {
        stop()
        continuation?.finish()
    }
}
```

> **Nota de implementação:** detectar "right" vs "left" Option exige inspecionar `event.flags` mais a fundo (NSEvent.ModifierFlags expõe `.deviceIndependentFlagsMask` mas pra distinguir L/R precisa do `kCGEventFlagMaskAlphaShift` + flags de hardware). Esta impl só dispara em qualquer Option — refinar pra right-only quando integrar manualmente. Anotar como TODO inline e abrir issue/ADR se virar dor.

- [ ] **Step 14.2: Build.** `⌘B`. Se quebrar pq a API mudou no SDK atual, ajustar.

- [ ] **Step 14.3: Smoke-test manual** (sem teste automatizado pra event tap):

Adicionar temporariamente no `TagarelaApp.swift`:
```swift
.task {
    let svc = HotkeyServiceLive()
    do {
        try svc.start()
        for await ev in svc.events {
            print("hotkey event: \(ev)")
        }
    } catch {
        print("hotkey error: \(error)")
    }
}
```

Rodar (`⌘R`), conceder Acessibilidade quando macOS pedir, apertar `⌥` direito. Verificar logs no console mostrando `hotkey event: toggle`. Apertar Esc → `hotkey event: cancel`. Reverter o smoke-test code.

- [ ] **Step 14.4: Commit.**

```bash
git add app/Tagarela/Hotkey/HotkeyServiceLive.swift
git commit -m "feat(hotkey): HotkeyServiceLive com CGEventTap (toggle no Option, cancel no Esc)"
```

---

## Task 15: PermissionService

**Files:**
- Create: `app/Tagarela/Permissions/PermissionStatus.swift`
- Create: `app/Tagarela/Permissions/PermissionService.swift`
- Create: `app/Tagarela/Permissions/PermissionServiceLive.swift`
- Create: `app/TagarelaTests/PermissionServiceTests.swift`

- [ ] **Step 15.1: Escrever `PermissionStatus.swift`.**

```swift
import Foundation

enum PermissionStatus: String, Codable, Equatable {
    case unknown
    case needed
    case granted
    case denied
}

struct PermissionsSnapshot: Equatable {
    var microphone: PermissionStatus
    var accessibility: PermissionStatus
    var inputMonitoring: PermissionStatus

    var allGranted: Bool {
        microphone == .granted && accessibility == .granted && inputMonitoring == .granted
    }
}
```

- [ ] **Step 15.2: Escrever `PermissionService.swift` (protocol).**

```swift
import Foundation

protocol PermissionService: AnyObject {
    func snapshot() -> PermissionsSnapshot
    func requestMicrophone() async -> Bool
    func openAccessibilitySettings()
    func openInputMonitoringSettings()

    /// Stream que reemite snapshot quando algo muda (poll a cada 1s).
    var snapshots: AsyncStream<PermissionsSnapshot> { get }
}
```

- [ ] **Step 15.3: Escrever `PermissionServiceLive.swift`.**

```swift
import AppKit
import AVFoundation
import OSLog

final class PermissionServiceLive: PermissionService {
    private let logger = Logger(subsystem: "com.tagarela", category: "Permissions")
    private var continuation: AsyncStream<PermissionsSnapshot>.Continuation?
    let snapshots: AsyncStream<PermissionsSnapshot>
    private var task: Task<Void, Never>?

    init() {
        var contRef: AsyncStream<PermissionsSnapshot>.Continuation!
        self.snapshots = AsyncStream { continuation in
            contRef = continuation
        }
        self.continuation = contRef
        startPolling()
    }

    func snapshot() -> PermissionsSnapshot {
        PermissionsSnapshot(
            microphone: micStatus(),
            accessibility: AXIsProcessTrusted() ? .granted : .needed,
            inputMonitoring: inputMonitoringStatus()
        )
    }

    func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    private func micStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .needed
        @unknown default: return .unknown
        }
    }

    private func inputMonitoringStatus() -> PermissionStatus {
        // IOHIDCheckAccess está em IOKit/hid; valor 0 = granted, 1 = denied, 2 = unknown.
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        switch access {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .needed
        }
    }

    private func startPolling() {
        task = Task { [weak self] in
            guard let self else { return }
            var last: PermissionsSnapshot?
            while !Task.isCancelled {
                let now = self.snapshot()
                if now != last {
                    self.continuation?.yield(now)
                    last = now
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    deinit { task?.cancel(); continuation?.finish() }
}
```

> Adicionar `import IOKit.hid` se necessário.

- [ ] **Step 15.4: Escrever `PermissionServiceTests.swift`.**

```swift
import XCTest
@testable import Tagarela

final class PermissionServiceTests: XCTestCase {
    func test_snapshot_allGranted_isTrue_whenAllGranted() {
        let s = PermissionsSnapshot(microphone: .granted, accessibility: .granted, inputMonitoring: .granted)
        XCTAssertTrue(s.allGranted)
    }

    func test_snapshot_allGranted_isFalse_whenAnyMissing() {
        let s = PermissionsSnapshot(microphone: .granted, accessibility: .needed, inputMonitoring: .granted)
        XCTAssertFalse(s.allGranted)
    }
}
```

(Não testamos `PermissionServiceLive` automatizado — depende de estado real do sistema.)

- [ ] **Step 15.5: Build + test.** `⌘U`.

- [ ] **Step 15.6: Commit.**

```bash
git add app/Tagarela/Permissions/ app/TagarelaTests/PermissionServiceTests.swift
git commit -m "feat(permissions): PermissionService (mic / accessibility / input monitoring) + tests"
```

---

## Task 16: AudioCapturing protocol + AVAudioEngine impl

**Files:**
- Create: `app/Tagarela/Audio/AudioCapturing.swift`
- Create: `app/Tagarela/Audio/AudioCaptureLive.swift`

- [ ] **Step 16.1: Escrever protocol.**

```swift
import Foundation

protocol AudioCapturing: AnyObject {
    /// Inicia captura. Erros: mic não autorizado, device indisponível.
    func start() throws

    /// Para captura, retorna o buffer PCM 16kHz mono Float32.
    func stop() async throws -> AudioBuffer

    /// Stream do nível de áudio (RMS) entre 0...1, ~30 Hz, pra alimentar waveform.
    var levels: AsyncStream<Double> { get }

    var isRecording: Bool { get }
}

struct AudioBuffer: Equatable {
    let samples: [Float]    // mono 16kHz
    let sampleRate: Double  // sempre 16000
    var durationSeconds: Double { Double(samples.count) / sampleRate }
}

enum AudioCaptureError: Error, Equatable {
    case microphoneDenied
    case noInputDevice
    case engineFailedToStart
    case notRecording
}
```

- [ ] **Step 16.2: Escrever impl.**

```swift
import AVFoundation
import OSLog

final class AudioCaptureLive: AudioCapturing {
    private let logger = Logger(subsystem: "com.tagarela", category: "Audio")
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var collected: [Float] = []
    private(set) var isRecording: Bool = false

    private var levelContinuation: AsyncStream<Double>.Continuation?
    let levels: AsyncStream<Double>

    init() {
        var ref: AsyncStream<Double>.Continuation!
        self.levels = AsyncStream { c in ref = c }
        self.levelContinuation = ref
    }

    func start() throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw AudioCaptureError.microphoneDenied
        }
        collected.removeAll()
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: 16_000,
                                             channels: 1,
                                             interleaved: false) else {
            throw AudioCaptureError.engineFailedToStart
        }
        guard let conv = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw AudioCaptureError.engineFailedToStart
        }
        self.converter = conv

        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buf, _ in
            guard let self else { return }
            self.process(buffer: buf, converter: conv, outFormat: outFormat)
        }

        engine.prepare()
        do { try engine.start() } catch {
            throw AudioCaptureError.engineFailedToStart
        }
        isRecording = true
        logger.info("AudioCapture started")
    }

    func stop() async throws -> AudioBuffer {
        guard isRecording else { throw AudioCaptureError.notRecording }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        let samples = collected
        collected.removeAll()
        return AudioBuffer(samples: samples, sampleRate: 16_000)
    }

    private func process(buffer: AVAudioPCMBuffer,
                         converter: AVAudioConverter,
                         outFormat: AVAudioFormat) {
        let outFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * 16_000.0 / buffer.format.sampleRate) + 256
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outFrameCapacity) else { return }
        var error: NSError?
        var consumed = false
        let status = converter.convert(to: outBuf, error: &error) { _, statusPtr in
            if consumed { statusPtr.pointee = .endOfStream; return nil }
            consumed = true
            statusPtr.pointee = .haveData
            return buffer
        }
        if status == .error || error != nil {
            logger.error("converter failed: \(String(describing: error))")
            return
        }
        guard let ch = outBuf.floatChannelData?[0] else { return }
        let n = Int(outBuf.frameLength)
        let arr = Array(UnsafeBufferPointer(start: ch, count: n))
        collected.append(contentsOf: arr)

        // RMS pro nível
        let rms = sqrt(arr.reduce(0) { $0 + $1 * $1 } / Float(max(1, n)))
        let level = min(1.0, max(0.0, Double(rms) * 4)) // gain visual
        levelContinuation?.yield(level)
    }

    deinit { levelContinuation?.finish() }
}
```

- [ ] **Step 16.3: Build.** `⌘B`.

- [ ] **Step 16.4: Commit.**

```bash
git add app/Tagarela/Audio/
git commit -m "feat(audio): AudioCapturing protocol + AVAudioEngine impl (16kHz mono float32 + RMS levels)"
```

---

## Task 17: Transcribing protocol + InitialPromptBuilder

**Files:**
- Create: `app/Tagarela/Transcription/Transcribing.swift`
- Create: `app/Tagarela/Transcription/InitialPromptBuilder.swift`
- Create: `app/TagarelaTests/InitialPromptBuilderTests.swift`

- [ ] **Step 17.1: Escrever protocol.**

```swift
import Foundation

protocol Transcribing: AnyObject {
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws
    func transcribe(buffer: AudioBuffer,
                    language: String,
                    initialPrompt: String?) async throws -> String
    var loadedModelName: String? { get }
}

enum TranscribeError: Error, Equatable {
    case modelNotLoaded
    case modelDownloadFailed(String)
    case transcriptionFailed(String)
    case bufferTooShort
}
```

- [ ] **Step 17.2: Escrever testes do `InitialPromptBuilder`.**

`InitialPromptBuilderTests.swift`:

```swift
import XCTest
@testable import Tagarela

final class InitialPromptBuilderTests: XCTestCase {
    func test_emptyVocab_returnsBaseContext() {
        let s = InitialPromptBuilder.build(vocab: [])
        XCTAssertTrue(s.contains("português brasileiro"))
        XCTAssertFalse(s.contains("contendo termos como"))
    }

    func test_withVocab_listsTerms() {
        let s = InitialPromptBuilder.build(vocab: ["Postgres", "deploy", "Kubernetes"])
        XCTAssertTrue(s.contains("Postgres"))
        XCTAssertTrue(s.contains("deploy"))
        XCTAssertTrue(s.contains("Kubernetes"))
    }

    func test_truncatesVocabAtTokenLimit() {
        let huge = (0..<500).map { "termo\($0)" }
        let s = InitialPromptBuilder.build(vocab: huge)
        // Whisper aceita ~224 tokens; cortamos antes disso.
        XCTAssertLessThan(s.count, 1500)
    }
}
```

- [ ] **Step 17.3: Implementar `InitialPromptBuilder`.**

```swift
import Foundation

enum InitialPromptBuilder {
    /// Limite conservador: Whisper aceita ~224 tokens; ~4 chars por token em PT;
    /// reservamos folga pro contexto base.
    private static let maxChars = 700

    static func build(vocab: [String]) -> String {
        let base = "Transcrição em português brasileiro de desenvolvedor de software."
        guard !vocab.isEmpty else { return base }
        var list = vocab.joined(separator: ", ")
        let suffix = " Termos esperados: "
        let budget = maxChars - base.count - suffix.count
        if list.count > budget {
            list = String(list.prefix(budget))
            if let lastComma = list.lastIndex(of: ",") {
                list = String(list[..<lastComma])
            }
        }
        return base + suffix + list + "."
    }
}
```

- [ ] **Step 17.4: Build + test.** `⌘U`.

- [ ] **Step 17.5: Commit.**

```bash
git add app/Tagarela/Transcription/Transcribing.swift app/Tagarela/Transcription/InitialPromptBuilder.swift app/TagarelaTests/InitialPromptBuilderTests.swift
git commit -m "feat(transcription): Transcribing protocol + InitialPromptBuilder com truncamento"
```

---

## Task 18: WhisperKitTranscriber

**Files:**
- Create: `app/Tagarela/Transcription/WhisperKitTranscriber.swift`

- [ ] **Step 18.1: Escrever impl.**

```swift
import Foundation
import WhisperKit
import OSLog

final class WhisperKitTranscriber: Transcribing {
    private let logger = Logger(subsystem: "com.tagarela", category: "Transcribe")
    private var pipe: WhisperKit?
    private(set) var loadedModelName: String?

    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {
        do {
            let pipe = try await WhisperKit(model: name, download: true) { progress in
                onProgress(progress.fractionCompleted)
            }
            self.pipe = pipe
            self.loadedModelName = name
            logger.info("loaded whisper model: \(name)")
        } catch {
            throw TranscribeError.modelDownloadFailed(String(describing: error))
        }
    }

    func transcribe(buffer: AudioBuffer,
                    language: String,
                    initialPrompt: String?) async throws -> String {
        guard let pipe else { throw TranscribeError.modelNotLoaded }
        guard buffer.durationSeconds >= 0.5 else { throw TranscribeError.bufferTooShort }

        let opts = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language,
            usePrefillPrompt: initialPrompt != nil,
            promptTokens: nil,
            withoutTimestamps: true
        )

        do {
            let results = try await pipe.transcribe(audioArray: buffer.samples,
                                                     decodeOptions: opts)
            let text = results.map(\.text).joined(separator: " ")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw TranscribeError.transcriptionFailed(String(describing: error))
        }
    }
}
```

> **Aviso:** API do WhisperKit pode ter mudado entre versões. Validar o nome e parâmetros corretos do método `transcribe(...)` no momento da implementação. Se a API exigir `initialPrompt` via outro mecanismo (ex: `promptTokens`), ajustar.

- [ ] **Step 18.2: Build.** `⌘B`. Se quebrar, ajustar à API atual de WhisperKit.

- [ ] **Step 18.3: Commit.**

```bash
git add app/Tagarela/Transcription/WhisperKitTranscriber.swift
git commit -m "feat(transcription): WhisperKitTranscriber com loadModel + transcribe (pt-BR)"
```

---

## Task 19: TextRefiner protocol + IdentityRefiner

**Files:**
- Create: `app/Tagarela/Refiner/TextRefiner.swift`
- Create: `app/Tagarela/Refiner/IdentityRefiner.swift`
- Create: `app/TagarelaTests/IdentityRefinerTests.swift`

- [ ] **Step 19.1: Escrever protocol + Identity.**

`TextRefiner.swift`:

```swift
import Foundation

protocol TextRefiner: AnyObject {
    /// Recebe texto cru e retorna texto refinado. `style` é o nome do estilo selecionado;
    /// implementações simples (Identity) ignoram.
    func refine(_ raw: String, style: String) async throws -> String

    var kind: RefinerKind { get }
}

enum RefinerKind: String, Codable, Equatable {
    case identity
    case ollama
    case openai
}
```

`IdentityRefiner.swift`:

```swift
import Foundation

final class IdentityRefiner: TextRefiner {
    let kind: RefinerKind = .identity
    func refine(_ raw: String, style: String) async throws -> String { raw }
}
```

- [ ] **Step 19.2: Tests.**

`IdentityRefinerTests.swift`:

```swift
import XCTest
@testable import Tagarela

final class IdentityRefinerTests: XCTestCase {
    func test_returnsInputUnchanged() async throws {
        let r = IdentityRefiner()
        let out = try await r.refine("foo bar", style: "qualquer")
        XCTAssertEqual(out, "foo bar")
    }

    func test_kindIsIdentity() {
        XCTAssertEqual(IdentityRefiner().kind, .identity)
    }
}
```

- [ ] **Step 19.3: Test + commit.**

```bash
git add app/Tagarela/Refiner/ app/TagarelaTests/IdentityRefinerTests.swift
git commit -m "feat(refiner): TextRefiner protocol + IdentityRefiner + tests"
```

---

## Task 20: Injector

**Files:**
- Create: `app/Tagarela/Injection/Injecting.swift`
- Create: `app/Tagarela/Injection/InjectorLive.swift`
- Create: `app/TagarelaTests/InjectorTests.swift`

- [ ] **Step 20.1: Protocol + tipo de retorno.**

`Injecting.swift`:

```swift
import Foundation

protocol Injecting: AnyObject {
    /// Injeta texto no app em foco via clipboard + ⌘V.
    /// Retorna o bundle ID do app que estava em foco no momento da injeção.
    @discardableResult
    func inject(text: String) async throws -> String?
}

enum InjectionError: Error, Equatable {
    case accessibilityDenied
    case pasteboardWriteFailed
}
```

- [ ] **Step 20.2: Impl.**

`InjectorLive.swift`:

```swift
import AppKit
import OSLog

final class InjectorLive: Injecting {
    private let logger = Logger(subsystem: "com.tagarela", category: "Inject")
    private let restoreDelayNanoseconds: UInt64 = 250_000_000

    func inject(text: String) async throws -> String? {
        guard AXIsProcessTrusted() else { throw InjectionError.accessibilityDenied }
        let pasteboard = NSPasteboard.general
        let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // 1. Snapshot do clipboard atual (todos os tipos)
        let savedItems = pasteboard.pasteboardItems?.map { item -> [NSPasteboard.PasteboardType: Data] in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        } ?? []

        // 2. Coloca texto novo
        pasteboard.declareTypes([.string], owner: nil)
        guard pasteboard.setString(text, forType: .string) else {
            throw InjectionError.pasteboardWriteFailed
        }

        // 3. Simula ⌘V
        let src = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)

        // 4. Restaura clipboard depois do delay
        try? await Task.sleep(nanoseconds: restoreDelayNanoseconds)
        pasteboard.clearContents()
        for dict in savedItems {
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            pasteboard.writeObjects([item])
        }

        return frontBundleID
    }
}
```

- [ ] **Step 20.3: Tests (do que dá pra testar — error cases).**

`InjectorTests.swift`:

```swift
import XCTest
@testable import Tagarela

final class InjectorTests: XCTestCase {
    func test_injectionError_equatable() {
        XCTAssertEqual(InjectionError.accessibilityDenied, InjectionError.accessibilityDenied)
        XCTAssertNotEqual(InjectionError.accessibilityDenied, InjectionError.pasteboardWriteFailed)
    }
}
```

(Injeção real exige interação manual — checklist na Task 30.)

- [ ] **Step 20.4: Commit.**

```bash
git add app/Tagarela/Injection/ app/TagarelaTests/InjectorTests.swift
git commit -m "feat(injection): Injecting protocol + InjectorLive (clipboard save→paste→restore)"
```

---

## Task 21: PipelineCoordinator

**Files:**
- Create: `app/Tagarela/Pipeline/PipelineEvent.swift`
- Create: `app/Tagarela/Pipeline/PipelineCoordinator.swift`
- Create: `app/TagarelaTests/PipelineCoordinatorTests.swift`

- [ ] **Step 21.1: Eventos.**

`PipelineEvent.swift`:

```swift
import Foundation

enum PipelineEvent: Equatable {
    case toggle
    case cancel
    case stateChanged(PipelineState)
    case finished(rawText: String, refinedText: String, frontmostApp: String?)
    case errorOccurred(String)
}
```

- [ ] **Step 21.2: Coordenador.**

`PipelineCoordinator.swift`:

```swift
import Foundation
import OSLog

actor PipelineCoordinator {
    private let logger = Logger(subsystem: "com.tagarela", category: "Pipeline")
    private let audio: AudioCapturing
    private let transcriber: Transcribing
    private let refiner: TextRefiner
    private let injector: Injecting
    private let language: String
    private let initialPromptProvider: () -> String?

    private(set) var state: PipelineState = .idle
    private var continuation: AsyncStream<PipelineEvent>.Continuation?
    let events: AsyncStream<PipelineEvent>

    init(audio: AudioCapturing,
         transcriber: Transcribing,
         refiner: TextRefiner,
         injector: Injecting,
         language: String = "pt",
         initialPromptProvider: @escaping () -> String? = { nil }) {
        self.audio = audio
        self.transcriber = transcriber
        self.refiner = refiner
        self.injector = injector
        self.language = language
        self.initialPromptProvider = initialPromptProvider

        var ref: AsyncStream<PipelineEvent>.Continuation!
        self.events = AsyncStream { c in ref = c }
        self.continuation = ref
    }

    func handle(_ event: PipelineEvent) async {
        switch event {
        case .toggle: await handleToggle()
        case .cancel: await handleCancel()
        default: break
        }
    }

    private func setState(_ s: PipelineState) {
        state = s
        continuation?.yield(.stateChanged(s))
    }

    private func handleToggle() async {
        switch state {
        case .idle:
            do {
                try audio.start()
                setState(.recording(elapsedSeconds: 0, audioLevel: 0))
            } catch {
                setState(.error(message: "mic indisponível"))
                continuation?.yield(.errorOccurred("mic: \(error)"))
            }
        case .recording:
            await runTranscribeAndInject()
        case .processing, .refining, .error:
            // Ignorado — apenas .cancel é aceito durante esses estados
            break
        }
    }

    private func handleCancel() async {
        switch state {
        case .recording:
            _ = try? await audio.stop()
            setState(.idle)
        case .processing, .refining:
            // Sem cancel real do whisper na v1 — só marcamos idle e descartamos resultado
            setState(.idle)
        case .idle, .error:
            break
        }
    }

    private func runTranscribeAndInject() async {
        do {
            let buffer = try await audio.stop()
            guard buffer.durationSeconds >= 0.5 else {
                setState(.idle); return
            }
            setState(.processing)
            let raw = try await transcriber.transcribe(
                buffer: buffer, language: language,
                initialPrompt: initialPromptProvider()
            )
            setState(.refining)
            let refined = try await refiner.refine(raw, style: "cru — sem reescrita")
            let frontApp = try await injector.inject(text: refined)
            continuation?.yield(.finished(rawText: raw, refinedText: refined, frontmostApp: frontApp))
            setState(.idle)
        } catch {
            setState(.error(message: "erro no pipeline"))
            continuation?.yield(.errorOccurred(String(describing: error)))
            // Auto-recover pra idle após 2s
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            setState(.idle)
        }
    }

    deinit { continuation?.finish() }
}
```

- [ ] **Step 21.3: Tests com fakes.**

`PipelineCoordinatorTests.swift`:

```swift
import XCTest
@testable import Tagarela

final class PipelineCoordinatorTests: XCTestCase {
    func test_toggleFromIdle_movesToRecording() async {
        let p = makeCoordinator()
        await p.handle(.toggle)
        let s = await p.state
        if case .recording = s {} else { XCTFail("expected recording, got \(s)") }
    }

    func test_toggleFromRecording_runsPipelineAndReturnsToIdle() async {
        let p = makeCoordinator()
        await p.handle(.toggle)
        await p.handle(.toggle)
        // dar tempo da pipeline rodar (fakes são síncronos suficientes)
        try? await Task.sleep(nanoseconds: 100_000_000)
        let s = await p.state
        XCTAssertEqual(s, .idle)
    }

    func test_cancelDuringRecording_returnsToIdle() async {
        let p = makeCoordinator()
        await p.handle(.toggle)
        await p.handle(.cancel)
        let s = await p.state
        XCTAssertEqual(s, .idle)
    }

    private func makeCoordinator() -> PipelineCoordinator {
        PipelineCoordinator(
            audio: FakeAudio(),
            transcriber: FakeTranscriber(),
            refiner: IdentityRefiner(),
            injector: FakeInjector()
        )
    }
}

private final class FakeAudio: AudioCapturing {
    var isRecording = false
    let levels = AsyncStream<Double> { _ in }
    func start() throws { isRecording = true }
    func stop() async throws -> AudioBuffer {
        isRecording = false
        return AudioBuffer(samples: Array(repeating: 0.1, count: 16_000), sampleRate: 16_000) // 1s
    }
}

private final class FakeTranscriber: Transcribing {
    var loadedModelName: String? = "fake"
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String, initialPrompt: String?) async throws -> String {
        "olá mundo"
    }
}

private final class FakeInjector: Injecting {
    var injected: String?
    func inject(text: String) async throws -> String? {
        injected = text
        return "com.example.app"
    }
}
```

- [ ] **Step 21.4: Test.** `⌘U`. Os 3 testes devem passar.

- [ ] **Step 21.5: Commit.**

```bash
git add app/Tagarela/Pipeline/ app/TagarelaTests/PipelineCoordinatorTests.swift
git commit -m "feat(pipeline): PipelineCoordinator (actor, 5 estados) + tests com fakes"
```

---

## Task 22: FloatingIndicatorPanel (NSPanel)

**Files:**
- Create: `app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift`

- [ ] **Step 22.1: Implementar `NSPanel` non-activating.**

```swift
import AppKit
import SwiftUI

@MainActor
final class FloatingIndicatorPanel {
    private var panel: NSPanel?

    func show(rootView: some View) {
        if panel == nil {
            let p = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .floating
            p.isMovableByWindowBackground = true
            p.backgroundColor = .clear
            p.hasShadow = false
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            self.panel = p
        }
        let host = NSHostingController(rootView: rootView)
        host.view.layer?.backgroundColor = .clear
        panel?.contentViewController = host
        positionNearCursor()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func positionNearCursor() {
        guard let p = panel else { return }
        let cursor = NSEvent.mouseLocation
        let frame = NSRect(x: cursor.x - 110, y: cursor.y - 80,
                            width: p.frame.width, height: p.frame.height)
        p.setFrame(frame, display: true)
    }
}
```

- [ ] **Step 22.2: Build.** `⌘B`.

- [ ] **Step 22.3: Commit.**

```bash
git add app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift
git commit -m "feat(ui): FloatingIndicatorPanel (NSPanel non-activating, posiciona perto do cursor)"
```

---

## Task 23: WaveBars + IndicatorPill (variação A)

**Files:**
- Create: `app/Tagarela/UI/Indicator/WaveBars.swift`
- Create: `app/Tagarela/UI/Indicator/IndicatorPill.swift`

- [ ] **Step 23.1: WaveBars.**

```swift
import SwiftUI

struct WaveBars: View {
    var level: Double
    var color: Color
    var count: Int = 16
    var height: CGFloat = 22
    var width: CGFloat = 84
    var gap: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * 12
            HStack(alignment: .center, spacing: gap) {
                let barW = (width - gap * CGFloat(count - 1)) / CGFloat(count)
                ForEach(0..<count, id: \.self) { i in
                    let seed1 = (sin(Double(i) * 1.7 + t * 0.4) + 1) / 2
                    let seed2 = (sin(Double(i) * 0.9 + t * 0.7 + 2) + 1) / 2
                    let env = sin(Double(i) / Double(count) * .pi)
                    let h = max(2, (0.18 + level * 0.7 * (seed1 * 0.6 + seed2 * 0.4))
                        * Double(height) * (0.5 + env * 0.6))
                    Rectangle()
                        .fill(color)
                        .opacity(0.85 + 0.15 * env)
                        .frame(width: barW, height: CGFloat(h))
                }
            }
            .frame(width: width, height: height)
        }
    }
}
```

- [ ] **Step 23.2: IndicatorPill.**

```swift
import SwiftUI

struct IndicatorPill: View {
    let state: PipelineState
    var onCancel: () -> Void = {}

    private var (level: Double, seconds: Double) {
        if case .recording(let secs, let lvl) = state { return (lvl, secs) }
        return (0, 0)
    }

    private var dotColor: Color {
        switch state {
        case .recording: return DS.Color.carmine
        case .processing, .refining: return DS.Color.amber
        case .error: return DS.Color.carmineDeep
        case .idle: return DS.Color.ink
        }
    }

    private var formatted: String {
        let m = Int(seconds) / 60, s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .modifier(PulseIfRecording(state: state))
            WaveBars(level: level,
                     color: state == .idle ? DS.Color.ink3 : DS.Color.ink,
                     count: 16, height: 22, width: 84)
            Text(formatted)
                .font(DS.Font.mono(11))
                .monospacedDigit()
                .foregroundStyle(DS.Color.ink2)
                .frame(minWidth: 38)
            Rectangle()
                .fill(DS.Color.hairline)
                .frame(width: 1, height: 16)
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.Color.ink3)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DS.Color.paper, in: Capsule())
        .overlay(Capsule().stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
        .dsShadowPop()
    }
}

private struct PulseIfRecording: ViewModifier {
    let state: PipelineState
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing && isRecording ? 0.55 : 1)
            .scaleEffect(pulsing && isRecording ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.6).repeatForever(), value: pulsing)
            .onAppear { pulsing = true }
    }

    private var isRecording: Bool {
        if case .recording = state { return true }; return false
    }
}

#Preview {
    VStack(spacing: 20) {
        IndicatorPill(state: .recording(elapsedSeconds: 12, audioLevel: 0.6))
        IndicatorPill(state: .processing)
        IndicatorPill(state: .refining)
        IndicatorPill(state: .error(message: "erro"))
    }
    .padding(40)
    .background(LinearGradient(colors: [DS.Color.paper2, DS.Color.paper], startPoint: .topLeading, endPoint: .bottomTrailing))
}
```

> Há um syntax error de propósito acima na propriedade computed — a sintaxe `private var (level: Double, seconds: Double)` precisa virar:
>
> ```swift
> private var levelAndSeconds: (level: Double, seconds: Double) {
>     if case .recording(let secs, let lvl) = state { return (lvl, secs) }
>     return (0, 0)
> }
> ```
>
> E no uso: `let (level, seconds) = levelAndSeconds`. Corrigir antes de buildar.

- [ ] **Step 23.3: Build, ajustar, preview.**

- [ ] **Step 23.4: Commit.**

```bash
git add app/Tagarela/UI/Indicator/
git commit -m "feat(ui): WaveBars (TimelineView) + IndicatorPill (variação A) com estados"
```

---

## Task 24: MenuBarController + StateRow

**Files:**
- Create: `app/Tagarela/UI/MenuBar/StateRow.swift`
- Create: `app/Tagarela/UI/MenuBar/MenuBarController.swift`
- Modify: `app/Tagarela/App/TagarelaApp.swift`

- [ ] **Step 24.1: StateRow.**

```swift
import SwiftUI

struct StateRow: View {
    let state: PipelineState

    private var sub: String {
        switch state {
        case .idle: return "right ⌥ pra começar"
        case .recording(let s, _): return String(format: "%02d:%02d · 16 kHz mono", Int(s)/60, Int(s)%60)
        case .processing: return "whisper large-v3"
        case .refining: return "identity (sem llm)"
        case .error: return "fallback: texto cru"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Color(state.dotColorName)).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.label).font(DS.Font.mono(13)).foregroundStyle(DS.Color.ink)
                Text(sub).font(DS.Font.mono(10)).foregroundStyle(DS.Color.ink3)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
```

- [ ] **Step 24.2: MenuBarController** (refatora o conteúdo do `MenuBarExtra` em arquivo próprio).

```swift
import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Wordmark(size: 18)
                Spacer()
                Text("v1.0.0-fase1")
                    .font(DS.Font.mono(9))
                    .tracking(0.5)
                    .foregroundStyle(DS.Color.ink3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(Divider().background(DS.Color.hairline), alignment: .bottom)

            StateRow(state: appState.pipeline)

            Divider().background(DS.Color.hairline)
            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Text("sair")
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.ink3)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 320)
        .background(DS.Color.paper)
    }
}
```

- [ ] **Step 24.3: Atualizar `TagarelaApp.swift` pra usar `MenuBarContent`.**

```swift
import SwiftUI

@main
struct TagarelaApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent().environmentObject(container.appState)
        } label: {
            Glyph(size: 16, color: .primary,
                  recording: container.appState.pipeline != .idle)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 24.4: Build + run.** Confirmar visual bate com `tagarela design v1.html` seção "menu da status bar".

- [ ] **Step 24.5: Commit.**

```bash
git add app/Tagarela/UI/MenuBar/ app/Tagarela/App/TagarelaApp.swift
git commit -m "feat(ui): MenuBarContent + StateRow refatorados em módulos próprios"
```

---

## Task 25-28: Onboarding (Welcome + Perms + Model + Coordinator)

> Tarefas agrupadas porque são as 3 telas + um wrapper.

**Files:**
- Create: `app/Tagarela/UI/Onboarding/OnboardingWindow.swift`
- Create: `app/Tagarela/UI/Onboarding/OnboardWelcome.swift`
- Create: `app/Tagarela/UI/Onboarding/OnboardPerms.swift`
- Create: `app/Tagarela/UI/Onboarding/OnboardModel.swift`
- Create: `app/Tagarela/UI/Onboarding/OnboardingCoordinator.swift`

- [ ] **Step 25.1: OnboardingCoordinator.**

```swift
import SwiftUI

@MainActor
final class OnboardingCoordinator: ObservableObject {
    enum Step { case welcome, perms, model }
    @Published var step: Step = .welcome

    let permissionService: PermissionService
    let transcriber: Transcribing
    @Published var permsSnapshot: PermissionsSnapshot
    @Published var modelDownloadProgress: Double = 0
    @Published var modelLoaded: Bool = false

    init(permissionService: PermissionService, transcriber: Transcribing) {
        self.permissionService = permissionService
        self.transcriber = transcriber
        self.permsSnapshot = permissionService.snapshot()
        Task { for await s in permissionService.snapshots { permsSnapshot = s } }
    }

    func advance() {
        switch step {
        case .welcome: step = .perms
        case .perms: step = .model
        case .model: break
        }
    }

    func loadModel(_ name: String) {
        Task { [weak self] in
            guard let self else { return }
            try? await transcriber.loadModel(name) { [weak self] p in
                Task { @MainActor in self?.modelDownloadProgress = p }
            }
            self.modelLoaded = true
        }
    }
}
```

- [ ] **Step 25.2: OnboardWelcome.**

```swift
import SwiftUI

struct OnboardWelcome: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark(size: 48).padding(.bottom, 32)
            Text("ditado por voz para qualquer coisa que você escreva.")
                .font(DS.Font.display(32))
                .foregroundStyle(DS.Color.ink)
                .padding(.bottom, 16)
            Text("aperte ⌥ direito em qualquer app, fale, aperte de novo. o texto refinado aparece onde estiver o cursor. funciona offline. fala português.")
                .font(DS.Font.ui(14))
                .foregroundStyle(DS.Color.ink2)
                .lineSpacing(4)
                .frame(maxWidth: 460, alignment: .leading)
            Spacer()
            HStack {
                Spacer()
                Button(action: onContinue) {
                    Text("continuar →").font(DS.Font.mono(12)).foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                Text("PASSO 1 / 3").font(DS.Font.mono(9)).tracking(1)
                Text("·")
                Text("BOAS-VINDAS").font(DS.Font.mono(9)).tracking(1)
            }
            .foregroundStyle(DS.Color.ink3)
            .padding(.top, 16)
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 48)
        .frame(width: 560, height: 400)
        .background(DS.Color.paper)
    }
}
```

- [ ] **Step 25.3: OnboardPerms.**

```swift
import SwiftUI

struct OnboardPerms: View {
    let snapshot: PermissionsSnapshot
    var onMicTap: () -> Void
    var onAccessibilityTap: () -> Void
    var onInputMonitoringTap: () -> Void
    var onContinue: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PASSO 2 / 3").font(DS.Font.mono(9)).tracking(1.4).foregroundStyle(DS.Color.ink3)
                Text("três permissões.")
                    .font(DS.Font.display(26)).foregroundStyle(DS.Color.ink)
                Text("o macOS exige isso pra app capturar áudio e atalhos globais. nada vai pra fora da máquina.")
                    .font(DS.Font.ui(12)).foregroundStyle(DS.Color.ink2)
            }
            VStack(spacing: 10) {
                permCard(name: "microfone", status: snapshot.microphone,
                         why: "captura sua voz pra transcrever. áudio nunca é salvo, só processado em memória.",
                         onTap: onMicTap)
                permCard(name: "acessibilidade", status: snapshot.accessibility,
                         why: "necessário pra registrar o atalho global e simular ⌘V no app de destino.",
                         onTap: onAccessibilityTap)
                permCard(name: "input monitoring", status: snapshot.inputMonitoring,
                         why: "pra ouvir a tecla ⌥ direito mesmo quando outro app está em foco.",
                         onTap: onInputMonitoringTap)
            }
            Spacer()
            HStack {
                Spacer()
                Button(action: onBack) {
                    Text("← voltar").font(DS.Font.mono(12)).foregroundStyle(DS.Color.ink3)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(DS.Color.paper2, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
                Button(action: onContinue) {
                    Text("continuar →").font(DS.Font.mono(12)).foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
        .frame(width: 560, height: 520)
        .background(DS.Color.paper)
    }

    @ViewBuilder
    private func permCard(name: String, status: PermissionStatus, why: String, onTap: @escaping () -> Void) -> some View {
        let color: Color = status == .granted ? DS.Color.moss : status == .denied ? DS.Color.carmine : DS.Color.ink3
        let label = status == .granted ? "concedida" : status == .denied ? "negada" : "necessária"
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(name).font(DS.Font.mono(12, weight: .medium)).foregroundStyle(DS.Color.ink)
                Spacer()
                Text(label.uppercased()).font(DS.Font.mono(9)).tracking(1).foregroundStyle(color)
            }
            Text(why).font(DS.Font.ui(12)).foregroundStyle(DS.Color.ink2).lineSpacing(2)
            if status != .granted {
                Button(action: onTap) {
                    Text("abrir configurações").font(DS.Font.mono(11)).foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(DS.Color.paper2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
    }
}
```

- [ ] **Step 25.4: OnboardModel.**

```swift
import SwiftUI

struct OnboardModel: View {
    let downloadProgress: Double
    let loaded: Bool
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PASSO 3 / 3").font(DS.Font.mono(9)).tracking(1.4).foregroundStyle(DS.Color.ink3)
                Text("modelos.").font(DS.Font.display(26)).foregroundStyle(DS.Color.ink)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("WHISPER · TRANSCRIÇÃO").font(DS.Font.mono(10)).tracking(1.4).foregroundStyle(DS.Color.ink3)
                modelRow(name: "large-v3", size: "2.9 GB", ram: "≥ 16 GB", recommended: true, selected: true)
                modelRow(name: "medium", size: "1.4 GB", ram: "≥ 8 GB", recommended: false, selected: false)
                modelRow(name: "small", size: "466 MB", ram: "≥ 4 GB", recommended: false, selected: false)
                if !loaded && downloadProgress > 0 {
                    HStack(spacing: 8) {
                        ProgressView(value: downloadProgress).progressViewStyle(.linear).tint(DS.Color.carmine)
                        Text("baixando \(Int(downloadProgress * 100))%")
                            .font(DS.Font.mono(10)).foregroundStyle(DS.Color.ink3)
                    }
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button(action: onStart) {
                    Text("começar →").font(DS.Font.mono(12)).foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(loaded ? DS.Color.ink : DS.Color.ink3, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain).disabled(!loaded)
            }
        }
        .padding(.horizontal, 48).padding(.vertical, 40)
        .frame(width: 560, height: 560)
        .background(DS.Color.paper)
    }

    @ViewBuilder
    private func modelRow(name: String, size: String, ram: String, recommended: Bool, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Circle().stroke(DS.Color.ink, lineWidth: 1.2)
                .background(selected ? Circle().fill(DS.Color.ink).padding(3) : nil)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(DS.Font.mono(12, weight: .medium)).foregroundStyle(DS.Color.ink)
                Text("\(size) · \(ram) RAM").font(DS.Font.mono(10)).foregroundStyle(DS.Color.ink3)
            }
            Spacer()
            if recommended {
                Text("RECOM.").font(DS.Font.mono(9)).tracking(1).foregroundStyle(DS.Color.carmine)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(DS.Color.carmine, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(selected ? DS.Color.paper2 : .clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? DS.Color.ink : DS.Color.hairlineStrong, lineWidth: 0.5))
    }
}
```

- [ ] **Step 25.5: OnboardingWindow** (wrapper que mostra o passo certo).

```swift
import SwiftUI

struct OnboardingWindow: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    var onFinish: () -> Void

    var body: some View {
        Group {
            switch coordinator.step {
            case .welcome:
                OnboardWelcome(onContinue: { coordinator.advance() })
            case .perms:
                OnboardPerms(
                    snapshot: coordinator.permsSnapshot,
                    onMicTap: { Task { _ = await coordinator.permissionService.requestMicrophone() } },
                    onAccessibilityTap: { coordinator.permissionService.openAccessibilitySettings() },
                    onInputMonitoringTap: { coordinator.permissionService.openInputMonitoringSettings() },
                    onContinue: { coordinator.advance() },
                    onBack: { coordinator.step = .welcome }
                )
            case .model:
                OnboardModel(
                    downloadProgress: coordinator.modelDownloadProgress,
                    loaded: coordinator.modelLoaded,
                    onStart: { onFinish() }
                ).onAppear { coordinator.loadModel("large-v3") }
            }
        }
    }
}
```

- [ ] **Step 25.6: Build + commit.**

```bash
git add app/Tagarela/UI/Onboarding/
git commit -m "feat(ui): onboarding (welcome + perms + model picker) com coordinator"
```

---

## Task 29: Wire-up final no AppContainer + TagarelaApp

**Files:**
- Modify: `app/Tagarela/App/AppContainer.swift`
- Modify: `app/Tagarela/App/TagarelaApp.swift`

- [ ] **Step 29.1: AppContainer completo.**

```swift
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let appState = AppState()
    let permissions: PermissionService
    let transcriber: Transcribing
    let audio: AudioCapturing
    let injector: Injecting
    let refiner: TextRefiner
    let hotkeyService: HotkeyService
    let pipeline: PipelineCoordinator
    let onboarding: OnboardingCoordinator
    let indicatorPanel = FloatingIndicatorPanel()

    @Published var showOnboarding: Bool

    init() {
        self.permissions = PermissionServiceLive()
        self.transcriber = WhisperKitTranscriber()
        self.audio = AudioCaptureLive()
        self.injector = InjectorLive()
        self.refiner = IdentityRefiner()
        self.hotkeyService = HotkeyServiceLive()
        self.pipeline = PipelineCoordinator(
            audio: audio, transcriber: transcriber,
            refiner: refiner, injector: injector
        )
        self.onboarding = OnboardingCoordinator(
            permissionService: permissions, transcriber: transcriber
        )
        // Mostra onboarding se nunca terminou
        self.showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingCompleted")
        wireHotkeyToPipeline()
        wirePipelineToAppState()
        wirePermissionsToAppState()
        if !showOnboarding {
            try? hotkeyService.start()
            Task { try? await transcriber.loadModel("large-v3") { _ in } }
        }
    }

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        showOnboarding = false
        try? hotkeyService.start()
    }

    private func wireHotkeyToPipeline() {
        Task { [weak self] in
            guard let self else { return }
            for await event in self.hotkeyService.events {
                let pipelineEvent: PipelineEvent = (event == .toggle) ? .toggle : .cancel
                await self.pipeline.handle(pipelineEvent)
            }
        }
    }

    private func wirePipelineToAppState() {
        Task { [weak self] in
            guard let self else { return }
            for await event in await self.pipeline.events {
                await MainActor.run {
                    switch event {
                    case .stateChanged(let s):
                        self.appState.pipeline = s
                        self.refreshIndicator(for: s)
                    case .errorOccurred(let msg):
                        Logger.tagarela.error("pipeline error: \(msg, privacy: .public)")
                    case .finished:
                        break
                    default: break
                    }
                }
            }
        }
    }

    private func wirePermissionsToAppState() {
        Task { [weak self] in
            guard let self else { return }
            for await snap in self.permissions.snapshots {
                await MainActor.run {
                    self.appState.permissionsAllGranted = snap.allGranted
                }
            }
        }
    }

    private func refreshIndicator(for state: PipelineState) {
        switch state {
        case .idle:
            indicatorPanel.hide()
        default:
            indicatorPanel.show(rootView:
                IndicatorPill(state: state) { [weak self] in
                    Task { await self?.pipeline.handle(.cancel) }
                }
            )
        }
    }
}

extension Logger {
    static let tagarela = Logger(subsystem: "com.tagarela", category: "App")
}
```

- [ ] **Step 29.2: TagarelaApp final.**

```swift
import SwiftUI

@main
struct TagarelaApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent().environmentObject(container.appState)
        } label: {
            Glyph(size: 16, color: .primary,
                  recording: container.appState.pipeline != .idle)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("tagarela — bem-vindo", id: "onboarding") {
            if container.showOnboarding {
                OnboardingWindow(onFinish: { container.finishOnboarding() })
                    .environmentObject(container.onboarding)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 560)
    }
}
```

- [ ] **Step 29.3: Build + run.** `⌘R`. Onboarding aparece. Walk through. Termina. App fica na status bar.

- [ ] **Step 29.4: Commit.**

```bash
git add app/Tagarela/App/
git commit -m "feat(app): wire-up completo (hotkey↔pipeline↔state↔indicator) + onboarding gate"
```

---

## Task 30: Checklist manual de aceite + doc de fechamento

**Files:**
- Create: `tagarela_docs/03-funcionalidades/checklists/fase1-manual.md`
- Create: `tagarela_docs/02-arquitetura/01-modulos-fase1.md`

- [ ] **Step 30.1: Escrever checklist manual.**

`fase1-manual.md`:

```markdown
# Fase 1 — checklist manual de aceite

Executar em Mac com Apple Silicon, 16+ GB RAM, macOS 14+, primeira execução do app (apagar `~/Library/Preferences/com.tagarela.Tagarela.plist` e `~/Library/Containers/com.tagarela.Tagarela` se houver).

## Onboarding
- [ ] App abre com janela "boas-vindas" centralizada (560×400, paper warm)
- [ ] Botão "continuar →" leva pra "três permissões" (560×520)
- [ ] 3 cards mostram status real do sistema (cinza/verde/vermelho)
- [ ] Botão "abrir configurações" em cada card abre o painel certo do macOS
- [ ] Conceder mic via popup nativo → card vira verde
- [ ] Conceder Acessibilidade → card vira verde
- [ ] Conceder Input Monitoring → card vira verde
- [ ] "continuar →" leva pra "modelos" (560×560)
- [ ] Modelo `large-v3` aparece selecionado e marcado como recomendado
- [ ] Barra de progresso anda durante download
- [ ] "começar →" só fica ativo após modelo carregado
- [ ] Onboarding fecha; app some do Dock; ícone aparece na status bar

## Status bar
- [ ] Click no Glyph abre dropdown 320px com Wordmark + estado "pronto"
- [ ] "PRONTO" e sub "right ⌥ pra começar" aparecem
- [ ] Botão "sair" funciona

## Pipeline (com Acessibilidade + Input Monitoring concedidos)
- [ ] Apertar `⌥` direito em qualquer app: indicador pílula aparece perto do cursor
- [ ] Indicador mostra dot pulsante carmim, waveform reage à voz, timer correndo
- [ ] Falar "olá mundo isso é um teste" por ~3 segundos
- [ ] Apertar `⌥` direito de novo: indicador vira "transcrevendo" (amber), depois "refinando", depois some
- [ ] Texto cru do whisper aparece colado no app em foco (TextEdit, Notes, etc.)
- [ ] Clipboard original é restaurado após ~250ms
- [ ] Status bar reflete estados em tempo real
- [ ] Esc durante gravação cancela e indicador some sem injetar
- [ ] Botão X no indicador também cancela
- [ ] Apertar `⌥` direito durante "transcrevendo" não dispara nova captura

## Apps testados pra injeção
- [ ] TextEdit
- [ ] Notes
- [ ] Slack
- [ ] Mail
- [ ] VS Code
- [ ] Terminal
- [ ] Safari (textarea/input/contenteditable)
- [ ] iMessage

## Edge cases
- [ ] Captura < 0.5s: descartada silenciosamente, indicador some
- [ ] Captura > 5min: ainda funciona (sem warning visual nesta fase, ok)
- [ ] Negar Acessibilidade: hotkey não funciona; status bar mostra estado de erro (futuro — ok ignorar nesta fase, basta não crashar)
- [ ] Reabrir app após fechar: vai direto pra status bar (sem onboarding de novo)

## Performance
- [ ] Latência típica ditado→texto colado: < 3s pra 5s de fala em `large-v3`
- [ ] Sem spike de CPU > 30% em idle
- [ ] Sem leak visível de memória após 20 capturas (≤ 500MB residentes)

## Conclusão
Quando todos os checks acima passarem: Fase 1 está aceita. Atualizar `tagarela_docs/02-arquitetura/01-modulos-fase1.md` com qualquer desvio observado. Dar git tag `v1-fase1-aceita`.
```

- [ ] **Step 30.2: Escrever doc dos módulos da Fase 1.**

`01-modulos-fase1.md`:

```markdown
# Módulos implementados na Fase 1

Snapshot do que existe no código ao fim da Fase 1. Atualizar conforme drift acontece.

## Implementados
| Módulo | Arquivo principal | Responsabilidade |
|---|---|---|
| AppState | `App/AppState.swift` | ObservableObject com PipelineState (5 estados) |
| AppContainer | `App/AppContainer.swift` | Composition root + wire-up |
| DesignSystem | `Design/DesignSystem.swift` | Color/Font/Radius/Shadow tokens |
| Wordmark, Glyph | `Design/{Wordmark,Glyph}.swift` | Identity views |
| PermissionService | `Permissions/` | mic / accessibility / input monitoring |
| HotkeyService | `Hotkey/` | CGEventTap p/ ⌥ direito + Esc |
| AudioCapturing | `Audio/` | AVAudioEngine 16kHz mono float32 |
| Transcribing (WhisperKit) | `Transcription/` | load model + transcribe pt-BR |
| InitialPromptBuilder | `Transcription/` | monta initialPrompt com vocab |
| TextRefiner (Identity) | `Refiner/` | passa texto cru direto |
| Injecting | `Injection/` | clipboard save → ⌘V → restore |
| PipelineCoordinator | `Pipeline/` | actor com 5 estados |
| MenuBarContent + StateRow | `UI/MenuBar/` | dropdown da status bar |
| FloatingIndicatorPanel + IndicatorPill (A) + WaveBars | `UI/Indicator/` | indicador flutuante variação A |
| Onboarding (Welcome + Perms + Model) | `UI/Onboarding/` | primeira execução |

## Não implementados (vão pra Fase 2)
- TextRefiner: Ollama, OpenAI
- Keychain (API key OpenAI)
- PreferencesStore + tela de Preferências
- HistoryStore (SwiftData)
- Menu da status bar com "últimos 5"
- Indicador variações B / C / D
- Toasts de erro
- Estados visuais de "permissão faltando" no menu
- Localizable.strings completo (strings hardcoded por enquanto)

## Não implementados (vão pra Fase 3)
- Code signing Developer ID
- Notarization
- DMG build
- Sparkle / auto-update
- Homebrew Cask
- Logging em arquivo
```

- [ ] **Step 30.3: Atualizar `tagarela_docs/README.md` apontando pros novos docs.**

```bash
# Editar tagarela_docs/README.md adicionando entradas em 02-arquitetura e 03-funcionalidades
```

- [ ] **Step 30.4: Commit + tag.**

```bash
git add tagarela_docs/
git commit -m "docs: checklist manual de aceite da Fase 1 + snapshot dos módulos implementados"
git tag v1-fase1-pronto
```

- [ ] **Step 30.5: Executar o checklist `fase1-manual.md` integralmente.**

Quando todos os checks passarem, ajustar onde houver drift, commitar correções, retag pra `v1-fase1-aceita`.

---

## Self-review do plano (concluído pelo autor antes de entregar)

- [x] Cobre tudo da spec referente à Fase 1 (ditado puro end-to-end sem LLM, persistência, ou refinamento real).
- [x] Sem placeholders "TBD" / "implementar depois" — código completo em cada step que toca código.
- [x] Tipos consistentes entre tarefas (`PipelineState`, `Hotkey`, `AudioBuffer`, `PermissionsSnapshot` aparecem com mesma assinatura onde quer que apareçam).
- [x] Tarefas com TDD onde apropriado; UI com preview + checklist manual.
- [x] Caminhos absolutos e exatos pra cada arquivo.
- [x] Comandos exatos pra git, build, test.

**Pontos de atenção pra quem executar:**

1. WhisperKit API (Task 18) pode ter mudado — validar e ajustar.
2. Detecção L/R do Option em CGEventTap (Task 14) é simplificada — refinar se incomodar.
3. Nomes PostScript das fontes (Task 4 step 4.3) — verificar antes de usar em DesignSystem.
4. `IndicatorPill` (Task 23) tem um snippet com syntax error de propósito sinalizado — corrigir antes do build.
