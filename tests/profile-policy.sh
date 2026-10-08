#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
allowed='SAFEBOX_RAM_MIB SAFEBOX_VCPUS SAFEBOX_MEM_HARD_MIB SAFEBOX_IOTHREADS SAFEBOX_CPU_PERIOD_US SAFEBOX_CPU_MAX_PERCENT SAFEBOX_DISK_TOTAL_BYTES_SEC SAFEBOX_DISK_TOTAL_IOPS_SEC SAFEBOX_MIN_FREE_GIB SAFEBOX_RUNTIME_MIN_FREE_GIB SAFEBOX_OVERLAY_MAX_GIB'

for profile in hardened balanced performance; do
  file="$ROOT/profiles/$profile.conf"
  [[ -f "$file" && ! -L "$file" ]] || { echo "[FAIL] Profil fehlt: $profile" >&2; exit 1; }
  while IFS='' read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    key=${line%%=*}
    grep -qw "$key" <<<"$allowed" || { echo "[FAIL] $profile darf Sicherheitsvariable $key nicht verändern" >&2; exit 1; }
  done <"$file"
  (
    # shellcheck source=/dev/null
    source "$ROOT/config/defaults.conf"
    # shellcheck source=/dev/null
    source "$file"
    [[ "$SAFEBOX_RAM_MIB" =~ ^[0-9]+$ && "$SAFEBOX_VCPUS" =~ ^[0-9]+$ && "$SAFEBOX_MEM_HARD_MIB" =~ ^[0-9]+$ ]]
    (( SAFEBOX_RAM_MIB >= 2048 ))
    (( SAFEBOX_VCPUS >= 1 ))
    (( SAFEBOX_MEM_HARD_MIB >= SAFEBOX_RAM_MIB + 1024 ))
    (( SAFEBOX_IOTHREADS == 1 ))
    (( SAFEBOX_CPU_MAX_PERCENT >= 10 ))
    (( SAFEBOX_CPU_MAX_PERCENT <= 100 ))
    [[ "$SAFEBOX_NET_BACKEND" == qemu ]]
  ) || { echo "[FAIL] Profil ungültig: $profile" >&2; exit 1; }
  echo "[PASS] Profil $profile verändert ausschließlich Ressourcenlimits."
done

grep -Fq 'apply_profile "$profile"' "$ROOT/safebox"
grep -Fq 'hardened|balanced|performance' "$ROOT/safebox"
echo '[PASS] Profile sind CLI-integriert und behalten die Sicherheitsgrenzen bei.'
