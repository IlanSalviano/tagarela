---
data: 2026-04-27
status: pronto pra execução
fase: 2a de 3
goal: ditado refinado por LLM funcionando end-to-end, configurável sem `defaults write`, com persistência durável
---

# tagarela v1 — Fase 2a: Persistência + LLM funcionando

> **Para agentes de execução:** SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendado) ou `superpowers:executing-plans`. Tarefas usam checkbox (`- [ ]`).
>
> **Antes de qualquer tarefa:** ler [`/CLAUDE.md`](../../CLAUDE.md), [`tagarela_docs/specs/2026-04-27-tagarela-v1-fase2a-design.md`](./2026-04-27-tagarela-v1-fase2a-design.md), [`02-arquitetura/01-modulos-fase1.md`](../02-arquitetura/01-modulos-fase1.md), [`04-decisoes/cleanup-fase1.md`](../04-decisoes/cleanup-fase1.md). **Antes de marcar uma tarefa como concluída:** atualizar a doc afetada.

**Goal:** Implementar a infraestrutura de persistência (`PreferencesStore`, `HistoryStore`, `KeychainService`) e os três refiners do design v1 (`OpenAIRefiner`, `OllamaRefiner`, `IdentityRefiner`) atrás do protocolo `TextRefiner`, com mínima UI funcional na status bar (dois submenus + modal de API key) para tornar a 2a usável sem editar UserDefaults ou Keychain pelo CLI. Inclui cleanups #2 (initialPrompt → promptTokens) e #4 (audioBoostMaxGain).

**Architecture:** Sobre a Fase 1, adicionar (a) `PreferencesStore` Combine-publishing, (b) `KeychainService` atrás de protocolo, (c) `Style` + 4 built-ins, (d) refiners HTTP com `BaseRemoteRefiner` compartilhado, (e) `RefinerFactory` lendo prefs, (f) `HistoryStore` SwiftData com retenção, (g) `MenuBarContent` com submenus radio + modal `NSPanel` para API key. `PipelineCoordinator` ganha `historyStore.save` e `actualRefinerKind` semântico.

**Tech stack:** mesmo da Fase 1 + SwiftData, Security.framework, URLSession (sem novas SPMs).

**Não está nesta fase:** tela de Preferências, menu "últimos 5", indicadores B/C/D, toasts, estados visuais de permissão, migração total Localizable, custom styles, endpoints OpenAI custom, cleanup #3 (stderr → Logger). Ver [`fase2a-design.md` §1.3](./2026-04-27-tagarela-v1-fase2a-design.md#13-não-objetivos-da-2a-vão-para-2b).

---

## File structure desta fase

Adições/modificações sobre Fase 1 (raiz `app/Tagarela/`):

```
app/Tagarela/
├── Preferences/
│   ├── PreferencesStore.swift              # NOVO — ObservableObject + @Published
│   ├── Preferences+Defaults.swift          # NOVO — defaults centralizados
│   ├── KeychainService.swift               # NOVO — protocol + KeychainError
│   └── KeychainServiceLive.swift           # NOVO — Security.framework wrapper
├── Refiner/
│   ├── TextRefiner.swift                   # (Fase 1)
│   ├── IdentityRefiner.swift               # (Fase 1)
│   ├── Style.swift                         # NOVO
│   ├── BuiltInStyles.swift                 # NOVO — 4 prompts hardcoded
│   ├── RefinerError.swift                  # NOVO — enum semântico
│   ├── RefinerErrorMapper.swift            # NOVO — URLError + HTTP → RefinerError
│   ├── TokenCounter.swift                  # NOVO — chars/4 estimate
│   ├── RemoteRefinerConfig.swift           # NOVO — tabela contextWindow por modelo
│   ├── BaseRemoteRefiner.swift             # NOVO — trunca-com-marcador, retry
│   ├── OpenAIRefiner.swift                 # NOVO
│   ├── OllamaRefiner.swift                 # NOVO
│   ├── OllamaHealthChecker.swift           # NOVO — GET /api/tags + cache 30s
│   └── RefinerFactory.swift                # NOVO — lê prefs e devolve impl
├── History/
│   ├── Transcription.swift                 # NOVO — @Model SwiftData
│   ├── HistoryStore.swift                  # NOVO — protocol
│   ├── HistoryStoreLive.swift              # NOVO — SwiftData impl
│   └── HistoryStoreNoop.swift              # NOVO — fallback se container falha
├── UI/
│   ├── MenuBar/
│   │   ├── MenuBarContent.swift            # MODIFICAR — incorpora submenus
│   │   ├── BackendSubmenu.swift            # NOVO
│   │   └── StyleSubmenu.swift              # NOVO
│   └── Onboarding/
│       └── OpenAIKeyPromptWindow.swift     # NOVO — NSPanel modal
├── Resources/
│   └── DefaultVocabulary.swift             # NOVO — array hardcoded ~30-50 termos
├── Audio/
│   └── AudioCaptureLive.swift              # MODIFICAR — audioBoostMaxGain injetado
├── Transcription/
│   └── WhisperKitTranscriber.swift         # MODIFICAR — promptTokens via tokenizer
├── Pipeline/
│   └── PipelineCoordinator.swift           # MODIFICAR — historyStore.save + actualRefinerKind
├── App/
│   └── AppContainer.swift                  # MODIFICAR — wire-up novos módulos
└── Localization/
    └── pt-BR.lproj/Localizable.strings     # MODIFICAR — adicionar chaves novas

app/TagarelaTests/
├── Helpers/
│   └── MockURLProtocol.swift               # NOVO
├── PreferencesStoreTests.swift             # NOVO
├── KeychainServiceTests.swift              # NOVO
├── StyleTests.swift                        # NOVO
├── RefinerErrorMapperTests.swift           # NOVO
├── TokenCounterTests.swift                 # NOVO
├── OpenAIRefinerTests.swift                # NOVO
├── OllamaRefinerTests.swift                # NOVO
├── HistoryStoreTests.swift                 # NOVO
└── PipelineCoordinatorTests.swift          # MODIFICAR — adições
```

Documentação atualizada por esta fase em `tagarela_docs/`:
- `02-arquitetura/01-modulos-fase1.md` → renomear/superseder com `02-modulos-fase2a.md` (ou versão evoluída — decisão da Tarefa 16)
- `03-funcionalidades/checklists/fase2a-manual.md` (criar) — checklist manual de aceite
- `03-funcionalidades/checklists/fase2-validacao-prompt.md` (criar) — A/B do cleanup #2
- `04-decisoes/cleanup-fase1.md` (atualizar) — fechar #2 e #4
- `04-decisoes/ADR-0002-*.md` (criar conforme decisões emergirem)

---

## Convenções desta fase

Mesmas da Fase 1, reforçando:

- **Idioma:** strings de UI novas em `Localizable.strings` (pt-BR). Identificadores Swift em inglês.
- **Concorrência:** `actor` ou `@MainActor` pra estado mutável. `@unchecked Sendable` apenas onde inevitável (SwiftData ModelContainer).
- **Erros:** cada módulo expõe `enum {Modulo}Error: Error`. Sem `Error` genérico.
- **Logging:** `Logger(subsystem: "com.tagarela", category: <nome>)` (não `FileHandle.standardError.write` — cleanup #3 fica como está, mas código novo já entra com `Logger`).
- **Sem dados sensíveis em log:** nada de API key, texto cru, texto refinado. Permitido: refiner kind, modelo, status code, duração da chamada, error case.
- **TDD:** lógica pura → teste primeiro. UI/SwiftUI → preview + checklist manual.
- **Commits:** um commit por tarefa (ou alguns commits relacionados), mensagem em pt-BR no estilo `tipo(escopo): descrição`.
- **xcodegen é a fonte da verdade do projeto Xcode.** Após criar/mover arquivos, sempre rodar `xcodegen generate` em `/Users/tars/Dev/tagarela/app/`.

---

## Pre-flight (antes de começar a Tarefa 1)

- [ ] **Confirmar `main` está limpo e em verde.**

```bash
cd /Users/tars/Dev/tagarela
git status                                    # working tree clean
git log -1 --oneline                          # último: b2fd6b3 docs(spec): adicionar design da Fase 2a
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -5
# expected: ** TEST SUCCEEDED ** com 16 testes verdes
```

- [ ] **Confirmar Ollama instalado e rodando localmente** (necessário pra checklist manual; não bloqueia código):

```bash
brew list | grep -q ollama && curl -s http://localhost:11434/api/tags > /dev/null && echo "ok" || echo "instalar/iniciar ollama antes da Tarefa 6"
```

Se faltar: `brew install ollama && ollama serve` em outro terminal.

- [ ] **Confirmar API key da OpenAI à mão** (env var ou nota). Vai ser usada na Tarefa 5 e na Tarefa 12.

- [ ] **Limpar artefatos do diagnóstico anterior** se existirem:

```bash
rm -rf ~/Library/Logs/tagarela/diag ~/Library/Logs/tagarela/diag-prefix
```

---

## Tarefa 1: `PreferencesStore` + Defaults

**Files:**
- Create: `app/Tagarela/Preferences/PreferencesStore.swift`
- Create: `app/Tagarela/Preferences/Preferences+Defaults.swift`
- Create: `app/TagarelaTests/PreferencesStoreTests.swift`

- [ ] **Step 1.1: Criar pasta `Preferences/`** (vazia se não existir; xcodegen pega via `type: folder` indireto pelo `path: Tagarela`).

```bash
mkdir -p /Users/tars/Dev/tagarela/app/Tagarela/Preferences
```

- [ ] **Step 1.2: Escrever `Preferences+Defaults.swift`.**

```swift
import Foundation

enum PreferencesKey {
    static let refinerKind          = "com.tagarela.preferences.refinerKind"
    static let selectedStyleID      = "com.tagarela.preferences.selectedStyleID"
    static let openAIModel          = "com.tagarela.preferences.openAIModel"
    static let ollamaBaseURL        = "com.tagarela.preferences.ollamaBaseURL"
    static let ollamaModel          = "com.tagarela.preferences.ollamaModel"
    static let refinerTimeoutSec    = "com.tagarela.preferences.refinerTimeoutSec"
    static let technicalVocabulary  = "com.tagarela.preferences.technicalVocabulary"
    static let historyMaxItems      = "com.tagarela.preferences.historyMaxItems"
    static let historyMaxDays       = "com.tagarela.preferences.historyMaxDays"
    static let audioBoostMaxGain    = "com.tagarela.preferences.audioBoostMaxGain"
}

enum RefinerKind: String, Codable, CaseIterable, Sendable {
    case none
    case openai
    case ollama
}

enum PreferencesDefaults {
    static let refinerKind: RefinerKind   = .none
    static let openAIModel: String        = "gpt-5.4-mini"
    static let ollamaBaseURL: String      = "http://localhost:11434"
    static let ollamaModel: String        = "qwen3.5:9b-nvfp4"
    static let refinerTimeoutSec: Double  = 30
    static let historyMaxItems: Int       = 200
    static let historyMaxDays: Int        = 30
    static let audioBoostMaxGain: Float   = 20.0
    static let audioBoostMaxGainRange: ClosedRange<Float> = 1...50
}
```

- [ ] **Step 1.3: Escrever `PreferencesStore.swift`.**

```swift
import Combine
import Foundation

/// Wrapper de UserDefaults com properties @Published pra Combine.
/// Single source of truth pra config persistente que precisa reagir em UI.
@MainActor
final class PreferencesStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var refinerKind: RefinerKind {
        didSet { defaults.set(refinerKind.rawValue, forKey: PreferencesKey.refinerKind) }
    }
    @Published var selectedStyleID: UUID {
        didSet { defaults.set(selectedStyleID.uuidString, forKey: PreferencesKey.selectedStyleID) }
    }
    @Published var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: PreferencesKey.openAIModel) }
    }
    @Published var ollamaBaseURL: String {
        didSet { defaults.set(ollamaBaseURL, forKey: PreferencesKey.ollamaBaseURL) }
    }
    @Published var ollamaModel: String {
        didSet { defaults.set(ollamaModel, forKey: PreferencesKey.ollamaModel) }
    }
    @Published var refinerTimeoutSec: Double {
        didSet { defaults.set(refinerTimeoutSec, forKey: PreferencesKey.refinerTimeoutSec) }
    }
    @Published var technicalVocabulary: [String] {
        didSet { defaults.set(technicalVocabulary, forKey: PreferencesKey.technicalVocabulary) }
    }
    @Published var historyMaxItems: Int {
        didSet { defaults.set(historyMaxItems, forKey: PreferencesKey.historyMaxItems) }
    }
    @Published var historyMaxDays: Int {
        didSet { defaults.set(historyMaxDays, forKey: PreferencesKey.historyMaxDays) }
    }
    @Published var audioBoostMaxGain: Float {
        didSet {
            let clamped = min(max(audioBoostMaxGain, PreferencesDefaults.audioBoostMaxGainRange.lowerBound),
                              PreferencesDefaults.audioBoostMaxGainRange.upperBound)
            if clamped != audioBoostMaxGain {
                audioBoostMaxGain = clamped // dispara didSet de novo, persiste
                return
            }
            defaults.set(audioBoostMaxGain, forKey: PreferencesKey.audioBoostMaxGain)
        }
    }

    init(defaults: UserDefaults = .standard,
         defaultStyleID: UUID) {
        self.defaults = defaults

        let kindRaw = defaults.string(forKey: PreferencesKey.refinerKind) ?? PreferencesDefaults.refinerKind.rawValue
        self.refinerKind = RefinerKind(rawValue: kindRaw) ?? PreferencesDefaults.refinerKind

        let idRaw = defaults.string(forKey: PreferencesKey.selectedStyleID)
        self.selectedStyleID = idRaw.flatMap(UUID.init(uuidString:)) ?? defaultStyleID

        self.openAIModel = defaults.string(forKey: PreferencesKey.openAIModel)
            ?? PreferencesDefaults.openAIModel
        self.ollamaBaseURL = defaults.string(forKey: PreferencesKey.ollamaBaseURL)
            ?? PreferencesDefaults.ollamaBaseURL
        self.ollamaModel = defaults.string(forKey: PreferencesKey.ollamaModel)
            ?? PreferencesDefaults.ollamaModel
        self.refinerTimeoutSec = defaults.object(forKey: PreferencesKey.refinerTimeoutSec) as? Double
            ?? PreferencesDefaults.refinerTimeoutSec
        self.technicalVocabulary = defaults.stringArray(forKey: PreferencesKey.technicalVocabulary)
            ?? [] // populado depois pelo init do AppContainer com DefaultVocabulary.terms
        self.historyMaxItems = defaults.object(forKey: PreferencesKey.historyMaxItems) as? Int
            ?? PreferencesDefaults.historyMaxItems
        self.historyMaxDays = defaults.object(forKey: PreferencesKey.historyMaxDays) as? Int
            ?? PreferencesDefaults.historyMaxDays
        self.audioBoostMaxGain = defaults.object(forKey: PreferencesKey.audioBoostMaxGain) as? Float
            ?? PreferencesDefaults.audioBoostMaxGain
    }
}
```

- [ ] **Step 1.4: Escrever `PreferencesStoreTests.swift`.**

```swift
import XCTest
@testable import Tagarela

@MainActor
final class PreferencesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "tagarela.tests.preferences"
    private let dummyStyleID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func test_defaults_match_designV1() {
        let store = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        XCTAssertEqual(store.refinerKind, .none)
        XCTAssertEqual(store.selectedStyleID, dummyStyleID)
        XCTAssertEqual(store.openAIModel, "gpt-5.4-mini")
        XCTAssertEqual(store.ollamaBaseURL, "http://localhost:11434")
        XCTAssertEqual(store.ollamaModel, "qwen3.5:9b-nvfp4")
        XCTAssertEqual(store.refinerTimeoutSec, 30)
        XCTAssertEqual(store.historyMaxItems, 200)
        XCTAssertEqual(store.historyMaxDays, 30)
        XCTAssertEqual(store.audioBoostMaxGain, 20.0)
    }

    func test_setRefinerKind_persistsAcrossInit() {
        let s1 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s1.refinerKind = .ollama
        let s2 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        XCTAssertEqual(s2.refinerKind, .ollama)
    }

    func test_setSelectedStyleID_persistsAcrossInit() {
        let newID = UUID()
        let s1 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s1.selectedStyleID = newID
        let s2 = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        XCTAssertEqual(s2.selectedStyleID, newID)
    }

    func test_audioBoostMaxGain_clampedToRange() {
        let s = PreferencesStore(defaults: defaults, defaultStyleID: dummyStyleID)
        s.audioBoostMaxGain = 100   // > 50
        XCTAssertEqual(s.audioBoostMaxGain, 50)
        s.audioBoostMaxGain = 0.1   // < 1
        XCTAssertEqual(s.audioBoostMaxGain, 1)
    }
}
```

- [ ] **Step 1.5: Regenerar projeto Xcode + rodar tests.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: `** TEST SUCCEEDED **` com 20 testes (16 + 4 novos).

- [ ] **Step 1.6: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Preferences app/TagarelaTests/PreferencesStoreTests.swift app/Tagarela.xcodeproj
git commit -m "feat(prefs): PreferencesStore com @Published + defaults centralizados"
```

**Critério de aceite:** PreferencesStore carrega defaults conforme spec §4.2; mudanças persistem em UserDefaults e via sink do Combine; range de `audioBoostMaxGain` é forçado [1,50]; 4 testes verdes.

---

## Tarefa 2: `KeychainService`

**Files:**
- Create: `app/Tagarela/Preferences/KeychainService.swift`
- Create: `app/Tagarela/Preferences/KeychainServiceLive.swift`
- Create: `app/TagarelaTests/KeychainServiceTests.swift`

- [ ] **Step 2.1: Escrever protocol + erros + fake (in-memory) em `KeychainService.swift`.**

```swift
import Foundation

protocol KeychainService: Sendable {
    func openAIKey() throws -> String?
    func setOpenAIKey(_ key: String?) throws // nil deleta
}

enum KeychainError: Error, Equatable {
    case osStatus(OSStatus)
    case invalidEncoding
}

/// Fake in-memory pra testes. Nunca toca Keychain real.
final class FakeKeychainService: KeychainService, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?

    init(initial: String? = nil) { self.stored = initial }

    func openAIKey() throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    func setOpenAIKey(_ key: String?) throws {
        lock.lock(); defer { lock.unlock() }
        stored = key
    }
}
```

- [ ] **Step 2.2: Escrever `KeychainServiceLive.swift`.**

```swift
import Foundation
import Security

/// Wrapper de Security.framework pra `account: "openai-api-key"` no service "com.tagarela".
final class KeychainServiceLive: KeychainService, @unchecked Sendable {
    private let service = "com.tagarela"
    private let account = "openai-api-key"
    private let access  = kSecAttrAccessibleAfterFirstUnlock

    func openAIKey() throws -> String? {
        var query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.osStatus(status) }
        guard let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidEncoding
        }
        return s
    }

    func setOpenAIKey(_ key: String?) throws {
        // Sempre delete + insert pra evitar attr races
        let baseQuery: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  account,
        ]
        let delStatus = SecItemDelete(baseQuery as CFDictionary)
        if delStatus != errSecSuccess && delStatus != errSecItemNotFound {
            throw KeychainError.osStatus(delStatus)
        }
        guard let key, let data = key.data(using: .utf8) else { return }
        var addQuery = baseQuery
        addQuery[kSecValueData as String]   = data
        addQuery[kSecAttrAccessible as String] = access
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.osStatus(addStatus) }
    }
}
```

- [ ] **Step 2.3: Escrever `KeychainServiceTests.swift`.**

```swift
import XCTest
@testable import Tagarela

final class KeychainServiceTests: XCTestCase {
    func test_setKey_thenGet_returnsKey() throws {
        let svc = FakeKeychainService()
        try svc.setOpenAIKey("sk-abc")
        XCTAssertEqual(try svc.openAIKey(), "sk-abc")
    }

    func test_setNil_deletesKey() throws {
        let svc = FakeKeychainService(initial: "sk-abc")
        try svc.setOpenAIKey(nil)
        XCTAssertNil(try svc.openAIKey())
    }

    func test_getWhenAbsent_returnsNil() throws {
        let svc = FakeKeychainService()
        XCTAssertNil(try svc.openAIKey())
    }

    /// Smoke test no Keychain real. Marca depois e limpa no tearDown.
    func test_live_setAndGet_smoke() throws {
        let live = KeychainServiceLive()
        try live.setOpenAIKey("sk-tagarela-test")
        defer { _ = try? live.setOpenAIKey(nil) }
        XCTAssertEqual(try live.openAIKey(), "sk-tagarela-test")
    }
}
```

- [ ] **Step 2.4: Regenerar + rodar.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: 24 testes verdes (20 + 4).

- [ ] **Step 2.5: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Preferences/KeychainService*.swift app/TagarelaTests/KeychainServiceTests.swift app/Tagarela.xcodeproj
git commit -m "feat(prefs): KeychainService com Live (Security.framework) + Fake in-memory"
```

**Critério de aceite:** Live persiste/lê/deleta a key no Keychain real do macOS; Fake é determinístico e não toca filesystem; 4 testes verdes.

---

## Tarefa 3: `RefinerError` + `RefinerErrorMapper` + `TokenCounter` + `RemoteRefinerConfig`

**Files:**
- Create: `app/Tagarela/Refiner/RefinerError.swift`
- Create: `app/Tagarela/Refiner/RefinerErrorMapper.swift`
- Create: `app/Tagarela/Refiner/TokenCounter.swift`
- Create: `app/Tagarela/Refiner/RemoteRefinerConfig.swift`
- Create: `app/TagarelaTests/RefinerErrorMapperTests.swift`
- Create: `app/TagarelaTests/TokenCounterTests.swift`

- [ ] **Step 3.1: Escrever `RefinerError.swift`.**

```swift
import Foundation

enum RefinerError: Error, Equatable, Sendable {
    case networkOffline
    case unauthorized
    case timedOut
    case serverError(Int)
    case rateLimited
    case contextExceeded
    case modelNotFound(String)
    case malformedResponse
    case cancelled
}
```

- [ ] **Step 3.2: Escrever `RefinerErrorMapper.swift`.**

```swift
import Foundation

enum RefinerErrorMapper {
    static func from(_ error: Error) -> RefinerError {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost:
                return .networkOffline
            case .timedOut:
                return .timedOut
            case .cancelled:
                return .cancelled
            default:
                return .networkOffline
            }
        }
        if let r = error as? RefinerError { return r }
        return .malformedResponse
    }

    static func from(httpStatus: Int, body: Data) -> RefinerError {
        switch httpStatus {
        case 401: return .unauthorized
        case 404:
            if let s = String(data: body, encoding: .utf8),
               s.lowercased().contains("model") {
                return .modelNotFound(extractModelName(s) ?? "?")
            }
            return .serverError(404)
        case 429: return .rateLimited
        case 400:
            if let s = String(data: body, encoding: .utf8)?.lowercased(),
               s.contains("context_length") || s.contains("context window") {
                return .contextExceeded
            }
            return .serverError(400)
        case 500...599: return .serverError(httpStatus)
        default: return .serverError(httpStatus)
        }
    }

    private static func extractModelName(_ body: String) -> String? {
        // Matches: model followed by quoted token (handles both escaped and unescaped quotes).
        // Pattern: 'model' + optional space + optional backslash + quote + name + optional backslash + quote
        let patterns = [
            // Escaped quotes: model \"name\"
            try? NSRegularExpression(pattern: "model\\s+\\\\\"([A-Za-z0-9._:\\-]{1,63})\\\\\"", options: []),
            // Unescaped quotes: model "name"
            try? NSRegularExpression(pattern: "model\\s+\"([A-Za-z0-9._:\\-]{1,63})\"", options: [])
        ]

        let nsBody = body as NSString
        for pattern in patterns.compactMap({ $0 }) {
            if let match = pattern.firstMatch(in: body, options: [], range: NSRange(location: 0, length: nsBody.length)),
               let range = Range(match.range(at: 1), in: body) {
                return String(body[range])
            }
        }
        return nil
    }
}
```

- [ ] **Step 3.3: Escrever `TokenCounter.swift`.**

```swift
import Foundation

/// Estimativa rápida e barata. Não é tokenizer real — usado só pra decidir
/// se vale truncar antes da chamada HTTP.
enum TokenCounter {
    static func estimate(_ text: String) -> Int {
        max(1, text.count / 4)
    }
}
```

- [ ] **Step 3.4: Escrever `RemoteRefinerConfig.swift`.**

```swift
import Foundation

/// Tabela de context windows aproximadas por modelo. Usada por BaseRemoteRefiner
/// pra decidir se trunca antes de chamar a API.
enum RemoteRefinerConfig {
    static let conservativeFallback = 8_000

    static func contextWindow(for modelName: String) -> Int {
        let lower = modelName.lowercased()
        if lower.hasPrefix("gpt-5.4") { return 200_000 }
        // Cobre qwen3.5:*, qwen3.0:* etc — todas as variantes Qwen3 tem janela ~32k.
        if lower.hasPrefix("qwen3")   { return 32_768 }
        if lower.hasPrefix("llama3.2"){ return 128_000 }
        return conservativeFallback
    }

    /// Reserva 20% pra completion + system prompt.
    static let usableFraction: Double = 0.8
}
```

- [ ] **Step 3.5: Escrever `RefinerErrorMapperTests.swift`.**

```swift
import XCTest
@testable import Tagarela

final class RefinerErrorMapperTests: XCTestCase {
    func test_urlError_notConnected_mapsToNetworkOffline() {
        let e = URLError(.notConnectedToInternet)
        XCTAssertEqual(RefinerErrorMapper.from(e), .networkOffline)
    }

    func test_urlError_timedOut_mapsToTimedOut() {
        let e = URLError(.timedOut)
        XCTAssertEqual(RefinerErrorMapper.from(e), .timedOut)
    }

    func test_http401_mapsToUnauthorized() {
        XCTAssertEqual(
            RefinerErrorMapper.from(httpStatus: 401, body: Data()),
            .unauthorized)
    }

    func test_http429_mapsToRateLimited() {
        XCTAssertEqual(
            RefinerErrorMapper.from(httpStatus: 429, body: Data()),
            .rateLimited)
    }

    func test_http500_mapsToServerError() {
        XCTAssertEqual(
            RefinerErrorMapper.from(httpStatus: 503, body: Data()),
            .serverError(503))
    }

    func test_http400_withContextLength_mapsToContextExceeded() {
        let body = Data(#"{"error":"context_length_exceeded"}"#.utf8)
        XCTAssertEqual(
            RefinerErrorMapper.from(httpStatus: 400, body: body),
            .contextExceeded)
    }

    func test_http404_withModelMessage_mapsToModelNotFound() {
        let body = Data(#"{"error":"model \"qwen3.5\" not found"}"#.utf8)
        if case let .modelNotFound(name) = RefinerErrorMapper.from(httpStatus: 404, body: body) {
            XCTAssertEqual(name, "qwen3.5")
        } else {
            XCTFail("expected .modelNotFound")
        }
    }

    func test_http404_withUnquotedModelMessage_returnsQuestionMark() {
        let body = Data(#"{"error":"model qwen3.5 not found"}"#.utf8)
        if case let .modelNotFound(name) = RefinerErrorMapper.from(httpStatus: 404, body: body) {
            XCTAssertEqual(name, "?")
        } else {
            XCTFail("expected .modelNotFound")
        }
    }

    func test_urlError_cancelled_mapsToCancelled() {
        let e = URLError(.cancelled)
        XCTAssertEqual(RefinerErrorMapper.from(e), .cancelled)
    }
}
```

- [ ] **Step 3.6: Escrever `TokenCounterTests.swift`.**

```swift
import XCTest
@testable import Tagarela

final class TokenCounterTests: XCTestCase {
    func test_emptyString_returnsAtLeast1() {
        XCTAssertEqual(TokenCounter.estimate(""), 1)
    }

    func test_8chars_returns2() {
        XCTAssertEqual(TokenCounter.estimate("abcdefgh"), 2)
    }

    func test_largeText_estimateBatesMargem() {
        let s = String(repeating: "a", count: 10_000)
        let est = TokenCounter.estimate(s)
        XCTAssertGreaterThan(est, 2000)
        XCTAssertLessThan(est, 3000)
    }
}
```

- [ ] **Step 3.6: Escrever `RemoteRefinerConfigTests.swift` (adição).**

```swift
import XCTest
@testable import Tagarela

final class RemoteRefinerConfigTests: XCTestCase {
    func test_gpt54_returns200k() {
        XCTAssertEqual(RemoteRefinerConfig.contextWindow(for: "gpt-5.4-mini"), 200_000)
        XCTAssertEqual(RemoteRefinerConfig.contextWindow(for: "GPT-5.4"), 200_000) // case insensitive
    }

    func test_qwen3DefaultModel_returns32k() {
        XCTAssertEqual(RemoteRefinerConfig.contextWindow(for: "qwen3.5:9b-nvfp4"), 32_768)
    }

    func test_llama32_returns128k() {
        XCTAssertEqual(RemoteRefinerConfig.contextWindow(for: "llama3.2:3b"), 128_000)
    }

    func test_unknownModel_returnsConservativeFallback() {
        XCTAssertEqual(
            RemoteRefinerConfig.contextWindow(for: "gemma:2b"),
            RemoteRefinerConfig.conservativeFallback)
    }

    func test_usableFraction_isPointEight() {
        XCTAssertEqual(RemoteRefinerConfig.usableFraction, 0.8, accuracy: 0.001)
    }
}
```

- [ ] **Step 3.7: Regenerar + rodar.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: 43 testes verdes (36 + 7 novos: 3 RefinerErrorMapper + 1 cancelled + 5 RemoteRefinerConfig).

- [ ] **Step 3.8: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Refiner/RefinerError.swift app/Tagarela/Refiner/RefinerErrorMapper.swift app/Tagarela/Refiner/TokenCounter.swift app/Tagarela/Refiner/RemoteRefinerConfig.swift app/TagarelaTests/RefinerErrorMapperTests.swift app/TagarelaTests/TokenCounterTests.swift app/TagarelaTests/RemoteRefinerConfigTests.swift app/Tagarela.xcodeproj tagarela_docs/specs/2026-04-27-tagarela-v1-fase2a-plan.md
git commit -m "fix(refiner): extractModelName via regex + .cancelled + cobertura RemoteRefinerConfig

Resolve Critical/Important do code review da Tarefa 3:
- extractModelName usa regex pra capturar token quotado após \"model\"; agora retorna o nome do modelo correto.
- Adicionado RefinerError.cancelled + mapping de URLError.cancelled.
- Comentário inline em RemoteRefinerConfig sobre qwen3.
- Novo RemoteRefinerConfigTests cobre 4 caminhos da tabela.
- Teste de modelo sem aspas valida fallback gracioso.
- Plan atualizado."
```

**Critério de aceite:** extractModelName captura corretamente o nome (qwen3.5) do body com escaped quotes; URLError.cancelled mapeia para .cancelled; tabela contextWindow cobre 4 modelos; 43 testes verdes.

---

## Tarefa 4: `Style` + `BuiltInStyles` + `DefaultVocabulary`

**Files:**
- Create: `app/Tagarela/Refiner/Style.swift`
- Create: `app/Tagarela/Refiner/BuiltInStyles.swift`
- Create: `app/Tagarela/Resources/DefaultVocabulary.swift`
- Create: `app/TagarelaTests/StyleTests.swift`

- [ ] **Step 4.1: Escrever `Style.swift`.**

```swift
import Foundation

struct Style: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let systemPrompt: String
    let preserveOrality: Bool
    let isBuiltIn: Bool
}
```

- [ ] **Step 4.2: Escrever `BuiltInStyles.swift`.**

UUIDs literais hardcoded — assim `selectedStyleID` salvo em UserDefaults numa run continua válido em rebuilds.

```swift
import Foundation

enum BuiltInStyles {
    private static let codeSwitchingClause = """

    Preserve termos técnicos em inglês conforme o uso comum em desenvolvimento de software brasileiro \
    (ex: cloud, deploy, pool, pattern, mutex). Corrija fonetizações óbvias do Whisper \
    (ex: 'loquei' → 'log it', 'diploiei' → 'deployei'). \
    Se preservar oralidade está ativo, mantenha contrações orais ('tô', 'pra', 'cê').
    """

    static let conversaInformal = Style(
        id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
        name: "conversa informal",
        systemPrompt: """
        Você refina ditados de voz em português brasileiro.
        Remova muletas ('tipo', 'aí', 'então' repetidos), corrija pontuação e \
        capitalização, mas mantenha o tom informal e a estrutura da fala. \
        Não adicione informação que não estava no original.
        """ + codeSwitchingClause,
        preserveOrality: true,
        isBuiltIn: true)

    static let emailProfissional = Style(
        id: UUID(uuidString: "11111111-0000-0000-0000-000000000002")!,
        name: "e-mail profissional",
        systemPrompt: """
        Você refina ditados de voz pra virarem texto de e-mail profissional em \
        português brasileiro. Use estrutura clara, tom cordial mas direto, \
        pontuação completa. Corrija oralidades e contrações ('tô' → 'estou', \
        'pra' → 'para'). Não adicione informação que não estava no original.
        """ + codeSwitchingClause,
        preserveOrality: false,
        isBuiltIn: true)

    static let notasTecnicas = Style(
        id: UUID(uuidString: "11111111-0000-0000-0000-000000000003")!,
        name: "notas técnicas",
        systemPrompt: """
        Você refina ditados de voz pra virarem notas técnicas em português \
        brasileiro. Estrutura concisa, frases diretas, pontuação clara. \
        Preserve nomes próprios, siglas e termos técnicos exatamente como ditos. \
        Não adicione interpretação além do que foi dito.
        """ + codeSwitchingClause,
        preserveOrality: false,
        isBuiltIn: true)

    static let cruSemReescrita = Style(
        id: UUID(uuidString: "11111111-0000-0000-0000-000000000004")!,
        name: "cru — sem reescrita",
        systemPrompt: "",  // sentinel: pipeline pula refiner inteiro
        preserveOrality: true,
        isBuiltIn: true)

    static let all: [Style] = [conversaInformal, emailProfissional, notasTecnicas, cruSemReescrita]

    static func style(for id: UUID) -> Style? {
        all.first { $0.id == id }
    }

    static let defaultStyleID: UUID = conversaInformal.id
}
```

- [ ] **Step 4.3: Escrever `DefaultVocabulary.swift`.**

```swift
import Foundation

enum DefaultVocabulary {
    static let terms: [String] = [
        // ferramentas
        "Postgres", "Kubernetes", "Docker", "Slack", "Linear", "Notion",
        "GitHub", "GitLab", "Jira", "VS Code", "Xcode",
        // ações de dev
        "deploy", "deployei", "commit", "commitei", "push", "pushei",
        "pull request", "merge", "rebase", "revert", "scope", "scopei",
        "log it", "logei", "run", "runei",
        // conceitos
        "bug", "feature flag", "endpoint", "payload", "request", "response",
        "header", "body", "cache", "queue", "mutex", "actor", "async",
        "await", "closure", "struct", "enum",
        // domínio
        "cloud", "pool", "pattern", "hook", "lifecycle", "refactor", "lint",
        "build", "webhook", "websocket", "gRPC", "REST", "GraphQL",
        "JSON", "YAML",
    ]
}
```

- [ ] **Step 4.4: Escrever `StyleTests.swift`.**

```swift
import XCTest
@testable import Tagarela

final class StyleTests: XCTestCase {
    func test_4builtIns_haveDistinctIDs() {
        let ids = Set(BuiltInStyles.all.map(\.id))
        XCTAssertEqual(ids.count, 4)
    }

    func test_systemPrompt_includesCodeSwitchingClause_whenNotCru() {
        for s in BuiltInStyles.all where s.id != BuiltInStyles.cruSemReescrita.id {
            XCTAssertTrue(s.systemPrompt.contains("desenvolvimento de software brasileiro"),
                          "style \(s.name) sem cláusula code-switching")
        }
    }

    func test_cru_hasEmptySystemPrompt() {
        XCTAssertTrue(BuiltInStyles.cruSemReescrita.systemPrompt.isEmpty)
    }

    func test_defaultStyleID_pointsToConversaInformal() {
        XCTAssertEqual(BuiltInStyles.defaultStyleID, BuiltInStyles.conversaInformal.id)
    }
}
```

- [ ] **Step 4.5: Regenerar + rodar.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: 38 testes verdes (34 + 4).

- [ ] **Step 4.6: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Refiner/Style.swift app/Tagarela/Refiner/BuiltInStyles.swift app/Tagarela/Resources/DefaultVocabulary.swift app/TagarelaTests/StyleTests.swift app/Tagarela.xcodeproj
git commit -m "feat(refiner): Style + 4 built-ins + DefaultVocabulary"
```

**Critério de aceite:** 4 styles com UUIDs hardcoded estáveis, cláusula code-switching anexada (exceto cru), `cruSemReescrita.systemPrompt` vazio (sentinel), DefaultVocabulary tem ≥30 termos; 4 testes verdes.

---

## Tarefa 5: `MockURLProtocol` + `BaseRemoteRefiner` + `OpenAIRefiner`

**Files:**
- Create: `app/TagarelaTests/Helpers/MockURLProtocol.swift`
- Create: `app/Tagarela/Refiner/BaseRemoteRefiner.swift`
- Create: `app/Tagarela/Refiner/OpenAIRefiner.swift`
- Create: `app/TagarelaTests/OpenAIRefinerTests.swift`

- [ ] **Step 5.1: Escrever `MockURLProtocol.swift`.**

```swift
import Foundation

final class MockURLProtocol: URLProtocol {
    typealias Responder = (URLRequest) throws -> (HTTPURLResponse, Data)

    nonisolated(unsafe) static var responder: Responder?

    static func session() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: cfg)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = MockURLProtocol.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown)); return
        }
        do {
            let (resp, data) = try responder(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

- [ ] **Step 5.2: Escrever `BaseRemoteRefiner.swift`.**

```swift
import Foundation

/// Helpers compartilhados entre OpenAIRefiner e OllamaRefiner: trunca-com-marcador,
/// retry de 1× ao exceder context, error mapping comum.
enum BaseRemoteRefiner {
    static let truncationMarker = "[…texto cortado…]"

    /// Retorna texto truncado se exceder context window. Mantém primeiros 40% chars +
    /// marker + últimos 40%. Se já cabe, retorna `nil` (não precisa truncar).
    static func truncatedIfNeeded(_ text: String, modelName: String, systemTokens: Int) -> String? {
        let estimated = TokenCounter.estimate(text) + systemTokens
        let window = RemoteRefinerConfig.contextWindow(for: modelName)
        let usable = Int(Double(window) * RemoteRefinerConfig.usableFraction)
        if estimated <= usable { return nil }

        let chars = Array(text)
        let cut = chars.count * 4 / 10  // 40% chars de cada ponta
        let head = String(chars[0..<cut])
        let tail = String(chars[(chars.count - cut)..<chars.count])
        return head + truncationMarker + tail
    }
}
```

- [ ] **Step 5.3: Escrever `OpenAIRefiner.swift`.**

```swift
import Foundation
import OSLog

final class OpenAIRefiner: TextRefiner, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "OpenAIRefiner")
    private let session: URLSession
    private let keychain: KeychainService
    private let model: String
    private let timeoutSec: TimeInterval
    private let baseURL = URL(string: "https://api.openai.com/v1")!

    init(session: URLSession, keychain: KeychainService, model: String, timeoutSec: TimeInterval) {
        self.session = session
        self.keychain = keychain
        self.model = model
        self.timeoutSec = timeoutSec
    }

    var kind: String { "openai" }

    func refine(_ rawText: String, style: Style) async throws -> String {
        guard let key = try keychain.openAIKey(), !key.isEmpty else {
            throw RefinerError.unauthorized
        }
        let systemTokens = TokenCounter.estimate(style.systemPrompt)
        let textToSend: String
        if let truncated = BaseRemoteRefiner.truncatedIfNeeded(rawText, modelName: model, systemTokens: systemTokens) {
            textToSend = truncated
        } else {
            textToSend = rawText
        }
        do {
            return try await chat(rawText: textToSend, style: style, key: key)
        } catch RefinerError.contextExceeded {
            logger.info("contextExceeded, retry with hard truncation")
            // se já vinha truncado, força um truncamento mais agressivo
            let chars = Array(textToSend)
            let cut = chars.count * 3 / 10  // 30% cada ponta agora
            let hard = String(chars[0..<cut]) + BaseRemoteRefiner.truncationMarker + String(chars[(chars.count-cut)..<chars.count])
            return try await chat(rawText: hard, style: style, key: key)
        }
    }

    private func chat(rawText: String, style: Style, key: String) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        req.httpMethod = "POST"
        req.timeoutInterval = timeoutSec
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": style.systemPrompt],
                ["role": "user",   "content": rawText],
            ],
            "temperature": 0.3,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RefinerError.malformedResponse }
        if http.statusCode != 200 {
            throw RefinerErrorMapper.from(httpStatus: http.statusCode, body: data)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else { throw RefinerError.malformedResponse }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

> O `TextRefiner` protocol vem da Fase 1. Verificar (`app/Tagarela/Refiner/TextRefiner.swift`) que assinatura aceita `style: Style`. Caso a assinatura existente seja `(text, style: String)`, atualizar pra `(text, style: Style)` e adaptar `IdentityRefiner` + `PipelineCoordinator` no Step 5.4.

- [ ] **Step 5.4: Atualizar `TextRefiner` protocol e `IdentityRefiner`** se necessário.

Abrir `app/Tagarela/Refiner/TextRefiner.swift`. Garantir:

```swift
import Foundation

protocol TextRefiner: Sendable {
    var kind: String { get }
    func refine(_ rawText: String, style: Style) async throws -> String
}
```

Atualizar `IdentityRefiner.swift`:

```swift
final class IdentityRefiner: TextRefiner, @unchecked Sendable {
    var kind: String { "none" }
    func refine(_ rawText: String, style: Style) async throws -> String {
        return rawText
    }
}
```

Atualizar `PipelineCoordinator.runTranscribeAndInject` pra passar `style: Style` em vez de `style: String`. Como `RefinerFactory` ainda não existe, usar temporariamente: `await refiner.refine(raw, style: BuiltInStyles.conversaInformal)`. Vai ser substituído na Tarefa 7.

- [ ] **Step 5.5: Escrever `OpenAIRefinerTests.swift`.**

```swift
import XCTest
@testable import Tagarela

final class OpenAIRefinerTests: XCTestCase {
    private var keychain: FakeKeychainService!

    override func setUp() async throws {
        keychain = FakeKeychainService(initial: "sk-fake")
        MockURLProtocol.responder = nil
    }

    override func tearDown() async throws {
        MockURLProtocol.responder = nil
    }

    private func makeRefiner(timeout: TimeInterval = 30) -> OpenAIRefiner {
        OpenAIRefiner(session: MockURLProtocol.session(),
                      keychain: keychain,
                      model: "gpt-5.4-mini",
                      timeoutSec: timeout)
    }

    private func httpResp(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/chat/completions")!,
                        statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private func successBody(_ content: String) -> Data {
        let json: [String: Any] = ["choices": [["message": ["content": content]]]]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    func test_success_returnsRefinedText() async throws {
        MockURLProtocol.responder = { _ in (self.httpResp(200), self.successBody("texto refinado")) }
        let r = makeRefiner()
        let out = try await r.refine("texto cru", style: BuiltInStyles.conversaInformal)
        XCTAssertEqual(out, "texto refinado")
    }

    func test_unauthorized401_throwsUnauthorized() async {
        MockURLProtocol.responder = { _ in (self.httpResp(401), Data()) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .unauthorized)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_serverError500_throwsServerError() async {
        MockURLProtocol.responder = { _ in (self.httpResp(503), Data()) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .serverError(503))
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_timeout_throwsTimedOut() async {
        MockURLProtocol.responder = { _ in throw URLError(.timedOut) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .timedOut)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_rateLimited429_throwsRateLimited() async {
        MockURLProtocol.responder = { _ in (self.httpResp(429), Data()) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .rateLimited)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_malformedJSON_throwsMalformed() async {
        MockURLProtocol.responder = { _ in (self.httpResp(200), Data("not json".utf8)) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_missingChoicesField_throwsMalformed() async {
        MockURLProtocol.responder = { _ in (self.httpResp(200), Data(#"{"foo":"bar"}"#.utf8)) }
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_contextExceeded_truncatesAndRetries_succeedsOnSecondTry() async throws {
        var attempts = 0
        MockURLProtocol.responder = { _ in
            attempts += 1
            if attempts == 1 {
                return (self.httpResp(400), Data(#"{"error":"context_length_exceeded"}"#.utf8))
            }
            return (self.httpResp(200), self.successBody("ok"))
        }
        let r = makeRefiner()
        let out = try await r.refine(String(repeating: "a", count: 100), style: BuiltInStyles.conversaInformal)
        XCTAssertEqual(out, "ok")
        XCTAssertEqual(attempts, 2)
    }

    func test_contextExceededTwice_throwsContextExceeded() async {
        MockURLProtocol.responder = { _ in
            (self.httpResp(400), Data(#"{"error":"context_length_exceeded"}"#.utf8))
        }
        let r = makeRefiner()
        do {
            _ = try await r.refine(String(repeating: "a", count: 100), style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .contextExceeded)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_emptyApiKey_throwsUnauthorized_withoutHTTP() async {
        keychain = FakeKeychainService(initial: nil)
        let r = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .unauthorized)
        } catch { XCTFail("wrong error: \(error)") }
    }
}
```

- [ ] **Step 5.6: Regenerar + rodar.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: 48 testes verdes (38 + 10).

- [ ] **Step 5.7: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Refiner app/TagarelaTests app/Tagarela.xcodeproj
git commit -m "feat(refiner): OpenAIRefiner + BaseRemoteRefiner + MockURLProtocol"
```

**Milestone:** pipeline com OpenAI funcionando, configurável manualmente via Keychain + `defaults write com.tagarela.preferences refinerKind openai`. (Wire-up no AppContainer ainda vem na Tarefa 7.)

**Critério de aceite:** 10 testes do OpenAIRefiner verdes cobrindo success, 401, 5xx, timeout, 429, malformed, missing choices, contextExceeded retry, contextExceeded twice, empty key.

---

## Tarefa 6: `OllamaHealthChecker` + `OllamaRefiner`

**Files:**
- Create: `app/Tagarela/Refiner/OllamaHealthChecker.swift`
- Create: `app/Tagarela/Refiner/OllamaRefiner.swift`
- Create: `app/TagarelaTests/OllamaRefinerTests.swift`

- [ ] **Step 6.1: Escrever `OllamaHealthChecker.swift`.**

```swift
import Foundation

actor OllamaHealthChecker {
    private let session: URLSession
    private let baseURL: URL
    private let cacheTTL: TimeInterval = 30
    private var lastCheck: (timestamp: Date, ok: Bool)?

    init(session: URLSession, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Invalida cache. Chamar quando refinerKind ou ollamaBaseURL mudar.
    func invalidate() { lastCheck = nil }

    func isAvailable() async -> Bool {
        if let last = lastCheck, Date().timeIntervalSince(last.timestamp) < cacheTTL {
            return last.ok
        }
        let ok = await ping()
        lastCheck = (Date(), ok)
        return ok
    }

    private func ping() async -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        req.timeoutInterval = 2
        req.httpMethod = "GET"
        do {
            let (_, resp) = try await session.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
```

- [ ] **Step 6.2: Escrever `OllamaRefiner.swift`.**

```swift
import Foundation
import OSLog

final class OllamaRefiner: TextRefiner, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "OllamaRefiner")
    private let session: URLSession
    private let baseURL: URL
    private let model: String
    private let timeoutSec: TimeInterval
    private let healthChecker: OllamaHealthChecker

    init(session: URLSession,
         baseURL: URL,
         model: String,
         timeoutSec: TimeInterval,
         healthChecker: OllamaHealthChecker) {
        self.session = session
        self.baseURL = baseURL
        self.model = model
        self.timeoutSec = timeoutSec
        self.healthChecker = healthChecker
    }

    var kind: String { "ollama" }

    func refine(_ rawText: String, style: Style) async throws -> String {
        guard await healthChecker.isAvailable() else {
            throw RefinerError.networkOffline
        }
        let systemTokens = TokenCounter.estimate(style.systemPrompt)
        let textToSend = BaseRemoteRefiner.truncatedIfNeeded(rawText, modelName: model, systemTokens: systemTokens) ?? rawText
        do {
            return try await chat(rawText: textToSend, style: style)
        } catch RefinerError.contextExceeded {
            logger.info("contextExceeded, retry with hard truncation")
            let chars = Array(textToSend)
            let cut = chars.count * 3 / 10
            let hard = String(chars[0..<cut]) + BaseRemoteRefiner.truncationMarker + String(chars[(chars.count-cut)..<chars.count])
            return try await chat(rawText: hard, style: style)
        }
    }

    private func chat(rawText: String, style: Style) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
        req.httpMethod = "POST"
        req.timeoutInterval = timeoutSec
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": style.systemPrompt],
                ["role": "user",   "content": rawText],
            ],
            "options": ["temperature": 0.3],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RefinerError.malformedResponse }
        if http.statusCode != 200 {
            throw RefinerErrorMapper.from(httpStatus: http.statusCode, body: data)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String
        else { throw RefinerError.malformedResponse }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 6.3: Escrever `OllamaRefinerTests.swift`.**

```swift
import XCTest
@testable import Tagarela

final class OllamaRefinerTests: XCTestCase {
    override func setUp() async throws { MockURLProtocol.responder = nil }
    override func tearDown() async throws { MockURLProtocol.responder = nil }

    private let baseURL = URL(string: "http://localhost:11434")!

    private func httpResp(_ status: Int, path: String = "/api/chat") -> HTTPURLResponse {
        HTTPURLResponse(url: baseURL.appendingPathComponent(path),
                        statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private func successBody(_ content: String) -> Data {
        let json: [String: Any] = ["message": ["content": content]]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeRefiner() -> (OllamaRefiner, OllamaHealthChecker) {
        let session = MockURLProtocol.session()
        let hc = OllamaHealthChecker(session: session, baseURL: baseURL)
        let r = OllamaRefiner(session: session, baseURL: baseURL,
                              model: "qwen3.5:9b-nvfp4", timeoutSec: 30, healthChecker: hc)
        return (r, hc)
    }

    func test_healthCheckOffline_skipsChatAndThrowsOffline() async {
        var chatCalled = false
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                throw URLError(.cannotConnectToHost)
            }
            chatCalled = true
            return (self.httpResp(200), self.successBody("nope"))
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .networkOffline)
            XCTAssertFalse(chatCalled, "chat foi chamado mesmo com health offline")
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_healthCheckOnline_proceedsToChat() async throws {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (self.httpResp(200, path: "/api/tags"), Data("{}".utf8))
            }
            return (self.httpResp(200), self.successBody("refinado"))
        }
        let (r, _) = makeRefiner()
        let out = try await r.refine("cru", style: BuiltInStyles.conversaInformal)
        XCTAssertEqual(out, "refinado")
    }

    func test_healthCheckCache_avoidsDoubleCall() async throws {
        var tagsCalls = 0
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                tagsCalls += 1
                return (self.httpResp(200, path: "/api/tags"), Data("{}".utf8))
            }
            return (self.httpResp(200), self.successBody("ok"))
        }
        let (r, _) = makeRefiner()
        _ = try await r.refine("a", style: BuiltInStyles.conversaInformal)
        _ = try await r.refine("b", style: BuiltInStyles.conversaInformal)
        XCTAssertEqual(tagsCalls, 1, "cache 30s deveria ter evitado segunda chamada")
    }

    func test_modelNotFound404_throwsModelNotFound() async {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (self.httpResp(200, path: "/api/tags"), Data("{}".utf8))
            }
            return (self.httpResp(404), Data(#"{"error":"model \"qwen\" not found"}"#.utf8))
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            if case .modelNotFound = e { /* ok */ } else { XCTFail("expected .modelNotFound, got \(e)") }
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_serverError500_throwsServerError() async {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (self.httpResp(200, path: "/api/tags"), Data("{}".utf8))
            }
            return (self.httpResp(500), Data())
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .serverError(500))
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_timeout_throwsTimedOut() async {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (self.httpResp(200, path: "/api/tags"), Data("{}".utf8))
            }
            throw URLError(.timedOut)
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .timedOut)
        } catch { XCTFail("wrong error: \(error)") }
    }

    func test_malformed_throwsMalformed() async {
        MockURLProtocol.responder = { req in
            if req.url?.path.hasSuffix("/api/tags") == true {
                return (self.httpResp(200, path: "/api/tags"), Data("{}".utf8))
            }
            return (self.httpResp(200), Data("not json".utf8))
        }
        let (r, _) = makeRefiner()
        do {
            _ = try await r.refine("oi", style: BuiltInStyles.conversaInformal)
            XCTFail("expected throw")
        } catch let e as RefinerError {
            XCTAssertEqual(e, .malformedResponse)
        } catch { XCTFail("wrong error: \(error)") }
    }
}
```

- [ ] **Step 6.4: Regenerar + rodar.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: 55 testes verdes (48 + 7).

- [ ] **Step 6.5: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Refiner/OllamaRefiner.swift app/Tagarela/Refiner/OllamaHealthChecker.swift app/TagarelaTests/OllamaRefinerTests.swift app/Tagarela.xcodeproj
git commit -m "feat(refiner): OllamaRefiner + HealthChecker com cache 30s"
```

**Milestone:** pipeline com Ollama funcionando, configurável via `defaults write com.tagarela.preferences refinerKind ollama`. (Wire-up final na Tarefa 7.)

**Critério de aceite:** 7 testes verdes cobrindo health offline (skip /chat), online, cache evita double-call, 404 model, 5xx, timeout, malformed.

---

## Tarefa 7: `RefinerFactory` + wire-up no `AppContainer` + ajustes em `PipelineCoordinator`

**Files:**
- Create: `app/Tagarela/Refiner/RefinerFactory.swift`
- Modify: `app/Tagarela/App/AppContainer.swift`
- Modify: `app/Tagarela/Pipeline/PipelineCoordinator.swift`
- Modify: `app/TagarelaTests/PipelineCoordinatorTests.swift`

- [ ] **Step 7.1: Escrever `RefinerFactory.swift`.**

```swift
import Foundation

/// Lê estado atual do PreferencesStore + Keychain e devolve o TextRefiner concreto.
/// Não é thread-safe entre rebuilds — chamar a partir do PipelineCoordinator (que serializa).
@MainActor
final class RefinerFactory {
    private let prefs: PreferencesStore
    private let keychain: KeychainService
    private let openAI: () -> OpenAIRefiner
    private let ollama: () -> OllamaRefiner
    private let identity: IdentityRefiner

    init(prefs: PreferencesStore,
         keychain: KeychainService,
         openAI: @escaping () -> OpenAIRefiner,
         ollama: @escaping () -> OllamaRefiner,
         identity: IdentityRefiner = IdentityRefiner()) {
        self.prefs = prefs
        self.keychain = keychain
        self.openAI = openAI
        self.ollama = ollama
        self.identity = identity
    }

    /// (refiner, style ativo). Se cru — retorna identity independentemente da prefs.
    func current() -> (refiner: TextRefiner, style: Style) {
        let style = BuiltInStyles.style(for: prefs.selectedStyleID) ?? BuiltInStyles.conversaInformal
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

- [ ] **Step 7.2: Atualizar `PipelineCoordinator`.**

Modificações em `app/Tagarela/Pipeline/PipelineCoordinator.swift`:

(a) Trocar `private let refiner: TextRefiner` por:

```swift
private let refinerProvider: @MainActor () -> (refiner: TextRefiner, style: Style)
private let historyStore: HistoryStore  // PROTOCOL — vem da Tarefa 10
```

> **Nota de ordem:** este step assume `HistoryStore` já existe. A Tarefa 10 cria. Se executando em ordem estrita, fazer este step **após** a Tarefa 10. **Alternativa:** pular o `historyStore` neste step; adicionar `HistoryStore` na Tarefa 10. Recomendado: pular agora, adicionar na Tarefa 10. Ajustar `init` accordingly e marcar TODO.

Por ora (sem HistoryStore ainda), modificar pra:

```swift
private let refinerProvider: @MainActor () -> (refiner: TextRefiner, style: Style)

init(audio: AudioCapturing,
     transcriber: Transcribing,
     refinerProvider: @escaping @MainActor () -> (refiner: TextRefiner, style: Style),
     injector: Injecting,
     language: String = "pt",
     initialPromptProvider: @escaping @Sendable () -> String? = { nil }) {
    self.audio = audio
    self.transcriber = transcriber
    self.refinerProvider = refinerProvider
    self.injector = injector
    self.language = language
    self.initialPromptProvider = initialPromptProvider
    // …
}
```

(b) Em `runTranscribeAndInject`, trocar:

```swift
let refined = try await refiner.refine(raw, style: "cru — sem reescrita")
```

Por:

```swift
let (refiner, style) = await refinerProvider()
var actualRefinerKind = refiner.kind
let refined: String
do {
    refined = try await refiner.refine(raw, style: style)
} catch {
    logger.error("refiner failed (\(refiner.kind)): \(String(describing: error))")
    let identity = IdentityRefiner()
    refined = try await identity.refine(raw, style: style)
    actualRefinerKind = identity.kind
}
```

(c) Adicionar (placeholder pra Tarefa 10) — o pipeline ainda não salva história. Comentar `// TODO(tarefa-10): historyStore.save(...)`.

- [ ] **Step 7.3: Atualizar `AppContainer.swift`.**

```swift
// dentro do AppContainer (mantém estrutura existente, adicionar):
let prefs = PreferencesStore(defaults: .standard, defaultStyleID: BuiltInStyles.defaultStyleID)
// Popula vocab default na 1ª run (se vazio):
if prefs.technicalVocabulary.isEmpty {
    prefs.technicalVocabulary = DefaultVocabulary.terms
}
let keychain: KeychainService = KeychainServiceLive()
let session = URLSession.shared
let healthChecker = OllamaHealthChecker(
    session: session,
    baseURL: URL(string: prefs.ollamaBaseURL) ?? URL(string: "http://localhost:11434")!)
let factory = RefinerFactory(
    prefs: prefs,
    keychain: keychain,
    openAI: { [weak prefs, keychain] in
        guard let prefs else { fatalError("prefs deallocated") }
        return OpenAIRefiner(session: session,
                             keychain: keychain,
                             model: prefs.openAIModel,
                             timeoutSec: prefs.refinerTimeoutSec)
    },
    ollama: { [weak prefs, healthChecker] in
        guard let prefs else { fatalError("prefs deallocated") }
        return OllamaRefiner(
            session: session,
            baseURL: URL(string: prefs.ollamaBaseURL) ?? URL(string: "http://localhost:11434")!,
            model: prefs.ollamaModel,
            timeoutSec: prefs.refinerTimeoutSec,
            healthChecker: healthChecker)
    })

// Quando criar o pipeline, passar o factory:
let pipeline = PipelineCoordinator(
    audio: audio,
    transcriber: transcriber,
    refinerProvider: { factory.current() },
    injector: injector,
    initialPromptProvider: { /* prefs.technicalVocabulary etc — Tarefa 8 */ nil })
```

> **Observação:** invalidar cache do health checker quando `prefs.refinerKind` ou `prefs.ollamaBaseURL` mudar. Adicionar Combine sink no AppContainer (ou onde fizer sentido):

```swift
prefs.$refinerKind.dropFirst().sink { _ in Task { await healthChecker.invalidate() } }.store(in: &cancellables)
prefs.$ollamaBaseURL.dropFirst().sink { _ in Task { await healthChecker.invalidate() } }.store(in: &cancellables)
```

- [ ] **Step 7.4: Atualizar `PipelineCoordinatorTests` — 3 testes novos.**

Adicionar fakes locais e cenários:

```swift
final class FakeRefiner: TextRefiner, @unchecked Sendable {
    let kind: String
    let result: Result<String, Error>
    init(kind: String, result: Result<String, Error>) {
        self.kind = kind; self.result = result
    }
    func refine(_ rawText: String, style: Style) async throws -> String {
        switch result {
        case .success(let s): return s
        case .failure(let e): throw e
        }
    }
}

func test_refinerFails_fallsBackToIdentity_actualKindIsNone() async {
    let fakeAudio = FakeAudioCapture(buffer: AudioBuffer(samples: [Float](repeating: 0.1, count: 32_000), sampleRate: 16_000))
    let fakeTranscriber = FakeTranscriber(text: "cru")
    let fakeInjector = FakeInjector()
    let pipe = PipelineCoordinator(
        audio: fakeAudio,
        transcriber: fakeTranscriber,
        refinerProvider: {
            (FakeRefiner(kind: "openai", result: .failure(RefinerError.networkOffline)),
             BuiltInStyles.conversaInformal)
        },
        injector: fakeInjector)

    var injected: String?
    Task {
        for await ev in pipe.events {
            if case .finished(_, let refined, _) = ev { injected = refined }
        }
    }
    await pipe.handle(.toggle)
    await pipe.handle(.toggle)
    try? await Task.sleep(nanoseconds: 200_000_000)
    XCTAssertEqual(injected, "cru")  // identity passou o cru
}

func test_styleCru_skipsRefinerEntirely() async {
    // Style cru pula refiner via factory; FakeRefiner falha se chamado.
    // Aqui o provider retorna o IdentityRefiner direto — simulando o factory.
    let fakeAudio = FakeAudioCapture(buffer: AudioBuffer(samples: [Float](repeating: 0.1, count: 32_000), sampleRate: 16_000))
    let fakeTranscriber = FakeTranscriber(text: "cru")
    let fakeInjector = FakeInjector()
    let pipe = PipelineCoordinator(
        audio: fakeAudio,
        transcriber: fakeTranscriber,
        refinerProvider: { (IdentityRefiner(), BuiltInStyles.cruSemReescrita) },
        injector: fakeInjector)
    var injected: String?
    Task {
        for await ev in pipe.events {
            if case .finished(_, let refined, _) = ev { injected = refined }
        }
    }
    await pipe.handle(.toggle)
    await pipe.handle(.toggle)
    try? await Task.sleep(nanoseconds: 200_000_000)
    XCTAssertEqual(injected, "cru")
}
```

> 3º teste (cancel during refining cancela HTTP) — implementar usando `FakeRefiner` que segura num `Task.sleep` longo, disparar `pipe.handle(.cancel)` no meio, verificar que `state` voltou pra `.idle` sem `injected`.

- [ ] **Step 7.5: Build do app + tests.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: 58 testes verdes.

- [ ] **Step 7.6: Smoke manual rápido.**

```bash
defaults write com.tagarela.preferences refinerKind openai
# abrir o app instalado, garantir API key no Keychain via security CLI ou pelo modal (Tarefa 12)
# fazer 1 captura curta — texto deve voltar refinado
defaults write com.tagarela.preferences refinerKind ollama
# fazer 1 captura — texto refinado pelo Ollama
defaults write com.tagarela.preferences refinerKind none
# fazer 1 captura — texto cru
```

- [ ] **Step 7.7: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Refiner/RefinerFactory.swift app/Tagarela/App/AppContainer.swift app/Tagarela/Pipeline/PipelineCoordinator.swift app/TagarelaTests/PipelineCoordinatorTests.swift app/Tagarela.xcodeproj
git commit -m "feat(refiner): RefinerFactory + wire-up no AppContainer + fallback Identity"
```

**Critério de aceite:** trocar `refinerKind` via `defaults write` reflete na próxima captura sem rebuild; refiner que falha cai pra Identity automaticamente; style cru pula refiner; 3 testes novos verdes.

---

## Tarefa 8: Cleanup #2 — `promptTokens` via `WhisperKit.tokenizer`

**Files:**
- Modify: `app/Tagarela/Transcription/WhisperKitTranscriber.swift`
- Modify: `app/Tagarela/App/AppContainer.swift` (passar `prefs.technicalVocabulary` pro `initialPromptProvider`)
- Create: `tagarela_docs/03-funcionalidades/checklists/fase2-validacao-prompt.md`
- Modify: `tagarela_docs/04-decisoes/cleanup-fase1.md` (atualizar status do #2)

- [ ] **Step 8.1: Atualizar `WhisperKitTranscriber.swift`.**

```swift
func transcribe(buffer: AudioBuffer,
                language: String,
                initialPrompt: String?) async throws -> String {
    guard let pipe else { throw TranscribeError.modelNotLoaded }
    guard buffer.durationSeconds >= 0.5 else { throw TranscribeError.bufferTooShort }

    let promptTokens: [Int]?
    if ProcessInfo.processInfo.environment["TAGARELA_DISABLE_PROMPT"] == "1" {
        promptTokens = nil
    } else if let prompt = initialPrompt, !prompt.isEmpty,
              let tokenizer = pipe.tokenizer {
        let encoded = tokenizer.encode(text: prompt)
        promptTokens = encoded.isEmpty ? nil : encoded
    } else {
        promptTokens = nil
    }

    let opts = DecodingOptions(
        verbose: false,
        task: .transcribe,
        language: language,
        usePrefillPrompt: true,
        promptTokens: promptTokens,
        withoutTimestamps: true
    )

    do {
        let results: [TranscriptionResult] = try await pipe.transcribe(
            audioArray: buffer.samples,
            decodeOptions: opts
        )
        let text = results.map(\.text).joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        throw TranscribeError.transcriptionFailed(String(describing: error))
    }
}
```

> **Verificação API:** `WhisperKit.tokenizer` é uma propriedade da WhisperKit 0.18.x que expõe a tokenizer carregada com o modelo. Se o nome ou shape divergir, ajustar a partir do `WhisperKit` lib em `~/Library/Developer/Xcode/DerivedData/.../checkouts/WhisperKit/`. Se a API for incompatível, **fechar cleanup #2 com decisão (a)** (não usar promptTokens) e atualizar Step 8.5.

- [ ] **Step 8.2: Atualizar `AppContainer.swift` `initialPromptProvider`.**

```swift
let initialPromptProvider: @Sendable () -> String? = { [weak prefs] in
    guard let prefs else { return nil }
    let vocab = prefs.technicalVocabulary
    guard !vocab.isEmpty else { return nil }
    return InitialPromptBuilder.build(vocab: vocab)
}
```

(`InitialPromptBuilder` já existe da Fase 1.)

- [ ] **Step 8.3: Criar `tagarela_docs/03-funcionalidades/checklists/fase2-validacao-prompt.md`.**

```markdown
---
data: 2026-04-27
status: aberto
escopo: validação cleanup #2 (initialPrompt → promptTokens)
---

# Validação A/B do `promptTokens`

Cleanup #2 do `cleanup-fase1.md`. Pergunta: `promptTokens` melhora ou piora a transcrição em PT-BR técnico?

## Como rodar

Cada frase é capturada **duas vezes**:

1. App rodando normal: `open ~/Applications/Tagarela.app`
2. App rodando com prompt desligado: `TAGARELA_DISABLE_PROMPT=1 open ~/Applications/Tagarela.app`

Coletar texto cru via diag dump (reativar com `git show <commit-fix-downmix> -- app/Tagarela/Diagnostics/`) ou via log no Console.app filtrado por subsystem `com.tagarela`.

## Frases-teste (8)

1. Faz um deploy do Postgres na produção.
2. O Kubernetes está com problema de pool de conexões.
3. Mandei o pull request mas o linter quebrou.
4. A gente precisa scopar o webhook do Slack.
5. O endpoint da API GraphQL está retornando 500.
6. Não conseguimos fazer o merge porque o rebase quebrou.
7. O Linear ticket tá com a feature flag errada.
8. Vou commitar e fazer push da branch.

## Tabela de resultados

| # | Sem prompt | Com prompt | Termo técnico mantido? |
|---|---|---|---|
| 1 | _____ | _____ | ☐ Postgres ☐ deploy |
| 2 | _____ | _____ | ☐ Kubernetes ☐ pool |
| 3 | _____ | _____ | ☐ pull request ☐ linter |
| 4 | _____ | _____ | ☐ scopar ☐ webhook ☐ Slack |
| 5 | _____ | _____ | ☐ endpoint ☐ API ☐ GraphQL |
| 6 | _____ | _____ | ☐ merge ☐ rebase |
| 7 | _____ | _____ | ☐ Linear ☐ feature flag |
| 8 | _____ | _____ | ☐ commitar ☐ push ☐ branch |

## Decisão

- ☐ Prompt melhora (≥ 6/8 termos preservados a mais com prompt) → manter ON, fechar cleanup #2 critério (b)
- ☐ Prompt piora (≥ 2/8 frases pioraram com prompt vs sem) → manter OFF, ADR documentando, fechar cleanup #2 critério (a)
- ☐ Inconcluso → manter ON e revisar daqui a 2 meses

ADR `tagarela_docs/04-decisoes/ADR-0002-initialprompt-validacao.md` criado com a decisão.
```

- [ ] **Step 8.4: Executar checklist** (manual; usuário humano grava as 8 frases ×2 e preenche tabela).

- [ ] **Step 8.5: Registrar decisão.**

Criar `tagarela_docs/04-decisoes/ADR-0002-initialprompt-validacao.md` com Contexto/Decisão/Consequências/Alternativas conforme [convenções do README](../../tagarela_docs/README.md). **Atualizar** `cleanup-fase1.md` item 2 → status concluído com link pro ADR.

- [ ] **Step 8.6: Build + tests + commit.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -5
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Transcription/WhisperKitTranscriber.swift app/Tagarela/App/AppContainer.swift tagarela_docs/03-funcionalidades/checklists/fase2-validacao-prompt.md tagarela_docs/04-decisoes/cleanup-fase1.md tagarela_docs/04-decisoes/ADR-0002-initialprompt-validacao.md
git commit -m "feat(transcribe): promptTokens via WhisperKit.tokenizer (cleanup #1.2)"
```

**Critério de aceite:** Whisper recebe `promptTokens` quando vocab não-vazio e env não desativa; checklist A/B preenchido; ADR-0002 criado; cleanup #2 fechado.

---

## Tarefa 9: Cleanup #4 — `audioBoostMaxGain` configurável

**Files:**
- Modify: `app/Tagarela/Audio/AudioCaptureLive.swift`
- Modify: `app/Tagarela/App/AppContainer.swift`
- Modify: `tagarela_docs/04-decisoes/cleanup-fase1.md` (fechar #4)

- [ ] **Step 9.1: Modificar `AudioCaptureLive` pra receber `maxGainProvider`.**

```swift
final class AudioCaptureLive: AudioCapturing, @unchecked Sendable {
    // … propriedades existentes …
    private let maxGainProvider: @Sendable () -> Float

    init(maxGainProvider: @escaping @Sendable () -> Float = { 20.0 }) {
        self.maxGainProvider = maxGainProvider
        // … resto do init existente …
    }

    private func boostPeakNormalize(_ samples: [Float], targetPeak: Float = 0.6) -> [Float] {
        guard !samples.isEmpty else { return samples }
        var peak: Float = 0
        for s in samples { let a = abs(s); if a > peak { peak = a } }
        guard peak > 0.0001 else { return samples }
        let cap = maxGainProvider()  // ← era hardcoded 20
        let gain = min(targetPeak / peak, cap)
        return samples.map { s in max(-1, min(1, s * gain)) }
    }
}
```

- [ ] **Step 9.2: Atualizar `AppContainer.swift` pra injetar `prefs.audioBoostMaxGain`.**

```swift
let audioCapture = AudioCaptureLive(
    maxGainProvider: { [weak prefs] in
        prefs?.audioBoostMaxGain ?? PreferencesDefaults.audioBoostMaxGain
    })
```

- [ ] **Step 9.3: Build + smoke teste.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -5
# manual: defaults write com.tagarela.preferences audioBoostMaxGain -float 5
# gravar com gain 5 (esperado: voz quieta soa mais quieta no resultado refinado)
# defaults write com.tagarela.preferences audioBoostMaxGain -float 20  # restaurar
```

- [ ] **Step 9.4: Atualizar `cleanup-fase1.md` item 4 → status concluído.**

- [ ] **Step 9.5: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Audio/AudioCaptureLive.swift app/Tagarela/App/AppContainer.swift tagarela_docs/04-decisoes/cleanup-fase1.md app/Tagarela.xcodeproj
git commit -m "feat(audio): audioBoostMaxGain configurável via prefs (cleanup #1.4)"
```

**Critério de aceite:** boost cap lê de `prefs.audioBoostMaxGain`; mudar via `defaults write` reflete na próxima captura; range [1,50] enforced pelo PreferencesStore; cleanup #4 fechado.

---

## Tarefa 10: `HistoryStore` (SwiftData) + retenção + integração no `PipelineCoordinator`

**Files:**
- Create: `app/Tagarela/History/Transcription.swift`
- Create: `app/Tagarela/History/HistoryStore.swift`
- Create: `app/Tagarela/History/HistoryStoreLive.swift`
- Create: `app/Tagarela/History/HistoryStoreNoop.swift`
- Create: `app/TagarelaTests/HistoryStoreTests.swift`
- Modify: `app/Tagarela/Pipeline/PipelineCoordinator.swift`
- Modify: `app/Tagarela/App/AppContainer.swift`

- [x] **Step 10.1: Escrever `Transcription.swift`.**

```swift
import Foundation
import SwiftData

@Model
final class Transcription {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var durationSeconds: Double
    var rawText: String
    var refinedText: String
    var refinerKind: String        // "openai" | "ollama" | "none"
    var llmModelName: String?
    var whisperModelName: String
    var styleName: String
    var frontmostAppBundleID: String?

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         durationSeconds: Double,
         rawText: String,
         refinedText: String,
         refinerKind: String,
         llmModelName: String?,
         whisperModelName: String,
         styleName: String,
         frontmostAppBundleID: String?) {
        self.id = id
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.rawText = rawText
        self.refinedText = refinedText
        self.refinerKind = refinerKind
        self.llmModelName = llmModelName
        self.whisperModelName = whisperModelName
        self.styleName = styleName
        self.frontmostAppBundleID = frontmostAppBundleID
    }
}
```

- [x] **Step 10.2: Escrever `HistoryStore.swift` (protocol).**

```swift
import Foundation

struct TranscriptionInput: Sendable {
    let durationSeconds: Double
    let rawText: String
    let refinedText: String
    let refinerKind: String
    let llmModelName: String?
    let whisperModelName: String
    let styleName: String
    let frontmostAppBundleID: String?
}

protocol HistoryStore: Sendable {
    func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws
    func recent(limit: Int) async throws -> [Transcription]
}
```

- [x] **Step 10.3: Escrever `HistoryStoreLive.swift`.**

```swift
import Foundation
import OSLog
import SwiftData

@MainActor
final class HistoryStoreLive: HistoryStore {
    private let logger = Logger(subsystem: "com.tagarela", category: "History")
    private let container: ModelContainer

    init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent("com.tagarela.Tagarela", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("History.store")
        let config = ModelConfiguration(url: url)
        self.container = try ModelContainer(for: Transcription.self, configurations: config)
    }

    init(inMemory: Bool) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: Transcription.self, configurations: config)
    }

    func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws {
        let ctx = container.mainContext
        let t = Transcription(
            durationSeconds: input.durationSeconds,
            rawText: input.rawText,
            refinedText: input.refinedText,
            refinerKind: input.refinerKind,
            llmModelName: input.llmModelName,
            whisperModelName: input.whisperModelName,
            styleName: input.styleName,
            frontmostAppBundleID: input.frontmostAppBundleID)
        ctx.insert(t)
        try ctx.save()
        try applyRetention(maxItems: maxItems, maxDays: maxDays)
    }

    func recent(limit: Int) async throws -> [Transcription] {
        let ctx = container.mainContext
        var fd = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        fd.fetchLimit = limit
        return try ctx.fetch(fd)
    }

    private func applyRetention(maxItems: Int, maxDays: Int) throws {
        let ctx = container.mainContext
        // (1) Apaga por idade
        let cutoff = Date().addingTimeInterval(-Double(maxDays) * 86_400)
        let oldFD = FetchDescriptor<Transcription>(
            predicate: #Predicate { $0.createdAt < cutoff })
        for old in try ctx.fetch(oldFD) { ctx.delete(old) }

        // (2) Mantém só os top maxItems
        let allFD = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let all = try ctx.fetch(allFD)
        if all.count > maxItems {
            for extra in all.dropFirst(maxItems) { ctx.delete(extra) }
        }
        try ctx.save()
    }
}
```

- [x] **Step 10.4: Escrever `HistoryStoreNoop.swift`.**

```swift
import OSLog

/// Fallback usado quando o ModelContainer falha ao abrir.
final class HistoryStoreNoop: HistoryStore {
    private let logger = Logger(subsystem: "com.tagarela", category: "History")

    func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws {
        logger.error("HistoryStoreNoop: ignorando save — container indisponível")
    }

    func recent(limit: Int) async throws -> [Transcription] { [] }
}
```

- [x] **Step 10.5: Escrever `HistoryStoreTests.swift`.**

```swift
import XCTest
import SwiftData
@testable import Tagarela

@MainActor
final class HistoryStoreTests: XCTestCase {
    private func make() throws -> HistoryStoreLive {
        try HistoryStoreLive(inMemory: true)
    }

    private func sample(rawText: String = "cru",
                        createdOffsetDays: Double = 0) -> TranscriptionInput {
        TranscriptionInput(
            durationSeconds: 3.5, rawText: rawText, refinedText: "ref",
            refinerKind: "none", llmModelName: nil,
            whisperModelName: "large-v3", styleName: "conversa informal",
            frontmostAppBundleID: nil)
    }

    func test_save_persistsTranscription() async throws {
        let s = try make()
        try await s.save(sample(rawText: "abc"), maxItems: 100, maxDays: 30)
        let r = try await s.recent(limit: 10)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.rawText, "abc")
    }

    func test_recent_returnsNewestFirst() async throws {
        let s = try make()
        try await s.save(sample(rawText: "older"), maxItems: 100, maxDays: 30)
        try await Task.sleep(nanoseconds: 10_000_000)
        try await s.save(sample(rawText: "newer"), maxItems: 100, maxDays: 30)
        let r = try await s.recent(limit: 10)
        XCTAssertEqual(r.first?.rawText, "newer")
    }

    func test_retentionByCount_keepsTopN() async throws {
        let s = try make()
        for i in 0..<5 {
            try await s.save(sample(rawText: "n\(i)"), maxItems: 3, maxDays: 30)
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        let r = try await s.recent(limit: 10)
        XCTAssertEqual(r.count, 3)
    }

    func test_retentionByDays_purgesOld() async throws {
        let s = try make()
        // Insere uma com createdAt no passado, manualmente
        let ctx = ModelContext(try ModelContainer(
            for: Transcription.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let oldTrans = Transcription(
            createdAt: Date().addingTimeInterval(-60 * 86_400),
            durationSeconds: 1, rawText: "old", refinedText: "old",
            refinerKind: "none", llmModelName: nil,
            whisperModelName: "large-v3", styleName: "conversa informal",
            frontmostAppBundleID: nil)
        ctx.insert(oldTrans)
        try ctx.save()
        try await s.save(sample(rawText: "new"), maxItems: 100, maxDays: 30)
        let r = try await s.recent(limit: 10)
        XCTAssertFalse(r.contains { $0.rawText == "old" })
    }

    func test_retention_bothLimitsApply() async throws {
        let s = try make()
        for i in 0..<10 {
            try await s.save(sample(rawText: "n\(i)"), maxItems: 5, maxDays: 30)
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        let r = try await s.recent(limit: 100)
        XCTAssertEqual(r.count, 5)
    }

    func test_save_appliesRetentionImmediately() async throws {
        let s = try make()
        for _ in 0..<3 { try await s.save(sample(), maxItems: 2, maxDays: 30) }
        let r = try await s.recent(limit: 100)
        XCTAssertEqual(r.count, 2)
    }
}
```

- [x] **Step 10.6: Atualizar `PipelineCoordinator.swift`.**

(a) Adicionar `historyStore: HistoryStore` ao init.
(b) Adicionar property `prefs: PreferencesStore` (pra ler `historyMaxItems`/`historyMaxDays`).

> **Decisão de design:** PipelineCoordinator passa a depender de `PreferencesStore`. Como é actor, ler `@Published` de fora exige pegar valor via `await MainActor.run`. Pra evitar anti-padrão, melhor passar `historyMaxItemsProvider: @Sendable () -> Int` e `historyMaxDaysProvider: @Sendable () -> Int` ao init. Manter o coordinator sem conhecer prefs.

```swift
init(audio: AudioCapturing,
     transcriber: Transcribing,
     refinerProvider: @escaping @MainActor () -> (refiner: TextRefiner, style: Style),
     injector: Injecting,
     historyStore: HistoryStore,
     historyMaxItemsProvider: @escaping @Sendable () -> Int,
     historyMaxDaysProvider:  @escaping @Sendable () -> Int,
     language: String = "pt",
     initialPromptProvider: @escaping @Sendable () -> String? = { nil }) {
    // …
}
```

(c) No `runTranscribeAndInject`, após `injector.inject(...)`:

```swift
let frontApp = try await injector.inject(text: refined)
do {
    try await historyStore.save(
        TranscriptionInput(
            durationSeconds: buffer.durationSeconds,
            rawText: raw,
            refinedText: refined,
            refinerKind: actualRefinerKind,
            llmModelName: refinerKindLLMModel(actualRefinerKind),
            whisperModelName: transcriber.loadedModelName ?? "<unknown>",
            styleName: style.name,
            frontmostAppBundleID: frontApp),
        maxItems: historyMaxItemsProvider(),
        maxDays:  historyMaxDaysProvider())
} catch {
    logger.error("history save failed: \(String(describing: error))")
}
```

> `refinerKindLLMModel` é uma helper local: para `"openai"` retorna `prefs.openAIModel`, para `"ollama"` retorna `prefs.ollamaModel`, para `"none"` retorna `nil`. Esse mapeamento é melhor passado via closure `llmModelNameProvider: @Sendable (String) -> String?` no init pra manter o coordinator desacoplado.

- [x] **Step 10.7: Atualizar `AppContainer.swift`.**

```swift
let historyStore: HistoryStore = (try? HistoryStoreLive()) ?? HistoryStoreNoop()
let pipeline = PipelineCoordinator(
    audio: audioCapture,
    transcriber: transcriber,
    refinerProvider: { factory.current() },
    injector: injector,
    historyStore: historyStore,
    historyMaxItemsProvider: { [weak prefs] in prefs?.historyMaxItems ?? PreferencesDefaults.historyMaxItems },
    historyMaxDaysProvider:  { [weak prefs] in prefs?.historyMaxDays  ?? PreferencesDefaults.historyMaxDays },
    initialPromptProvider: { [weak prefs] in
        guard let prefs, !prefs.technicalVocabulary.isEmpty else { return nil }
        return InitialPromptBuilder.build(vocab: prefs.technicalVocabulary)
    })
```

- [x] **Step 10.8: Build + tests.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -10
```

Esperado: 64 testes verdes (58 + 6).

- [ ] **Step 10.9: Smoke manual.**

Fazer 3 capturas seguidas. Verificar que `~/Library/Application Support/com.tagarela.Tagarela/History.store` foi criado e tem entries (inspect via `sqlite3` se quiser, ou esperar Tarefa 16 quando expor `recent` no menu).

- [x] **Step 10.10: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/History app/TagarelaTests/HistoryStoreTests.swift app/Tagarela/Pipeline/PipelineCoordinator.swift app/Tagarela/App/AppContainer.swift app/Tagarela.xcodeproj
git commit -m "feat(history): SwiftData HistoryStore com retenção a cada save"
```

**Milestone:** histórico persistente entre sessões, com retenção 200/30 default. Sem UI ainda.

**Critério de aceite:** SwiftData container criado em `Application Support`; cada captura insere uma `Transcription`; retenção purga por idade e por contagem; falha de save logs sem bloquear pipeline; container indisponível → `HistoryStoreNoop`; 6 testes verdes.

---

## Tarefa 11: Submenu `Backend` no `MenuBarContent`

**Files:**
- Create: `app/Tagarela/UI/MenuBar/BackendSubmenu.swift`
- Modify: `app/Tagarela/UI/MenuBar/MenuBarContent.swift`

- [ ] **Step 11.1: Escrever `BackendSubmenu.swift`.**

```swift
import SwiftUI

struct BackendSubmenu: View {
    @ObservedObject var prefs: PreferencesStore
    /// Triggar abertura do modal de API key (vem do AppContainer).
    var onConfigureKey: () -> Void

    var body: some View {
        Menu {
            ForEach(RefinerKind.allCases, id: \.self) { kind in
                Button {
                    prefs.refinerKind = kind
                    if kind == .openai { onConfigureKey() } // modal só abre se key vazia (decidido no handler)
                } label: {
                    HStack {
                        Text(label(for: kind))
                        Spacer()
                        if prefs.refinerKind == kind { Image(systemName: "checkmark") }
                    }
                }
            }
            Divider()
            Button("Configurar API key da OpenAI…") { onConfigureKey() }
        } label: {
            HStack {
                Text("Backend")
                Spacer()
                Text(label(for: prefs.refinerKind)).foregroundStyle(.secondary)
            }
        }
    }

    private func label(for kind: RefinerKind) -> String {
        switch kind {
        case .none:   return NSLocalizedString("backend.none",   value: "Sem LLM",  comment: "")
        case .openai: return NSLocalizedString("backend.openai", value: "OpenAI",   comment: "")
        case .ollama: return NSLocalizedString("backend.ollama", value: "Ollama",   comment: "")
        }
    }
}
```

- [ ] **Step 11.2: Modificar `MenuBarContent.swift`.**

```swift
struct MenuBarContent: View {
    @ObservedObject var appState: AppState
    @ObservedObject var prefs: PreferencesStore
    var onConfigureOpenAIKey: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // … cabeçalho + StateRow existentes …
            Divider()
            BackendSubmenu(prefs: prefs, onConfigureKey: onConfigureOpenAIKey)
            // (StyleSubmenu vai aqui na Tarefa 13)
            Divider()
            // … Permissões + Sair existentes …
        }
    }
}
```

- [ ] **Step 11.3: Wire-up no `AppContainer` ou `TagarelaApp`.**

Passar `prefs` e um closure `onConfigureOpenAIKey` que por enquanto loga (a Tarefa 12 conecta o modal real). Por exemplo:

```swift
.menuBarExtra(...) {
    MenuBarContent(
        appState: appState,
        prefs: prefs,
        onConfigureOpenAIKey: { /* TODO Tarefa 12 */ },
        onQuit: { NSApp.terminate(nil) })
}
```

- [ ] **Step 11.4: Build + smoke manual.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' build 2>&1 | tail -5
# abrir o app, conferir que o submenu aparece, troca de backend persiste em UserDefaults
```

- [ ] **Step 11.5: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/UI/MenuBar/BackendSubmenu.swift app/Tagarela/UI/MenuBar/MenuBarContent.swift app/Tagarela/App/AppContainer.swift app/Tagarela.xcodeproj
git commit -m "feat(ui): BackendSubmenu radio na status bar"
```

**Critério de aceite:** submenu mostra 3 opções com checkmark no ativo; mudar persiste em UserDefaults imediatamente; troca reflete no label do menu pai.

---

## Tarefa 12: `OpenAIKeyPromptWindow` modal + integração

**Files:**
- Create: `app/Tagarela/UI/Onboarding/OpenAIKeyPromptWindow.swift`
- Modify: `app/Tagarela/App/AppContainer.swift`

- [ ] **Step 12.1: Escrever `OpenAIKeyPromptWindow.swift`.**

```swift
import AppKit
import SwiftUI

/// Modal NSPanel pra cadastrar API key da OpenAI no Keychain.
/// Usado quando: (a) seleciona OpenAI sem key cadastrada; (b) item explícito do submenu.
@MainActor
final class OpenAIKeyPromptWindow {
    private var window: NSPanel?
    private let keychain: KeychainService
    /// Callback chamado se o usuário cancelar (pra reverter prefs.refinerKind).
    var onCancel: (() -> Void)?
    /// Callback chamado se a key foi salva com sucesso.
    var onSaved: (() -> Void)?

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    func show() {
        if window != nil { window?.makeKeyAndOrderFront(nil); return }
        let view = OpenAIKeyPromptView(
            keychain: keychain,
            onCancel: { [weak self] in self?.close(canceled: true) },
            onSaved:  { [weak self] in self?.close(canceled: false) })
        let host = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        panel.title = NSLocalizedString("openai.key.window.title",
                                        value: "API key da OpenAI",
                                        comment: "")
        panel.contentViewController = host
        panel.center()
        panel.isFloatingPanel = true
        self.window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close(canceled: Bool) {
        window?.close()
        window = nil
        if canceled { onCancel?() } else { onSaved?() }
    }
}

private struct OpenAIKeyPromptView: View {
    let keychain: KeychainService
    let onCancel: () -> Void
    let onSaved: () -> Void
    @State private var keyText: String = ""
    @State private var inlineError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("openai.key.body",
                value: "A key fica no Keychain do macOS, no serviço com.tagarela. Nunca aparece em logs nem é enviada para outros lugares.",
                comment: ""))
                .font(.callout)
                .foregroundStyle(.secondary)
            SecureField("sk-…", text: $keyText)
                .textFieldStyle(.roundedBorder)
            if let inlineError {
                Label(inlineError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            HStack {
                Spacer()
                Button(NSLocalizedString("common.cancel", value: "Cancelar", comment: ""), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(NSLocalizedString("common.save", value: "Salvar", comment: "")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(keyText.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360, height: 220)
    }

    private func save() {
        do {
            try keychain.setOpenAIKey(keyText)
            onSaved()
        } catch {
            inlineError = NSLocalizedString("openai.key.error.save",
                value: "Não foi possível salvar — tente de novo.", comment: "")
        }
    }
}
```

- [ ] **Step 12.2: Wire-up no `AppContainer`.**

```swift
let keyPromptWindow = OpenAIKeyPromptWindow(keychain: keychain)

// Closure passada pro BackendSubmenu:
let onConfigureOpenAIKey: () -> Void = {
    let keyExists = (try? keychain.openAIKey()).flatMap { $0 } != nil
    keyPromptWindow.onCancel = { [weak prefs] in
        // Se o user cancelou e a prefs estava sendo movida pra openai, reverter:
        if !keyExists, prefs?.refinerKind == .openai {
            prefs?.refinerKind = .none
        }
    }
    keyPromptWindow.onSaved = { /* nada extra */ }
    keyPromptWindow.show()
}

// E auto-trigger quando seleciona OpenAI sem key:
let bridgedConfigure: () -> Void = {
    let hasKey = (try? keychain.openAIKey())??.isEmpty == false
    if hasKey { return }  // nada a fazer
    onConfigureOpenAIKey()
}
```

> **Importante:** o `BackendSubmenu` da Tarefa 11 chama `onConfigureKey()` em **dois** lugares:
>
> 1. Quando o user clica explicitamente em "Configurar API key da OpenAI…" — sempre abre.
> 2. Quando o user seleciona "OpenAI" — abre só se key vazia.
>
> Refinar o submenu pra distinguir esses casos: passar dois closures separados, ou um closure que recebe um Bool/enum dizendo o gatilho. Recomendo:
>
> ```swift
> struct BackendSubmenu: View {
>     // …
>     var onSelectOpenAINeedsKey: () -> Void  // só dispara se Keychain vazio
>     var onExplicitConfigureKey: () -> Void  // sempre abre modal
>     // …
> }
> ```

- [ ] **Step 12.3: Build + manual.**

Manual:
1. Apagar key atual: `security delete-generic-password -s com.tagarela -a openai-api-key 2>/dev/null || true`.
2. Abrir app, status bar → Backend → OpenAI. Modal deve abrir.
3. Cancelar → backend volta pra valor anterior (`Sem LLM`).
4. Selecionar OpenAI de novo → modal abre. Colar key real. Salvar → modal fecha.
5. Verificar key gravada: `security find-generic-password -s com.tagarela -a openai-api-key -w`.
6. Próxima captura usa OpenAI.

- [ ] **Step 12.4: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/UI/Onboarding/OpenAIKeyPromptWindow.swift app/Tagarela/App/AppContainer.swift app/Tagarela/UI/MenuBar/BackendSubmenu.swift app/Tagarela.xcodeproj
git commit -m "feat(ui): modal NSPanel pra cadastrar API key OpenAI"
```

**Milestone:** trocar backend e configurar API key sem CLI. 2a usável end-to-end.

**Critério de aceite:** modal abre quando seleciona OpenAI sem key; cancelar reverte refinerKind; salvar persiste no Keychain; SecureField não vaza em logs/screen.

---

## Tarefa 13: Submenu `Estilo` + cabeçalho mostrando ativo

**Files:**
- Create: `app/Tagarela/UI/MenuBar/StyleSubmenu.swift`
- Modify: `app/Tagarela/UI/MenuBar/MenuBarContent.swift`

- [ ] **Step 13.1: Escrever `StyleSubmenu.swift`.**

```swift
import SwiftUI

struct StyleSubmenu: View {
    @ObservedObject var prefs: PreferencesStore

    var body: some View {
        Menu {
            ForEach(BuiltInStyles.all) { style in
                Button {
                    prefs.selectedStyleID = style.id
                } label: {
                    HStack {
                        Text(style.name)
                        Spacer()
                        if prefs.selectedStyleID == style.id { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack {
                Text("Estilo")
                Spacer()
                Text(activeStyleName).foregroundStyle(.secondary)
            }
        }
    }

    private var activeStyleName: String {
        BuiltInStyles.style(for: prefs.selectedStyleID)?.name ?? "—"
    }
}
```

- [ ] **Step 13.2: Adicionar ao `MenuBarContent.swift`.**

```swift
BackendSubmenu(prefs: prefs,
               onSelectOpenAINeedsKey: bridgedConfigure,
               onExplicitConfigureKey: onConfigureOpenAIKey)
StyleSubmenu(prefs: prefs)
```

- [ ] **Step 13.3: Build + smoke.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' build 2>&1 | tail -5
```

Manual: trocar de "conversa informal" pra "cru — sem reescrita" via menu, gravar uma frase, conferir que o texto colado é o cru (sem reescrita).

- [ ] **Step 13.4: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/UI/MenuBar/StyleSubmenu.swift app/Tagarela/UI/MenuBar/MenuBarContent.swift app/Tagarela.xcodeproj
git commit -m "feat(ui): StyleSubmenu radio com 4 built-ins"
```

**Milestone:** ergonomia da 2a completa. Tudo controlável pela status bar.

**Critério de aceite:** submenu mostra 4 estilos com checkmark; trocar reflete no label e na próxima captura; estilo cru pula refiner.

---

## Tarefa 14: `Localizable.strings` infra (apenas strings novas)

**Files:**
- Modify: `app/Tagarela/Localization/pt-BR.lproj/Localizable.strings`
- Modify: vários arquivos da Fase 2a (substituir literais por `NSLocalizedString`)

- [ ] **Step 14.1: Adicionar chaves novas em `Localizable.strings`.**

```
"backend.none"   = "Sem LLM";
"backend.openai" = "OpenAI";
"backend.ollama" = "Ollama";

"menubar.backend.label" = "Backend";
"menubar.style.label"   = "Estilo";
"menubar.configure.openaikey" = "Configurar API key da OpenAI…";

"openai.key.window.title" = "API key da OpenAI";
"openai.key.body" = "A key fica no Keychain do macOS, no serviço com.tagarela. Nunca aparece em logs nem é enviada para outros lugares.";
"openai.key.error.save" = "Não foi possível salvar — tente de novo.";

"common.cancel" = "Cancelar";
"common.save"   = "Salvar";

"style.name.conversa-informal"   = "conversa informal";
"style.name.email-profissional"  = "e-mail profissional";
"style.name.notas-tecnicas"      = "notas técnicas";
"style.name.cru-sem-reescrita"   = "cru — sem reescrita";
```

- [ ] **Step 14.2: Substituir literais nos arquivos da 2a.**

Em `BackendSubmenu.swift`, `StyleSubmenu.swift`, `OpenAIKeyPromptWindow.swift`, `MenuBarContent.swift` (parte adicionada na 2a) — todos os literais em pt-BR já foram chamados via `NSLocalizedString(...)` nas tarefas anteriores. Conferir que cada chave existe no `.strings`.

> **Não migrar** strings da Fase 1 — escopo é só 2a. Ver decisão F2a-13 do spec.

> Em `BuiltInStyles.swift`, manter os `name` hardcoded por enquanto (tem um propósito de identificação semântica que só é exibido se o user usar pt-BR; se virar localizável, exige cuidado pra não quebrar `style.name` no histórico). Caso seja desejado localizar, fazer via `NSLocalizedString` nos lugares de exibição (e.g. `StyleSubmenu`), mantendo a string crua no struct.

- [ ] **Step 14.3: Build.**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' build 2>&1 | tail -5
```

Manual: trocar locale do macOS pra inglês (System Settings → Language) e conferir que (a) ainda mostra pt-BR (porque só temos pt-BR.lproj, sem fallback), ou (b) mostra strings de fallback (`value:`). Aceitar comportamento atual; documentar.

- [ ] **Step 14.4: Commit.**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Localization app/Tagarela/UI app/Tagarela.xcodeproj
git commit -m "feat(i18n): infra Localizable + chaves novas da Fase 2a"
```

**Critério de aceite:** todas as strings UI da 2a têm chave em `Localizable.strings`; nenhum literal em arquivo Swift da 2a.

---

## Tarefa 15: Checklist manual `fase2a-manual.md` + execução completa

**Files:**
- Create: `tagarela_docs/03-funcionalidades/checklists/fase2a-manual.md`

- [ ] **Step 15.1: Criar checklist.**

```markdown
---
data: 2026-04-27
status: aberto
escopo: aceite manual da Fase 2a
---

# Aceite manual — Fase 2a

Pré-condição: build da 2a instalado em `~/Applications/Tagarela.app`. Ollama rodando (`ollama serve` em outro terminal).

## Setup limpo

- [ ] Apagar key atual: `security delete-generic-password -s com.tagarela -a openai-api-key 2>/dev/null || true`
- [ ] Apagar UserDefaults: `defaults delete com.tagarela.preferences 2>/dev/null || true`
- [ ] Apagar history: `rm -rf ~/Library/Application\ Support/com.tagarela.Tagarela/History.store*`
- [ ] Reabrir app

## Backend submenu

- [ ] Status bar mostra "Backend ▸ Sem LLM" (default).
- [ ] Trocar pra Ollama: ícone atualiza pra "Ollama". Próxima captura usa Ollama.
- [ ] Trocar pra OpenAI **sem key**: modal abre automaticamente.
- [ ] Cancelar modal: backend volta pra Ollama (estado anterior).
- [ ] Trocar pra OpenAI de novo: modal abre.
- [ ] Colar key real e Salvar: modal fecha. Backend = OpenAI.
- [ ] Reabrir app: backend ainda OpenAI (persistiu).
- [ ] Item "Configurar API key da OpenAI…" abre modal mesmo com key cadastrada.

## Style submenu

- [ ] Default = "conversa informal".
- [ ] Trocar pra "e-mail profissional": gravar "tô indo lá" → texto colado tem tom mais formal.
- [ ] Trocar pra "cru — sem reescrita": gravar "tô indo lá" → texto colado é cru sem reescrita (sem chamada HTTP — confirmar via Console.app que não houve log de `OpenAIRefiner` ou `OllamaRefiner`).

## Refiners — caminho feliz

- [ ] OpenAI: gravar "preciso fazer um deploy do Postgres", colar — texto refinado preserva "deploy" e "Postgres".
- [ ] Ollama: idem com Ollama selecionado.

## Refiners — fallback

- [ ] OpenAI selecionado, internet desligada: gravar — texto cru chega ao destino, log mostra fallback (filtrar `subsystem:com.tagarela`).
- [ ] Ollama selecionado, `ollama serve` desligado: gravar — texto cru chega ao destino, log mostra fallback. Histórico marca `refinerKind = "none"`.
- [ ] OpenAI selecionado com key inválida (substituir por `sk-invalida` via modal): gravar — fallback Identity.

## Histórico (sem UI ainda)

- [ ] Após 5 capturas, inspecionar:
  ```bash
  sqlite3 ~/Library/Application\ Support/com.tagarela.Tagarela/History.store \
    "SELECT createdAt, refinerKind, length(rawText), length(refinedText) FROM ZTRANSCRIPTION ORDER BY ZCREATEDAT DESC;"
  ```
- [ ] Setar retenção pra 3: `defaults write com.tagarela.preferences historyMaxItems -int 3`. Reabrir app. Fazer 1 captura. Conferir que o store agora tem só 3 entries.

## Cancelamento

- [ ] Iniciar gravação, falar 3s, apertar `right ⌥` pra parar, no meio de "refinando" pressionar Esc → indicador some, sem nova entrada no histórico.

## Injeção

Testar 1 captura por app:

- [ ] TextEdit
- [ ] Notes
- [ ] Slack
- [ ] VS Code
- [ ] Terminal
- [ ] Mail (cliente nativo)

Em cada um: texto refinado é colado no foco; clipboard é restaurado depois de 250ms.

## Sair e voltar

- [ ] Sair via menu → "Sair". Reabrir app. Conferir que `prefs.refinerKind`, `prefs.selectedStyleID` e key continuam.

## Checklist concluído

Quando todos os itens passam, marcar `status: concluído (YYYY-MM-DD)` no header e atualizar `02-arquitetura/01-modulos-fase1.md` (Tarefa 16).
```

- [ ] **Step 15.2: Executar o checklist** (manual; usuário humano).

- [ ] **Step 15.3: Resolver bugs encontrados** (commits separados conforme aparecem). Cada bug vira commit `fix(<area>): …`.

- [ ] **Step 15.4: Commit do checklist.**

```bash
cd /Users/tars/Dev/tagarela
git add tagarela_docs/03-funcionalidades/checklists/fase2a-manual.md
git commit -m "docs: checklist manual de aceite da Fase 2a"
```

**Critério de aceite:** todos os itens marcados; bugs encontrados resolvidos em commits separados antes da Tarefa 16.

---

## Tarefa 16: Atualização final de docs + fechamento da Fase 2a

**Files:**
- Modify: `tagarela_docs/02-arquitetura/01-modulos-fase1.md` → renomear pra `02-modulos-fase2a.md` ou evoluir o conteúdo (ver Step 16.1)
- Modify: `tagarela_docs/README.md`
- Modify: `tagarela_docs/04-decisoes/cleanup-fase1.md` (cleanup #2 e #4 fechados; conferir #5 que já foi fechado)
- Create: `tagarela_docs/04-decisoes/ADR-0003-pipeline-2a.md` (resumo das decisões F2a-1 .. F2a-16 do spec, agora confirmadas em produção)

- [ ] **Step 16.1: Decidir nome do doc de módulos.**

Opção A (recomendada): manter `01-modulos-fase1.md` e adicionar seção "Evolução para Fase 2a" no fim. Mais simples, preserva histórico.

Opção B: criar `02-modulos-fase2a.md` espelhando estrutura do anterior, marcar `01-modulos-fase1.md` como histórico congelado.

Escolher A. Adicionar seção:

```markdown
## Fase 2a (2026-04-27 → ___)

### Implementados nesta sub-fase

| Módulo | Arquivo | Responsabilidade |
|---|---|---|
| PreferencesStore | `Preferences/PreferencesStore.swift` | UserDefaults + @Published |
| KeychainService | `Preferences/Keychain*` | API key OpenAI no Keychain |
| Style + BuiltInStyles | `Refiner/` | 4 presets hardcoded |
| RefinerError + Mapper + TokenCounter + RemoteRefinerConfig | `Refiner/` | Error semântico + token estimate |
| BaseRemoteRefiner | `Refiner/` | Trunca-com-marcador compartilhado |
| OpenAIRefiner | `Refiner/` | TextRefiner via OpenAI chat completions |
| OllamaRefiner + HealthChecker | `Refiner/` | TextRefiner via Ollama /api/chat com cache |
| RefinerFactory | `Refiner/` | Lê prefs e devolve impl |
| Transcription + HistoryStore | `History/` | SwiftData + retenção a cada save |
| BackendSubmenu + StyleSubmenu | `UI/MenuBar/` | Radios na status bar |
| OpenAIKeyPromptWindow | `UI/Onboarding/` | NSPanel modal pra API key |
| DefaultVocabulary | `Resources/` | Lista hardcoded de termos técnicos |

### Modificados

- `WhisperKitTranscriber` — promptTokens via tokenizer (cleanup #2 fechado).
- `AudioCaptureLive` — `audioBoostMaxGain` lido de prefs (cleanup #4 fechado).
- `PipelineCoordinator` — `actualRefinerKind` semântico, `historyStore.save` após inject.
- `MenuBarContent` — incorpora 2 submenus.
- `AppContainer` — wire-up dos novos módulos + sinks de invalidação do health checker.

### Cobertura de testes

~40-45 testes XCTest verdes.

### Não implementados (vão pra Fase 2b)

[mesmas linhas existentes]
```

- [ ] **Step 16.2: Atualizar `tagarela_docs/README.md`.**

Adicionar entrada apontando pro plano e atualizar status do design 2a → "concluído". Garantir que cleanup-fase1 reflete só itens ainda pendentes (#1 L/R Option, #3 stderr, #5 já fechado, #6 TCC, #7 drift visual, #8 IndicatorPill, #9 Documents folder).

- [ ] **Step 16.3: Confirmar `cleanup-fase1.md` atualizado.**

- [ ] **Step 16.4: Criar ADR-0003 com decisões nucleares da 2a.**

Resumo das decisões F2a-1 a F2a-16 do spec, com nota: "Confirmadas em produção após execução do plano e checklist `fase2a-manual.md`".

- [ ] **Step 16.5: Atualizar versão / commit final.**

```bash
cd /Users/tars/Dev/tagarela
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -5
# expected: TEST SUCCEEDED com ~40-45 testes
git add tagarela_docs/02-arquitetura/01-modulos-fase1.md tagarela_docs/README.md tagarela_docs/04-decisoes/cleanup-fase1.md tagarela_docs/04-decisoes/ADR-0003-pipeline-2a.md
git commit -m "docs: fechamento da Fase 2a — módulos, ADR-0003, cleanups #2 e #4"
```

- [ ] **Step 16.6: Tag opcional.**

```bash
git tag fase-2a-merged
```

**Critério de aceite:** docs refletem 2a; cleanups #2 e #4 fechados em `cleanup-fase1.md`; ADR-0003 criado; suite de testes verde com ~40-45 testes; checklist manual passa.

---

## Estado esperado ao fim da Fase 2a

- Pipeline completo: ditado → Whisper (com promptTokens) → refiner (OpenAI/Ollama/Identity com fallback) → injeção → histórico SwiftData.
- Status bar com 2 submenus + modal de API key. Configurável sem CLI.
- `~/Library/Application Support/com.tagarela.Tagarela/History.store` cresce conforme uso, com retenção 200/30 default.
- Suite XCTest verde (~40-45 testes).
- Checklist manual passou.
- Cleanups #2 e #4 fechados; #1, #3, #5–#9 ainda abertos (foco da revisão futura).
- Pronto pra brainstorming da Fase 2b: tela de Preferências, menu "últimos 5", indicadores B/C/D, toasts, estados de permissão, migração total Localizable.
