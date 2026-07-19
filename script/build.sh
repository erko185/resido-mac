#!/usr/bin/env bash
# macOS counterpart of windows_app_script/script/build.ps1 — asks which
# version to release, generates resido-client from resido.sh, installs its
# dependencies, packages the .dmg/.zip and uploads them to the distribution
# host over SFTP, mirroring build.ps1's upload to residowindows.vorntech.sk.
#
# No auto-update here (see resido.sh) — this is a plain distribution host,
# not an update server. Installed apps do not check residomac.vorntech.sk on
# their own; this upload just gives you one place to grab the latest build.
#
# Usage:
#   ./build.sh                  # asks interactively for version + SFTP login
#   ./build.sh -v 3.5.1         # sets the version non-interactively
#   ./build.sh --skip-version   # keeps the current .env version, no prompt
#   ./build.sh --skip-upload    # build only, don't touch residomac.vorntech.sk

# Re-exec in proper bash mode if invoked as `sh build.sh` — on macOS /bin/sh
# IS bash, just started in restricted POSIX mode (BASH_VERSION is still set
# there, so that alone can't be used to detect it; POSIXLY_CORRECT is what
# actually flips on), which breaks this script's bash-only syntax (process
# substitution, arrays).
if [ -n "${POSIXLY_CORRECT:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Guard against a second concurrent run: the clean-rebuild step below does
# `rm -rf resido-client`, so if this script is started twice (e.g. it looked
# stuck during the ~1-2 minute .zip compression and got re-run), the second
# run deletes the first run's in-progress dist/ files out from under it —
# electron-builder then fails with a confusing ENOENT on the .zip/.dmg it
# was still writing. Fail fast instead with a clear message.
LOCK_DIR="$SCRIPT_DIR/.build.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Iny beh build.sh uz prebieha (existuje $LOCK_DIR)." >&2
  echo "Ak si si isty, ze ziadny build v skutocnosti nebezi (napr. po predchadzajucom zlyhani/Ctrl+C), zmaz $LOCK_DIR rucne a skus znova." >&2
  exit 1
fi

sftp_batch_file=""
cleanup() {
  [ -n "$sftp_batch_file" ] && rm -f "$sftp_batch_file"
  rmdir "$LOCK_DIR" 2>/dev/null
}
trap cleanup EXIT

FTP_HOST="residomac.vorntech.sk"
FTP_HOST_FALLBACK="37.9.175.196"
FTP_PORT=22
# SFTP account username == the hostname on this server; only the password is
# asked for (interactively, by ssh/sftp itself — never stored anywhere here).
ENV_PATH="$SCRIPT_DIR/.env"

VERSION=""
SKIP_VERSION_PROMPT=0
SKIP_UPLOAD=0

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
    --skip-upload)
      SKIP_UPLOAD=1
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

# 2. Cisty build — zmaz stary resido-client (stare node_modules aj stare
# subory v dist by inak zostali a skoncili by v zozname vyssie).
CLIENT_ROOT="$SCRIPT_DIR/resido-client"
if [ -d "$CLIENT_ROOT" ]; then
  echo "Mazem stary resido-client..."
  rm -rf "$CLIENT_ROOT"
fi

echo "Generujem resido-client z resido.sh..."
"$SCRIPT_DIR/resido.sh"

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

# 3. Nahraj vsetko na distribucny host cez SFTP (port 22 = SSH/SFTP).
if [ "$SKIP_UPLOAD" -eq 1 ]; then
  echo ""
  echo "--skip-upload zadany, subory hore nahraj rucne na https://$FTP_HOST/"
  exit 0
fi

echo ""
echo "Nahravam na $FTP_HOST (SFTP, port $FTP_PORT)..."
sftp_user="$FTP_HOST"

sftp_batch_file="$(mktemp)"
for f in "${artifacts[@]}"; do
  printf 'put %q\n' "$f" >> "$sftp_batch_file"
done
echo "bye" >> "$sftp_batch_file"

# NOTE: deliberately NOT using sftp's `-b batchfile` flag here — per
# `man sftp`, batch mode "lacks user interaction" and per `man ssh_config`
# BatchMode disables password prompts entirely (auth would just silently
# fail/hang, no password prompt ever shown). Feeding the put/bye commands via
# stdin redirection instead keeps interactive password auth working — the
# same trust-on-first-use behaviour as build.ps1's -AcceptKey for host keys.
if ! sftp -oPort="$FTP_PORT" -oStrictHostKeyChecking=accept-new "$sftp_user@$FTP_HOST" < "$sftp_batch_file"; then
  echo "Pripojenie na $FTP_HOST zlyhalo, skusam IP fallback $FTP_HOST_FALLBACK..." >&2
  sftp -oPort="$FTP_PORT" -oStrictHostKeyChecking=accept-new "$sftp_user@$FTP_HOST_FALLBACK" < "$sftp_batch_file"
fi

echo ""
echo "Hotovo. Vsetky subory su nahrate na $FTP_HOST."
