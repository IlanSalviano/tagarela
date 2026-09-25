---
data: 2026-09-25
status: implementado, aceito e publicado na v1.0.6 (2026-09-25)
origem: pedido do usuário após publicar a v1.0.5
revisa: decisão nº 3 do design da Fase 3 (Sparkle minimal)
---

# Item "Buscar atualizações…" no menu

## Contexto

A Fase 3 decidiu um Sparkle **minimal**: checagem automática no launch e a cada
24 h (`SUScheduledCheckInterval`), sem nenhuma UI manual — decisão nº 3 do
[design da Fase 3](./2026-05-01-tagarela-v1-fase3-release-design.md), com escopo
explícito de *"nesta fase"*.

Ao publicar a v1.0.5 — a primeira atualização assinada com a chave nova do
Sparkle — ficou evidente o custo: não havia como o usuário pedir a checagem.
Para receber a versão na hora, a saída era apagar `SULastCheckTime` na mão e
reabrir o app. O usuário pediu o item.

## Decisão

1. **Item "Buscar atualizações…" no menu da barra**, logo abaixo de
   "Preferências…". Chama `SPUUpdater.checkForUpdates()`; o Sparkle desenha o
   resto (achou versão nova, ou "você está atualizado").
2. **Desabilitado enquanto uma checagem já está em andamento**, observando
   `SPUUpdater.canCheckForUpdates` (KVO) — padrão recomendado pela documentação
   do Sparkle, para não empilhar checagens.
3. Antes de chamar o Sparkle, o popover do menu é fechado e o app é ativado —
   o mesmo cuidado que as Preferências já tomam — senão a janela do Sparkle pode
   abrir atrás de tudo, num app de barra de menu.

A checagem automática não muda.

## Aceite manual

**Resultado (2026-09-25):** o usuário clicou no item e o Sparkle respondeu *"Tagarela 1.0.6-dev é a versão mais recente disponível."* — build 6 contra os 6 publicados, a resposta certa. O nome mostrado é o `CFBundleShortVersionString` do build de aceite; a comparação do Sparkle é pelo `CFBundleVersion` (ADR-0007). O último item depende da publicação da v1.0.6.

Build local `1.0.6-dev` com build number **6** — igual ao da v1.0.5 publicada.

- [x] O item aparece logo abaixo de "Preferências…".
- [x] O clique fecha o menu e abre a janela do Sparkle **na frente**.
- [x] Com o build igual ao publicado, o Sparkle diz que está atualizado.
- [ ] Depois de publicada a v1.0.6, o mesmo item a oferece — e a atualização instala com as permissões intactas.

## Implementação (2026-09-25)

- `CheckForUpdatesModel` (`@MainActor`) observa `canCheckForUpdates` via
  `publisher(for:)` e repassa o pedido ao `SPUUpdater`. Sem teste unitário: é um
  repasse fino para o Sparkle, que não tem como ser simulado sem o próprio
  Sparkle; coberto pelo aceite manual.
- `PreferencesWindow.dismissMenuBarExtraPopover()` virou `internal` para ser
  reaproveitado pelo item.
- Suíte continua em **257**, verde. (Uma primeira execução falhou no
  `CopySwiftLibs` apontando para o toolchain do Metal montado pelo sistema em
  `/var/run/com.apple.security.cryptexd/…`: o asset foi remontado durante o
  build. Transitório — a segunda passou sem mudança nenhuma.)

## Publicação — v1.0.6 (2026-09-25)

https://github.com/IlanSalviano/tagarela/releases/tag/v1.0.6 — `release.sh`
de primeira, as sete etapas. Verificado como nas anteriores: release pública,
DMG com HTTP 200, `appcast` do raw da main em `sparkle:version` 7, assinatura
EdDSA **válida** com a `SUPublicEDKey` do app instalado sobre o DMG baixado do
GitHub, e por dentro 1.0.6 (build 7), Developer ID, DR idêntico ao do app
instalado, Gatekeeper `accepted · Notarized Developer ID`, staple válido.

Falta o último item do aceite: o usuário receber a v1.0.6 pelo próprio item.
