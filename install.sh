#!/bin/sh
# Installs PRevue: downloads the latest release's DMG, checks it against the release's SHA256SUMS,
# and copies PRevue.app into /Applications.
#
# The source is octavehq/PRevue's scripts/install.sh; scripts/release.sh copies it to
# octavehq/prevue-releases (where the curl line below reads it) when it changes.
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
sums_url=$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*/SHA256SUMS"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')

dest="${PREVUE_INSTALL_DIR:-/Applications}"
[ -d "$dest" ] || mkdir -p "$dest"
if [ ! -w "$dest" ]; then dest="$HOME/Applications"; mkdir -p "$dest"; say "No write access to /Applications; installing into $dest."; fi

tmp=$(mktemp -d)
mnt=""
cleanup() { [ -n "$mnt" ] && hdiutil detach -quiet "$mnt" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT INT TERM

say "Downloading PRevue ${tag}..."
curl -fL --progress-bar -o "$tmp/PRevue.dmg" "$url" || fail "download failed."
# Releases made since scripts/release.sh started publishing SHA256SUMS: a DMG that doesn't match it is never installed.
# Older releases have none, so those install with a warning.
if [ -n "$sums_url" ]; then
  curl -fsSL -o "$tmp/SHA256SUMS" "$sums_url" || fail "couldn't download SHA256SUMS for ${tag}, so the DMG can't be checked. Nothing was installed."
  want=$(awk -v f="${url##*/}" '$2 == f || $2 == "*" f { print $1 }' "$tmp/SHA256SUMS" | head -1)
  [ -n "$want" ] || fail "SHA256SUMS for ${tag} doesn't list ${url##*/}. Nothing was installed."
  got=$(shasum -a 256 "$tmp/PRevue.dmg" | awk '{ print $1 }')
  [ "$got" = "$want" ] || fail "the downloaded DMG doesn't match its SHA256SUMS (got $got, expected $want). It may be damaged or tampered with; nothing was installed."
  say "Checked the DMG against SHA256SUMS."
else
  say "Warning: release ${tag} has no SHA256SUMS (it predates them), so the DMG isn't checked."
fi
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
