---
data: 2026-04-29
status: ok-com-achados
fase: 2b-1
ambiente: macOS 26 (build Release instalada em ~/Applications/Tagarela.app); Ollama rodando local com gemma4:e4b
executado_em: 2026-04-29
achados: ver tagarela_docs/04-decisoes/cleanup-fase2b1.md
---

> **Resumo do aceite (2026-04-29):** Blocos 1-11 e 13 todos OK (1 fix aplicado durante: z-order do popover do MenuBarExtra — commit 8bbd9e7). Bloco 12 com 3 achados:
> - 12.1 visualizador de histórico — esperado, escopo da Fase 2b-2.
> - 12.2 custom style respondia à frase em vez de transcrever — **fix aplicado** (commit 855b416, rewriter discipline prefixada).
> - 12.5 Esc não cancela injeção em vôo — cleanup #5 da 2a, esperado, escopo da Fase 2b-3.


# Checklist manual — Fase 2b-1

Aceite manual após implementação completa. Rodar com defaults zerados:

```bash
defaults delete com.tagarela.Tagarela 2>/dev/null
rm -rf ~/Library/Application\ Support/com.tagarela
```

## 0. Pré-requisitos
- [ ] Suíte XCTest verde (`xcodebuild test`).
- [ ] Build sem warnings novos.
- [ ] `ollama list` mostra `gemma4:e4b`.

## 1. Janela de Preferências (shell + nav)
- [ ] `⌘,` abre a janela.
- [ ] Botão "Preferências…" no menu da status bar abre a mesma janela.
- [ ] Sidebar lista: Geral, Refiner (com sub-itens Geral/Ollama/OpenAI), Estilos, Áudio, Histórico, Vocabulário, Atalhos.
- [ ] Selecionar cada uma navega pro detail correspondente.
- [ ] Fechar (⌘W) e reabrir (⌘,) restaura tamanho e posição.
- [ ] Resize abaixo do mínimo (600×400) é bloqueado.

## 2. Geral
- [ ] Versão e Build são exibidos corretamente.

## 3. Refiner > Geral
- [ ] Trocar Backend entre Ollama/OpenAI/Sem LLM persiste em `defaults read`.
- [ ] Mudar timeout pra 90 persiste; nova captura usa 90s.

## 4. Refiner > Ollama
- [ ] BaseURL mostra `http://localhost:11434`.
- [ ] Lista de modelos carrega via `/api/tags` em < 2s.
- [ ] `gemma4:e4b` aparece selecionado por default.
- [ ] Mudar baseURL pra `http://localhost:99999` → após delay, banner amarelo "Ollama offline".
- [ ] Clicar Atualizar → loading volta + erro/lista re-fires.
- [ ] Voltar baseURL pro válido → lista volta.
- [ ] `prefs.ollamaModel` que não está instalado aparece com sufixo "(não instalado)".

## 5. Refiner > OpenAI
- [ ] Provider segmented: 4 opções (OpenAI oficial / OpenRouter / LM Studio / URL custom).
- [ ] Selecionar OpenRouter → baseURL atualiza pra `https://openrouter.ai/api/v1`.
- [ ] Selecionar URL custom → baseURL fica editável e mantém o valor anterior.
- [ ] Modelo é editável (free text).
- [ ] API key: "Não configurada" inicialmente.
- [ ] Clicar "Alterar…" → modal abre, inserir key dummy `sk-test-1234`, fechar. Display vira `••••••••1234`.

## 6. Estilos
- [ ] Grid mostra 4 built-in cards (badge PRONTO) + card "+ Novo" dashed.
- [ ] Tap num card built-in seleciona (highlight + persiste em `prefs.selectedStyleID`).
- [ ] "+ Novo": sheet abre vazio, "Salvar" disabled enquanto nome OU prompt vazio (incluindo whitespace-only).
- [ ] Preencher nome="commits git", prompt curto, salvar → card aparece com lápis ✎.
- [ ] Tap no novo card seleciona; submenu Style da menubar mostra "commits git" misturado aos built-ins, ordenado.
- [ ] Lápis no card abre sheet pré-preenchido. Editar nome, salvar → submenu reflete o novo nome.
- [ ] Right-click no card custom → "Apagar" → NSAlert. Confirmar → some.
- [ ] Apagar o style ativo → automaticamente volta pra `conversa informal` no submenu.

## 7. Áudio
- [ ] Slider mostra `prefs.audioBoostMaxGain` atual.
- [ ] Step de 1× nas pontas.
- [ ] Range respeita 1–50.
- [ ] Display "%.1f×" atualiza com monospaced digits.

## 8. Histórico
- [ ] `historyMaxItems` e `historyMaxDays` editáveis (numéricos). Valores persistem.
- [ ] Tentar setar 0 ou negativo → clampa pra 1 (via setHistoryMaxItems/setHistoryMaxDays).

## 9. Vocabulário
- [ ] TextEditor mostra um termo por linha.
- [ ] Editar (adicionar termo, remover) persiste.
- [ ] Linhas em branco e whitespace trailing são normalizadas no próximo onAppear.

## 10. Atalhos
- [ ] Read-only: `⌥ direito` (toggle) e `Esc` (cancelar).
- [ ] Texto auxiliar "Atalhos customizáveis chegam em uma versão futura" presente.

## 11. Localizable
- [ ] Nenhuma string visível em inglês na UI (exceto identifiers como "OpenAI", "Ollama", nomes de modelos).
- [ ] `LocalizableKeysTests` verde (smoke das 8 chaves principais).
- [ ] `swift tools/audit_strings.swift` retorna apenas hits ignoráveis (version tag, separadores, identifiers de design).

## 12. Pipeline runtime (regressão)
- [ ] Capturar com Ollama + estilo built-in: completa em < 30s, `refinerKind=ollama` no histórico.
- [ ] Capturar com Ollama + custom style criado na seção 6: refiner usa o systemPrompt correto (validar via log + diferença visível no output).
- [ ] OpenAI com key válida: idem, completa.
- [ ] OpenAI com endpoint LM Studio (local): se LM Studio estiver rodando, captura completa via baseURL custom.
- [ ] Cancel via Esc durante recording: volta pra idle.
- [ ] OpenAI raw "ola" (3 chars): pulado, retorna "ola" sem chamada à API (cleanup #3 da 2a).
- [ ] OpenAI raw "1234567" (7 chars): pulado.
- [ ] OpenAI raw "12345678" (8 chars): chama API normalmente.

## 13. Submenu Style reativo (T6)
- [ ] Abrir o submenu Style com 0 custom styles → 4 built-ins aparecem.
- [ ] Sem fechar o submenu, criar um custom via Preferências (em outra janela). Reabrir submenu → custom aparece misturado.
- [ ] Editar (rename) custom style → submenu reflete o novo nome ao reabrir.
- [ ] Apagar custom selecionado → submenu volta a marcar `conversa informal`.

## 14. Resultado
- [ ] Todos os itens acima ✅. Marcar `status: ok` no frontmatter.
- [ ] Achados adicionais documentados em `tagarela_docs/04-decisoes/cleanup-fase2b1.md` (criar se houver).
