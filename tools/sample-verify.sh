#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
# An ISO mounted in a running VM is only safe when it cannot be replaced by a
# less privileged actor. Root compromise is beyond the guest containment model.
CONFIG="${SAFEBOX_CONFIG_FILE:-/etc/safebox/defaults.conf}"
[[ -r "$CONFIG" ]] || exit 2
# shellcheck source=/dev/null
source "$CONFIG"
disk=${1:-}; iso=${2:-}
[[ -n "$disk" && "$iso" == "$disk.sample.iso" ]] || exit 2
real_dir="$(readlink -f "$SAFEBOX_SESSIONS_DIR")"
real_iso="$(readlink -f "$iso" 2>/dev/null || true)"
[[ "$real_iso" == "$real_dir"/* && ! -L "$iso" && -f "$iso" ]] || exit 1
[[ "$(stat -c %u "$iso")" == 0 && "$(stat -c %a "$iso")" == 440 ]] || exit 1
hash_file="$iso.sha256"
[[ ! -L "$hash_file" && -f "$hash_file" && "$(stat -c %u "$hash_file")" == 0 && "$(stat -c %a "$hash_file")" == 400 ]] || exit 1
expected="$(cat "$hash_file")"
[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || exit 1
actual="$(sha256sum "$iso" | awk '{print $1}')"
[[ "$actual" == "$expected" ]] || exit 1
printf '[PASS] Schreibgeschützte Sample-ISO ist an SHA-256 gebunden.\n'
