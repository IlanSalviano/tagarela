#!/bin/bash
#
# notarize.sh
#
# zip build/release/Tagarela.app → notarytool submit --wait → staple
# no .app. Logs em build/release/notarization.log.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$REPO_ROOT/build/release/Tagarela.app"
ZIP_PATH="$REPO_ROOT/build/release/Tagarela.zip"
LOG_PATH="$REPO_ROOT/build/release/notarization.log"

ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe"
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

for var in APPLE_ID APPLE_TEAM_ID APPLE_APP_SPECIFIC_PASSWORD; do
    if [ -z "${!var:-}" ]; then
        echo "erro: $var não setado em $ENV_FILE"
        exit 1
    fi
done

if [ ! -d "$APP_PATH" ]; then
    echo "erro: $APP_PATH não existe (rodar build.sh + sign.sh primeiro)"
    exit 1
fi

echo "notarize.sh: criando $ZIP_PATH"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "notarize.sh: submetendo pro notarytool (vai esperar resposta — pode levar 1-5 minutos)"
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait \
    --output-format plist 2>&1 | tee "$LOG_PATH"

# Verificar status
status=$(grep -A1 "<key>status</key>" "$LOG_PATH" | tail -1 | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
if [ "$status" != "Accepted" ]; then
    echo ""
    echo "erro: notarization status='$status' (esperado 'Accepted')"
    echo "      log completo em $LOG_PATH"
    echo "      consultar log detalhado:"
    submission_id=$(grep -A1 "<key>id</key>" "$LOG_PATH" | head -2 | tail -1 | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
    echo "      xcrun notarytool log $submission_id --apple-id $APPLE_ID --team-id $APPLE_TEAM_ID --password \$APPLE_APP_SPECIFIC_PASSWORD"
    exit 1
fi

echo ""
echo "notarize.sh: notarization aceita; staplando ticket no .app"
xcrun stapler staple "$APP_PATH"

echo "notarize.sh: validando staple"
xcrun stapler validate "$APP_PATH"

echo ""
echo "notarize.sh: ok"
