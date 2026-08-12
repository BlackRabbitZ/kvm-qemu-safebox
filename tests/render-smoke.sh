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
      <filterref filter='clean-traffic'>
        <parameter name='IP' value='10.77.0.100'/>
      </filterref>
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
  xmllint --noout "$TMP"/*.xml "$ROOT/network/safebox-net.xml" "$ROOT/network/safebox-install-net.xml"
else
  python3 - "$TMP" "$ROOT/network" <<'PY'
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
for f in list(Path(sys.argv[1]).glob('*.xml')) + [Path(sys.argv[2])/'safebox-net.xml', Path(sys.argv[2])/'safebox-install-net.xml']:
    ET.parse(f)
PY
fi

if command -v virt-xml-validate >/dev/null 2>&1; then
  virt-xml-validate "$TMP/installer.xml" domain
  virt-xml-validate "$TMP/runtime.xml" domain
  virt-xml-validate "$TMP/offline.xml" domain
  virt-xml-validate "$ROOT/network/safebox-net.xml" network
  virt-xml-validate "$ROOT/network/safebox-install-net.xml" network
fi

! grep -R '__[A-Z_]*__' "$TMP" >/dev/null || { echo "[FAIL] Nicht ersetzter Template-Platzhalter" >&2; exit 1; }
! grep -q "<interface" "$TMP/offline.xml" || { echo "[FAIL] Offline-Profil enthält Netzwerkinterface" >&2; exit 1; }
grep -q "<source network='safebox-net'" "$TMP/runtime.xml" || { echo "[FAIL] Runtime-Profil nutzt nicht safebox-net" >&2; exit 1; }
grep -q "parameter name='IP' value='10.77.0.100'" "$TMP/runtime.xml" || { echo "[FAIL] Runtime-Profil erzwingt nicht die feste Gast-IP" >&2; exit 1; }
grep -q "<source network='safebox-install-net'" "$TMP/installer.xml" || { echo "[FAIL] Installer nutzt nicht safebox-install-net" >&2; exit 1; }
grep -q "CTRL_IP_LEARNING' value='dhcp'" "$TMP/installer.xml" || { echo "[FAIL] Installer-nwfilter nutzt kein DHCP-Snooping" >&2; exit 1; }

echo "[PASS] XML-Templates rendern und validieren für Installer, Runtime und Offline."
