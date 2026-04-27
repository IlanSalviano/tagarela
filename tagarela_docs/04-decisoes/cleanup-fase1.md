---
data: 2026-04-27
status: aberto
revisitar_em: 2026-05-11
---

# Cleanup pós-Fase 1

Lista de TODOs deixados durante a implementação da Fase 1 que merecem ser revisitados depois que a fase estiver no ar. Não bloqueia a Fase 1; bloqueia a sensação de "limpo" antes de começar a Fase 2.

> Quando voltar aqui (sugerido em **2026-05-11**), rodar `xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test` antes e depois de cada item pra garantir que nada regrediu.

## 1. Detecção L/R do Option no `HotkeyServiceLive`

**Arquivo:** [`app/Tagarela/Hotkey/HotkeyServiceLive.swift`](../../app/Tagarela/Hotkey/HotkeyServiceLive.swift) (TODO inline na seção `.flagsChanged`).

Hoje qualquer Option (esquerdo OU direito) dispara `.toggle`. O plano define a hotkey default como `right ⌥` (`virtualKeyCode = 0x3D`), mas `event.flags.contains(.maskAlternate)` não distingue lados.

Pra distinguir, precisa olhar bits específicos do flag:
- `NSEvent.ModifierFlags.option` (deviceIndependent) tem o bit genérico.
- Os bits de hardware ficam em `event.flags.rawValue` — `kCGEventFlagMaskAlphaShift`-style constants existem só pra alguns; pro Option, dá pra cruzar com o `keycode` do event:
  - keycode `0x3A` = Left Option, `0x3D` = Right Option.
  - Se já filtramos por `keyCode == hotkey.virtualKeyCode`, isso na prática **deveria** restringir a Right só. Verificar se o filtro atual tá fazendo isso ou se o `flagsChanged` dispara pros dois lados independente do keycode.

**Critério de aceite:** apertar `⌥` esquerdo NÃO dispara toggle; só `⌥` direito dispara. Adicionar nota no `tagarela_docs/02-arquitetura/02-stack-tecnica.md` se a abordagem mudou.

## 2. `initialPrompt` → `promptTokens` no `WhisperKitTranscriber`

**Arquivo:** [`app/Tagarela/Transcription/WhisperKitTranscriber.swift`](../../app/Tagarela/Transcription/WhisperKitTranscriber.swift).

`InitialPromptBuilder.build(vocab:)` retorna uma `String`, mas `DecodingOptions.promptTokens: [Int]?` espera tokens já tokenizados. Hoje a string é construída mas **descartada** — só o `usePrefillPrompt: true` é setado (que força idioma + task, sem vocab).

Antes de virar tokens:
1. Validar empiricamente se vocab faz diferença na transcrição PT-BR técnica do dia-a-dia. Coletar 5–10 amostras com termos como "Postgres", "Kubernetes", "Slack", "deploy" — comparar resultado com e sem vocab.
2. Se sim: usar o tokenizer exposto pelo `WhisperKit.tokenizer` pra converter `InitialPromptBuilder.build(...)` em `[Int]` e passar como `promptTokens`.

**Critério de aceite:** ou (a) decisão documentada de que vocab não vale o esforço (commit no doc), ou (b) `promptTokens` setado, com teste validando que termos do vocab aparecem corretamente em pelo menos 1 amostra.

## 3. Drift visual entre código e bundle de design

**Pastas:** [`app/Tagarela/Design/`](../../app/Tagarela/Design/) vs [`tagarela_docs/05-design/`](../05-design/).

Itens implementados sem inspeção visual lado-a-lado:
- `Wordmark.swift` — offsets do dot carmim, `padding(.trailing, -size * 0.04)` no `a` italic, baseline alignment.
- `Glyph.swift` — proporções da bolha de fala, posição dos 3 dots, lineWidth 1.6.
- 12 Color Sets em Display P3 — verificar saturação contra HTML/JSX do bundle de design (especialmente Carmine vs CarmineDeep e os 4 Inks no dark).

**Como verificar:**
1. `open tagarela_docs/05-design/bundle/project/tagarela\ design\ v1.html` lado a lado com Xcode Canvas das previews em `DesignSystem.swift`/`Wordmark.swift`/`Glyph.swift`.
2. Switchar entre light e dark no Xcode preview.
3. Tirar screenshot de cada e comparar pixel-a-pixel se possível.

**Critério de aceite:** doc `02-arquitetura/01-modulos-fase1.md` (a criar na Task 30) lista qualquer divergência aceita; PR de correção pra divergências não aceitas.

---

## Quando isto sai daqui

Quando os 3 itens estiverem resolvidos (cada um com critério de aceite atendido), apagar este arquivo e adicionar uma linha em [`README.md`](../README.md) marcando "Cleanup Fase 1: ✅ resolvido em YYYY-MM-DD".
