#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for cidr in 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4; do
  grep -Fq "$cidr" "$ROOT/network/apply-firewall.sh"
  grep -Fq "$cidr" "$ROOT/guest/nftables.conf"
done
grep -Fq 'set host_v4' "$ROOT/network/apply-firewall.sh"
grep -Fq 'set local_v4' "$ROOT/network/apply-firewall.sh"
grep -Fq 'ip -4 -o route show table all' "$ROOT/network/apply-firewall.sh"
grep -Fq 'ip -4 -o route show table all' "$ROOT/tools/firewall-verify.sh"
grep -Fq 'ip daddr @host_v4 drop' "$ROOT/network/apply-firewall.sh"
grep -Fq 'ip daddr @local_v4 drop' "$ROOT/network/apply-firewall.sh"
grep -Fq "expected={'input':6,'output':7,'forward':16}" "$ROOT/tools/firewall-verify.sh"
grep -Fq "sorted(['blocked_v4','host_v4','local_v4'])" "$ROOT/tools/firewall-verify.sh"
grep -Fq "<dns enable='no'/>" "$ROOT/network/safebox-net.xml"
! grep -Fq '<dhcp>' "$ROOT/network/safebox-net.xml"
echo '[PASS] Netzwerk-Policy v0.5.1-rc3.'
