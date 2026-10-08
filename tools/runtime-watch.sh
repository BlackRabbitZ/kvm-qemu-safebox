#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C

CONFIG=${SAFEBOX_CONFIG_FILE:-/etc/safebox/defaults.conf}
[[ -r "$CONFIG" ]] || { logger -t safebox "Watchdog-Konfiguration fehlt: $CONFIG"; exit 2; }
# shellcheck source=/dev/null
source "$CONFIG"

DOMAIN="${1:?DOMAIN fehlt}"
MODE="${2:-runtime}"
DISK="${3:-}"
LIBEXEC="${SAFEBOX_LIBEXEC:-/usr/local/libexec/safebox}"
VERIFY_BIN="$LIBEXEC/runtime-verify.sh"
FW_BIN="$LIBEXEC/firewall-verify.sh"
QEMU_BIN="$LIBEXEC/qemu-security-check.sh"
KILL_BIN="$LIBEXEC/kill-domain.sh"
STORAGE_BIN="$LIBEXEC/storage-verify.sh"
PID_BIN="$LIBEXEC/domain-pid.sh"
NWFILTER_BIN="$LIBEXEC/nwfilter-verify.sh"
VIRSH_BIN="${SAFEBOX_VIRSH_BIN:-virsh}"
SLEEP_BIN="${SAFEBOX_SLEEP_BIN:-sleep}"
TESTING="${SAFEBOX_TESTING:-0}"
MAX_LOOPS="${SAFEBOX_WATCH_MAX_LOOPS:-0}"
LOOPS=0

for f in "$VERIFY_BIN" "$FW_BIN" "$QEMU_BIN" "$KILL_BIN" "$STORAGE_BIN" "$PID_BIN" "$NWFILTER_BIN" "$LIBEXEC/proc-absence.py" "$LIBEXEC/sample-verify.sh"; do
  if [[ "$TESTING" == 1 ]]; then
    [[ -x "$f" ]] || { echo "Watchdog-Test-Helfer fehlt: $f" >&2; exit 2; }
  else
    [[ -x "$f" && $(stat -c %U "$f" 2>/dev/null) == root ]] || {
      logger -t safebox "Watchdog-Helfer unsicher oder fehlt: $f"
      exit 2
    }
  fi
  perms="$(stat -c %a "$f" 2>/dev/null || echo 777)"
  (( (8#$perms & 8#022) == 0 )) || { logger -t safebox "Watchdog-Helfer beschreibbar: $f"; exit 2; }
done

fail_closed() {
  local reason=$1
  timeout 1s logger -t safebox "FAIL-CLOSED: $DOMAIN: $reason" >/dev/null 2>&1 || true
  SAFEBOX_CONFIG_FILE="$CONFIG" "$KILL_BIN" "$DOMAIN" || { timeout 1s logger -t safebox "KRITISCH: Kill-Fallback unbestätigt für $DOMAIN; manueller Host-Eingriff erforderlich" >/dev/null 2>&1 || true; }
}

while :; do
  if ! "$VIRSH_BIN" -c "$SAFEBOX_CONNECT_URI" list --all --name >/dev/null 2>&1; then
    fail_closed 'libvirt nicht erreichbar'
    exit 1
  fi

  if ! "$VIRSH_BIN" -c "$SAFEBOX_CONNECT_URI" dominfo "$DOMAIN" >/dev/null 2>&1; then
    # Domain disappeared from libvirt. Do not assume QEMU is gone: independently
    # verify /proc in kill-domain, even when the identity file is missing.
    SAFEBOX_CONFIG_FILE="$CONFIG" "$KILL_BIN" "$DOMAIN" >/dev/null 2>&1 || { fail_closed 'Domain aus libvirt verschwunden, QEMU-Zustand nicht sicher'; exit 1; }
    exit 0
  fi

  state="$("$VIRSH_BIN" -c "$SAFEBOX_CONNECT_URI" domstate "$DOMAIN" 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
  case "$state" in
    *shut\ off*)
      # A shut-off libvirt state is only clean if no matching QEMU process survives.
      if ! "$LIBEXEC/proc-absence.py" "$DOMAIN" >/dev/null 2>&1; then
        fail_closed 'Domain ist shut off, aber QEMU-Ende unbestätigt'
        exit 1
      fi
      exit 0
      ;;
    *in\ shutdown*|shutdown)
      # Transitional state: keep all security boundaries under observation until
      # QEMU is really gone / libvirt reaches shut off.
      ;;
    *crashed*)
      # Never treat a crash as a clean stop without proving the QEMU process is gone.
      if ! "$LIBEXEC/proc-absence.py" "$DOMAIN" >/dev/null 2>&1; then
        fail_closed 'Domain ist crashed, aber QEMU-Ende unbestätigt'
        exit 1
      fi
      exit 0
      ;;
    *running*|*paused*|*idle*) ;;
    *) fail_closed "unerwarteter Domainzustand: ${state:-unbekannt}"; exit 1;;
  esac

  if [[ "$MODE" == installer ]]; then
    if ! SAFEBOX_CONFIG_FILE="$CONFIG" "$QEMU_BIN" network >/dev/null 2>&1; then
      fail_closed 'QEMU/CVE-Sicherheitsgate fehlgeschlagen'
      exit 1
    fi
    if ! "$FW_BIN" >/dev/null 2>&1; then
      fail_closed 'Firewall-Attestation fehlgeschlagen'
      exit 1
    fi
    if ! SAFEBOX_CONFIG_FILE="$CONFIG" "$NWFILTER_BIN" >/dev/null 2>&1; then
      fail_closed 'nwfilter-Attestation fehlgeschlagen'
      exit 1
    fi
  elif [[ "$MODE" == offline || "$MODE" == malware ]]; then
    if ! SAFEBOX_CONFIG_FILE="$CONFIG" "$QEMU_BIN" offline >/dev/null 2>&1; then
      fail_closed 'QEMU-Sicherheitsgate fehlgeschlagen'
      exit 1
    fi
  else
    fail_closed 'Unerlaubter Runtime-Modus mit Netzwerk'
    exit 1
  fi

  sample_iso=''
  if [[ "$MODE" == malware ]]; then
    sample_iso="$DISK.sample.iso"
    if ! SAFEBOX_CONFIG_FILE="$CONFIG" "$LIBEXEC/sample-verify.sh" "$DISK" "$sample_iso" >/dev/null 2>&1; then
      fail_closed 'Sample-ISO nicht mehr unverändert/readonly'
      exit 1
    fi
  fi

  if ! SAFEBOX_CONFIG_FILE="$CONFIG" "$VERIFY_BIN" "$DOMAIN" "$MODE" "$DISK" "$sample_iso" >/dev/null 2>&1; then
    fail_closed 'Runtime-Attestation fehlgeschlagen'
    exit 1
  fi

  if [[ "$MODE" != installer ]]; then
    if ! SAFEBOX_CONFIG_FILE="$CONFIG" "$STORAGE_BIN" "$DOMAIN" "$MODE" "$DISK" >/dev/null 2>&1; then
      fail_closed 'Storage-Limit oder Overlay-Bindung verletzt'
      exit 1
    fi
  fi

  LOOPS=$((LOOPS+1))
  if [[ "$MAX_LOOPS" =~ ^[0-9]+$ ]] && (( MAX_LOOPS > 0 && LOOPS >= MAX_LOOPS )); then exit 0; fi
  "$SLEEP_BIN" "$SAFEBOX_WATCH_INTERVAL"
done
