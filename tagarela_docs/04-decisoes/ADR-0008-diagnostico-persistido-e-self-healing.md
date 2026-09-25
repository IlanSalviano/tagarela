---
data: 2026-09-07
status: aceito (implementado na Fase 5; aceite manual dos Blocos B–E pendente)
---

# ADR-0008 — Diagnóstico persistido e self-healing em sessão longa

## Contexto

O app para de fazer STT depois de muitos dias no ar. Não crasha, não avisa;
relaunch resolve. A [auditoria de 2026-09-07](../02-arquitetura/10-auditoria-2026-09-07.md)
inspecionou um processo com 9 dias e 12 horas e **não conseguiu confirmar a
causa-raiz** — por dois motivos que se reforçam:

1. **Os caminhos de falha candidatos são mudos por construção.** Buffer curto
   descartado em `.info`, transcrição vazia injetada como string vazia, cola
   negada retornando antes do `save`, tap invalidado sem aviso. Todos produzem
   exatamente o sintoma relatado: nada acontece.
2. **O log não sobrevive.** A retenção efetiva do log unificado para o processo
   do app nesta máquina é de ~1,5 dia, e `.info` praticamente não chega ao disco.
   Quando o usuário percebe a falha, a evidência já foi descartada. O botão
   "Abrir logs no Console" era inútil para o caso de uso que motivou sua
   existência.

Restaram três hipóteses não testáveis sem instrumentação: **H1** captura de
áudio (engine único, nunca recriado, sem verificação de que buffers chegaram),
**H2** decoder degradado (nenhuma métrica exposta para distinguir de áudio ruim),
**H3** churn de permissões (Acessibilidade ou Input Monitoring caindo no meio da
sessão).

## Decisão

### 1. Diagnóstico persiste em arquivo, não só no log unificado

`DiagnosticsLog` escreve em `~/Library/Logs/Tagarela/tagarela.log`, rotativo
5 MB × 3. `Diag.notice` e `Diag.error` vão para o log unificado **e** para o
arquivo; `Diag.info` só para o unificado.

**Nunca o conteúdo do usuário.** Só contagens, durações, formatos, métricas
numéricas e bundle id do app-alvo. A linha `transcribed: '\(raw)'` — que mandava
todo ditado para o log — virou `transcribed chars=N`. Como as linhas agora
persistem em disco, o vazamento seria permanente, então a regra é verificada por
um teste que varre os fontes e reprova qualquer `Diag.*` que interpole variável
de texto.

### 2. Toda falha silenciosa vira evento, toast e `.error`

Nenhum caminho pode terminar em "nada aconteceu". Captura sem áudio e transcrição
vazia emitem evento com toast; anomalias sobem para `.error` no log.

**Exceção deliberada:** um descarte por buffer curto com **menos de 1 segundo de
wall-clock** continua silencioso. É toque acidental na hotkey, e transformá-lo em
toast treinaria o usuário a ignorar toasts.

### 3. Vazio nunca é injetado nem salvo

Antes, `''` era colado no app-alvo e gravado no histórico. Agora o pipeline para,
avisa e conta. **Duas transcrições vazias seguidas** recriam o `WhisperKit` **a
partir do disco** — de disco porque o app está degradado justamente quando não se
quer depender de `huggingface.co` estar de pé.

### 4. Self-healing onde a falha é invisível

- **Áudio:** `AVAudioEngine` novo a cada gravação (custa milissegundos) e watchdog de 1 s — sem buffer, recria e tenta uma vez; se ainda assim nada vier, o `stop()` **lança** em vez de devolver silêncio.
- **Hotkey:** `start()` idempotente, watchdog de 30 s no tap, e re-`start()` quando Input Monitoring volta a `granted`. Um tap invalidado não avisa ninguém.
- **Decoder:** ver decisão 3.

### 5. Política de restauração do clipboard

Não há como confirmar que o app-alvo processou o ⌘V. Na dúvida, **o ditado fica
no clipboard**:

| Regra | Motivo |
|---|---|
| Texto vai ao pasteboard **antes** de checar Acessibilidade | Com a Acessibilidade caída o ditado sumia inteiro — não colava, não ficava no clipboard, não entrava no histórico |
| Histórico salvo **antes** da cola | Mesma razão: a cola é o passo que pode falhar |
| Restauração em `Task.detached` | O Esc do usuário cancelava a Task do pipeline, interrompia o sleep e restaurava **antes** do alvo consumir o ⌘V, colando o conteúdo anterior |
| Só restaura se `changeCount` não mudou | Se alguém copiou outra coisa no meio, restaurar seria atropelar |
| Só restaura se havia algo antes | Com o clipboard vazio, restaurar significaria **apagar** o ditado |
| Delay 400 ms (era 250) | Os alvos reais deste usuário — Claude, Codex, WhatsApp — são Electron e consomem o ⌘V depois de 250 ms |

## Consequências

**Positivas.** A próxima ocorrência vira um bug diagnosticável em minutos: a
sequência `start → stop → buffer → transcribe → inject` de cada ditado fica em
disco por dias, com formato de entrada, device default, contagem de buffers,
pico antes/depois, wall-clock e métricas do decoder. "Exportar diagnóstico" junta
log, retrato do estado e `vmmap` numa pasta. E três subsistemas se recuperam
sozinhos, então parte das ocorrências deixa de ser percebida como falha.

**Negativas e aceitas.**

- **Escrita em disco no caminho quente.** Poucas linhas por ditado, sob lock, fora da thread de render — o tap de áudio não loga. Aceito.
- **Engine novo por gravação** troca uma latência de milissegundos no início da gravação por robustez. O risco a medir em campo é o tempo até o primeiro buffer.
- **Mais toasts.** Falhas que antes eram invisíveis agora interrompem. Mitigado pelo limiar de 1 s de wall-clock.
- **A recuperação do decoder é um tiro no escuro.** Recriar o `WhisperKit` só ajuda se H2 for verdadeira. Se não for, o custo é uma recarga ocasional de modelo — e a linha de log que registra a tentativa passa a ser evidência **contra** H2.

**O que esta fase não resolve.** A causa-raiz continua não confirmada. A decisão
é deliberadamente instrumentar em vez de adivinhar: a
[Tarefa 13 do plano](../specs/2026-09-07-tagarela-v1-fase5-robustez-sessao-longa-plan.md)
usa a próxima ocorrência em campo para fechá-la.

## Alternativas consideradas

- **Só instrumentar, sem self-healing.** Mais honesto do ponto de vista científico — o self-healing pode mascarar a falha que se quer observar. Recusado porque o usuário conviveria com o bug por mais semanas, e os contadores de recuperação registram cada mascaramento, preservando a evidência.
- **Só self-healing, sem diagnóstico persistido.** Mais barato, mas repetiria o erro de maio de 2026: uma hipótese registrada sem prova, que a auditoria não conseguiu confirmar nem refutar um ano depois.
- **Reiniciar o app periodicamente (watchdog externo).** Resolveria o sintoma sem entender nada, e trocaria uma falha rara por uma interrupção previsível.
- **Manter o engine e recriar só em `AVAudioEngineConfigurationChange`.** Menos invasivo, mas o reprodutor `tools/diag/engine_reuse_test.swift` mostrou que o agregado do macOS 26 **absorve** esse gatilho — a notificação pode simplesmente não chegar no cenário real.
- **Escrever o log via `OSLogStore` em vez de arquivo próprio.** Depende da retenção do sistema, que é exatamente o que falhou aqui.
