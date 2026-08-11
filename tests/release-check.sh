#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PLACEHOLDER_PATTERN='YOUR_GITHUB_USERNAME|YOUR_NAME|DEIN_GITHUB_USERNAME|DEIN NAME'

if grep -R --exclude-dir=.git --exclude='release-check.sh' -nE "$PLACEHOLDER_PATTERN" "$ROOT"; then
  echo '[FAIL] Release-Platzhalter vorhanden.' >&2
  exit 1
fi

bash "$ROOT/tools/verify-attribution.sh"
echo '[PASS] Keine Release-Platzhalter vorhanden.'
