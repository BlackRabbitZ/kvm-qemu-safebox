#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

command -v nft >/dev/null || { echo "FEHLER: nftables ist nicht installiert." >&2; exit 1; }
command -v systemctl >/dev/null || { echo "FEHLER: systemd/systemctl wird benötigt." >&2; exit 1; }

install -d -m 0755 /etc/safebox /usr/local/libexec/safebox
install -m 0644 "$SCRIPT_DIR/safebox-guard.nft" /etc/safebox/safebox-guard.nft
install -m 0755 "$SCRIPT_DIR/apply-firewall.sh" /usr/local/libexec/safebox/apply-firewall.sh
install -m 0644 "$SCRIPT_DIR/safebox-firewall.service" /etc/systemd/system/safebox-firewall.service
systemctl daemon-reload
systemctl enable safebox-firewall.service >/dev/null
if systemctl is-active --quiet safebox-firewall.service; then
  systemctl reload safebox-firewall.service
else
  systemctl start safebox-firewall.service
fi
systemctl is-active --quiet safebox-firewall.service || {
  echo "FEHLER: safebox-firewall.service ist nicht aktiv." >&2
  exit 1
}

echo "[OK] Persistenter SafeBox-Firewall-Service installiert, aktiv und verifiziert."
