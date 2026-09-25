#!/bin/bash
#
# release.sh initial|patch|minor|major
#
# Orquestrador: bump (se não-initial) → build → sign → notarize → dmg →
#               tag → gh release (upload do DMG) → verifica HTTP 200 →
#               appcast + commit → git push --follow-tags
#
# A ORDEM IMPORTA. Até a Fase 5, o appcast.xml era commitado e pushado ANTES
# do `gh release create` subir o DMG. Como o feed do Sparkle é o raw do main,
# qualquer falha do gh (auth, rede) — ou só a janela entre push e upload —
# deixava todo cliente vendo um item novo e tomando 404 a cada checagem, até
# alguém consertar à mão. E o rerun travava, porque tag e commit já existiam.
#
# initial: pula bump.sh (pra v1.0.0 onde MARKETING_VERSION já está
#          editado em project.yml).
# patch/minor/major: chama bump.sh primeiro.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "uso: release.sh initial|patch|minor|major"
    exit 64
fi

case "$1" in
    initial|patch|minor|major) ;;
    *) echo "erro: arg inválido '$1'"; exit 64 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$REPO_ROOT/scripts"

ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe (copiar de .tagarela-release.env.example)"
    exit 1
fi

# Confirma working tree limpa
cd "$REPO_ROOT"
if [ -n "$(git status --porcelain)" ]; then
    echo "erro: working tree não está limpa"
    git status --short
    exit 1
fi

# Confirma estamos em main (ou avisa)
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "main" ]; then
    echo "aviso: não está em main (current: $current_branch). Continuar? (y/N)"
    read -r confirm
    if [ "$confirm" != "y" ]; then
        echo "cancelado."
        exit 0
    fi
fi

# 1. Bump (se aplicável)
#
# Idempotente: se o HEAD já é um commit de bump SEM tag correspondente, é uma
# tentativa anterior que morreu depois do bump. Reaproveita em vez de bumpar de
# novo — senão `release.sh patch` duas vezes ia de 1.0.4 direto pra 1.0.5, sem
# nenhuma release publicada no meio.
if [ "$1" != "initial" ]; then
    echo "===== 1/7 bump ====="
    head_subject=$(git log -1 --pretty=%s)
    pending_version=$(grep -E '^\s*MARKETING_VERSION:' "$REPO_ROOT/app/project.yml" \
        | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ "$head_subject" == "chore(release): bump "* ]] \
        && ! git rev-parse "v$pending_version" >/dev/null 2>&1; then
        echo "release.sh: HEAD já é o bump de v$pending_version e não há tag — reaproveitando"
    else
        "$SCRIPTS/bump.sh" "$1"
    fi
fi

# 2. Build
echo "===== 2/7 build ====="
"$SCRIPTS/build.sh"

# 3. Sign
echo "===== 3/7 sign ====="
"$SCRIPTS/sign.sh"

# 4. Notarize
echo "===== 4/7 notarize ====="
"$SCRIPTS/notarize.sh"

# 5. DMG
echo "===== 5/7 dmg ====="
"$SCRIPTS/dmg.sh"

# Lê versão atual
version=$(grep -E '^\s*MARKETING_VERSION:' "$REPO_ROOT/app/project.yml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
DMG_PATH="$REPO_ROOT/build/release/Tagarela-$version.dmg"
DMG_NAME="$(basename "$DMG_PATH")"

# Mesma derivação do appcast.sh — aqui é preciso antes de chamá-lo, pra montar
# a URL que vai ser verificada.
GITHUB_USER=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+)/.*|\1|' || echo "")
if [ -z "$GITHUB_USER" ]; then
    echo "erro: não consegui detectar GITHUB_USER do remote 'origin'"
    exit 1
fi

rollback_hint() {
    echo ""
    echo "===== FALHOU depois da tag — como voltar ====="
    echo "  git tag -d v$version"
    echo "  git push --delete origin v$version   # só se a tag já subiu"
    echo "  gh release delete v$version --yes    # só se a release foi criada"
    echo ""
    echo "  O appcast.xml NÃO foi commitado, então nenhum cliente Sparkle viu"
    echo "  um item apontando pra um DMG que não existe. Pode rodar de novo:"
    echo "  o bump é reaproveitado."
}

# 6. Tag + release + upload do DMG (antes do appcast — ver cabeçalho)
echo "===== 6/7 tag + gh release ====="
git tag -a "v$version" -m "tagarela $version"
trap rollback_hint ERR

gh release create "v$version" "$DMG_PATH" \
    --title "tagarela $version" \
    --generate-notes

DMG_URL="https://github.com/$GITHUB_USER/tagarela/releases/download/v$version/$DMG_NAME"
echo "release.sh: confirmando que o DMG está acessível…"
if ! curl -sSfI --retry 5 --retry-delay 2 --retry-all-errors "$DMG_URL" >/dev/null; then
    echo "erro: $DMG_URL não respondeu 200."
    echo "      O appcast NÃO foi gerado — nenhum cliente vai tomar 404."
    exit 1
fi
echo "release.sh: DMG confirmado em $DMG_URL"

# 7. Appcast — só agora que o binário existe e responde
echo "===== 7/7 appcast + push ====="
"$SCRIPTS/appcast.sh"
git add appcast.xml
git commit -m "chore(release): appcast.xml v$version"

# Push commits + tag. Fall back pra --set-upstream se branch atual
# ainda não tem tracking remoto (primeiro push após gh repo create).
if ! git push --follow-tags 2>/dev/null; then
    echo "release.sh: setando upstream + push"
    git push --set-upstream origin "$current_branch"
    git push origin "v$version"
fi
trap - ERR

echo ""
echo "release.sh: v$version publicado"
echo "  DMG: $DMG_PATH"
echo "  GitHub: $(gh release view v$version --json url -q .url)"
