---
data: pendente
status: pendente
fase: 2b-3
testado_em: pendente
build: pendente
---

# Aceite manual — Fase 2b-3

Checklist do aceite manual da Fase 2b-3. Conduzido bloco-a-bloco conforme [memory: workflow_aceite_manual](file:///Users/tars/.claude/projects/-Users-tars-Dev-tagarela/memory/workflow_aceite_manual.md).

**Setup geral:**
- Build em Release: `xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -configuration Release build`
- Instalar em `~/Applications/Tagarela.app` (não rodar do Xcode):
  ```bash
  pkill -f Tagarela.app && sleep 1 \
    && rm -rf ~/Applications/Tagarela.app \
    && cp -R /Users/tars/Dev/tagarela/app/build/Build/Products/Release/Tagarela.app ~/Applications/Tagarela.app \
    && open ~/Applications/Tagarela.app
  ```
- Domain UserDefaults: `com.tagarela.Tagarela`. Store SwiftData em `~/Library/Application Support/com.tagarela.Tagarela/`.

---

## Bloco 1 — Cancel HTTP (OpenAI)

**Setup:** backend OpenAI, key válida configurada em Preferências, modelo default (`gpt-5.4-mini`).

- [ ] Hotkey, falar "isso é um teste muito longo de cancelamento que deve ser interrompido", soltar hotkey.
- [ ] Durante `.refining` (pill amarelo) apertar Esc.
- [ ] State vai pra idle dentro de < 200ms (sensação visual).
- [ ] **Nada injetado** no app de foco (TextEdit, Notes, etc).
- [ ] Verificável por timing entre Esc e idle. Bonus: dashboard OpenAI não cobra a request abortada (verificar em https://platform.openai.com/usage após 5min).

**Edge:** Esc 100ms após começar refine — assert idle limpo, sem race nem flicker.

---

## Bloco 2 — Cancel HTTP (Ollama)

**Setup:** Ollama local rodando (`ollama serve`), modelo grande (preferencialmente algum que use GPU/CPU notavelmente — `gemma2:e9b` ou `llama3:e8b`). Selecionar como backend em Preferências.

- [ ] Abrir Activity Monitor (CPU + Memory) ou rodar `top -o cpu` numa Terminal lateral.
- [ ] Hotkey, frase técnica longa, soltar.
- [ ] Durante `.refining`, observar processo `ollama` consumindo CPU/GPU.
- [ ] Apertar Esc.
- [ ] Processo `ollama` cai pra idle dentro de ~1s. Não fica em loop processando. (Sintoma de antes do fix: GPU continuava em ~100% até completar o refine inteiro.)

---

## Bloco 3 — Cancel durante transcribe (whisper)

- [ ] Frase longa (10s+ de áudio), soltar hotkey.
- [ ] Durante `.processing` (não chega em `.refining` — pill cinza/azul, não amarelo), apertar Esc.
- [ ] State vai pra idle, sem inject.
- [ ] Whisper pode completar fisicamente (best-effort) — não é falha.
- [ ] Critério: UI limpa, sem inject, sem refine subsequente.

---

## Bloco 4 — Network-drop sem cancel (regression `99d174e`)

**Setup:** backend Ollama.

- [ ] Capturar frase, durante refine matar `ollama` em outro terminal:
      ```bash
      pkill ollama
      ```
- [ ] **Sem** apertar Esc.
- [ ] Toast "Refiner falhou — usando texto bruto" (ou similar mensagem de fallback) aparece acima do indicator pill.
- [ ] Texto cru injetado no app de foco.
- [ ] Garante que `99d174e` segue valendo após o refactor: `RefinerError.cancelled` sem flag `cancelled` cai em `RefinerFallbackReason.networkOffline` + identity fallback.

---

## Bloco 5 — Modo refinador (default)

- [ ] Preferências → Estilos → "Novo estilo custom".
- [ ] Nome: "Pergunta-teste". System prompt: "Reescreva o ditado mantendo o sentido, sem alterar nada substancial."
- [ ] Toggle "Modo refinador (recomendado)" deixa default ON.
- [ ] Caption "Refinador prefixa proteção..." visível em cinza.
- [ ] Sem warning laranja.
- [ ] Salvar.
- [ ] Selecionar o style (clicar no card).
- [ ] Ditar: "qual a capital da França".
- [ ] **Esperado:** texto injetado contém algo como "qual a capital da França" — o LLM transcreve a pergunta, **NÃO** responde "Paris".

---

## Bloco 6 — Modo livre

- [ ] Preferências → Estilos → editar o "Pergunta-teste" criado no Bloco 5.
- [ ] Desligar toggle "Modo refinador". Toggle vira OFF.
- [ ] **Warning laranja com triângulo aparece inline** logo abaixo do caption: "Modo livre: sem proteção. O LLM pode responder à fala em vez de transcrever."
- [ ] Salvar.
- [ ] Ditar: "qual a capital da França" (mesma frase do Bloco 5).
- [ ] **Esperado:** texto injetado agora pode responder "Paris" ou "A capital da França é Paris" — o LLM ficou livre, sem proteção.
- [ ] Confirma que o toggle muda comportamento real.

(Em algumas iterações o LLM pode mesmo assim transcrever — depende do prompt do user. O critério é: comportamento **muda**, não que responda determinísticamente.)

---

## Bloco 7 — Migration de styles existentes

**Pré-requisito:** ANTES do build novo da 2b-3, ter pelo menos 1 custom style criado na 2b-2 no store SwiftData. Se não tiver, criar antes:
- Reverter brevemente pro app instalado da 2b-2: `git stash; git checkout 373ae7e -- app/`, build Release, instalar, criar style "migration-teste", fechar app, e voltar:
  `git checkout main -- app/; git stash pop`
- Ou: confirmar que já existe via `ls ~/Library/Application\ Support/com.tagarela.Tagarela/`.

- [ ] Build novo da 2b-3, instalar via reciclo padrão.
- [ ] Abrir app, abrir Preferências → Estilos.
- [ ] Style "migration-teste" (ou outro existente da 2b-2) deve aparecer no card normalmente.
- [ ] Editar o style.
- [ ] Toggle "Modo refinador" vem **ON** (modo refinador, default).
- [ ] Sem warning.
- [ ] Comportamento de transcrição idêntico ao anterior (testar com hotkey).
- [ ] Sem crash de SwiftData migration ao abrir o app.

**Se Bloco 7 falhar com crash de migration:** ativar Plano B (campo `Bool?` opcional) — modificar `CustomStyle.swift` pra `var bypassDiscipline: Bool?`, ajustar `asStyle()` (`bypassDiscipline ?? false`), populate (`s.bypassDiscipline ?? false`). Hotfix dentro da própria fase.

---

## Bloco 8 — Persistência do toggle

- [ ] Editar style do Bloco 6 (ainda em modo livre), clicar Salvar de novo (sem mudanças).
- [ ] Fechar Preferências.
- [ ] Reabrir Preferências → Estilos → editar mesmo style.
- [ ] Toggle "Modo refinador" vem em OFF (livre).
- [ ] Warning laranja visível.

---

## Conclusão

- [ ] Todos os 8 blocos passaram **OU** achados não-bloqueantes documentados em `tagarela_docs/04-decisoes/cleanup-fase2b3.md`.
- [ ] Atualizar frontmatter desta nota: `status: ok` ou `status: ok-com-achados`.
- [ ] `testado_em: 2026-04-XX` e `build: <hash do commit>`.

Após aceite ✅, prosseguir com Tarefa 8 (doc closeout).
