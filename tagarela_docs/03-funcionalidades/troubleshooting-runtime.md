---
data: 2026-05-04
status: vivo (adicionar entradas conforme aparecem em uso real)
---

# Troubleshooting — sintomas em runtime

Coletânea de sintomas observados rodando v1.0.x em uso real (não em aceite manual estruturado), com a remediação que destravou cada um. Cada entrada deve registrar **sintoma → diagnóstico → remediação** com a linha de log que provou a causa.

---

## 1. Transcrição volta vazia depois de horas + mexer em Accessibility

**Data:** 2026-05-04 (v1.0.1, build instalada em `/Applications/Tagarela.app`).

### Sintoma

Após o app rodar por horas e o usuário ter removido/re-adicionado Tagarela em **System Settings → Privacy & Security → Accessibility** (numa tentativa anterior de destravar a injeção), a captura de áudio continua funcionando mas o `transcribed: ''` chega vazio. Pílula transita por `.recording` → `.processing`, evento `finished(rawText: "", refinedText: "", ...)` é emitido, nada vai para o campo de texto.

### Logs-chave

Subsystem `com.tagarela`, categoria `Pipeline`:

```
buffer duration=2.74s samples=43840
transcribing (model loaded? large-v3_turbo)
transcribed: ''                       ← bandeira vermelha
injecting (kind=none)
injected to com.apple.Notes           ← injeta string vazia
```

ANE devolve sucesso (`ANEProgramProcessRequestDirect status=0x0`) — o decoder da WhisperKit está retornando sem erro mas com texto vazio. Audio peak no buffer estava em ~0.149 (acima do threshold de silêncio), então não é VAD trivial; é estado interno do contexto Whisper que travou.

### Remediação

**`Cmd+Q` total no Tagarela** (Quit, não só fechar a janela de Preferências) e relaunch a partir de `/Applications/Tagarela.app`. Após o relaunch, duas execuções consecutivas voltaram a funcionar:

```
transcribed: 'Um, dois, três...'
injected to com.apple.Notes
```

Fechar a janela das Preferências sozinho **não** resolve — a janela é só uma view sobre o `NSApp` que continua rodando.

### Causa-raiz provável

Long-running session + churn de permissões (TCC `kTCCServiceAccessibility` foi removido e re-concedido durante a sessão) deixou o `WhisperKitContext` num estado interno em que decoder/VAD para de gerar tokens mas não devolve erro. Não foi possível confirmar se o gatilho é (a) horas de uso, (b) o re-adicionar em Accessibility especificamente, ou (c) a combinação. Reproduzir requer recriar a janela de uso real — não há repro automatizado.

### Mitigações futuras (não implementadas)

- Auto-reinit do `WhisperKitContext` se N tentativas seguidas vierem com `rawText.isEmpty` e `audioPeak >= threshold`.
- Recriar contexto proativamente quando o app receber `kTCCServiceAccessibility` change notification.
- Diagnóstico in-app: detectar transcribed-vazio em audio-com-sinal e sugerir restart do app via toast.

Investigar como item de backlog se sintoma reaparecer em outra sessão.

---

## 2. Sparkle não detecta release nova (update silenciosamente não oferecido)

**Data:** 2026-05-27 (máquina secundária na v1.0.2 não viu a v1.0.3).

### Sintoma

Uma máquina rodando uma versão antiga não recebe o prompt de update mesmo com a release
nova publicada e o appcast atualizado. Nenhum erro visível; o Sparkle simplesmente conclui
que não há nada mais novo.

### Diagnóstico

O `appcast.xml` trazia `sparkle:version` = versão de marketing (`1.0.3`), mas o Sparkle
compara esse campo contra o `CFBundleVersion` do app instalado, que é um inteiro de build
(`4`). `[1,0,3]` perde para `[4]` no primeiro componente (`1 < 4`) → update considerado
"mais antigo" → não oferecido. Bug presente desde sempre; só não apareceu antes porque o
único update testado no aceite (v1.0.0 build `1` → v1.0.1) é o caso que funciona por
acidente. Detalhe completo em [ADR-0007](../04-decisoes/ADR-0007-sparkle-version-vs-build-number.md).

### Remediação

`sparkle:version` deve ser o `CFBundleVersion` (build number), não a versão de marketing.
Corrigido em `appcast.xml` (itens passam a usar 1/2/3/4) e em `scripts/appcast.sh` (lê o
`CFBundleVersion` do `.app` notarizado). Após push, a raw URL do GitHub leva ~5 min de CDN
pra propagar; a máquina pega na próxima checagem (launch ou 24h).

### Como confirmar que voltou

Na máquina antiga, forçar uma checagem (relaunch do app) e verificar que o prompt de update
aparece. Alternativamente, comparar `CFBundleVersion` instalado (`< 4`) com o
`sparkle:version` do appcast (`4`).
