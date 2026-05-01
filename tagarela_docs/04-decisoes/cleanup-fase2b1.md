---
data: 2026-04-29
status: fechado
revisitar_em: n/a
fechados_em: 2026-04-29 (1, 2, 3) + 2026-04-30 (2 follow-up, 4)
---

# Cleanup pós-Fase 2b-1

Achados levantados durante o aceite manual da Fase 2b-1 (ver [`fase2b1-manual.md`](../03-funcionalidades/checklists/fase2b1-manual.md)). 1 fix aplicado durante o aceite, 2 achados conhecidos do roadmap, 1 follow-up de UX pra Fase 2b-3.

**Status (2026-04-30):** todos os 4 itens acionáveis fechados. Itens 1, 2, 3 fechados em 2026-04-29 (item 3 pela 2b-2). Item 2 follow-up + item 4 fechados em 2026-04-30 pela 2b-3. Item 5 segue como grupo informacional (achados pra fases futuras).

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

**Follow-up fechado na Fase 2b-3 (2026-04-30):** `CustomStyleEditSheet` ganha Toggle "Modo refinador (recomendado)" (default ON, paralelo ao toggle de code-switching) + caption help text explicativo + warning inline laranja (`exclamationmark.triangle.fill`) condicional ao modo livre. Persistência via novo campo `bypassDiscipline: Bool` (default `false`) em `@Model CustomStyle`. `asStyle()` consulta o campo pra decidir se prefixa `rewriterDiscipline`. Protocol `CustomStyleStore.create(...)` ganha o param sem default no protocol (call sites passam explícito — F2b3-7). 3 chaves Localizable em `styles.edit.discipline.*`. SwiftData lightweight migration validada implicitamente no aceite (Bloco 7 ok-com-ressalva — sem dado pré-existente, mas store da 2b-2 abriu sem crash). Plano B (`Bool?` opcional) não foi necessário. Verificado nos Blocos 5, 6, 8 do aceite manual da 2b-3. Commits `923395b`, `5dd57e2`, `32232c7`, `e109747`. Tuning fino dos built-ins foi explicitamente excluído do escopo da 2b-3 pelo user — segue como item futuro sem fase definida.

## 3. Visualizador de histórico não existe ainda — ✅ FECHADO 2026-04-29 (Fase 2b-2)

**Sintoma observado:** não há UI pra ver as transcrições gravadas. SwiftData store é populado normalmente (verificável via `defaults` ou inspecionando o arquivo em `~/Library/Application Support/com.tagarela.Tagarela/History.store`).

**Fix aplicado (Fase 2b-2):** `HistoryListView` + `HistoryEntryView` em `Preferences/UI/History/`, embutidos na seção `HistoryView` (Preferências > Histórico) — paginação observa `historyMaxItems`, cada entry mostra timestamp/raw/refined com kind badge, botão "Limpar tudo" com confirm. Plus: `RecentTranscriptionsSubmenu` (status bar) com últimos 5 entries que re-injetam no app de foco ao clicar. Verificado no aceite manual da 2b-2 (Bloco 7 + Bloco 8).

## 4. Esc não cancela injeção HTTP em vôo — ✅ FECHADO 2026-04-30 (Fase 2b-3)

**Sintoma observado:** capturar com OpenAI/Ollama, falar uma frase, apertar `Esc` antes da resposta. App volta pra idle, mas quando o request HTTP completa, a injeção acontece.

**Fix aplicado (2026-04-30, Fase 2b-3):** mesmo fix do [cleanup #5 da Fase 2a](./cleanup-fase2a.md#5-cancelamento-durante-refiner-não-interrompe-a-request-http--fechado-2026-04-30). Ver lá pros detalhes técnicos. Verificado nos Blocos 1 e 2 do aceite manual da 2b-3.

## 5. Achados secundários do code review do branch (informacional)

Durante reviews per-task e final review do branch, alguns pontos foram flagados sem ação imediata. Tracker pra próximas fases:

- **`HistoryStoreLive.init(inMemory:)`** ainda usa schema single-entity (`Transcription.self` apenas). Tests atuais não exercitam, mas vira fail se algum dia compartilhar com `CustomStyleStoreLive` em memória. Trivial fix quando ficar relevante.
- **`VersionedSchema` baseline** não foi estabelecido. Próxima mudança schema-breaking precisa estabelecer migration plan. 2 schemas adicionados sem chain (`Transcription` na 2a, `CustomStyle` na 2b-1).
- **`FakeCustomStore` duplicado** entre `StyleProviderTests.swift` e `RefinerFactoryTests.swift`. Se uma terceira aparição surgir, extrair pra `app/TagarelaTests/Helpers/FakeCustomStyleStore.swift`.
- **Locale-naive sort** em `StyleProvider.all` (`lowercased()` em vez de `localizedCaseInsensitiveCompare`). Defer até user reportar problema com diacríticos em nomes de custom styles.
- **`pipeline.sub.refining` localizable value** = "identity (sem llm)" — texto incorreto pro caso de OpenAI/Ollama processando. Pré-existente da 2a (não introduzido na 2b-1). Considerar dynamic text na 2b-2 junto dos toasts/indicadores.
- **Header stale do `Localizable.strings`** dizia "Apenas strings da Fase 2a" — atualizado durante T12 cleanup.

Nenhum desses bloqueia ship; todos são polish/maintenance.
