---
data: 2026-05-01
status: planejado
fase: 2d-velocidade-transcribe
goal: trocar default Whisper pra large-v3-turbo + picker funcional + knobs ANE/prewarm + timing log
---

# tagarela v1 — Fase 2d: Implementation Plan

> **Para agentes de execução:** SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendado) ou `superpowers:executing-plans`. Tarefas usam checkbox (`- [ ]`).
>
> **Antes de qualquer tarefa:** ler [`/CLAUDE.md`](../../CLAUDE.md), [`tagarela_docs/specs/2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-design.md`](./2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-design.md), e [`tagarela_docs/02-arquitetura/06-modulos-fase2c-cleanup.md`](../02-arquitetura/06-modulos-fase2c-cleanup.md) (lição operacional). **Antes de marcar uma tarefa como concluída:** atualizar a doc afetada (regra inviolável 2 do CLAUDE.md). **Antes de mergear cada tarefa que toca AppKit/SwiftUI/IO (Tarefas 4, 6, 7, 8, 9):** rodar aceite manual em build local — lição 2c-cleanup.

**Goal:** Reduzir tempo wall-clock de transcrição em ditados curtos via troca de modelo default (`large-v3` → `large-v3-turbo`), expondo escolha em Onboarding e Preferências. Inclui knobs ANE/prewarm e instrumentação de timing.

**Architecture:** (a) `Preferences.whisperModelName` (UserDefaults) vira fonte da verdade; default `"large-v3-turbo"` em novos installs, mantém modelo em disco em users existentes. (b) Catálogo estático (`WhisperModelCatalog`) lista 3 modelos com metadata. (c) `WhisperModelStore` checa presença/tamanho em disco e apaga. (d) `WhisperModelSwapCoordinator` orquestra troca em runtime: load do novo → troca atômica do ponteiro `transcriber` no AppContainer → unload do antigo → alerta de cleanup. (e) `WhisperKitTranscriber` ganha `prewarmModels: true` + `computeOptions = ModelComputeOptions(.cpuAndNeuralEngine, .cpuAndNeuralEngine)` + log de timing por chamada + método `unloadModel()`. (f) `WhisperModelPicker` componente compartilhado entre Onboarding e Preferências. (g) Onboarding: radios funcionais; Preferências > Transcrição: section nova com picker, banner pra users existentes, sheets de erro/cleanup.

**Tech stack:** Swift 5.10, SwiftUI, UserDefaults, AppKit cirúrgico, WhisperKit 0.9+, XCTest. Sem novas SPMs.

**Não está nesta fase:** modelos `distil-*` ou `small`/`base` no picker (decisão "conservador"); mexer em `DecodingOptions.temperatureFallbackCount` (risco de alucinação); persistir histórico de timing em SwiftData; lista de "todos os modelos baixados em disco" com botão deletar individual; download paralelo de múltiplos modelos. Ver [`fase2d-design.md`](./2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-design.md#não-objetivos).

---

## File structure desta fase

Raiz `app/Tagarela/`:

```
app/Tagarela/
├── Transcription/
│   ├── WhisperKitTranscriber.swift          # MODIFICAR — config (prewarm + computeOptions) + timing log + unloadModel()
│   ├── Transcribing.swift                    # MODIFICAR — protocol ganha unloadModel()
│   ├── WhisperModelCatalog.swift             # CRIAR — metadata estática dos 3 modelos
│   ├── WhisperModelStore.swift               # CRIAR — protocol (isDownloaded/sizeOnDisk/delete)
│   ├── WhisperModelStoreLive.swift           # CRIAR — impl com FileManager
│   └── WhisperModelSwapCoordinator.swift     # CRIAR — máquina de estado do swap em runtime
├── Preferences/
│   ├── Preferences+Defaults.swift            # MODIFICAR — chave + default whisperModelName
│   ├── PreferencesStore.swift                # MODIFICAR — campo @Published whisperModelName
│   └── UI/
│       ├── PrefsSection.swift                # MODIFICAR — case .transcricao
│       ├── PreferencesRoot.swift             # MODIFICAR — wire da section nova
│       ├── Components/
│       │   └── WhisperModelPicker.swift      # CRIAR — componente compartilhado
│       ├── Sections/
│       │   └── TranscriptionView.swift       # CRIAR — section Preferências > Transcrição
│       └── Sheets/
│           └── SwapErrorSheet.swift          # CRIAR — sheet modal de erro com retry
├── UI/Onboarding/
│   ├── OnboardModel.swift                    # MODIFICAR — picker funcional + erro inline
│   ├── OnboardingWindow.swift                # MODIFICAR — passa selected pro coordinator
│   └── OnboardingCoordinator.swift           # MODIFICAR — error inline + grava prefs
├── App/
│   └── AppContainer.swift                    # MODIFICAR — usa prefs.whisperModelName + wire coordinator + migration
└── Localization/pt-BR.lproj/
    └── Localizable.strings                   # MODIFICAR — strings novas

app/TagarelaTests/
├── WhisperModelCatalogTests.swift            # CRIAR
├── WhisperModelStoreTests.swift              # CRIAR
├── WhisperModelSwapCoordinatorTests.swift    # CRIAR
├── PreferencesStoreTests.swift               # MODIFICAR — caso whisperModelName
└── LocalizableKeysTests.swift                # MODIFICAR — chaves novas
```

Documentação atualizada por esta fase em `tagarela_docs/`:
- `02-arquitetura/07-modulos-fase2d.md` (criar) — snapshot pós-2d.
- `03-funcionalidades/checklists/fase2d-manual.md` (criar) — checklist manual + bench antes/depois.
- `04-decisoes/cleanup-fase2d.md` (criar se aceite levantar achados; opcional).
- `README.md` — atualizar status da 2d quando fechar.

---

## Convenções desta fase

- **Idioma:** strings de UI em `Localizable.strings` (pt-BR base). Identificadores Swift em inglês.
- **Concorrência:** `WhisperModelSwapCoordinator` é `@MainActor` (lê e escreve `@Published state` consumido pela UI; chama `transcriber.loadModel` que é `async`). `WhisperModelStore` impl é `Sendable` (puro IO via `FileManager`).
- **Erros:** novos enums `SwapError` e `WhisperModelStoreError`. `TranscribeError` existente continua igual.
- **Logging:** `Logger.tagarela` (subsystem `com.tagarela`, category dependendo do módulo). `WhisperKitTranscriber` já usa categoria `Transcribe`. Coordinator usa `SwapCoordinator` nova.
- **TDD:** lógica → teste primeiro. UI/SwiftUI → preview + checklist manual. Aceite manual em build local antes de mergear tarefas que tocam AppKit/SwiftUI/IO (Tarefas 4, 6, 7, 8, 9).
- **Commits:** um commit por tarefa (ou alguns commits relacionados), em pt-BR no estilo `tipo(escopo): descrição` + co-author Claude.
- **xcodegen é fonte da verdade do projeto Xcode.** Esta fase **cria** arquivos novos no app target. Após criar arquivos novos, sempre `cd /Users/tars/Dev/tagarela/app && xcodegen generate` antes de buildar.

---

## Pre-flight (antes da Tarefa 1)

- [ ] **Confirmar `main` está limpo e em verde.**

```bash
cd /Users/tars/Dev/tagarela
git status                                      # working tree clean
git log -1 --oneline                            # último: 6eefb87 docs: design da Fase 2d
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -5
```

Esperado: `** TEST SUCCEEDED **`, 155 testes passando.

- [ ] **Criar branch de trabalho.**

```bash
cd /Users/tars/Dev/tagarela
git checkout -b fase-2d
```

- [ ] **Confirmar `xcodegen` instalado.**

```bash
which xcodegen
```

Esperado: caminho não-vazio (ex: `/opt/homebrew/bin/xcodegen`). Se faltar: `brew install xcodegen`.

- [ ] **Capturar baseline de timing antes da troca.**

Pra ter número real do "antes": rodar o app empacotado atual (large-v3), ditar 5× ditados de ~3s, anotar tempos observados (cronômetro). Se for impraticável agora, pular — bench oficial vem na Tarefa 11.

---

## Tarefa 1: `WhisperModelCatalog` — metadata estática dos 3 modelos

Objetivo: fonte única da verdade pra metadata dos modelos exibidos no picker (nome técnico, tamanho, RAM mínima, badge "recomendado"). Puro Swift, sem IO.

**Files:**
- Create: `app/Tagarela/Transcription/WhisperModelCatalog.swift`
- Create: `app/TagarelaTests/WhisperModelCatalogTests.swift`

- [ ] **Step 1: Escrever teste falhando**

Criar `app/TagarelaTests/WhisperModelCatalogTests.swift`:

```swift
import XCTest
@testable import Tagarela

final class WhisperModelCatalogTests: XCTestCase {

    func test_all_contains_three_models() {
        XCTAssertEqual(WhisperModelCatalog.all.count, 3)
    }

    func test_all_includes_largeV3Turbo_as_recommended_default() {
        let turbo = WhisperModelCatalog.all.first { $0.name == "large-v3-turbo" }
        XCTAssertNotNil(turbo)
        XCTAssertTrue(turbo?.recommended == true)
    }

    func test_all_includes_largeV3() {
        XCTAssertTrue(WhisperModelCatalog.all.contains { $0.name == "large-v3" })
    }

    func test_all_includes_medium() {
        XCTAssertTrue(WhisperModelCatalog.all.contains { $0.name == "medium" })
    }

    func test_all_does_not_include_small_or_distil() {
        let names = WhisperModelCatalog.all.map(\.name)
        XCTAssertFalse(names.contains("small"))
        XCTAssertFalse(names.contains("distil-large-v3"))
    }

    func test_info_lookup_by_name_returns_match() {
        let info = WhisperModelCatalog.info(for: "large-v3-turbo")
        XCTAssertEqual(info?.name, "large-v3-turbo")
        XCTAssertEqual(info?.displaySize, "815 MB")
    }

    func test_info_lookup_unknown_returns_nil() {
        XCTAssertNil(WhisperModelCatalog.info(for: "tiny"))
    }
}
```

- [ ] **Step 2: Verificar que falha em compilar**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -8
```

Esperado: erro de compilação ("Cannot find 'WhisperModelCatalog' in scope").

- [ ] **Step 3: Implementar catálogo**

Criar `app/Tagarela/Transcription/WhisperModelCatalog.swift`:

```swift
import Foundation

/// Metadata estática de um modelo Whisper exibido no picker.
struct WhisperModelInfo: Equatable, Hashable, Identifiable {
    let name: String          // "large-v3-turbo" — nome técnico passado pro WhisperKit
    let displaySize: String   // "815 MB" — pra UI
    let displayRAM: String    // "≥ 4 GB" — pra UI
    let approxBytes: Int64    // pra cálculo de "libera X MB" no cleanup prompt
    let recommended: Bool     // badge "recom." na UI

    var id: String { name }
}

/// Fonte da verdade dos modelos disponíveis na v1.
/// Ordem aqui = ordem de exibição no picker.
enum WhisperModelCatalog {
    static let all: [WhisperModelInfo] = [
        WhisperModelInfo(
            name: "large-v3-turbo",
            displaySize: "815 MB",
            displayRAM: "≥ 4 GB",
            approxBytes: 815 * 1024 * 1024,
            recommended: true
        ),
        WhisperModelInfo(
            name: "large-v3",
            displaySize: "2.9 GB",
            displayRAM: "≥ 16 GB",
            approxBytes: 2_900 * 1024 * 1024,
            recommended: false
        ),
        WhisperModelInfo(
            name: "medium",
            displaySize: "1.4 GB",
            displayRAM: "≥ 8 GB",
            approxBytes: 1_400 * 1024 * 1024,
            recommended: false
        ),
    ]

    static func info(for name: String) -> WhisperModelInfo? {
        all.first { $0.name == name }
    }
}
```

- [ ] **Step 4: Regenerar projeto e rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|FAIL|SUCCESS" | tail -5
```

Esperado: 155 + 7 novos = 162 testes verdes. `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Transcription/WhisperModelCatalog.swift \
        app/TagarelaTests/WhisperModelCatalogTests.swift \
        app/Tagarela.xcodeproj
git commit -m "$(cat <<'EOF'
feat(transcription): catálogo estático dos modelos Whisper

WhisperModelCatalog lista os 3 modelos da v1 (large-v3-turbo recomendado,
large-v3, medium). Fonte da verdade pra metadata do picker.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 2: `WhisperModelStore` — protocol + impl com FileManager

Objetivo: abstrair leitura/exclusão de modelos no disco. WhisperKit baixa pra `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-<name>/`. Store sabe checar presença, tamanho, e apagar a pasta.

**Files:**
- Create: `app/Tagarela/Transcription/WhisperModelStore.swift`
- Create: `app/Tagarela/Transcription/WhisperModelStoreLive.swift`
- Create: `app/TagarelaTests/WhisperModelStoreTests.swift`

- [ ] **Step 1: Escrever teste falhando (testando impl Live com diretório temporário)**

Criar `app/TagarelaTests/WhisperModelStoreTests.swift`:

```swift
import XCTest
@testable import Tagarela

final class WhisperModelStoreTests: XCTestCase {
    var tempDir: URL!
    var store: WhisperModelStoreLive!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisperStoreTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = WhisperModelStoreLive(rootDirectory: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_isDownloaded_returnsFalseWhenAbsent() {
        XCTAssertFalse(store.isDownloaded("large-v3-turbo"))
    }

    func test_isDownloaded_returnsTrueAfterFakeContent() throws {
        let modelDir = tempDir.appendingPathComponent("openai_whisper-large-v3-turbo")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try Data([0xCA, 0xFE]).write(to: modelDir.appendingPathComponent("dummy.bin"))
        XCTAssertTrue(store.isDownloaded("large-v3-turbo"))
    }

    func test_sizeOnDisk_returnsBytes() throws {
        let modelDir = tempDir.appendingPathComponent("openai_whisper-medium")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: 1024).write(to: modelDir.appendingPathComponent("a.bin"))
        try Data(repeating: 0xCD, count: 2048).write(to: modelDir.appendingPathComponent("b.bin"))
        XCTAssertEqual(store.sizeOnDisk("medium"), 1024 + 2048)
    }

    func test_sizeOnDisk_returnsNilWhenAbsent() {
        XCTAssertNil(store.sizeOnDisk("large-v3"))
    }

    func test_delete_removesDirectory() async throws {
        let modelDir = tempDir.appendingPathComponent("openai_whisper-large-v3")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try Data([0x01]).write(to: modelDir.appendingPathComponent("dummy.bin"))
        XCTAssertTrue(store.isDownloaded("large-v3"))

        try await store.delete("large-v3")
        XCTAssertFalse(store.isDownloaded("large-v3"))
    }

    func test_delete_throwsWhenAbsent() async {
        do {
            try await store.delete("nonexistent")
            XCTFail("expected throw")
        } catch WhisperModelStoreError.notFound {
            // ok
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }
}
```

- [ ] **Step 2: Verificar que falha em compilar**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -5
```

Esperado: erro "Cannot find 'WhisperModelStoreLive'".

- [ ] **Step 3: Implementar protocol**

Criar `app/Tagarela/Transcription/WhisperModelStore.swift`:

```swift
import Foundation

protocol WhisperModelStore: Sendable {
    /// Retorna true se a pasta do modelo existe em disco com pelo menos 1 arquivo.
    func isDownloaded(_ name: String) -> Bool

    /// Retorna soma dos bytes de todos os arquivos da pasta do modelo, ou nil se ausente.
    func sizeOnDisk(_ name: String) -> Int64?

    /// Remove a pasta do modelo do disco. Lança `notFound` se não existe.
    func delete(_ name: String) async throws
}

enum WhisperModelStoreError: Error, Equatable {
    case notFound
    case ioFailure(String)
}
```

- [ ] **Step 4: Implementar `Live`**

Criar `app/Tagarela/Transcription/WhisperModelStoreLive.swift`:

```swift
import Foundation
import OSLog

/// Impl que assume o layout de cache do WhisperKit:
/// `<rootDirectory>/openai_whisper-<name>/`.
/// `rootDirectory` default = `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml`,
/// que é onde o WhisperKit 0.9.x baixa por padrão.
final class WhisperModelStoreLive: WhisperModelStore, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "ModelStore")
    private let root: URL
    private let fm: FileManager

    init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fm = fileManager
        if let rootDirectory {
            self.root = rootDirectory
        } else {
            // Mesmo path que o WhisperKit 0.9.x usa por default
            // (referência: WhisperKit.HubApi defaultDownloadBase).
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            self.root = docs
                .appendingPathComponent("huggingface")
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
        }
    }

    func isDownloaded(_ name: String) -> Bool {
        let dir = modelDir(for: name)
        guard fm.fileExists(atPath: dir.path) else { return false }
        let contents = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return !contents.isEmpty
    }

    func sizeOnDisk(_ name: String) -> Int64? {
        let dir = modelDir(for: name)
        guard fm.fileExists(atPath: dir.path) else { return nil }
        guard let enumerator = fm.enumerator(at: dir,
                                             includingPropertiesForKeys: [.fileSizeKey],
                                             options: [.skipsHiddenFiles]) else { return nil }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    func delete(_ name: String) async throws {
        let dir = modelDir(for: name)
        guard fm.fileExists(atPath: dir.path) else {
            throw WhisperModelStoreError.notFound
        }
        do {
            try fm.removeItem(at: dir)
            logger.info("deleted model: \(name, privacy: .public)")
        } catch {
            throw WhisperModelStoreError.ioFailure(String(describing: error))
        }
    }

    private func modelDir(for name: String) -> URL {
        root.appendingPathComponent("openai_whisper-\(name)")
    }
}
```

- [ ] **Step 5: Regenerar projeto e rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|FAIL|SUCCESS" | tail -5
```

Esperado: 162 + 6 novos = 168 testes verdes.

- [ ] **Step 6: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Transcription/WhisperModelStore.swift \
        app/Tagarela/Transcription/WhisperModelStoreLive.swift \
        app/TagarelaTests/WhisperModelStoreTests.swift \
        app/Tagarela.xcodeproj
git commit -m "$(cat <<'EOF'
feat(transcription): WhisperModelStore (protocol + Live)

Abstrai leitura/exclusão de modelos do cache WhisperKit. Live usa FileManager
no path default do WhisperKit 0.9.x.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 3: `Preferences.whisperModelName` — campo + default + persistência

Objetivo: adicionar `whisperModelName` ao `PreferencesStore`, com default `"large-v3-turbo"` em novos installs (chave ausente). Migration em users existentes (chave ausente E modelo já em disco) é responsabilidade do AppContainer e está na Tarefa 9.

**Files:**
- Modify: `app/Tagarela/Preferences/Preferences+Defaults.swift`
- Modify: `app/Tagarela/Preferences/PreferencesStore.swift`
- Modify: `app/TagarelaTests/PreferencesStoreTests.swift`

- [ ] **Step 1: Escrever teste falhando**

Adicionar ao `PreferencesStoreTests.swift` (no fim do `final class PreferencesStoreTests`):

```swift
    func test_whisperModelName_defaultsToTurbo_whenAbsent() {
        let suite = makeIsolatedDefaults()
        let store = PreferencesStore(defaults: suite, defaultStyleID: UUID())
        XCTAssertEqual(store.whisperModelName, "large-v3-turbo")
    }

    func test_whisperModelName_persistsAcrossInits() {
        let suite = makeIsolatedDefaults()
        let store1 = PreferencesStore(defaults: suite, defaultStyleID: UUID())
        store1.whisperModelName = "large-v3"
        let store2 = PreferencesStore(defaults: suite, defaultStyleID: UUID())
        XCTAssertEqual(store2.whisperModelName, "large-v3")
    }
```

(`makeIsolatedDefaults()` é helper já existente em `PreferencesStoreTests.swift`. Confirmar antes de escrever — se nome divergir, ajustar pra usar o helper local existente.)

- [ ] **Step 2: Verificar que falha**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "FAIL|error:" | head -5
```

Esperado: "Value of type 'PreferencesStore' has no member 'whisperModelName'".

- [ ] **Step 3: Adicionar chave + default**

Em `app/Tagarela/Preferences/Preferences+Defaults.swift`:

Adicionar dentro do enum `PreferencesKey`:
```swift
    static let whisperModelName     = "com.tagarela.preferences.whisperModelName"
```

Adicionar dentro do enum `PreferencesDefaults`:
```swift
    static let whisperModelName: String   = "large-v3-turbo"
```

- [ ] **Step 4: Adicionar campo @Published em `PreferencesStore`**

Em `app/Tagarela/Preferences/PreferencesStore.swift`, dentro da classe (ordem alfabética com os outros @Published; pode colocar logo antes do `init`):

```swift
    @Published var whisperModelName: String {
        didSet { defaults.set(whisperModelName, forKey: PreferencesKey.whisperModelName) }
    }
```

E no `init(defaults:defaultStyleID:)`, adicionar a leitura inicial logo antes do `super.init` ou no fim do bloco existente:

```swift
        self.whisperModelName = defaults.string(forKey: PreferencesKey.whisperModelName)
            ?? PreferencesDefaults.whisperModelName
```

- [ ] **Step 5: Rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|FAIL|SUCCESS" | tail -5
```

Esperado: 168 + 2 = 170 testes verdes.

- [ ] **Step 6: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Preferences/Preferences+Defaults.swift \
        app/Tagarela/Preferences/PreferencesStore.swift \
        app/TagarelaTests/PreferencesStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(prefs): whisperModelName em PreferencesStore (default large-v3-turbo)

Adiciona campo @Published whisperModelName persistido em UserDefaults.
Default "large-v3-turbo". Migration de users existentes vem na Tarefa 9.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 4: `WhisperKitTranscriber` — knobs ANE/prewarm + timing log + `unloadModel()`

Objetivo: ligar `prewarmModels: true` e `computeOptions = ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine)`; instrumentar `transcribe()` com log de wall-clock; expor `unloadModel()` pra liberar memória após swap.

**Aceite manual obrigatório antes de mergear** (toca IO + ANE; lição 2c-cleanup).

**Files:**
- Modify: `app/Tagarela/Transcription/Transcribing.swift`
- Modify: `app/Tagarela/Transcription/WhisperKitTranscriber.swift`

- [ ] **Step 1: Adicionar `unloadModel()` ao protocolo**

Em `app/Tagarela/Transcription/Transcribing.swift`, adicionar no protocol:

```swift
protocol Transcribing: AnyObject, Sendable {
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws
    func transcribe(buffer: AudioBuffer,
                    language: String,
                    initialPrompt: String?) async throws -> String
    func unloadModel()
    var loadedModelName: String? { get }
}
```

- [ ] **Step 2: Atualizar fakes existentes pro novo método**

Editar `app/TagarelaTests/PipelineCoordinatorTests.swift` — adicionar `func unloadModel() {}` em ambos `FakeTranscriber` e `FakeTranscriberSlow` (linhas ~370 e ~418).

```swift
private final class FakeTranscriber: Transcribing, @unchecked Sendable {
    var loadedModelName: String? = "fake"
    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {}
    func transcribe(buffer: AudioBuffer, language: String, initialPrompt: String?) async throws -> String {
        "olá mundo"
    }
    func unloadModel() { loadedModelName = nil }
}
```

E no `FakeTranscriberSlow`:
```swift
    func unloadModel() { loadedModelName = nil }
```

- [ ] **Step 3: Adicionar knobs + log + impl de unloadModel em `WhisperKitTranscriber`**

Em `app/Tagarela/Transcription/WhisperKitTranscriber.swift`, substituir o conteúdo todo por:

```swift
import Foundation
import OSLog
import WhisperKit

/// Adaptador do WhisperKit (0.9+) pro protocolo Transcribing.
///
/// Fluxo de loadModel: usa WhisperKit.download(variant:progressCallback:) pra
/// baixar com progresso, depois inicializa WhisperKit apontando pro modelFolder
/// local com prewarm + computeOptions ANE-explícitos.
final class WhisperKitTranscriber: Transcribing, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "Transcribe")
    private var pipe: WhisperKit?
    private(set) var loadedModelName: String?

    func loadModel(_ name: String,
                   onProgress: @escaping (Double) -> Void) async throws {
        do {
            let modelFolder = try await WhisperKit.download(variant: name) { progress in
                onProgress(progress.fractionCompleted)
            }
            let config = WhisperKitConfig(
                modelFolder: modelFolder.path,
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                ),
                prewarmModels: true,
                load: true
            )
            let pipe = try await WhisperKit(config)
            self.pipe = pipe
            self.loadedModelName = name
            logger.info("loaded whisper model: \(name, privacy: .public)")
        } catch {
            throw TranscribeError.modelDownloadFailed(String(describing: error))
        }
    }

    func unloadModel() {
        pipe = nil
        loadedModelName = nil
        logger.info("unloaded whisper model")
    }

    func transcribe(buffer: AudioBuffer,
                    language: String,
                    initialPrompt: String?) async throws -> String {
        guard let pipe else { throw TranscribeError.modelNotLoaded }
        guard buffer.durationSeconds >= 0.5 else { throw TranscribeError.bufferTooShort }

        let promptTokens: [Int]?
        if ProcessInfo.processInfo.environment["TAGARELA_DISABLE_PROMPT"] == "1" {
            promptTokens = nil
            logger.info("promptTokens desabilitado via env var TAGARELA_DISABLE_PROMPT=1")
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
            withoutTimestamps: true,
            promptTokens: promptTokens
        )

        do {
            let start = Date()
            let results: [TranscriptionResult] = try await pipe.transcribe(
                audioArray: buffer.samples,
                decodeOptions: opts
            )
            let wallMs = Int(Date().timeIntervalSince(start) * 1000)
            let audioSec = String(format: "%.1f", buffer.durationSeconds)
            let modelName = self.loadedModelName ?? "?"
            logger.info("transcribe model=\(modelName, privacy: .public) audio=\(audioSec, privacy: .public)s wall=\(wallMs, privacy: .public)ms")

            let text = results.map(\.text).joined(separator: " ")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw TranscribeError.transcriptionFailed(String(describing: error))
        }
    }
}
```

- [ ] **Step 4: Build + rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|FAIL|SUCCESS" | tail -5
```

Esperado: 170 verdes (sem novos testes; só refactor de fakes).

- [ ] **Step 5: ACEITE MANUAL — rodar app, ditar 1×, conferir log no Console.app**

```bash
cd /Users/tars/Dev/tagarela
pkill -x Tagarela 2>/dev/null
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Library/Developer/Xcode/DerivedData/Tagarela-*/Build/Products/Debug/Tagarela.app /Users/tars/Applications/Tagarela.app
open /Users/tars/Applications/Tagarela.app
```

Em Console.app (filtro: `subsystem:com.tagarela category:Transcribe`):
1. Disparar hotkey, ditar ~3s.
2. Esperar transcrição.
3. Confirmar log `transcribe model=large-v3 audio=3.X s wall=YYYYms` aparece (large-v3 porque `prefs.whisperModelName` ainda não está cabeado no AppContainer — vem na Tarefa 9; nesta tarefa só queremos validar o log + knobs sem regressão).
4. Confirmar que pílula apareceu, transcribe terminou, texto foi injetado. Sem regressão.

Pedir confirmação ao user antes de seguir.

- [ ] **Step 6: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Transcription/Transcribing.swift \
        app/Tagarela/Transcription/WhisperKitTranscriber.swift \
        app/TagarelaTests/PipelineCoordinatorTests.swift
git commit -m "$(cat <<'EOF'
feat(transcribe): knobs ANE/prewarm + timing log + unloadModel

WhisperKitConfig agora seta prewarmModels=true e computeOptions explícito
pra ANE (Apple Silicon; Intel ignora). transcribe() loga model/audio/wall
ms via Logger.tagarela. Protocol Transcribing ganha unloadModel() —
WhisperKitTranscriber libera pipe; fakes implementam no-op.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 5: `WhisperModelSwapCoordinator` — máquina de estado do swap em runtime

Objetivo: orquestrar troca de modelo em Preferências sem interromper hotkey durante o download. Estados: `.idle`, `.downloading`, `.swapping`, `.failed`. Coordinator usa um `Transcribing` separado pra carregar o target, depois pede ao AppContainer pra trocar o ponteiro ativo.

**Files:**
- Create: `app/Tagarela/Transcription/WhisperModelSwapCoordinator.swift`
- Create: `app/TagarelaTests/WhisperModelSwapCoordinatorTests.swift`

- [ ] **Step 1: Esboçar protocol/types**

Criar `app/Tagarela/Transcription/WhisperModelSwapCoordinator.swift`:

```swift
import Combine
import Foundation
import OSLog

enum SwapState: Equatable {
    case idle(active: String)
    case downloading(active: String, target: String, progress: Double)
    case swapping(active: String, target: String)
    case failed(active: String, target: String, error: SwapError)
}

enum SwapError: Error, Equatable {
    case downloadFailed(String)
    case loadFailed(String)
    case cancelled
}

/// Orquestra troca de modelo Whisper em runtime.
///
/// Convenção: durante `.downloading` o "transcriber ativo" continua respondendo
/// a hotkey usando o modelo antigo. Coordinator instancia um Transcribing
/// separado (`stagingFactory`) pra baixar/carregar o target. Quando carregamento
/// termina, chama `swapActive` pra trocar o ponteiro no AppContainer; depois
/// chama `unloadModel()` no antigo (passado via callback).
@MainActor
final class WhisperModelSwapCoordinator: ObservableObject {
    private let logger = Logger(subsystem: "com.tagarela", category: "SwapCoordinator")

    @Published private(set) var state: SwapState

    /// Factory que cria um novo Transcribing pra staging (download/load do target).
    /// Em produção: `{ WhisperKitTranscriber() }`. Em teste: fake controlado.
    private let stagingFactory: @Sendable () -> Transcribing

    /// Chamado após load do novo terminar com sucesso. Recebe o staging
    /// transcriber (já carregado) e deve trocar o ponteiro ativo no AppContainer
    /// + retornar o transcriber antigo (que será unloaded).
    private let swapActive: @MainActor (_ newActive: Transcribing) -> Transcribing

    private var swapTask: Task<Void, Never>?

    init(initialActive: String,
         stagingFactory: @escaping @Sendable () -> Transcribing,
         swapActive: @escaping @MainActor (_ newActive: Transcribing) -> Transcribing) {
        self.state = .idle(active: initialActive)
        self.stagingFactory = stagingFactory
        self.swapActive = swapActive
    }

    /// Pede troca pro target. Se já está em `.downloading` ou `.swapping`, no-op.
    func requestSwap(target: String) {
        guard case .idle(let active) = state, active != target else {
            logger.info("requestSwap ignored (state=\(String(describing: self.state), privacy: .public))")
            return
        }
        startSwap(from: active, to: target)
    }

    /// Reinicia swap após `.failed`. Mesma lógica do `requestSwap` mas a partir
    /// do estado de erro.
    func retry() {
        guard case .failed(let active, let target, _) = state else { return }
        startSwap(from: active, to: target)
    }

    /// Cancela download em curso. Volta pra `.idle(active: <original>)`.
    func cancel() {
        swapTask?.cancel()
    }

    private func startSwap(from active: String, to target: String) {
        state = .downloading(active: active, target: target, progress: 0)
        let staging = stagingFactory()
        swapTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await staging.loadModel(target) { [weak self] p in
                    Task { @MainActor in
                        guard let self else { return }
                        if case .downloading(let a, let t, _) = self.state {
                            self.state = .downloading(active: a, target: t, progress: p)
                        }
                    }
                }
                if Task.isCancelled {
                    self.state = .idle(active: active)
                    return
                }
                self.state = .swapping(active: active, target: target)
                let oldActive = self.swapActive(staging)
                oldActive.unloadModel()
                self.state = .idle(active: target)
                self.logger.info("swap done: \(active, privacy: .public) -> \(target, privacy: .public)")
            } catch is CancellationError {
                self.state = .idle(active: active)
            } catch let TranscribeError.modelDownloadFailed(reason) {
                self.state = .failed(active: active, target: target,
                                     error: .downloadFailed(reason))
                self.logger.error("swap downloadFailed: \(reason, privacy: .public)")
            } catch {
                self.state = .failed(active: active, target: target,
                                     error: .loadFailed(String(describing: error)))
                self.logger.error("swap loadFailed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
```

- [ ] **Step 2: Escrever testes (TDD pesado — múltiplos cenários)**

Criar `app/TagarelaTests/WhisperModelSwapCoordinatorTests.swift`:

```swift
import XCTest
import Combine
@testable import Tagarela

@MainActor
final class WhisperModelSwapCoordinatorTests: XCTestCase {

    func test_initialState_isIdleWithGivenActive() {
        let coord = makeCoord(initialActive: "large-v3", stagingBehavior: .immediateSuccess)
        XCTAssertEqual(coord.state, .idle(active: "large-v3"))
    }

    func test_requestSwap_sameModel_noop() {
        let coord = makeCoord(initialActive: "large-v3-turbo", stagingBehavior: .immediateSuccess)
        coord.requestSwap(target: "large-v3-turbo")
        XCTAssertEqual(coord.state, .idle(active: "large-v3-turbo"))
    }

    func test_requestSwap_happyPath_endsInIdleAtTarget() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3-turbo")
        var swappedFrom: String?
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in
                swappedFrom = oldT.loadedModelName
                return oldT
            }
        )
        coord.requestSwap(target: "large-v3-turbo")
        await Task.yield()
        await waitFor { coord.state == .idle(active: "large-v3-turbo") }
        XCTAssertEqual(swappedFrom, "large-v3")
        XCTAssertNil(oldT.loadedModelName)  // unloadModel foi chamado
    }

    func test_requestSwap_downloadFails_endsInFailedDownloadFailed() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3-turbo")
        newT.loadError = TranscribeError.modelDownloadFailed("network err")
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3-turbo")
        await waitFor {
            if case .failed(_, _, let err) = coord.state {
                return err == .downloadFailed("network err")
            }
            return false
        }
    }

    func test_retry_afterFailure_reentersDownloading() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3-turbo")
        newT.loadError = TranscribeError.modelDownloadFailed("network")
        var produced = 0
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { produced += 1; return newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3-turbo")
        await waitFor {
            if case .failed = coord.state { return true }
            return false
        }
        // Limpar erro pra retry passar
        newT.loadError = nil
        coord.retry()
        await waitFor { coord.state == .idle(active: "large-v3-turbo") }
        XCTAssertEqual(produced, 1, "stagingFactory é instanciada 1× e reusada na retry — se mudar pra recriar, ajustar este teste")
    }

    func test_cancel_duringDownload_returnsToIdleWithOldActive() async {
        let oldT = FakeT(name: "large-v3")
        let newT = FakeT(name: "large-v3-turbo")
        newT.loadDelayNs = 500_000_000  // 0.5s — tempo pra cancelar antes
        let coord = WhisperModelSwapCoordinator(
            initialActive: "large-v3",
            stagingFactory: { newT },
            swapActive: { _ in oldT }
        )
        coord.requestSwap(target: "large-v3-turbo")
        try? await Task.sleep(nanoseconds: 50_000_000)
        coord.cancel()
        await waitFor { coord.state == .idle(active: "large-v3") }
    }

    // MARK: - Helpers

    private func makeCoord(initialActive: String,
                           stagingBehavior: StagingBehavior) -> WhisperModelSwapCoordinator {
        let staging = FakeT(name: "target")
        switch stagingBehavior {
        case .immediateSuccess: break
        case .immediateFailure(let err): staging.loadError = err
        }
        return WhisperModelSwapCoordinator(
            initialActive: initialActive,
            stagingFactory: { staging },
            swapActive: { _ in FakeT(name: initialActive) }
        )
    }

    private enum StagingBehavior {
        case immediateSuccess
        case immediateFailure(Error)
    }

    private func waitFor(_ predicate: @escaping () -> Bool,
                         timeoutSec: Double = 2.0) async {
        let deadline = Date().addingTimeInterval(timeoutSec)
        while Date() < deadline {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("waitFor timeout")
    }
}

private final class FakeT: Transcribing, @unchecked Sendable {
    var loadedModelName: String?
    var loadError: Error?
    var loadDelayNs: UInt64 = 0

    init(name: String) { self.loadedModelName = name }

    func loadModel(_ name: String, onProgress: @escaping (Double) -> Void) async throws {
        if loadDelayNs > 0 {
            try await Task.sleep(nanoseconds: loadDelayNs)
        }
        if let err = loadError { throw err }
        onProgress(1.0)
        loadedModelName = name
    }

    func transcribe(buffer: AudioBuffer, language: String, initialPrompt: String?) async throws -> String {
        ""
    }

    func unloadModel() {
        loadedModelName = nil
    }
}
```

- [ ] **Step 3: Regenerar projeto e rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|FAIL|SUCCESS" | tail -5
```

Esperado: 170 + 5 = 175 testes verdes.

- [ ] **Step 4: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Transcription/WhisperModelSwapCoordinator.swift \
        app/TagarelaTests/WhisperModelSwapCoordinatorTests.swift \
        app/Tagarela.xcodeproj
git commit -m "$(cat <<'EOF'
feat(transcription): WhisperModelSwapCoordinator (state machine)

Orquestra troca de modelo em runtime: idle → downloading → swapping → idle
(happy), com error path (.failed → retry/cancel) e cancel mid-download.
Hotkey continua funcionando durante .downloading; AppContainer troca o
ponteiro ativo via callback @MainActor.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 6: `WhisperModelPicker` — componente compartilhado

Objetivo: componente SwiftUI reutilizável entre Onboarding e Preferências. Renderiza linha por modelo (radio + nome + tamanho + RAM + badge "recom.") com base em `WhisperModelCatalog.all`.

**Aceite manual obrigatório antes de mergear** (toca SwiftUI; lição 2c-cleanup).

**Files:**
- Create: `app/Tagarela/Preferences/UI/Components/WhisperModelPicker.swift`

- [ ] **Step 1: Implementar componente**

Criar `app/Tagarela/Preferences/UI/Components/WhisperModelPicker.swift`:

```swift
import SwiftUI

/// Picker visual de modelo Whisper, compartilhado entre Onboarding e Preferências.
///
/// Renderiza uma linha por entrada do `WhisperModelCatalog.all` com radio,
/// nome técnico, tamanho/RAM display, e badge "RECOM." pros recomendados.
/// Quando `enabled == false`, todas as linhas ficam não-clicáveis (mas
/// continuam destacando a seleção atual — usado durante swap em curso).
struct WhisperModelPicker: View {
    @Binding var selected: String
    let enabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(WhisperModelCatalog.all) { model in
                row(model: model)
            }
        }
    }

    @ViewBuilder
    private func row(model: WhisperModelInfo) -> some View {
        let isSelected = selected == model.name
        Button(action: { if enabled { selected = model.name } }) {
            HStack(spacing: 10) {
                Circle()
                    .stroke(DS.Color.ink, lineWidth: 1.2)
                    .background(isSelected ? Circle().fill(DS.Color.ink).padding(3) : nil)
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(DS.Font.mono(12, weight: .medium))
                        .foregroundStyle(DS.Color.ink)
                    Text("\(model.displaySize) · \(model.displayRAM) RAM")
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.ink3)
                }
                Spacer()
                if model.recommended {
                    Text(String(localized: "transcription.picker.badge.recommended",
                                 defaultValue: "RECOM."))
                        .font(DS.Font.mono(9))
                        .tracking(1)
                        .foregroundStyle(DS.Color.carmine)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .stroke(DS.Color.carmine, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(isSelected ? DS.Color.paper2 : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? DS.Color.ink : DS.Color.hairlineStrong, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.6)
    }
}

#Preview {
    @Previewable @State var sel = "large-v3-turbo"
    return WhisperModelPicker(selected: $sel, enabled: true)
        .padding(20)
        .frame(width: 480)
        .background(DS.Color.paper)
}
```

- [ ] **Step 2: Regenerar projeto, build**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
```

Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: ACEITE MANUAL — abrir SwiftUI preview no Xcode**

```bash
open /Users/tars/Dev/tagarela/app/Tagarela.xcodeproj
```

Em Xcode: navegar pra `WhisperModelPicker.swift`, abrir Canvas (`⌘ ⌥ ↵`). Confirmar:
1. 3 linhas aparecem na ordem: large-v3-turbo, large-v3, medium.
2. large-v3-turbo está selecionado por default e tem badge "RECOM.".
3. Tamanhos exibidos: "815 MB · ≥ 4 GB RAM", "2.9 GB · ≥ 16 GB RAM", "1.4 GB · ≥ 8 GB RAM".
4. Clicar em outras linhas troca a seleção.
5. Sem frame retangular ao redor (lição da fix de sombras de hoje).

Pedir confirmação ao user antes de seguir.

- [ ] **Step 4: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Preferences/UI/Components/WhisperModelPicker.swift \
        app/Tagarela.xcodeproj
git commit -m "$(cat <<'EOF'
feat(prefs/ui): WhisperModelPicker componente compartilhado

Picker visual reutilizado entre Onboarding e Preferências. Renderiza
catálogo do WhisperModelCatalog com radio + tamanho + RAM + badge
"RECOM." pros recomendados.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 7: Onboarding — picker funcional + erro inline

Objetivo: trocar os 3 radios decorativos por `WhisperModelPicker` real, fazer "começar →" baixar o modelo selecionado, gravar em `prefs.whisperModelName` ao concluir, mostrar erro inline se download falhar.

**Aceite manual obrigatório antes de mergear** (toca SwiftUI + IO; lição 2c-cleanup).

**Files:**
- Modify: `app/Tagarela/UI/Onboarding/OnboardModel.swift`
- Modify: `app/Tagarela/UI/Onboarding/OnboardingWindow.swift`
- Modify: `app/Tagarela/UI/Onboarding/OnboardingCoordinator.swift`

- [ ] **Step 1: `OnboardingCoordinator` ganha state de erro + grava prefs**

Em `app/Tagarela/UI/Onboarding/OnboardingCoordinator.swift`, substituir o conteúdo todo:

```swift
import SwiftUI

@MainActor
final class OnboardingCoordinator: ObservableObject {
    enum Step { case welcome, perms, model }

    @Published var step: Step = .welcome
    @Published var permsSnapshot: PermissionsSnapshot
    @Published var modelDownloadProgress: Double = 0
    @Published var modelLoaded: Bool = false
    @Published var modelLoadError: String?
    @Published var selectedModel: String = WhisperModelCatalog.all.first(where: { $0.recommended })?.name
                                          ?? "large-v3-turbo"

    let permissionService: PermissionService
    let transcriber: Transcribing
    private let prefs: PreferencesStore

    init(permissionService: PermissionService,
         transcriber: Transcribing,
         prefs: PreferencesStore) {
        self.permissionService = permissionService
        self.transcriber = transcriber
        self.prefs = prefs
        self.permsSnapshot = permissionService.snapshot()
        Task { [weak self] in
            guard let self else { return }
            for await snap in self.permissionService.snapshots {
                await MainActor.run { self.permsSnapshot = snap }
            }
        }
    }

    func advance() {
        switch step {
        case .welcome: step = .perms
        case .perms: step = .model
        case .model: break
        }
    }

    func back() {
        switch step {
        case .welcome: break
        case .perms: step = .welcome
        case .model: step = .perms
        }
    }

    func loadSelectedModel() {
        modelLoaded = false
        modelDownloadProgress = 0
        modelLoadError = nil
        let name = selectedModel
        Task { [weak self] in
            guard let self else { return }
            do {
                try await transcriber.loadModel(name) { [weak self] p in
                    Task { @MainActor in self?.modelDownloadProgress = p }
                }
                await MainActor.run {
                    self.modelLoaded = true
                    self.prefs.whisperModelName = name
                }
            } catch {
                await MainActor.run {
                    self.modelLoadError = String(describing: error)
                }
            }
        }
    }
}
```

- [ ] **Step 2: `OnboardModel` usa o picker + mostra erro inline**

Substituir conteúdo de `app/Tagarela/UI/Onboarding/OnboardModel.swift`:

```swift
import SwiftUI

struct OnboardModel: View {
    @Binding var selected: String
    let downloadProgress: Double
    let loaded: Bool
    let errorMessage: String?
    var onRetry: () -> Void
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "onboarding.step3.label", defaultValue: "PASSO 3 / 3"))
                    .font(DS.Font.mono(9)).tracking(1.4).foregroundStyle(DS.Color.ink3)
                Text(String(localized: "onboarding.model.headline", defaultValue: "modelos."))
                    .font(DS.Font.display(26)).foregroundStyle(DS.Color.ink)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "onboarding.model.whisper.header", defaultValue: "WHISPER · TRANSCRIÇÃO"))
                    .font(DS.Font.mono(10)).tracking(1.4).foregroundStyle(DS.Color.ink3)
                WhisperModelPicker(selected: $selected, enabled: !loaded)
                if !loaded && downloadProgress > 0 && errorMessage == nil {
                    HStack(spacing: 8) {
                        ProgressView(value: downloadProgress)
                            .progressViewStyle(.linear)
                            .tint(DS.Color.carmine)
                        Text(String(localized: "onboarding.model.downloading",
                                     defaultValue: "baixando \(Int(downloadProgress * 100))%"))
                            .font(DS.Font.mono(10))
                            .foregroundStyle(DS.Color.ink3)
                    }
                }
                if let errorMessage {
                    HStack(spacing: 8) {
                        Text(String(localized: "onboarding.model.error",
                                     defaultValue: "falha: \(errorMessage) · tentar de novo"))
                            .font(DS.Font.mono(10))
                            .foregroundStyle(DS.Color.carmineDeep)
                        Button("retry") { onRetry() }
                            .buttonStyle(.plain)
                            .font(DS.Font.mono(10, weight: .medium))
                            .foregroundStyle(DS.Color.carmine)
                    }
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button(action: onStart) {
                    Text(String(localized: "onboarding.button.start", defaultValue: "começar →"))
                        .font(DS.Font.mono(12))
                        .foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(loaded ? DS.Color.ink : DS.Color.ink3,
                                    in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!loaded)
            }
        }
        .padding(.horizontal, 48).padding(.vertical, 40)
        .frame(width: 560, height: 560)
        .background(DS.Color.paper)
    }
}
```

- [ ] **Step 3: `OnboardingWindow` propaga selection + dispara load + retry**

Substituir conteúdo de `app/Tagarela/UI/Onboarding/OnboardingWindow.swift`:

```swift
import SwiftUI

struct OnboardingWindow: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @Environment(\.dismissWindow) private var dismissWindow
    var onFinish: () -> Void

    var body: some View {
        Group {
            switch coordinator.step {
            case .welcome:
                OnboardWelcome(onContinue: { coordinator.advance() })
            case .perms:
                OnboardPerms(
                    snapshot: coordinator.permsSnapshot,
                    onMicTap: {
                        Task { _ = await coordinator.permissionService.requestMicrophone() }
                    },
                    onAccessibilityTap: { coordinator.permissionService.openAccessibilitySettings() },
                    onInputMonitoringTap: { coordinator.permissionService.openInputMonitoringSettings() },
                    onContinue: { coordinator.advance() },
                    onBack: { coordinator.back() }
                )
            case .model:
                OnboardModel(
                    selected: $coordinator.selectedModel,
                    downloadProgress: coordinator.modelDownloadProgress,
                    loaded: coordinator.modelLoaded,
                    errorMessage: coordinator.modelLoadError,
                    onRetry: { coordinator.loadSelectedModel() },
                    onStart: {
                        onFinish()
                        dismissWindow(id: "onboarding")
                    }
                )
                .onAppear { coordinator.loadSelectedModel() }
                .onChange(of: coordinator.selectedModel) { _, _ in
                    coordinator.loadSelectedModel()
                }
            }
        }
    }
}
```

- [ ] **Step 4: `AppContainer` instancia coordinator com `prefs`**

Em `app/Tagarela/App/AppContainer.swift`, localizar a instanciação de `OnboardingCoordinator` (linha ~147):

Antes:
```swift
self.onboarding = OnboardingCoordinator(
    permissionService: permissions, transcriber: transcriber
)
```

Depois:
```swift
self.onboarding = OnboardingCoordinator(
    permissionService: permissions, transcriber: transcriber, prefs: prefs
)
```

- [ ] **Step 5: Build**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
```

Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: ACEITE MANUAL — fluxo onboarding completo**

```bash
# Limpar UserDefaults pra forçar onboarding
defaults delete com.tagarela.Tagarela 2>/dev/null
pkill -x Tagarela 2>/dev/null
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Library/Developer/Xcode/DerivedData/Tagarela-*/Build/Products/Debug/Tagarela.app /Users/tars/Applications/Tagarela.app
open /Users/tars/Applications/Tagarela.app
```

Validar:
1. Onboarding aparece, vai até Passo 3.
2. Picker mostra 3 modelos com large-v3-turbo selecionado + badge.
3. Download inicia automaticamente. Progresso visível.
4. Trocar pra `medium` mid-download — confirma re-download de medium.
5. Após concluir, "começar →" habilita; clicar fecha onboarding.
6. Verificar via `defaults read com.tagarela.Tagarela com.tagarela.preferences.whisperModelName` → "medium".

Bonus (negativo): desligar Wi-Fi durante download → ver erro inline + botão retry. Religar Wi-Fi, clicar retry, validar recuperação.

Pedir confirmação ao user antes de seguir.

- [ ] **Step 7: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/UI/Onboarding/ app/Tagarela/App/AppContainer.swift
git commit -m "$(cat <<'EOF'
feat(onboarding): picker funcional de modelo Whisper + erro inline

Substitui radios decorativos pelo WhisperModelPicker. Trocar de modelo
durante onboarding cancela e re-baixa. Erro de download mostra mensagem
inline + botão retry. Modelo escolhido é gravado em prefs.whisperModelName
ao concluir. Resolve bug latente dos radios fake.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 8: Preferências > Transcrição — section nova + sheet de erro

Objetivo: nova seção em Preferências com picker, estado dinâmico baseado no `WhisperModelSwapCoordinator`, alerta de confirmação antes do swap, alerta de cleanup após swap, sheet modal de erro com retry.

**Aceite manual obrigatório antes de mergear** (toca SwiftUI; lição 2c-cleanup).

**Files:**
- Modify: `app/Tagarela/Preferences/UI/PrefsSection.swift`
- Modify: `app/Tagarela/Preferences/UI/PreferencesRoot.swift`
- Create: `app/Tagarela/Preferences/UI/Sections/TranscriptionView.swift`
- Create: `app/Tagarela/Preferences/UI/Sheets/SwapErrorSheet.swift`

- [ ] **Step 1: Adicionar enum case `transcricao` em `PrefsSection`**

Em `app/Tagarela/Preferences/UI/PrefsSection.swift`, adicionar logo após `case geral`:

```swift
    case transcricao
```

E no `var label`, adicionar:
```swift
        case .transcricao:   return String(localized: "preferences.section.transcricao", defaultValue: "Transcrição")
```

- [ ] **Step 2: Criar `SwapErrorSheet`**

Criar `app/Tagarela/Preferences/UI/Sheets/SwapErrorSheet.swift`:

```swift
import SwiftUI

struct SwapErrorSheet: View {
    let target: String
    let errorMessage: String
    var onRetry: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "preferences.transcription.swap.error.title",
                         defaultValue: "Falha ao trocar"))
                .font(DS.Font.display(20))
                .foregroundStyle(DS.Color.ink)
            Text(String(localized: "preferences.transcription.swap.error.body",
                         defaultValue: "Não consegui mudar pra \(target).\n\n\(errorMessage)"))
                .font(DS.Font.mono(11))
                .foregroundStyle(DS.Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(String(localized: "preferences.transcription.swap.error.close",
                              defaultValue: "Fechar")) { onClose() }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(DS.Color.hairlineStrong, lineWidth: 0.5))
                Button(action: onRetry) {
                    Text(String(localized: "preferences.transcription.swap.error.retry",
                                 defaultValue: "Tentar de novo"))
                        .foregroundStyle(DS.Color.paper)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(DS.Color.ink, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(DS.Color.paper)
    }
}
```

- [ ] **Step 3: Criar `TranscriptionView`**

Criar `app/Tagarela/Preferences/UI/Sections/TranscriptionView.swift`:

```swift
import SwiftUI

struct TranscriptionView: View {
    @ObservedObject var prefs: PreferencesStore
    @ObservedObject var swapCoordinator: WhisperModelSwapCoordinator
    let modelStore: WhisperModelStore

    @State private var pendingTarget: String?            // alerta de confirmação
    @State private var pendingCleanup: String?           // alerta de cleanup pós-swap
    @State private var errorSheetVisible: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(String(localized: "preferences.section.transcricao", defaultValue: "Transcrição"))
                    .font(DS.Font.display(22))
                Text(String(localized: "preferences.transcription.activeModel",
                             defaultValue: "Modelo ativo: \(activeName)"))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink2)
                WhisperModelPicker(
                    selected: Binding(
                        get: { activeName },
                        set: { newValue in
                            guard newValue != activeName else { return }
                            pendingTarget = newValue
                        }
                    ),
                    enabled: pickerEnabled
                )
                statusBlock
            }
            .padding(20)
        }
        .alert(String(localized: "preferences.transcription.swapConfirm.title",
                       defaultValue: "Trocar pra \(pendingTarget ?? "")?"),
               isPresented: Binding(
                    get: { pendingTarget != nil },
                    set: { if !$0 { pendingTarget = nil } }
               )) {
            Button(String(localized: "common.cancel", defaultValue: "Cancelar"),
                   role: .cancel) { pendingTarget = nil }
            Button(String(localized: "preferences.transcription.swapConfirm.proceed",
                           defaultValue: "Trocar")) {
                if let target = pendingTarget {
                    swapCoordinator.requestSwap(target: target)
                }
                pendingTarget = nil
            }
        } message: {
            if let target = pendingTarget,
               let info = WhisperModelCatalog.info(for: target) {
                Text(String(localized: "preferences.transcription.swapConfirm.body",
                             defaultValue: "Vai baixar \(info.displaySize). Você pode continuar usando o app durante o download."))
            }
        }
        .alert(String(localized: "preferences.transcription.deletePrevious.title",
                       defaultValue: "Apagar \(pendingCleanup ?? "")?"),
               isPresented: Binding(
                    get: { pendingCleanup != nil },
                    set: { if !$0 { pendingCleanup = nil } }
               )) {
            Button(String(localized: "preferences.transcription.deletePrevious.keep",
                           defaultValue: "Manter"), role: .cancel) {
                pendingCleanup = nil
            }
            Button(String(localized: "preferences.transcription.deletePrevious.delete",
                           defaultValue: "Apagar"), role: .destructive) {
                if let target = pendingCleanup {
                    Task {
                        try? await modelStore.delete(target)
                    }
                }
                pendingCleanup = nil
            }
        } message: {
            if let target = pendingCleanup,
               let bytes = modelStore.sizeOnDisk(target) {
                Text(String(localized: "preferences.transcription.deletePrevious.body",
                             defaultValue: "Libera \(formatBytes(bytes)) de espaço."))
            }
        }
        .sheet(isPresented: $errorSheetVisible) {
            if case .failed(_, let target, let err) = swapCoordinator.state {
                SwapErrorSheet(
                    target: target,
                    errorMessage: errorDescription(err),
                    onRetry: {
                        errorSheetVisible = false
                        swapCoordinator.retry()
                    },
                    onClose: {
                        errorSheetVisible = false
                        // coordinator continua em .failed; ao re-entrar Preferências,
                        // cair em .idle com o transcriber ativo (sem mudar fonte).
                        // Pra fechar limpo, podemos invocar cancel() — mas isso
                        // pode no-op em failed. Em vez disso, deixamos coordinator
                        // ser substituído por novo requestSwap (ou ignorado).
                    }
                )
            }
        }
        .onChange(of: swapCoordinator.state) { _, newState in
            handleStateTransition(newState)
        }
    }

    private var activeName: String {
        switch swapCoordinator.state {
        case .idle(let active): return active
        case .downloading(let active, _, _): return active
        case .swapping(let active, _): return active
        case .failed(let active, _, _): return active
        }
    }

    private var pickerEnabled: Bool {
        if case .idle = swapCoordinator.state { return true }
        return false
    }

    @ViewBuilder
    private var statusBlock: some View {
        switch swapCoordinator.state {
        case .idle:
            EmptyView()
        case .downloading(_, let target, let progress):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress).progressViewStyle(.linear).tint(DS.Color.carmine)
                HStack {
                    Text(String(localized: "preferences.transcription.swap.downloading",
                                 defaultValue: "Baixando \(target) — \(Int(progress * 100))%"))
                        .font(DS.Font.mono(10)).foregroundStyle(DS.Color.ink3)
                    Spacer()
                    Button(String(localized: "common.cancel", defaultValue: "Cancelar")) {
                        swapCoordinator.cancel()
                    }
                    .buttonStyle(.plain)
                    .font(DS.Font.mono(10))
                }
            }
        case .swapping(_, let target):
            Text(String(localized: "preferences.transcription.swap.swapping",
                         defaultValue: "Trocando pra \(target)…"))
                .font(DS.Font.mono(10)).foregroundStyle(DS.Color.ink3)
        case .failed:
            EmptyView()  // sheet cobre
        }
    }

    private func handleStateTransition(_ state: SwapState) {
        switch state {
        case .idle(let active):
            // se acabei de mudar (vinha de .swapping), ofereço cleanup do antigo
            if let last = lastActive, last != active, modelStore.isDownloaded(last) {
                pendingCleanup = last
                prefs.whisperModelName = active
            }
            lastActive = active
            errorSheetVisible = false
        case .downloading(let active, _, _):
            lastActive = active
        case .swapping(let active, _):
            lastActive = active
        case .failed:
            errorSheetVisible = true
        }
    }

    @State private var lastActive: String?

    private func errorDescription(_ error: SwapError) -> String {
        switch error {
        case .downloadFailed(let r): return "Falha ao baixar: \(r)"
        case .loadFailed(let r):     return "Falha ao carregar: \(r)"
        case .cancelled:             return "Cancelado."
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let mb = Double(b) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}
```

- [ ] **Step 4: `PreferencesRoot` adiciona NavigationLink + case wire**

Em `app/Tagarela/Preferences/UI/PreferencesRoot.swift`:

(a) Adicionar `let swapCoordinator: WhisperModelSwapCoordinator` e `let modelStore: WhisperModelStore` aos parâmetros (logo após `let injector: Injecting`).

(b) Adicionar NavigationLink no sidebar logo após `geral` (linha ~19):
```swift
                NavigationLink(value: PrefsSection.transcricao) { Label(PrefsSection.transcricao.label, systemImage: "mic.and.signal.meter") }
```

(c) Adicionar case na switch detail (linha ~36):
```swift
            case .transcricao:
                TranscriptionView(prefs: prefs,
                                  swapCoordinator: swapCoordinator,
                                  modelStore: modelStore)
```

- [ ] **Step 5: `AppContainer` instancia + injeta swapCoordinator/modelStore**

Será detalhado na Tarefa 9 — por enquanto, fazer instanciação stub no chamador do `PreferencesRoot` pra build passar.

Localizar onde `PreferencesRoot` é instanciado (provavelmente em `app/Tagarela/App/AppContainer.swift` ou equivalente). Adicionar `swapCoordinator: <stub>` e `modelStore: <stub>` no init temporariamente — refinado na T9.

Stub temporário (cole onde `PreferencesRoot(...)` é construído):
```swift
swapCoordinator: WhisperModelSwapCoordinator(
    initialActive: prefs.whisperModelName,
    stagingFactory: { WhisperKitTranscriber() },
    swapActive: { _ in WhisperKitTranscriber() }  // stub T9 cabeia direito
),
modelStore: WhisperModelStoreLive()
```

- [ ] **Step 6: Build**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
```

Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: ACEITE MANUAL — abrir Preferências > Transcrição**

```bash
pkill -x Tagarela 2>/dev/null
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Library/Developer/Xcode/DerivedData/Tagarela-*/Build/Products/Debug/Tagarela.app /Users/tars/Applications/Tagarela.app
open /Users/tars/Applications/Tagarela.app
```

Abrir Preferências (⌘ ,) > Transcrição. Validar:
1. Section nova aparece no sidebar com ícone `mic.and.signal.meter` e label "Transcrição".
2. Mostra "Modelo ativo: large-v3-turbo" (ou o que `prefs.whisperModelName` definir).
3. WhisperModelPicker visível com seleção atual destacada.
4. Sem frame retangular.

**Não validar troca real ainda** — `swapActive` está stubbed; T9 cabeia direito. Apenas conferir UI estática.

Pedir confirmação ao user antes de seguir.

- [ ] **Step 8: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Preferences/UI/ app/Tagarela.xcodeproj
git commit -m "$(cat <<'EOF'
feat(prefs): section "Transcrição" com picker + alerta swap + sheet erro

Adiciona PrefsSection.transcricao + TranscriptionView que renderiza o
WhisperModelPicker, alertas de confirmação/cleanup e SwapErrorSheet pro
estado .failed. Swap real é cabeado na T9 (AppContainer).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 9: `AppContainer` — wiring real do swap + migration de users existentes

Objetivo: trocar os 2 `loadModelLogging("large-v3")` hardcoded por `loadModelLogging(prefs.whisperModelName)`. Cabear `WhisperModelSwapCoordinator.swapActive` pra trocar o ponteiro real `transcriber` no AppContainer (e bloquear hotkey durante `.swapping`). Implementar migration: se chave `whisperModelName` ausente E modelo ja em disco, gravar `<modelo em disco>` em vez de aplicar default.

**Aceite manual obrigatório antes de mergear** (toca IO + AppContainer; lição 2c-cleanup).

**Files:**
- Modify: `app/Tagarela/App/AppContainer.swift`

- [ ] **Step 1: Migration na boot — detectar modelo já em disco**

Em `app/Tagarela/App/AppContainer.swift`, **antes** de criar `prefs` (logo no início do `init`):

```swift
        // Migration: se whisperModelName ainda não existe em UserDefaults E
        // tem modelo em disco, prefere o que já está em disco (evita download
        // surpresa em users existentes). Novo install: cai pro default.
        let migrationStore = WhisperModelStoreLive()
        let userDefaults = UserDefaults.standard
        if userDefaults.string(forKey: PreferencesKey.whisperModelName) == nil {
            for candidate in ["large-v3", "medium", "small", "large-v3-turbo"] {
                if migrationStore.isDownloaded(candidate) {
                    userDefaults.set(candidate, forKey: PreferencesKey.whisperModelName)
                    break
                }
            }
        }
```

(Após esse bloco, `PreferencesStore(...)` lê o valor migrado.)

- [ ] **Step 2: Trocar `loadModelLogging("large-v3")` por `loadModelLogging(prefs.whisperModelName)`**

Localizar as 2 ocorrências em `AppContainer.swift` (~linhas 177 e 267). Substituir cada `loadModelLogging("large-v3")` por `loadModelLogging(prefs.whisperModelName)`.

- [ ] **Step 3: Cabear o swap coordinator de verdade**

(a) Tornar `transcriber` mutável no AppContainer — declarar como `var transcriber: Transcribing` (em vez de `let`).

(b) Localizar a instanciação stub do `WhisperModelSwapCoordinator` (Tarefa 8 step 5). Substituir por:

```swift
let swapCoord = WhisperModelSwapCoordinator(
    initialActive: prefs.whisperModelName,
    stagingFactory: { WhisperKitTranscriber() },
    swapActive: { [weak self] newActive in
        guard let self else { return WhisperKitTranscriber() }
        let old = self.transcriber
        self.transcriber = newActive
        return old
    }
)
self.swapCoordinator = swapCoord
```

E declarar a propriedade `let swapCoordinator: WhisperModelSwapCoordinator` na classe (com inicialização adequada — pode-se usar `lazy var` se o init não permite circular).

(c) Bloquear hotkey durante `.swapping`. Localizar o wiring do `HotkeyService` (provavelmente `wireHotkeyToPipeline()`). Adicionar antes de processar evento de toggle:

```swift
if case .swapping = swapCoordinator.state {
    Logger.tagarela.info("hotkey ignored: swap in progress")
    return
}
```

(d) Passar `swapCoord` e `WhisperModelStoreLive()` reais pra `PreferencesRoot` no lugar dos stubs.

- [ ] **Step 4: Build + rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|FAIL|SUCCESS" | tail -5
```

Esperado: 175 verdes (sem testes novos nesta tarefa; só wiring).

- [ ] **Step 5: ACEITE MANUAL — fluxo completo de swap**

```bash
pkill -x Tagarela 2>/dev/null
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Library/Developer/Xcode/DerivedData/Tagarela-*/Build/Products/Debug/Tagarela.app /Users/tars/Applications/Tagarela.app
open /Users/tars/Applications/Tagarela.app
```

Validar:

**A. Migration** (user existente com large-v3 em disco):
1. Apagar `prefs.whisperModelName` apenas: `defaults delete com.tagarela.Tagarela com.tagarela.preferences.whisperModelName`.
2. Restart app.
3. Conferir Preferências > Transcrição mostra "Modelo ativo: large-v3" (ou o que estava em disco). Sem swap automático.

**B. Swap fluxo feliz**:
1. Em Preferências > Transcrição, clicar `large-v3-turbo`.
2. Alerta de confirmação aparece. Clicar "Trocar".
3. Barra de progresso aparece. Disparar hotkey, ditar 3s — deve transcrever com modelo antigo (large-v3).
4. Esperar download terminar. Status muda pra "Trocando…" brevemente.
5. Status volta pra "Modelo ativo: large-v3-turbo".
6. Alerta de cleanup aparece: "Apagar large-v3? (libera ~2.9 GB)". Clicar "Apagar".
7. Conferir disco: pasta `large-v3` foi removida.
8. Disparar hotkey. Conferir Console.app: log `transcribe model=large-v3-turbo audio=Xs wall=Yms`. **Yms deve ser sensivelmente menor** que era com large-v3.

**C. Swap erro**:
1. Desligar Wi-Fi.
2. Trocar pra `medium`. Alerta. Confirmar.
3. Download falha após alguns segundos. Sheet modal aparece.
4. "Tentar de novo" em offline ainda → outra falha.
5. Religar Wi-Fi. "Tentar de novo" → sucesso.
6. Cleanup prompt do antigo aparece.

**D. Cancel mid-download**:
1. Trocar pra `large-v3` (pesado).
2. Durante download, clicar "Cancelar".
3. Status volta pra "Modelo ativo: large-v3-turbo".
4. Disparar hotkey — funciona normal com turbo.

Pedir confirmação ao user antes de seguir.

- [ ] **Step 6: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/App/AppContainer.swift
git commit -m "$(cat <<'EOF'
feat(app): cabear whisperModelName no AppContainer + migration + swap real

loadModel passa a ler prefs.whisperModelName (não mais hardcoded "large-v3").
Migration de users existentes: se chave ausente E modelo já em disco,
preserva o disco (sem download surpresa). WhisperModelSwapCoordinator.
swapActive troca o ponteiro real de `transcriber`. Hotkey bloqueia em
.swapping (janela curta).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 10: Localizable strings + LocalizableKeysTests

Objetivo: gravar todas as strings novas em `Localizable.strings` (pt-BR) e adicionar suas chaves ao smoke test de localizable.

**Files:**
- Modify: `app/Tagarela/Localization/pt-BR.lproj/Localizable.strings`
- Modify: `app/TagarelaTests/LocalizableKeysTests.swift`

- [ ] **Step 1: Adicionar chaves no `Localizable.strings`**

Em `app/Tagarela/Localization/pt-BR.lproj/Localizable.strings`, adicionar (no fim do arquivo, agrupadas):

```
/* Fase 2d: transcrição & picker */
"transcription.picker.badge.recommended" = "RECOM.";
"preferences.section.transcricao" = "Transcrição";
"preferences.transcription.activeModel" = "Modelo ativo: %@";
"preferences.transcription.swapConfirm.title" = "Trocar pra %@?";
"preferences.transcription.swapConfirm.body" = "Vai baixar %@. Você pode continuar usando o app durante o download.";
"preferences.transcription.swapConfirm.proceed" = "Trocar";
"preferences.transcription.swap.downloading" = "Baixando %@ — %d%%";
"preferences.transcription.swap.swapping" = "Trocando pra %@…";
"preferences.transcription.swap.error.title" = "Falha ao trocar";
"preferences.transcription.swap.error.body" = "Não consegui mudar pra %@.\n\n%@";
"preferences.transcription.swap.error.retry" = "Tentar de novo";
"preferences.transcription.swap.error.close" = "Fechar";
"preferences.transcription.deletePrevious.title" = "Apagar %@?";
"preferences.transcription.deletePrevious.body" = "Libera %@ de espaço.";
"preferences.transcription.deletePrevious.keep" = "Manter";
"preferences.transcription.deletePrevious.delete" = "Apagar";
"onboarding.model.error" = "falha: %@ · tentar de novo";
"common.cancel" = "Cancelar";
```

(Se `common.cancel` já existir, não duplicar.)

- [ ] **Step 2: Adicionar chaves ao smoke test**

Em `app/TagarelaTests/LocalizableKeysTests.swift`, localizar a lista de chaves esperadas (provavelmente um array `expectedKeys`) e adicionar:

```swift
"transcription.picker.badge.recommended",
"preferences.section.transcricao",
"preferences.transcription.activeModel",
"preferences.transcription.swapConfirm.title",
"preferences.transcription.swapConfirm.body",
"preferences.transcription.swapConfirm.proceed",
"preferences.transcription.swap.downloading",
"preferences.transcription.swap.swapping",
"preferences.transcription.swap.error.title",
"preferences.transcription.swap.error.body",
"preferences.transcription.swap.error.retry",
"preferences.transcription.swap.error.close",
"preferences.transcription.deletePrevious.title",
"preferences.transcription.deletePrevious.body",
"preferences.transcription.deletePrevious.keep",
"preferences.transcription.deletePrevious.delete",
"onboarding.model.error",
```

(Se `common.cancel` ainda não está, adicionar também.)

- [ ] **Step 3: Rodar testes**

```bash
cd /Users/tars/Dev/tagarela/app
xcodebuild -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|FAIL|SUCCESS" | tail -5
```

Esperado: 175 verdes.

- [ ] **Step 4: Commit**

```bash
cd /Users/tars/Dev/tagarela
git add app/Tagarela/Localization/pt-BR.lproj/Localizable.strings \
        app/TagarelaTests/LocalizableKeysTests.swift
git commit -m "$(cat <<'EOF'
i18n: strings da Fase 2d (transcrição) em pt-BR + smoke test

Adiciona chaves pra section Transcrição, picker badge, alertas de swap/
cleanup, sheet de erro e mensagem inline de erro no Onboarding.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 11: Aceite manual completo + bench antes/depois + atualizar docs

Objetivo: rodar checklist manual end-to-end no build empacotado, registrar bench oficial de timing antes/depois, e atualizar a documentação obrigatória da fase.

**Files:**
- Create: `tagarela_docs/03-funcionalidades/checklists/fase2d-manual.md`
- Create: `tagarela_docs/02-arquitetura/07-modulos-fase2d.md`
- Modify: `tagarela_docs/README.md`
- (opcional, se aceite levantar achados: `tagarela_docs/04-decisoes/cleanup-fase2d.md`)

- [ ] **Step 1: Criar checklist manual**

Criar `tagarela_docs/03-funcionalidades/checklists/fase2d-manual.md`:

```markdown
---
data: 2026-05-01
fase: 2d-velocidade-transcribe
status: aberto
---

# Aceite manual — Fase 2d (velocidade da transcrição)

## Bloco 1 — Onboarding picker funcional

Pre: `defaults delete com.tagarela.Tagarela`, app freshly installed.

- [ ] Onboarding aparece e chega no Passo 3.
- [ ] Picker mostra 3 modelos: large-v3-turbo (selecionado, badge RECOM.), large-v3, medium.
- [ ] Download de large-v3-turbo inicia automaticamente; barra visível.
- [ ] Trocar pra `medium` mid-download: download anterior cancela, download de medium começa.
- [ ] Após "começar →", `defaults read ... com.tagarela.preferences.whisperModelName` retorna `medium`.

## Bloco 2 — Onboarding erro de download

- [ ] Limpar prefs. Iniciar onboarding. Desligar Wi-Fi. Erro aparece inline com mensagem + botão retry.
- [ ] Religar Wi-Fi, clicar retry → download retoma e conclui.

## Bloco 3 — Preferências > Transcrição

Pre: app rodando com large-v3-turbo ativo.

- [ ] Section "Transcrição" no sidebar (ícone mic.and.signal.meter).
- [ ] Mostra "Modelo ativo: large-v3-turbo".
- [ ] Picker exibe os 3 modelos sem frame quadrado.

## Bloco 4 — Swap fluxo feliz

- [ ] Clicar large-v3 → alerta de confirmação aparece com tamanho. Confirmar "Trocar".
- [ ] Barra de progresso visível. Hotkey funciona durante download (transcreve com turbo).
- [ ] Status vai pra "Trocando pra large-v3…" brevemente.
- [ ] Volta pra "Modelo ativo: large-v3".
- [ ] Alerta cleanup aparece: "Apagar large-v3-turbo? (libera ~815 MB)". Clicar "Apagar".
- [ ] Pasta `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-turbo` foi removida.
- [ ] Disparar hotkey, ditar 3s. Console.app log: `transcribe model=large-v3 audio=3.Xs wall=YYYYms`.

## Bloco 5 — Bench oficial

- [ ] Em modelo `large-v3`, ditar 5× ditados de ~3s. Anotar wall ms de cada. Calcular mediana.
- [ ] Trocar pra `large-v3-turbo` (pelo Preferências). Ditar 5× ditados de ~3s. Anotar wall ms. Calcular mediana.
- [ ] Confirmar redução ≥ 5× (esperado: large-v3 ~6000-10000ms; turbo ~800-1500ms numa máquina M1+).
- [ ] Registrar números no spec ou cleanup-fase2d.md.

## Bloco 6 — Swap erro + retry

- [ ] Desligar Wi-Fi. Trocar pra medium. Confirmar.
- [ ] Sheet modal de erro aparece após timeout do download. Mensagem inclui razão.
- [ ] Clicar "Tentar de novo" em offline: outra falha. OK.
- [ ] Religar Wi-Fi. "Tentar de novo" → sucesso.
- [ ] Cleanup prompt aparece após sucesso.

## Bloco 7 — Cancel mid-download

- [ ] Trocar pra `large-v3` (pesado). Mid-download, clicar "Cancelar".
- [ ] Status volta pra "Modelo ativo: large-v3-turbo".
- [ ] Pasta de large-v3 não foi criada (ou foi limpa pelo HubApi — verificar disco).
- [ ] Hotkey funciona normal com turbo.

## Bloco 8 — Migration de user existente

- [ ] Estado: `prefs.whisperModelName` ausente, large-v3 em disco.
  ```bash
  defaults delete com.tagarela.Tagarela com.tagarela.preferences.whisperModelName
  ```
- [ ] Restart app. Sem swap automático.
- [ ] Preferências > Transcrição mostra "Modelo ativo: large-v3" (preservou o disco).
- [ ] Disparar hotkey, ditar 3s — transcreve com large-v3 normalmente.

## Bloco 9 — Não-regressão

- [ ] Pílula sem frame retangular (regressão da fix de hoje).
- [ ] Toasts ainda aparecem ao mudar de tela; ToastView não foi afetado.
- [ ] Custom styles, refiner, history continuam funcionando sem mudanças.

---

Status final: `ok` / `ok-com-achados` / `bloqueado`.
```

- [ ] **Step 2: Rodar todos os blocos do checklist no build empacotado**

Ir bloco por bloco do checklist. Marcar `[x]` os passos validados. Anotar achados (se houver) num arquivo `tagarela_docs/04-decisoes/cleanup-fase2d.md`.

- [ ] **Step 3: Criar snapshot pós-2d**

Criar `tagarela_docs/02-arquitetura/07-modulos-fase2d.md`:

```markdown
---
data: 2026-05-01
fase: 2d-velocidade-transcribe
status: implementado
---

# Snapshot pós-Fase 2d

A Fase 2d troca o default Whisper de `large-v3` pra `large-v3-turbo` e adiciona escolha runtime via Preferências. Inclui knobs ANE/prewarm e instrumentação de timing.

## Módulos novos

- `Transcription/WhisperModelCatalog.swift` — metadata estática dos 3 modelos.
- `Transcription/WhisperModelStore.swift` + `WhisperModelStoreLive.swift` — leitura/exclusão de modelos no disco.
- `Transcription/WhisperModelSwapCoordinator.swift` — máquina de estado do swap em runtime.
- `Preferences/UI/Components/WhisperModelPicker.swift` — picker compartilhado.
- `Preferences/UI/Sections/TranscriptionView.swift` — section nova "Transcrição".
- `Preferences/UI/Sheets/SwapErrorSheet.swift` — sheet modal de erro com retry.

## Módulos modificados

- `WhisperKitTranscriber.swift` — `WhisperKitConfig` ganha `prewarmModels: true` e `computeOptions = ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine)`. `transcribe()` loga model/audio/wall ms via `Logger.tagarela`. Novo método `unloadModel()`.
- `Transcribing.swift` (protocol) — ganha `unloadModel()`.
- `PreferencesStore.swift` + `Preferences+Defaults.swift` — campo `whisperModelName: String` (default `"large-v3-turbo"`).
- `PrefsSection.swift` + `PreferencesRoot.swift` — case `.transcricao` + wiring.
- `OnboardModel.swift` + `OnboardingWindow.swift` + `OnboardingCoordinator.swift` — picker funcional, erro inline + retry.
- `AppContainer.swift` — usa `prefs.whisperModelName` em loadModel; instancia `WhisperModelSwapCoordinator`; migration de users existentes; bloqueio de hotkey durante `.swapping`.

## Bug latente fechado

Onboarding mostrava 3 radios decorativos que ignoravam seleção. Agora o radio do user é honrado.

## Bench

(preencher com números medidos no Bloco 5 do checklist manual)

| Modelo | Mediana wall ms (5×3s) |
|---|---|
| large-v3 | ?ms |
| large-v3-turbo | ?ms |

Redução: ?×.

## Testes

Suíte: 155 → ~175 testes verdes (+ 20).
```

- [ ] **Step 4: Atualizar `README.md` do vault**

Adicionar entry do snapshot:

Em `tagarela_docs/README.md` na seção `### 02 — Arquitetura`, após a linha do `06-modulos-fase2c-cleanup.md`:

```markdown
- [`07-modulos-fase2d.md`](./02-arquitetura/07-modulos-fase2d.md) — snapshot pós-Fase 2d (velocidade): `large-v3-turbo` default, picker funcional em Onboarding/Preferências, knobs ANE+prewarm, timing log, swap coordinator em runtime. Fecha bug latente dos radios decorativos do Onboarding.
```

E na seção `### 03 — Funcionalidades`:
```markdown
- [`checklists/fase2d-manual.md`](./03-funcionalidades/checklists/fase2d-manual.md) — aceite manual da Fase 2d (8 blocos: onboarding, swap fluxo feliz, erro/retry, cancel, migration, não-regressão).
```

E atualizar a entry do design pra `Status: implementado`:
Trocar `**Status: design.**` por `**Status: implementado** (branch fase-2d, ~12 commits, ~175 testes verdes).`

E adicionar entry do plan:
```markdown
- [`2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-plan.md`](./specs/2026-05-01-tagarela-v1-fase2d-velocidade-transcribe-plan.md) — plano executado da Fase 2d (~12 tarefas, +20 testes, suíte 175).
```

- [ ] **Step 5: Commit final dos docs**

```bash
cd /Users/tars/Dev/tagarela
git add tagarela_docs/
git commit -m "$(cat <<'EOF'
docs: snapshot pós-2d + checklist manual + atualizar índice

Documenta entrega da Fase 2d (velocidade). Bench antes/depois preenchido
no snapshot. Checklist manual com 8 blocos.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Tarefa 12: Merge da branch em `main`

Objetivo: integrar `fase-2d` em `main`. Não fazer push (não há remote configurado por política).

- [ ] **Step 1: Confirmar suíte verde + clean tree**

```bash
cd /Users/tars/Dev/tagarela
git status                   # nothing to commit
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | tail -5
```

- [ ] **Step 2: Trocar pra main e mergear**

```bash
cd /Users/tars/Dev/tagarela
git checkout main
git merge --no-ff fase-2d -m "$(cat <<'EOF'
Merge fase-2d into main: velocidade da transcrição

- Default Whisper: large-v3 → large-v3-turbo (5–8x mais rápido em PT)
- Picker funcional em Onboarding (resolve bug dos radios decorativos)
- Section "Transcrição" em Preferências com swap em runtime
- Knobs WhisperKitConfig: prewarmModels=true + computeOptions ANE-explícito
- Instrumentação de timing via Logger.tagarela (categoria Transcribe)
- Migration de users existentes preserva modelo já em disco

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Re-rodar suíte em main**

```bash
cd /Users/tars/Dev/tagarela
xcodebuild -project app/Tagarela.xcodeproj -scheme Tagarela -destination 'platform=macOS' test 2>&1 | grep -E "Executed|SUCCESS" | tail -3
```

Esperado: ~175 testes, `** TEST SUCCEEDED **`.

- [ ] **Step 4: Atualizar app empacotado em `~/Applications`**

```bash
pkill -x Tagarela 2>/dev/null
sleep 1
xcodebuild -scheme Tagarela -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
rm -rf /Users/tars/Applications/Tagarela.app
cp -R /Users/tars/Library/Developer/Xcode/DerivedData/Tagarela-*/Build/Products/Debug/Tagarela.app /Users/tars/Applications/Tagarela.app
open /Users/tars/Applications/Tagarela.app
```

Smoke test final: ditar 1× no modelo ativo, validar log + transcrição + injection.

---

## Self-review

**Spec coverage:**
- §1 Arquitetura geral → Tarefas 1, 2, 3, 4, 5, 6, 7, 8, 9 cobrem todos os componentes novos/modificados ✓
- §2 Data flow do swap → Tarefa 5 (coordinator) + Tarefa 8 (UI) ✓
- §3 Onboarding flow → Tarefa 7 ✓
- §4 Instrumentação → Tarefa 4 ✓
- §5 Knobs WhisperKitConfig → Tarefa 4 ✓
- §6 Error handling → Tarefas 5, 8 (sheet modal) ✓
- §7 Testing → cada tarefa tem TDD inline; aceite manual em Tarefa 11 ✓
- Migração → Tarefa 9 ✓
- Pico de memória durante swap → coberto pela sequência load→swap→unload em Tarefa 5 step 1 + AppContainer wiring T9 ✓

**Placeholder scan:** sem TBD/TODO/vague. Cada step tem código completo ou comando exato.

**Type consistency:**
- `Transcribing.unloadModel()` definido em T4 → usado em T5 (coordinator), T2/T4 fakes ✓
- `SwapState` enum + `SwapError` definidos em T5 → consumidos em T8 ✓
- `WhisperModelInfo.approxBytes`/`displaySize` em T1 → consumidos em T8 (alerta confirm) ✓
- `WhisperModelStore.delete(_ name: String) async throws` em T2 → consumido em T8 ✓
- `WhisperModelSwapCoordinator(initialActive:stagingFactory:swapActive:)` em T5 → instanciado em T8 stub e T9 real ✓

**Cobertura de aceite manual** (lição 2c-cleanup): tarefas que tocam AppKit/SwiftUI/IO têm step explícito de aceite manual antes do commit (T4, T6, T7, T8, T9). Tarefa 11 consolida o aceite end-to-end.
