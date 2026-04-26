# Sistema visual — tagarela

Sistema visual autoral do tagarela, exportado do **Claude Design** em 2026-04-26.

> Bundle original (HTML/CSS/JSX): [`bundle/`](./bundle/) — não editar; é referência canônica.
> Documento canônico apresentado: [`bundle/project/tagarela design v1.html`](./bundle/project/tagarela%20design%20v1.html)
> Conversa de design: [`bundle/chats/chat1.md`](./bundle/chats/chat1.md)

---

## Posição do design no fluxo

O design exportado é um **protótipo HTML/CSS/JS** — não código de produção. A implementação Swift/SwiftUI deve **recriar a aparência fielmente** sem copiar a estrutura interna do protótipo. Tokens, tipografia, cores, copy e layouts são fonte da verdade. Estrutura de componentes vira detalhe da implementação SwiftUI.

---

## Identidade

**Posicionamento.** App utilitário com voz visual forte. Mono pra estrutura, serif italic pra alma. Carmim pra estado vivo (gravando). Paper warm como base. Dark mode é dark de verdade, não claro tingido. **Sem azul de sistema.**

**Wordmark.** "tagarela" em mono (JetBrains Mono 500), com o **primeiro `a` em serif italic carmim** (Instrument Serif), e um **ponto carmim** acima do segundo `a` — o ponto dobra como indicador de gravação. Spec do glyph: ver [`bundle/project/wordmark.jsx`](./bundle/project/wordmark.jsx).

**Glyph (status bar).** Bolha de fala simples com 3 pontos internos. Quando gravando: preenchimento carmim, pontos brancos. SVG 24×24. Ver `wordmark.jsx`.

**Nome do produto.** O design assume `tagarela` como nome final (não mais codinome). Confirmar com usuário se isso fica.

---

## Tokens

Fonte: [`bundle/project/tokens.css`](./bundle/project/tokens.css). Todas as cores e medidas abaixo são CSS custom properties — a implementação Swift deve mapear cada uma pra constantes nomeadas (`Color.paper`, `Color.carmine`, etc.) num arquivo `DesignTokens.swift` ou em um `Color Set` no asset catalog (preferível pra suporte automático a dark mode).

### Cor — modo claro

| Token | Hex | Uso |
|---|---|---|
| `--paper` | `#f4ede0` | base / janela |
| `--paper-2` | `#ebe2d1` | superfície elevada (cards, abas inativas) |
| `--paper-3` | `#ddd1ba` | divisor sutil |
| `--ink` | `#1a1612` | texto primário |
| `--ink-2` | `#3a3128` | texto secundário |
| `--ink-3` | `#6b5d4d` | texto terciário (hints, eyebrow) |
| `--ink-4` | `#9e8d77` | texto muted |
| `--carmine` | `#c8311c` | recording, ação primária, brand |
| `--carmine-deep` | `#8f1d0d` | hover/pressed |
| `--amber` | `#c97a14` | warning, processing |
| `--amber-soft` | `#e8b86b` | warning soft |
| `--moss` | `#5a6b3a` | success, ok |

### Cor — modo escuro

| Token | Hex |
|---|---|
| `--paper` | `#15110d` |
| `--paper-2` | `#1f1a14` |
| `--paper-3` | `#2c241c` |
| `--ink` | `#f0e9da` |
| `--ink-2` | `#c8bca6` |
| `--ink-3` | `#8e8170` |
| `--ink-4` | `#5a4f42` |
| `--carmine` | `#e85a3f` |
| `--carmine-deep` | `#c8311c` |
| `--amber` | `#e8a040` |
| `--moss` | `#8ba455` |

### Sombras / chrome

| Token | Valor |
|---|---|
| `--chrome` (light) | `rgba(244, 237, 224, 0.78)` (com backdrop-blur 20px) |
| `--hairline` | `rgba(26, 22, 18, 0.10)` |
| `--hairline-strong` | `rgba(26, 22, 18, 0.18)` |
| `--shadow-sm` | `0 1px 2px rgba(26, 22, 18, 0.08)` |
| `--shadow-md` | `0 4px 12px rgba(26, 22, 18, 0.10), 0 1px 3px rgba(26, 22, 18, 0.06)` |
| `--shadow-lg` | `0 16px 48px rgba(26, 22, 18, 0.18), 0 2px 8px rgba(26, 22, 18, 0.08)` |
| `--shadow-pop` | `0 24px 64px rgba(26, 22, 18, 0.28), 0 4px 12px rgba(26, 22, 18, 0.12)` (indicador flutuante e dropdowns) |

### Tipografia

| Família | Uso | Fonte da fonte |
|---|---|---|
| **Inter Tight** (400/500/600) | UI body, parágrafos, texto transcrito | Google Fonts (precisa empacotar no app ou usar fallback `SF Pro Text`) |
| **JetBrains Mono** (400/500/600) | Estrutura: labels, kbd, status, eyebrows, timer, vocab chips | Empacotar no bundle |
| **Instrument Serif** (italic) | Display: wordmark, headlines de onboarding, eyebrows do histórico | Empacotar no bundle |

Todas têm fallback de sistema se não empacotadas:
- mono → `"SF Mono", Menlo, monospace`
- display → `"Iowan Old Style", Georgia, serif`
- ui → `"SF Pro Text", -apple-system, system-ui, sans-serif`

**Decisão pendente:** empacotar as 3 fontes no bundle (~600KB cada) ou usar fallbacks de sistema? Recomendo empacotar — o caráter visual depende fortemente delas.

### Eyebrows / labels técnicos

Padrão repetido em telas: `font: mono 10px, letter-spacing: 0.14em, text-transform: uppercase, color: ink-3`. Define seções e categorias.

### Radii

`--r-1: 3px` (chips pequenos), `--r-2: 6px` (botões, inputs, abas), `--r-3: 10px` (cards, dropdowns), `--r-pill: 999px` (indicador pill, vocab chips).

### Animações

| Nome | Propósito | Detalhe |
|---|---|---|
| `tg-pulse` | Dot de gravação | 1.2s ease-in-out, opacity 1↔0.55 + scale 1↔0.85 |
| `tg-spin` | Spinner | 1 volta linear |
| `tg-blink` | Caret de input | 1s steps(2), opacity 50% off |
| `tg-sweep` | Gradient HUD style Siri | 3s linear, background-position 0%→200% |

---

## Componentes catalogados

| Componente | Arquivo | Estados |
|---|---|---|
| `Wordmark`, `Glyph` | `bundle/project/wordmark.jsx` | tamanhos 14/18/20/32/48/56/88; recording on/off |
| `IndicatorPill` (A) | `bundle/project/indicators.jsx` | recording, processing, refining, error |
| `IndicatorOrb` (B) | `bundle/project/indicators.jsx` | mesmos |
| `IndicatorVertical` (C) | `bundle/project/indicators.jsx` | mesmos |
| `IndicatorHUD` (D) | `bundle/project/indicators.jsx` | mesmos (dark only) |
| `WaveBars` | `bundle/project/indicators.jsx` | shared, 14/16/20 bars, animated via tick |
| `MenuBarExtra` | `bundle/project/menubar.jsx` | idle, recording, processing, refining, error |
| `StateRow` | `bundle/project/menubar.jsx` | mesmos |
| `HistRow` (compacto) | `bundle/project/menubar.jsx` | kind: ollama / openai / none |
| `OnboardWelcome` | `bundle/project/onboarding.jsx` | passo 1/3 |
| `OnboardPerms` | `bundle/project/onboarding.jsx` | states: needed / granted / denied (3 cards) |
| `OnboardModel` | `bundle/project/onboarding.jsx` | ollama: found / scanning / missing |
| `PrefShell` | `bundle/project/preferences.jsx` | 7 abas: geral / atalho / modelo / llm / estilos / vocab / histórico |
| `PrefGeneral`, `PrefHotkey`, `PrefModel`, `PrefLLM`, `PrefStyles`, `PrefVocab`, `PrefHistory` | mesmo arquivo | uma por aba |
| `Toast` | `bundle/project/errors.jsx` | tones: warn / error / info / success |
| `PermDeniedDropdown` | `bundle/project/errors.jsx` | variante do MenuBarExtra |

### Indicadores: variações disponíveis

O design entrega **4 explorações** do indicador flutuante. Pendência: escolher a default da v1.

- **A — pílula horizontal** (paper, ~210×42px). Dot pulsante + waveform horizontal + timer + cancel. Mais "Wispr-like". Encaixa bem em qualquer monitor.
- **B — bolha radial** (paper, 92×92px). Linhas radiais animadas em volta de centro com timer. Mais autoral, mais discreto.
- **C — barra vertical** (paper, 38×~140px). Coluna lateral com bars verticais e timer rotacionado. Boa pra encostar na borda da tela.
- **D — HUD Siri** (dark, ~250×56px com gradient sweep). Mais cinematográfico, agressivo, "look-at-me".

Recomendação minha: **A (pílula)** como default da v1. Razão: presença/discrição equilibradas, copy legível, não rouba atenção, escala bem em conteúdo (waveform horizontal é familiar). B/C/D ficam disponíveis na preferência "estilo do indicador" mostrada em `PrefGeneral`.

### Estados do pipeline (revisão)

A `StateRow` do MenuBarExtra usa **5 estados**, não 4 como no spec atual:

| Estado | Cor do dot | Label | Sublabel |
|---|---|---|---|
| `idle` | moss | "pronto" | "right ⌥ pra começar" |
| `recording` | carmine | "gravando" | "00:14 · 16 kHz mono" |
| `processing` | amber | "transcrevendo" | "whisper large-v3" |
| `refining` | amber | "refinando" | "ollama · qwen3.5:9b" |
| `error` | carmine-deep | "ollama offline" (etc.) | "fallback: texto cru" |

**Implicação:** o `PipelineCoordinator.State` precisa separar `processing` (transcrição) de `refining` (LLM) pra refletir feedback visual correto. Era 4 estados no spec; vira 5.

---

## Copy strings (pt-BR) — extraídas do design

Lista canônica das strings de UI em português. Devem virar `Localizable.strings` (chave inglesa, valor pt-BR) ou enum Swift com casos nomeados.

### Status / pipeline

- `idle.title`: **"pronto"**
- `idle.sub`: **"right ⌥ pra começar"**
- `recording.title`: **"gravando"**
- `recording.sub`: `"00:14 · 16 kHz mono"` (timer dinâmico)
- `processing.title`: **"transcrevendo"**
- `processing.sub`: `"whisper {modelo}"`
- `refining.title`: **"refinando"**
- `refining.sub`: `"{backend} · {modelo}"`
- `error.title`: variável (ex: `"ollama offline"`, `"api key inválida"`)
- `error.sub`: `"fallback: texto cru"` (quando aplicável)

### Indicador flutuante (label inferior do orb)

- recording → **"ouvindo"**
- processing → **"transcrevendo…"**
- refining → **"refinando…"**
- error → **"erro"**

### Onboarding

- Welcome: **"ditado por voz para qualquer coisa que você escreva."** (display italic)
- Welcome body: `"aperte right ⌥ em qualquer app, fale, aperte de novo. o texto refinado aparece onde estiver o cursor. funciona offline. fala português."`
- Botão: **"continuar →"** / **"começar →"** / **"← voltar"**
- Permissões headline: **"três permissões."**
- Permissões body: `"o macOS exige isso pra app capturar áudio e atalhos globais. nada vai pra fora da máquina."`
- Card 1 — microfone: `"captura sua voz pra transcrever. áudio nunca é salvo, só processado em memória."`
- Card 2 — acessibilidade: `"necessário pra registrar o atalho global e simular ⌘V no app de destino."`
- Card 3 — input monitoring: `"pra ouvir a tecla right ⌥ mesmo quando outro app está em foco."`
- Botão por card: **"abrir configurações"**
- Status: **"necessária"** / **"concedida"** / **"negada"**
- Modelos headline: **"modelos."**
- Eyebrows: `"whisper · transcrição"`, `"ollama · refino opcional"`
- Ollama states: `"ollama detectado em localhost:11434"`, `"procurando ollama…"`, `"ollama não encontrado"`
- Botão skip permissões: **"continuar sem hotkey global"**

### Toasts (erros / fallbacks)

| Tone | Title | Body | Hint |
|---|---|---|---|
| warn | `"ollama offline"` | `"usando texto cru do whisper. próxima captura tenta de novo."` | `"GET /api/tags · timeout 2s"` |
| error | `"api key inválida"` | `"o openai recusou a key configurada. abrindo preferências…"` | `"HTTP 401 · invalid_api_key"` |
| warn | `"texto longo"` | `"excedeu a janela do modelo. truncado pra refinar — trecho meio omitido."` | `"{N} tokens > {M} context"` |
| info | `"não foi possível colar"` | `"o app de destino não aceitou ⌘V. texto está na área de transferência — cole manual."` | `"frontmost: {bundleID}"` |
| success | `"modelo baixado"` | `"whisper {modelo} pronto pra uso. próxima transcrição usa ele."` | `"{tamanho} · stored in ~/Library/Application Support/"` |

### Preferências — labels (todas as abas)

Lista exaustiva extraída de `preferences.jsx` (preservar exatamente como está):

**Geral:** `"abrir no login"`, `"indicador flutuante"`, `"estilo do indicador"`, `"tema"` (sistema/claro/escuro), `"nível de log"` (`.info`), bloco `"privacidade"` com texto fixo.

**Atalho:** `"atalho global"` (com kbd `right ⌥`), `"modo"` (toggle / push-to-talk), `"bipe ao iniciar/parar"`, `"cancelar com Esc"`.

**Modelo:** lista de 4 modelos (`large-v3` / `medium` / `small` / `base`), `"idioma"`, `"prompt inicial"`, `"duração mínima"`, `"duração máxima"`.

**LLM:** 3 cards (ollama / openai / sem llm), bloco `"config ollama"` (endpoint, modelo, status, "testar conexão"), bloco `"config openai"` (api key, modelo, endpoint), `"timeout"`.

**Estilos:** lista lateral de presets (`"conversa informal"`, `"e-mail profissional"`, `"notas técnicas"`, `"cru — sem reescrita"`, `"bullet points"`, `"+ novo estilo"`), painel direito com `"nome"`, `"prompt do sistema"`, `"preservar oralidade"`. Hint: `"as regras de code-switching são anexadas automaticamente."`

**Vocabulário:** chip-list editor de palavras, contador `"{N} palavras · ~{M} tokens · cabe no prompt"`, link `"importar de arquivo"`. Hint: `"palavras que o whisper costuma errar. injetadas no initialPrompt da transcrição."`

**Histórico:** `"manter no máximo"` (200 itens), `"por até"` (30 dias), barra resumo `"{N} transcrições · mais antiga há {X} dias · 0 áudios salvos"`, `"limpar tudo"`, lista com colunas `time / app / kind / cru / refinado`.

---

## Layouts e medidas-chave

| Tela | Tamanho |
|---|---|
| MenuBarExtra dropdown | 320px de largura |
| PermDeniedDropdown | 300px |
| Indicador pill | inline (~210×42px conteúdo) |
| Indicador orb | 92×92px |
| Indicador vertical | 38px wide × dinâmico |
| Indicador HUD | inline (~270×56px conteúdo) |
| Onboarding window | 560×400 (welcome) / 560×520 (perms) / 560×560 (model) |
| Preferências window | 620×500 (maioria) / 620×580 (LLM) / 720×500 (estilos) / 760×580 (histórico) |
| Toast | 320px wide |

Padrão de title bar do macOS: 36-44px de altura, 3 traffic lights à esquerda (12×12, gap 7).

---

## Mapeamento pra implementação Swift

Sugestões iniciais (não-vinculantes — viram decisões no plano):

| Conceito do design | Equivalente Swift/SwiftUI |
|---|---|
| `tokens.css` custom properties | `Assets.xcassets` Color Sets (suporte nativo dark mode) + `DesignSystem.swift` com semantic constants |
| Fontes empacotadas | Pasta `Fonts/` no bundle + `UIFontDescriptor`/`Font.custom` |
| `MenuBarExtra` | `MenuBarExtra` SwiftUI nativo (macOS 13+) |
| `Wordmark` JSX | View SwiftUI com `HStack` mixando `Text` + custom font |
| `Glyph` SVG | Custom SwiftUI `Shape` ou conversão pra SF Symbol custom (`.symbolset`) |
| Indicador (`NSPanel` flutuante) | `NSPanel` `.nonactivatingPanel` + `NSHostingView` com SwiftUI dentro |
| `WaveBars` animado | SwiftUI `Canvas` com `TimelineView(.animation)` |
| `Toast` stack | overlay window ou view in panel; `.transition(.move)` + auto-dismiss |
| `tg-pulse`, `tg-spin`, `tg-sweep` | SwiftUI `.symbolEffect`, `withAnimation(.easeInOut.repeatForever)`, ou `TimelineView` |
| Preferências window 7 abas | SwiftUI `Settings` scene com `TabView` + `.tabItem` |
| Onboarding window | `WindowGroup` separada, conteúdo SwiftUI |

---

## Itens em aberto (precisam decisão antes do plano de Fase 1)

1. **Indicador default da v1.** A/B/C/D? (Recomendo A — pílula.)
2. **Nome final do produto.** Manter `tagarela` (que o design assume) ou ainda quer mudar?
3. **Empacotar fontes vs. usar fallbacks de sistema.** (Recomendo empacotar.)
4. **Aba "Histórico" rica nas Preferências.** O design inclui — mas o spec atual classificou histórico em janela própria como **não-objetivo da v1**. A aba não é janela própria, mas é uma view rica com cru+refinado lado a lado. Mantém na v1 ou empurra pra v2 (deixando só o menu da status bar com últimos 5)?
5. **Vocabulário como chip-list editor com importação de arquivo.** O spec atual previa "campo livre, separado por vírgula ou nova linha". Adotar o chip-list (UX melhor, mas mais código)?
6. **Botão "testar conexão" do Ollama.** OK adicionar à aba LLM da v1?
7. **Estado adicional `refining` no pipeline.** O design separa `processing` (transcrevendo) de `refining` (LLM). Adotar (vira 5 estados em vez de 4)?
8. **Toggles novos em Atalho.** `"bipe ao iniciar/parar"` e `"cancelar com Esc"` — entram na v1?
9. **Toggle de modo "push-to-talk".** O design oferece em Preferências, mas você havia escolhido só toggle. Manter só toggle ou adicionar push-to-talk como opção?
10. **Preset extra "bullet points".** O design adiciona um 5º preset de estilo. Mantém ou v2?
