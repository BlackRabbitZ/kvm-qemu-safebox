#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

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
  libvirt-daemon-driver-qemu libvirt-daemon-driver-network \
  libvirt-daemon-driver-nwfilter libvirt-daemon-config-nwfilter \
  virtinst virt-viewer \
  dnsmasq-base nftables ebtables iptables \
  apparmor apparmor-utils \
  ca-certificates curl jq \
  libxml2-utils shellcheck python3 procps

# Sicherheitskritische Dienste werden nicht mit "|| true" verschluckt.
systemctl enable --now apparmor.service

aa-status --enabled >/dev/null 2>&1 || {
  echo "FEHLER: AppArmor konnte nicht aktiviert werden." >&2
  exit 1
}

# Debian richtet beim Paketinstallieren die passende libvirt-Daemon-Variante
# ein. Wir starten nicht gleichzeitig monolithische und modulare Sockets.
# Nur falls qemu:///system noch nicht erreichbar ist, aktivieren wir die
# klassische libvirtd-Schnittstelle als gezielten Fallback.
if ! virsh -c qemu:///system capabilities >/dev/null 2>&1; then
  if systemctl list-unit-files libvirtd.socket >/dev/null 2>&1; then
    systemctl enable --now libvirtd.socket
  elif systemctl list-unit-files libvirtd.service >/dev/null 2>&1; then
    systemctl enable --now libvirtd.service
  else
    echo "FEHLER: Keine nutzbare libvirt-Systeminstanz gefunden." >&2
    exit 1
  fi
fi
virsh -c qemu:///system capabilities >/dev/null

# Kein automatisches Hinzufügen des Desktop-Benutzers zu libvirt/kvm: SafeBox
# verwendet sudo für Managementoperationen und vermeidet damit unnötige,
# dauerhafte Hypervisor-Rechte für das normale Benutzerkonto.

bash "$ROOT/host/harden-libvirt.sh"
bash "$ROOT/network/install-firewall-service.sh"

echo "[OK] Host-Abhängigkeiten installiert und SafeBox-Sicherheitsprofil aktiviert."
echo "[INFO] Normale Benutzer wurden absichtlich NICHT zu libvirt/kvm hinzugefügt."
