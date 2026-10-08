#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C
CONFIG=${SAFEBOX_CONFIG_FILE:-/etc/safebox/defaults.conf}
[[ -r "$CONFIG" ]] || exit 2
# shellcheck source=/dev/null
source "$CONFIG"
DOMAIN=${1:-}
[[ "$DOMAIN" =~ ^safebox-[A-Za-z0-9._-]+$ ]] || { echo 'Ungültiger Domainname' >&2; exit 2; }
LIBEXEC="${SAFEBOX_LIBEXEC:-/usr/local/libexec/safebox}"
IDENTITY="${SAFEBOX_RUNTIME_DIR:-/run/safebox}/identities/$DOMAIN.json"
log(){ timeout 1s logger -t safebox "FAIL-CLOSED: $DOMAIN: $*" >/dev/null 2>&1 || true; }
log 'Kill-Service aktiviert'
# Never infer absence from a failed dominfo. libvirt connectivity is separate.
if ! virsh -c "$SAFEBOX_CONNECT_URI" list --all --name >/dev/null 2>&1; then
  # Safe fallback: signal only a PID positively validated against UUID and starttime.
  pid="$(SAFEBOX_CONFIG_FILE="$CONFIG" "$LIBEXEC/domain-pid.sh" "$DOMAIN" 2>/dev/null || true)"
  if [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )); then
    start="$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true)"
    if [[ "$start" =~ ^[0-9]+$ ]]; then
      kill -TERM "$pid" 2>/dev/null || true
      for _ in {1..10}; do
        if ! kill -0 "$pid" 2>/dev/null; then break; fi
        sleep 0.2
      done
      # Do not signal a reused PID.
      now="$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true)"
      if [[ "$now" == "$start" ]]; then kill -KILL "$pid" 2>/dev/null || true; fi
    fi
  fi
  log 'libvirt nicht erreichbar; kein bestätigter VM-Endzustand (Exit 1)'
  exit 1
fi
# libvirt reachable: shutdown the domain if still active.
active="$(virsh -c "$SAFEBOX_CONNECT_URI" list --name)" || exit 1
if grep -Fxq -- "$DOMAIN" <<<"$active"; then
  virsh -c "$SAFEBOX_CONNECT_URI" destroy "$DOMAIN" >/dev/null 2>&1 || true
fi
# Still running? Try strictly validated process fallback, never use an unvalidated PID.
pid="$(SAFEBOX_CONFIG_FILE="$CONFIG" "$LIBEXEC/domain-pid.sh" "$DOMAIN" 2>/dev/null || true)"
if [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )); then
  start="$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true)"
  if [[ "$start" =~ ^[0-9]+$ ]]; then
    kill -TERM "$pid" 2>/dev/null || true
    for _ in {1..10}; do
      if ! kill -0 "$pid" 2>/dev/null; then break; fi
      sleep 0.2
    done
    now="$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true)"
    if [[ "$now" == "$start" ]]; then kill -KILL "$pid" 2>/dev/null || true; fi
  fi
fi
# A successful kill must be independently verified, including the libvirt inventory.
if ! virsh -c "$SAFEBOX_CONNECT_URI" list --all --name >/dev/null 2>&1; then
  log 'libvirt-Verbindung bei Nachkontrolle verloren'; exit 1
fi
active="$(virsh -c "$SAFEBOX_CONNECT_URI" list --name)" || exit 1
if grep -Fxq -- "$DOMAIN" <<<"$active"; then log 'Domain weiterhin aktiv'; exit 1; fi
if ! python3 "$LIBEXEC/proc-absence.py" "$DOMAIN"; then
  log 'QEMU noch aktiv oder Prozessinventar unvollständig'; exit 1
fi
rm -f -- "$IDENTITY"
log 'VM-Ende unabhängig bestätigt'
exit 0
