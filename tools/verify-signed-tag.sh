#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '\n' <"$ROOT/VERSION")"; TAG=${1:-"v$VERSION"}
EXPECTED="${SAFEBOX_SIGNING_FINGERPRINT:-${RELEASE_SIGNER_FINGERPRINT:-}}"
command -v git >/dev/null || { echo 'FEHLER: git fehlt.' >&2; exit 1; }
[[ "$TAG" == "v$VERSION" ]] || { echo "FEHLER: Tag $TAG passt nicht zu VERSION=$VERSION" >&2; exit 1; }
[[ "$(git -C "$ROOT" cat-file -t "$TAG" 2>/dev/null || true)" == tag ]] || { echo "FEHLER: $TAG ist kein annotierter Tag." >&2; exit 1; }
[[ "$EXPECTED" =~ ^[A-Fa-f0-9]{40,64}$ ]] || { echo 'FEHLER: RELEASE_SIGNER_FINGERPRINT/SAFEBOX_SIGNING_FINGERPRINT muss auf den erlaubten Release-Key gesetzt sein.' >&2; exit 1; }
raw="$(git -C "$ROOT" verify-tag --raw "$TAG" 2>&1)" || { echo "FEHLER: Kryptografische Tag-Signatur konnte nicht verifiziert werden: $TAG" >&2; exit 1; }
normalized="${EXPECTED// /}"; normalized="${normalized^^}"
# Literal embedded program/test syntax: $ belongs to that program, not Bash.
# shellcheck disable=SC2016
actual="$(awk '/\[GNUPG:\] VALIDSIG /{print toupper($3); exit}' <<<"$raw")"
[[ -n "$actual" && "$actual" == "$normalized" ]] || { echo "FEHLER: Tag ist gültig signiert, aber vom falschen Key: ${actual:-unbekannt}" >&2; exit 1; }
echo "[PASS] $TAG ist kryptografisch mit dem erlaubten Fingerprint $actual verifiziert."
