#!/usr/bin/env bash
# macOS counterpart of the Windows client's resido.ps1 — generates the
# resido-client Electron project, configured to package as a .dmg/.zip for
# macOS instead of an NSIS .exe for Windows.
#
# No auto-update support yet (no electron-updater, no publish/update-server
# config, no "Skontrolovat aktualizacie" button) — build.sh still uploads
# the built .dmg/.zip to residomac.vorntech.sk so there is one place to
# download the latest build from, but installed apps do not check for or
# apply updates on their own. Auto-update can be added later the same way
# the Windows client has it, once the app is signed with an Apple Developer
# ID certificate (Squirrel.Mac, which electron-updater uses on macOS,
# refuses to apply updates to an unsigned app).
# Re-exec in proper bash mode if invoked as `sh resido.sh` — on macOS /bin/sh
# IS bash, just started in restricted POSIX mode (BASH_VERSION is still set
# there, so that alone can't be used to detect it; POSIXLY_CORRECT is what
# actually flips on), which breaks this script's bash-only syntax (process
# substitution, arrays).
if [ -n "${POSIXLY_CORRECT:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read APP_NAME from .env (look two levels up from script = project root, then
# fall back to the script's own .env), same lookup order as resido.ps1.
# NOTE: the project root .env exists (Laravel's own .env) but does not
# contain APP_NAME/RESIDO_CLIENT_VERSION for this script's purposes in a
# way that matters here — keep checking later candidates until one of them
# actually contains the line, instead of stopping at the first .env that
# merely exists.
app_name="Resido"
for candidate in "$SCRIPT_DIR/../../.env" "$SCRIPT_DIR/.env"; do
  if [ -f "$candidate" ]; then
    line="$(grep -m1 '^APP_NAME=' "$candidate" || true)"
    if [ -n "$line" ]; then
      app_name="$(echo "$line" | sed -E "s/^APP_NAME=['\"]?([^'\"]+)['\"]?\$/\1/")"
      break
    fi
  fi
done
if [ -n "${APP_NAME:-}" ]; then
  app_name="$APP_NAME"
fi

# Read RESIDO_CLIENT_VERSION the same way, so a release bump is a one-line
# .env edit instead of hunting for the hardcoded literal in this script.
client_version="1.0.0"
for candidate in "$SCRIPT_DIR/../../.env" "$SCRIPT_DIR/.env"; do
  if [ -f "$candidate" ]; then
    line="$(grep -m1 '^RESIDO_CLIENT_VERSION=' "$candidate" || true)"
    if [ -n "$line" ]; then
      client_version="$(echo "$line" | sed -E "s/^RESIDO_CLIENT_VERSION=['\"]?([^'\"]+)['\"]?\$/\1/")"
      break
    fi
  fi
done
if [ -n "${RESIDO_CLIENT_VERSION:-}" ]; then
  client_version="$RESIDO_CLIENT_VERSION"
fi

app_slug="$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g')"

project_name="resido-client"
root="$(pwd)/$project_name"

mkdir -p "$root/src" "$root/assets"

# Copy pre-built icon from script assets
icon_src="$SCRIPT_DIR/assets/icon.icns"
icon_dst="$root/assets/icon.icns"
if [ -f "$icon_src" ]; then
  cp "$icon_src" "$icon_dst"
  echo "  ikona skopirovana: assets/icon.icns"
else
  echo "  VAROVANIE: icon.icns nenajdeny v $icon_src — vloz ho rucne do assets/" >&2
fi

cat > "$root/package.json" <<JSON
{
  "name": "resido-client",
  "version": "$client_version",
  "description": "$app_name desktop klient pre manazment",
  "main": "src/main.js",
  "author": "Resido",
  "license": "MIT",
  "scripts": {
    "start": "electron .",
    "dist": "CSC_IDENTITY_AUTO_DISCOVERY=false electron-builder --mac dmg zip"
  },
  "dependencies": {
    "electron-store": "^8.2.0"
  },
  "devDependencies": {
    "electron": "^37.2.0",
    "electron-builder": "26.15.0"
  },
  "build": {
    "appId": "sk.efabrica.resido",
    "productName": "$app_name",
    "asar": false,
    "icon": "assets/icon.icns",
    "directories": {
      "output": "dist"
    },
    "files": [
      "src/**/*",
      "assets/**/*",
      "package.json"
    ],
    "mac": {
      "target": ["dmg", "zip"],
      "icon": "assets/icon.icns",
      "category": "public.app-category.business",
      "hardenedRuntime": false,
      "gatekeeperAssess": false
    },
    "dmg": {
      "artifactName": "$app_slug-setup-\${version}.dmg"
    }
  }
}
JSON

# The client's actual source (main.js, preload.js, the settings/offline screen
# and README) lives in assets/ as plain files and is only COPIED here — the
# same layout as the Windows client's script/assets/, so print fixes can be
# ported between the two by diffing the files directly instead of digging
# them out of heredoc strings.
copy_asset() {
  local source="$SCRIPT_DIR/assets/$1"
  local destination="$root/$2"
  local replace_app_name="$3"

  if [ ! -f "$source" ]; then
    echo "Chyba subor assets/$1 v $SCRIPT_DIR - klient sa neda vygenerovat." >&2
    exit 1
  fi

  if [ "$replace_app_name" = "1" ]; then
    sed "s/APP_NAME_PLACEHOLDER/$app_name/g" "$source" > "$destination"
  else
    cp "$source" "$destination"
  fi

  echo "  skopirovane: $2"
}

copy_asset "main.js"      "src/main.js"      0
copy_asset "preload.js"   "src/preload.js"   0
copy_asset "offline.html" "src/offline.html" 1
copy_asset "README.md"    "README.md"        1

echo "Hotovo. Projekt $app_name bol vytvoreny v: $root"
