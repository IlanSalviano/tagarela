---
data: 2026-04-29
status: pronto pra execução
fase: 2b-1 de 3 sub-fases da Fase 2b
goal: janela de Preferências completa, CRUD de custom styles, endpoints custom OpenAI, migração total para Localizable
---

# tagarela v1 — Fase 2b-1: Implementation Plan

> **Para agentes de execução:** SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendado) ou `superpowers:executing-plans`. Tarefas usam checkbox (`- [ ]`).
>
> **Antes de qualquer tarefa:** ler [`/CLAUDE.md`](../../CLAUDE.md), [`tagarela_docs/specs/2026-04-29-tagarela-v1-fase2b1-design.md`](./2026-04-29-tagarela-v1-fase2b1-design.md), [`tagarela_docs/04-decisoes/cleanup-fase2a.md`](../04-decisoes/cleanup-fase2a.md). **Antes de marcar uma tarefa como concluída:** atualizar a doc afetada (regra inviolável 2 do CLAUDE.md).

**Goal:** Implementar janela de Preferências completa (`NavigationSplitView` sidebar+detail com 7 seções), CRUD de custom styles (SwiftData), endpoints custom OpenAI (provider picker + URL), modelo Ollama com scan dinâmico, e migrar todas strings user-facing das Fases 1+2a+2b-1 pra `Localizable.xcstrings`. Cleanup #3 da 2a (guard de raw curto no OpenAI) entra como bônus barato.

**Architecture:** Sobre a 2a, adicionar (a) `OpenAIEndpoint` no `PreferencesStore`, (b) `OpenAIRefiner` parametrizado por `baseURL` + guard de raw curto, (c) `OllamaModelLister` reusando `OllamaHealthChecker`, (d) `@Model CustomStyle` + `CustomStyleStore` (mesmo `ModelContainer` do `HistoryStore`), (e) `StyleProvider` mesclando built-ins + custom, (f) `PreferencesWindow` SwiftUI segurando 9 sub-views (Geral, Refiner > Geral/Ollama/OpenAI, Estilos, Áudio, Histórico, Vocabulário, Atalhos), (g) sweep mecânico de strings pra `String(localized:)`.

**Tech stack:** mesmo da 2a — Swift 5.10, SwiftUI, SwiftData, AppKit cirúrgico, URLSession, XCTest. Sem novas SPMs.

**Não está nesta fase:** visualizador de histórico, menu "últimos 5", indicadores B/C/D, toasts, estados de permissão no menu, onboarding novo, re-bind hotkey, cleanups #2 e #5 da 2a. Ver [`fase2b1-design.md` §1.3](./2026-04-29-tagarela-v1-fase2b1-design.md#13-não-objetivos-da-2b-1).

---

## File structure desta fase

Adições/modificações sobre Fase 2a (raiz `app/Tagarela/`):

```
app/Tagarela/
├── Preferences/
│   ├── PreferencesStore.swift              # MODIFICAR — @Published openAIEndpoint
│   ├── Preferences+Defaults.swift          # MODIFICAR — chave + default
│   └── UI/                                 # NOVO — todo o SwiftUI da janela
│       ├── PrefsSection.swift              # NOVO — enum hierárquico
│       ├── PreferencesRoot.swift           # NOVO — NavigationSplitView
│       └── Sections/
│           ├── GeneralView.swift           # NOVO
│           ├── RefinerGeneralView.swift    # NOVO
│           ├── RefinerOllamaView.swift     # NOVO
│           ├── RefinerOpenAIView.swift     # NOVO
│           ├── StylesView.swift            # NOVO — cards grid
│           ├── AudioView.swift             # NOVO
│           ├── HistoryView.swift           # NOVO
│           ├── VocabularyView.swift        # NOVO
│           └── ShortcutsView.swift         # NOVO — read-only
│       └── Sheets/
│           └── CustomStyleEditSheet.swift  # NOVO — modal CRUD
├── Refiner/
│   ├── OpenAIEndpoint.swift                # NOVO — struct + enum provider
│   ├── OpenAIRefiner.swift                 # MODIFICAR — baseURL injetado + guard raw curto
│   ├── RefinerFactory.swift                # MODIFICAR — passa baseURL + usa StyleProvider
│   ├── OllamaModelLister.swift             # NOVO — list /api/tags
│   ├── CustomStyle.swift                   # NOVO — @Model
│   ├── CustomStyleStore.swift              # NOVO — protocol
│   ├── CustomStyleStoreLive.swift          # NOVO — SwiftData impl
│   ├── CustomStyleStoreNoop.swift          # NOVO — fallback
│   └── StyleProvider.swift                 # NOVO — merge built-in + custom
├── App/
│   ├── AppContainer.swift                  # MODIFICAR — share ModelContainer; PreferencesWindow
│   ├── PreferencesWindow.swift             # NOVO — NSWindowController + autosave
│   └── TagarelaApp.swift                   # MODIFICAR — .commands replacing .appSettings
├── History/
│   └── HistoryStoreLive.swift              # MODIFICAR — aceitar ModelContainer injetado
├── UI/
│   └── MenuBar/
│       └── StyleSubmenu.swift              # MODIFICAR — usar StyleProvider
└── Resources/
    └── Localizable.xcstrings               # MODIFICAR — chaves novas + migração total

tools/
└── audit_strings.swift                     # NOVO — script one-shot de audit

app/TagarelaTests/
├── OpenAIEndpointTests.swift               # NOVO
├── OpenAIRefinerTests.swift                # MODIFICAR — baseURL + guard raw
├── OllamaModelListerTests.swift            # NOVO
├── CustomStyleTests.swift                  # NOVO
├── CustomStyleStoreTests.swift             # NOVO
├── StyleProviderTests.swift                # NOVO
├── RefinerFactoryTests.swift               # MODIFICAR — endpoint
├── PreferencesStoreTests.swift             # MODIFICAR — openAIEndpoint
└── LocalizableKeysTests.swift              # NOVO
```

Documentação atualizada por esta fase em `tagarela_docs/`:
- `02-arquitetura/` — adicionar/atualizar snapshot de módulos pós-2b-1.
- `03-funcionalidades/checklists/fase2b1-manual.md` (criar) — checklist manual de aceite.
- `04-decisoes/cleanup-fase2a.md` — fechar item #3.
- `README.md` — ajustar status da 2b-1 quando fechar.

---

## Convenções desta fase

Mesmas da 2a:

- **Idioma:** strings de UI em `Localizable.xcstrings` (pt-BR base, sem traduções na 2b-1). Identificadores Swift em inglês.
- **Concorrência:** `actor` ou `@MainActor` pra estado mutável. SwiftData `@Model` é main-actor por padrão.
- **Erros:** cada módulo expõe `enum {Modulo}Error: Error` quando precisa.
- **Logging:** `Logger(subsystem: "com.tagarela", category: <nome>)`. Nada de `FileHandle.standardError.write` (eliminado no fechamento do cleanup #4 da 2a).
- **Sem dados sensíveis em log:** nada de API key, texto cru, texto refinado.
- **TDD:** lógica pura → teste primeiro. UI/SwiftUI → preview + checklist manual.
- **Commits:** um commit por tarefa (ou alguns commits relacionados), em pt-BR no estilo `tipo(escopo): descrição` + `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.
- **xcodegen é a fonte da verdade do projeto Xcode.** Após criar/mover arquivos, sempre rodar `xcodegen generate` em `/Users/tars/Dev/tagarela/app/`.

---

## Pre-flight (antes da Tarefa 1)

- [ ] **Confirmar `main` está limpo e em verde.**

```bash
cd /Users/tars/Dev/tagarela
git status                                      # working tree clean (workspace.json Obsidian é OK ficar M)
git log -1 --oneline                            # último: 621c3b8 docs(spec): aprovar design da Fase 2b-1
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: `** TEST SUCCEEDED **`, 81 testes passando.

- [ ] **Criar branch de trabalho.**

```bash
cd /Users/tars/Dev/tagarela
git checkout -b fase-2b1
```

- [ ] **Verificar Ollama rodando localmente** (necessário pro aceite manual da Tarefa 9).

```bash
curl -sf http://localhost:11434/api/tags | head -c 200
ollama list | grep -E "gemma4:e4b|llama3" | head -3
```

Se Ollama offline: pull antes de seguir, ou marcar checklist manual da T9 como pendente.

---

## Tarefa 1: `OpenAIEndpoint` + `PreferencesStore` extension

**Files:**
- Create: `app/Tagarela/Refiner/OpenAIEndpoint.swift`
- Create: `app/TagarelaTests/OpenAIEndpointTests.swift`
- Modify: `app/Tagarela/Preferences/Preferences+Defaults.swift` (chave + default)
- Modify: `app/Tagarela/Preferences/PreferencesStore.swift` (@Published)
- Modify: `app/TagarelaTests/PreferencesStoreTests.swift` (asserts novos)

- [ ] **Step 1: Escrever `OpenAIEndpoint.swift` com struct, enum, e defaults table**

```swift
// app/Tagarela/Refiner/OpenAIEndpoint.swift
import Foundation

enum OpenAIProvider: String, Codable, CaseIterable, Sendable {
    case official
    case openrouter
    case lmstudio
    case custom
}

struct OpenAIEndpoint: Codable, Hashable, Sendable {
    var provider: OpenAIProvider
    var baseURL: URL
}

enum OpenAIEndpointDefaults {
    /// Default baseURL pra cada provider. .custom retorna nil (user define).
    static func defaultURL(for provider: OpenAIProvider) -> URL? {
        switch provider {
        case .official:   return URL(string: "https://api.openai.com/v1")
        case .openrouter: return URL(string: "https://openrouter.ai/api/v1")
        case .lmstudio:   return URL(string: "http://localhost:1234/v1")
        case .custom:     return nil
        }
    }
}
```

- [ ] **Step 2: Adicionar chave + default em `Preferences+Defaults.swift`**

Edit `app/Tagarela/Preferences/Preferences+Defaults.swift`:
- Em `enum PreferencesKey`, adicionar:

```swift
static let openAIEndpoint = "com.tagarela.preferences.openAIEndpoint"
```

- Em `enum PreferencesDefaults`, adicionar:

```swift
static let openAIEndpoint: OpenAIEndpoint = OpenAIEndpoint(
    provider: .official,
    baseURL: URL(string: "https://api.openai.com/v1")!)
```

- [ ] **Step 3: Adicionar `@Published openAIEndpoint` no `PreferencesStore`**

Edit `app/Tagarela/Preferences/PreferencesStore.swift`:

Após o último `@Published` adicionar:

```swift
@Published var openAIEndpoint: OpenAIEndpoint {
    didSet {
        if let data = try? JSONEncoder().encode(openAIEndpoint) {
            defaults.set(data, forKey: PreferencesKey.openAIEndpoint)
        }
    }
}
```

No `init`, após o bloco do `audioBoostMaxGain` adicionar:

```swift
if let data = defaults.data(forKey: PreferencesKey.openAIEndpoint),
   let decoded = try? JSONDecoder().decode(OpenAIEndpoint.self, from: data) {
    self.openAIEndpoint = decoded
} else {
    self.openAIEndpoint = PreferencesDefaults.openAIEndpoint
}
```

- [ ] **Step 4: Escrever testes em `OpenAIEndpointTests.swift`**

```swift
// app/TagarelaTests/OpenAIEndpointTests.swift
import XCTest
@testable import Tagarela

final class OpenAIEndpointTests: XCTestCase {
    func test_codableRoundTrip() throws {
        let original = OpenAIEndpoint(provider: .openrouter,
                                       baseURL: URL(string: "https://openrouter.ai/api/v1")!)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIEndpoint.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_defaultURL_forEachProvider_matchesExpected() {
        XCTAssertEqual(OpenAIEndpointDefaults.defaultURL(for: .official),
                       URL(string: "https://api.openai.com/v1"))
        XCTAssertEqual(OpenAIEndpointDefaults.defaultURL(for: .openrouter),
                       URL(string: "https://openrouter.ai/api/v1"))
        XCTAssertEqual(OpenAIEndpointDefaults.defaultURL(for: .lmstudio),
                       URL(string: "http://localhost:1234/v1"))
        XCTAssertNil(OpenAIEndpointDefaults.defaultURL(for: .custom))
    }

    func test_allProvidersAreCaseIterable() {
        XCTAssertEqual(OpenAIProvider.allCases.count, 4)
    }
}
```

- [ ] **Step 5: Estender `PreferencesStoreTests`**

Edit `app/TagarelaTests/PreferencesStoreTests.swift`:

No `test_defaults_match_designV1`, adicionar antes do final do método:

```swift
XCTAssertEqual(store.openAIEndpoint, PreferencesDefaults.openAIEndpoint)
```

Adicionar novo teste de persistência:

```swift
func test_setOpenAIEndpoint_persistsAcrossInit() {
    let endpoint = OpenAIEndpoint(provider: .lmstudio,
                                   baseURL: URL(string: "http://localhost:1234/v1")!)
    let s1 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
    s1.openAIEndpoint = endpoint
    let s2 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
    XCTAssertEqual(s2.openAIEndpoint, endpoint)
}
```

- [ ] **Step 6: Regenerar projeto Xcode + rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -10
```

Esperado: `** TEST SUCCEEDED **`, ~84 testes (81 + 3 novos).

- [ ] **Step 7: Commit**

```bash
git add app/Tagarela/Refiner/OpenAIEndpoint.swift app/Tagarela/Preferences/Preferences+Defaults.swift app/Tagarela/Preferences/PreferencesStore.swift app/TagarelaTests/OpenAIEndpointTests.swift app/TagarelaTests/PreferencesStoreTests.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(preferences): adicionar OpenAIEndpoint pra suportar providers custom

- struct OpenAIEndpoint (provider + baseURL) Codable/Hashable
- enum OpenAIProvider (official/openrouter/lmstudio/custom)
- OpenAIEndpointDefaults com baseURL default por provider
- chave em PreferencesStore + default OpenAI oficial
- 3 testes novos do struct + 2 no PreferencesStoreTests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: `OpenAIRefiner` — `baseURL` injetado + guard de raw curto (cleanup #3 da 2a)

**Files:**
- Modify: `app/Tagarela/Refiner/OpenAIRefiner.swift`
- Modify: `app/Tagarela/Refiner/RefinerFactory.swift`
- Modify: `app/Tagarela/App/AppContainer.swift`
- Modify: `app/TagarelaTests/OpenAIRefinerTests.swift`
- Modify: `app/TagarelaTests/RefinerFactoryTests.swift`

- [ ] **Step 1: Atualizar `OpenAIRefiner` pra aceitar `baseURL` injetado**

Edit `app/Tagarela/Refiner/OpenAIRefiner.swift`:

Trocar `private let baseURL = URL(...)!` por field não-default:

```swift
private let baseURL: URL
```

Atualizar init:

```swift
init(session: URLSession, keychain: KeychainService, baseURL: URL,
     model: String, timeoutSec: TimeInterval) {
    self.session = session
    self.keychain = keychain
    self.baseURL = baseURL
    self.model = model
    self.timeoutSec = timeoutSec
}
```

- [ ] **Step 2: Adicionar guard de raw curto no `refine`**

No início do método `refine(_:style:)`, antes de `let storedKey = ...`, adicionar:

```swift
// Guard de raw curto: evita LLM responder conversacionalmente quando o input
// é vazio ou quase vazio (cleanup #3 da Fase 2a). 8 chars é heurística simples
// que deixa passar "ola" mas barra "" e " ".
let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
if trimmed.count < 8 {
    logger.info("raw curto (\(trimmed.count, privacy: .public) chars), skip refine")
    return rawText
}
```

- [ ] **Step 3: Atualizar `RefinerFactory` pra passar `baseURL` do prefs**

Edit `app/Tagarela/Refiner/RefinerFactory.swift` — sem mudanças no `Factory` propriamente; é o `AppContainer` que constrói a closure. Pular pra Step 4.

- [ ] **Step 4: Atualizar a closure no `AppContainer`**

Edit `app/Tagarela/App/AppContainer.swift`:

Na closure `openAI` do `RefinerFactory(...)`, trocar por:

```swift
openAI: { [weak prefs, keychain] in
    guard let prefs else { fatalError("prefs deallocated") }
    return OpenAIRefiner(session: session,
                         keychain: keychain,
                         baseURL: prefs.openAIEndpoint.baseURL,
                         model: prefs.openAIModel,
                         timeoutSec: prefs.refinerTimeoutSec)
},
```

- [ ] **Step 5: Atualizar `OpenAIRefinerTests` pra construir com `baseURL` + adicionar testes do guard**

Edit `app/TagarelaTests/OpenAIRefinerTests.swift`:

Onde quer que `OpenAIRefiner(...)` é instanciado nos helpers, adicionar `baseURL: baseURL`. Exemplo do helper típico:

```swift
private func makeRefiner() -> OpenAIRefiner {
    let session = MockURLProtocol.session()
    return OpenAIRefiner(session: session,
                         keychain: FakeKeychain(),
                         baseURL: URL(string: "https://api.openai.com/v1")!,
                         model: "gpt-5.4-mini",
                         timeoutSec: 30)
}
```

Adicionar testes novos no fim da classe:

```swift
func test_rawCurto_skipRefineSemChamarAPI() async throws {
    nonisolated(unsafe) var apiCalled = false
    MockURLProtocol.responder = { _ in
        apiCalled = true
        return (HTTPURLResponse(url: URL(string:"https://x")!, statusCode: 200,
                                httpVersion: nil, headerFields: nil)!,
                Data(#"{"choices":[{"message":{"content":"refinado"}}]}"#.utf8))
    }
    let r = makeRefiner()
    let out = try await r.refine("ola", style: BuiltInStyles.conversaInformal)
    XCTAssertEqual(out, "ola")
    XCTAssertFalse(apiCalled, "API foi chamada com raw curto — guard quebrou")
}

func test_rawNormal_chamaAPI() async throws {
    nonisolated(unsafe) var apiCalled = false
    MockURLProtocol.responder = { _ in
        apiCalled = true
        return (HTTPURLResponse(url: URL(string:"https://x")!, statusCode: 200,
                                httpVersion: nil, headerFields: nil)!,
                Data(#"{"choices":[{"message":{"content":"refinado"}}]}"#.utf8))
    }
    let r = makeRefiner()
    let out = try await r.refine("isso é um texto longo o suficiente", style: BuiltInStyles.conversaInformal)
    XCTAssertEqual(out, "refinado")
    XCTAssertTrue(apiCalled)
}

func test_baseURL_customIsUsedInRequest() async throws {
    nonisolated(unsafe) var capturedURL: URL?
    MockURLProtocol.responder = { req in
        capturedURL = req.url
        return (HTTPURLResponse(url: req.url!, statusCode: 200,
                                httpVersion: nil, headerFields: nil)!,
                Data(#"{"choices":[{"message":{"content":"r"}}]}"#.utf8))
    }
    let session = MockURLProtocol.session()
    let r = OpenAIRefiner(session: session, keychain: FakeKeychain(),
                          baseURL: URL(string: "http://localhost:1234/v1")!,
                          model: "x", timeoutSec: 30)
    _ = try await r.refine("texto suficientemente longo", style: BuiltInStyles.conversaInformal)
    XCTAssertEqual(capturedURL?.absoluteString, "http://localhost:1234/v1/chat/completions")
}
```

(Se `FakeKeychain` não existe na suite, criar inline um stub que retorna uma key qualquer — ou usar o helper já existente; auditar `OpenAIRefinerTests.swift` antes pra ver o padrão.)

- [ ] **Step 6: Atualizar `RefinerFactoryTests`**

Edit `app/TagarelaTests/RefinerFactoryTests.swift`: nos helpers que constroem o factory, garantir que a closure `openAI` recebe `baseURL` do prefs. Adicionar teste:

```swift
func test_factory_passesBaseURLFromPrefs_toOpenAIRefiner() async {
    let prefs = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
    prefs.openAIEndpoint = OpenAIEndpoint(
        provider: .lmstudio,
        baseURL: URL(string: "http://localhost:1234/v1")!)
    nonisolated(unsafe) var seenBaseURL: URL?
    let factory = RefinerFactory(
        prefs: prefs,
        openAI: { [weak prefs] in
            guard let prefs else { fatalError() }
            seenBaseURL = prefs.openAIEndpoint.baseURL
            return OpenAIRefiner(session: .shared, keychain: FakeKeychain(),
                                 baseURL: prefs.openAIEndpoint.baseURL,
                                 model: "x", timeoutSec: 30)
        },
        ollama: { fatalError("não chamado") })
    prefs.refinerKind = .openai
    _ = factory.current()
    XCTAssertEqual(seenBaseURL, URL(string: "http://localhost:1234/v1"))
}
```

- [ ] **Step 7: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, +3-4 testes (~88).

- [ ] **Step 8: Commit + atualizar cleanup-fase2a.md marcando #3 como fechado**

Edit `tagarela_docs/04-decisoes/cleanup-fase2a.md`:
- Trocar título da seção `## 3. OpenAI responde conversacionalmente quando raw é muito curto` por `## 3. OpenAI responde conversacionalmente quando raw é muito curto — ✅ FECHADO 2026-04-XX`.
- Adicionar bloco "Fix aplicado:" descrevendo o guard de 8 chars no `OpenAIRefiner.refine`.
- Atualizar campo `status:` no frontmatter (ainda permanece "parcialmente fechado" enquanto #2 e #5 ficam abertos).

```bash
git add app/Tagarela/Refiner/OpenAIRefiner.swift app/Tagarela/App/AppContainer.swift app/TagarelaTests/OpenAIRefinerTests.swift app/TagarelaTests/RefinerFactoryTests.swift tagarela_docs/04-decisoes/cleanup-fase2a.md
git commit -m "$(cat <<'EOF'
feat(refiner): OpenAIRefiner aceita baseURL + guard de raw curto

- baseURL deixa de ser hardcoded; vem do PreferencesStore.openAIEndpoint
- guard: raw < 8 chars (após trim) retorna direto sem chamar a API
  (resolve cleanup #3 da Fase 2a — OpenAI conversacional em raw curto)
- AppContainer atualizado pra injetar baseURL do prefs
- 3 testes novos no OpenAIRefinerTests + 1 no RefinerFactoryTests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: `OllamaModelLister`

**Files:**
- Create: `app/Tagarela/Refiner/OllamaModelLister.swift`
- Create: `app/TagarelaTests/OllamaModelListerTests.swift`

- [ ] **Step 1: Escrever teste failing primeiro**

```swift
// app/TagarelaTests/OllamaModelListerTests.swift
import XCTest
@testable import Tagarela

final class OllamaModelListerTests: XCTestCase {
    override func setUp() async throws { MockURLProtocol.responder = nil }
    override func tearDown() async throws { MockURLProtocol.responder = nil }

    private let baseURL = URL(string: "http://localhost:11434")!

    private func makeLister() -> OllamaModelLister {
        OllamaModelLister(session: MockURLProtocol.session(), baseURL: baseURL)
    }

    private func tagsBody(_ models: [String]) -> Data {
        let json: [String: Any] = [
            "models": models.map { ["name": $0, "modified_at": "2026-04-01T00:00:00Z"] }
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    func test_parseHappy_returnsModelNames() async throws {
        MockURLProtocol.responder = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             self.tagsBody(["gemma4:e4b", "llama3.2:3b"]))
        }
        let lister = makeLister()
        let names = try await lister.availableModels()
        XCTAssertEqual(names, ["gemma4:e4b", "llama3.2:3b"])
    }

    func test_emptyList_returnsEmpty() async throws {
        MockURLProtocol.responder = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             self.tagsBody([]))
        }
        let lister = makeLister()
        let names = try await lister.availableModels()
        XCTAssertEqual(names, [])
    }

    func test_malformed_throwsMalformed() async {
        MockURLProtocol.responder = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data("not json".utf8))
        }
        let lister = makeLister()
        do {
            _ = try await lister.availableModels()
            XCTFail("expected throw")
        } catch let e as OllamaModelListerError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_offline_throwsOffline() async {
        MockURLProtocol.responder = { _ in throw URLError(.cannotConnectToHost) }
        let lister = makeLister()
        do {
            _ = try await lister.availableModels()
            XCTFail("expected throw")
        } catch let e as OllamaModelListerError {
            XCTAssertEqual(e, .offline)
        } catch { XCTFail("wrong error: \(error)") }
    }
}
```

- [ ] **Step 2: Rodar pra ver os testes falhando**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -10
```

Esperado: erro de compilação — `OllamaModelLister` não existe.

- [ ] **Step 3: Implementar `OllamaModelLister`**

```swift
// app/Tagarela/Refiner/OllamaModelLister.swift
import Foundation

enum OllamaModelListerError: Error, Equatable {
    case offline
    case malformedResponse
}

actor OllamaModelLister {
    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Lista nomes de modelos pulled localmente via GET /api/tags.
    /// Sem cache — refresh é responsabilidade do caller.
    func availableModels() async throws -> [String] {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        req.timeoutInterval = 4
        req.httpMethod = "GET"
        let data: Data
        do {
            (data, _) = try await session.data(for: req)
        } catch {
            throw OllamaModelListerError.offline
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["models"] as? [[String: Any]]
        else { throw OllamaModelListerError.malformedResponse }
        return arr.compactMap { $0["name"] as? String }
    }
}
```

- [ ] **Step 4: Re-gerar projeto + rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, +4 testes (~92).

- [ ] **Step 5: Commit**

```bash
git add app/Tagarela/Refiner/OllamaModelLister.swift app/TagarelaTests/OllamaModelListerTests.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(ollama): adicionar OllamaModelLister pra scan dinâmico de /api/tags

Reusa o mesmo endpoint do OllamaHealthChecker mas devolve a lista
parsed de modelos pulled. Sem cache — refresh é manual via botão na UI.
4 testes (happy, empty, malformed, offline).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: `CustomStyle` + `CustomStyleStore` + share `ModelContainer`

**Files:**
- Create: `app/Tagarela/Refiner/CustomStyle.swift`
- Create: `app/Tagarela/Refiner/CustomStyleStore.swift` (protocol)
- Create: `app/Tagarela/Refiner/CustomStyleStoreLive.swift`
- Create: `app/Tagarela/Refiner/CustomStyleStoreNoop.swift`
- Modify: `app/Tagarela/History/HistoryStoreLive.swift` (init recebe `ModelContainer` opcional)
- Modify: `app/Tagarela/App/AppContainer.swift` (cria container compartilhado)
- Create: `app/TagarelaTests/CustomStyleTests.swift`
- Create: `app/TagarelaTests/CustomStyleStoreTests.swift`

- [x] **Step 1: Definir `@Model CustomStyle`**

```swift
// app/Tagarela/Refiner/CustomStyle.swift
import Foundation
import SwiftData

@Model
final class CustomStyle {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemPrompt: String
    var appendCodeSwitching: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         name: String,
         systemPrompt: String,
         appendCodeSwitching: Bool,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.appendCodeSwitching = appendCodeSwitching
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Converte o `CustomStyle` num `Style` consumível pelo `RefinerFactory`/refiners.
    /// Cláusula de code-switching é anexada igual aos built-ins (BuiltInStyles).
    func asStyle() -> Style {
        let codeSwitchingClause = """

        Preserve termos técnicos em inglês conforme o uso comum em desenvolvimento de software brasileiro \
        (ex: cloud, deploy, pool, pattern, mutex). Corrija fonetizações óbvias do Whisper \
        (ex: 'loquei' → 'log it', 'diploiei' → 'deployei').
        """
        let prompt = appendCodeSwitching ? systemPrompt + codeSwitchingClause : systemPrompt
        return Style(id: id,
                     name: name,
                     systemPrompt: prompt,
                     preserveOrality: false,
                     isBuiltIn: false)
    }
}
```

- [x] **Step 2: Definir protocolo `CustomStyleStore`**

```swift
// app/Tagarela/Refiner/CustomStyleStore.swift
import Foundation

@MainActor
protocol CustomStyleStore: AnyObject {
    var styles: [CustomStyle] { get }
    func reload() async
    func create(name: String, systemPrompt: String, appendCodeSwitching: Bool) async throws -> CustomStyle
    func update(_ style: CustomStyle) async throws
    func delete(_ style: CustomStyle) async throws
}

/// Callback chamado pelo store após `delete`, com o UUID do style apagado.
/// O caller (AppContainer) decide se o ID coincidia com `prefs.selectedStyleID`
/// e reseta pra `BuiltInStyles.defaultStyleID` se sim.
typealias OnStyleDeleted = @MainActor (UUID) -> Void

enum CustomStyleStoreError: Error {
    case invalidInput(String)
    case persistenceFailed(Error)
}
```

- [x] **Step 3: Implementar `CustomStyleStoreLive` usando SwiftData**

```swift
// app/Tagarela/Refiner/CustomStyleStoreLive.swift
import Foundation
import SwiftData
import OSLog

@MainActor
final class CustomStyleStoreLive: ObservableObject, CustomStyleStore {
    private let logger = Logger(subsystem: "com.tagarela", category: "CustomStyleStore")
    private let container: ModelContainer
    private let context: ModelContext
    /// Callback pós-delete; recebe o UUID do style apagado pra caller decidir
    /// reset de `prefs.selectedStyleID`.
    private let onStyleDeleted: OnStyleDeleted

    @Published private(set) var styles: [CustomStyle] = []

    init(container: ModelContainer,
         onStyleDeleted: @escaping OnStyleDeleted) {
        self.container = container
        self.context = ModelContext(container)
        self.onStyleDeleted = onStyleDeleted
    }

    func reload() async {
        do {
            let descriptor = FetchDescriptor<CustomStyle>(
                sortBy: [SortDescriptor(\.name, order: .forward)])
            self.styles = try context.fetch(descriptor)
        } catch {
            logger.error("fetch custom styles failed: \(String(describing: error), privacy: .public)")
            self.styles = []
        }
    }

    func create(name: String, systemPrompt: String, appendCodeSwitching: Bool) async throws -> CustomStyle {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw CustomStyleStoreError.invalidInput("nome vazio") }
        guard !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CustomStyleStoreError.invalidInput("system prompt vazio")
        }
        let style = CustomStyle(name: trimmedName,
                                 systemPrompt: systemPrompt,
                                 appendCodeSwitching: appendCodeSwitching)
        context.insert(style)
        do {
            try context.save()
        } catch {
            throw CustomStyleStoreError.persistenceFailed(error)
        }
        await reload()
        return style
    }

    func update(_ style: CustomStyle) async throws {
        style.updatedAt = .now
        do {
            try context.save()
        } catch {
            throw CustomStyleStoreError.persistenceFailed(error)
        }
        await reload()
    }

    func delete(_ style: CustomStyle) async throws {
        let deletedID = style.id
        context.delete(style)
        do {
            try context.save()
        } catch {
            throw CustomStyleStoreError.persistenceFailed(error)
        }
        onStyleDeleted(deletedID)
        await reload()
    }
}
```

- [x] **Step 4: Implementar `CustomStyleStoreNoop`**

```swift
// app/Tagarela/Refiner/CustomStyleStoreNoop.swift
import Foundation

@MainActor
final class CustomStyleStoreNoop: ObservableObject, CustomStyleStore {
    @Published private(set) var styles: [CustomStyle] = []

    func reload() async { }
    func create(name: String, systemPrompt: String, appendCodeSwitching: Bool) async throws -> CustomStyle {
        throw CustomStyleStoreError.persistenceFailed(NSError(domain: "noop", code: 0))
    }
    func update(_ style: CustomStyle) async throws {
        throw CustomStyleStoreError.persistenceFailed(NSError(domain: "noop", code: 0))
    }
    func delete(_ style: CustomStyle) async throws {
        throw CustomStyleStoreError.persistenceFailed(NSError(domain: "noop", code: 0))
    }
}
```

- [x] **Step 5: Modificar `HistoryStoreLive` pra aceitar `ModelContainer` injetado**

Edit `app/Tagarela/History/HistoryStoreLive.swift`. Auditar o init existente; adicionar overload (sem quebrar API):

```swift
// (manter init() existente que cria container internamente)

init(container: ModelContainer) throws {
    self.container = container
    self.context = ModelContext(container)
}
```

Pra criar o container compartilhado lá no `AppContainer`:

```swift
extension HistoryStoreLive {
    static func sharedContainer() throws -> ModelContainer {
        let schema = Schema([Transcription.self, CustomStyle.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

(Auditar `HistoryStoreLive.swift` antes — pode haver fricção com o `Schema` atual que só tem `Transcription`. Adaptar accordingly.)

- [x] **Step 6: Wire-up no `AppContainer`**

Edit `app/Tagarela/App/AppContainer.swift`:

Substituir o bloco onde `historyStore` é criado por:

```swift
// Container SwiftData compartilhado entre HistoryStoreLive e CustomStyleStoreLive.
// Falha → ambos caem em Noop. (Fase 2b-1)
let sharedContainer: ModelContainer? = try? HistoryStoreLive.sharedContainer()

let historyStore: HistoryStore
if let c = sharedContainer {
    historyStore = (try? HistoryStoreLive(container: c)) ?? HistoryStoreNoop()
} else {
    historyStore = HistoryStoreNoop()
}

let customStyleStore: CustomStyleStore
if let c = sharedContainer {
    customStyleStore = CustomStyleStoreLive(container: c) { [weak prefs] deletedID in
        guard let prefs else { return }
        if prefs.selectedStyleID == deletedID {
            prefs.selectedStyleID = BuiltInStyles.defaultStyleID
        }
    }
} else {
    customStyleStore = CustomStyleStoreNoop()
}
```

Adicionar property no `AppContainer`:

```swift
let customStyleStore: CustomStyleStore
```

E setar self após `self.historyStore = historyStore`:

```swift
self.customStyleStore = customStyleStore
```

- [x] **Step 7: Testes do `@Model CustomStyle`**

```swift
// app/TagarelaTests/CustomStyleTests.swift
import XCTest
import SwiftData
@testable import Tagarela

@MainActor
final class CustomStyleTests: XCTestCase {
    func test_init_setsDefaults() {
        let s = CustomStyle(name: "x", systemPrompt: "y", appendCodeSwitching: true)
        XCTAssertEqual(s.name, "x")
        XCTAssertEqual(s.systemPrompt, "y")
        XCTAssertTrue(s.appendCodeSwitching)
        XCTAssertEqual(s.createdAt.timeIntervalSinceNow, 0, accuracy: 1.0)
    }

    func test_asStyle_appendsCodeSwitchingWhenFlagOn() {
        let s = CustomStyle(name: "x", systemPrompt: "base", appendCodeSwitching: true)
        XCTAssertTrue(s.asStyle().systemPrompt.contains("code-switching") ||
                       s.asStyle().systemPrompt.contains("termos técnicos"))
    }

    func test_asStyle_withoutCodeSwitching_returnsRawPrompt() {
        let s = CustomStyle(name: "x", systemPrompt: "base", appendCodeSwitching: false)
        XCTAssertEqual(s.asStyle().systemPrompt, "base")
    }

    func test_asStyle_isBuiltInIsFalse() {
        let s = CustomStyle(name: "x", systemPrompt: "y", appendCodeSwitching: false)
        XCTAssertFalse(s.asStyle().isBuiltIn)
    }
}
```

- [x] **Step 8: Testes do `CustomStyleStoreLive`**

```swift
// app/TagarelaTests/CustomStyleStoreTests.swift
import XCTest
import SwiftData
@testable import Tagarela

@MainActor
final class CustomStyleStoreTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: Schema([Transcription.self, CustomStyle.self]),
                                          isStoredInMemoryOnly: true)
        return try ModelContainer(for: Schema([Transcription.self, CustomStyle.self]),
                                   configurations: [config])
    }

    private func makeStore(_ container: ModelContainer) -> CustomStyleStoreLive {
        CustomStyleStoreLive(container: container) { _ in }
    }

    func test_create_emptyName_throws() async throws {
        let store = makeStore(try makeContainer())
        do {
            _ = try await store.create(name: "  ", systemPrompt: "p", appendCodeSwitching: false)
            XCTFail("expected throw")
        } catch CustomStyleStoreError.invalidInput {} catch { XCTFail("wrong: \(error)") }
    }

    func test_create_emptyPrompt_throws() async throws {
        let store = makeStore(try makeContainer())
        do {
            _ = try await store.create(name: "n", systemPrompt: "", appendCodeSwitching: false)
            XCTFail("expected throw")
        } catch CustomStyleStoreError.invalidInput {} catch { XCTFail("wrong: \(error)") }
    }

    func test_create_persists() async throws {
        let store = makeStore(try makeContainer())
        let s = try await store.create(name: "commits", systemPrompt: "...", appendCodeSwitching: true)
        await store.reload()
        XCTAssertEqual(store.styles.count, 1)
        XCTAssertEqual(store.styles.first?.id, s.id)
    }

    func test_update_changesUpdatedAt() async throws {
        let store = makeStore(try makeContainer())
        let s = try await store.create(name: "x", systemPrompt: "y", appendCodeSwitching: true)
        let original = s.updatedAt
        try await Task.sleep(nanoseconds: 50_000_000)
        s.name = "x updated"
        try await store.update(s)
        XCTAssertGreaterThan(s.updatedAt, original)
    }

    func test_delete_callsCallbackWithDeletedID() async throws {
        let container = try makeContainer()
        nonisolated(unsafe) var capturedID: UUID?
        let store = CustomStyleStoreLive(container: container) { id in
            capturedID = id
        }
        let s = try await store.create(name: "x", systemPrompt: "y", appendCodeSwitching: true)
        let originalID = s.id
        try await store.delete(s)
        XCTAssertEqual(capturedID, originalID)
        await store.reload()
        XCTAssertEqual(store.styles.count, 0)
    }

    func test_noop_returnsEmptyAndThrowsOnWrites() async throws {
        let store = CustomStyleStoreNoop()
        await store.reload()
        XCTAssertEqual(store.styles.count, 0)
        do {
            _ = try await store.create(name: "x", systemPrompt: "y", appendCodeSwitching: false)
            XCTFail("expected throw")
        } catch {}
    }
}
```

- [x] **Step 9: Re-gerar projeto + rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, +10 testes (~102). ✅ Resultado real: 105 testes (2026-04-29).

- [x] **Step 10: Commit**

```bash
git add app/Tagarela/Refiner/CustomStyle.swift app/Tagarela/Refiner/CustomStyleStore.swift app/Tagarela/Refiner/CustomStyleStoreLive.swift app/Tagarela/Refiner/CustomStyleStoreNoop.swift app/Tagarela/History/HistoryStoreLive.swift app/Tagarela/App/AppContainer.swift app/TagarelaTests/CustomStyleTests.swift app/TagarelaTests/CustomStyleStoreTests.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(custom-styles): SwiftData @Model CustomStyle + CustomStyleStore

- @Model CustomStyle (id, name, systemPrompt, appendCodeSwitching, dates)
- protocolo + Live (SwiftData) + Noop (fallback se container falha)
- HistoryStoreLive aceita ModelContainer injetado pra compartilhar com
  o CustomStyleStore — single container com [Transcription, CustomStyle]
- AppContainer cria container compartilhado; ambos os stores caem em
  Noop se o container falhar
- 10 testes (4 do @Model, 6 do store)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: `StyleProvider` + reset do `selectedStyleID` ao apagar

**Files:**
- Create: `app/Tagarela/Refiner/StyleProvider.swift`
- Modify: `app/Tagarela/Refiner/RefinerFactory.swift` (usa StyleProvider)
- Modify: `app/Tagarela/App/AppContainer.swift` (wire-up + closure de reset)
- Create: `app/TagarelaTests/StyleProviderTests.swift`
- Modify: `app/TagarelaTests/RefinerFactoryTests.swift` (adapta pra StyleProvider)

- [ ] **Step 1: Implementar `StyleProvider`**

```swift
// app/Tagarela/Refiner/StyleProvider.swift
import Foundation

@MainActor
final class StyleProvider {
    private let customStore: CustomStyleStore

    init(customStore: CustomStyleStore) {
        self.customStore = customStore
    }

    /// Lista combinada built-in + custom, ordenada por nome (case-insensitive).
    var all: [Style] {
        let builtIns = BuiltInStyles.all
        let customs = customStore.styles.map { $0.asStyle() }
        return (builtIns + customs).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Resolve um Style pelo UUID. Procura primeiro nos built-ins (UUIDs estáveis),
    /// depois nos custom. Retorna nil se nenhum bate.
    func style(for id: UUID) -> Style? {
        if let b = BuiltInStyles.style(for: id) { return b }
        return customStore.styles.first { $0.id == id }?.asStyle()
    }

    /// Style ativo dado um ID; cai pra defaultStyleID se não encontra.
    func styleOrDefault(for id: UUID) -> Style {
        style(for: id) ?? BuiltInStyles.style(for: BuiltInStyles.defaultStyleID)!
    }
}
```

- [ ] **Step 2: Modificar `RefinerFactory` pra consultar `StyleProvider`**

Edit `app/Tagarela/Refiner/RefinerFactory.swift`:

Adicionar property + ajustar init e `current()`:

```swift
@MainActor
final class RefinerFactory {
    private let prefs: PreferencesStore
    private let styleProvider: StyleProvider
    private let openAI: () -> OpenAIRefiner
    private let ollama: () -> OllamaRefiner
    private let identity: IdentityRefiner

    init(prefs: PreferencesStore,
         styleProvider: StyleProvider,
         openAI: @escaping () -> OpenAIRefiner,
         ollama: @escaping () -> OllamaRefiner,
         identity: IdentityRefiner = IdentityRefiner()) {
        self.prefs = prefs
        self.styleProvider = styleProvider
        self.openAI = openAI
        self.ollama = ollama
        self.identity = identity
    }

    func current() -> (refiner: TextRefiner, style: Style) {
        let style = styleProvider.styleOrDefault(for: prefs.selectedStyleID)
        if style.id == BuiltInStyles.cruSemReescrita.id {
            return (identity, style)
        }
        switch prefs.refinerKind {
        case .none:   return (identity, style)
        case .openai: return (openAI(), style)
        case .ollama: return (ollama(), style)
        }
    }
}
```

- [ ] **Step 3: Atualizar wire-up no `AppContainer`**

Edit `app/Tagarela/App/AppContainer.swift`:

Após o bloco que cria `customStyleStore` (já com a closure final da T4), criar o `StyleProvider` logo abaixo:

```swift
let styleProvider = StyleProvider(customStore: customStyleStore)
self.styleProvider = styleProvider
```

(Adicionar `let styleProvider: StyleProvider` no topo da classe.)

Atualizar a chamada do `RefinerFactory` pra passar `styleProvider`:

```swift
let factory = RefinerFactory(
    prefs: prefs,
    styleProvider: styleProvider,
    openAI: { /* mesma de T2 */ },
    ollama: { /* mesma de T2 */ })
```

Salvar como property:

```swift
self.styleProvider = styleProvider
```

(Adicionar `let styleProvider: StyleProvider` no topo da classe.)

Adicionar reload inicial após o init:

```swift
Task { await customStyleStore.reload() }
```

- [ ] **Step 4: Testes do `StyleProvider`**

```swift
// app/TagarelaTests/StyleProviderTests.swift
import XCTest
@testable import Tagarela

@MainActor
final class StyleProviderTests: XCTestCase {
    private final class FakeCustomStore: CustomStyleStore, ObservableObject {
        var styles: [CustomStyle]
        init(styles: [CustomStyle] = []) { self.styles = styles }
        func reload() async {}
        func create(name: String, systemPrompt: String, appendCodeSwitching: Bool) async throws -> CustomStyle {
            fatalError()
        }
        func update(_ style: CustomStyle) async throws { fatalError() }
        func delete(_ style: CustomStyle) async throws { fatalError() }
    }

    func test_all_mergesBuiltInAndCustom() {
        let custom = CustomStyle(name: "aaa primeiro alfabeticamente",
                                  systemPrompt: "p", appendCodeSwitching: false)
        let store = FakeCustomStore(styles: [custom])
        let provider = StyleProvider(customStore: store)
        let names = provider.all.map(\.name)
        XCTAssertEqual(names.first, "aaa primeiro alfabeticamente")
        XCTAssertEqual(provider.all.count, 5)  // 4 built-in + 1 custom
    }

    func test_styleForId_findsBuiltIn() {
        let store = FakeCustomStore()
        let provider = StyleProvider(customStore: store)
        XCTAssertNotNil(provider.style(for: BuiltInStyles.conversaInformal.id))
    }

    func test_styleForId_findsCustom() {
        let custom = CustomStyle(name: "x", systemPrompt: "y", appendCodeSwitching: false)
        let store = FakeCustomStore(styles: [custom])
        let provider = StyleProvider(customStore: store)
        XCTAssertEqual(provider.style(for: custom.id)?.id, custom.id)
    }

    func test_styleForId_unknown_returnsNil() {
        let provider = StyleProvider(customStore: FakeCustomStore())
        XCTAssertNil(provider.style(for: UUID()))
    }

    func test_styleOrDefault_unknown_returnsConversaInformal() {
        let provider = StyleProvider(customStore: FakeCustomStore())
        let style = provider.styleOrDefault(for: UUID())
        XCTAssertEqual(style.id, BuiltInStyles.defaultStyleID)
    }
}
```

- [ ] **Step 5: Adaptar `RefinerFactoryTests`**

Edit `app/TagarelaTests/RefinerFactoryTests.swift`: nos helpers que constroem `RefinerFactory(...)`, criar um `StyleProvider` com `FakeCustomStore` (vazio) e passar pro factory.

- [ ] **Step 6: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, +5 testes (~107).

- [ ] **Step 7: Commit**

```bash
git add app/Tagarela/Refiner/StyleProvider.swift app/Tagarela/Refiner/RefinerFactory.swift app/Tagarela/App/AppContainer.swift app/TagarelaTests/StyleProviderTests.swift app/TagarelaTests/RefinerFactoryTests.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(refiner): StyleProvider mescla built-in + custom styles

- StyleProvider.all: lista única ordenada por nome
- styleForId: lookup em built-ins primeiro (UUIDs estáveis), depois custom
- styleOrDefault: fallback pra conversaInformal se ID some
- RefinerFactory passa a consultar StyleProvider (não mais BuiltInStyles direto)
- AppContainer: closure onSelectedStyleDeleted reseta prefs.selectedStyleID
  pra default quando o style ativo é apagado
- 5 testes novos do provider + adaptações no RefinerFactoryTests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 6: Status bar Style submenu usa `StyleProvider`

**Status: implementado em 2026-04-29.** Build clean, 112 testes verdes.

**Files:**
- Modify: `app/Tagarela/UI/MenuBar/StyleSubmenu.swift`
- Modify: `app/Tagarela/UI/MenuBar/MenuBarController.swift` (MenuBarContent recebe customStore? + styleProvider)
- Modify: `app/Tagarela/App/AppContainer.swift` (expõe customStyleStoreLive; passa pro MenuBarContent)
- Modify: `app/Tagarela/App/TagarelaApp.swift` (passa os novos params ao instanciar MenuBarContent)

**Nota de implementação:** A task foi expandida em relação ao plano original. `StyleSubmenu` recebe `@ObservedObject customStore: CustomStyleStoreLive` (para reactivity ao vivo quando custom styles forem criados na T11) e `styleProvider`. `StyleSubmenuStaticFallback` foi adicionado no mesmo arquivo para o caso degenerado onde `customStyleStoreLive` é nil. `AppContainer` expõe `customStyleStoreLive: CustomStyleStoreLive?` via downcast. O hack `.id(customStore.styles.count)` força re-render do menu quando a contagem de custom styles muda.

- [x] **Step 1: Auditar `StyleSubmenu.swift` atual**

```bash
cat /Users/tars/Dev/tagarela/app/Tagarela/UI/MenuBar/StyleSubmenu.swift
```

Identificar onde `BuiltInStyles.all` é consumido e substituir por `styleProvider.all`.

- [x] **Step 2: Modificar `StyleSubmenu` pra aceitar `StyleProvider`**

Padrão típico (adaptar conforme o código real):

```swift
struct StyleSubmenu: View {
    @ObservedObject var prefs: PreferencesStore
    let styleProvider: StyleProvider

    var body: some View {
        Menu("Estilo") {
            ForEach(styleProvider.all) { style in
                Button(action: { prefs.selectedStyleID = style.id }) {
                    HStack {
                        if prefs.selectedStyleID == style.id { Image(systemName: "checkmark") }
                        Text(style.name)
                    }
                }
            }
        }
    }
}
```

(Se `StyleSubmenu` é AppKit/`NSMenu`, adaptar o pattern equivalente — auditar antes.)

- [x] **Step 3: Wire-up no `AppContainer`**

Onde o `MenuBarController`/`MenuBarContent` é construído, passar `styleProvider`:

```swift
StyleSubmenu(prefs: prefs, styleProvider: styleProvider)
```

- [x] **Step 4: Build (sem testes — UI)**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -10
```

- [ ] **Step 5: Aceite manual rápido (não automatizado)** — pendente, executar manualmente

Rodar app, abrir menubar:
- Submenu "Estilo" deve listar **4 built-ins** (mesma lista de antes).
- Selecionar um: indica check.
- Validação posterior: depois da T11 (StylesView CRUD), criar 1 custom; voltar aqui e confirmar que aparece no submenu misturado aos built-ins, ordenado.

- [x] **Step 6: Commit**

```bash
git add app/Tagarela/UI/MenuBar/StyleSubmenu.swift app/Tagarela/App/AppContainer.swift
git commit -m "$(cat <<'EOF'
refactor(menubar): submenu Estilo consome StyleProvider

Substitui BuiltInStyles.all direto por styleProvider.all. Custom
styles entrarão na lista automaticamente quando criados (T11). Sem
mudança visível pro user enquanto a lista de custom estiver vazia.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: `PreferencesWindow` shell + sidebar nav + `⌘,` wiring

**Files:**
- Create: `app/Tagarela/Preferences/UI/PrefsSection.swift`
- Create: `app/Tagarela/Preferences/UI/PreferencesRoot.swift`
- Create: `app/Tagarela/App/PreferencesWindow.swift`
- Create: stubs vazios pra cada section view (`Preferences/UI/Sections/*.swift`)
- Modify: `app/Tagarela/App/TagarelaApp.swift` (`.commands` replacing `.appSettings`)
- Modify: `app/Tagarela/App/AppContainer.swift` (instancia + abre janela)

- [ ] **Step 1: `PrefsSection` enum**

```swift
// app/Tagarela/Preferences/UI/PrefsSection.swift
import Foundation

enum PrefsSection: String, Hashable, CaseIterable, Identifiable {
    case geral
    case refinerGeral
    case refinerOllama
    case refinerOpenAI
    case estilos
    case audio
    case historico
    case vocabulario
    case atalhos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .geral:         return String(localized: "preferences.section.geral", defaultValue: "Geral")
        case .refinerGeral:  return String(localized: "preferences.section.refiner.geral", defaultValue: "Geral")
        case .refinerOllama: return String(localized: "preferences.section.refiner.ollama", defaultValue: "Ollama")
        case .refinerOpenAI: return String(localized: "preferences.section.refiner.openai", defaultValue: "OpenAI")
        case .estilos:       return String(localized: "preferences.section.estilos", defaultValue: "Estilos")
        case .audio:         return String(localized: "preferences.section.audio", defaultValue: "Áudio")
        case .historico:     return String(localized: "preferences.section.historico", defaultValue: "Histórico")
        case .vocabulario:   return String(localized: "preferences.section.vocabulario", defaultValue: "Vocabulário")
        case .atalhos:       return String(localized: "preferences.section.atalhos", defaultValue: "Atalhos")
        }
    }
}
```

- [ ] **Step 2: Stubs vazios pra cada section view**

Pra cada arquivo abaixo, criar com placeholder `Text("…")`:

```swift
// app/Tagarela/Preferences/UI/Sections/GeneralView.swift
import SwiftUI
struct GeneralView: View {
    var body: some View {
        Form { Text("Geral — em construção") }.padding()
    }
}
```

Repetir pra: `RefinerGeneralView.swift`, `RefinerOllamaView.swift`, `RefinerOpenAIView.swift`, `StylesView.swift`, `AudioView.swift`, `HistoryView.swift`, `VocabularyView.swift`, `ShortcutsView.swift` — cada uma com Text apropriado.

- [ ] **Step 3: `PreferencesRoot` com `NavigationSplitView`**

```swift
// app/Tagarela/Preferences/UI/PreferencesRoot.swift
import SwiftUI

struct PreferencesRoot: View {
    @ObservedObject var prefs: PreferencesStore
    let styleProvider: StyleProvider
    let customStore: CustomStyleStore
    let ollamaModelLister: () -> OllamaModelLister
    let openAIKeyEditor: () -> Void
    let healthChecker: OllamaHealthChecker

    @State private var selection: PrefsSection = .geral

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: PrefsSection.geral) { Label(PrefsSection.geral.label, systemImage: "gearshape") }

                Section(header: Text(String(localized: "preferences.section.refiner.group", defaultValue: "Refiner"))) {
                    NavigationLink(value: PrefsSection.refinerGeral) { Text(PrefsSection.refinerGeral.label) }
                    NavigationLink(value: PrefsSection.refinerOllama) { Text(PrefsSection.refinerOllama.label) }
                    NavigationLink(value: PrefsSection.refinerOpenAI) { Text(PrefsSection.refinerOpenAI.label) }
                }

                NavigationLink(value: PrefsSection.estilos) { Label(PrefsSection.estilos.label, systemImage: "sparkles") }
                NavigationLink(value: PrefsSection.audio) { Label(PrefsSection.audio.label, systemImage: "waveform") }
                NavigationLink(value: PrefsSection.historico) { Label(PrefsSection.historico.label, systemImage: "scroll") }
                NavigationLink(value: PrefsSection.vocabulario) { Label(PrefsSection.vocabulario.label, systemImage: "book") }
                NavigationLink(value: PrefsSection.atalhos) { Label(PrefsSection.atalhos.label, systemImage: "keyboard") }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch selection {
            case .geral:         GeneralView()
            case .refinerGeral:  RefinerGeneralView()
            case .refinerOllama: RefinerOllamaView()
            case .refinerOpenAI: RefinerOpenAIView()
            case .estilos:       StylesView()
            case .audio:         AudioView()
            case .historico:     HistoryView()
            case .vocabulario:   VocabularyView()
            case .atalhos:       ShortcutsView()
            }
        }
        .frame(minWidth: 600, minHeight: 400, idealWidth: 720, idealHeight: 520)
    }
}
```

(Cada section view ainda é stub. Próximas tarefas implementam o conteúdo e injetam dependencies via `.environmentObject` ou via params.)

- [ ] **Step 4: `PreferencesWindow` (`NSWindowController` autosave)**

```swift
// app/Tagarela/App/PreferencesWindow.swift
import AppKit
import SwiftUI

@MainActor
final class PreferencesWindow {
    private var window: NSWindow?

    func show(content: () -> AnyView) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: content())
        let win = NSWindow(contentViewController: host)
        win.title = String(localized: "preferences.window.title", defaultValue: "Preferências")
        win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        win.setFrameAutosaveName("PreferencesWindow")
        win.setContentSize(NSSize(width: 720, height: 520))
        win.contentMinSize = NSSize(width: 600, height: 400)
        win.isReleasedWhenClosed = false
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 5: Wire-up `⌘,` no `TagarelaApp`**

Edit `app/Tagarela/App/TagarelaApp.swift`. No corpo da `App`, adicionar:

```swift
.commands {
    CommandGroup(replacing: .appSettings) {
        Button(String(localized: "preferences.menu.item", defaultValue: "Preferências…")) {
            container.openPreferences()
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
```

(Onde `container` é a referência ao `AppContainer` instanciado. Adaptar conforme padrão do app.)

- [ ] **Step 6: `AppContainer.openPreferences()`**

Edit `app/Tagarela/App/AppContainer.swift`:

```swift
let preferencesWindow = PreferencesWindow()

// no init, após criar tudo:
self.preferencesWindow = preferencesWindow

@MainActor
func openPreferences() {
    let view = PreferencesRoot(
        prefs: prefs,
        styleProvider: styleProvider,
        customStore: customStyleStore,
        ollamaModelLister: { OllamaModelLister(session: .shared,
                                                 baseURL: URL(string: prefs.ollamaBaseURL) ?? URL(string: "http://localhost:11434")!) },
        openAIKeyEditor: { [weak self] in self?.keyPromptWindow.show() },
        healthChecker: healthChecker)
    preferencesWindow.show(content: { AnyView(view) })
}
```

- [ ] **Step 7: Build (sem testes UI) + smoke manual**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -10
```

Manual:
- Rodar app, pressionar `⌘,`. Esperado: janela abre com sidebar listando 7 entradas + grupo Refiner aninhado. Cada link mostra placeholder "em construção" no detail.
- Fechar e reabrir: tamanho/posição persistem.

- [ ] **Step 8: Commit**

```bash
git add app/Tagarela/Preferences/UI/PrefsSection.swift app/Tagarela/Preferences/UI/PreferencesRoot.swift app/Tagarela/Preferences/UI/Sections/*.swift app/Tagarela/App/PreferencesWindow.swift app/Tagarela/App/TagarelaApp.swift app/Tagarela/App/AppContainer.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(preferences): janela de Preferências (shell sidebar+detail) + ⌘,

- PreferencesRoot SwiftUI com NavigationSplitView (sidebar + detail)
- PrefsSection enum cobrindo 7 seções, com Refiner aninhado em sub-grupo
- PreferencesWindow (NSWindowController) com setFrameAutosaveName
- TagarelaApp registra ⌘, via CommandGroup(replacing: .appSettings)
- 9 section views com stubs "em construção"; conteúdo nas T8-T11

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 8: Seções simples — Geral, Áudio, Histórico, Vocabulário, Atalhos

**Files:**
- Modify: `app/Tagarela/Preferences/UI/Sections/GeneralView.swift`
- Modify: `app/Tagarela/Preferences/UI/Sections/AudioView.swift`
- Modify: `app/Tagarela/Preferences/UI/Sections/HistoryView.swift`
- Modify: `app/Tagarela/Preferences/UI/Sections/VocabularyView.swift`
- Modify: `app/Tagarela/Preferences/UI/Sections/ShortcutsView.swift`
- Modify: `app/Tagarela/Preferences/UI/PreferencesRoot.swift` (passar `prefs` pras views)

- [ ] **Step 1: Atualizar `PreferencesRoot` pra passar `prefs` pras section views**

No detail switch, trocar cada `XView()` por `XView(prefs: prefs)`. (Mantém compatível com T7 onde stubs eram sem args; agora exigem prefs.)

- [ ] **Step 2: `GeneralView`**

```swift
// app/Tagarela/Preferences/UI/Sections/GeneralView.swift
import SwiftUI

struct GeneralView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.geral.about.header", defaultValue: "Sobre"))) {
                LabeledContent(String(localized: "preferences.geral.version", defaultValue: "Versão")) {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
                LabeledContent(String(localized: "preferences.geral.build", defaultValue: "Build")) {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 3: `AudioView`**

```swift
// app/Tagarela/Preferences/UI/Sections/AudioView.swift
import SwiftUI

struct AudioView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.audio.boost.header", defaultValue: "Ganho de áudio"))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "preferences.audio.maxgain.label", defaultValue: "Ganho máximo:"))
                        Spacer()
                        Text(String(format: "%.1f×", prefs.audioBoostMaxGain))
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { prefs.audioBoostMaxGain },
                        set: { prefs.setAudioBoostMaxGain($0) }
                    ), in: PreferencesDefaults.audioBoostMaxGainRange,
                       step: 1.0)
                    Text(String(localized: "preferences.audio.maxgain.help",
                                 defaultValue: "Compensa input gain baixo do microfone. Padrão: 20×."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 4: `HistoryView`**

```swift
// app/Tagarela/Preferences/UI/Sections/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.history.retention.header",
                                         defaultValue: "Retenção"))) {
                LabeledContent(String(localized: "preferences.history.maxItems", defaultValue: "Máximo de itens")) {
                    TextField("", value: $prefs.historyMaxItems, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "preferences.history.maxDays", defaultValue: "Máximo de dias")) {
                    TextField("", value: $prefs.historyMaxDays, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                Text(String(localized: "preferences.history.help",
                             defaultValue: "Histórico é truncado a cada nova captura, mantendo o menor entre os dois limites."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 5: `VocabularyView`**

```swift
// app/Tagarela/Preferences/UI/Sections/VocabularyView.swift
import SwiftUI

struct VocabularyView: View {
    @ObservedObject var prefs: PreferencesStore
    @State private var text: String = ""

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.vocab.header", defaultValue: "Vocabulário técnico"))) {
                Text(String(localized: "preferences.vocab.help",
                             defaultValue: "Termos passados como initial prompt pro Whisper, melhorando reconhecimento de jargão. Um por linha."))
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .frame(minHeight: 200)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { text = prefs.technicalVocabulary.joined(separator: "\n") }
        .onChange(of: text) { _, newValue in
            prefs.technicalVocabulary = newValue
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
    }
}
```

- [ ] **Step 6: `ShortcutsView` (read-only)**

```swift
// app/Tagarela/Preferences/UI/Sections/ShortcutsView.swift
import SwiftUI

struct ShortcutsView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.shortcuts.header", defaultValue: "Atalhos atuais"))) {
                LabeledContent(String(localized: "preferences.shortcuts.toggle",
                                       defaultValue: "Iniciar/parar ditado")) {
                    Text("⌥ direito").font(.system(.body, design: .monospaced))
                }
                LabeledContent(String(localized: "preferences.shortcuts.cancel",
                                       defaultValue: "Cancelar")) {
                    Text("Esc").font(.system(.body, design: .monospaced))
                }
                Text(String(localized: "preferences.shortcuts.help",
                             defaultValue: "Atalhos customizáveis chegam em uma versão futura."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 7: Build + manual smoke**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -5
```

Manual:
- Abrir Preferências, navegar entre Geral / Áudio / Histórico / Vocabulário / Atalhos.
- Áudio: mexer slider → check `defaults read com.tagarela.Tagarela com.tagarela.preferences.audioBoostMaxGain` reflete.
- Histórico: alterar maxItems → persiste após reabrir.
- Vocabulário: editar lista → persiste.
- Atalhos: read-only, atalhos certos.

- [ ] **Step 8: Commit**

```bash
git add app/Tagarela/Preferences/UI/Sections/GeneralView.swift app/Tagarela/Preferences/UI/Sections/AudioView.swift app/Tagarela/Preferences/UI/Sections/HistoryView.swift app/Tagarela/Preferences/UI/Sections/VocabularyView.swift app/Tagarela/Preferences/UI/Sections/ShortcutsView.swift app/Tagarela/Preferences/UI/PreferencesRoot.swift
git commit -m "$(cat <<'EOF'
feat(preferences): seções Geral, Áudio, Histórico, Vocabulário, Atalhos

- GeneralView: read-only versão+build
- AudioView: slider audioBoostMaxGain (1-50, step 1)
- HistoryView: numeric inputs maxItems/maxDays
- VocabularyView: TextEditor multilinha (split em \n)
- ShortcutsView: read-only display dos atalhos atuais

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 9: `RefinerGeneralView` + `RefinerOllamaView` (model picker dinâmico)

**Files:**
- Modify: `app/Tagarela/Preferences/UI/Sections/RefinerGeneralView.swift`
- Modify: `app/Tagarela/Preferences/UI/Sections/RefinerOllamaView.swift`
- Modify: `app/Tagarela/Preferences/UI/PreferencesRoot.swift` (passar `ollamaModelLister`)

- [ ] **Step 1: `RefinerGeneralView`**

```swift
// app/Tagarela/Preferences/UI/Sections/RefinerGeneralView.swift
import SwiftUI

struct RefinerGeneralView: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.refiner.geral.backend", defaultValue: "Backend"))) {
                Picker("", selection: $prefs.refinerKind) {
                    Text(String(localized: "refiner.kind.ollama", defaultValue: "Ollama")).tag(RefinerKind.ollama)
                    Text(String(localized: "refiner.kind.openai", defaultValue: "OpenAI")).tag(RefinerKind.openai)
                    Text(String(localized: "refiner.kind.none", defaultValue: "Sem LLM")).tag(RefinerKind.none)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            Section(header: Text(String(localized: "preferences.refiner.geral.timeout.header", defaultValue: "Timeout"))) {
                LabeledContent(String(localized: "preferences.refiner.geral.timeout.label", defaultValue: "Tempo máximo (s)")) {
                    TextField("", value: $prefs.refinerTimeoutSec, format: .number)
                        .frame(width: 80).multilineTextAlignment(.trailing)
                }
                Text(String(localized: "preferences.refiner.geral.timeout.help",
                             defaultValue: "Aplicado a OpenAI e Ollama. Padrão: 60s. Modelos lentos podem precisar de mais."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 2: `RefinerOllamaView` com scan dinâmico**

```swift
// app/Tagarela/Preferences/UI/Sections/RefinerOllamaView.swift
import SwiftUI

@MainActor
struct RefinerOllamaView: View {
    @ObservedObject var prefs: PreferencesStore
    let modelLister: () -> OllamaModelLister

    @State private var availableModels: [String] = []
    @State private var loading = false
    @State private var loadError: String?

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.refiner.ollama.endpoint.header", defaultValue: "Endpoint"))) {
                LabeledContent(String(localized: "preferences.refiner.ollama.baseURL", defaultValue: "Base URL")) {
                    TextField("", text: $prefs.ollamaBaseURL)
                        .frame(maxWidth: 280)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: prefs.ollamaBaseURL) { _, _ in
                            availableModels = []
                            Task { await loadModels() }
                        }
                }
            }
            Section(header: Text(String(localized: "preferences.refiner.ollama.model.header", defaultValue: "Modelo"))) {
                if loading {
                    ProgressView(String(localized: "preferences.refiner.ollama.loading", defaultValue: "Carregando lista…"))
                } else if let err = loadError {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle")
                        VStack(alignment: .leading) {
                            Text(err).foregroundStyle(.orange)
                            TextField(String(localized: "preferences.refiner.ollama.fallback.placeholder",
                                              defaultValue: "Digite o nome (ex: gemma4:e4b)"),
                                      text: $prefs.ollamaModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 280)
                        }
                    }
                } else {
                    Picker(String(localized: "preferences.refiner.ollama.model.label", defaultValue: "Modelo"),
                           selection: $prefs.ollamaModel) {
                        ForEach(modelsIncludingCurrent, id: \.self) { name in
                            Text(displayName(name)).tag(name)
                        }
                    }
                }
                Button(String(localized: "preferences.refiner.ollama.refresh", defaultValue: "Atualizar")) {
                    Task { await loadModels() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await loadModels() }
    }

    /// Lista exibida no Picker: união da lista de availableModels e do prefs.ollamaModel
    /// (garante que o modelo selecionado nunca some — aparece como "(não instalado)").
    private var modelsIncludingCurrent: [String] {
        if availableModels.contains(prefs.ollamaModel) || prefs.ollamaModel.isEmpty {
            return availableModels
        }
        return availableModels + [prefs.ollamaModel]
    }

    private func displayName(_ name: String) -> String {
        if name == prefs.ollamaModel && !availableModels.contains(name) {
            return "\(name) (não instalado)"
        }
        return name
    }

    private func loadModels() async {
        loading = true
        loadError = nil
        defer { loading = false }
        do {
            availableModels = try await modelLister().availableModels()
        } catch {
            loadError = String(localized: "preferences.refiner.ollama.offline",
                                defaultValue: "Ollama offline. Digite o nome manualmente.")
        }
    }
}
```

- [ ] **Step 3: Atualizar `PreferencesRoot` pra passar `modelLister`**

No `detail` switch:

```swift
case .refinerOllama:
    RefinerOllamaView(prefs: prefs, modelLister: ollamaModelLister)
```

- [ ] **Step 4: Build + smoke manual**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -5
```

Manual (Ollama precisa estar rodando):
- Abrir Preferências > Refiner > Ollama. Espera ver `gemma4:e4b` na lista.
- Mudar baseURL pra um inválido (`http://localhost:99999`) → após delay, banner offline aparece.
- Clicar Atualizar → re-fires.

- [ ] **Step 5: Commit**

```bash
git add app/Tagarela/Preferences/UI/Sections/RefinerGeneralView.swift app/Tagarela/Preferences/UI/Sections/RefinerOllamaView.swift app/Tagarela/Preferences/UI/PreferencesRoot.swift
git commit -m "$(cat <<'EOF'
feat(preferences): seções Refiner > Geral e Refiner > Ollama

- RefinerGeneralView: backend picker (radio) + timeout
- RefinerOllamaView: baseURL + scan dinâmico via OllamaModelLister
  - loading state, offline fallback (free-text + banner), refresh button
  - prefs.ollamaModel sempre presente na lista (mesmo se não instalado)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 10: `RefinerOpenAIView` (provider + endpoints + key)

**Files:**
- Modify: `app/Tagarela/Preferences/UI/Sections/RefinerOpenAIView.swift`
- Modify: `app/Tagarela/Preferences/UI/PreferencesRoot.swift` (passar `openAIKeyEditor`)
- Verificar: `app/Tagarela/UI/Onboarding/OpenAIKeyPromptWindow.swift` expõe método `show()`.

- [ ] **Step 1: Auditar `OpenAIKeyPromptWindow.show()`**

```bash
grep -n "func show" /Users/tars/Dev/tagarela/app/Tagarela/UI/Onboarding/OpenAIKeyPromptWindow.swift
```

Se não tiver, adicionar método público que reabre a NSPanel.

- [ ] **Step 2: `RefinerOpenAIView`**

```swift
// app/Tagarela/Preferences/UI/Sections/RefinerOpenAIView.swift
import SwiftUI

@MainActor
struct RefinerOpenAIView: View {
    @ObservedObject var prefs: PreferencesStore
    let keychain: KeychainService
    let openAIKeyEditor: () -> Void

    @State private var keyMaskedDisplay: String = "—"

    var body: some View {
        Form {
            Section(header: Text(String(localized: "preferences.refiner.openai.provider.header", defaultValue: "Provider"))) {
                Picker("", selection: $prefs.openAIEndpoint.provider) {
                    Text(String(localized: "preferences.refiner.openai.provider.official",
                                 defaultValue: "OpenAI oficial")).tag(OpenAIProvider.official)
                    Text(String(localized: "preferences.refiner.openai.provider.openrouter",
                                 defaultValue: "OpenRouter")).tag(OpenAIProvider.openrouter)
                    Text(String(localized: "preferences.refiner.openai.provider.lmstudio",
                                 defaultValue: "LM Studio")).tag(OpenAIProvider.lmstudio)
                    Text(String(localized: "preferences.refiner.openai.provider.custom",
                                 defaultValue: "URL custom")).tag(OpenAIProvider.custom)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: prefs.openAIEndpoint.provider) { _, newProvider in
                    if let url = OpenAIEndpointDefaults.defaultURL(for: newProvider) {
                        prefs.openAIEndpoint = OpenAIEndpoint(provider: newProvider, baseURL: url)
                    }
                }
            }
            Section(header: Text(String(localized: "preferences.refiner.openai.url.header", defaultValue: "Base URL"))) {
                TextField("", text: Binding(
                    get: { prefs.openAIEndpoint.baseURL.absoluteString },
                    set: { newStr in
                        if let url = URL(string: newStr) {
                            prefs.openAIEndpoint = OpenAIEndpoint(
                                provider: prefs.openAIEndpoint.provider,
                                baseURL: url)
                        }
                    }))
                    .frame(maxWidth: 380)
                    .textFieldStyle(.roundedBorder)
            }
            Section(header: Text(String(localized: "preferences.refiner.openai.model.header", defaultValue: "Modelo"))) {
                TextField("", text: $prefs.openAIModel)
                    .frame(maxWidth: 240)
                    .textFieldStyle(.roundedBorder)
            }
            Section(header: Text(String(localized: "preferences.refiner.openai.key.header", defaultValue: "API key"))) {
                HStack {
                    Text(keyMaskedDisplay).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(String(localized: "preferences.refiner.openai.key.edit", defaultValue: "Alterar…")) {
                        openAIKeyEditor()
                        // refresh display após o modal fechar (best effort)
                        Task {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            refreshKeyDisplay()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { refreshKeyDisplay() }
    }

    private func refreshKeyDisplay() {
        // try? sobre `throws -> String?` colapsa pra `String?` (SE-0230). Não duplo-bind.
        if let key = try? keychain.openAIKey(), let key, !key.isEmpty {
            // ⚠️ se você está executando isto: o `let key` no meio é redundante e
            // não compila em Swift 5.0+ — remova. Implementer corrigiu pra:
            //     if let key = try? keychain.openAIKey(), !key.isEmpty
            let last4 = String(key.suffix(4))
            keyMaskedDisplay = "••••••••\(last4)"
        } else {
            keyMaskedDisplay = String(localized: "preferences.refiner.openai.key.missing",
                                       defaultValue: "Não configurada")
        }
    }
}
```

- [ ] **Step 3: Atualizar `PreferencesRoot`**

```swift
case .refinerOpenAI:
    RefinerOpenAIView(prefs: prefs, keychain: keychain, openAIKeyEditor: openAIKeyEditor)
```

(Adicionar `keychain: KeychainService` no init de `PreferencesRoot` e na chamada do `AppContainer.openPreferences`.)

- [ ] **Step 4: Build + manual smoke**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -5
```

Manual:
- Abrir Preferências > Refiner > OpenAI.
- Trocar provider entre official/openrouter/lmstudio/custom: baseURL atualiza com defaults; custom mantém o que estava.
- Clicar "Alterar…": modal `OpenAIKeyPromptWindow` abre. Inserir key, fechar. Display atualiza pra "••••••••XXXX".
- Trocar modelo, fechar e reabrir janela: persiste.

- [ ] **Step 5: Commit**

```bash
git add app/Tagarela/Preferences/UI/Sections/RefinerOpenAIView.swift app/Tagarela/Preferences/UI/PreferencesRoot.swift app/Tagarela/UI/Onboarding/OpenAIKeyPromptWindow.swift app/Tagarela/App/AppContainer.swift
git commit -m "$(cat <<'EOF'
feat(preferences): seção Refiner > OpenAI com endpoints custom

- Provider segmented picker (official/openrouter/lmstudio/custom)
- Mudar provider auto-preenche baseURL com defaults da tabela
- TextField pro baseURL e modelo
- API key display masked + botão Alterar reabre OpenAIKeyPromptWindow
  existente
- Display da key refresh após modal fechar (best-effort 200ms)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 11: `StylesView` (cards) + `CustomStyleEditSheet`

**Files:**
- Modify: `app/Tagarela/Preferences/UI/Sections/StylesView.swift`
- Create: `app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift`
- Modify: `app/Tagarela/Preferences/UI/PreferencesRoot.swift` (passar `customStore`)

- [ ] **Step 1: `CustomStyleEditSheet`**

```swift
// app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift
import SwiftUI

@MainActor
struct CustomStyleEditSheet: View {
    enum Mode { case create, edit(CustomStyle) }
    let mode: Mode
    let customStore: CustomStyleStore
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var systemPrompt: String = ""
    @State private var appendCodeSwitching: Bool = true
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleLabel).font(.title2).bold()
            Form {
                LabeledContent(String(localized: "styles.edit.name", defaultValue: "Nome")) {
                    TextField("", text: $name).textFieldStyle(.roundedBorder)
                }
                Text(String(localized: "styles.edit.prompt", defaultValue: "System prompt")).font(.caption)
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 160)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
                Toggle(String(localized: "styles.edit.codeswitch",
                               defaultValue: "Anexar cláusula de code-switching"),
                       isOn: $appendCodeSwitching)
            }
            if let err = saveError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            HStack {
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancelar")) { onClose() }
                Button(String(localized: "common.save", defaultValue: "Salvar")) { Task { await save() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || systemPrompt.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 420)
        .onAppear { populate() }
    }

    private var titleLabel: String {
        switch mode {
        case .create: return String(localized: "styles.edit.title.create", defaultValue: "Novo estilo custom")
        case .edit:   return String(localized: "styles.edit.title.edit", defaultValue: "Editar estilo")
        }
    }

    private func populate() {
        if case .edit(let s) = mode {
            name = s.name
            systemPrompt = s.systemPrompt
            appendCodeSwitching = s.appendCodeSwitching
        }
    }

    private func save() async {
        do {
            switch mode {
            case .create:
                _ = try await customStore.create(name: name,
                                                  systemPrompt: systemPrompt,
                                                  appendCodeSwitching: appendCodeSwitching)
            case .edit(let s):
                s.name = name
                s.systemPrompt = systemPrompt
                s.appendCodeSwitching = appendCodeSwitching
                try await customStore.update(s)
            }
            onClose()
        } catch {
            saveError = String(localized: "styles.edit.save.failed",
                                defaultValue: "Não foi possível salvar: ") + String(describing: error)
        }
    }
}
```

- [ ] **Step 2: `StylesView` com cards grid**

```swift
// app/Tagarela/Preferences/UI/Sections/StylesView.swift
import SwiftUI
import AppKit

@MainActor
struct StylesView: View {
    @ObservedObject var prefs: PreferencesStore
    let customStore: CustomStyleStoreLive   // observed pra @Published styles

    @State private var sheetMode: CustomStyleEditSheet.Mode?
    @State private var showSheet = false

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(BuiltInStyles.all, id: \.id) { s in
                    builtInCard(s)
                }
                ForEach(customStore.styles, id: \.id) { c in
                    customCard(c)
                }
                addCard
            }
            .padding(20)
        }
        .task { await customStore.reload() }
        .sheet(isPresented: $showSheet, onDismiss: { sheetMode = nil }) {
            if let mode = sheetMode {
                CustomStyleEditSheet(mode: mode, customStore: customStore) {
                    showSheet = false
                }
            }
        }
    }

    private func builtInCard(_ style: Style) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(style.name).font(.headline)
                Spacer()
                Text(String(localized: "styles.badge.builtin", defaultValue: "PRONTO"))
                    .font(.caption2).foregroundStyle(.tint)
            }
            Text(style.systemPrompt.prefix(120) + (style.systemPrompt.count > 120 ? "…" : ""))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(prefs.selectedStyleID == style.id ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(prefs.selectedStyleID == style.id ? Color.accentColor : Color.secondary.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { prefs.selectedStyleID = style.id }
    }

    private func customCard(_ style: CustomStyle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(style.name).font(.headline)
                Spacer()
                Button { sheetMode = .edit(style); showSheet = true } label: {
                    Image(systemName: "pencil")
                }.buttonStyle(.plain)
            }
            Text(style.systemPrompt.prefix(120) + (style.systemPrompt.count > 120 ? "…" : ""))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(prefs.selectedStyleID == style.id ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(prefs.selectedStyleID == style.id ? Color.accentColor : Color.secondary.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button(String(localized: "styles.context.delete", defaultValue: "Apagar"), role: .destructive) {
                confirmAndDelete(style)
            }
        }
        .onTapGesture { prefs.selectedStyleID = style.id }
    }

    private var addCard: some View {
        Button { sheetMode = .create; showSheet = true } label: {
            VStack {
                Image(systemName: "plus.circle").font(.title)
                Text(String(localized: "styles.add", defaultValue: "Novo estilo custom"))
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])))
        }
        .buttonStyle(.plain)
    }

    private func confirmAndDelete(_ style: CustomStyle) {
        let alert = NSAlert()
        alert.messageText = String(localized: "styles.delete.confirm.title",
                                    defaultValue: "Apagar '\(style.name)'?")
        alert.informativeText = String(localized: "styles.delete.confirm.info",
                                        defaultValue: "Esta ação não pode ser desfeita.")
        alert.addButton(withTitle: String(localized: "common.delete", defaultValue: "Apagar"))
        alert.addButton(withTitle: String(localized: "common.cancel", defaultValue: "Cancelar"))
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            Task { try? await customStore.delete(style) }
        }
    }
}
```

- [ ] **Step 3: Atualizar `PreferencesRoot` pra passar `customStore` (concrete) ao StylesView**

```swift
case .estilos:
    if let live = customStore as? CustomStyleStoreLive {
        StylesView(prefs: prefs, customStore: live)
    } else {
        Text(String(localized: "styles.unavailable",
                     defaultValue: "Custom styles indisponíveis (armazenamento offline)"))
            .padding()
    }
```

- [ ] **Step 4: Build + manual smoke**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -5
```

Manual:
- Abrir Preferências > Estilos.
- Ver 4 cards built-in + card "+ Novo estilo custom" com borda dashed.
- Clicar "+ Novo": sheet abre vazio. Preencher nome="commits git", prompt="Mensagens de commit Conventional…", manter toggle on. Salvar.
- Card aparece na lista com lápis ✎ visível. Selecionável (clique no card).
- Editar: clicar lápis, mudar nome, salvar. Card reflete.
- Apagar: contextual menu (right-click), confirmar. Some.
- Apagar o style ativo: confirmar; após delete, o submenu da menubar mostra `conversa informal` selecionado.
- No submenu Style da status bar: custom criado aparece misturado aos built-ins.

- [ ] **Step 5: Commit**

```bash
git add app/Tagarela/Preferences/UI/Sections/StylesView.swift app/Tagarela/Preferences/UI/Sheets/CustomStyleEditSheet.swift app/Tagarela/Preferences/UI/PreferencesRoot.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(preferences): seção Estilos com cards + CustomStyleEditSheet CRUD

- StylesView: LazyVGrid de cards (built-ins read-only com badge PRONTO,
  custom com botão ✎, "+ Novo" dashed)
- Tap no card seleciona (atualiza prefs.selectedStyleID)
- Contextual menu sobre custom: Apagar com NSAlert de confirmação
- CustomStyleEditSheet: form name+prompt+codeSwitching, modo create/edit
- Validação inline (Salvar disabled se name/prompt vazios)
- Erros de save aparecem no sheet (sem toast — toasts vêm na 2b-2)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 12: Migração total Localizable

**Files:**
- Create: `tools/audit_strings.swift`
- Modify: `app/Tagarela/**/*.swift` (todas as views/services com strings hardcoded)
- Modify: `app/Tagarela/Resources/Localizable.xcstrings`
- Create: `app/TagarelaTests/LocalizableKeysTests.swift`

- [ ] **Step 1: Escrever `tools/audit_strings.swift` (one-shot)**

```bash
mkdir -p /Users/tars/Dev/tagarela/tools
```

```swift
// tools/audit_strings.swift — uso: swift tools/audit_strings.swift
// Lista candidatos a strings hardcoded user-facing nas views/services.
import Foundation

let root = "/Users/tars/Dev/tagarela/app/Tagarela"

let patterns = [
    #"Text\(\s*"([^"]+)"\s*\)"#,
    #"Button\(\s*"([^"]+)"\s*\)"#,
    #"Label\(\s*"([^"]+)"#,
    #"\.alert\(\s*"([^"]+)"#,
    #"messageText\s*=\s*"([^"]+)""#,
]

let fm = FileManager.default
let enumerator = fm.enumerator(atPath: root)!
var hits: [(file: String, line: Int, match: String)] = []

for case let path as String in enumerator where path.hasSuffix(".swift") {
    let full = (root as NSString).appendingPathComponent(path)
    guard let content = try? String(contentsOfFile: full, encoding: .utf8) else { continue }
    let lines = content.components(separatedBy: "\n")
    for (idx, line) in lines.enumerated() {
        if line.contains("String(localized:") { continue }
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: line) {
                hits.append((path, idx + 1, String(line[range])))
            }
        }
    }
}

hits.forEach { print("\($0.file):\($0.line)\t\($0.match)") }
print("\nTotal: \(hits.count) candidatos.")
```

```bash
cd /Users/tars/Dev/tagarela
swift tools/audit_strings.swift > /tmp/audit-strings.txt
wc -l /tmp/audit-strings.txt
head -50 /tmp/audit-strings.txt
```

- [ ] **Step 2: Migrar mecanicamente cada string**

Pra cada hit, abrir o arquivo, transformar em `String(localized: "section.subsection.key", defaultValue: "<original>")`. Padrão de chave:

| Local | Chave |
|---|---|
| `App/MenuBarController` | `menubar.<purpose>` |
| `Preferences/UI/Sections/...` | `preferences.<section>.<purpose>` |
| `Pipeline/...` (errors) | `pipeline.<state>.<purpose>` |
| `App/...` (alerts/onboarding) | `app.<flow>.<purpose>` |
| Common (Cancelar/Salvar/etc) | `common.<purpose>` |

(Boa fração já foi feita na 2a — começar pelos arquivos da Fase 1.)

Exemplo de migração:

Antes:
```swift
Text("Iniciar ditado")
```

Depois:
```swift
Text(String(localized: "menubar.start", defaultValue: "Iniciar ditado"))
```

Iterar até `audit_strings.swift` retornar 0 candidatos OR só candidatos justificadamente ignorados (ex: log strings, debug).

- [ ] **Step 3: Atualizar `Localizable.xcstrings`**

Como `defaultValue:` está no código, o Xcode 15+ extrai automaticamente na próxima build. Após build:

```bash
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela build 2>&1 | tail -5
```

Conferir que `Localizable.xcstrings` tem todas as chaves novas (rolar no Xcode).

- [ ] **Step 4: Smoke test em `LocalizableKeysTests`**

```swift
// app/TagarelaTests/LocalizableKeysTests.swift
import XCTest

final class LocalizableKeysTests: XCTestCase {
    /// Smoke: chaves principais resolvem em pt-BR (não retornam a key bruta).
    func test_principalKeys_resolveInPtBR() {
        let keys = [
            "preferences.section.geral",
            "preferences.section.estilos",
            "preferences.refiner.openai.provider.header",
            "preferences.audio.maxgain.label",
            "preferences.shortcuts.toggle",
            "styles.add",
            "common.cancel",
            "common.save",
        ]
        for k in keys {
            let resolved = String(localized: String.LocalizationValue(k))
            XCTAssertNotEqual(resolved, k, "chave '\(k)' não resolve em Localizable")
        }
    }
}
```

- [ ] **Step 5: Build + testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela test 2>&1 | tail -5
```

Esperado: ** TEST SUCCEEDED **, +1 teste.

- [ ] **Step 6: Commit**

```bash
git add tools/audit_strings.swift app/Tagarela/**/*.swift app/Tagarela/Resources/Localizable.xcstrings app/TagarelaTests/LocalizableKeysTests.swift app/Tagarela.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(i18n): migração total de strings user-facing pra Localizable.xcstrings

- script tools/audit_strings.swift (one-shot) lista candidatos a hardcoded
- todas Text/Button/Label/alert das Fases 1+2a+2b-1 trocadas por
  String(localized: "key", defaultValue: "...")
- chaves seguem padrão <section>.<subsection>.<purpose>
- pt-BR é a base; sem traduções nesta fase
- LocalizableKeysTests faz smoke das 8 chaves principais

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 13: Checklist manual `fase2b1-manual.md`

**Files:**
- Create: `tagarela_docs/03-funcionalidades/checklists/fase2b1-manual.md`

- [ ] **Step 1: Criar o checklist**

```markdown
---
data: 2026-04-XX
status: aberto
fase: 2b-1
ambiente: macOS 26 (build de Debug); Ollama rodando local com gemma4:e4b
---

# Checklist manual — Fase 2b-1

Aceite manual após implementação completa. Rodar com defaults zerados (`defaults delete com.tagarela.Tagarela; rm -rf ~/Library/Application\ Support/com.tagarela`).

## 0. Pré-requisitos
- [ ] Suíte XCTest verde (`xcodebuild test`).
- [ ] Build sem warnings novos.
- [ ] `ollama list` mostra `gemma4:e4b`.

## 1. Janela de Preferências (shell + nav)
- [ ] `⌘,` abre a janela.
- [ ] `Tagarela > Preferências…` (menubar) abre a mesma janela.
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
- [ ] Provider segmented: 4 opções.
- [ ] Selecionar OpenRouter → baseURL atualiza pra `https://openrouter.ai/api/v1`.
- [ ] Selecionar URL custom → baseURL fica editável e mantém o valor anterior.
- [ ] Modelo é editável (free text).
- [ ] API key: "Não configurada" inicialmente.
- [ ] Clicar "Alterar…" → modal abre, inserir key dummy `sk-test-1234`, fechar. Display vira `••••••••1234`.

## 6. Estilos
- [ ] Grid mostra 4 built-in cards (badge PRONTO) + card "+ Novo" dashed.
- [ ] Tap num card built-in seleciona (highlight + persiste em `prefs.selectedStyleID`).
- [ ] "+ Novo": sheet abre vazio, "Salvar" disabled.
- [ ] Preencher nome="commits git", prompt curto, salvar → card aparece com lápis.
- [ ] Tap no novo card seleciona; submenu Style da menubar mostra "commits git" misturado aos built-ins, ordenado.
- [ ] Lápis no card abre sheet pré-preenchido. Salvar atualiza.
- [ ] Right-click no card custom → "Apagar" → NSAlert. Confirmar → some.
- [ ] Apagar o style ativo → automaticamente volta pra `conversa informal`.

## 7. Áudio
- [ ] Slider mostra `prefs.audioBoostMaxGain` atual.
- [ ] Step de 1× nas pontas.
- [ ] Range respeita 1–50.

## 8. Histórico
- [ ] `historyMaxItems` e `historyMaxDays` editáveis. Valores persistem.

## 9. Vocabulário
- [ ] TextEditor mostra um termo por linha.
- [ ] Editar (adicionar termo, remover) persiste.

## 10. Atalhos
- [ ] Read-only: `⌥ direito` e `Esc`.

## 11. Localizable
- [ ] Nenhuma string visível em inglês na UI (exceto "OpenAI", nomes de modelos, etc).
- [ ] `LocalizableKeysTests` verde.

## 12. Pipeline runtime (regressão)
- [ ] Capturar com Ollama + estilo built-in: completa em < 30s, `refinerKind=ollama` no histórico.
- [ ] Capturar com Ollama + custom style criado na T11: refiner usa o systemPrompt correto (validar via log "transcribed:" + diferença visível no output).
- [ ] OpenAI com key válida: idem, completa.
- [ ] OpenAI com endpoint LM Studio (local): se LM Studio estiver rodando, captura completa via baseURL custom.
- [ ] Cancel via Esc durante recording: volta pra idle.
- [ ] OpenAI raw "ola" (curto): pulado, retorna "ola" sem erro nem chamada à API.

## 13. Resultado
- [ ] Todos os itens acima ✅. Marcar `status: ok` no frontmatter.
- [ ] Achados adicionais documentados em `tagarela_docs/04-decisoes/cleanup-fase2b1.md` (criar se houver).
```

- [ ] **Step 2: Commit do checklist**

```bash
git add tagarela_docs/03-funcionalidades/checklists/fase2b1-manual.md
git commit -m "$(cat <<'EOF'
docs(checklist): aceite manual da Fase 2b-1

13 seções cobrindo shell da janela, todas as seções, custom styles
CRUD, runtime regression, e Localizable smoke. Rodar com defaults
zerados.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 14: Aceite manual completo + doc closeout

**Files:**
- Update: `tagarela_docs/03-funcionalidades/checklists/fase2b1-manual.md` (status `ok` ou `ok-com-achados`)
- Update: `tagarela_docs/04-decisoes/cleanup-fase2a.md` (frontmatter — só #2 e #5 abertos agora)
- Update: `tagarela_docs/README.md` (status da 2b-1 = "implementado")
- Update: `tagarela_docs/specs/2026-04-29-tagarela-v1-fase2b1-design.md` (frontmatter `status: implementado`)
- Create: `tagarela_docs/02-arquitetura/03-modulos-fase2b1.md` (snapshot dos módulos pós-2b-1)
- Create (se houver achados): `tagarela_docs/04-decisoes/cleanup-fase2b1.md`
- Update: `~/.claude/projects/-Users-tars-Dev-tagarela/memory/achados_fase2a.md` (item #3 fechado)

- [ ] **Step 1: Rodar o checklist manual completo**

Resetar defaults:
```bash
defaults delete com.tagarela.Tagarela 2>/dev/null
rm -rf ~/Library/Application\ Support/com.tagarela
```

Buildar fresh, rodar, executar cada item da Tarefa 13 marcando ✅ ou anotando achado.

- [ ] **Step 2: Marcar checklist como ok**

Atualizar frontmatter do `fase2b1-manual.md` pra `status: ok` (ou `ok-com-achados`).

- [ ] **Step 3: Atualizar cleanup-fase2a.md**

Marcar item #3 como FECHADO (foi pago na T2). Frontmatter continua "parcialmente fechado" (#2 e #5 ainda abertos).

- [ ] **Step 4: Criar `02-arquitetura/03-modulos-fase2b1.md`**

Snapshot tipo `01-modulos-fase1.md`/`02-modulos-fase2a.md`: lista os módulos pós-2b-1, divergências do plano, cobertura de testes (~107-117), o que ficou pra 2b-2/2b-3.

- [ ] **Step 5: Atualizar `tagarela_docs/README.md`**

Mudar status da 2b-1 pra "implementado". Apontar pro novo doc de arquitetura.

- [ ] **Step 6: Atualizar memória** `~/.claude/projects/-Users-tars-Dev-tagarela/memory/achados_fase2a.md`

Marcar item #3 como ✅ fechado em 2026-04-XX. Atualizar descrição do `description:` no frontmatter.

- [ ] **Step 7: Atualizar frontmatter do design da 2b-1**

```yaml
status: implementado  # antes: aprovado para implementação
```

- [ ] **Step 8: Commit final + merge pra main**

```bash
git add tagarela_docs/03-funcionalidades/checklists/fase2b1-manual.md tagarela_docs/04-decisoes/cleanup-fase2a.md tagarela_docs/02-arquitetura/03-modulos-fase2b1.md tagarela_docs/README.md tagarela_docs/specs/2026-04-29-tagarela-v1-fase2b1-design.md
git commit -m "$(cat <<'EOF'
docs: fechamento da Fase 2b-1 — checklist manual ok, cleanup #3 fechado

- fase2b1-manual.md: status ok (XX itens validados)
- 03-modulos-fase2b1.md: snapshot pós-2b-1 (~107-117 testes)
- cleanup-fase2a.md item #3 fechado (guard de raw curto no OpenAI)
- README do vault: 2b-1 status = implementado
- spec frontmatter: implementado

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

# merge pra main
git checkout main
git merge --no-ff fase-2b1 -m "Merge fase-2b1 into main: tela de Preferências + custom styles + endpoints custom + Localizable total"
```

(Se houver achados, criar `cleanup-fase2b1.md` antes do commit final, listando-os com data limite ~2 semanas.)

---

## Self-review (gates de fim de fase)

Antes de declarar fim:

- [ ] Suíte verde: ~107-117 testes, 0 falhas. (`xcodebuild test` final.)
- [ ] Doc de design (`fase2b1-design.md`) com `status: implementado`.
- [ ] Doc de arquitetura (`03-modulos-fase2b1.md`) reflete módulos reais.
- [ ] Checklist manual com `status: ok`.
- [ ] `tagarela_docs/04-decisoes/cleanup-fase2a.md` marca #3 como fechado.
- [ ] Não há strings hardcoded user-facing remanescentes (`audit_strings.swift` retorna 0 ou só candidatos justificados).
- [ ] `git log --oneline main..fase-2b1` mostra ~14 commits (um por tarefa) com co-author.
- [ ] `defaults read com.tagarela.Tagarela` exibe valores configurados via UI (não via CLI).
