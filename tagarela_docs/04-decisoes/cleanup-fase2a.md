---
data: 2026-04-28
status: fechado
revisitar_em: n/a
fechados_em: 2026-04-29 (1, 2, 3, 4) + 2026-04-30 (5)
---

# Cleanup pós-Fase 2a

Achados levantados durante o aceite manual da Fase 2a (ver [`fase2a-manual.md`](../03-funcionalidades/checklists/fase2a-manual.md)). Não bloqueiam o fechamento da fase — código está funcional. Bloqueiam a sensação de "limpo" antes da Fase 2b.

**Status (2026-04-30):** todos os 5 itens fechados. Itens 1, 2, 3, 4 fechados em 2026-04-29 (item 2 pela 2b-2). Item 5 fechado em 2026-04-30 pela 2b-3. Suíte 155 testes verde ao fim da fase.

> Quando voltar (sugerido **2026-05-12**), rodar `xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test` antes/depois de cada item.

## 1. Default de `ollamaModel` é thinking model + timeout curto — ✅ FECHADO 2026-04-29

**Arquivos:** [`app/Tagarela/Preferences/Preferences+Defaults.swift`](../../app/Tagarela/Preferences/Preferences+Defaults.swift), [`app/Tagarela/Refiner/OllamaRefiner.swift`](../../app/Tagarela/Refiner/OllamaRefiner.swift).

`PreferencesDefaults.ollamaModel = "qwen3.5:9b-nvfp4"` é um modelo com chain-of-thought. Pra uma frase curta gera 800+ tokens de "thinking" antes de responder, levando ~50s. O `refinerTimeoutSec` default de 30s sempre estoura → fallback Identity silencioso.

**Sintoma observado:** durante o teste controlado de retenção/refiners, todas as capturas Ollama vinham marcadas `refinerKind = "none"` no histórico. Diagnóstico via `time curl` mostrou 52s de latência total no modelo default. Trocar pra `gemma4:e4b` (sem thinking) fez o caminho feliz funcionar.

**Fix aplicado (2026-04-29):**
- `PreferencesDefaults.ollamaModel` → `"gemma4:e4b"` (sem chain-of-thought).
- `PreferencesDefaults.refinerTimeoutSec` → `60s` (margem extra pra modelos maiores ou cold start).
- `PreferencesStoreTests.test_defaults_match_designV1` atualizado pros novos valores.
- Opção 3 (`"think": false` no payload) não foi adotada — adicionaria dependência da versão Ollama (>=0.4) e a troca de modelo já resolve.

**Critério de aceite (manual, pendente):** com defaults zerados, `cmd+option` numa frase técnica usando Ollama → completa em < 30s e grava `refinerKind = "ollama"` no histórico. *Validar no próximo aceite.*

## 2. Fallback Identity é silencioso pro usuário — ✅ FECHADO 2026-04-29

**Arquivo:** [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift).

Quando o refiner remoto falha (timeout, offline, key inválida), o pipeline cai em `IdentityRefiner` e injeta o texto cru. Hoje o usuário só percebe vendo que o texto não veio refinado — nenhuma sinalização visual. Único registro é `logger.error("refiner failed (...)")` em `os_log`.

**Fix aplicado (2026-04-29, Fase 2b-2):** novo `PipelineEvent.refinerFellBack(reason: RefinerFallbackReason)` emitido no `catch` do refine. Mapeamento de erros em `RefinerFallbackReason.init(refinerError:)` (8 casos: networkOffline, timeout, serverError, keyInvalid, modelMissing, ollamaUnreachable, malformedResponse, identityForced). `wirePipelineToAppState` em `AppContainer` consome o event e dispara `ToastCenter.show(.refinerFellBack(reason:))` que renderiza um `ToastView` 4s acima do indicator pill (ver [`fase2b2-design.md` §3 Toasts](../specs/2026-04-29-tagarela-v1-fase2b2-design.md)).

**Bonus (descoberto no aceite manual da 2b-2):** `URLError.cancelled` (-999) chega no refiner como `RefinerError.cancelled` quando o remote termina conexão abruptamente (ex: `pkill ollama` durante refine). Distinção via flag interna `cancelled` no `PipelineCoordinator`: `catch RefinerError.cancelled where cancelled` é user-cancel real (Esc); `catch RefinerError.cancelled` sem a flag vira `RefinerFallbackReason.networkOffline`. Commit `99d174e`.

**Critério de aceite (validado em 2026-04-29):** com Ollama backend, capturar texto e matar `ollama serve` durante o refine → toast "Refiner falhou — usando texto bruto" aparece + texto cru injetado. Verificado durante o aceite manual da 2b-2.

## 3. OpenAI responde conversacionalmente quando raw é muito curto — ✅ FECHADO 2026-04-29

**Arquivos:** [`app/Tagarela/Refiner/OpenAIRefiner.swift`](../../app/Tagarela/Refiner/OpenAIRefiner.swift), [`app/Tagarela/Refiner/BuiltInStyles.swift`](../../app/Tagarela/Refiner/BuiltInStyles.swift).

Com `gpt-5.4-mini` (default) + estilo "e-mail profissional", quando a transcrição vem quase vazia (sussurro, ruído), o LLM responde algo tipo `"Claro — envie o ditado de voz que eu transformo em um texto de e-mail profissional em português brasileiro."` em vez de processar.

**Sintoma observado:** 2 de 3 capturas curtas durante o teste de injeção em apps reais.

**Proposta:** guard de tamanho mínimo do raw (< N chars) → pula refiner, injeta direto OU adicionar instrução no system prompt tipo "Se o ditado for vazio ou ininteligível, responda apenas com o texto original sem comentários."

**Fix aplicado (2026-04-29):** guard de 8 chars (após trim de whitespace/newlines) no início de `OpenAIRefiner.refine(_:style:)`. Se `rawText` for menor, retorna direto sem chamar a API. 8 é heurística que deixa passar "ola" mas barra "" e " ". Implementado junto da injeção de `baseURL` (Tarefa 2 da fase 2b-1). 3 testes cobrindo: raw curto pula API; raw normal chama API; baseURL custom é usada na request.
**Escopo:** guard é OpenAI-only por agora. `OllamaRefiner` não tem equivalente — cleanup #3 documentou só sintomas com OpenAI/gpt-5.4-mini, e o guard adiciona um overhead que pode ser mais opinativo do que necessário pro Ollama. Se Ollama exibir comportamento similar com algum modelo, abrir débito separado.

## 4. Logs do pipeline em `stderr` não chegam no Console.app — ✅ FECHADO 2026-04-29

**Arquivos:** [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift), [`app/Tagarela/Audio/AudioCaptureLive.swift`](../../app/Tagarela/Audio/AudioCaptureLive.swift), [`app/Tagarela/Hotkey/HotkeyServiceLive.swift`](../../app/Tagarela/Hotkey/HotkeyServiceLive.swift), [`app/Tagarela/App/AppContainer.swift`](../../app/Tagarela/App/AppContainer.swift).

Vários logs estão em `FileHandle.standardError.write(...)` em vez de `os_log`/`Logger`. stderr de GUI app não vai pro Console.app — só dá pra ver com `sudo log stream` (que o user mantenedor não tem permissão).

**Sintoma observado:** durante o aceite manual, vários diagnósticos exigiram `sudo log stream` que falhou; tive que migrar logs ad-hoc pra `logger.info` pra debugar (cancelamento via pill, hide do indicator).

**Fix aplicado (2026-04-29):** todos os `FileHandle.standardError.write(...)` substituídos por `Logger(subsystem: "com.tagarela", category: …)` nos 4 arquivos. `Console.app` filtrando por `subsystem:com.tagarela` agora mostra todo o trace do pipeline sem `sudo`. Categorias: `Pipeline`, `Audio`, `Hotkey`, `App`. Suíte de 81 testes continua verde.

## 5. Cancelamento durante refiner não interrompe a request HTTP — ✅ FECHADO 2026-04-30

**Arquivo:** [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift).

O fix da Fase 2a usa uma flag `cancelled` checada após cada `await`. Funciona pro lado do app (não inject, não save), mas a request HTTP pro OpenAI/Ollama continua rolando até completar (gastando tokens / segurando recurso).

**Fix aplicado (2026-04-30, Fase 2b-3):** `PipelineCoordinator` agora envolve `runTranscribeAndInject` numa `pipelineTask: Task<Void, Never>?` armazenada (`internal private(set)` pra acesso em tests via `@testable`). `handleCancel` em `.processing/.refining` chama `pipelineTask?.cancel()` além de setar a flag `cancelled = true`. URLSession honra cancellation nativamente — Esc durante refine remoto aborta o request HTTP em vôo. WhisperKit é best-effort: se honrar `Task.isCancelled`, transcribe aborta junto; se não, novo helper `aborted() -> Bool { cancelled || Task.isCancelled }` consolidado nos 3 checkpoints internos impede progressão.

Lógica `catch RefinerError.cancelled where cancelled` (commit `99d174e`, distinguindo user-cancel real de network-drop disfarçado) preservada — flag `cancelled` continua existindo paralela ao `Task.isCancelled`. Tarefas 1+2 do plano da 2b-3 + 5 testes novos (`test_cancelDuringRefining_cancelsRefinerTask`, `_doesNotInject`, `_doesNotSaveHistory`, `test_cancelDuringProcessing_doesNotCallRefiner`, `test_pipelineTask_clearedAfterCompletion`).

**Critério de aceite (validado em 2026-04-30):** Blocos 1, 2, 3 do aceite manual da 2b-3. Bloco 1 com OpenAI: state idle < 200ms após Esc, nada injetado. Bloco 2 com Ollama: processo cai pra ocioso em ~1s (GPU/CPU não ficam em loop processando). Bloco 4 (regression): network-drop sem flag cai em fallback Identity normalmente. Commits `5593e7d`, `e9da254`, `6d26f0b`.
