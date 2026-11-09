#!/bin/sh
# Installs PRevue: downloads the latest release's DMG and copies PRevue.app into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/octavehq/prevue-releases/main/install.sh | sh
#
# Downloaded with curl, the app isn't marked as "from the internet", so macOS opens it without
# the unsigned-app warning. Options (environment variables):
#   PREVUE_VERSION=v0.1.0      install that release instead of the latest
#   PREVUE_INSTALL_DIR=DIR     install into DIR instead of /Applications
#   PREVUE_NO_OPEN=1           don't open the app afterwards
set -eu

REPO="octavehq/prevue-releases"
say() { printf '%s\n' "$*"; }
fail() { printf 'PRevue install: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "PRevue is a macOS app."
[ "$(uname -m)" = "arm64" ] || fail "this build is for Apple Silicon Macs (M1 or later) only."

if [ -n "${PREVUE_VERSION:-}" ]; then api="https://api.github.com/repos/$REPO/releases/tags/$PREVUE_VERSION"
else api="https://api.github.com/repos/$REPO/releases/latest"; fi
json=$(curl -fsSL -H "Accept: application/vnd.github+json" "$api") || fail "couldn't reach GitHub ($api)."
url=$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*aarch64\.dmg"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
tag=$(printf '%s' "$json" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
[ -n "$url" ] || fail "no Apple Silicon DMG found in release ${tag:-?}."

dest="${PREVUE_INSTALL_DIR:-/Applications}"
[ -d "$dest" ] || mkdir -p "$dest"
if [ ! -w "$dest" ]; then dest="$HOME/Applications"; mkdir -p "$dest"; say "No write access to /Applications; installing into $dest."; fi

tmp=$(mktemp -d)
mnt=""
cleanup() { [ -n "$mnt" ] && hdiutil detach -quiet "$mnt" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT INT TERM

say "Downloading PRevue ${tag}..."
curl -fL --progress-bar -o "$tmp/PRevue.dmg" "$url" || fail "download failed."
mnt=$(hdiutil attach -nobrowse -readonly -noautoopen "$tmp/PRevue.dmg" 2>/dev/null | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)
[ -n "$mnt" ] && [ -d "$mnt/PRevue.app" ] || fail "couldn't open the DMG."

if pgrep -f "$dest/PRevue.app/Contents/MacOS/" >/dev/null 2>&1; then
  say "Quitting the running PRevue..."; osascript -e 'tell application "PRevue" to quit' >/dev/null 2>&1 || true; sleep 1
fi
rm -rf "$dest/PRevue.app"
cp -R "$mnt/PRevue.app" "$dest/" || fail "couldn't copy PRevue.app into $dest."
xattr -dr com.apple.quarantine "$dest/PRevue.app" 2>/dev/null || true

say "Installed PRevue ${tag} in $dest."
command -v gh >/dev/null 2>&1 || say "Next: install the GitHub CLI (brew install gh) and run: gh auth login"
[ -n "${PREVUE_NO_OPEN:-}" ] || open "$dest/PRevue.app"
