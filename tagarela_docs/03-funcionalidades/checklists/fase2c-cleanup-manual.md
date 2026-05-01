---
data: 2026-05-01
fase: 2c-cleanup
status: ok-com-achados
---

# Fase 2c-cleanup — aceite manual

Aceite manual dos itens de cleanup ainda em escopo na branch `fase-2c-cleanup` após o refactor `FloatingIndicatorPanel` ter sido revertido (ver seção "Notas — refactor revertido" abaixo). Cobre o `WhisperKit downloadBase` (Task 5, fecha #9 da Fase 1) e a validação L/R Option (Task 6, fecha #1 da Fase 1).

## Bloco D — WhisperKit downloadBase

**Atenção:** este bloco é destrutivo (apaga modelo baixado). Backup recomendado.

1. Confirmar localização atual:
   ```bash
   ls ~/Documents/huggingface/ 2>/dev/null
   ls ~/Library/Application\ Support/com.tagarela.Tagarela/Models/ 2>/dev/null
   ```
2. Apagar `~/Documents/huggingface/` (ou só renomear pra `huggingface.bak`).
3. Apagar `~/Library/Application\ Support/com.tagarela.Tagarela/Models/` se existir.
4. Cold start Tagarela → onboarding pede download do modelo (ou primeiro hotkey ON dispara o download dependendo do fluxo).
5. Aguardar download completar.

**Esperado:**
- Novo modelo em `~/Library/Application\ Support/com.tagarela.Tagarela/Models/`. Path antigo `~/Documents/huggingface/` não recriado.
- System Settings → Privacy & Security → Files and Folders **não mostra** "Documents Folder" listado pra Tagarela (ou popup nativo não dispara).
- Falar uma frase de teste — transcrição funciona.

**Critério de aceite:** modelo no novo path + popup de Documents folder não dispara + transcrição OK.

Se popup `kTCCServiceSystemPolicyDocumentsFolder` aparecer mesmo assim:
- Verificar logs (`Console.app` filtrado por `subsystem == "com.tagarela"`) pra ver onde rola fileIO em `~/Documents`.
- Possível causa: WhisperKit faz cache adicional fora do `downloadBase`. Investigar.

**Resultado:** ❌ falhou — `~/Documents/huggingface/Models/` não foi recriada (override funcionou pra esta parte) **mas** `~/Library/Application Support/com.tagarela.Tagarela/Models/` ficou só com estrutura de diretório vazia, sem arquivos do modelo. Cold start subsequente: pílula não transitou pra `.refining` e texto não foi injetado. Commit `37a9552` revertido em `d4ff1e7`. Cleanup #9 da Fase 1 segue aberto.

## Bloco E — L/R Option distinguishing

**Pré-requisito:** Tagarela rodando (status bar visível). `Console.app` aberto, filtrado por `subsystem == "com.tagarela"` + categoria `Hotkey`.

1. Apertar **Left Option** 10× lentamente (1s entre presses).
2. Apertar **Right Option** 10× lentamente.

**Esperado:**
- Passo 1: zero linhas de `flagsChanged keyCode=61 (Right Option)` no Console.
- Passo 2: ~10 linhas de `flagsChanged keyCode=61 (Right Option)` (toggle on/off — pode dobrar).

**Critério de aceite:** 0 hits no passo 1.

Se passo 1 também disparar: documentar caso, manter cleanup #1 da Fase 1 aberto, abrir sub-task pra distinguir bits via `event.flags.rawValue & NX_DEVICERCTLKEYMASK` em [`HotkeyServiceLive.swift:99`](../../../app/Tagarela/Hotkey/HotkeyServiceLive.swift#L99).

**Resultado:** ✅ passou. Right Option 10× → pílula apareceu, hotkey toggle disparou (gravação rolou). Left Option 10× → nada (sem toggle, sem entry no log do Console.app filtrado por `Hotkey`). Confirma que `keyCode == 0x3D` é exclusivo do Right Option no macOS atual. TODO removido em `HotkeyServiceLive.swift:99`, commit `51c0d00`. Cleanup #1 da Fase 1 fechado.

---

## Notas — refactor `FloatingIndicatorPanel` revertido

Os Blocos A (pill flicker), B (NSHostingController allocations) e C (preview IndicatorPicker) foram **removidos** desta sessão de aceite porque o refactor que eles validavam (Task 3 do plano: `FloatingIndicatorPanel` em torno de `IndicatorViewModel` + `IndicatorRootView`) **regrediu o pipeline em runtime** quando testado pelo user em 2026-05-01:

- Pill não transitou pra `.refining` (cor laranja não apareceu).
- Texto não foi injetado no app alvo.

Sintomas: estado da pipeline parou de propagar pra UI **e** o inject final falhou. Os 3 commits do refactor (`15b4630` IndicatorViewModel, `1d90915` IndicatorRootView, `ba25fd9` refactor de `FloatingIndicatorPanel`) foram revertidos. Suíte de 155 testes verde (155 = baseline, 5 testes do `IndicatorViewModelTests` foram embora junto com o vm).

**Cleanups que continuam abertos por causa do revert:**
- Cleanup #8 da Fase 1 (`NSHostingController` recriado a cada level update) — **reaberto** com nota "tentado em 2026-05-01 via refactor `IndicatorViewModel`; broke pipeline em runtime; revertido; root cause unknown, precisa investigação mais profunda antes de tentar de novo."
- Cleanup #1 da Fase 2b-3 (pill flicker no Esc rápido) — **reaberto** pelo mesmo motivo.

A investigação do root cause não foi feita nesta sessão. Hipóteses ainda não testadas: (a) `NSHostingController` + `@ObservedObject` com `@MainActor`-isolated `ObservableObject` interagem mal em runtime; (b) panel sizing fica preso ao tamanho do primeiro estado renderizado (`.idle` no momento da criação do hostingController); (c) main actor ficou bloqueado por re-renders sincronos cascateados. Validar via `Logger.tagarela.info` em `wirePipelineToAppState` + `refreshIndicator` + `show()` rodando do Xcode (Cmd+R) com stderr visível.

---

## Status final

**ok-com-achados** (2026-05-01).

- ✅ Bloco E (L/R Option): passou. Cleanup #1 da Fase 1 fechado.
- ❌ Bloco D (downloadBase): falhou. Cleanup #9 da Fase 1 segue aberto, commit revertido.
- ⚠️ Blocos A/B/C (refactor `IndicatorViewModel`): removidos do escopo após regressão runtime detectada antes destes blocos rodarem. Cleanups #8 da Fase 1 e #1 da 2b-3 seguem abertos, commits revertidos.

**Liquido entregue desta sessão:**
- ✅ Cleanup #1 da Fase 1 (L/R Option): TODO removido após validação empírica.
- ✅ Cleanup #3 da Fase 1 (stderr → Logger): registro retroativo do fechamento (que aconteceu na 2b-1).
