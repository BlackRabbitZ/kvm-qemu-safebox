#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
fail(){ echo "[FAIL] AUDIT: $*" >&2; exit 1; }
pass(){ echo "[PASS] AUDIT: $*"; }

# Both REAL project XML templates, no weakened policy, with production value set.
python3 - "$ROOT" "$T" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); out=Path(sys.argv[2])
vals={'__DOMAIN_NAME__':'safebox-disposable-test', '__RAM_MIB__':'6144', '__VCPUS__':'4',
 '__MEM_HARD_MIB__':'8192', '__IOTHREADS__':'1', '__CPU_PERIOD_US__':'100000',
 '__CPU_GLOBAL_QUOTA_US__':'280000', '__DISK_TOTAL_BYTES_SEC__':'134217728',
 '__DISK_TOTAL_IOPS_SEC__':'12000', '__DISK_IMAGE__':'/tmp/test.qcow2',
 '__ISO_IMAGE__':'/tmp/test.iso','__NET_BACKEND__':'qemu',
 }
for name in ('installer','offline','malware','runtime'):
    source='installer' if name=='installer' else 'runtime'
    xml=(root/'vm/templates'/f'{source}.xml.in').read_text()
    for k,v in vals.items(): xml=xml.replace(k,v)
    if name=='runtime':
        net="<interface type='network'><mac address='52:54:00:77:00:10'/><source network='safebox-net'/><model type='e1000e'/><rom bar='off'/><port isolated='yes'/><filterref filter='safebox-runtime-filter'><parameter name='IP' value='10.77.0.100'/><parameter name='CTRL_IP_LEARNING' value='none'/></filterref></interface>"
        xml=xml.replace('__NETWORK_BLOCK__',net)
    else:
        xml=xml.replace('__NETWORK_BLOCK__','')
    if name!='malware':
        xml=xml.replace('__SAMPLE_BLOCK__','')
    if name=='malware':
        sample="<disk type='file' device='cdrom'><driver name='qemu' type='raw'/><source file='/tmp/sample.iso'/><target dev='sdb' bus='sata'/><readonly/></disk>"
        xml=xml.replace('__SAMPLE_BLOCK__',sample)
    assert '__' not in xml
    (out/f'{name}.xml').write_text(xml)
PY
export SAFEBOX_RAM_MIB=6144 SAFEBOX_VCPUS=4 SAFEBOX_MEM_HARD_MIB=8192 SAFEBOX_IOTHREADS=1
export SAFEBOX_CPU_PERIOD_US=100000 SAFEBOX_CPU_MAX_PERCENT=70 SAFEBOX_DISK_TOTAL_BYTES_SEC=134217728
export SAFEBOX_DISK_TOTAL_IOPS_SEC=12000 SAFEBOX_NET_BACKEND=qemu SAFEBOX_NET_MODEL=e1000e
export SAFEBOX_NETWORK=safebox-net SAFEBOX_INSTALL_NETWORK_NAME=safebox-install-net
export SAFEBOX_INSTALL_NWFILTER=safebox-install-filter SAFEBOX_NWFILTER=safebox-runtime-filter
export SAFEBOX_GUEST_IP=10.77.0.100 SAFEBOX_MAC=52:54:00:77:00:10
for mode in installer offline malware; do
  iso=''; [[ "$mode" != malware ]] || iso=/tmp/sample.iso
  python3 "$ROOT/tools/xml-policy-check.py" "$T/$mode.xml" "$mode" /tmp/test.qcow2 "$iso" >/dev/null || fail "$mode unverändertes Template abgelehnt"
done
if python3 "$ROOT/tools/xml-policy-check.py" "$T/runtime.xml" disposable /tmp/test.qcow2 >/dev/null 2>&1; then
  fail 'Vernetzte Runtime vom XML-Validator akzeptiert'
fi
python3 - "$T/installer.xml" <<'PY'
import sys,xml.etree.ElementTree as ET
p=sys.argv[1]
r=ET.parse(p); e=r.find('.//filterref'); e.set('filter','safebox-runtime-filter'); r.write(p)
PY
if python3 "$ROOT/tools/xml-policy-check.py" "$T/installer.xml" installer /tmp/test.qcow2 >/dev/null 2>&1; then
  fail 'Installer-NIC mit falschem Filter zugelassen'
fi
pass 'Installer-/Offline-/Malware-Produktions-XML; Vernetzung in Runtime abgelehnt'

cat >"$T/nw-a.xml" <<'EOF'
<filter name='foo'><rule direction='out' action='drop' priority='10'><ip srcipaddr='10.0.0.1'/></rule></filter>
EOF
cat >"$T/nw-b.xml" <<'EOF'
<filter name="foo">
   <uuid>f0000000-0000-0000-0000-000000000000</uuid>
   <rule priority="10" action="drop" direction="out">
      <ip srcipaddr="10.0.0.1"></ip>
   </rule>
</filter>
EOF
[[ "$(python3 "$ROOT/tools/nwfilter-canon.py" <"$T/nw-a.xml")" == "$(python3 "$ROOT/tools/nwfilter-canon.py" <"$T/nw-b.xml")" ]] || fail 'nwfilter-Normalisierung ist nicht whitespace-/attributstabil'
sed 's/action="drop"/action="accept"/' "$T/nw-b.xml" >"$T/nw-c.xml"
[[ "$(python3 "$ROOT/tools/nwfilter-canon.py" <"$T/nw-a.xml")" != "$(python3 "$ROOT/tools/nwfilter-canon.py" <"$T/nw-c.xml")" ]] || fail 'nwfilter-Regeländerung wurde verschluckt'
pass 'nwfilter-Whitespace stabil, echte Regelmanipulation erkannt'

cat >"$T/host.conf" <<'EOF'
# security_driver = "suspicious"
security_driver = "apparmor"
security_default_confined = 1
security_require_confined = 1
seccomp_sandbox = 1
max_core = 0
dump_guest_core = 0
namespaces = [ "mount" ]
EOF
python3 "$ROOT/tools/check-host-qemu-config.py" "$T/host.conf" >/dev/null || fail 'Korrekte aktive qemu.conf nicht akzeptiert'
printf '\nsecurity_driver = "none"\n' >> "$T/host.conf"
if python3 "$ROOT/tools/check-host-qemu-config.py" "$T/host.conf" >/dev/null 2>&1; then fail 'Doppelter aktiver QEMU-Key nicht abgelehnt'; fi
pass 'Aktive QEMU-Einstellungen erkannt; Kommentare und doppelte Schlüssel sicher abgelehnt'

cat >"$T/routes.txt" <<'EOF'
default via 198.51.100.1 dev eth0 table 100
10.77.0.0/24 dev virbr-safebox proto kernel scope link src 10.77.0.1
local 10.77.0.1 dev lo table local proto kernel scope host src 10.77.0.1
192.168.99.0/24 dev wg0 table 200 proto static
192.168.99.5 dev wg0 table 200 proto static
broadcast 192.168.99.255 dev wg0 table local proto kernel scope link src 192.168.99.1
EOF
python3 "$ROOT/tools/local-routes.py" <"$T/routes.txt" >"$T/routelist"
grep -Fxq '192.168.99.0/24' "$T/routelist" || fail 'Policy-Routing-Präfix fehlt'
if grep -q '0.0.0.0/0' "$T/routelist"; then
  fail 'Internet-Default-Route versehentlich gesperrt'
fi
pass 'VPN/Policy-Tables und überlappende lokale Routen sauber zusammengeführt'

mkdir "$T/bin" "$T/libexec" "$T/run"
cat > "$T/bin/virsh" <<'EOF'
#!/usr/bin/env bash
if [[ "${MOCK_LIBVIRT_DOWN:-0}" == 1 ]]; then exit 1; fi
if [[ " $* " == *' list '* ]]; then exit 0; fi
exit 1
EOF
cat > "$T/libexec/domain-pid.sh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat > "$T/libexec/proc-absence.py" <<'PY'
#!/usr/bin/env python3
import os,sys
sys.exit(int(os.environ.get('MOCK_PROC_PRESENT','0')))
PY
chmod +x "$T/bin/virsh" "$T/libexec/domain-pid.sh" "$T/libexec/proc-absence.py"
cat > "$T/kill.conf" <<EOF
SAFEBOX_CONNECT_URI=qemu:///system
SAFEBOX_LIBEXEC="$T/libexec"
SAFEBOX_RUNTIME_DIR="$T/run"
EOF
set +e
PATH="$T/bin:$PATH" MOCK_LIBVIRT_DOWN=1 SAFEBOX_CONFIG_FILE="$T/kill.conf" bash "$ROOT/tools/kill-domain.sh" safebox-disposable-test >/dev/null 2>&1; result_down=$?
PATH="$T/bin:$PATH" MOCK_LIBVIRT_DOWN=0 MOCK_PROC_PRESENT=1 SAFEBOX_CONFIG_FILE="$T/kill.conf" bash "$ROOT/tools/kill-domain.sh" safebox-disposable-test >/dev/null 2>&1; result_orphan=$?
PATH="$T/bin:$PATH" MOCK_LIBVIRT_DOWN=0 MOCK_PROC_PRESENT=0 SAFEBOX_CONFIG_FILE="$T/kill.conf" bash "$ROOT/tools/kill-domain.sh" safebox-disposable-test >/dev/null 2>&1; result_clean=$?
set -e
[[ $result_down -ne 0 && $result_orphan -ne 0 && $result_clean -eq 0 ]] || fail "Kill-Service liefert falschen Status: libvirt-down=$result_down orphan=$result_orphan clean=$result_clean"
pass 'Kill-Service: unbekannter libvirt-Zustand != Erfolg; verwaistes QEMU != Erfolg'

# Supply-chain verifier refuses unsigned artefacts even when the SHA list matches.
if SAFEBOX_SIGNING_FINGERPRINT='' bash "$ROOT/tools/verify-release.sh" "$T" >/dev/null 2>&1; then fail 'Unsigned Release akzeptiert'; fi
pass 'Unsigned Release wird nicht als authentifiziert ausgegeben'

echo '[PASS] Neue Regressionen aus dem Sicherheits-Audit vollständig bestanden.'
