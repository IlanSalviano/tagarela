---
data: 2026-04-29
status: aprovado para implementação
fase: 2b-1 de 3 sub-fases da Fase 2b
goal: janela de Preferências completa, CRUD de custom styles, endpoints custom OpenAI, migração total para Localizable
---

# tagarela v1 — Fase 2b-1: Preferências + Custom styles + Endpoints custom + Localizable

Spec da primeira sub-fase da Fase 2b. Decompõe a Fase 2b "monolítica" da spec da [Fase 2a](./2026-04-27-tagarela-v1-fase2a-design.md) em três sub-fases sequenciais; ver §1.5.

> Regras de processo: ver [`/CLAUDE.md`](../../CLAUDE.md). Nada é implementado sem ler a doc; nada é dado como pronto sem atualizar a doc.
>
> **Spec base:** [`2026-04-26-tagarela-v1-design.md`](./2026-04-26-tagarela-v1-design.md). Esta spec é especialização: onde diverge é marcado explicitamente.
>
> **Spec antecessora:** [`2026-04-27-tagarela-v1-fase2a-design.md`](./2026-04-27-tagarela-v1-fase2a-design.md). 2a entregou pipeline LLM funcional, persistência, refiners e UI mínima na status bar. 2b-1 entrega a tela de Preferências.
>
> **Estado pós-2a:** suíte de 81 testes verde; cleanups [#1 e #4 da 2a](../04-decisoes/cleanup-fase2a.md) fechados em 2026-04-29 (defaults Ollama corrigidos, logs migrados pra `Logger`).

---

## 1. Visão e escopo

### 1.1 Goal

Dar ao usuário uma janela de Preferências completa que substitua todas as configurações que hoje só são editáveis via `defaults write`, adicione CRUD de custom styles, suporte endpoints custom OpenAI (Azure/OpenRouter/LM Studio), e migre todas as strings user-facing do app para `Localizable.strings`.

### 1.2 Exit criteria (pronto pra Fase 2b-2)

1. `⌘,` ou `Tagarela > Preferências…` abre janela com **7 seções** na sidebar (Geral, ▾ Refiner [Geral/Ollama/OpenAI], Estilos, Áudio, Histórico, Vocabulário, Atalhos).
2. Toda chave hoje em `PreferencesDefaults` é editável pela GUI: `refinerKind`, `selectedStyleID`, `openAIModel`, `ollamaBaseURL`, `ollamaModel` (com **scan dinâmico** via `/api/tags`), `refinerTimeoutSec`, `technicalVocabulary` (textarea), `historyMaxItems`, `historyMaxDays`, `audioBoostMaxGain`. Nova chave `openAIEndpoint` (JSON) também editável.
3. **CRUD de custom styles** funcional via SwiftData `@Model CustomStyle`. Built-ins continuam imutáveis. "+ Novo" abre sheet vazio. Cards visuais com badge "PRONTO" pros built-ins e ✎ pros custom.
4. Submenu Style da status bar passa a listar built-ins **+** custom (misturados, ordenados por nome).
5. **Endpoints custom OpenAI** (provider OpenAI oficial / OpenRouter / LM Studio / URL custom) salvam em `PreferencesStore` e são consumidos pelo `OpenAIRefiner`.
6. Modal `OpenAIKeyPromptWindow` continua existindo; tela Refiner > OpenAI mostra "••••••••3a4f" + botão "Alterar…" que reabre o modal.
7. Aba **Atalhos é read-only display** ("Toggle: ⌥ direito", "Cancelar: Esc"). Re-bind real fica pra fase futura.
8. Toda string user-facing das Fases 1 + 2a + 2b-1 está em `Localizable.xcstrings` (pt-BR base; sem traduções).
9. Suíte XCTest verde com **~25-35 testes novos** (total ~107-117).
10. **Cleanup [#3 da 2a](../04-decisoes/cleanup-fase2a.md#3-openai-responde-conversacionalmente-quando-raw-é-muito-curto)** (OpenAI conversacional em raw curto) entra como guard de tamanho mínimo no `OpenAIRefiner` — bônus barato porque já estaremos editando o refiner.

### 1.3 Não-objetivos da 2b-1

Vão pra 2b-2:
- Visualizador de histórico (janela "Histórico completo").
- Menu "últimos 5" na status bar.
- Indicadores B/C/D do design v1.
- Toasts (sucesso, erro, fallback).
- Estados visuais "permissão faltando" no menu.
- [Cleanup #2 da 2a](../04-decisoes/cleanup-fase2a.md#2-fallback-identity-é-silencioso-pro-usuário) (fallback Identity surfaceiado) — depende de toasts.

Vão pra 2b-3:
- Onboarding novo (LLM scan, key prompt no fluxo guiado, escolha inicial de backend/style).
- Re-bind real da hotkey, captura L/R Option.
- [Cleanup #5 da 2a](../04-decisoes/cleanup-fase2a.md#5-cancelamento-durante-refiner-não-interrompe-a-request-http) (cancel HTTP real via `Task.cancel()`).
- Tuning fino dos prompts dos built-in styles (além do guard simples do cleanup #3).

Fora de escopo (sem fase definida):
- Custom styles importáveis/exportáveis (JSON drag-drop).
- Edição em batch / drag-drop reorder de custom styles.
- Provider Azure first-class (com deployment/api-version dedicados) — entra via "URL custom" na 2b-1.
- Modelo OpenAI com combobox curado — fica free-text.

### 1.4 Decisões nucleares (do brainstorming 2026-04-29)

| # | Decisão | Alternativas consideradas |
|---|---|---|
| F2b1-1 | Janela com **`NavigationSplitView`** sidebar+detail (não SwiftUI Settings scene) | Settings scene canônico TabView; form único scrollável |
| F2b1-2 | **7 seções** na sidebar, com Refiner aninhado (Geral/Ollama/OpenAI) | 6 seções flat; merge Geral+Atalhos |
| F2b1-3 | **Áudio é seção dedicada** (não parte de Geral nem Atalhos) | Botar `audioBoostMaxGain` em Geral; em Atalhos |
| F2b1-4 | Custom styles em **cards visuais** com edição via **sheet modal** | Lista única + detail panel; dois grupos colapsados |
| F2b1-5 | "+ Novo estilo" abre modal **vazio** (sem "duplicar de…") | Picker de duplicação primeiro; dropdown "preencher com" |
| F2b1-6 | Custom styles persistidos em **SwiftData** (mesmo container do history) | UserDefaults JSON; arquivo Application Support |
| F2b1-7 | Endpoints custom OpenAI: **sub-aba** Refiner > OpenAI (não modal nem disclosure) | Disclosure expansível "Avançado"; sheet modal dedicado |
| F2b1-8 | API key OpenAI: campo na tela é **read-only**; modal `OpenAIKeyPromptWindow` continua sendo o editor | Campo editável inline (eliminar modal); dois entrypoints independentes |
| F2b1-9 | Modelo Ollama: **scan dinâmico** via `/api/tags` (reusa `OllamaHealthChecker`) | Free text puro; combobox hardcoded |
| F2b1-10 | Atalhos tab é **read-only display**; re-bind real fica pra fase futura | Re-bind básico (modificador único); re-bind completo (modifiers+key); mover Atalhos pra 2b-2/2b-3 |
| F2b1-11 | **Migração total** Localizable (Fases 1+2a+2b-1) | Só strings da 2b-1; só strings da 2a+2b-1; deferir tudo pra 2b-2 |
| F2b1-12 | Cleanup #3 da 2a (guard raw curto no OpenAI) entra como bônus barato | Deixar pra 2b-3 |
| F2b1-13 | Azure entra via "URL custom" — sem lógica condicional | Provider Azure first-class com deployment/api-version |

### 1.5 Decomposição da Fase 2b (contexto)

A Fase 2b "original" descrita na spec da 2a abrangia: tela de Preferências completa, custom styles, endpoints custom, Localizable, menu "últimos 5", indicadores B/C/D, toasts, estados de permissão, onboarding novo. Brainstorming de 2026-04-29 decompôs em três sub-fases sequenciais:

- **2b-1 (este doc)** — Preferências + Custom styles + Endpoints + Localizable.
- **2b-2** — Histórico visível + Indicadores B/C/D + Toasts + Estados de permissão + Cleanup #2 (fallback Identity surfaceiado).
- **2b-3** — Onboarding completo + Re-bind hotkey + Cleanup #5 (cancel HTTP real) + Tuning fino dos prompts.

Ordem é por impacto/uso: 2b-1 destrava configurações hoje só editáveis via CLI (maior dor diária); 2b-2 dá feedback ao usuário; 2b-3 polimento de fluxo.

---

## 2. Arquitetura

### 2.1 Princípios herdados

- Boundaries via protocolos. UI consome `PreferencesStore` (já `@Published`), `RefinerFactory`, e o novo `CustomStyleStore` via `@MainActor`.
- SwiftUI quando dá; AppKit/`NSPanel` só pra modals que já existem (`OpenAIKeyPromptWindow`).
- Single `ModelContainer` SwiftData segurando `[Transcription, CustomStyle]`. Falha do container → ambos os stores caem em fallback Noop.
- Strings user-facing → `String(localized: "preferences.refiner.title", comment: "…")` apontando pra `Localizable.xcstrings`.

### 2.2 Módulos novos

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| `PreferencesWindow` | `App/PreferencesWindow.swift` | `NSWindowController` ou `WindowGroup` SwiftUI segurando a `NavigationSplitView`. Wired ao menu `Tagarela > Preferências…` (`⌘,`). Persiste tamanho/posição via `NSWindow.setFrameAutosaveName("PreferencesWindow")`. |
| `PreferencesRoot` | `Preferences/UI/PreferencesRoot.swift` | View raiz com sidebar + detail. Mantém `@State selection: PrefsSection`. |
| `PrefsSection` | `Preferences/UI/PrefsSection.swift` | Enum hierárquico: `.geral`, `.refinerGeral`, `.refinerOllama`, `.refinerOpenAI`, `.estilos`, `.audio`, `.historico`, `.vocabulario`, `.atalhos`. |
| Views por seção | `Preferences/UI/Sections/*.swift` | `GeneralView`, `RefinerGeneralView`, `RefinerOllamaView`, `RefinerOpenAIView`, `StylesView`, `AudioView`, `HistoryView`, `VocabularyView`, `ShortcutsView`. SwiftUI forms observando `PreferencesStore`. |
| `CustomStyleEditSheet` | `Preferences/UI/Sheets/CustomStyleEditSheet.swift` | Modal pra criar/editar custom style. Form com `name`, `systemPrompt`, `appendCodeSwitching`. Reusado em create/update mode. |
| `CustomStyle` | `Refiner/CustomStyle.swift` | `@Model final class CustomStyle { id: UUID, name: String, systemPrompt: String, appendCodeSwitching: Bool, createdAt: Date, updatedAt: Date }`. |
| `CustomStyleStore` | `Refiner/CustomStyleStore.swift` (protocol) + `CustomStyleStoreLive.swift` + `CustomStyleStoreNoop.swift` | CRUD: `all() async`, `create(name:systemPrompt:appendCodeSwitching:) async throws`, `update(_:) async throws`, `delete(_:) async throws`. Live usa o mesmo `ModelContainer` do `HistoryStoreLive`. Noop devolve lista vazia, silencia writes. |
| `StyleProvider` | `Refiner/StyleProvider.swift` | `@MainActor` ator. Combina `BuiltInStyles.all` + `CustomStyleStore.all()` numa lista única `[Style]` ordenada. Resolve `selectedStyleID` em qualquer um dos dois grupos. Usado pelo submenu da status bar **e** pela `StylesView`. |
| `OllamaModelLister` | `Refiner/OllamaModelLister.swift` | Extende ou compõe sobre `OllamaHealthChecker`: novo método `availableModels() async throws -> [String]` parseando `/api/tags`. Sem cache (refresh manual via botão). |
| `OpenAIEndpoint` | `Refiner/OpenAIEndpoint.swift` | `struct Codable Hashable Sendable { provider: OpenAIProvider, baseURL: URL }`. Persistido como JSON em `UserDefaults` na chave `"com.tagarela.preferences.openAIEndpoint"`. |
| `OpenAIProvider` | mesmo arquivo | `enum String, CaseIterable Codable Sendable { official, openrouter, lmstudio, custom }`. **Azure não é primeira-classe** — usa `.custom` com URL Azure completa (ver §5). |
| `OpenAIEndpointDefaults` | mesmo arquivo | Tabela `[OpenAIProvider: URL]` com baseURLs default por provider. Auto-preenche ao mudar provider. |
| `audit_strings.swift` | `tools/audit_strings.swift` (não-runtime) | Script de apoio: grep nas Views da Fase 1+2a por hardcoded strings, lista candidatos pra audit. Executado uma vez durante a migração. |

### 2.3 Módulos modificados

| Módulo | Mudança |
|---|---|
| `PreferencesStore` | Nova chave `openAIEndpoint` (JSON `OpenAIEndpoint`). Resto inalterado. |
| `PreferencesDefaults` | Novo `openAIEndpoint = OpenAIEndpoint(provider: .official, baseURL: URL("https://api.openai.com/v1")!)`. |
| `OpenAIRefiner` | Construtor passa a aceitar `baseURL: URL`. Hardcoded `https://api.openai.com/v1` removido. Adiciona **guard de tamanho mínimo**: se `rawText.count < 8`, retorna `rawText` direto sem chamar a API (resolve cleanup #3 da 2a). |
| `RefinerFactory` | Closure `openAI` lê `prefs.openAIEndpoint.baseURL` e passa pro construtor. |
| `AppContainer` | Cria `CustomStyleStoreLive` compartilhando o `ModelContainer` do `HistoryStoreLive`. Cria `StyleProvider` injetando ambos. Cria `PreferencesWindow` e adiciona menu item `⌘,`. |
| `StatusBarMenu` (existente) | Submenu Style passa a usar `StyleProvider.all` ao invés de `BuiltInStyles.all`. Custom styles aparecem misturados aos built-ins, ordenados por nome. |
| `BuiltInStyles` | Sem mudança — continua hardcoded com 4 UUIDs estáveis. `defaultStyleID` segue apontando pra `conversaInformal`. |
| Strings em todos os arquivos UI (Fase 1+2a+2b-1) | Migração mecânica pra `String(localized:)` + `Localizable.xcstrings` (~150-300 strings). |

### 2.4 Container SwiftData

```
ModelContainer
 ├─ Transcription   (Fase 2a — history)
 └─ CustomStyle     (Fase 2b-1 — novo)
```

Construído uma única vez no `AppContainer.init`. Falha → ambos os stores caem em Noop. Mesma URL de Application Support.

---

## 3. Data flow e pontos críticos

### 3.1 Boot

`AppContainer.init` cria o `ModelContainer` único. Tanto `HistoryStoreLive` quanto `CustomStyleStoreLive` recebem o mesmo container. Falha do container → ambos caem em Noop e a UI mostra cards built-in apenas (custom invisíveis, "+ Novo" desabilitado com tooltip "armazenamento indisponível"). `PreferencesWindow` é instanciado mas não exibido. Menu `Tagarela > Preferências…` é registrado com `⌘,`.

### 3.2 Status bar Style submenu

```
StatusBarMenu builds Style submenu
  └─ StyleProvider.all() async
       ├─ BuiltInStyles.all (4)
       └─ CustomStyleStore.all() (n)
  └─ items renderizados ordenados por nome (case-insensitive)
  └─ check pelo prefs.selectedStyleID
```

Custom styles e built-ins aparecem **misturados** (sem grupo) — distinção visual fica só na tela de Preferências.

### 3.3 Pipeline runtime (sem mudança estrutural)

`PipelineCoordinator.runTranscribeAndInject` segue chamando `refinerProvider()` que retorna `(refiner, style)`. A novidade é que o `RefinerFactory` lê `prefs.selectedStyleID` e resolve via `StyleProvider` (que pode retornar built-in **ou** custom). O refiner não distingue origem do style — é só `Style`.

### 3.4 Tela "Estilos" — fluxo CRUD

1. **Abrir**: `StylesView` observa `CustomStyleStore` via `@Published` exposto pelo protocolo (não `@Query` direto — preserva testabilidade pelo seam do protocolo). Renderiza grid: 4 built-in cards (badge "PRONTO", read-only) + N custom cards (botão ✎) + 1 card dashed "+ Novo".
2. **+ Novo**: abre `CustomStyleEditSheet` em modo create. Form: `name` (TextField, required, non-empty), `systemPrompt` (TextEditor, required, 5-30 linhas), `appendCodeSwitching` (Toggle, default true). Botões "Cancelar" / "Salvar". Save → `CustomStyleStore.create(...)` → SwiftData persist → `@Query` atualiza grid.
3. **✎ Editar** (custom apenas): abre o **mesmo** sheet pré-preenchido em modo update. Save → `CustomStyleStore.update(_:)`.
4. **Apagar**: contextual menu sobre card custom. Confirm via `NSAlert` ("Apagar 'commits git'? Esta ação não pode ser desfeita."). Se o style apagado é o `prefs.selectedStyleID` atual → `CustomStyleStoreLive.delete` reseta `prefs.selectedStyleID = BuiltInStyles.defaultStyleID` antes de remover do contexto.

**Edge:** custom style com nome igual a um built-in é permitido (UUID disambigua). Submenu da status bar mostra ambos com mesmo label — limitação aceita; resolve em fase futura se virar problema.

**Falha de save (SwiftData):** `NSAlert` bloqueante "Não foi possível salvar o estilo. Detalhes: \(error)". Toasts não-bloqueantes só na 2b-2.

### 3.5 Tela "Refiner > Ollama" — model picker dinâmico

1. View aparece → `OllamaModelLister.availableModels()` dispara em `.task { }`.
2. Enquanto carrega: `Picker` desabilitado, label "Carregando lista…".
3. Sucesso (lista parsed de `/api/tags`): `Picker` habilitado com itens; valor atual `prefs.ollamaModel` selecionado se presente; se não, primeiro item **e** o `prefs.ollamaModel` atual aparece como item extra "(não instalado: gemma4:e4b)" pra preservar a escolha do user.
4. Erro (Ollama offline): banner amarelo "Ollama offline. Digite o nome manualmente." + `TextField` editável. `prefs.ollamaModel` salva o que o user digitar.
5. Botão "Atualizar" re-dispara o lister.

### 3.6 Tela "Refiner > OpenAI" — endpoints custom

1. Bloco "Provider": `Picker` segmented com `OpenAIProvider.allCases` rotulados (oficial / OpenRouter / LM Studio / URL custom). Mudar → atualiza `prefs.openAIEndpoint.provider` **e** auto-preenche `prefs.openAIEndpoint.baseURL` com o default da tabela (user pode editar depois).
2. Bloco "Base URL": `TextField` editável. Validação de URL ao perder foco (regex `^https?://...`). Default vem de `OpenAIEndpointDefaults`.
3. Bloco "Modelo": `TextField` (free text — variedade de modelos por provider torna combobox inviável).
4. Bloco "API key": label `"••••••••3a4f"` (últimos 4 chars **do próprio valor da key** lidos do keychain — padrão da indústria pra display de keys masked) ou `"Não configurada"`. Botão "Alterar…" abre o `OpenAIKeyPromptWindow` existente sem mudanças.
5. Mudança de `openAIEndpoint` não invalida `OllamaHealthChecker` (são endpoints distintos); `RefinerFactory` recria o `OpenAIRefiner` na próxima chamada com a nova URL.

### 3.7 Localizable migration

- `Localizable.xcstrings` (formato moderno do Xcode 15+, JSON-based) já existe da 2a.
- Migração mecânica: cada `Text("foo")`, `Button("foo")`, `String literal user-facing` vira `String(localized: "section.subsection.key", defaultValue: "foo")`.
- Chaves seguem padrão `<section>.<subsection>.<purpose>` (ex: `preferences.refiner.openai.title`, `pipeline.error.fallback`).
- pt-BR é base/source; sem traduções na 2b-1.
- Output do script `tools/audit_strings.swift` (mencionado em §2.2) lista candidatos pra audit manual.

### 3.8 Window persistence

`PreferencesWindow` usa `NSWindow.setFrameAutosaveName("PreferencesWindow")` — tamanho e posição persistem via `UserDefaults` automaticamente. Default: 720×520. Min: 600×400.

### 3.9 Menubar `⌘,`

Wire via `.commands { CommandGroup(replacing: .appSettings) { Button("Preferências…") { … } .keyboardShortcut(",") } }` no `TagarelaApp`. Substitui o item gerado pelo SwiftUI `Settings` scene (que não usaríamos por causa do layout sidebar+detail custom).

---

## 4. Estratégia de testes

### 4.1 Princípio (herdado da 2a)

XCTest puro, sem dependência de UI test runner. Toda lógica testável passa por seams (`MockURLProtocol`, in-memory `ModelContainer`, fakes de protocolos). Views SwiftUI **não** são unit-tested — verificadas no checklist manual.

### 4.2 Testes novos esperados (~25-35)

| Suite | Cobertura | Estimativa |
|---|---|---|
| `CustomStyleTests` | `@Model CustomStyle` codable/queryable, defaults | 3-4 |
| `CustomStyleStoreTests` | create/update/delete; delete do styleID atual reseta `prefs.selectedStyleID`; Noop devolve lista vazia | 6-8 |
| `StyleProviderTests` | merge built-in+custom, ordenação, lookup por UUID, fallback quando UUID não existe | 4-5 |
| `OllamaModelListerTests` | parse de `/api/tags`, lista vazia, malformed, offline throws | 4-5 |
| `OpenAIEndpointTests` | Codable round-trip, defaults por provider, URL validation | 3-4 |
| `OpenAIRefinerTests` (extensão) | guard de raw curto (<8 chars retorna sem chamar API), baseURL custom é usada na request | 2-3 |
| `RefinerFactoryTests` (extensão) | factory injeta `prefs.openAIEndpoint.baseURL` no OpenAIRefiner | 1-2 |
| `PreferencesStoreTests` (extensão) | `openAIEndpoint` Codable persistence; default match | 2-3 |
| `LocalizableKeysTests` | smoke: chaves principais de `Localizable.xcstrings` resolvem em pt-BR | 1-2 |

**Total ~26-36 testes novos.** Soma com os 81 atuais → ~107-117. Critério: tudo verde antes de fechar a fase.

### 4.3 Não testado em XCTest (cobertura via checklist manual)

- Layout `NavigationSplitView`, `⌘,` abrindo a janela, menu item visível.
- Animação/refresh de cards na `StylesView`.
- `OpenAIKeyPromptWindow` reabrindo a partir do botão "Alterar…".
- Persistência de tamanho/posição da janela entre sessões.
- Submenu da status bar listando custom + built-in misturados, check correto no selecionado.
- Migração Localizable: smoke visual (todas as labels aparecem, nada quebrou).
- Custom style criado é selecionável imediatamente no submenu da status bar (sem reiniciar).

Checklist manual fica em `tagarela_docs/03-funcionalidades/checklists/fase2b1-manual.md` — criado junto da implementação (regra inviolável 2 do CLAUDE.md).

### 4.4 Testes de regressão (rodar antes/depois)

Suíte completa da 2a deve continuar verde. Em particular:
- `PreferencesStoreTests.test_defaults_match_designV1` — atualizar pra incluir `openAIEndpoint`.
- `OpenAIRefinerTests.*` — adaptar pra novo construtor com `baseURL`.
- `RefinerFactoryTests.*` — adaptar pra injetar endpoint.

---

## 5. Limitações conhecidas e débitos abertos

Documentados explicitamente pra evitar surpresa no aceite manual:

1. **Azure OpenAI** não é primeira-classe na 2b-1. User configura via "URL custom" colando a URL completa de chat completions Azure (`{endpoint}/openai/deployments/{deployment}/chat/completions?api-version=...`). Frágil mas evita lógica condicional Azure-específica nesta fase. Se virar dor real, vira sub-fase própria com fields de deployment/api-version.
2. **Modelo OpenAI free-text** — sem combobox curado (variedade de modelos é grande demais). Validação só na próxima inferência (`model_not_found` 404).
3. **Hotkey re-bind** continua não-implementado. Aba Atalhos é read-only display.
4. **Toast / banner de erro** ao salvar custom style: usa `NSAlert` bloqueante (toasts entram na 2b-2). UX menos polida temporariamente.
5. **Cleanup #5 da 2a** (cancel HTTP real) **não** entra aqui — fica pra 2b-3.
6. **Cleanup #2 da 2a** (fallback Identity surfaceiado no UI) **não** entra aqui — depende de toasts da 2b-2.
7. **Custom styles importáveis/exportáveis** (JSON) — fora de escopo. SwiftData nativa não tem export pronto. Se virar feature pedida, vira sub-fase.
8. **Edição em batch / drag-drop reorder** dos custom styles — fora de escopo. CRUD um-por-vez.

---

## 6. Roadmap pós-2b-1

- **2b-2** — Histórico visível + Indicadores B/C/D + Toasts + Estados de permissão + Cleanup #2.
- **2b-3** — Onboarding completo + Re-bind hotkey + Cleanup #5 + Tuning fino dos prompts.
- **3** (futuro) — features extras do design v1 ainda não destrinchadas (multi-idioma, profiles, backups, etc).
