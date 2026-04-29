---
data: 2026-04-28
status: aberto
revisitar_em: 2026-05-12
---

# Cleanup pós-Fase 2a

Achados levantados durante o aceite manual da Fase 2a (ver [`fase2a-manual.md`](../03-funcionalidades/checklists/fase2a-manual.md)). Não bloqueiam o fechamento da fase — código está funcional. Bloqueiam a sensação de "limpo" antes da Fase 2b.

> Quando voltar (sugerido **2026-05-12**), rodar `xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test` antes/depois de cada item.

## 1. Default de `ollamaModel` é thinking model + timeout curto

**Arquivos:** [`app/Tagarela/Preferences/Preferences+Defaults.swift`](../../app/Tagarela/Preferences/Preferences+Defaults.swift), [`app/Tagarela/Refiner/OllamaRefiner.swift`](../../app/Tagarela/Refiner/OllamaRefiner.swift).

`PreferencesDefaults.ollamaModel = "qwen3.5:9b-nvfp4"` é um modelo com chain-of-thought. Pra uma frase curta gera 800+ tokens de "thinking" antes de responder, levando ~50s. O `refinerTimeoutSec` default de 30s sempre estoura → fallback Identity silencioso.

**Sintoma observado:** durante o teste controlado de retenção/refiners, todas as capturas Ollama vinham marcadas `refinerKind = "none"` no histórico. Diagnóstico via `time curl` mostrou 52s de latência total no modelo default. Trocar pra `gemma4:e4b` (sem thinking) fez o caminho feliz funcionar.

**Opções de fix (não-mutuamente-exclusivas):**
1. Trocar default pra modelo sem thinking (`gemma4:e4b`, `llama3.2:3b`).
2. Subir `refinerTimeoutSec` default pra 90-120s.
3. Detectar thinking no `OllamaRefiner` e enviar `"think": false` no payload (Ollama API >= 0.4 suporta).

**Critério de aceite:** com defaults zerados, `cmd+option` numa frase técnica usando Ollama → completa em < 30s e grava `refinerKind = "ollama"` no histórico.

## 2. Fallback Identity é silencioso pro usuário

**Arquivo:** [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift).

Quando o refiner remoto falha (timeout, offline, key inválida), o pipeline cai em `IdentityRefiner` e injeta o texto cru. Hoje o usuário só percebe vendo que o texto não veio refinado — nenhuma sinalização visual. Único registro é `logger.error("refiner failed (...)")` em `os_log`.

**Proposta:** event `.refinerFellBack(reason:)` no stream do pipeline → `wirePipelineToAppState` mostra um toast/badge breve no indicador OU muda cor do dot. Decidir UX na Fase 2b.

## 3. OpenAI responde conversacionalmente quando raw é muito curto

**Arquivos:** [`app/Tagarela/Refiner/OpenAIRefiner.swift`](../../app/Tagarela/Refiner/OpenAIRefiner.swift), [`app/Tagarela/Refiner/BuiltInStyles.swift`](../../app/Tagarela/Refiner/BuiltInStyles.swift).

Com `gpt-5.4-mini` (default) + estilo "e-mail profissional", quando a transcrição vem quase vazia (sussurro, ruído), o LLM responde algo tipo `"Claro — envie o ditado de voz que eu transformo em um texto de e-mail profissional em português brasileiro."` em vez de processar.

**Sintoma observado:** 2 de 3 capturas curtas durante o teste de injeção em apps reais.

**Proposta:** guard de tamanho mínimo do raw (< N chars) → pula refiner, injeta direto OU adicionar instrução no system prompt tipo "Se o ditado for vazio ou ininteligível, responda apenas com o texto original sem comentários."

## 4. Logs do pipeline em `stderr` não chegam no Console.app

**Arquivos:** [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift), [`app/Tagarela/Audio/AudioCaptureLive.swift`](../../app/Tagarela/Audio/AudioCaptureLive.swift), [`app/Tagarela/Hotkey/HotkeyServiceLive.swift`](../../app/Tagarela/Hotkey/HotkeyServiceLive.swift).

Vários logs estão em `FileHandle.standardError.write(...)` em vez de `os_log`/`Logger`. stderr de GUI app não vai pro Console.app — só dá pra ver com `sudo log stream` (que o user mantenedor não tem permissão).

**Sintoma observado:** durante o aceite manual, vários diagnósticos exigiram `sudo log stream` que falhou; tive que migrar logs ad-hoc pra `logger.info` pra debugar (cancelamento via pill, hide do indicator).

**Proposta:** padronizar tudo em `Logger(subsystem: "com.tagarela", category: ...)`. Manter stderr só pra erros catastróficos (que já vão pra crashlog).

## 5. Cancelamento durante refiner não interrompe a request HTTP

**Arquivo:** [`app/Tagarela/Pipeline/PipelineCoordinator.swift`](../../app/Tagarela/Pipeline/PipelineCoordinator.swift).

O fix da Fase 2a usa uma flag `cancelled` checada após cada `await`. Funciona pro lado do app (não inject, não save), mas a request HTTP pro OpenAI/Ollama continua rolando até completar (gastando tokens / segurando recurso).

**Proposta:** envolver `runTranscribeAndInject` numa `Task` armazenada e usar `Task.cancel()` no `handleCancel`. URLSession honra cancellation. WhisperKit pode não — mas pelo menos a parte de network seria cancelada.
