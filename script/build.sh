#!/usr/bin/env bash
# macOS counterpart of windows_app_script/script/build.ps1 — asks which
# version to release, generates resido-client from resido.sh, installs its
# dependencies and packages the .dmg/.zip.
#
# No SFTP/upload step here (unlike build.ps1) because this client has no
# auto-update support yet — there is no update host to publish to. Once
# auto-update is added for macOS, extend this script the same way build.ps1
# uploads to residowindows.vorntech.sk.
#
# Usage:
#   ./build.sh                  # asks interactively for the version
#   ./build.sh -v 3.5.1         # sets the version non-interactively
#   ./build.sh --skip-version   # keeps the current .env version, no prompt
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_PATH="$SCRIPT_DIR/.env"
VERSION=""
SKIP_VERSION_PROMPT=0

while [ $# -gt 0 ]; do
  case "$1" in
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    --skip-version)
      SKIP_VERSION_PROMPT=1
      shift
      ;;
    *)
      echo "Neznamy parameter: $1" >&2
      exit 1
      ;;
  esac
done

get_current_version() {
  if [ -f "$ENV_PATH" ]; then
    grep -m1 '^RESIDO_CLIENT_VERSION=' "$ENV_PATH" | sed -E 's/^RESIDO_CLIENT_VERSION=//' || true
  fi
}

current_version="$(get_current_version)"
[ -n "$current_version" ] || current_version="(neznama)"

# 1. Ktoru verziu vydavame — spytaj sa, ak nebola daná parametrom.
if [ -z "$VERSION" ] && [ "$SKIP_VERSION_PROMPT" -eq 0 ]; then
  read -r -p "Aka verzia sa ma nastavit do .env? (aktualna: $current_version, Enter = bez zmeny) " answer
  if [ -n "$answer" ]; then
    VERSION="$answer"
  fi
fi

if [ -n "$VERSION" ]; then
  if [ -f "$ENV_PATH" ] && grep -q '^RESIDO_CLIENT_VERSION=' "$ENV_PATH"; then
    sed -i '' "s/^RESIDO_CLIENT_VERSION=.*/RESIDO_CLIENT_VERSION=$VERSION/" "$ENV_PATH"
  else
    echo "RESIDO_CLIENT_VERSION=$VERSION" >> "$ENV_PATH"
  fi
  export RESIDO_CLIENT_VERSION="$VERSION"
  echo "RESIDO_CLIENT_VERSION nastavena na $VERSION (ulozena do .env)"
else
  echo "Verzia sa nemeni, ostava $current_version."
fi

# 2. Generuj a zbuilduj.
echo "Generujem resido-client z resido.sh..."
"$SCRIPT_DIR/resido.sh"

CLIENT_ROOT="$SCRIPT_DIR/resido-client"
if [ ! -d "$CLIENT_ROOT" ]; then
  echo "resido-client nebol vytvoreny — skontroluj vystup resido.sh vyssie." >&2
  exit 1
fi

pushd "$CLIENT_ROOT" > /dev/null
echo "npm install..."
npm install
echo "npm run dist (buildim .dmg/.zip)..."
npm run dist
popd > /dev/null

DIST_DIR="$CLIENT_ROOT/dist"
artifacts=()
if [ -d "$DIST_DIR" ]; then
  while IFS= read -r -d '' f; do
    artifacts+=("$f")
  done < <(find "$DIST_DIR" -maxdepth 1 -type f \( -name '*.dmg' -o -name '*.zip' -o -name '*.blockmap' \) -print0)
fi

if [ ${#artifacts[@]} -eq 0 ]; then
  echo "V $DIST_DIR sa nenasli ziadne .dmg/.zip/.blockmap subory — build zrejme zlyhal." >&2
  exit 1
fi

echo ""
echo "Zbuildovane subory:"
for f in "${artifacts[@]}"; do
  echo "  - $(basename "$f")"
done

echo ""
echo "Hotovo. Auto-update host zatial nie je nastaveny — subory hore rozdaj/nainstaluj rucne."
