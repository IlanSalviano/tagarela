---
data: 2026-05-02
fase: 3-release
status: ativo
---

# Cleanup pós-Fase 3

## Item 1 — TCC zumbi por coexistência de builds (✅ remediado em 2026-05-02)

### Sintomas

Reportado pelo user em 2026-05-02:
- A cada launch da `/Applications/Tagarela.app` o macOS pede acesso a **Microfone** e à pasta **Documents**, mesmo já tendo concedido.
- Ditado captura áudio e transcreve, mas o **paste não cola** no campo focado — texto vai pra clipboard com toast "Cola falhou — texto na área de transferência".

### Causa-raiz confirmada

O LaunchServices conhecia **8 cópias** de `com.tagarela.Tagarela` em paths diferentes (build artifacts em `build/release/*`, `app/build/`, `~/Library/Developer/Xcode/DerivedData/`, DMG montado em `/Volumes/Tagarela 1.0.0/`, `/Applications/`). Algumas com cert Apple Development (Team `BCM26K6YNA`), outras com Developer ID (Team `22CZXFP6W7`) — Designated Requirements incompatíveis para o **mesmo bundle id**.

`tccutil reset Microphone com.tagarela.Tagarela` retornou **"Successfully reset" 4 vezes** por serviço, comprovando que o TCC tinha 4 registros distintos sob o mesmo bundle id. Cada launch escolhia uma identidade diferente e o TCC tratava como app nova.

Em cima disso, o **Sparkle auto-update** v1.0.0 → v1.0.1 substituiu o binário em `/Applications/`, e a permissão de Accessibility (mais frágil que mic) não foi herdada — `AXIsProcessTrusted()` em [`InjectorLive.swift`](../../app/Tagarela/Injection/InjectorLive.swift) passou a retornar false, derrubando a cola.

### Remediação aplicada

1. `pkill -f Tagarela.app`
2. `rm -rf ~/Library/Developer/Xcode/DerivedData/Tagarela-fomhjihjbmrpwcaikdahfugtlqrq`
3. `tccutil reset {Microphone,Accessibility,SystemPolicyDocumentsFolder,AppleEvents,ListenEvent,PostEvent,All} com.tagarela.Tagarela`
4. `lsregister -r -domain local -domain system -domain user` (a flag `-kill` foi removida em macOS recente; a rescan basta)
5. `lsregister -u <path>` em cada cópia rival no disco (não apaga, só desregistra)
6. Abrir `/Applications/Tagarela.app` (v1.0.1, Developer ID)
7. Conceder Accessibility e Input Monitoring manualmente em System Settings; aceitar popups nativos de Microfone e Documents na primeira gravação/uso.

### Lição operacional

**Nunca abrir builds locais (`build/release/*`, `app/build/`, DerivedData) enquanto a release oficial estiver em `/Applications/`.** Cada cópia rival com identidade de assinatura ligeiramente diferente cria um registro TCC fantasma, e na próxima vez que o macOS resolver a app por bundle id o TCC desmorona. Ver instrução adicionada em [`02-arquitetura/00-setup-dev.md`](../02-arquitetura/00-setup-dev.md).

### Follow-up de código (opcional, não aplicado ainda)

- **Banner persistente quando `AXIsProcessTrusted() == false`** no init do `AppContainer`, com botão deep-link pro painel de Accessibility. Hoje o user só descobre que perdeu Accessibility quando a primeira cola falha.
- **Detectar duplicatas no startup** via `LSCopyApplicationURLsForBundleIdentifier` e avisar se houver mais de uma cópia do `com.tagarela.Tagarela` no disco.

Revisitar em 2026-05-16 se reincidir.

## Reincidência em 2026-09-24 — só o microfone

### Sintoma

A v1.0.6 chegou pelo item "Buscar atualizações…" (Sparkle) e, no primeiro launch,
o macOS pediu o **Microfone** de novo, embora a identidade de assinatura seja a do
build que ela substituiu (o `1.0.6-dev` de aceite, Developer ID — DR idêntico). Monitoramento de Entrada e Acessibilidade vieram concedidos
sem pedido, e a cola funcionou.

### Evidência (log do TCC, 22:30–23:40)

`/usr/bin/log show --predicate 'subsystem == "com.apple.TCC"'`. Cada janela exibida
aparece como `AUTHREQ_PROMPTING`; o resultado, como `AUTHREQ_RESULT` (`authValue`
2 = permitido, 1 = desconhecido, 0 = negado; `authReason` 2 = consentimento do
usuário). O `pid` do pedido e o `binary_path` dizem qual cópia pediu.

- **10 launches pediram o microfone com janela**: 6 de builds locais no DerivedData
  (host de testes e build de aceite) e 4 da `/Applications`.
- **Toda** janela da `/Applications` veio logo depois de um launch no DerivedData.
  Quatro launches seguidos da `/Applications` (22:43–22:45) não pediram nada.
- 23:09:13 — o host de testes do `xcodebuild test` (pid 78310; no log dele, os
  próprios testes rodando) pede o microfone, e a janela é aprovada.
- 23:20:19 — a v1.0.6 recém-atualizada consulta (preflight) e recebe
  `authValue=1`: a concessão já não era dela. Pede, janela, aprovada às 23:20:21.
- No mesmo launch da 1.0.6, `ListenEvent`, `Accessibility` e `PostEvent` voltaram
  `authValue=2` direto, sem janela.

### Mecanismo

O log mostra que a concessão de microfone do bundle id vale para a assinatura de
**quem aprovou a última janela**. O host de testes é o app inteiro, assinado com a
Apple Development desta máquina. Como o onboarding já foi feito (os `UserDefaults`
são os mesmos da release, pelo bundle id), o `AppContainer` roda
`ensureMicPermission()` no launch, pede o microfone e, aprovado, fica com a
concessão. O próximo launch da release pede de volta.

Monitoramento de Entrada e Acessibilidade não caem porque, nesses dois, o host de
testes não ganha janela: o pedido é negado na hora (`authReason=5`) e o registro da
release fica intacto.

Conclusão: **quem derruba o microfone é o `xcodebuild test`, não a atualização.**
Sem build local no meio — a situação de qualquer usuário —, a identidade igual
basta, como já basta hoje para as outras duas permissões. A prova direta para o
microfone fica para a próxima atualização sem suíte rodada no meio.

### O que mais o host de testes faz no launch (mesmo log, pid 78310)

- Carrega o modelo Whisper de verdade (`large-v3_turbo`, 5,9 s) a cada execução
  da suíte.
- Pede Acessibilidade e tenta ligar o atalho (negado).
- Os testes do `InjectorLive` com `axTrusted: { true }` enviam um **Cmd+V real**
  (`CGEvent` na sessão) ao app da frente — às 23:09:22 era o app do Claude. Não
  colou nada porque o TCC nega `PostEvent` ao host de testes (negação registrada
  15 ms antes). Se o build de Debug um dia ganhar essa permissão, a suíte colaria a
  área de transferência do usuário no app da frente. O pasteboard dos testes é
  privado (nome aleatório); a área de transferência real não é tocada.

### Follow-up de código — aplicado em 2026-09-25

Aplicado pelo [host de testes inerte](../specs/2026-09-24-tagarela-v1-host-de-testes-inerte-design.md),
que achou uma segunda fonte de janela: o teste do exportador de diagnóstico
abria o `inputNode`, e o coreaudiod pedia o microfone em nome do host — a
segunda janela de cada suíte (às 23:09:14, por exemplo). Verificado no log do
TCC durante a suíte: nenhuma janela, nenhum pedido real de microfone, nenhum ⌘V
real. A lista abaixo é a proposta original:

1. Sob XCTest, o `AppContainer` pula os efeitos de launch (`ensureMicPermission`,
   `requestAccessibilityIfMissing`, atalho, carga do modelo). Ataca a causa: o host
   de testes para de tomar a concessão do microfone, de abrir janelas durante a
   suíte e de carregar o modelo à toa.
2. Injetar no `InjectorLive` o envio do Cmd+V, para os testes nunca postarem
   evento real.
3. `ensureMicPermission()` pede a **câmera** antes do microfone ("tentativa 0",
   hipótese antiga de webcam C920). O TCC nega na hora (`authReason=5`), sem janela.
   Candidato a remoção.

### Como conferir de novo

```bash
/usr/bin/log show --predicate 'subsystem == "com.apple.TCC"' --last 1h --style compact | grep AUTHREQ_PROMPTING | grep -i tagarela
```

Cada linha é uma janela exibida; o `binary_path` diz se foi a `/Applications` ou
uma cópia local.
