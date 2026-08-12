#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_NET="$ROOT/network/safebox-net.xml"
INSTALL_NET="$ROOT/network/safebox-install-net.xml"
NFT="$ROOT/network/safebox-guard.nft"
FAIL=0

pass(){ printf '[PASS] %s\n' "$1"; }
fail(){ printf '[FAIL] %s\n' "$1"; FAIL=1; }
check(){ local pattern=$1 file=$2 msg=$3; if grep -Eq "$pattern" "$file"; then pass "$msg"; else fail "$msg"; fi; }

check "<forward mode='nat'/>" "$RUNTIME_NET" "Runtime nutzt dediziertes NAT-Netz"
check "<bridge name='virbr-safebox'" "$RUNTIME_NET" "Dedizierte Runtime-Bridge"
check "<port isolated='yes'/>" "$RUNTIME_NET" "Runtime-Port-Isolation"
check "<dns enable='no'/>" "$RUNTIME_NET" "Runtime-DNS auf dem Host deaktiviert"
if grep -q '<dhcp>' "$RUNTIME_NET"; then fail "Runtime besitzt keinen DHCP-Dienst"; else pass "Runtime besitzt keinen DHCP-Dienst"; fi
if grep -Eq "<ip[^>]*family='ipv6'" "$RUNTIME_NET"; then fail "Runtime-Netz definiert kein IPv6"; else pass "Runtime-Netz definiert kein IPv6"; fi

check "<name>safebox-install-net</name>" "$INSTALL_NET" "Getrenntes Installationsnetz"
check "<bridge name='virbr-safebox-inst'" "$INSTALL_NET" "Getrennte Installer-Bridge"
check "<dns enable='yes'" "$INSTALL_NET" "DNS existiert nur im Installationsnetz"
check "<host mac='52:54:00:77:00:10'.*ip='10.77.0.100'" "$INSTALL_NET" "Installer hat feste DHCP-Zuordnung"
if grep -q '<range ' "$INSTALL_NET"; then fail "Kein dynamischer DHCP-Pool"; else pass "Kein dynamischer DHCP-Pool"; fi
if grep -Eq "<ip[^>]*family='ipv6'" "$INSTALL_NET"; then fail "Installationsnetz definiert kein IPv6"; else pass "Installationsnetz definiert kein IPv6"; fi

check 'iifname "virbr-safebox" meta nfproto ipv6 drop' "$NFT" "Runtime-IPv6 Gast->Host wird verworfen"
check 'oifname "virbr-safebox" meta nfproto ipv6 drop' "$NFT" "Runtime-IPv6 Host->Gast wird verworfen"
check 'iifname "virbr-safebox" drop' "$NFT" "Runtime-Gast kann keine Host-Dienste erreichen"
check 'oifname "virbr-safebox" drop' "$NFT" "Neue Host-Verbindungen zum Runtime-Gast werden verworfen"
check 'iifname "virbr-safebox" ip saddr != 10\.77\.0\.100 drop' "$NFT" "Runtime IPv4-Source-Spoofing wird verworfen"

if grep -Eq 'iifname "virbr-safebox".*dport (53|67).*accept' "$NFT"; then
  fail "Runtime-Bridge exponiert weder DNS noch DHCP zum Host"
else
  pass "Runtime-Bridge exponiert weder DNS noch DHCP zum Host"
fi
check 'iifname "virbr-safebox-inst".*udp sport 68 dport 67 accept' "$NFT" "DHCP nur auf Installer-Bridge erlaubt"
check 'iifname "virbr-safebox-inst".*udp dport 53 accept' "$NFT" "DNS/UDP nur auf Installer-Bridge erlaubt"
check 'iifname "virbr-safebox-inst".*tcp dport 53 accept' "$NFT" "DNS/TCP nur auf Installer-Bridge erlaubt"
check 'iifname "virbr-safebox-inst" drop' "$NFT" "Sonstiger Installer-Gast->Host-Verkehr wird verworfen"
check 'iifname "virbr-safebox-inst" ip saddr != 10\.77\.0\.100 drop' "$NFT" "Installer IPv4-Source-Spoofing wird geroutet geblockt"

check 'oifname "virbr-safebox" ct state established,related accept' "$NFT" "Nur etablierte Antworten dürfen zum Runtime-Gast"
check '192\.168\.0\.0/16' "$NFT" "Privates 192.168/16 blockiert"
check '10\.0\.0\.0/8' "$NFT" "Privates 10/8 blockiert"
check '172\.16\.0\.0/12' "$NFT" "Privates 172.16/12 blockiert"

exit "$FAIL"
