#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

if [[ ! -f /etc/debian_version ]]; then
  echo "FEHLER: Gast-Härtung ist für Debian vorgesehen." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  apparmor apparmor-utils nftables unattended-upgrades ca-certificates

# Bewusst keine Host/Gast-Komfortagenten in der gehärteten VM.
apt-get purge -y qemu-guest-agent spice-vdagent 2>/dev/null || true

install -m 0644 "$SCRIPT_DIR/nftables.conf" /etc/nftables.conf
install -m 0644 "$SCRIPT_DIR/99-safebox-hardening.conf" /etc/sysctl.d/99-safebox-hardening.conf

systemctl enable --now apparmor.service || true
systemctl enable --now nftables.service

# Dienste, die eine Desktop-Sandbox normalerweise nicht nach außen anbieten soll.
for unit in ssh.service ssh.socket avahi-daemon.service avahi-daemon.socket cups.service cups.socket; do
  if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
    systemctl disable --now "$unit" 2>/dev/null || true
  fi
done

# Security-Upgrades aktivieren. Debian-Paket erzeugt die Standardkonfiguration.
dpkg-reconfigure -f noninteractive unattended-upgrades || true
sysctl --system >/dev/null

echo "[OK] Gast-Härtung angewendet."
echo "[INFO] Neustart des Debian-Gasts empfohlen."
