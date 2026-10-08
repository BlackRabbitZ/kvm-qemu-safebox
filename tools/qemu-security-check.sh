#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C

CONFIG=${SAFEBOX_CONFIG_FILE:-/etc/safebox/defaults.conf}
[[ -r "$CONFIG" ]] || CONFIG="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/config/defaults.conf"
# shellcheck source=/dev/null
source "$CONFIG"

MODE=${1:-network}
[[ "$MODE" == network || "$MODE" == offline ]] || { echo "FEHLER: qemu-security-check.sh network|offline" >&2; exit 2; }
command -v qemu-system-x86_64 >/dev/null || { echo '[FAIL] qemu-system-x86_64 fehlt.' >&2; exit 1; }
command -v dpkg >/dev/null || { echo '[FAIL] dpkg fehlt.' >&2; exit 1; }

raw="$(qemu-system-x86_64 --version | head -n1)"
version="$(sed -nE 's/.*version[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' <<<"$raw")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "[FAIL] QEMU-Version nicht sicher ermittelt: $raw" >&2; exit 1; }
dpkg --compare-versions "$version" ge "${SAFEBOX_QEMU_MIN_VERSION:-10.0.13}" || { echo "[FAIL] QEMU $version ist älter als ${SAFEBOX_QEMU_MIN_VERSION:-10.0.13}." >&2; exit 1; }

# Hardened default deliberately avoids the two currently problematic VirtIO paths:
# - NIC: e1000e instead of virtio-net
# - disk: SATA instead of virtio-blk
# If somebody changes those defaults back to VirtIO, fail closed unless a patched
# QEMU branch is present.
if [[ "$MODE" == network && "${SAFEBOX_NET_MODEL:-e1000e}" == virtio ]]; then
  vulnerable=0
  if dpkg --compare-versions "$version" lt "${SAFEBOX_QEMU_MIN_NETWORK_VERSION:-10.0.14}"; then vulnerable=1; fi
  if dpkg --compare-versions "$version" ge 11.0.0 && dpkg --compare-versions "$version" lt "${SAFEBOX_QEMU_BLOCK_11_BELOW:-11.1.2}"; then vulnerable=1; fi
  (( vulnerable == 0 )) || { echo "[FAIL] VirtIO-Netzwerk ist auf QEMU $version wegen CVE-2026-66900 blockiert." >&2; exit 1; }
fi
if [[ "${SAFEBOX_DISK_BUS:-sata}" == virtio ]]; then
  echo '[FAIL] VirtIO-Block ist im Hardened-Profil wegen CVE-2024-8612 nicht erlaubt. SafeBox erwartet SATA.' >&2
  exit 1
fi

# The hardened default uses Q35 SATA/AHCI to avoid the currently open VirtIO
# block disclosure path. Debian still tracks historical AHCI guest-triggered
# denial-of-service issues (e.g. CVE-2021-3735/CVE-2019-12067). They are not
# documented host-code-execution escapes, but the residual availability risk is
# surfaced explicitly instead of claiming a CVE-free device model.
if [[ "${SAFEBOX_DISK_BUS:-sata}" == sata ]]; then
  echo '[WARN] SATA/AHCI bleibt als reduzierte Rest-Angriffsfläche bestehen; bekannte gastgetriggerte QEMU-DoS-Risiken werden dokumentiert.' >&2
fi

printf '[PASS] QEMU-Sicherheitsgate: %s (%s, NIC=%s, Disk=%s)\n' "$version" "$MODE" "${SAFEBOX_NET_MODEL:-e1000e}" "${SAFEBOX_DISK_BUS:-sata}"
