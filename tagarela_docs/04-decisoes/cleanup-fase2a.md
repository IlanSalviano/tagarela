---
data: 2026-04-28
status: parcialmente fechado
revisitar_em: 2026-05-12
fechados_em: 2026-04-29 (itens 1, 3 e 4)
---

# Cleanup pós-Fase 2a

Achados levantados durante o aceite manual da Fase 2a (ver [`fase2a-manual.md`](../03-funcionalidades/checklists/fase2a-manual.md)). Não bloqueiam o fechamento da fase — código está funcional. Bloqueiam a sensação de "limpo" antes da Fase 2b.

**Status (2026-04-29):** itens 1, 3 e 4 fechados (suíte de 89 testes verde após T2 da Fase 2b-1). Itens 2 e 5 seguem abertos — entram naturalmente no escopo da 2b ou viram débito separado.

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

## 2. Fallback Identity é silencioso pro usuário

**Arquivo:** [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift).

Quando o refiner remoto falha (timeout, offline, key inválida), o pipeline cai em `IdentityRefiner` e injeta o texto cru. Hoje o usuário só percebe vendo que o texto não veio refinado — nenhuma sinalização visual. Único registro é `logger.error("refiner failed (...)")` em `os_log`.

**Proposta:** event `.refinerFellBack(reason:)` no stream do pipeline → `wirePipelineToAppState` mostra um toast/badge breve no indicador OU muda cor do dot. Decidir UX na Fase 2b.

## 3. OpenAI responde conversacionalmente quando raw é muito curto — ✅ FECHADO 2026-04-29

**Arquivos:** [`app/Tagarela/Refiner/OpenAIRefiner.swift`](../../app/Tagarela/Refiner/OpenAIRefiner.swift), [`app/Tagarela/Refiner/BuiltInStyles.swift`](../../app/Tagarela/Refiner/BuiltInStyles.swift).

Com `gpt-5.4-mini` (default) + estilo "e-mail profissional", quando a transcrição vem quase vazia (sussurro, ruído), o LLM responde algo tipo `"Claro — envie o ditado de voz que eu transformo em um texto de e-mail profissional em português brasileiro."` em vez de processar.

**Sintoma observado:** 2 de 3 capturas curtas durante o teste de injeção em apps reais.

**Proposta:** guard de tamanho mínimo do raw (< N chars) → pula refiner, injeta direto OU adicionar instrução no system prompt tipo "Se o ditado for vazio ou ininteligível, responda apenas com o texto original sem comentários."

**Fix aplicado (2026-04-29):** guard de 8 chars (após trim de whitespace/newlines) no início de `OpenAIRefiner.refine(_:style:)`. Se `rawText` for menor, retorna direto sem chamar a API. 8 é heurística que deixa passar "ola" mas barra "" e " ". Implementado junto da injeção de `baseURL` (Tarefa 2 da fase 2b-1). 3 testes cobrindo: raw curto pula API; raw normal chama API; baseURL custom é usada na request.

## 4. Logs do pipeline em `stderr` não chegam no Console.app — ✅ FECHADO 2026-04-29

**Arquivos:** [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift), [`app/Tagarela/Audio/AudioCaptureLive.swift`](../../app/Tagarela/Audio/AudioCaptureLive.swift), [`app/Tagarela/Hotkey/HotkeyServiceLive.swift`](../../app/Tagarela/Hotkey/HotkeyServiceLive.swift), [`app/Tagarela/App/AppContainer.swift`](../../app/Tagarela/App/AppContainer.swift).

Vários logs estão em `FileHandle.standardError.write(...)` em vez de `os_log`/`Logger`. stderr de GUI app não vai pro Console.app — só dá pra ver com `sudo log stream` (que o user mantenedor não tem permissão).

**Sintoma observado:** durante o aceite manual, vários diagnósticos exigiram `sudo log stream` que falhou; tive que migrar logs ad-hoc pra `logger.info` pra debugar (cancelamento via pill, hide do indicator).

**Fix aplicado (2026-04-29):** todos os `FileHandle.standardError.write(...)` substituídos por `Logger(subsystem: "com.tagarela", category: …)` nos 4 arquivos. `Console.app` filtrando por `subsystem:com.tagarela` agora mostra todo o trace do pipeline sem `sudo`. Categorias: `Pipeline`, `Audio`, `Hotkey`, `App`. Suíte de 81 testes continua verde.

## 5. Cancelamento durante refiner não interrompe a request HTTP

**Arquivo:** [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift).

O fix da Fase 2a usa uma flag `cancelled` checada após cada `await`. Funciona pro lado do app (não inject, não save), mas a request HTTP pro OpenAI/Ollama continua rolando até completar (gastando tokens / segurando recurso).

**Proposta:** envolver `runTranscribeAndInject` numa `Task` armazenada e usar `Task.cancel()` no `handleCancel`. URLSession honra cancellation. WhisperKit pode não — mas pelo menos a parte de network seria cancelada.
