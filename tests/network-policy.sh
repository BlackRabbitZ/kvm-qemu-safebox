#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
NET="$ROOT/network/safebox-net.xml"
NFT="$ROOT/network/safebox-guard.nft"
FAIL=0

pass(){ printf '[PASS] %s\n' "$1"; }
fail(){ printf '[FAIL] %s\n' "$1"; FAIL=1; }
check(){
  local pattern=$1 file=$2 msg=$3
  if grep -Eq "$pattern" "$file"; then pass "$msg"; else fail "$msg"; fi
}

check "<forward mode='nat'/>" "$NET" "Dediziertes NAT-Netz"
check "<bridge name='virbr-safebox'" "$NET" "Dedizierte Bridge"
check "<port isolated='yes'/>" "$NET" "Gast-Port-Isolation"
check "<host mac='52:54:00:77:00:10'.*ip='10.77.0.100'" "$NET" "Feste DHCP-Zuordnung"
if grep -q '<range ' "$NET"; then fail "Kein dynamischer DHCP-Pool"; else pass "Kein dynamischer DHCP-Pool"; fi

check 'iifname "virbr-safebox".*udp sport 68 dport 67 accept' "$NFT" "Nur DHCP zum Host erlaubt"
check 'ip saddr 10\.77\.0\.100 udp dport 53 accept' "$NFT" "DNS/UDP nur von erwarteter Gast-IP"
check 'ip saddr 10\.77\.0\.100 tcp dport 53 accept' "$NFT" "DNS/TCP nur von erwarteter Gast-IP"
check 'iifname "virbr-safebox" drop' "$NFT" "Sonstiger Gast-zu-Host-Verkehr wird gedroppt"
check 'ip saddr != 10\.77\.0\.100 drop' "$NFT" "Geroutetes IPv4-Source-Spoofing wird gedroppt"
check '192\.168\.0\.0/16' "$NFT" "Privates 192.168/16 blockiert"
check '10\.0\.0\.0/8' "$NFT" "Privates 10/8 blockiert"
check '172\.16\.0\.0/12' "$NFT" "Privates 172.16/12 blockiert"

exit "$FAIL"
