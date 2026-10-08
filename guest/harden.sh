#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ${EUID} -ne 0 ]]; then exec sudo -- /usr/bin/bash "$0" "$@"; fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends apparmor apparmor-utils nftables unattended-upgrades network-manager ca-certificates
apt-get purge -y qemu-guest-agent spice-vdagent openssh-server avahi-daemon cups-daemon
systemctl enable --now apparmor.service nftables.service unattended-upgrades.service NetworkManager.service
for svc in ssh.service ssh.socket avahi-daemon.service avahi-daemon.socket cups.service cups.socket; do systemctl disable --now "$svc" 2>/dev/null || true; done
for pkg in qemu-guest-agent spice-vdagent openssh-server avahi-daemon cups-daemon; do
  # Literal embedded program/test syntax: $ belongs to that program, not Bash.
  # shellcheck disable=SC2016
  if dpkg-query -W -f='${db:Status-Abbrev}' "$pkg" 2>/dev/null | grep -q '^ii '; then
    echo "FEHLER: Verbotenes Gast-Paket ist noch installiert: $pkg" >&2
    exit 1
  fi
done
for pkg in apparmor nftables network-manager; do
  # Literal embedded program/test syntax: $ belongs to that program, not Bash.
  # shellcheck disable=SC2016
  dpkg-query -W -f='${db:Status-Abbrev}' "$pkg" 2>/dev/null | grep -q '^ii ' || { echo "FEHLER: Pflichtpaket fehlt: $pkg" >&2; exit 1; }
done
install -m 0644 "$ROOT/guest/nftables.conf" /etc/nftables.conf
install -m 0644 "$ROOT/guest/99-safebox-hardening.conf" /etc/sysctl.d/99-safebox-hardening.conf
sysctl --system >/dev/null
nft -f /etc/nftables.conf
iface="$(find /sys/class/net -mindepth 1 -maxdepth 1 -printf '%f\n' | grep -v '^lo$' | head -n1)"
[[ -n "$iface" ]] || { echo "FEHLER: Kein Gast-Netzwerkinterface gefunden." >&2; exit 1; }
if nmcli -t -f NAME con show | grep -Fxq safebox-static; then
  nmcli con delete safebox-static >/dev/null
fi
while IFS='' read -r con; do
  [[ -z "$con" ]] && continue
  nmcli con modify "$con" connection.autoconnect no 2>/dev/null || true
done < <(nmcli -t -f NAME,DEVICE con show | awk -F: -v dev="$iface" '$2==dev {print $1}')
nmcli con add type ethernet ifname "$iface" con-name safebox-static connection.autoconnect yes connection.autoconnect-priority 100 ipv4.method manual ipv4.addresses 10.77.0.100/24 ipv4.gateway 10.77.0.1 ipv4.dns "1.1.1.1,9.9.9.9" ipv4.ignore-auto-dns yes ipv6.method disabled >/dev/null
nmcli con up safebox-static >/dev/null
install -d -m 0755 /etc/safebox
cat >/etc/safebox/hardened <<EOF
version=0.5.1-rc5
network=static
ipv4=10.77.0.100/24
gateway=10.77.0.1
ipv6=disabled
apparmor=enabled
nftables=enabled
qemu_guest_agent=absent
spice_vdagent=absent
ssh_server=absent
EOF
chmod 0644 /etc/safebox/hardened
echo '[OK] Gast-Härtung installiert. Jetzt neu starten und danach herunterfahren.'
