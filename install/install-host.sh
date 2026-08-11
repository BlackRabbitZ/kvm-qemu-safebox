#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "FEHLER: Dieses Installationsskript unterstützt aktuell Debian/apt-basierte Hosts." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  qemu-system-x86 qemu-utils \
  libvirt-daemon-system libvirt-clients \
  virtinst virt-viewer \
  dnsmasq-base nftables \
  apparmor apparmor-utils \
  ca-certificates curl jq \
  libxml2-utils shellcheck

# Klassischer libvirtd-Kompatibilitätsdienst ist auf Debian weiterhin eine
# robuste Schnittstelle. Falls nur socket activation vorhanden ist, wird
# entsprechend auf den Socket zurückgefallen.
if systemctl list-unit-files libvirtd.service >/dev/null 2>&1; then
  systemctl enable --now libvirtd.service || true
fi
if systemctl list-unit-files libvirtd.socket >/dev/null 2>&1; then
  systemctl enable --now libvirtd.socket || true
fi
systemctl enable --now nftables.service || true
systemctl enable --now apparmor.service || true

TARGET_USER="${SUDO_USER:-}"
if [[ -n "$TARGET_USER" && "$TARGET_USER" != "root" ]]; then
  if getent group libvirt >/dev/null; then
    usermod -aG libvirt "$TARGET_USER"
  fi
  if getent group kvm >/dev/null; then
    usermod -aG kvm "$TARGET_USER"
  fi
  echo "[INFO] $TARGET_USER wurde – falls vorhanden – den Gruppen libvirt und kvm hinzugefügt."
  echo "[INFO] Danach einmal ab- und wieder anmelden, damit neue Gruppen gelten."
fi

echo "[OK] Host-Abhängigkeiten installiert."
