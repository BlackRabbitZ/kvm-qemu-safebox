#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PH_GITHUB='YOUR_''GITHUB_USERNAME'
PH_NAME='YOUR_''NAME'

if grep -R --exclude-dir=.git -nE "${PH_GITHUB}|${PH_NAME}" "$ROOT"; then
  echo "[FAIL] Release-Platzhalter vorhanden. Zuerst ./tools/configure-project.sh ausführen." >&2
  exit 1
fi

echo "[PASS] Keine Release-Platzhalter vorhanden."
