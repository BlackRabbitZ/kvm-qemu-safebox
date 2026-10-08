#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
BASE="$T/base.xml"

# Referenzdomain exakt so rendern, wie das hardened-Profil sie erzeugt.
set -a
# shellcheck source=/dev/null
source "$ROOT/config/defaults.conf"
# shellcheck source=/dev/null
source "$ROOT/profiles/hardened.conf"
set +a
export SAFEBOX_NETWORK SAFEBOX_INSTALL_NETWORK_NAME SAFEBOX_MAC SAFEBOX_GUEST_IP SAFEBOX_NWFILTER SAFEBOX_NET_BACKEND SAFEBOX_NET_MODEL SAFEBOX_DISK_BUS SAFEBOX_DISK_TARGET

python3 - "$ROOT" "$BASE" <<'PY'
from pathlib import Path
import os,sys
root=Path(sys.argv[1]); out=Path(sys.argv[2])
s=(root/'vm/templates/runtime.xml.in').read_text()
quota=int(os.environ['SAFEBOX_VCPUS'])*int(os.environ['SAFEBOX_CPU_PERIOD_US'])*int(os.environ['SAFEBOX_CPU_MAX_PERCENT'])//100
repl={
'__DOMAIN_NAME__':'safebox-disposable-test','__RAM_MIB__':os.environ['SAFEBOX_RAM_MIB'],'__VCPUS__':os.environ['SAFEBOX_VCPUS'],
'__MEM_HARD_MIB__':os.environ['SAFEBOX_MEM_HARD_MIB'],'__IOTHREADS__':os.environ['SAFEBOX_IOTHREADS'],
'__CPU_PERIOD_US__':os.environ['SAFEBOX_CPU_PERIOD_US'],'__CPU_GLOBAL_QUOTA_US__':str(quota),
'__DISK_TOTAL_BYTES_SEC__':os.environ['SAFEBOX_DISK_TOTAL_BYTES_SEC'],'__DISK_TOTAL_IOPS_SEC__':os.environ['SAFEBOX_DISK_TOTAL_IOPS_SEC'],
'__DISK_IMAGE__':'/tmp/test.qcow2','__NETWORK_BLOCK__':'','__SAMPLE_BLOCK__':'','__NET_BACKEND__':os.environ['SAFEBOX_NET_BACKEND']}
for k,v in repl.items(): s=s.replace(k,v)
if '__' in s: raise SystemExit('Unersetzter Platzhalter')
out.write_text(s)
PY

verify(){ python3 "$ROOT/tools/xml-policy-check.py" "$1" offline /tmp/test.qcow2 >/dev/null 2>&1; }
verify "$BASE" || { echo '[FAIL] Referenz-XML wird abgelehnt.' >&2; exit 1; }
echo '[PASS] Referenz-XML wird akzeptiert.'

mutate(){
  local name=$1 code=$2 out
  out="$T/$name.xml"
  python3 - "$BASE" "$out" "$code" <<'PY'
import sys,xml.etree.ElementTree as ET
src,out,code=sys.argv[1:]
t=ET.parse(src); r=t.getroot(); d=r.find('devices')
if code=='clipboard': r.find('./devices/graphics/clipboard').set('copypaste','yes')
elif code=='channel': ET.SubElement(d,'channel',{'type':'unix'})
elif code=='hostdev': ET.SubElement(d,'hostdev',{'mode':'subsystem','type':'pci'})
elif code=='vhost':
    ET.SubElement(d,'interface',{'type':'network'})
elif code=='second-disk':
    disk=ET.SubElement(d,'disk',{'type':'file','device':'disk'}); ET.SubElement(disk,'source',{'file':'/tmp/evil.qcow2'}); ET.SubElement(disk,'target',{'dev':'sdc','bus':'sata'})
elif code=='virtio-video': r.find('./devices/video/model').set('type','virtio')
elif code=='vapic-on': r.find('./features/hyperv/vapic').set('state','on')
elif code=='ksm':
    mb=r.find('memoryBacking'); mb.remove(mb.find('nosharepages'))
elif code=='filesystem': ET.SubElement(d,'filesystem',{'type':'mount'})
else: raise SystemExit(code)
t.write(out,encoding='unicode')
PY
  if verify "$out"; then echo "[FAIL] Manipuliertes XML wurde akzeptiert: $name" >&2; exit 1; fi
  echo "[PASS] Manipuliertes XML blockiert: $name"
}

for item in clipboard channel hostdev vhost second-disk virtio-video vapic-on ksm filesystem; do mutate "$item" "$item"; done
echo '[PASS] Runtime-Allowlist blockiert alle getesteten XML-Manipulationen.'
