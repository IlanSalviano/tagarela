# tagarela

**Ditado por voz local pro macOS, com pós-processamento por LLM.**

Aperta a tecla, fala, solta. O texto transcrito (e opcionalmente refinado por um LLM) é injetado direto no app onde o cursor está. Áudio nunca sai da máquina — Whisper roda local via [WhisperKit](https://github.com/argmaxinc/WhisperKit) na Neural Engine do Apple Silicon.

> Clone individual do Wispr Flow, feito pra mim e algumas pessoas próximas. Foco em português brasileiro.

---

## Como funciona

```
[Right Option] → grava → [Right Option] → Whisper (local)
                                           ↓
                                       texto cru
                                           ↓
                              Refiner (Identity / Ollama / OpenAI)
                                           ↓
                               injeção via AX no app ativo
```

- **Hotkey**: Right Option (toggle start/stop). Esc cancela.
- **Transcrição**: WhisperKit + Core ML. Default `large-v3_turbo` (~1.5 GB, ~2× tempo real). Trocável em Preferências > Transcrição.
- **Refiner** (pós-processamento): escolha entre
  - **Sem refiner** (Identity) — texto cru do Whisper.
  - **Ollama local** — modelo da sua escolha rodando em `localhost:11434`. Privacidade total.
  - **OpenAI API** — mais qualidade, mais custo, key fica no Keychain.
- **Estilos**: presets de prompt pro refiner ("conversa informal", "documentação", custom seu) pra moldar o tom.
- **Histórico**: últimas N transcrições (configurável), com retenção por dias. Tudo local em SwiftData.
- **Vocabulário técnico**: lista de termos passados como `initial_prompt` pro Whisper, melhora reconhecimento de jargão.

## Instalar

Baixa o DMG mais recente:

→ **[github.com/IlanSalviano/tagarela/releases/latest](https://github.com/IlanSalviano/tagarela/releases/latest)**

Arrasta `Tagarela.app` pro `Applications`. Na primeira abertura, o macOS pergunta se quer abrir um app baixado da internet — clica "Abrir".

### Setup de permissões (1 minuto)

Pra hotkey + injeção funcionarem, o macOS exige 3 TCCs. O **Microphone** vem por popup nativo na primeira gravação. Os outros 2 precisam ser adicionados manualmente:

1. **System Settings → Privacy & Security → Accessibility**
   - `+` → escolhe `Tagarela.app` em `/Applications` → toggle ON.
2. **System Settings → Privacy & Security → Input Monitoring**
   - mesma coisa.

Reabre o app. Aperta Right Option, fala 3 segundos, solta — texto deve aparecer onde o cursor estiver.

### Onboarding

Na primeira execução, o app guia por 3 passos:

1. **Boas-vindas**.
2. **Permissões** — checklist visual de Microphone, Accessibility, Input Monitoring.
3. **Modelo** — escolha entre `large-v3_turbo` (recomendado), `large-v3` (qualidade máxima), `medium` (mais leve). Faz download (815 MB a 2.9 GB conforme escolha) na hora.

## Atualizações

Auto-update via [Sparkle](https://sparkle-project.org/). Quando saio nova versão, o app detecta sozinho na próxima abertura e oferece a sheet de update — clica "Install" e ele baixa, valida assinatura, instala, reabre.

Sem servidor próprio: o feed (`appcast.xml`) e os DMGs ficam neste repo + GitHub Releases.

## Privacidade

- Áudio: **nunca** sai da máquina. Processado em memória, descartado após transcrição.
- Texto cru do Whisper: 100% local.
- Refiner Identity ou Ollama: 100% local.
- Refiner OpenAI: o texto cru é enviado pra API da OpenAI. Você ativa explicitamente em Preferências e a key fica no Keychain. Áudio nunca vai pra nenhuma API remota.
- Histórico: SQLite local em `~/Library/Application Support/com.tagarela.Tagarela/`.
- Sem analytics. Sem crash reports. Sem telemetria.

## Build local

Requer Xcode 15.4+, Apple Silicon, macOS 14+.

```bash
git clone https://github.com/IlanSalviano/tagarela.git
cd tagarela/app
brew install xcodegen
xcodegen generate
xcodebuild -scheme Tagarela -destination 'platform=macOS' build
```

Pra builds Release + DMG distribuível, ver [`tagarela_docs/02-arquitetura/00-setup-dev.md`](tagarela_docs/02-arquitetura/00-setup-dev.md).

## Stack

- Swift 5.10, SwiftUI, AppKit cirúrgico.
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Whisper em Core ML).
- [Sparkle](https://sparkle-project.org/) (auto-update).
- SwiftData (histórico + custom styles).
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (project Xcode é gerado).
- macOS 14+.

## Documentação

Vault Obsidian em [`tagarela_docs/`](tagarela_docs/). Comece por [`tagarela_docs/README.md`](tagarela_docs/README.md). Inclui design original, snapshots por fase, ADRs, checklists de aceite manual.

## Status

v1.0.x publicada. Distribuição pra mim + uns conhecidos. Não é um produto comercial.

## Autor

Ilan Salviano

- X: [@IlanSalviano](https://x.com/IlanSalviano)
- Email: ilan.salviano@gmail.com

Coautoria de implementação: Claude (Anthropic) via Claude Code.
