#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

network_block=$(cat <<'XML'
    <interface type='network'>
      <mac address='52:54:00:77:00:10'/>
      <source network='safebox-net'/>
      <model type='virtio'/>
      <rom bar='off'/>
      <port isolated='yes'/>
    </interface>
XML
)

render() {
  local src=$1 dst=$2 name=$3 disk=$4 iso=${5:-} block=${6:-}
  sed \
    -e "s|__DOMAIN_NAME__|$name|g" \
    -e 's|__RAM_MIB__|4096|g' \
    -e 's|__VCPUS__|2|g' \
    -e "s|__DISK_IMAGE__|$disk|g" \
    -e "s|__ISO_IMAGE__|$iso|g" \
    "$src" > "$dst.tmp"
  awk -v block="$block" '/__NETWORK_BLOCK__/ { print block; next } { print }' "$dst.tmp" > "$dst"
  rm -f "$dst.tmp"
}

render "$ROOT/vm/templates/installer.xml.in" "$TMP/installer.xml" safebox-installer /var/lib/libvirt/images/safebox/base.qcow2 /var/lib/libvirt/images/safebox/installer.iso ""
render "$ROOT/vm/templates/runtime.xml.in" "$TMP/runtime.xml" safebox-test /var/lib/libvirt/images/safebox/test.qcow2 "" "$network_block"
render "$ROOT/vm/templates/runtime.xml.in" "$TMP/offline.xml" safebox-offline-test /var/lib/libvirt/images/safebox/offline.qcow2 "" ""

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$TMP"/*.xml
else
  python3 - "$TMP" <<'PY'
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
for f in Path(sys.argv[1]).glob('*.xml'):
    ET.parse(f)
PY
fi

! grep -R '__[A-Z_]*__' "$TMP" >/dev/null || { echo "[FAIL] Nicht ersetzter Template-Platzhalter" >&2; exit 1; }
! grep -q "<interface" "$TMP/offline.xml" || { echo "[FAIL] Offline-Profil enthält Netzwerkinterface" >&2; exit 1; }
grep -q "<interface" "$TMP/runtime.xml" || { echo "[FAIL] Online-Profil enthält kein Netzwerkinterface" >&2; exit 1; }

echo "[PASS] XML-Templates rendern für Installer, Online und Offline."
