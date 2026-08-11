#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

command -v nft >/dev/null || { echo "FEHLER: nftables ist nicht installiert." >&2; exit 1; }

# Atomisch unsere eigene Tabelle ersetzen, ohne fremde Host-Regeln anzufassen.
if nft list table inet safebox_guard >/dev/null 2>&1; then
  nft delete table inet safebox_guard
fi
nft -f "$SCRIPT_DIR/safebox-guard.nft"

echo "[OK] nftables-Tabelle inet/safebox_guard aktiv."
