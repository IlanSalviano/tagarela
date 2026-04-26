---
status: aceita
data: 2026-04-26
---

# ADR-0001 — Sistema visual e variação default do indicador

## Contexto

A v1 do tagarela precisa de uma identidade visual concreta antes do plano de implementação. O design foi explorado em sessão paralela no Claude Design e exportado como bundle HTML/CSS/JSX em 2026-04-26 (ver [`tagarela_docs/05-design/`](../05-design/)).

O bundle entrega: tokens de cor (light/dark), três famílias tipográficas, copy pt-BR catalogada, **4 variações do indicador flutuante**, 5 estados do menu da status bar, 3 telas de onboarding, 7 abas de Preferências, toasts e variantes de erro. Algumas decisões expandem o escopo do spec original (ex: aba "Histórico" rica, vocabulário como chip-list, estado adicional `refining`); outras precisam apenas de escolha entre alternativas (qual indicador é o default).

## Decisão

### Identidade

- **Nome final do produto:** `tagarela` (deixa de ser apenas codinome).
- **Paleta:** paper warm (`#f4ede0`) como base, carmim (`#c8311c`) como cor de marca/recording, amber (`#c97a14`) pra warning/processing, moss (`#5a6b3a`) pra success. Sem azul de sistema.
- **Tipografia:**
  - **JetBrains Mono** (400/500/600) — estrutura: labels, kbd, status, eyebrows, timer
  - **Instrument Serif** (italic) — display: wordmark, headlines de onboarding
  - **Inter Tight** (400/500/600) — UI body, parágrafos, texto transcrito
  - As 3 são **empacotadas no bundle do app** (~1.5MB total). Caráter visual depende delas.
- **Wordmark:** "tagarela" em mono com primeiro `a` em serif italic carmim e dot carmim acima do segundo `a` (dobra como indicador de gravação). Spec em [`05-design/bundle/project/wordmark.jsx`](../05-design/bundle/wordmark.jsx).

### Indicador flutuante — variação default

**Adotada: A — pílula horizontal** (paper, ~210×42px). Dot pulsante carmim + waveform horizontal + timer mono + botão cancel.

Razão: presença equilibrada entre visibilidade (modo toggle precisa de feedback claro pra evitar gravação esquecida) e discrição (não rouba atenção do app em foco). Layout horizontal escala bem em qualquer monitor. Linguagem familiar (lembra Wispr e similares).

B (orb radial), C (barra vertical) e D (HUD style Siri) ficam disponíveis como opção em `Preferências → Geral → Estilo do indicador`. Implementadas todas na v1 — um protocolo `IndicatorView` com 4 implementações, cada uma um `View` SwiftUI dentro do mesmo `NSPanel`.

### Estados do pipeline (5 em vez de 4)

Adotado: `idle / recording / processing / refining / error`. Splita o antigo `processing` em transcrição e refino LLM, dando feedback visual correto na status bar e no indicador. Implica `PipelineCoordinator.State` com 5 cases.

### Mudanças de escopo aceitas (entram na v1)

- **Vocabulário como chip-list editor.** Persistido como `[String]` em vez de `String`. UX dramaticamente melhor; trabalho de UI moderado em SwiftUI.
- **Toggles novos em Preferências → Atalho:** "bipe ao iniciar/parar" (default off) e "cancelar com Esc" (default on).

### Mudanças de escopo recusadas (ficam pra v2)

- Aba "Histórico" rica nas Preferências (cru + refinado lado a lado, busca, limpar tudo).
- Botão "testar conexão" do Ollama na aba LLM.
- 5º preset de estilo "bullet points".
- Modo push-to-talk como opção configurável (v1 é só toggle).

## Consequências

### Positivas

- Toda decisão visual da v1 está concreta e versionada — plano de implementação consegue referenciar tokens, copy, layouts exatos sem inventar.
- Indicador único default (A) reduz superfície de teste manual sem fechar a porta pras outras 3 variações.
- Estados separados `processing` e `refining` evitam mentira na UI quando a transcrição já terminou mas o LLM ainda tá refinando.

### Negativas / custo

- Empacotar 3 fontes adiciona ~1.5MB ao bundle. Aceitável.
- Implementar 4 variações de indicador na v1 (em vez de só A) é trabalho extra. Mitigado: o protocolo `IndicatorView` abstrai a diferença; cada variação é um SwiftUI View autocontido na faixa de 80-150 linhas.
- Mudança de `technicalVocabulary: String` pra `[String]` exige migração se houver usuário pré-existente. Como ainda não há release, custo é zero na v1.
- Estado `refining` adicional impacta `PipelineCoordinator`, `MenuBarController`, `FloatingIndicator`. Mudança contida — só adiciona um case ao enum + handlers correspondentes.

## Alternativas consideradas

- **Indicador default = D (HUD Siri).** Mais cinematográfico; rejeitado por ser muito "agressivo" pra app utilitário e por exigir dark mode forçado mesmo no tema claro.
- **Indicador default = B (orb).** Mais discreto, mais autoral. Rejeitado por ter copy menos legível (timer e label dentro de 92×92) e ser menos imediatamente legível como "tô gravando".
- **Implementar só A na v1, B/C/D em versões futuras.** Rejeitado: as 4 já existem desenhadas, e o custo de portar cada uma pra SwiftUI é baixo (~150 LoC cada). Permitir que o usuário troque é um diferencial barato.
- **Não empacotar fontes.** Rejeitado: o caráter visual desmancha com fallbacks de sistema (especialmente o wordmark, que depende do contraste mono+serif italic).
- **Aba Histórico rica na v1.** Rejeitado pelo usuário no fechamento das pendências; mantém v1 enxuta.

## Referências

- Bundle do design: [`tagarela_docs/05-design/bundle/`](../05-design/bundle/)
- Sistema visual documentado: [`tagarela_docs/05-design/README.md`](../05-design/README.md)
- Spec da v1: [`tagarela_docs/specs/2026-04-26-tagarela-v1-design.md`](../specs/2026-04-26-tagarela-v1-design.md)
