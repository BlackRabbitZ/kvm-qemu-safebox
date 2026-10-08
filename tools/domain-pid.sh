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
[[ "$DOMAIN" =~ ^safebox-[A-Za-z0-9._-]+$ ]] || { echo "FEHLER: Ungültiger Domainname: $DOMAIN" >&2; exit 2; }

validate_pid_identity(){
  local pid=$1
  local uuid=$2
  local expected_start=${3:-}
  local start_before start_after exe cmdline
  local found_uuid=0
  [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 ]] || return 1
  [[ "$uuid" =~ ^[0-9a-f-]{36}$ ]] || return 1
  "${SUDO[@]}" test -r "/proc/$pid/stat" || return 1

  # awk script uses its own $n fields, which must remain literal.
  # shellcheck disable=SC2016
  start_before="$("${SUDO[@]}" awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true)"
  [[ "$start_before" =~ ^[0-9]+$ ]] || return 1
  [[ -z "$expected_start" || "$start_before" == "$expected_start" ]] || return 1

  exe="$("${SUDO[@]}" readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
  [[ "$exe" == */qemu-system-x86_64 ]] || return 1

  cmdline="$("${SUDO[@]}" cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' '\n' || true)"
  grep -Fxq -- "guest=$DOMAIN,debug-threads=on" <<<"$cmdline" || grep -Eq "^guest=${DOMAIN//./\\.}," <<<"$cmdline" || return 1

  mapfile -t args < <("${SUDO[@]}" cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' '\n')
  local i
  for i in "${!args[@]}"; do
    # Das letzte Argument kann kein Wert zu -uuid sein.
    [[ "$i" -lt $((${#args[@]} - 1)) ]] || break
    if [[ "${args[$i]}" == -uuid && "${args[$((i+1))],,}" == "$uuid" ]]; then
      found_uuid=1
      break
    fi
  done
  (( found_uuid == 1 )) || return 1

  # awk script uses its own $n fields, which must remain literal.
  # shellcheck disable=SC2016
  start_after="$("${SUDO[@]}" awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true)"
  [[ "$start_before" == "$start_after" ]] || return 1
  printf '%s\n' "$pid"
}

# Primär: PID und UUID live über libvirt bestimmen.
if "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" dominfo "$DOMAIN" >/dev/null 2>&1; then
  uuid="$("${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" domuuid "$DOMAIN" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  [[ "$uuid" =~ ^[0-9a-f-]{36}$ ]] || { echo 'FEHLER: Domain-UUID konnte nicht sicher ermittelt werden.' >&2; exit 1; }
  pid=''
  for pf in "/run/libvirt/qemu/$DOMAIN.pid" "/var/run/libvirt/qemu/$DOMAIN.pid"; do
    if "${SUDO[@]}" test -r "$pf"; then
      candidate="$("${SUDO[@]}" cat "$pf" 2>/dev/null || true)"
      if [[ "$candidate" =~ ^[0-9]+$ && "$candidate" -gt 1 ]]; then pid=$candidate; break; fi
    fi
  done
  [[ "$pid" =~ ^[0-9]+$ ]] || { echo 'FEHLER: QEMU-PID nicht gefunden.' >&2; exit 1; }
  validate_pid_identity "$pid" "$uuid" || { echo 'FEHLER: QEMU-PID/Domain-Zuordnung fehlgeschlagen.' >&2; exit 1; }
  exit 0
fi

# Fail-closed-Fallback: libvirt kann ausgefallen sein. Dann wird ausschließlich eine
# root-owned Runtime-Identität akzeptiert und gegen PID-Startzeit, QEMU-Binary,
# Domainname und die tatsächlich an QEMU übergebene UUID validiert.
identity="${SAFEBOX_RUNTIME_DIR:-/run/safebox}/identities/$DOMAIN.json"
"${SUDO[@]}" test -r "$identity" || { echo 'FEHLER: libvirt nicht erreichbar und keine Runtime-Identität vorhanden.' >&2; exit 1; }
[[ "$("${SUDO[@]}" stat -c %U "$identity" 2>/dev/null)" == root ]] || { echo 'FEHLER: Runtime-Identität ist nicht root-owned.' >&2; exit 1; }
perm="$("${SUDO[@]}" stat -c %a "$identity" 2>/dev/null || echo 777)"
(( (8#$perm & 8#077) == 0 )) || { echo 'FEHLER: Runtime-Identität ist zu offen berechtigt.' >&2; exit 1; }
json="$("${SUDO[@]}" cat "$identity")"
read -r stored_domain uuid pid start < <(python3 - "$json" <<'PY'
import json,sys
j=json.loads(sys.argv[1])
print(j.get('domain',''), j.get('uuid',''), j.get('pid',''), j.get('starttime',''))
PY
)
[[ "$stored_domain" == "$DOMAIN" ]] || { echo 'FEHLER: Runtime-Identität gehört zu einer anderen Domain.' >&2; exit 1; }
validate_pid_identity "$pid" "${uuid,,}" "$start" || { echo 'FEHLER: Runtime-Identität passt nicht zum laufenden QEMU-Prozess.' >&2; exit 1; }
