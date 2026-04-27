---
data: 2026-04-27
status: aberto
escopo: aceite manual da Fase 2a
---

# Aceite manual — Fase 2a

Pré-condição: build da 2a instalado em `~/Applications/Tagarela.app`. Ollama rodando (`ollama serve` em outro terminal) caso queira testar o backend Ollama.

## Setup limpo (rodar antes de começar)

- [ ] Apagar key OpenAI atual: `security delete-generic-password -s com.tagarela -a openai-api-key 2>/dev/null || true`
- [ ] Apagar UserDefaults: `defaults delete com.tagarela.preferences 2>/dev/null || true`
- [ ] Apagar history: `rm -rf ~/Library/Application\ Support/com.tagarela.Tagarela/History.store*`
- [ ] Reabrir app

## Backend submenu

- [ ] Status bar mostra "Backend ▸ Sem LLM" (default).
- [ ] Trocar pra Ollama: label atualiza pra "Ollama". Próxima captura usa Ollama.
- [ ] Trocar pra OpenAI **sem key**: modal de API key abre automaticamente.
- [ ] Cancelar modal: backend volta pra valor anterior (Ollama).
- [ ] Trocar pra OpenAI de novo: modal abre.
- [ ] Colar key real e Salvar: modal fecha. Backend = OpenAI.
- [ ] Reabrir app: backend ainda OpenAI (persistiu).
- [ ] Item "Configurar API key da OpenAI…" abre modal mesmo com key cadastrada.

## Style submenu

- [ ] Default = "conversa informal".
- [ ] Trocar pra "e-mail profissional": gravar "tô indo lá agora" → texto colado tem tom mais formal ("Estou indo lá agora.").
- [ ] Trocar pra "cru — sem reescrita": gravar "tô indo lá" → texto colado é cru, sem reescrita. Confirmar via Console.app filtrado por subsystem `com.tagarela` que não houve log de OpenAIRefiner ou OllamaRefiner.

## Refiners — caminho feliz

- [ ] OpenAI: gravar "preciso fazer um deploy do Postgres" → texto refinado preserva "deploy" e "Postgres".
- [ ] Ollama: idem com Ollama selecionado.

## Refiners — fallback Identity

- [ ] OpenAI selecionado, internet desligada: gravar uma frase → texto **cru** chega ao destino. Console.app mostra log de fallback. Histórico marca `refinerKind = "none"`.
- [ ] Ollama selecionado, `ollama serve` desligado: gravar → texto cru chega. Log de fallback. Histórico marca `refinerKind = "none"`.
- [ ] OpenAI selecionado com key inválida (substituir por `sk-invalida` via modal): gravar → fallback Identity. Log de `.unauthorized`.

## Histórico (sem UI ainda)

- [ ] Após 5 capturas, inspecionar via SQLite:
  ```bash
  sqlite3 ~/Library/Application\ Support/com.tagarela.Tagarela/History.store \
    "SELECT ZCREATEDAT, ZREFINERKIND, length(ZRAWTEXT), length(ZREFINEDTEXT) FROM ZTRANSCRIPTION ORDER BY ZCREATEDAT DESC;"
  ```
- [ ] Setar retenção pra 3: `defaults write com.tagarela.preferences historyMaxItems -int 3`. Reabrir app. Fazer 1 captura. Conferir que o store agora tem só 3 entries.
- [ ] Restaurar default: `defaults write com.tagarela.preferences historyMaxItems -int 200`.

## Cleanup #4 — audioBoostMaxGain

- [ ] `defaults write com.tagarela.preferences audioBoostMaxGain -float 5`. Gravar uma frase em volume baixo — boost agora é capado em 5×, log do AudioCaptureLive mostra `peak after` proporcional.
- [ ] `defaults write com.tagarela.preferences audioBoostMaxGain -float 20` pra restaurar default.

## Cleanup #2 — promptTokens (validação A/B)

> Ver checklist separada em [`fase2-validacao-prompt.md`](./fase2-validacao-prompt.md). Resultado vira ADR-0002.

## Cancelamento

- [ ] Iniciar gravação, falar 3s, apertar `right ⌥` pra parar, durante o estado "refining" pressionar Esc → indicador some, sem nova entrada no histórico.

## Injeção em apps reais

Testar 1 captura com texto refinado em cada app:

- [ ] TextEdit
- [ ] Notes
- [ ] Slack
- [ ] VS Code
- [ ] Terminal
- [ ] Mail (cliente nativo)

Em cada um: texto refinado é colado no foco; clipboard é restaurado depois de 250ms.

## Sair e voltar

- [ ] Sair via menu → "sair". Reabrir app. Conferir que `prefs.refinerKind`, `prefs.selectedStyleID`, key OpenAI e histórico continuam.

## Checklist concluído

Quando todos os itens marcados:

1. Editar header do arquivo: `status: concluído (YYYY-MM-DD)`.
2. Reportar resultado pro mantenedor (issues abertas viram fix commits separados antes da Tarefa 16).
