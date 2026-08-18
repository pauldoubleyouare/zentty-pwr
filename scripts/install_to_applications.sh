#!/usr/bin/env bash
# Install the Release build to /Applications/Zentty-PWR.app, signed with a
# stable local identity.
#
# Why the signing matters: macOS keys TCC permission grants (Desktop, Documents,
# Downloads, Full Disk Access, Accessibility) to the app's code signature. An
# ad-hoc signature has no stable identity, so every rebuild produces a new
# signature and macOS re-prompts for every permission. Signing with the same
# self-signed certificate each time keeps one identity across rebuilds, so the
# grants stick.
#
# One-time setup: create a self-signed code-signing certificate named
# "Zentty PWR Local" in Keychain Access (Certificate Assistant > Create a
# Certificate, Identity Type "Self Signed Root", Certificate Type "Code
# Signing"). Override the name with SIGN_IDENTITY if you use a different one.
#
# Pass an app bundle as $1 to sign that instead of the Release build, which is
# how an already-installed ad-hoc app gets adopted without a rebuild.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIGN_IDENTITY="${SIGN_IDENTITY:-Zentty PWR Local}"
DEST="/Applications/Zentty-PWR.app"
SRC="${1:-$ROOT/build/Build/Products/Release/Zentty.app}"
ENTITLEMENTS="$ROOT/Zentty/Zentty.entitlements"

[ -d "$SRC" ] || { echo "no app bundle at $SRC, run xcodebuild first" >&2; exit 1; }

if ! security find-identity -p codesigning | grep -qF "$SIGN_IDENTITY"; then
  echo "code-signing identity \"$SIGN_IDENTITY\" not found." >&2
  echo "Create it in Keychain Access (see the header of this script), or set SIGN_IDENTITY." >&2
  exit 1
fi

TMP="$(mktemp -d)"
STAGE="$TMP/Zentty-PWR.app"
trap 'rm -rf "$TMP"' EXIT

# Sign a staged copy so a running app is never modified in place.
# No hardened runtime: these builds are not notarized, and enabling it on a
# build that was not compiled for it can block launch.
cp -R "$SRC" "$STAGE"
codesign --force --deep --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" "$STAGE"
codesign --verify --deep --strict "$STAGE"

if [ -d "$DEST" ]; then
  rm -rf "$DEST.previous"
  mv "$DEST" "$DEST.previous"
fi
cp -R "$STAGE" "$DEST"

echo "installed $DEST"
codesign -dv "$DEST" 2>&1 | grep -E 'Identifier|Authority|Signature'
echo
echo "Quit and relaunch Zentty. Approve each permission prompt once; they persist from now on."
