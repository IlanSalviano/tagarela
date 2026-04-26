---
data: 2026-04-26
status: aprovado para implementação
versao: v1
---

# tagarela — design da v1

Spec consolidada da primeira versão do **tagarela**: aplicativo macOS nativo de ditado universal por voz com pós-processamento opcional por LLM. Resultado do brainstorming de 2026-04-26.

> Regras de processo: ver [`/CLAUDE.md`](../../CLAUDE.md). Nada é implementado sem ler a doc; nada é dado como pronto sem atualizar a doc.

---

## 1. Visão e escopo

### 1.1 O que é

Aplicativo macOS nativo de **ditado universal por voz** com pós-processamento opcional por LLM. O usuário aperta `right ⌥` em qualquer aplicativo, fala, aperta de novo, e o texto **refinado** (sem muletas, com pontuação, no estilo configurado) é colado onde o cursor estiver. Foco em português brasileiro com regionalização e vocabulário técnico configurável. Funciona 100% offline com WhisperKit + Ollama; opcionalmente com OpenAI; ou sem LLM (texto cru).

### 1.2 Persona alvo da v1

Usuário individual (especificamente o autor do projeto) num Mac com Apple Silicon, ≥ 16 GB RAM, macOS 14 Sonoma ou superior. Conforto com configurar Ollama. Quer ditar em português técnico com gírias e termos em inglês embutidos sem o app destruir nem uns nem outros.

### 1.3 Não-objetivos da v1

Registrados pra ficarem fora explicitamente:

- Comandos por voz embutidos ("novo parágrafo", "negrito", etc.)
- Detecção/troca automática de idioma (PT/EN/ES)
- Histórico rico em janela própria (apenas últimos N no menu da status bar)
- Snippets / atalhos de texto
- Multi-usuário, sincronização entre Macs
- App Store (escolha consciente — sandbox impede o que precisamos)
- Versão iOS

### 1.4 Decisões nucleares (do brainstorming)

| # | Decisão | Alternativas consideradas |
|---|---|---|
| D1 | Escopo da v1 = ditado + limpeza por LLM | Ditado puro / + comandos por voz |
| D2 | ASR = WhisperKit (Swift, CoreML/Neural Engine) | Speech framework Apple, whisper.cpp, faster-whisper, MLX Whisper, Whisper API |
| D3 | LLM = 3 backends (Ollama / OpenAI / Sem LLM) atrás de protocolo `TextRefiner` | Só Ollama, só OpenAI, sem LLM na v1 |
| D4 | Ativação = toggle com `right ⌥` (configurável); injeção via clipboard + ⌘V | Push-to-talk; toggle por toque curto; AX direto; keystroke simulation |
| D5 | UI = `MenuBarExtra` na status bar + `NSPanel` flutuante perto do cursor | Só status bar / janela rica de histórico / sem status bar |
| D6 | Regionalização = `language: pt` forçado + `initialPrompt` com vocabulário técnico + modelo `large-v3` default + system prompts do refiner com regras de code-switching | Cada alavanca isolada; multi-idioma automático |
| D7 | Histórico = SwiftData, texto cru + refinado, sem áudio, retenção 200/30 dias | Áudio incluído; só texto final; SQLite/GRDB; JSON; sem persistência |
| D8 | Stack = macOS 14+, SwiftUI + AppKit pontual, sem sandbox, Developer ID + notarized, distribuição via DMG | Catalyst, AppKit puro, sandbox, App Store |

Cada decisão vira ADR detalhado em `tagarela_docs/04-decisoes/` na implementação.

---

## 2. Arquitetura

### 2.1 Princípios

- **Boundaries explícitas via protocolos.** `PipelineCoordinator` só conhece interfaces (`Transcribing`, `TextRefiner`, `AudioCapturing`, `Injecting`, `HistoryStoring`). Implementações concretas são plugáveis e testáveis com fakes.
- **Tudo Swift.** Target macOS 14+. Sem CocoaPods, sem Carthage, sem Python embutido. Dependências externas só via SPM.
- **SwiftUI quando dá, AppKit cirúrgico onde precisa.** AppKit aparece em três lugares: `NSPanel` flutuante, `CGEventTap` de hotkey, captura de áudio com `AVAudioEngine`.
- **Offline-first.** Default da v1 funciona sem internet. OpenAI é opção; Ollama precisa estar rodando localmente.

### 2.2 Módulos

| Módulo | Responsabilidade | Tecnologia |
|---|---|---|
| `App` | Entry point, lifecycle, composição de dependências | SwiftUI `App` |
| `PermissionService` | Consulta/observa status de Microfone, Acessibilidade, Input Monitoring | `AVCaptureDevice`, `AXIsProcessTrustedWithOptions`, `IOHIDCheckAccess` |
| `HotkeyService` | Registra `right ⌥` global, emite eventos toggle on/off | `CGEventTap` (AppKit) |
| `AudioCapture` | Captura mic, gera buffer PCM 16 kHz mono, expõe níveis pra waveform | `AVAudioEngine` |
| `Transcriber` (impl. `WhisperKitTranscriber`) | Wrapper de WhisperKit. Carrega modelo, transcreve com `language: pt` + `initialPrompt` montado do vocabulário técnico | `WhisperKit` SPM |
| `TextRefiner` (protocolo) | Recebe `(rawText, style)`, devolve `refinedText` | — |
| `OllamaRefiner` | Implementação via `localhost:11434/api/chat` + health check `/api/tags` | `URLSession` |
| `OpenAIRefiner` | Implementação via `api.openai.com/v1/chat/completions` | `URLSession` |
| `IdentityRefiner` | Devolve o texto cru sem alteração; é também o fallback universal | — |
| `Injector` | Salva pasteboard atual → coloca texto → simula `⌘V` via `CGEvent` → restaura após delay | `NSPasteboard`, `CGEvent` |
| `HistoryStore` | Persiste `Transcription`, aplica retenção (N itens / N dias) | SwiftData |
| `PreferencesStore` | Lê/escreve preferências; expõe Combine publishers | `UserDefaults` + Keychain (só pra API key OpenAI) |
| `MenuBarController` | Ícone na status bar (estados `idle` / `recording` / `processing` / `error`), menu com últimos N itens | SwiftUI `MenuBarExtra` |
| `FloatingIndicator` | Janelinha não-ativadora perto do cursor: waveform animada, timer, botão cancelar | `NSPanel` (`.floating`, `.nonactivatingPanel`) embebendo SwiftUI |
| `PreferencesUI` | Tela de preferências (Geral / Atalho / Modelo / LLM / Estilos / Vocabulário / Histórico) | SwiftUI `Settings` scene |
| `OnboardingUI` | Primeira execução: 3 cards de permissão + escolha inicial de modelo Whisper + scan de Ollama | SwiftUI |
| `PipelineCoordinator` | Orquestra todo o fluxo. Mantém máquina de estados. É um `actor`. | Swift puro |

### 2.3 Diagrama de dependências (alto nível)

```
                      App (composition root)
                         │
            ┌────────────┼────────────────────────────┐
            ▼            ▼                            ▼
     PreferencesStore  MenuBarController         OnboardingUI
            │            │                            │
            │            │ observa estado          PermissionService
            │            ▼
            │      PipelineCoordinator (actor)
            │            │
            │   ┌────────┼─────────┬──────────┬──────────┬──────────┐
            ▼   ▼        ▼         ▼          ▼          ▼          ▼
   HotkeyService  AudioCapture  Transcriber  TextRefiner  Injector  HistoryStore
                                              │
                                ┌─────────────┼─────────────┐
                                ▼             ▼             ▼
                        OllamaRefiner  OpenAIRefiner  IdentityRefiner
                                │             │
                                ▼             ▼
                              URLSession    Keychain
                                                │
                                                ▼
                                       FloatingIndicator (UI lateral)
```

`FloatingIndicator` é controlado pelo `PipelineCoordinator` via callback de mudança de estado, não está no caminho de dados.

---

## 3. Fluxo principal

```
[1] Usuário aperta right ⌥
       │
       ▼
[2] HotkeyService → emite .toggle → PipelineCoordinator
       │  (estado: idle → recording)
       ▼
[3] PipelineCoordinator pede:
     • AudioCapture.start()                  → buffer cresce em background
     • FloatingIndicator.show(.recording)    → aparece perto do cursor
     • MenuBarController.setState(.recording)→ ícone vermelho
       │
       │  (usuário fala; níveis de áudio alimentam waveform via callback)
       ▼
[4] Usuário aperta right ⌥ de novo
       │
       ▼
[5] HotkeyService → emite .toggle → PipelineCoordinator
       │  (estado: recording → processing)
       ▼
[6] AudioCapture.stop() → entrega Data PCM 16kHz mono
       │
       ▼
[7] Pré-validação:
     • duração < 0,5s              → descarta silenciosamente, indicador some, fim
     • duração > 5min              → segue, mas mostra aviso "isso vai demorar"
       │
       ▼
[8] Transcriber.transcribe(buffer):
     • language = "pt"
     • initialPrompt = montado de PreferencesStore.technicalVocabulary
     • model = PreferencesStore.whisperModel
       │
       ▼
[9] Texto cru retorna
       │
       ▼
[10] Refiner ativo (Ollama | OpenAI | Identity) recebe (rawText, styleSystemPrompt)
       │
       │  Identity é instantâneo. Ollama e OpenAI são HTTP — timeout 30s.
       │  Em erro → fallback automático pro IdentityRefiner com aviso visual,
       │  o texto cru é entregue mesmo assim. Usuário nunca fica sem resultado.
       ▼
[11] Texto refinado retorna
       │
       ▼
[12] Injector:
     a. captura NSWorkspace.frontmostApplication?.bundleIdentifier (pra histórico)
     b. salva NSPasteboard.general.items atuais (todos os tipos)
     c. NSPasteboard.general.declareTypes([.string]) + setString(refinedText)
     d. CGEvent ⌘V down/up no display de evento HID
     e. após 250ms: restaura items originais
       │
       ▼
[13] HistoryStore.save(Transcription{...})
       │
       ▼
[14] FloatingIndicator.hide()
     MenuBarController.setState(.idle)
       │  (estado: processing → idle)
       ▼
     fim
```

**Máquina de estados.** `idle → recording → processing → idle`. Durante `processing`, novas chegadas de `.toggle` da hotkey são **ignoradas** (sem fila, sem encadeamento). Apenas `.cancel` é aceito.

**Cancelamento.** Botão "X" no `FloatingIndicator` emite `.cancel`. Em qualquer estado pós-captura, descarta resultado, não chama `Injector` nem `HistoryStore`. Em `recording`, descarta o buffer.

**Concorrência.** `PipelineCoordinator` é `actor`. `AudioCapture` roda em queue própria do `AVAudioEngine`. WhisperKit gerencia threading interno. HTTP do refiner usa `async/await`. UI é atualizada via `@MainActor` publishers.

---

## 4. Modelo de dados

### 4.1 SwiftData

```swift
@Model
final class Transcription {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var durationSeconds: Double
    var rawText: String
    var refinedText: String
    var refinerKind: String      // "ollama" | "openai" | "none"
    var llmModelName: String?    // ex: "qwen3.5:9b-nvfp4" ou "gpt-5.4-mini"; nil se none
    var whisperModelName: String // ex: "large-v3"
    var styleName: String        // nome do preset de estilo usado
    var frontmostAppBundleID: String? // app que tinha foco no momento da injeção
}
```

`HistoryStore` na inicialização e a cada `save()` aplica retenção: apaga onde `createdAt < now - historyMaxDays` **OU** mantém só os `historyMaxItems` mais recentes (o que vier primeiro corta).

### 4.2 Preferências (`UserDefaults`)

Chave-raiz: `com.tagarela.preferences`. Defaults da v1:

```
hotkey                 : Hotkey  (default: rightOption, mode: .toggle)
whisperModel           : enum    (default: largeV3 se RAM>=16GB, senão medium)
refinerKind            : enum    (default: .none na 1ª execução)
ollamaBaseURL          : String  (default: "http://localhost:11434")
ollamaModel            : String  (default: "qwen3.5:9b-nvfp4")
openAIBaseURL          : String  (default: "https://api.openai.com/v1")
openAIModel            : String  (default: "gpt-5.4-mini")
selectedStyleID        : UUID    (aponta pra um Style em customStyles)
customStyles           : [Style] (presets: Informal / Profissional / Notas técnicas / Cru)
technicalVocabulary    : String  (campo livre, separado por vírgula ou nova linha)
historyMaxItems        : Int     (default 200)
historyMaxDays         : Int     (default 30)
launchAtLogin          : Bool    (default false; usa SMAppService.mainApp)
showFloatingIndicator  : Bool    (default true)
logLevel               : enum    (default .info)
```

> **Nota sobre `ollamaModel` default.** `qwen3.5:9b-nvfp4` é o default conforme escolha do usuário. `nvfp4` é uma quantização NVIDIA FP4 (CUDA); Ollama no Apple Silicon roda em Metal e tipicamente serve quantizações GGUF (`q4_K_M`, `q5_K_M`, `q4_0`). Se o pull falhar nesse Mac, o usuário troca a string nas preferências. Onboarding pode sugerir um substituto Mac-friendly se detectar pull-fail.

### 4.3 Segredos (Keychain)

`Security.framework`, `kSecClass = GenericPassword`, `kSecAttrService = "com.tagarela"`:

```
account "openai-api-key" → token bruto
```

A API key **nunca** entra em `UserDefaults`, log, telemetria, ou histórico.

### 4.4 `Style`

```swift
struct Style: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String              // ex: "E-mail profissional"
    var systemPrompt: String      // texto editável pelo usuário
    var preserveOrality: Bool     // injeta cláusula extra sobre regionalismos
    var isBuiltIn: Bool           // presets travados; usuário cria cópia pra editar
}
```

Presets embutidos da v1: `Conversa informal`, `E-mail profissional`, `Notas técnicas`, `Cru — sem reescrita`.

Todo `systemPrompt` da v1 inclui, como bloco fixo no fim, instruções sobre code-switching:

> "Preserve termos técnicos em inglês conforme o uso comum em desenvolvimento de software brasileiro (ex: cloud, deploy, pool, pattern, mutex). Corrija fonetizações óbvias do Whisper (ex: 'loquei' → 'log it', 'diploiei' → 'deployei'). Se `preserveOrality` está ativo, mantenha contrações orais ('tô', 'pra', 'cê')."

---

## 5. Tratamento de erros e estados de degradação

Princípio: **o usuário nunca deve perder o que falou.** Se algo quebra depois da transcrição, pelo menos o texto cru chega ao destino ou ao histórico.

| Cenário | Comportamento |
|---|---|
| Microfone não autorizado | Onboarding cobre na 1ª execução. Em runtime: ícone âmbar, clique mostra "Microfone bloqueado — abrir Configurações". Hotkey vira no-op com beep curto. |
| Acessibilidade não autorizada | `CGEventTap` não consegue ser registrada. Status bar mostra erro com link pro painel. App ainda funciona via item "Iniciar gravação" no menu (fallback manual). |
| Input Monitoring não autorizado | Mesma coisa que Acessibilidade. |
| WhisperKit modelo não baixado | Onboarding força escolha + download na 1ª execução com progresso. Troca de modelo nas preferências baixa em background; até concluir, transcrições usam o modelo anterior. |
| WhisperKit falha ao transcrever | Indicador mostra "Erro ao transcrever" por 2s, log em arquivo, sem entrada no histórico. |
| Ollama offline | Health check (`GET /api/tags`, timeout 2s, cache 30s). Se offline → fallback pra Identity, toast "Ollama offline — usando texto cru". Próxima captura tenta de novo. |
| OpenAI sem rede / 5xx / timeout | Fallback pra Identity, toast "OpenAI indisponível — usando texto cru". |
| OpenAI 401 / API key inválida | Toast "API key inválida" + abre Preferências na aba LLM. Identity nessa captura. |
| Refiner: prompt + texto excedem context window | Trunca o texto cru (mantém início e fim, marcador no meio) e tenta. Se ainda falhar, fallback Identity. |
| Injetor: app de destino não aceita `⌘V` | Texto fica no clipboard (porque restore não roda se paste falhou). Toast "Não foi possível colar — texto está na área de transferência". Histórico salvo normalmente. |
| Captura interrompida (mudança de device, sleep) | `AudioCapture` emite erro, pipeline cancela, indicador some, sem entrada no histórico. |
| App em foco mudou entre captura e injeção | Sem detecção. Texto vai pro app que está em foco no momento da injeção (esperado, igual ao Wispr). |
| Disco cheio / SwiftData write falha | Erro logado, transcrição **não** é salva no histórico, mas o paste já aconteceu. Toast no indicador. |

**Logs.** Arquivo rolando em `~/Library/Logs/tagarela/tagarela.log`, último ~5 MB, sem dados sensíveis (sem texto transcrito, sem API key, sem áudio). Apenas eventos de pipeline, erros e timings. Nível configurável (default `.info`).

---

## 6. Permissões macOS

Necessárias pra app funcionar:

| Permissão | Por quê | Como conceder |
|---|---|---|
| Microfone | Captura de áudio | Popup nativo na 1ª gravação (`NSMicrophoneUsageDescription`) |
| Acessibilidade | `CGEventTap` global da hotkey + simulação de `⌘V` | Sem popup automático; onboarding abre `Configurações do Sistema` no painel via `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` |
| Input Monitoring | Capturar `right ⌥` globalmente sem foco | Mesmo mecanismo via `Privacy_ListenEvent` |

**Não** precisa de Acesso Total ao Disco, Automação, Compartilhamento de Tela, Câmera.

Fluxo de onboarding (1ª execução): tela única com 3 cards (um por permissão), cada um com botão "Abrir Configurações" + indicador verde quando concedida (atualiza via `PermissionService.observe()`). Botão "Continuar" só fica ativo quando as 3 estão verdes (ou usuário marca explicitamente "Continuar mesmo assim — sem hotkey global"). Depois disso, escolha do modelo Whisper + scan de Ollama (ping em `localhost:11434`) com sugestão de configuração.

---

## 7. Distribuição

- **Code signing.** Developer ID Application + Developer ID Installer (se DMG empacotar `.pkg`; provavelmente não — DMG simples com `.app`).
- **Notarization.** `xcrun notarytool submit ... --wait` no CI. Stapling com `xcrun stapler staple`.
- **DMG.** Gerado por `create-dmg` (Homebrew formula). Background com seta indicando arrastar pro `Applications`.
- **Canal primário.** GitHub Releases. Tag `vX.Y.Z`, asset `Tagarela-X.Y.Z.dmg`.
- **Auto-update.** Sparkle 2.x via SPM. Appcast em GitHub Pages. **Pode escorregar pra v1.1** se atrasar; releases manuais cobrem o início.
- **Canal secundário.** Homebrew Cask (`Casks/tagarela.rb` apontando pro DMG do Releases). Entra quando a v1 estiver estável.

---

## 8. Estratégia de testes

**Unitários (XCTest):**

- `IdentityRefiner`, `OllamaRefiner`, `OpenAIRefiner` com `URLProtocol` mock (sucesso, 401, 5xx, timeout, payload malformado, truncamento por context window)
- Montagem do `initialPrompt` a partir de `technicalVocabulary` (formatação, escape, limite de tokens)
- `HistoryStore`: insert, retenção por contagem, retenção por idade, limpeza ao cruzar dois limites
- `PreferencesStore`: persistência, defaults, migração de versão de schema
- `Hotkey` codable/equatable
- `Style`: defaults, customização, preservação de orality injetada no prompt
- Política de fallback do `PipelineCoordinator` (com fakes): refiner falhou → Identity; transcrição falhou → sem histórico; cancel → nada acontece

**Integração:**

- `PipelineCoordinator` end-to-end com `FakeAudioCapture`, `FakeTranscriber`, refiner real (`Identity`), `FakeInjector`, `HistoryStore` em SwiftData in-memory. Verifica ordem do pipeline, estados, métricas.

**Manual (checklist versionado em `tagarela_docs/03-funcionalidades/checklists/`):**

- Hotkey real captura `right ⌥` em foreground/background
- Injeção real funciona em: TextEdit, Notes, Slack, Mail, VS Code, Terminal, Safari (input/textarea/contenteditable), iMessage
- Indicador flutuante aparece sem roubar foco
- Permissões: fluxo de onboarding em Mac sem nenhuma permissão concedida
- Whisper `large-v3` baixa, transcreve PT-BR com vocabulário técnico (lista de frases-teste versionada)
- Ollama com modelo configurado: refina texto preservando regionalismos
- OpenAI com modelo configurado: refina texto, falha graciosamente em key inválida
- Histórico aplica retenção corretamente após N capturas
- App reinicia sem perder configurações nem histórico
- DMG instala, é notarized (Gatekeeper aprova sem aviso)

**Sem testes E2E automatizados.** Não vale a complexidade de UI tests do Xcode pra esse porte; checklist manual é mais sincero.

---

## 9. Telemetria

**Nenhuma.** Zero. Nada sai da máquina exceto chamadas explícitas pra OpenAI quando o usuário escolheu esse backend, e pull do Ollama quando o usuário troca de modelo.

Crash reports anônimos podem virar opt-in numa versão futura, fora da v1.

---

## 10. Roadmap pós-v1 (não-objetivos rastreados)

Anotados pra ficarem fora da v1 mas registrados:

- Comandos por voz embutidos
- Histórico em janela própria com busca FTS
- Snippets / atalhos de texto (frases salvas que viram triggers)
- Modo bilingue PT/EN com detecção de bloco
- Áudio salvo opcional (re-transcrição com modelo melhor depois)
- Tecla `fn` (Globe) como hotkey via virtual HID
- Auto-update via Sparkle (se a v1 sair sem)
- Modo "vault criptografado por senha" pro histórico
- Backend remoto opcional (Whisper API, Anthropic API, etc.) atrás da mesma interface `TextRefiner`
- Versão iOS

---

## 11. Próximos passos

1. Esta spec é revisada pelo usuário.
2. Após aprovação, `superpowers:writing-plans` produz o plano de implementação detalhado, salvo em `tagarela_docs/specs/2026-04-26-tagarela-v1-plan.md`.
3. Implementação segue o plano, com cada passo atualizando `tagarela_docs/` antes de ser declarado pronto (per `/CLAUDE.md`).
