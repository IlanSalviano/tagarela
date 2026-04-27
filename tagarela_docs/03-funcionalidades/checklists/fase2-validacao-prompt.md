---
data: 2026-04-27
status: aberto
escopo: validação cleanup #2 (initialPrompt → promptTokens)
---

# Validação A/B do `promptTokens`

Cleanup #2 do `cleanup-fase1.md`. Pergunta: `promptTokens` melhora ou piora a transcrição em PT-BR técnico?

## Como rodar

Cada frase é capturada **duas vezes**:

1. App rodando normal: `open ~/Applications/Tagarela.app`
2. App rodando com prompt desligado:

```bash
TAGARELA_DISABLE_PROMPT=1 open ~/Applications/Tagarela.app
```

(Ou exportar a env var no shell antes de abrir o app.)

Coletar texto cru via Console.app filtrado por subsystem `com.tagarela`, ou via histórico SwiftData (Tarefa 10 expõe).

## Frases-teste (8)

1. Faz um deploy do Postgres na produção.
2. O Kubernetes está com problema de pool de conexões.
3. Mandei o pull request mas o linter quebrou.
4. A gente precisa scopar o webhook do Slack.
5. O endpoint da API GraphQL está retornando 500.
6. Não conseguimos fazer o merge porque o rebase quebrou.
7. O Linear ticket tá com a feature flag errada.
8. Vou commitar e fazer push da branch.

## Tabela de resultados

| # | Sem prompt | Com prompt | Termo técnico mantido? |
|---|---|---|---|
| 1 | _____ | _____ | ☐ Postgres ☐ deploy |
| 2 | _____ | _____ | ☐ Kubernetes ☐ pool |
| 3 | _____ | _____ | ☐ pull request ☐ linter |
| 4 | _____ | _____ | ☐ scopar ☐ webhook ☐ Slack |
| 5 | _____ | _____ | ☐ endpoint ☐ API ☐ GraphQL |
| 6 | _____ | _____ | ☐ merge ☐ rebase |
| 7 | _____ | _____ | ☐ Linear ☐ feature flag |
| 8 | _____ | _____ | ☐ commitar ☐ push ☐ branch |

## Decisão

- ☐ Prompt melhora (≥ 6/8 termos preservados a mais com prompt) → manter ON, fechar cleanup #2 critério (b)
- ☐ Prompt piora (≥ 2/8 frases pioraram com prompt vs sem) → manter OFF, fechar cleanup #2 critério (a) com ADR
- ☐ Inconcluso → manter ON e revisar daqui a 2 meses

ADR `tagarela_docs/04-decisoes/ADR-0002-initialprompt-validacao.md` é criado APÓS execução do checklist com a decisão.
