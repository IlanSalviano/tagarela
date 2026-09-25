---
data: 2026-09-25
status: em implementação (branch `feat-buscar-atualizacoes`)
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

Build local `1.0.6-dev` com build number **6** — igual ao da v1.0.5 publicada.

- [ ] O item aparece logo abaixo de "Preferências…".
- [ ] O clique fecha o menu e abre a janela do Sparkle **na frente**.
- [ ] Com o build igual ao publicado, o Sparkle diz que está atualizado.
- [ ] Depois de publicada a v1.0.6, o mesmo item a oferece — e a atualização instala com as permissões intactas.
