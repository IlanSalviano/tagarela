#!/bin/bash
#
# build.sh
#
# xcodebuild -configuration Release → build/release/Tagarela.app
# Sem signing além do que o build do Xcode aplica (cert do Release config
# do project.yml). Notarization e DMG vêm depois.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$REPO_ROOT/build/release"
DERIVED_DATA="$RELEASE_DIR/derived"

echo "build.sh: limpando $RELEASE_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

cd "$REPO_ROOT/app"

echo "build.sh: rodando xcodebuild -configuration Release"
xcodebuild \
    -scheme Tagarela \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    clean build 2>&1 | tail -20

BUILT_APP="$DERIVED_DATA/Build/Products/Release/Tagarela.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "erro: $BUILT_APP não existe após xcodebuild"
    exit 1
fi

echo "build.sh: copiando .app pra $RELEASE_DIR/Tagarela.app"
cp -R "$BUILT_APP" "$RELEASE_DIR/Tagarela.app"

# Validar versão no Info.plist do .app copiado
version=$(plutil -p "$RELEASE_DIR/Tagarela.app/Contents/Info.plist" | grep CFBundleShortVersionString | sed -E 's/.*=> "([^"]+)".*/\1/')
echo ""
echo "build.sh: ok"
echo "BUILD_APP_PATH=$RELEASE_DIR/Tagarela.app"
echo "BUILD_VERSION=$version"
