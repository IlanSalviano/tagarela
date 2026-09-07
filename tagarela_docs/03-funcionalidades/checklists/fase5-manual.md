---
data: 2026-09-07
status: em execução
fase: 5-robustez-sessao-longa
---

# Aceite manual — Fase 5 (robustez em sessão longa)

> **Regra de coexistência (leia antes de rodar).** A release v1.0.3 em
> `/Applications` tem o **mesmo bundle id** do build de dev. Rodar os dois juntos
> registra uma cópia rival no LaunchServices/TCC e derruba as permissões da
> release ([`cleanup-fase3.md`](../../04-decisoes/cleanup-fase3.md)).

## Roteiro de cada sessão de aceite

```bash
# 1. Fechar a release ANTES de abrir o build de dev (Cmd+Q no ícone da bandeja)
osascript -e 'quit app "Tagarela"'

# 2. Abrir o build de dev
open ~/Library/Developer/Xcode/DerivedData/Tagarela-fase5/Build/Products/Debug/Tagarela.app

# 3. ... rodar os blocos abaixo ...

# 4. Ao terminar: fechar o dev, desregistrar, reabrir a release
osascript -e 'quit app "Tagarela"'
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u ~/Library/Developer/Xcode/DerivedData/Tagarela-fase5/Build/Products/Debug/Tagarela.app
open /Applications/Tagarela.app
```

Depois de reabrir a release, confirmar que o ditado ainda funciona. Se o macOS
voltar a pedir Microfone/Acessibilidade, aplicar a remediação do `cleanup-fase3`
(`tccutil reset All com.tagarela.Tagarela` + `lsregister -u` no build de dev).

Na primeira execução o build de dev vai pedir Microfone, Acessibilidade e Input
Monitoring — é esperado. Ele é assinado com a identidade *Apple Development*
desta máquina (team `22CZXFP6W7`, o mesmo da release), então o designated
requirement é por certificado e **os grants sobrevivem a rebuilds**: só é
preciso conceder uma vez.

Log para acompanhar tudo: `tail -f ~/Library/Logs/Tagarela/tagarela.log`.

---

## Bloco A — captura de áudio (Tarefa 3)

Objetivo: a gravação nunca termina "sem áudio" em silêncio, o engine não
envelhece, e os níveis funcionam em **toda** gravação.

- [x] **A1 — três ditados seguidos.** As ondas do indicador precisam animar nos
      **três**, não só no primeiro. Este é o bug de regressão: até a Fase 5 os
      indicadores ficavam em `audioLevel = 0` da segunda gravação em diante.
      ✅ **2026-09-07 — confirmado pelo usuário.** É a prova em runtime de que a
      correção do stream por gravação funciona no `AudioCaptureLive` real, e não
      só contra o fake do teste.
- [ ] ⏳ **A2 — desconectar/reconectar a C920 entre ditados.** Ditar, desconectar,
      reconectar, ditar de novo. Tem que voltar a transcrever sem relaunch.
- [ ] ⏳ **A3 — trocar o device de entrada default e voltar** (Ajustes › Som, ou
      conectar o iPhone via Continuity). Ditar depois de cada troca.
- [ ] ⏳ **A4 — microfone ocupado por outro app.** Abrir algo que segure o mic e
      tentar ditar: em vez de "não fez nada", esperar erro visível.
- [ ] ⏳ **A5 — ditado de 60 s.** Sem truncar, sem estourar memória.
- [ ] **A6 — conferir o log.** `tail -30 ~/Library/Logs/Tagarela/tagarela.log`
      deve mostrar, por ditado, a sequência
      `start in=…Hz/…ch device='…'` → `stop raw=… buffers=… → 16k=… peak …→… wall=…s`
      → `buffer duration=…` → `transcribed chars=N` → `injected to <bundle>`.
      **Nenhuma linha pode conter o texto ditado.**
      Se algum ditado tiver disparado o watchdog, aparece
      `nenhum buffer após 1s; recriando o engine` e o `stop` traz `[engine recriado]`.
      ✅ **2026-09-07 — confirmado pelo usuário.**

**Resultado: `ok-parcial` (2026-09-07).** A1 e A6 confirmados pelo usuário — os
dois itens que fecham o bug de regressão dos níveis e a persistência/privacidade
do log. **A2, A3, A4 e A5 não foram exercitados nesta sessão** e seguem abertos:
são justamente os cenários de troca de device (gatilho da hipótese H1), mic
tomado por outro app e ditado longo. Reprogramados para o aceite completo da
Tarefa 12 — até lá, o self-healing da captura está verificado só no caminho
feliz.

---

## Bloco B — modelo e decoder (Tarefa 5)

- [ ] **B1 — launch sem rede.** Desligar Wi-Fi/Ethernet, fechar e reabrir o
      build de dev, ditar. Tem que transcrever normalmente. No log:
      `modelo '…' já em disco — carregando sem rede`. Antes desta fase o modelo
      nem carregava sem internet e todo ditado virava "erro no pipeline".
- [ ] **B2 — dois vazios seguidos disparam a recuperação.** Com o microfone
      mudo no sistema (ou tampado), ditar duas vezes. Esperado: toast
      "Não entendi nada — tente de novo." nas duas, depois
      "Reconhecedor reiniciado.". No log, `transcribed vazio` com `peak=` e as
      métricas (`logprob`, `cr`, `nsp`), depois `recarregando model=… do disco`
      e `reloaded model=…`.
- [ ] **B3 — o ditado seguinte funciona.** Reabilitar o microfone e ditar: tem
      que voltar ao normal, sem relaunch.
- [ ] **B4 — vazio não polui.** Confirmar que os ditados vazios de B2 **não**
      colaram nada no app-alvo e **não** aparecem em Preferências › Histórico.

**Resultado:** _(a preencher)_

## Bloco C — hotkey (Tarefa 7)
_(a preencher quando a Tarefa 7 fechar)_

## Bloco D — cola (Tarefa 8)
_(a preencher quando a Tarefa 8 fechar)_

## Bloco E — UI (Tarefa 9)
_(a preencher quando a Tarefa 9 fechar)_

## Bloco F — diagnóstico (Tarefas 1 e 2)

- [ ] **F1** — o menu da bandeja mostra a linha de saúde depois do primeiro
      ditado (`N ditados · 0 vazios · 0 curtos · …`).
- [ ] **F2** — o sub-label de `.processing` mostra o **modelo carregado** (não
      "whisper large-v3" fixo) e o de `.idle` diz "⌥ direito pra começar".
- [ ] **F3** — Preferências › Sobre › **Exportar diagnóstico…** cria a pasta no
      Desktop com `tagarela.log`, `snapshot.txt` e `vmmap.txt`, e revela no Finder.
- [ ] **F4** — abrir `snapshot.txt` e confirmar: **nenhuma** API key, **nenhum**
      texto ditado; contadores, formato do input, device default, permissões e
      event taps do processo presentes.
- [ ] **F5** — Preferências › Sobre › **Abrir log do app** abre
      `~/Library/Logs/Tagarela/tagarela.log`.

**Resultado: `ok-em-bloco` (2026-09-07).** O usuário confirmou o bloco de
diagnóstico funcionando junto com o A6, mas **sem registro item a item** — as
caixas F1–F5 seguem abertas de propósito, para serem conferidas uma a uma no
aceite da Tarefa 12.

## Bloco G — não-regressão (Tarefa 12)
_(a preencher na Tarefa 12: estilos, Ollama, idioma auto/pt/en)_
