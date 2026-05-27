---
data: 2026-05-27
fase: 4 (multi-idioma)
status: ok-parcial
---

> **2026-05-27:** auto-detecção de inglês (Bloco C) **confirmada em runtime pelo usuário** —
> falando inglês com idioma em Automático, a transcrição saiu em inglês (antes saía em
> português traduzido). Validada num build Debug local. Demais blocos (pt explícito, frase
> curta, migração) não percorridos formalmente; revisitar se necessário.

# Aceite manual — Fase 4 (idioma de transcrição)

Build Debug local. Modelo ativo deve ser multilíngue (default `large-v3_turbo`). Marcar
cada item ✅/❌ e anotar achados.

## Bloco A — Português explícito (não-regressão)

- [ ] Preferências > Transcrição: selecionar **Português**.
- [ ] Ditar uma frase em português → texto pt-BR correto, igual ao comportamento anterior.
- [ ] Sem latência perceptível a mais vs. antes (idioma explícito não roda detecção).

## Bloco B — Inglês explícito

- [ ] Selecionar **English**.
- [ ] Ditar uma frase em inglês → texto em inglês limpo (não "aportuguesado").
- [ ] Ditar em português com English selecionado → observar o comportamento (esperado:
      degradado; documenta o que sai).

## Bloco C — Automático (default)

- [ ] Selecionar **Automático** (ou confirmar que é o default numa instalação limpa).
- [ ] Ditar em português → sai português.
- [ ] Ditar em inglês → sai inglês.
- [ ] **Frase muito curta** (1–2 palavras) em inglês no Automático → confirmar/observar o
      risco de misdetect anotado no ADR-0006.

## Bloco D — Troca em runtime

- [ ] Trocar o idioma no picker **sem reiniciar** o app e ditar de novo → a escolha vale na
      próxima transcrição (sem reload de modelo, sem download).
- [ ] Fechar e reabrir o app → a escolha persiste.

## Bloco E — Migração (opcional, se houver build anterior instalado)

- [ ] Atualizar de uma versão pré-Fase 4 → idioma cai em **Automático** (migração implícita).

---

**Resultado:** _(preencher: ok / ok-com-achados / falhou)_

**Achados:** _(listar)_
