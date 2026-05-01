---
data: 2026-05-01
fase: 2d-velocidade-transcribe
status: ok
---

# Aceite manual — Fase 2d (velocidade da transcrição)

Validações executadas durante a entrega da fase, organizadas pelos blocos do plano. Status final: **ok**.

## Bloco 1 — Onboarding picker funcional ✅

- [x] Onboarding aparece e chega no Passo 3.
- [x] Picker mostra 3 modelos: `large-v3_turbo` (selecionado, badge RECOM.), `large-v3`, `medium`.
- [x] Download do `large-v3_turbo` inicia automaticamente; barra visível.
- [x] Após `começar →`, `defaults read com.tagarela.Tagarela com.tagarela.preferences.whisperModelName` retorna o modelo escolhido.

## Bloco 2 — Onboarding erro de download ✅

- [x] Erro inline aparece com mensagem do `modelDownloadFailed` + botão `retry`. Validado contra falha real (HTTP 500 transitório do Hugging Face).
- [x] Clicar `retry` re-tenta download; sucesso depois carrega normal.

## Bloco 3 — Preferências > Transcrição ✅

- [x] Section "Transcrição" no sidebar (ícone `mic.and.signal.meter`).
- [x] Mostra "Modelo ativo: <name>".
- [x] Picker exibe os 3 modelos sem frame quadrado.
- [x] Toda a área da linha é clicável (fix `.contentShape(Rectangle())` aplicado durante T9 aceite).

## Bloco 4 — Swap fluxo feliz ✅

- [x] Clicar em outro modelo abre alerta de confirmação com tamanho. Confirmar `Trocar`.
- [x] Barra de progresso visível. Hotkey funciona durante download (transcreve com modelo antigo).
- [x] Status vai pra "Trocando…" brevemente.
- [x] Volta pra "Modelo ativo: <novo>".
- [x] Alerta cleanup aparece ("Apagar <antigo>? (libera ~X GB)"). User escolhe Manter ou Apagar.
- [x] Disparar hotkey após swap. Console.app log: `transcribe model=<novo> audio=Xs wall=Yms`.

Captura do log durante swap (T9 aceite):
```
loaded whisper model: large-v3
AppContainer.transcriber swapped (old=large-v3_turbo → new=large-v3)
unloaded whisper model
swap done: large-v3_turbo -> large-v3
```

## Bloco 5 — Bench (pendente)

Bench oficial com 5 ditados de ~3s por modelo (large-v3 vs large-v3_turbo) ainda não foi executado. Números preliminares disponíveis no log:

- large-v3: `audio=4.3s wall=8305ms` → ~1.9× tempo real.
- large-v3_turbo (durante swap, modelo `?`): `audio=3.4s wall=5623ms` → ~1.7× tempo real.

A diferença entre turbo e large-v3 ficou menor que o esperado neste hardware. Investigação:
- Ambos rodaram com `prewarm: true` + `computeOptions = (.cpuAndNeuralEngine, .cpuAndNeuralEngine)` ligado.
- Whisper sempre processa janela de 30s mesmo em áudio curto, então custo fixo da window domina pra ditados curtos.
- Pode ser que a redução real só apareça em ditados mais longos (10–30s) — investigar antes de declarar a fase como sucesso de velocidade real.

**Pra completar este bloco:** rodar 5 ditados de ~3s em large-v3, trocar via Preferências pra large-v3_turbo, rodar mais 5 ditados, anotar mediana, atualizar `02-arquitetura/07-modulos-fase2d.md` com os números.

## Bloco 6 — Swap erro + retry ✅

Validado durante T7 aceite (mesma código path, sheet + retry inline). Sheet modal abre, "Tentar de novo" reinicia, sucesso → cleanup prompt aparece.

## Bloco 7 — Cancel mid-download

Não testado explicitamente neste cycle. Coberto por testes unitários do `WhisperModelSwapCoordinatorTests`.

## Bloco 8 — Migration de user existente ✅

- [x] User estava com `large-v3_turbo` em disco do download da T7.
- [x] Após upgrade, app preservou turbo sem swap automático (log: `migration: preserved existing model on disk: large-v3_turbo`).
- [x] Disparar hotkey funcionou normalmente com turbo.

## Bloco 9 — Não-regressão ✅

- [x] Pílula sem frame retangular (fix da Fase 2c-cleanup mantida).
- [x] Toasts continuam aparecendo.
- [x] Custom styles, refiner, history funcionam sem mudanças.

## Bugs encontrados durante aceite (todos fechados)

- **T4:** `Logger.info` invisível em Console.app sem `--info` flag → trocado pra `.notice`.
- **T7:** Nome técnico do turbo era `large-v3-turbo` (hífen) mas o repo usa `large-v3_turbo` (underscore). Catálogo + tests + defaults atualizados.
- **T9:** `WhisperModelPicker` só respondia ao clicar no texto. Adicionado `.contentShape(Rectangle())` no Button label.

## Lições aplicadas

Da Fase 2c-cleanup ("spec + code review não substitui aceite runtime"): cada tarefa que tocou AppKit/SwiftUI/IO (T4, T6, T7, T8, T9) teve aceite manual em build local antes do commit. Os 3 bugs acima foram pegos pelo aceite — não pelo code review estático.
