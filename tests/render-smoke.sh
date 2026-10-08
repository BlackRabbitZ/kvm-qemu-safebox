#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
python3 - "$ROOT" "$t" <<'PYSCRIPT'
from pathlib import Path
import sys,xml.etree.ElementTree as ET
root=Path(sys.argv[1]); out=Path(sys.argv[2])
common={
 '__DOMAIN_NAME__':'safebox-test',
 '__RAM_MIB__':'6144',
 '__VCPUS__':'4',
 '__MEM_HARD_MIB__':'8192',
 '__IOTHREADS__':'1',
 '__CPU_PERIOD_US__':'100000',
 '__CPU_GLOBAL_QUOTA_US__':'280000',
 '__DISK_TOTAL_BYTES_SEC__':'134217728',
 '__DISK_TOTAL_IOPS_SEC__':'12000',
 '__DISK_IMAGE__':'/tmp/test.qcow2',
 '__ISO_IMAGE__':'/tmp/test.iso',
 '__NETWORK_BLOCK__':'',
 '__SAMPLE_BLOCK__':'',
 '__NET_BACKEND__':'qemu'
}
for name in ('runtime','installer'):
    s=(root/'vm/templates'/f'{name}.xml.in').read_text()
    for k,v in common.items(): s=s.replace(k,v)
    p=out/f'{name}.xml'; p.write_text(s); ET.parse(p)
    if '__' in s: raise SystemExit(f'Unersetzter Platzhalter in {name}')
PYSCRIPT
if command -v virt-xml-validate >/dev/null 2>&1; then
  virt-xml-validate "$t/runtime.xml" domain >/dev/null
  virt-xml-validate "$t/installer.xml" domain >/dev/null
fi
echo '[PASS] XML-Render-/Schema-Smoke-Test.'
