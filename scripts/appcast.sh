#!/bin/bash
#
# appcast.sh
#
# Adiciona <item> ao appcast.xml apontando pro DMG do release atual.
# Usa sign_update (Sparkle) pra gerar EdDSA signature do DMG.
# GitHub Releases URL é construída a partir da versão.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$REPO_ROOT/build/release"
APPCAST_PATH="$REPO_ROOT/appcast.xml"

ENV_FILE="$HOME/.tagarela-release.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "erro: $ENV_FILE não existe"
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [ -z "${SPARKLE_ED_PRIVATE_KEY_PATH:-}" ]; then
    echo "erro: SPARKLE_ED_PRIVATE_KEY_PATH não setado"
    exit 1
fi
if [ ! -f "$SPARKLE_ED_PRIVATE_KEY_PATH" ]; then
    echo "erro: $SPARKLE_ED_PRIVATE_KEY_PATH não existe (gerar com Sparkle generate_keys -x)"
    exit 1
fi

# Detectar GITHUB_USER do remote
GITHUB_USER=$(cd "$REPO_ROOT" && git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+)/.*|\1|' || echo "")
if [ -z "$GITHUB_USER" ]; then
    echo "erro: não consegui detectar GITHUB_USER do remote 'origin'"
    echo "      configurar com: git remote add origin git@github.com:<user>/tagarela.git"
    exit 1
fi

# Encontrar o DMG mais recente em build/release/
DMG_PATH=$(ls -t "$RELEASE_DIR"/Tagarela-*.dmg 2>/dev/null | head -1)
if [ -z "$DMG_PATH" ] || [ ! -f "$DMG_PATH" ]; then
    echo "erro: nenhum DMG encontrado em $RELEASE_DIR (rodar dmg.sh primeiro)"
    exit 1
fi

DMG_NAME=$(basename "$DMG_PATH")
version=$(echo "$DMG_NAME" | sed -E 's/Tagarela-([0-9.]+)\.dmg/\1/')
length=$(stat -f %z "$DMG_PATH")

# sparkle:version DEVE ser o CFBundleVersion (número de build): o Sparkle compara
# esse campo contra o CFBundleVersion do app instalado pra decidir se há update.
# Usar a versão de marketing aqui (ex: "1.0.3" contra build "4") quebra a detecção
# — o comparador lê [1,0,3] < [4] e nunca oferece o update. Ver ADR-0007.
# O .app já notarizado (o mesmo empacotado no DMG) é a fonte da verdade.
APP_PATH="$RELEASE_DIR/Tagarela.app"
build_version=$(plutil -p "$APP_PATH/Contents/Info.plist" 2>/dev/null | grep '"CFBundleVersion"' | sed -E 's/.*=> "([^"]+)".*/\1/')
if [ -z "$build_version" ]; then
    echo "erro: não consegui ler CFBundleVersion de $APP_PATH/Contents/Info.plist"
    exit 1
fi

# Localizar sign_update (binário do Sparkle SPM)
# Find direto evita adivinhar estrutura intermediária do SPM artifact dir.
# Filtra `old_dsa_scripts/` (legacy DSA) — queremos a EdDSA do Sparkle 2.x.
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData/Tagarela-*/SourcePackages/artifacts \
    -type f -name "sign_update" -perm +111 2>/dev/null \
    | grep -v old_dsa_scripts | head -1)
if [ -z "$SIGN_UPDATE" ] || [ ! -x "$SIGN_UPDATE" ]; then
    echo "erro: sign_update (EdDSA) não encontrado em SourcePackages/artifacts."
    echo "      builda pelo menos uma vez via xcodebuild pra resolver SPM."
    exit 1
fi

echo "appcast.sh: assinando $DMG_NAME"
SIGNATURE_OUTPUT=$("$SIGN_UPDATE" -f "$SPARKLE_ED_PRIVATE_KEY_PATH" "$DMG_PATH")
# Output do sign_update: 'sparkle:edSignature="..." length="..."'
ed_signature=$(echo "$SIGNATURE_OUTPUT" | sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/')
if [ -z "$ed_signature" ] || [ "$ed_signature" = "$SIGNATURE_OUTPUT" ]; then
    echo "erro: não consegui extrair edSignature do output do sign_update"
    echo "      output: $SIGNATURE_OUTPUT"
    exit 1
fi

dmg_url="https://github.com/$GITHUB_USER/tagarela/releases/download/v$version/$DMG_NAME"
pub_date=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

# Construir o novo <item>
new_item=$(cat <<EOF
    <item>
      <title>Versão $version</title>
      <pubDate>$pub_date</pubDate>
      <sparkle:version>$build_version</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <enclosure
        url="$dmg_url"
        sparkle:edSignature="$ed_signature"
        length="$length"
        type="application/octet-stream" />
    </item>
EOF
)

# Inserir o item logo após <!-- Items adicionados por scripts/appcast.sh a cada release -->
# Usar Python pra manipular XML preservando formato (sed XML é frágil).
python3 - "$APPCAST_PATH" "$new_item" <<'PYEOF'
import sys

path = sys.argv[1]
new_item = sys.argv[2]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Inserir o novo item logo após o comentário marker, ou logo antes de </channel>
marker = "<!-- Items adicionados por scripts/appcast.sh a cada release -->"
if marker in content:
    content = content.replace(marker, marker + "\n" + new_item, 1)
else:
    content = content.replace("</channel>", new_item + "\n  </channel>", 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"appcast.sh: <item> inserido em {path}")
PYEOF

# Commit do appcast.xml
cd "$REPO_ROOT"
git add appcast.xml
git commit -m "chore(release): appcast.xml v$version"

echo ""
echo "appcast.sh: ok"
echo "APPCAST_VERSION=$version"
echo "APPCAST_DMG_URL=$dmg_url"
