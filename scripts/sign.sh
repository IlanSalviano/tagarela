#!/bin/bash
#
# sign.sh
#
# Re-assina build/release/Tagarela.app com cert Developer ID Application,
# hardened runtime, timestamp, e entitlements explícitos. Verifica.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$REPO_ROOT/build/release/Tagarela.app"
ENTITLEMENTS="$REPO_ROOT/app/Tagarela/Resources/Tagarela.entitlements"

# Carrega secrets
ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe (copiar de .tagarela-release.env.example)"
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [ -z "${DEVELOPER_ID_APP_SHA1:-}" ]; then
    echo "erro: DEVELOPER_ID_APP_SHA1 não setado em $ENV_FILE"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "erro: $APP_PATH não existe (rodar build.sh primeiro)"
    exit 1
fi

if [ ! -f "$ENTITLEMENTS" ]; then
    echo "erro: $ENTITLEMENTS não existe"
    exit 1
fi

echo "sign.sh: assinando $APP_PATH"
echo "        identity: $DEVELOPER_ID_APP_SHA1"

codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID_APP_SHA1" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_PATH"

echo "sign.sh: verificando assinatura"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tail -10

echo ""
echo "sign.sh: ok"
