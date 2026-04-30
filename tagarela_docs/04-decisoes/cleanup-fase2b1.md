---
data: 2026-04-29
status: parcialmente fechado
revisitar_em: 2026-05-13
fechados_em: 2026-04-29 (itens 1, 2 e 3 — item 3 fechado pela Fase 2b-2)
---

# Cleanup pós-Fase 2b-1

Achados levantados durante o aceite manual da Fase 2b-1 (ver [`fase2b1-manual.md`](../03-funcionalidades/checklists/fase2b1-manual.md)). 1 fix aplicado durante o aceite, 2 achados conhecidos do roadmap, 1 follow-up de UX pra Fase 2b-3.

**Status (2026-04-29):** itens 1, 2, 3 fechados; item 4 segue empurrado pra 2b-3; item 5 = grupo informacional.

## 1. Janela de Preferências abria atrás do popover do MenuBarExtra — ✅ FECHADO 2026-04-29

**Arquivo:** [`app/Tagarela/App/PreferencesWindow.swift`](../../app/Tagarela/App/PreferencesWindow.swift).

Clicar "Preferências…" no menu da bandeja abria a janela mas o popover do `MenuBarExtra(style: .window)` ficava por cima — janela invisível atrás dele. `OpenAIKeyPromptWindow` (Fase 2a) tinha o mesmo bug e foi corrigido com helper estático.

**Fix aplicado (2026-04-29, commit `8bbd9e7`):** mesmo pattern — `dismissMenuBarExtraPopover()` chamado no início de `show()`, e `NSApp.activate(...)` antes de `makeKeyAndOrderFront`. Helper procura janelas com `MenuBarExtra` ou `NSStatusBarWindow` no nome do tipo e chama `orderOut(nil)`.

**Critério de aceite:** clicar "Preferências…" no menu da bandeja → janela aparece com foco, popover fecha. Verificado durante o aceite manual.

## 2. Custom style fazia LLM responder à frase em vez de transcrever — ✅ FECHADO 2026-04-29

**Arquivo:** [`app/Tagarela/Refiner/CustomStyle.swift`](../../app/Tagarela/Refiner/CustomStyle.swift).

User criou um custom style com prompt direto (estilo "reescreva como mensagem de commit"); LLM tratou o input como pergunta e respondeu à fala em vez de processar.

**Causa raiz:** built-ins (`BuiltInStyles.swift`) têm proteção embutida em cada `systemPrompt` ("Você refina ditados de voz... Não adicione informação que não estava no original"). Custom styles dependiam apenas do prompt escrito pelo user — sem essa instrução protetora, o LLM se comporta como chat assistant.

**Fix aplicado (2026-04-29, commit `855b416`):** `CustomStyle.asStyle()` agora prefixa sempre `rewriterDiscipline` ao prompt do user (paralelo ao code-switching opcional via toggle). Cláusula:

> Você é um pós-processador de transcrição de voz em português brasileiro. NÃO responda ao que foi dito; apenas reescreva o ditado seguindo as regras abaixo. NÃO adicione informação além do que foi falado. NÃO faça comentários, perguntas ou interpretações.

3 testes adaptados/criados em `CustomStyleTests`. Verificado em runtime durante o aceite (mesmo custom style passou a transcrever em vez de responder).

**Follow-up pra Fase 2b-3:** decidir UX dedicada — talvez toggle "modo refinador" na sheet de edição (igual ao toggle de code-switching), com explicação do que cada modo faz. Ou: deixar a discipline sempre on e adicionar campo "tom do output" pra usuário customizar comportamento. Combinar com tuning fino dos prompts dos built-in styles que já está no escopo da 2b-3.

## 3. Visualizador de histórico não existe ainda — ✅ FECHADO 2026-04-29 (Fase 2b-2)

**Sintoma observado:** não há UI pra ver as transcrições gravadas. SwiftData store é populado normalmente (verificável via `defaults` ou inspecionando o arquivo em `~/Library/Application Support/com.tagarela.Tagarela/History.store`).

**Fix aplicado (Fase 2b-2):** `HistoryListView` + `HistoryEntryView` em `Preferences/UI/History/`, embutidos na seção `HistoryView` (Preferências > Histórico) — paginação observa `historyMaxItems`, cada entry mostra timestamp/raw/refined com kind badge, botão "Limpar tudo" com confirm. Plus: `RecentTranscriptionsSubmenu` (status bar) com últimos 5 entries que re-injetam no app de foco ao clicar. Verificado no aceite manual da 2b-2 (Bloco 7 + Bloco 8).

## 4. Esc não cancela injeção HTTP em vôo — referência ao cleanup #5 da Fase 2a

**Sintoma observado:** capturar com OpenAI/Ollama, falar uma frase, apertar `Esc` antes da resposta. App volta pra idle, mas quando o request HTTP completa, a injeção acontece.

**Why aberto:** este é exatamente o [cleanup #5 da Fase 2a](./cleanup-fase2a.md#5-cancelamento-durante-refiner-não-interrompe-a-request-http). Empurrado pra **Fase 2b-3** (refactor pra `Task.cancel()` envolvendo `runTranscribeAndInject`).

**How to apply:** se virar dor antes da 2b-3, adiantar como sub-fase técnica isolada.

## 5. Achados secundários do code review do branch (informacional)

Durante reviews per-task e final review do branch, alguns pontos foram flagados sem ação imediata. Tracker pra próximas fases:

- **`HistoryStoreLive.init(inMemory:)`** ainda usa schema single-entity (`Transcription.self` apenas). Tests atuais não exercitam, mas vira fail se algum dia compartilhar com `CustomStyleStoreLive` em memória. Trivial fix quando ficar relevante.
- **`VersionedSchema` baseline** não foi estabelecido. Próxima mudança schema-breaking precisa estabelecer migration plan. 2 schemas adicionados sem chain (`Transcription` na 2a, `CustomStyle` na 2b-1).
- **`FakeCustomStore` duplicado** entre `StyleProviderTests.swift` e `RefinerFactoryTests.swift`. Se uma terceira aparição surgir, extrair pra `app/TagarelaTests/Helpers/FakeCustomStyleStore.swift`.
- **Locale-naive sort** em `StyleProvider.all` (`lowercased()` em vez de `localizedCaseInsensitiveCompare`). Defer até user reportar problema com diacríticos em nomes de custom styles.
- **`pipeline.sub.refining` localizable value** = "identity (sem llm)" — texto incorreto pro caso de OpenAI/Ollama processando. Pré-existente da 2a (não introduzido na 2b-1). Considerar dynamic text na 2b-2 junto dos toasts/indicadores.
- **Header stale do `Localizable.strings`** dizia "Apenas strings da Fase 2a" — atualizado durante T12 cleanup.

Nenhum desses bloqueia ship; todos são polish/maintenance.
