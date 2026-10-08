#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C

CONFIG=${SAFEBOX_CONFIG_FILE:-/etc/safebox/defaults.conf}
[[ -r "$CONFIG" ]] || { echo "FEHLER: Konfiguration fehlt: $CONFIG" >&2; exit 2; }
# shellcheck source=/dev/null
source "$CONFIG"
SUDO=(); [[ ${EUID} -eq 0 ]] || SUDO=(sudo)
DOMAIN=${1:-}
MODE=${2:-runtime}
DISK=${3:-}
[[ "$DOMAIN" =~ ^safebox-[A-Za-z0-9._-]+$ ]] || { echo 'FEHLER: Ungültige Domain.' >&2; exit 2; }
[[ -n "$DISK" ]] || { echo 'FEHLER: Disk-Pfad fehlt.' >&2; exit 2; }

real_storage="$("${SUDO[@]}" readlink -f "$SAFEBOX_STORAGE" 2>/dev/null || true)"
real_disk="$("${SUDO[@]}" readlink -f "$DISK" 2>/dev/null || true)"
[[ -n "$real_disk" && "$real_disk" == "$real_storage"/* ]] || { echo '[FAIL] Disk liegt außerhalb des SafeBox-Speichers.' >&2; exit 1; }
"${SUDO[@]}" test -f "$real_disk" || { echo '[FAIL] Overlay fehlt.' >&2; exit 1; }
"${SUDO[@]}" test ! -L "$DISK" || { echo '[FAIL] Overlay darf kein Symlink sein.' >&2; exit 1; }

# Allokierte Host-Blöcke statt Dateilänge prüfen; das funktioniert auch bei laufender QEMU-VM.
# awk script uses its own $n fields, which must remain literal.
# shellcheck disable=SC2016
allocated_bytes="$("${SUDO[@]}" stat -c '%b %B' "$real_disk" | awk '{print $1*$2}')"
max_bytes=$(( SAFEBOX_OVERLAY_MAX_GIB * 1024 * 1024 * 1024 ))
(( allocated_bytes <= max_bytes )) || { echo "[FAIL] Overlay überschreitet Host-Limit (${SAFEBOX_OVERLAY_MAX_GIB} GiB)." >&2; exit 1; }

# Literal embedded program/test syntax: $ belongs to that program, not Bash.
# shellcheck disable=SC2016
avail_bytes="$("${SUDO[@]}" df -PB1 "$real_storage" | awk 'NR==2 {print $4}')"
min_bytes=$(( SAFEBOX_RUNTIME_MIN_FREE_GIB * 1024 * 1024 * 1024 ))
if [[ ! "$avail_bytes" =~ ^[0-9]+$ ]] || (( avail_bytes < min_bytes )); then
  echo "[FAIL] Host-Speicher unter Reserve (${SAFEBOX_RUNTIME_MIN_FREE_GIB} GiB)." >&2
  exit 1
fi

case "$MODE" in
  persistent) meta="$SAFEBOX_PERSISTENT_META";;
  runtime|disposable|offline|malware) meta="$DISK.meta.json";;
  installer) echo '[PASS] Installer-Speichergrenzen bestätigt.'; exit 0;;
  *) echo "FEHLER: Unbekannter Speichermodus: $MODE" >&2; exit 2;;
esac

"${SUDO[@]}" test -f "$meta" || { echo '[FAIL] Overlay-Metadaten fehlen.' >&2; exit 1; }
[[ "$("${SUDO[@]}" stat -c %U "$meta")" == root ]] || { echo '[FAIL] Overlay-Metadaten nicht root-owned.' >&2; exit 1; }
perm="$("${SUDO[@]}" stat -c %a "$meta")"
(( (8#$perm & 8#022) == 0 )) || { echo '[FAIL] Overlay-Metadaten sind beschreibbar.' >&2; exit 1; }
"${SUDO[@]}" test -f "$SAFEBOX_BASE_META" || { echo '[FAIL] Basis-Metadaten fehlen.' >&2; exit 1; }

meta_json="$("${SUDO[@]}" cat "$meta")"
base_json="$("${SUDO[@]}" cat "$SAFEBOX_BASE_META")"
python3 - "$DOMAIN" "$MODE" "$real_disk" "$SAFEBOX_BASE_IMAGE" "$SAFEBOX_VERSION" "$meta_json" "$base_json" <<'PY'
import json,os,sys
name,mode,disk,base,version,meta_s,base_s=sys.argv[1:]
m=json.loads(meta_s); b=json.loads(base_s)
expected_mode=mode
if mode=='runtime':
    if name=='safebox-persistent': expected_mode='persistent'
    elif name.startswith('safebox-disposable-'): expected_mode='disposable'
    elif name.startswith('safebox-offline-'): expected_mode='offline'
checks={
 'schema':m.get('schema')==1,
 'domain':m.get('domain')==name,
 'mode':m.get('mode')==expected_mode,
 'disk':os.path.realpath(m.get('disk',''))==os.path.realpath(disk),
 'base_path':os.path.realpath(m.get('base_path',''))==os.path.realpath(base),
 'base_id':m.get('base_id')==b.get('base_id'),
 'base_sha256':m.get('base_sha256')==b.get('sha256'),
 'version':m.get('safebox_version')==version,
 'base_version':b.get('safebox_version')==version,
}
failed=[k for k,v in checks.items() if not v]
if failed:
    raise SystemExit('[FAIL] Overlay-Bindung ungültig: '+', '.join(failed))
PY

echo '[PASS] Storage-Limit und Overlay-Bindung bestätigt.'
