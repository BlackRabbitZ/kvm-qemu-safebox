#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${EUID} -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl disable --now safebox-firewall.service 2>/dev/null || true
fi
if command -v nft >/dev/null 2>&1 && nft list table inet safebox_guard >/dev/null 2>&1; then
  nft delete table inet safebox_guard
fi
rm -f /etc/systemd/system/safebox-firewall.service \
      /etc/safebox/safebox-guard.nft \
      /usr/local/libexec/safebox/apply-firewall.sh
systemctl daemon-reload 2>/dev/null || true

echo "[OK] Persistenten SafeBox-Firewall-Service und Guard-Tabelle entfernt."
