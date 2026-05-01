---
data: 2026-05-01
fase: 2c-cleanup
status: parcialmente implementado
---

# Snapshot pós-Fase 2c-cleanup

Não é uma fase de feature. Bundle de cleanups que **tentou** tocar 4 itens; só 2 entregaram código líquido após reverts.

## Mudanças líquidas no código

- [`app/Tagarela/Hotkey/HotkeyServiceLive.swift`](../../app/Tagarela/Hotkey/HotkeyServiceLive.swift) (linha 99) — TODO `// TODO Fase 2: distinguir L/R do Option ...` removido após validação empírica via Bloco E do aceite manual. Substituído por nota explicativa "keyCode 0x3D (61) é exclusivo do Right Option no macOS — validado empiricamente em 2026-05-01."

## Mudanças líquidas em docs

- [`tagarela_docs/04-decisoes/cleanup-fase1.md`](../04-decisoes/cleanup-fase1.md) — itens #1 e #3 marcados como ✅ fechados; itens #8 e #9 atualizados com nota de "tentado e revertido" + hipóteses pra próxima tentativa.
- [`tagarela_docs/04-decisoes/cleanup-fase2b3.md`](../04-decisoes/cleanup-fase2b3.md) — item #1 atualizado com nota de revert (mesmo root cause de #8 da Fase 1).
- [`tagarela_docs/03-funcionalidades/checklists/fase2c-cleanup-manual.md`](../03-funcionalidades/checklists/fase2c-cleanup-manual.md) — checklist da sessão de aceite, status `ok-com-achados`.

## O que foi tentado e revertido

### Refactor `FloatingIndicatorPanel` em torno de `IndicatorViewModel`

Tasks 1, 2, 3 do plano. Implementou `IndicatorViewModel: ObservableObject` (`@Published` state/variant/toast + closures `onCancel`/`onToastDismiss`), `IndicatorRootView` que observa o vm, e refactor de `FloatingIndicatorPanel.ensurePanel()` instanciando `NSHostingController` 1× por vida do panel. Build verde, 160 testes verde, spec/code review aprovaram. **Aceite manual detectou regressão**: estado da pipeline parou de propagar pra UI (pílula não transitou pra `.refining`) **e** texto não foi injetado no app alvo. Commits `15b4630`, `1d90915`, `ba25fd9` revertidos em `48fb98e`, `1eea5c9`, `5743228`.

### WhisperKit `downloadBase` em Application Support

Task 5 do plano. Implementou `WhisperKit.download(variant:downloadBase:)` apontando pra `~/Library/Application Support/com.tagarela.Tagarela/Models/`. Build verde, 160 testes verde, spec/code review aprovaram. **Aceite manual (Bloco D) detectou regressão**: estrutura de diretório foi criada mas vazia, sem arquivos do modelo. Cold start subsequente: pílula não transitou e texto não foi injetado (mesma sintomatologia do refactor). Commit `37a9552` revertido em `d4ff1e7`.

## Cleanups fechados nesta sessão

- **Cleanup #1 da Fase 1** (L/R Option): validação empírica via Bloco E. Right Option dispara hotkey toggle; Left Option não. TODO removido.
- **Cleanup #3 da Fase 1** (stderr → Logger): retroativo. Já estava fechado no código (Fase 2b-1) — só faltava o registro nas docs.

## Cleanups que continuam abertos

- Cleanup #8 da Fase 1 (NSHostingController recriado): tentado e revertido. Hipóteses não testadas: (a) `NSHostingController` + `@ObservedObject` + `@MainActor`-isolated `ObservableObject` interagem mal em runtime; (b) panel sizing fica preso ao tamanho do primeiro estado; (c) main actor saturado por re-renders cascateados.
- Cleanup #1 da Fase 2b-3 (pill flicker): mesmo root cause do #8.
- Cleanup #9 da Fase 1 (Documents folder): tentado e revertido. Hipóteses não testadas: (a) `HubApi(downloadBase:...)` espera estrutura de path diferente; (b) pré-criação do diretório via `FileManager.createDirectory` interfere com a lógica de cache do HubApi; (c) algum flag/permission a mais é necessário pro download em Application Support.
- Cleanup #2 da Fase 1 (`promptTokens` empírico A/B): bloqueado por coleta manual.
- Cleanup #5 da Fase 1 (`AVAudioConverter` streaming): bloqueado por hardware.
- Cleanup #6 da Fase 1 (TCC manual): bloqueado até Fase 3.
- Cleanup #7 da Fase 1 (drift visual): inspeção manual demorada.

## Lição operacional

Spec compliance + code review estática **não substituiu** aceite runtime nesta sessão — duas mudanças passaram nos dois reviews mas quebraram em produção. Próximas tentativas de refactor de UI ou IO devem rodar aceite manual em build local **entre commit e merge**, não depois. Atualizar plano default da pipeline `brainstorm → plan → execute` pra incluir esse gate explícito quando código toca AppKit/SwiftUI/IO.

## Testes

- Suíte: 155 testes verdes (baseline da `main` pré-2c). Os 5 testes do `IndicatorViewModelTests` foram embora junto com o vm na revert.
