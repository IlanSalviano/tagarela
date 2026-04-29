---
data: 2026-04-29
status: aberto
fase: 2b-2
ambiente: macOS 26 (Release em ~/Applications/Tagarela.app); Ollama rodando local com gemma4:e4b
---

# Checklist manual — Fase 2b-2

Aceite manual após implementação completa. Resetar defaults antes:

```bash
defaults delete com.tagarela.Tagarela 2>/dev/null
rm -rf ~/Library/Application\ Support/com.tagarela.Tagarela
```

## 0. Pré-requisitos
- [ ] Suíte XCTest verde (`xcodebuild test`) — 145+ testes.
- [ ] Build sem warnings novos.
- [ ] Ollama rodando, `gemma4:e4b` pulled.

## 1. Histórico viewer (Preferências > Histórico)
- [ ] Após pelo menos 3 capturas, abrir Preferências > Histórico.
- [ ] Section "Retenção" continua exibida em cima (maxItems/maxDays).
- [ ] Section "Registros" abaixo lista os cards (cru truncado + refinado destacado, app de destino, refiner kind, modelo).
- [ ] Buscar por substring de uma transcrição filtra a lista.
- [ ] Limpar busca volta a lista cheia.
- [ ] Botão "Limpar tudo" disabled quando lista vazia, habilitado caso contrário.
- [ ] Clicar "Limpar tudo" → NSAlert pede confirmação. Confirmar → lista zera.
- [ ] Botão "Re-injetar" num card injeta o refinado no app de foco atual; status "Re-injetado" some em ~1.5s.
- [ ] Botão "Copiar" copia o refinado pra clipboard; cmd+V em outro app cola.

## 2. Submenu "Últimos" na status bar
- [ ] Abrir popover do MenuBarExtra → submenu "Últimos" entre Style e Preferências.
- [ ] Lista até 5 entradas mais recentes, ordem decrescente. Formato: `<App> · <preview ~50 chars>`.
- [ ] Click numa entrada injeta o refinado no app de foco atual.
- [ ] Sem capturas: "nenhum item ainda" (sem reagir a click).

## 3. Toasts — fallback do refiner (cleanup #2 da 2a fechado)
- [ ] Configurar Backend = Ollama, mas matar o Ollama antes da captura (`pkill ollama` ou stop o service).
- [ ] Capturar uma frase. Resultado: texto cru injetado + toast amarelo "Sem rede — usando texto cru" (ou similar) acima do indicator pill.
- [ ] Toast some em ~4s. Click no toast dismissa antecipado.
- [ ] Re-iniciar Ollama, capturar de novo: refiner volta a funcionar, sem toast.

## 4. Toasts — outros tipos
- [ ] Inject falhar (revogar Acessibilidade em System Settings durante runtime, capturar): toast vermelho `lock.shield` "Acessibilidade negada — abra Configurações…".
- [ ] Mic negado (revogar Microfone, tentar capturar): toast `lock.shield` "Microfone negado".
- [ ] Sucesso silencioso: capturar normalmente — sem toast.

## 5. Indicator picker (Preferências > Geral)
- [ ] Abrir Preferências > Geral. Section "Estilo do indicador" aparece com 4 cards.
- [ ] Card ativo (default = Pílula) tem check verde + borda accent.
- [ ] Tap em outro card seleciona-o (check muda).
- [ ] Botão "Visualizar selecionado por 3s" → indicator real aparece centrado por 3s e some.
- [ ] HUD card tem background dark.

## 6. Variações do indicator em runtime
- [ ] Selecionar Pílula em Preferências, capturar. Pílula aparece como antes.
- [ ] Selecionar Orb, capturar. Orb radial aparece perto do cursor.
- [ ] Selecionar Vertical, capturar. Barra vertical aparece.
- [ ] Selecionar HUD, capturar. HUD style Siri aparece (escuro).
- [ ] Cada um dos 4 estados (.recording/.processing/.refining/.error) renderiza corretamente em cada variação.

## 7. Toast persiste com indicator hidden
- [ ] Após uma captura com fallback Identity (ver bloco 3), o toast continua visível por ~4s mesmo após o indicator sumir.
- [ ] Click no toast dismissa antes do auto-dismiss.

## 8. Resultado
- [ ] Todos os itens acima ✅. Marcar `status: ok` no frontmatter.
- [ ] Achados adicionais documentados em `tagarela_docs/04-decisoes/cleanup-fase2b2.md` (criar se houver).
