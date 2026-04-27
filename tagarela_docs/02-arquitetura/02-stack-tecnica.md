# Stack técnica — Fase 1

## Versões

| Item | Versão alvo (plano) | Versão usada nesta máquina |
|---|---|---|
| macOS deploy target | 14.0 | 14.0 (mantido) |
| Swift | 5.10+ | 5.10 (modo Swift 5; Strict Concurrency: complete) |
| Xcode | 15.4+ | 26.4.1 |
| macOS host | 14+ | 26.4.1 |

## Geração do projeto

O projeto Xcode é gerado via [`xcodegen`](https://github.com/yonaskolb/XcodeGen) a partir de `app/project.yml`. Para regenerar:

```bash
cd app && xcodegen generate
```

O arquivo `app/Tagarela.xcodeproj/` é commitado (mantém o histórico legível para o reviewer humano), mas a fonte da verdade é `project.yml`.

## Dependências SPM

| Pacote | Versão resolvida | Uso |
|---|---|---|
| WhisperKit | `0.18.0` (`from: 0.9.0`) | ASR local com CoreML/Neural Engine |

Dependências transitivas resolvidas: `swift-transformers`, `swift-jinja`, `swift-collections`, `swift-argument-parser`, `swift-asn1`, `swift-crypto`, `yyjson`.

## Fontes empacotadas

Empacotadas em `app/Tagarela/Resources/Fonts/` e registradas via `ATSApplicationFontsPath = "Fonts"` no `Info.plist`.

- JetBrains Mono (Regular, Medium, SemiBold) — JetBrains, OFL
- Instrument Serif (Italic) — Instrument, OFL
- Inter Tight (Regular, Medium, SemiBold) — Rasmus Andersson, OFL

## Capabilities / entitlements

- **Sandbox:** desativado (Fase 1). Necessário pra `CGEventTap`, hotkey global e injeção via Pasteboard + `⌘V`.
- **Hardened Runtime:** ativado (preparação pra notarização na Fase 3).
- **`LSUIElement = true`:** app vive só na status bar (sem Dock, sem app switcher).
