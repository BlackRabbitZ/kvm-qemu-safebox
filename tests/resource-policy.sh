#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for f in "$ROOT/vm/templates/runtime.xml.in" "$ROOT/vm/templates/installer.xml.in"; do
  grep -Fq '<global_period>__CPU_PERIOD_US__</global_period>' "$f"
  grep -Fq '<global_quota>__CPU_GLOBAL_QUOTA_US__</global_quota>' "$f"
  grep -Fq '<total_bytes_sec>__DISK_TOTAL_BYTES_SEC__</total_bytes_sec>' "$f"
  grep -Fq '<total_iops_sec>__DISK_TOTAL_IOPS_SEC__</total_iops_sec>' "$f"
done
for v in SAFEBOX_CPU_PERIOD_US SAFEBOX_CPU_MAX_PERCENT SAFEBOX_DISK_TOTAL_BYTES_SEC SAFEBOX_DISK_TOTAL_IOPS_SEC SAFEBOX_MIN_FREE_GIB SAFEBOX_RUNTIME_MIN_FREE_GIB SAFEBOX_OVERLAY_MAX_GIB SAFEBOX_BASE_META SAFEBOX_PERSISTENT_META SAFEBOX_LOCK_FILE; do
  grep -Fq "$v" "$ROOT/config/defaults.conf"
done
grep -Fq 'global_quota' "$ROOT/tools/runtime-verify.sh"
grep -Fq 'total_bytes_sec' "$ROOT/tools/runtime-verify.sh"
grep -Fq 'total_iops_sec' "$ROOT/tools/runtime-verify.sh"
grep -Fq "stat -c '%b %B'" "$ROOT/tools/storage-verify.sh"
grep -Fq 'SAFEBOX_RUNTIME_MIN_FREE_GIB' "$ROOT/tools/storage-verify.sh"
grep -Fq 'SAFEBOX_OVERLAY_MAX_GIB' "$ROOT/tools/storage-verify.sh"
grep -Fq "'base_id'" "$ROOT/safebox"
grep -Fq "'base_sha256'" "$ROOT/safebox"
grep -Fq 'flock -n 9' "$ROOT/safebox"
grep -Fq 'umask 077' "$ROOT/safebox"
grep -Fq 'safe_mktemp' "$ROOT/safebox"
grep -Fq 'domain-pid.sh' "$ROOT/tools/runtime-verify.sh"
grep -Fq '== -uuid' "$ROOT/tools/domain-pid.sh"
grep -Fq 'QEMU-Monitor nur lokal/FD-basiert' "$ROOT/tools/runtime-verify.sh"
grep -Fq 'libvirtd-tcp.socket' "$ROOT/host/harden-libvirt.sh"
grep -Fq 'virtproxyd-tcp.socket' "$ROOT/host/harden-libvirt.sh"
grep -Fq 'security-check' "$ROOT/safebox"
grep -Fq 'status_cmd' "$ROOT/safebox"
grep -Fq 'cleanup_cmd' "$ROOT/safebox"
grep -Fq 'storage-verify.sh' "$ROOT/tools/runtime-watch.sh"
grep -Fq 'kvm-qemu-safebox.lock' "$ROOT/systemd/safebox-tmpfiles.conf"
grep -Fq 'Runtime-Identität' "$ROOT/tools/domain-pid.sh"
# Grund: Wörtlicher Such-/Testtext, Expansion wäre hier falsch.
# shellcheck disable=SC2016
grep -Fq 'identities/$DOMAIN.json' "$ROOT/tools/domain-pid.sh"
grep -Fq 'record_domain_identity' "$ROOT/safebox"
grep -Fq 'identities' "$ROOT/systemd/safebox-tmpfiles.conf"
echo '[PASS] Ressourcen-, Storage- und Stabilitäts-Policy.'
