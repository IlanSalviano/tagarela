# Fase 1 — checklist manual de aceite

Executar em Mac com Apple Silicon, 16+ GB RAM, macOS 14+, primeira execução do app. Resetar estado do app antes de começar:

```bash
defaults delete com.tagarela.Tagarela 2>/dev/null
rm -rf ~/Library/Containers/com.tagarela.Tagarela 2>/dev/null
```

Build + run via terminal:

```bash
cd /Users/tars/Dev/tagarela/app
xcodegen generate          # se project.yml mudou
xcodebuild -project Tagarela.xcodeproj -scheme Tagarela build
APP=$(xcodebuild -project Tagarela.xcodeproj -scheme Tagarela -showBuildSettings | awk -F' = ' '/ BUILT_PRODUCTS_DIR =/ {print $2}' | head -1)/Tagarela.app
open "$APP"
```

Ou abrir `Tagarela.xcodeproj` no Xcode e dar `⌘R`.

## Onboarding

- [ ] App abre com janela "boas-vindas" centralizada (560×400, paper warm)
- [ ] Botão "continuar →" leva pra "três permissões" (560×520)
- [ ] 3 cards mostram status real do sistema (cinza/verde/vermelho)
- [ ] Botão "abrir configurações" em cada card abre o painel certo do macOS
- [ ] Conceder mic via popup nativo → card vira verde
- [ ] Conceder Acessibilidade → card vira verde
- [ ] Conceder Input Monitoring → card vira verde
- [ ] "continuar →" leva pra "modelos" (560×560)
- [ ] Modelo `large-v3` aparece selecionado e marcado como recomendado
- [ ] Barra de progresso anda durante download
- [ ] "começar →" só fica ativo após modelo carregado
- [ ] Onboarding fecha; app some do Dock; ícone aparece na status bar

## Status bar

- [ ] Click no Glyph abre dropdown 320px com Wordmark + estado "pronto"
- [ ] "pronto" e sub "right ⌥ pra começar" aparecem
- [ ] Botão "sair" funciona

## Pipeline (com Acessibilidade + Input Monitoring concedidos)

- [ ] Apertar `⌥` direito em qualquer app: indicador pílula aparece perto do cursor
- [ ] Indicador mostra dot pulsante carmim, waveform reage à voz, timer correndo
- [ ] Falar "olá mundo isso é um teste" por ~3 segundos
- [ ] Apertar `⌥` direito de novo: indicador vira "transcrevendo" (amber), depois "refinando", depois some
- [ ] Texto cru do whisper aparece colado no app em foco (TextEdit, Notes, etc.)
- [ ] Clipboard original é restaurado após ~250ms
- [ ] Status bar reflete estados em tempo real
- [ ] Esc durante gravação cancela e indicador some sem injetar
- [ ] Botão X no indicador também cancela
- [ ] Apertar `⌥` direito durante "transcrevendo" não dispara nova captura

## Apps testados pra injeção

- [ ] TextEdit
- [ ] Notes
- [ ] Slack
- [ ] Mail
- [ ] VS Code
- [ ] Terminal
- [ ] Safari (textarea/input/contenteditable)
- [ ] iMessage

## Edge cases

- [ ] Captura < 0.5s: descartada silenciosamente, indicador some
- [ ] Captura > 5min: ainda funciona (sem warning visual nesta fase, ok)
- [ ] Negar Acessibilidade: hotkey não funciona; status bar mostra estado de erro (futuro — ok ignorar nesta fase, basta não crashar)
- [ ] Reabrir app após fechar: vai direto pra status bar (sem onboarding de novo)

## Performance

- [ ] Latência típica ditado→texto colado: < 3s pra 5s de fala em `large-v3`
- [ ] Sem spike de CPU > 30% em idle
- [ ] Sem leak visível de memória após 20 capturas (≤ 500MB residentes)

## Conclusão

Quando todos os checks acima passarem: Fase 1 está aceita. Atualizar [`02-arquitetura/01-modulos-fase1.md`](../../02-arquitetura/01-modulos-fase1.md) com qualquer desvio observado. Trocar a tag `v1-fase1-pronto` por `v1-fase1-aceita`.
