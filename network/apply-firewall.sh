#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C
if [[ ${EUID} -ne 0 ]]; then exec sudo -- /usr/bin/bash "$0" "$@"; fi
command -v nft >/dev/null || { echo "FEHLER: nft fehlt" >&2; exit 1; }
command -v ip >/dev/null || { echo "FEHLER: ip fehlt" >&2; exit 1; }
command -v python3 >/dev/null || { echo "FEHLER: python3 fehlt" >&2; exit 1; }

addr_dump="$(ip -4 -o addr show)" || { echo 'FEHLER: Host-Adressinventar nicht verfügbar' >&2; exit 1; }
route_dump="$(ip -4 -o route show table all)" || { echo 'FEHLER: Policy-Routing nicht abfragbar' >&2; exit 1; }
mapfile -t host_ips < <(printf '%s\n' "$addr_dump" | awk '{split($4,a,"/"); print a[1]}' | sort -u)
[[ ${#host_ips[@]} -gt 0 ]] || host_ips=(127.0.0.1)
host_list="$(IFS=', '; echo "${host_ips[*]}")"

# Alle direkt am Host angeschlossenen IPv4-Netze werden zusätzlich dynamisch
# gesperrt. Das schützt auch bei VPNs/Firmennetzen mit nicht-RFC1918-Adressen.
# Include policy-routing tables, VPN routes, local/broadcast destinations.
mapfile -t local_routes < <(
  printf '%s\n' "$route_dump" |
    python3 "${SAFEBOX_LIBEXEC:-/usr/local/libexec/safebox}/local-routes.py"
)
local_clause=''
if [[ ${#local_routes[@]} -gt 0 ]]; then
  local_list="$(IFS=', '; echo "${local_routes[*]}")"
  local_clause="elements = { $local_list }"
fi

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
cat >"$tmp" <<NFT
flush table inet safebox_guard
table inet safebox_guard {
  set blocked_v4 { type ipv4_addr; flags interval; elements = { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 192.88.99.0/24, 192.168.0.0/16, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4 } }
  set host_v4 { type ipv4_addr; elements = { $host_list } }
  set local_v4 { type ipv4_addr; flags interval; $local_clause }
  chain input {
    type filter hook input priority -100; policy accept;
    iifname "virbr-safebox" drop
    iifname "virbr-safebox-inst" meta nfproto ipv6 drop
    iifname "virbr-safebox-inst" ip saddr { 0.0.0.0, 10.77.0.100 } udp sport 68 dport 67 accept
    iifname "virbr-safebox-inst" ip saddr 10.77.0.100 ip daddr 10.77.0.1 udp dport 53 accept
    iifname "virbr-safebox-inst" ip saddr 10.77.0.100 ip daddr 10.77.0.1 tcp dport 53 accept
    iifname "virbr-safebox-inst" drop
  }
  chain output {
    type filter hook output priority -100; policy accept;
    oifname "virbr-safebox" meta nfproto ipv6 drop
    oifname "virbr-safebox" ct state established,related accept
    oifname "virbr-safebox" drop
    oifname "virbr-safebox-inst" meta nfproto ipv6 drop
    oifname "virbr-safebox-inst" udp sport 67 dport 68 accept
    oifname "virbr-safebox-inst" ct state established,related accept
    oifname "virbr-safebox-inst" drop
  }
  chain forward {
    type filter hook forward priority -100; policy accept;
    iifname "virbr-safebox" meta nfproto ipv6 drop
    oifname "virbr-safebox" meta nfproto ipv6 drop
    iifname "virbr-safebox-inst" meta nfproto ipv6 drop
    oifname "virbr-safebox-inst" meta nfproto ipv6 drop
    iifname "virbr-safebox" ip saddr != 10.77.0.100 drop
    iifname "virbr-safebox-inst" ip saddr != 10.77.0.100 drop
    iifname "virbr-safebox" ip daddr @blocked_v4 drop
    iifname "virbr-safebox-inst" ip daddr @blocked_v4 drop
    iifname "virbr-safebox" ip daddr @host_v4 drop
    iifname "virbr-safebox-inst" ip daddr @host_v4 drop
    iifname "virbr-safebox" ip daddr @local_v4 drop
    iifname "virbr-safebox-inst" ip daddr @local_v4 drop
    oifname "virbr-safebox" ct state established,related accept
    oifname "virbr-safebox" drop
    oifname "virbr-safebox-inst" ct state established,related accept
    oifname "virbr-safebox-inst" drop
  }
}
NFT
if ! nft -c -f "$tmp" >/dev/null 2>&1; then
  sed -i '/^flush table inet safebox_guard$/d' "$tmp"
  nft -c -f "$tmp" >/dev/null
fi
nft -f "$tmp"

# Exact runtime-policy baseline: hash the complete normalized nftables JSON after
# successful application. Later verification compares the full ruleset, not only
# selected rule fragments. Handles/metainfo are intentionally excluded.
install -d -m 0700 -o root -g root /run/safebox
python3 - /run/safebox/firewall-policy.sha256 <<'PYBASE'
import hashlib,json,subprocess,sys
out=sys.argv[1]
j=json.loads(subprocess.check_output(['nft','-j','list','table','inet','safebox_guard'], text=True))
def clean(x):
    if isinstance(x,dict): return {k:clean(v) for k,v in sorted(x.items()) if k not in {'handle'}}
    if isinstance(x,list): return [clean(v) for v in x]
    return x
j={'nftables':[clean(o) for o in j.get('nftables',[]) if 'metainfo' not in o]}
b=json.dumps(j,sort_keys=True,separators=(',',':')).encode()
open(out,'w').write(hashlib.sha256(b).hexdigest()+'  safebox_guard\n')
PYBASE
chown root:root /run/safebox/firewall-policy.sha256
chmod 0400 /run/safebox/firewall-policy.sha256
