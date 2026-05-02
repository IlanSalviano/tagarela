---
data: 2026-05-01
fase: 3-release
status: ok
---

# Aceite manual — Fase 3 (release engineering)

## Bloco A — primeiro release end-to-end (v1.0.0) ✅

- [x] `./scripts/release.sh initial` executou (com 1 fix iterativo: dmg.sh precisou notarizar o DMG separadamente antes do staple — ticket é por arquivo).
- [x] `Tagarela-1.0.0.dmg` em `build/release/`, 7.0 MB.
- [x] notarytool: `status: Accepted` pra .app (id `e79a0bd7...`) e pro DMG (id `c87b1857...`).
- [x] `xcrun stapler validate` passou em ambos (.app e DMG).
- [x] `appcast.xml` ganhou `<item>` v1.0.0 com edSignature, length, URL.
- [x] `git tag v1.0.0` criada.
- [x] `gh release create v1.0.0` com DMG anexado: https://github.com/IlanSalviano/tagarela/releases/tag/v1.0.0.

## Bloco B — Gatekeeper em máquina limpa ✅

- [x] DMG baixado de `curl -L https://github.com/IlanSalviano/tagarela/releases/download/v1.0.0/Tagarela-1.0.0.dmg`.
- [x] `spctl -a -vv -t install` retornou `accepted, source=Notarized Developer ID, origin=Developer ID Application: Ilan Salviano (22CZXFP6W7)`.
- [x] DMG aberto, Tagarela.app arrastado pro symlink `Applications` → instalado em `/Applications`.
- [x] Primeira abertura: NÃO mostrou "App de desenvolvedor não-identificado". Apenas popups TCC nativos (Microphone + Documents).

## Bloco C — TCC nativo (cleanup #6 da Fase 1) ✅

- [x] Popup nativo de **Microphone** apareceu automaticamente. Aceito. (Cleanup #6 da Fase 1 — workaround SQL no TCC.db NÃO é mais necessário.)
- [x] Popup nativo de **Documents** folder apareceu (esperado: WhisperKit baixa modelos pra `~/Documents/huggingface/...`). Aceito.
- [x] **Accessibility** e **Input Monitoring** ainda exigem add manual via System Settings → `+` → `Tagarela.app`. Esse é o comportamento padrão do macOS (esses TCCs não têm popup nativo). Documentado em `00-setup-dev.md`.
- [x] Após adicionar AX + Input Monitoring, hotkey + transcribe + inject funcionam fim-a-fim.
- [x] Cleanup #6 da Fase 1 → ✅ fechado.

## Bloco D — Sparkle ✅

- [x] `./scripts/release.sh patch` publicou v1.0.1: https://github.com/IlanSalviano/tagarela/releases/tag/v1.0.1.
- [x] `defaults write com.tagarela.Tagarela SULastCheckTime -string 'never'` + reabrir app v1.0.0 instalado.
- [x] Sheet nativa de update do Sparkle apareceu.
- [x] Update aplicou: app reabriu como v1.0.1.

## Bloco E — botão Console em Preferências > Sobre ✅

- [x] Preferências (⌘ ,) → Sobre → seção LOGS com botão "Abrir logs no Console".
- [x] Clicar abre Console.app. Console.app NÃO honra `--predicate` por argv (Versão B do plano), então a copy abaixo do botão guia o user a filtrar manualmente por `subsystem == com.tagarela`.

---

## Status final: **ok**

## Bugs encontrados durante aceite (todos fechados)

- **Bloco A:** dmg.sh original tentava staple sem notarização separada do DMG → erro 65 (Record not found). Fix: notarizar DMG antes do staple (`fix(release): dmg.sh notariza o DMG antes do staple`).
- **Bloco A → appcast:** find do binário `sign_update` adivinhava estrutura intermediária do SPM artifacts (`extract/sparkle/...`). Fix: find direto por nome do binário, filtrando `old_dsa_scripts/` legacy (`fix(release): appcast.sh procura sign_update via find direto`).
- **Bloco D:** `release.sh` falhou no push final por main não ter upstream. Fix: fallback pra `git push --set-upstream` + push da tag separado (`fix(release): release.sh push robusto sem upstream tracking`).

## Lição aplicada

Lição 2c-cleanup ("aceite manual antes do merge") foi cumprida. Cada uma das 3 falhas acima foi pega no aceite, corrigida, e re-executada — sem precisar reverter nada.
