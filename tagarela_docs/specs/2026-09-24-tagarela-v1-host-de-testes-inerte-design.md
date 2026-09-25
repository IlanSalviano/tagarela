---
data: 2026-09-24
status: em implementação (branch `fix-host-de-testes-inerte`)
origem: aceite da v1.0.6 — o microfone foi pedido de novo depois da atualização
resolve: follow-up da *Reincidência em 2026-09-24* no cleanup-fase3; parte do achado de câmera da auditoria §5.2/§5.3
---

# Host de testes inerte

## Contexto

`xcodebuild test` lança o próprio `Tagarela.app` de Debug como host da suíte —
mesmo bundle id da release, outra assinatura (Apple Development). O log do TCC
de 2026-09-24 ([`cleanup-fase3.md`](../04-decisoes/cleanup-fase3.md),
*Reincidência em 2026-09-24*) mostrou o que cada execução da suíte faz na
máquina do usuário:

1. **O launch inteiro roda.** Com o onboarding já feito (os `UserDefaults` são
   os da release), o `AppContainer` pede microfone (e câmera), pede
   Acessibilidade, tenta subir a hotkey (pedido de Monitoramento de Entrada) e
   carrega o modelo Whisper de verdade (5,9 s).
2. **O teste do exportador de diagnóstico abre o microfone.** O retrato do
   estado lê `AVAudioEngine().inputNode` para mostrar o formato de entrada; às
   23:09:14 o coreaudiod checou o microfone em nome do host de testes, e saiu
   uma segunda janela.
3. **Os testes do injetor mandam um ⌘V real** ao app da frente
   (`CGEvent.post`). Não colou nada só porque o TCC nega `PostEvent` ao host de
   testes.

Aprovada a janela do microfone, a concessão passa para a assinatura do host de
testes, e a release pede de volta no launch seguinte — foi o que aconteceu às
23:20 com a v1.0.6.

## Decisão

1. **`RuntimeEnvironment.isRunningTests`** — a checagem que o `Diag` já usa
   (variável `XCTestConfigurationFilePath` ou classe `XCTestCase` carregada),
   movida para um lugar comum. Já está provada nos dois sentidos, no momento do
   launch: a release escreve o log em arquivo, e o host de testes das 23:09 não
   escreveu nenhuma linha.
2. **`AppContainer` sob testes não roda os efeitos de launch** —
   `ensureMicPermission`, `startHotkeyServiceLogging`,
   `requestAccessibilityIfMissing`, `loadModelLogging` — **nem o observador de
   permissões**, que sobe a hotkey sozinho quando o Monitoramento de Entrada
   está concedido. O `TagarelaApp` também não abre o onboarding sob testes. O
   resto da fiação fica: a suíte não constrói `AppContainer`, e nada do que fica
   mostra janela ou mexe em registro do TCC.
3. **`DiagnosticsExporter`: a sondagem do áudio de entrada vira parâmetro**
   (`audioInput:`), com a sondagem real como padrão. O teste passa uma falsa. Na
   release, nada muda.
4. **`InjectorLive`: o envio do ⌘V vira parâmetro** (`postPaste:`), com o
   `CGEvent` real como padrão. Os testes passam um registrador — e ganham a
   verificação que não tinham: com Acessibilidade, o ⌘V sai exatamente uma vez;
   sem ela, não sai.
5. **Sai o pedido de câmera** do `ensureMicPermission` ("tentativa 0",
   hipótese antiga da webcam C920) e o `NSCameraUsageDescription` do
   `Info.plist`, como propõe a auditoria (§5.3): sem o entitlement de câmera, o
   hardened runtime já negava o pedido em silêncio (`authReason=5` no log). O
   resto daquele achado — com o microfone negado, o launch promove o app a
   `.regular` e roda uma `AVCaptureSession` — continua em aberto.

**Fora do escopo:**
- O Sparkle no host de testes: nenhuma linha dele no log do host das 23:09, e
  nenhum efeito observado.
- Unificar os Team IDs de Debug e Release (auditoria §5.5). Com a mesma
  assinatura, o host de testes deixaria de disputar a concessão, mas a mudança
  é maior e vale para todos os builds de Debug, não só para o host.

## Verificação — automática, pelos logs

- Suíte verde, com os testes novos.
- TDD no injetor: os testes novos rodam **vermelhos** com o parâmetro já
  existindo mas sem uso, e verdes depois de ligado.
- Durante cada execução da suíte, no log do TCC: **nenhum**
  `AUTHREQ_PROMPTING` cujo binário seja o do DerivedData, **nenhum** pedido de
  microfone não-preflight do host de testes, e nenhum pedido do coreaudiod em
  nome dele.
- No log unificado do host de testes: a linha `test host: launch effects
  skipped`, e nenhuma de `loaded model`, `pedido de Acessibilidade`, `hotkey
  service` ou `pasted to`.

Sem aceite manual: um pedido do host de testes é condição para ele tomar a
concessão, e a ausência de pedidos se lê no log com mais certeza do que uma
checagem na mão. A consequência visível — a release não pede mais o microfone
depois da suíte — o usuário vê no próximo launch.

## Plano

1. Este documento — commit.
2. `RuntimeEnvironment` + `Diag` passa a usá-lo + teste de que a checagem é
   verdadeira dentro da suíte (se um Xcode futuro mudar as convenções, o teste
   avisa antes de o host de testes voltar a agir).
3. Guardas no `AppContainer` (efeitos de launch e observador) e no
   `TagarelaApp` (onboarding); remoção do pedido de câmera e da usage string.
4. `DiagnosticsExporter` com `audioInput:`; o teste passa a sondagem falsa.
5. `InjectorLive` com `postPaste:` ainda sem uso + testes novos → **execução
   vermelha**, conferindo o log do TCC durante ela.
6. Ligar o `postPaste` → **execução verde**, conferindo o log do TCC e o log
   unificado do host.
7. Doc: `cleanup-fase3` (follow-up aplicado), `00-setup-dev` (a release não
   deve mais pedir o microfone depois da suíte), regra de coexistência do plano
   da Fase 5, auditoria (achado de câmera), `11-modulos-fase5` (snapshot),
   índice.
8. Merge na `main` (`--no-ff`), suíte na main mesclada, `lsregister -u` no app
   do DerivedData, push.
