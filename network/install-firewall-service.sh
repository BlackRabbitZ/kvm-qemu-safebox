#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

command -v nft >/dev/null || { echo "FEHLER: nftables ist nicht installiert." >&2; exit 1; }
command -v systemctl >/dev/null || { echo "FEHLER: systemd/systemctl wird benötigt." >&2; exit 1; }

install -d -m 0755 /etc/safebox
install -m 0644 "$SCRIPT_DIR/safebox-guard.nft" /etc/safebox/safebox-guard.nft
install -m 0644 "$SCRIPT_DIR/safebox-firewall.service" /etc/systemd/system/safebox-firewall.service
systemctl daemon-reload
systemctl enable --now safebox-firewall.service

echo "[OK] Persistenter SafeBox-Firewall-Service installiert und aktiv."
