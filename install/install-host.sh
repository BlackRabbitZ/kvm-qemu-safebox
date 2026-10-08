#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ${EUID} -ne 0 ]]; then exec sudo -- /usr/bin/bash "$0" "$@"; fi
command -v apt-get >/dev/null || { echo "Nur Debian/apt-basierte Hosts werden unterstützt." >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends qemu-system-x86 qemu-system-modules-spice qemu-utils libvirt-daemon-system libvirt-clients libvirt-daemon-driver-qemu libvirt-daemon-driver-network libvirt-daemon-driver-nwfilter libvirt-daemon-config-nwfilter virtinst virt-viewer libguestfs-tools dnsmasq-base nftables iproute2 iptables apparmor apparmor-utils ca-certificates curl gnupg gpgv debian-keyring jq libxml2-utils shellcheck python3 procps util-linux genisoimage cryptsetup findutils coreutils
systemctl enable --now apparmor.service
aa-status --enabled >/dev/null
if ! virsh -c qemu:///system capabilities >/dev/null 2>&1; then systemctl enable --now libvirtd.socket 2>/dev/null || systemctl enable --now libvirtd.service; fi
virsh -c qemu:///system capabilities >/dev/null
/usr/bin/bash "$ROOT/host/harden-libvirt.sh"
/usr/bin/bash "$ROOT/network/install-firewall-service.sh"
/usr/bin/bash "$ROOT/install/install-runtime-helpers.sh"
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]] && id -nG "$SUDO_USER" | tr ' ' '\n' | grep -Fxq libvirt; then
  echo "[WARN] $SUDO_USER ist bereits Mitglied der privilegierten libvirt-Gruppe." >&2
  echo "       Für maximale Host-Trennung auf einem dedizierten SafeBox-Host entfernen: sudo gpasswd -d $SUDO_USER libvirt" >&2
fi
echo "[OK] SafeBox Host-Abhängigkeiten und Härtung installiert; keine libvirt-Gruppenrechte wurden vergeben."
