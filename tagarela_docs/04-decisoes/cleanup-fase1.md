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

**Status (2026-04-27, sessão de stress test):** filtro por `keyCode == 0x3D` parece já estar restringindo só ao Option direito na prática (logs mostraram só keyCode=61 quando user apertou direito). Validar empiricamente que `⌥` esquerdo não dispara, e se confirmado, fechar este item sem código novo.

**Critério de aceite:** sessão de teste com Left Option apertado várias vezes — nenhum log `[hotkey] flagsChanged keyCode=61 (Right Option)` aparece. Se confirmado, fechar; senão, distinguir bits no flag.

## 2. `initialPrompt` → `promptTokens` no `WhisperKitTranscriber`

**Arquivo:** [`app/Tagarela/Transcription/WhisperKitTranscriber.swift`](../../app/Tagarela/Transcription/WhisperKitTranscriber.swift).

`InitialPromptBuilder.build(vocab:)` retorna uma `String`, mas `DecodingOptions.promptTokens: [Int]?` espera tokens já tokenizados. Hoje a string é construída mas **descartada** — só o `usePrefillPrompt: true` é setado (que força idioma + task, sem vocab).

Antes de virar tokens:
1. Validar empiricamente se vocab faz diferença na transcrição PT-BR técnica do dia-a-dia. Coletar 5–10 amostras com termos como "Postgres", "Kubernetes", "Slack", "deploy" — comparar resultado com e sem vocab.
2. Se sim: usar o tokenizer exposto pelo `WhisperKit.tokenizer` pra converter `InitialPromptBuilder.build(...)` em `[Int]` e passar como `promptTokens`.

**Critério de aceite:** ou (a) decisão documentada de que vocab não vale o esforço (commit no doc), ou (b) `promptTokens` setado, com teste validando que termos do vocab aparecem corretamente em pelo menos 1 amostra.

## 3. Stderr instrumentation deve virar `Logger.tagarela.info`

**Arquivos com `FileHandle.standardError.write` em produção:**
- [`app/Tagarela/Hotkey/HotkeyServiceLive.swift`](../../app/Tagarela/Hotkey/HotkeyServiceLive.swift)
- [`app/Tagarela/Audio/AudioCaptureLive.swift`](../../app/Tagarela/Audio/AudioCaptureLive.swift)
- [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift)
- [`app/Tagarela/App/AppContainer.swift`](../../app/Tagarela/App/AppContainer.swift)

Toda a instrumentação de debug que adicionamos pra investigar TCC + audio engine ficou via `FileHandle.standardError.write(Data(...))`. Foi crítico durante o desenvolvimento (dava pra `cat /tmp/tagarela.stderr` em paralelo), mas:
1. Polui stderr quando rodando via Xcode.
2. Não respeita níveis (info/debug/error) — tudo vira print bruto.
3. Burla o subsystem `com.tagarela` do `os.log`, que era a fonte oficial.

**Critério de aceite:** trocar todos os `FileHandle.standardError.write` por chamadas a `Logger.tagarela.info(...)` ou `.debug(...)` ou `.error(...)` conforme severidade. Validar que `Console.app` filtrado por `subsystem == "com.tagarela"` mostra os mesmos eventos antes ditos no stderr.

## 4. Software gain hardcoded no `AudioCaptureLive`

**Arquivo:** [`app/Tagarela/Audio/AudioCaptureLive.swift`](../../app/Tagarela/Audio/AudioCaptureLive.swift) — método `boostPeakNormalize(_:targetPeak:)`.

Adicionado boost peak-normalize pra compensar o input gain extremamente baixo do C920 (peak ~0.07 em fala normal). Hoje:
- `targetPeak: Float = 0.6` hardcoded.
- Limite de gain: `min(targetPeak / peak, 20)` — 20x máximo.

Isso resolve o problema imediato de "Whisper transcreve só `...` porque áudio parece silêncio", mas:
1. Em ambientes ruidosos, amplifica o ruído junto.
2. Hardcoded — não configurável por device/preferência.
3. Sem AGC (automatic gain control) real — peak normalize é uma aproximação cega.

**Critério de aceite:** ou (a) substituir por AGC simples (RMS-based, com attack/release) ou (b) expor como preferência (Fase 2 quando tiver tela de Preferências) com slider 0-20×, default 8×.

## 5. `AVAudioConverter` streaming não funcionou — workaround documentado

**Arquivo:** [`app/Tagarela/Audio/AudioCaptureLive.swift`](../../app/Tagarela/Audio/AudioCaptureLive.swift)

O design original (e o snippet do plano) usava `AVAudioConverter` em modo streaming dentro de `installTap` callback — converter de 48kHz stereo pra 16kHz mono frame-a-frame conforme buffers chegavam. **No macOS 26 com Apple Development sign + Logitech C920**, esse converter só processava o primeiro buffer; os demais caíam em `endOfStream` silenciosamente. Resultado: 6+ segundos de fala produziam 0.1s de áudio.

Workaround atual: tap acumula um array de samples por canal (`channelBuffers: [[Float]]`), e `stop()` faz downmix manual (mean dos canais) + resampling (interpolação linear) em batch. Funciona mas não é a abordagem canônica.

**Bug histórico do workaround (resolvido em 2026-04-27, pré-Fase 2):** a versão inicial usava um único `[Float]` linear (`collected`) e o `append` empilhava `c0_n + c1_n + c0_n + c1_n + ...` por callback, mas o downmix dividia `raw.count / channels` e tratava a primeira metade como canal 0 inteiro. Resultado: o sinal era somado consigo mesmo deslocado por metade da gravação — frases > 1 buffer saíam do Whisper com palavras certas em ordem embaralhada e repetições ("vai para a produção, eles deploy, não vai" para "esse deploy não vai pra produção"). Detectado via dump WAV+TXT do checklist [`fase2-diagnostico-asr.md`](../03-funcionalidades/checklists/fase2-diagnostico-asr.md). Fix: trocar para `channelBuffers: [[Float]]` e fazer downmix por canal preservando ordem temporal. Validado pós-fix com 5/5 frases-teste fiéis.

**Critério de aceite:** investigar se o problema do `AVAudioConverter` streaming é específico do C920 ou geral. Testar com mic interno em outro Mac. Se for específico do device, manter o workaround com nota inline. Se geral, abrir issue/relatório no WhisperKit ou achar a forma correta de usar `AVAudioConverter` streaming.

## 6. Permissões TCC injetadas manualmente via SQLite

**Contexto:** durante stress test, o popup nativo do macOS pedindo Microphone NUNCA apareceu pra Tagarela (mesmo com signing estável Apple Development, mesmo com `LSUIElement` desligado temporariamente, mesmo após reboot, mesmo com `AVCaptureSession` real). Foi necessário **injetar entries diretamente** no `~/Library/Application Support/com.apple.TCC/TCC.db` (via SQL clonando o `csreq` BLOB de uma entry existente):

```sql
INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq)
SELECT 'kTCCServiceMicrophone', client, client_type, 2, 0, 1, csreq
FROM access WHERE client = 'com.tagarela.Tagarela' LIMIT 1;
```

(Mesmo padrão pra `kTCCServiceCamera`.) Depois `killall tccd` (com admin password via `osascript`) pra forçar reload.

**Risco:** macOS pode revalidar entries TCC e descartá-las se a `csreq` não casar 100% com o binário atual. Como ad-hoc-resign muda o CDHash, mas Apple Development sign mantém TeamIdentifier e cert authority — assumimos que `csreq` clonado dá match.

**Acessibility** o user adicionou via System Settings → Privacy & Security → Accessibility manualmente (`+` → `~/Applications/Tagarela.app`). Esse caminho funcionou pra AX (provavelmente porque AX vive em `/Library/Application Support/com.apple.TCC/TCC.db` system-level e tem outro fluxo).

**Critério de aceite:** quando passarmos por code-sign Developer ID + notarização (Fase 3), os popups TCC nativos voltam a funcionar conforme esperado pela Apple. Documentar este episódio em ADR explicando o contexto, e deletar este item de cleanup.

**Workaround ainda relevante até Fase 3:** novo dev na máquina precisa rodar manualmente o SQL acima e configurar Accessibility via UI. Documentar no README ou em `tagarela_docs/02-arquitetura/00-setup-dev.md` (a criar).

## 7. Drift visual entre código e bundle de design

**Pastas:** [`app/Tagarela/Design/`](../../app/Tagarela/Design/) vs [`tagarela_docs/05-design/`](../05-design/).

Itens implementados sem inspeção visual lado-a-lado:
- `Wordmark.swift` — offsets do dot carmim, `padding(.trailing, -size * 0.04)` no `a` italic, baseline alignment.
- `Glyph.swift` — proporções da bolha de fala, posição dos 3 dots, lineWidth 1.6.
- 12 Color Sets em Display P3 — verificar saturação contra HTML/JSX do bundle de design (especialmente Carmine vs CarmineDeep e os 4 Inks no dark).

**Como verificar:**
1. `open tagarela_docs/05-design/bundle/project/tagarela\ design\ v1.html` lado a lado com Xcode Canvas das previews em `DesignSystem.swift`/`Wordmark.swift`/`Glyph.swift`.
2. Switchar entre light e dark no Xcode preview.
3. Tirar screenshot de cada e comparar pixel-a-pixel se possível.

**Critério de aceite:** doc [`02-arquitetura/01-modulos-fase1.md`](../02-arquitetura/01-modulos-fase1.md) lista qualquer divergência aceita; PR de correção pra divergências não aceitas.

## 8. `IndicatorPill` recria `NSHostingController` a cada level update

**Arquivos:**
- [`app/Tagarela/App/AppContainer.swift`](../../app/Tagarela/App/AppContainer.swift) (`refreshIndicator`)
- [`app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift`](../../app/Tagarela/UI/Indicator/FloatingIndicatorPanel.swift) (`show(rootView:)`)

`PipelineCoordinator` agora tica audioLevel a cada 80ms durante recording (~12 Hz). Cada update propaga via `pipeline.events → AppState.pipeline → refreshIndicator(for:) → indicatorPanel.show(rootView: IndicatorPill(state: ...))`. **`show()` cria um NSHostingController novo a cada chamada** — wasteful e pode causar flicker.

**Fix proposto:** introduzir `IndicatorViewModel: ObservableObject` com `@Published var state`. `FloatingIndicatorPanel.show()` é chamado **uma vez** com `IndicatorPill(viewModel: vm)`; `refreshIndicator` só atualiza `vm.state`. SwiftUI re-renderiza a pílula in-place sem recriar o host.

**Critério de aceite:** após gravar 30s, contagem de `NSHostingController` lifecycles permanece em 1 (medir via Instruments/Allocations). Sem flicker visível.

## 9. Documents Folder permission injetada inadvertidamente

**Contexto:** durante o stress test inicial, antes de descobrir o caminho do TCC manual, alguma chamada de file API do Tagarela disparou um popup nativo de "Documents folder access" (provavelmente `WhisperKit.download(...)` baixando o modelo pra `~/Documents/huggingface/...`). User aceitou. Isso virou a única entry TCC do Tagarela antes da injeção manual e ainda existe.

**Crítica:** o app NÃO deveria precisar de Documents folder access. WhisperKit deveria baixar pra `~/Library/Application Support/com.tagarela.Tagarela/...` ou caminho equivalente.

**Critério de aceite:** investigar onde WhisperKit está baixando, configurar `downloadBase` (campo do `WhisperKitConfig`) pra um path em `Application Support`. Após próximo download fresco, `kTCCServiceSystemPolicyDocumentsFolder` pra Tagarela some.

---

## Quando isto sai daqui

Quando os itens 1–9 estiverem resolvidos (cada um com critério de aceite atendido), apagar este arquivo e adicionar uma linha em [`README.md`](../README.md) marcando "Cleanup Fase 1: ✅ resolvido em YYYY-MM-DD".
