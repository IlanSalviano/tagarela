---
data: 2026-09-25
status: implementado (branch `fix-permissoes`) — aceite manual pendente
origem: relato de campo do usuário após instalar a v1.0.4
---

# Permissões depois do onboarding — design e plano

## Contexto

Relato de campo, 2026-09-25, logo após instalar a v1.0.4 com as permissões
zeradas (a assinatura mudou do build local para o Developer ID):

> "O processo de pedir as permissões ainda não está legal… não pede todas. A de
> 'Device Control and Data Access' não é explicitamente pedida e a de input
> monitoring também não, só a de microfone. O usuário tem que adivinhar qual
> precisa. Fora que ele mostra um erro e pede para abrir preferências no app, só
> que lá dentro não tem nada."

O log confirma: a hotkey subiu porque o usuário concedeu Monitoramento de Entrada
à mão; o primeiro ditado **não colou** (`AXIsProcessTrusted == false`) — ficou no
clipboard e no histórico, como a Fase 5 garante — e só dois minutos depois,
achada a permissão por tentativa, a cola funcionou.

"Device Control and Data Access" é como o usuário viu a Acessibilidade nos
Ajustes do macOS 27. O rótulo não foi encontrado nos recursos do sistema; o
design não depende dele — cada botão leva ao painel exato.

**Três buracos no código:**

1. **Acessibilidade nunca é pedida.** O app só *consulta* `AXIsProcessTrusted()`;
   nunca chama `AXIsProcessTrustedWithOptions` com o prompt, que é o que faz o
   macOS mostrar o diálogo e **inserir o app na lista** dos Ajustes. Depois de um
   `tccutil reset`, o Tagarela nem aparece lá — o usuário precisaria do "+".
2. **Depois do onboarding não existe lugar nenhum no app para ver ou resolver
   permissões.** O onboarding tem os três cartões, mas só roda na primeira
   execução.
3. **Os avisos apontam para esse lugar inexistente.** Os toasts dizem "abra
   Configurações"; o aviso do menu criado na Tarefa 6 da Fase 5 diz "abra
   Preferências" e não é clicável.

O design original da v1 (§4 e §6) já previa isso: *"status bar mostra erro com
link pro painel"* e um menu com *"variante de 'permissões faltando'"*. Nunca foi
implementado.

## Decisão

1. **`PermissionService` ganha os pedidos que faltavam:**
   `requestAccessibility()` (`AXIsProcessTrustedWithOptions` com
   `kAXTrustedCheckOptionPrompt`), `requestInputMonitoring()`
   (`IOHIDRequestAccess`) e `openMicrophoneSettings()`.
2. **No launch** (onboarding concluído), se a Acessibilidade não estiver
   concedida, o app a pede — uma vez por launch. Microfone já é pedido no
   launch; Monitoramento de Entrada, quando a hotkey sobe. Com isso as **três**
   são pedidas explicitamente.
3. **Nova seção Preferências › Permissões:** as três permissões com estado ao
   vivo (via `makeSnapshots()`, que desde a Tarefa 6 é multicast), para que
   serve cada uma em linguagem de usuário, e **um botão** cuja ação depende do
   estado — decidida por uma função pura (`PermissionAction`), testada:
   - concedida → nenhum botão;
   - microfone nunca decidido → pedir (diálogo do sistema);
   - microfone negado → abrir o painel de Microfone nos Ajustes (o macOS não
     pergunta de novo depois de um "não");
   - Monitoramento de Entrada / Acessibilidade faltando → pedir **e** abrir o
     painel correspondente.
4. **O aviso do menu vira botão** — "permissões pendentes — resolver…" — que abre
   as Preferências **direto** na seção Permissões (seleção compartilhada via um
   `PreferencesNavigator`).
5. **Toasts de permissão** passam a apontar para "Preferências › Permissões".

**Fora deste escopo:** o onboarding não muda; toasts continuam sem clique.

## Consequências

- O pedido de Acessibilidade no launch aparece **a cada launch** enquanto ela
  não for concedida. É o comportamento desejado — sem ela a cola não funciona —,
  mas é insistente de propósito.
- `PreferencesNavigator` é um `ObservableObject` na janela de Preferências. A
  regressão da 2c-cleanup com `ObservableObject` foi no painel do indicador, com
  atualizações a 12–25 Hz; aqui as mudanças são raras (um clique). Risco baixo,
  coberto pelo aceite manual.

## Plano

1. `PermissionAction` (puro) + testes.
2. `PermissionService`: `requestAccessibility`, `requestInputMonitoring`,
   `openMicrophoneSettings`.
3. `PrefsSection.permissoes` + `PermissionsView` + `PreferencesNavigator`;
   `openPreferences(section:)`.
4. Menu: aviso vira botão para Permissões.
5. Launch: pedido de Acessibilidade se faltar.
6. Toasts apontando para Preferências › Permissões; chaves de localização.
7. Suíte verde; build local assinado com o Developer ID (mesma identidade da
   v1.0.4, as permissões se mantêm) para aceite manual; depois v1.0.5.

## Aceite manual

Com o app fechado, zerar as três permissões
(`tccutil reset Microphone|ListenEvent|Accessibility com.tagarela.Tagarela`) e
abrir o app:

- [ ] Os três pedidos aparecem: microfone, Monitoramento de Entrada e Acessibilidade.
- [ ] Depois de conceder a Acessibilidade pelo diálogo, o Tagarela **já está na lista** dos Ajustes (sem "+").
- [ ] O menu mostra "permissões pendentes — resolver…" enquanto faltar alguma; o clique abre Preferências **na seção Permissões**.
- [ ] A seção mostra o estado certo de cada uma e muda ao vivo ao conceder.
- [ ] O botão de cada permissão faltante leva ao painel exato dos Ajustes.
- [ ] Com as três concedidas, o aviso some do menu e um ditado cola normalmente.

## Implementação (2026-09-25)

Os seis passos do plano entraram como desenhados. Notas:

- **`PermissionAction`** é o único pedaço com lógica própria — +4 testes. O resto
  é chamada de API do sistema e SwiftUI, coberto pelo aceite manual.
- O pedido de Acessibilidade usa a literal `"AXTrustedCheckOptionPrompt"` no lugar
  da global C `kAXTrustedCheckOptionPrompt`, que o modo estrito de concorrência do
  Swift trata como estado mutável compartilhado.
- A seção fica logo abaixo de **Geral**: é para onde o usuário vai quando algo
  quebra, então precisa estar à vista.
- Pedidos de Acessibilidade e de Monitoramento de Entrada agora deixam linha
  `.notice` no log de diagnóstico.

Suíte 253 → **257**, verde.
