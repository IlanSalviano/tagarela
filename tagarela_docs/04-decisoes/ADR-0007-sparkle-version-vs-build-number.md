---
data: 2026-05-27
status: aceita
---

# ADR-0007 — `sparkle:version` no appcast deve ser o `CFBundleVersion` (build number)

## Contexto

A detecção de update via Sparkle nunca funcionou de fato para usuários que já tinham
passado da v1.0.0. O sintoma apareceu em 2026-05-27: uma segunda máquina (rodando v1.0.2)
não detectou a release v1.0.3 recém-publicada, apesar de toda a infra de release estar
correta (release não-draft no GitHub, DMG anexado, `appcast.xml` commitado/pushado,
assinatura EdDSA presente, `SUFeedURL` apontando para a raw URL certa).

### Causa-raiz

O Sparkle compara o campo **`sparkle:version` do appcast** contra o **`CFBundleVersion`**
do app instalado (não o `CFBundleShortVersionString`, que é só exibição). O
`SUStandardVersionComparator` quebra ambos por `.` e compara componente a componente.

No tagarela os dois campos viviam em escalas diferentes:

| Campo | Valor (v1.0.3) | Origem |
| --- | --- | --- |
| `CFBundleVersion` (app instalado) | `4` (inteiro, incrementa 1→2→3→4) | `CURRENT_PROJECT_VERSION` no `project.yml` |
| `sparkle:version` (appcast) | `1.0.3` (versão de marketing) | `appcast.sh` usava a versão extraída do nome do DMG |

A comparação do Sparkle ficava `[1,0,3]` (appcast) contra `[4]` (instalado): primeiro
componente `1 < 4` → o appcast é considerado **mais antigo** que o instalado → **nenhum
update é oferecido**. Qualquer host com `CFBundleVersion` inteiro ≥ 2 perde a comparação
contra um `sparkle:version` que começa com `1.`.

### Por que o aceite da Fase 3 não pegou (falso positivo)

O Bloco D do [aceite da Fase 3](../03-funcionalidades/checklists/fase3-manual.md) validou
update **de v1.0.0 (build `1`) para v1.0.1**. Esse é o único caso que funciona por
acidente: host `"1"` → `[1]` contra appcast `"1.0.1"` → `[1,0,1]`; os primeiros componentes
empatam (`1 == 1`) e o appcast, sendo mais longo com componentes `> 0`, vence → update
oferecido. A partir do build `2` (`1 < 2`, `1 < 3`, …) a comparação quebra. O teste cobriu
exatamente a transição que mascarava o bug.

Mapeamento histórico build ↔ marketing (do `project.yml` por tag):

| Release | `MARKETING_VERSION` | `CFBundleVersion` |
| --- | --- | --- |
| v1.0.0 | 1.0.0 | 1 |
| v1.0.1 | 1.0.1 | 2 |
| v1.0.2 | 1.0.2 | 3 |
| v1.0.3 | 1.0.3 | 4 |

## Decisão

1. **`sparkle:version` = `CFBundleVersion`** (o número de build inteiro). É o que o Sparkle
   compara. `sparkle:shortVersionString` continua sendo a versão de marketing
   (`MARKETING_VERSION`), usada só para exibição na UI do Sparkle.
2. `scripts/appcast.sh` passa a ler o `CFBundleVersion` do `.app` notarizado em
   `build/release/Tagarela.app/Contents/Info.plist` (mesma fonte de verdade que o
   `dmg.sh` usa pra versão) e emite esse valor em `sparkle:version`. A versão de marketing
   (parseada do nome do DMG) continua em `sparkle:shortVersionString` e no `<title>`.
3. Corrigir retroativamente o `appcast.xml` atual: cada `<item>` passa a ter
   `sparkle:version` = build number (1, 2, 3, 4) em vez da versão de marketing.

Editar `sparkle:version` no `appcast.xml` **não invalida** a assinatura EdDSA: a assinatura
cobre os bytes do DMG (via `enclosure`), não o texto do XML.

## Consequências

### Positivas
- A máquina na v1.0.2 (build `3`) passa a ver `4 > 3` → update detectado. Vale para
  qualquer build anterior (`1`, `2`, `3` todos `< 4`).
- Releases futuras saem corretas automaticamente: o número de build sempre incrementa e o
  Sparkle compara inteiro contra inteiro.

### Negativas / cuidados
- O `CURRENT_PROJECT_VERSION` **precisa incrementar a cada release** (o `bump.sh` já faz
  isso). Se dois releases saírem com o mesmo build number, o Sparkle não oferece o update.
- A raw URL do GitHub (`raw.githubusercontent.com`) tem cache de CDN (~5 min). Após o push
  do appcast corrigido, a outra máquina pega na próxima checagem (auto-check no launch ou a
  cada 24h via `SUScheduledCheckInterval`).

### Neutras
- `CFBundleShortVersionString` (marketing) segue independente e é o que o usuário vê.

## Alternativas consideradas

1. **Alinhar `CFBundleVersion` ao marketing (ex: build = `10003` para 1.0.3).** Manteria
   um único número, mas exigiria um esquema de encoding (major*10000 + minor*100 + patch) e
   mudaria o `project.yml`/`bump.sh`. Rejeitado: o build number inteiro sequencial já existe
   e é exatamente o que o Sparkle quer. Menos partes móveis.
2. **Deixar `sparkle:version` = marketing e confiar só no `shortVersionString`.** Não
   funciona: o Sparkle ignora o `shortVersionString` na comparação quando `sparkle:version`
   está presente. Rejeitado por contrariar o comportamento documentado do Sparkle.

## Como revisitar

Se algum dia o esquema de build number mudar (ex: CI gerando build numbers por timestamp),
revalidar que ainda incrementa monotonicamente. Idealmente, adicionar ao aceite de release
um teste de update **a partir de um build ≥ 2** (não só de v1.0.0), que é o caso que
expõe esta classe de bug.
