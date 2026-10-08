#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for f in "$ROOT/vm/templates/runtime.xml.in" "$ROOT/vm/templates/installer.xml.in"; do
  grep -Fq "<vapic state='off'/>" "$f"
  grep -Fq "<model type='bochs' heads='1' primary='yes'/>" "$f"
  grep -Fq "<nosharepages/>" "$f"
  grep -Fq "<controller type='usb' model='none'/>" "$f"
  grep -Fq "<memballoon model='none'/>" "$f"
  grep -Fq "<clipboard copypaste='no'/>" "$f"
  grep -Fq "<filetransfer enable='no'/>" "$f"
  grep -Fq "<gl enable='no'/>" "$f"
done
for forbidden in '<hostdev' '<filesystem' '<channel' '<tpm' '<vsock' '<sound' '<rng' "model type='virtio' heads='1' primary='yes'"; do
  ! grep -Fq "$forbidden" "$ROOT/vm/templates/runtime.xml.in"
done
grep -Fq "CTRL_IP_LEARNING' value='none'" "$ROOT/safebox"
grep -Fq 'SAFEBOX_LIBEXEC="/usr/local/libexec/safebox"' "$ROOT/config/defaults.conf"
grep -Fq 'SAFEBOX_NET_BACKEND="qemu"' "$ROOT/config/defaults.conf"
grep -Fq 'SAFEBOX_QEMU_MIN_VERSION="10.0.13"' "$ROOT/config/defaults.conf"
grep -Fq 'SAFEBOX_NET_MODEL="e1000e"' "$ROOT/config/defaults.conf"
grep -Fq 'SAFEBOX_DISK_BUS="sata"' "$ROOT/config/defaults.conf"
grep -Fq 'qemu-system-modules-spice' "$ROOT/install/install-host.sh"
grep -Fq 'qemu-security-check.sh' "$ROOT/safebox"
grep -Fq "model/@type='\$SAFEBOX_NET_MODEL'" "$ROOT/tools/runtime-verify.sh"
grep -Fq 'install -m 0755 -o root -g root' "$ROOT/install/install-runtime-helpers.sh"
grep -Fq 'Restart=on-failure' "$ROOT/safebox"
grep -Fq 'OnFailure=' "$ROOT/safebox"
grep -Fq 'safebox-kill@.service' "$ROOT/install/install-runtime-helpers.sh"
grep -Fq 'domstate' "$ROOT/tools/runtime-watch.sh"
grep -Fq 'verify-debian-iso' "$ROOT/safebox"
grep -Fq "ip daddr @local_v4 drop" "$ROOT/network/apply-firewall.sh"
grep -Fq "sets)!=sorted(['blocked_v4','host_v4','local_v4'])" "$ROOT/tools/firewall-verify.sh"
grep -Fq "'(enforce)'" "$ROOT/tools/runtime-verify.sh"
grep -Fq 'nwfilter-verify.sh' "$ROOT/tools/runtime-watch.sh"
grep -Fq 'firewall-policy.sha256' "$ROOT/tools/firewall-verify.sh"
grep -Fq 'git -C "$ROOT" verify-tag' "$ROOT/tools/verify-signed-tag.sh"
echo '[PASS] Statische VM-Sicherheitsrichtlinie v0.5.1-rc3.'
