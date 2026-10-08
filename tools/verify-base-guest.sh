#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/config/defaults.conf"
SUDO=(); [[ ${EUID} -eq 0 ]] || SUDO=(sudo)
img="${1:-$SAFEBOX_BASE_IMAGE}"
command -v virt-cat >/dev/null || { echo "FEHLER: virt-cat/libguestfs-tools fehlt." >&2; exit 1; }

marker="$("${SUDO[@]}" virt-cat -a "$img" -i /etc/safebox/hardened 2>/dev/null)" || { echo "FEHLER: /etc/safebox/hardened fehlt. guest/harden.sh zuerst ausführen." >&2; exit 1; }
for kv in "version=$SAFEBOX_VERSION" 'network=static' 'ipv4=10.77.0.100/24' 'gateway=10.77.0.1' 'ipv6=disabled' 'apparmor=enabled' 'nftables=enabled' 'qemu_guest_agent=absent' 'spice_vdagent=absent' 'ssh_server=absent'; do
  grep -Fxq "$kv" <<<"$marker" || { echo "FEHLER: Härtungsmarker unvollständig: $kv" >&2; exit 1; }
done

"${SUDO[@]}" virt-cat -a "$img" -i /etc/nftables.conf 2>/dev/null | grep -Fq 'table inet safebox_guest' || { echo 'FEHLER: Gast-nftables nicht bestätigt.' >&2; exit 1; }
"${SUDO[@]}" virt-cat -a "$img" -i /etc/sysctl.d/99-safebox-hardening.conf 2>/dev/null | grep -Fq 'kernel.kptr_restrict = 2' || { echo 'FEHLER: Gast-sysctl-Härtung nicht bestätigt.' >&2; exit 1; }

# Do not trust the marker alone: verify the real offline dpkg database.
status_tmp="$(mktemp)"; trap 'rm -f -- "$status_tmp"' EXIT
"${SUDO[@]}" virt-cat -a "$img" -i /var/lib/dpkg/status >"$status_tmp" 2>/dev/null || { echo 'FEHLER: DPKG-Status im Gast nicht lesbar.' >&2; exit 1; }
python3 - "$status_tmp" <<'PY'
import sys
text=open(sys.argv[1],encoding='utf-8',errors='replace').read()
pkgs={}
for block in text.split('\n\n'):
    fields={}
    for line in block.splitlines():
        if ': ' in line:
            k,v=line.split(': ',1); fields[k]=v
    if fields.get('Package'):
        pkgs[fields['Package']]=fields.get('Status','')
forbidden=['qemu-guest-agent','spice-vdagent','openssh-server','avahi-daemon','cups-daemon']
required=['apparmor','nftables','network-manager']
for p in forbidden:
    if pkgs.get(p)=='install ok installed':
        raise SystemExit(f'FEHLER: Verbotenes Gast-Paket ist installiert: {p}')
for p in required:
    if pkgs.get(p)!='install ok installed':
        raise SystemExit(f'FEHLER: Erforderliches Gast-Paket fehlt: {p}')
PY

echo '[PASS] Offline-Gast-Härtung und reale Paketzustände im Basisimage bestätigt.'
