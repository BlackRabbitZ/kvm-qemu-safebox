#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
if [[ ${EUID} -ne 0 ]]; then exec sudo -- /usr/bin/bash "$0" "$@"; fi
conf=/etc/libvirt/qemu.conf
[[ -f "$conf" ]] || { echo "FEHLER: $conf fehlt" >&2; exit 1; }
cp -a "$conf" "$conf.safebox.bak.$(date +%Y%m%d%H%M%S)"
python3 - "$conf" <<'PYSCRIPT'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text()
settings={'security_driver':'"apparmor"','security_default_confined':'1','security_require_confined':'1','seccomp_sandbox':'1','max_core':'0','dump_guest_core':'0','namespaces':'[ "mount" ]'}
for k,v in settings.items():
    pat=re.compile(rf'^\s*#?\s*{re.escape(k)}\s*=.*$')
    output=[]
    seen=False
    for raw in s.splitlines():
        if pat.match(raw):
            if not seen:
                output.append(f'{k} = {v}')
                seen=True
            # Delete later duplicates, including commented default examples.
        else:
            output.append(raw)
    if not seen:
        output.append(f'{k} = {v}')
    s='\n'.join(output)+'\n'
p.write_text(s)
PYSCRIPT

# SafeBox benötigt ausschließlich lokale libvirt-Unix-Sockets. Remote-TCP/TLS
# wird auf Hosts, die diese systemd-Socket-Units anbieten, explizit deaktiviert.
for unit in libvirtd-tcp.socket libvirtd-tls.socket virtproxyd-tcp.socket virtproxyd-tls.socket; do
  if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "^$unit"; then
    systemctl disable --now "$unit" >/dev/null 2>&1 || true
  fi
done

systemctl restart virtqemud.service 2>/dev/null || systemctl restart libvirtd.service
if ss -lnt 2>/dev/null | grep -Eq ':(16509|16514)[[:space:]]'; then
  echo 'FEHLER: libvirt TCP/TLS Management-Port lauscht weiterhin.' >&2
  exit 1
fi
