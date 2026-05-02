#!/bin/bash
#
# dmg.sh
#
# Cria Tagarela-<version>.dmg com .app + symlink /Applications, assina,
# staple. Versão lida do Info.plist do .app já notarizado.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$REPO_ROOT/build/release/Tagarela.app"
RELEASE_DIR="$REPO_ROOT/build/release"

ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe"
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [ -z "${DEVELOPER_ID_APP_SHA1:-}" ]; then
    echo "erro: DEVELOPER_ID_APP_SHA1 não setado em $ENV_FILE"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "erro: $APP_PATH não existe (rodar build.sh + sign.sh + notarize.sh primeiro)"
    exit 1
fi

# Lê versão do Info.plist
version=$(plutil -p "$APP_PATH/Contents/Info.plist" | grep CFBundleShortVersionString | sed -E 's/.*=> "([^"]+)".*/\1/')
if [ -z "$version" ]; then
    echo "erro: não consegui ler CFBundleShortVersionString"
    exit 1
fi

DMG_PATH="$RELEASE_DIR/Tagarela-$version.dmg"
STAGING_DIR="$RELEASE_DIR/dmg-staging"

echo "dmg.sh: criando $DMG_PATH (versão $version)"

# Limpa e prepara staging dir
rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copia .app + cria symlink pra /Applications
cp -R "$APP_PATH" "$STAGING_DIR/Tagarela.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Cria DMG (formato UDZO comprimido)
hdiutil create \
    -volname "Tagarela $version" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "dmg.sh: assinando DMG"
codesign \
    --force \
    --sign "$DEVELOPER_ID_APP_SHA1" \
    --timestamp \
    "$DMG_PATH"

echo "dmg.sh: staplando ticket no DMG"
xcrun stapler staple "$DMG_PATH"

echo "dmg.sh: validando staple"
xcrun stapler validate "$DMG_PATH"

# Limpa staging
rm -rf "$STAGING_DIR"

echo ""
echo "dmg.sh: ok"
echo "DMG_PATH=$DMG_PATH"
echo "DMG_VERSION=$version"
