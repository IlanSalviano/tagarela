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
