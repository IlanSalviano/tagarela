#!/bin/bash
#
# release.sh initial|patch|minor|major
#
# Orquestrador: bump (se não-initial) → build → sign → notarize → dmg →
#               appcast → gh release create → git push --follow-tags
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
if [ "$1" != "initial" ]; then
    echo "===== 1/7 bump ====="
    "$SCRIPTS/bump.sh" "$1"
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

# 6. Appcast
echo "===== 6/7 appcast ====="
"$SCRIPTS/appcast.sh"

# Lê versão atual
version=$(grep -E '^\s*MARKETING_VERSION:' "$REPO_ROOT/app/project.yml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
DMG_PATH="$REPO_ROOT/build/release/Tagarela-$version.dmg"

# Cria git tag
echo "===== 7/7 tag + push + gh release ====="
git tag "v$version"

# Push commits + tags
git push --follow-tags

# gh release create
gh release create "v$version" "$DMG_PATH" \
    --title "tagarela $version" \
    --generate-notes

echo ""
echo "release.sh: v$version publicado"
echo "  DMG: $DMG_PATH"
echo "  GitHub: $(gh release view v$version --json url -q .url)"
