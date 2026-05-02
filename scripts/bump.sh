#!/bin/bash
#
# bump.sh patch|minor|major
#
# Lê MARKETING_VERSION + CURRENT_PROJECT_VERSION em app/project.yml,
# calcula próximo, edita o arquivo, regenera projeto Xcode, commita.
# NÃO cria tag (a tag é criada por release.sh após o build/sign/notarize).

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "uso: bump.sh patch|minor|major"
    exit 64
fi

case "$1" in
    patch|minor|major) ;;
    *) echo "erro: arg inválido '$1' (esperado: patch|minor|major)"; exit 64 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="$REPO_ROOT/app/project.yml"

current_version=$(grep -E '^\s*MARKETING_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
current_build=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$current_version" ] || [ -z "$current_build" ]; then
    echo "erro: não consegui ler MARKETING_VERSION ou CURRENT_PROJECT_VERSION em $PROJECT_YML"
    exit 1
fi

IFS='.' read -r major minor patch <<< "$current_version"

case "$1" in
    patch) new_version="$major.$minor.$((patch + 1))" ;;
    minor) new_version="$major.$((minor + 1)).0" ;;
    major) new_version="$((major + 1)).0.0" ;;
esac

new_build=$((current_build + 1))

echo "bump: $current_version ($current_build) → $new_version ($new_build)"

# Edita project.yml in-place. sed -i '' precisa de empty string como sufixo de backup no macOS.
sed -i '' -E "s/(MARKETING_VERSION:[[:space:]]+)\"$current_version\"/\1\"$new_version\"/" "$PROJECT_YML"
sed -i '' -E "s/(CURRENT_PROJECT_VERSION:[[:space:]]+)\"$current_build\"/\1\"$new_build\"/" "$PROJECT_YML"

# Verificar que a edição funcionou
verify_version=$(grep -E '^\s*MARKETING_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
verify_build=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$verify_version" != "$new_version" ] || [ "$verify_build" != "$new_build" ]; then
    echo "erro: edição do project.yml falhou (esperado $new_version/$new_build, lido $verify_version/$verify_build)"
    exit 1
fi

# Regenerar projeto Xcode
cd "$REPO_ROOT/app"
xcodegen generate

# Commit (sem tag — tag é criada por release.sh)
cd "$REPO_ROOT"
git add app/project.yml app/Tagarela.xcodeproj
git commit -m "chore(release): bump $current_version → $new_version"

echo ""
echo "bump.sh: ok ($new_version)"
echo "BUMP_NEW_VERSION=$new_version"
echo "BUMP_NEW_BUILD=$new_build"
