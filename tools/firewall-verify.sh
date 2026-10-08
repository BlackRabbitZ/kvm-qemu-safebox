#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C
SUDO=(); [[ ${EUID} -eq 0 ]] || SUDO=(sudo)
command -v nft >/dev/null || exit 1
command -v ip >/dev/null || exit 1
command -v python3 >/dev/null || exit 1

expected_blocked=('0.0.0.0/8' '10.0.0.0/8' '100.64.0.0/10' '127.0.0.0/8' '169.254.0.0/16' '172.16.0.0/12' '192.0.0.0/24' '192.0.2.0/24' '192.88.99.0/24' '192.168.0.0/16' '198.18.0.0/15' '198.51.100.0/24' '203.0.113.0/24' '224.0.0.0/4' '240.0.0.0/4')

live_txt="$("${SUDO[@]}" nft list table inet safebox_guard 2>/dev/null)" || { echo '[FAIL] safebox_guard fehlt.' >&2; exit 1; }
live_json="$(mktemp)"; trap 'rm -f "$live_json"' EXIT
"${SUDO[@]}" nft -j list table inet safebox_guard >"$live_json"

# Compare the complete normalized ruleset to the root-owned baseline created by
# apply-firewall.sh. This catches rule replacement/reordering/addition even when
# counts and selected text fragments still look valid.
baseline=/run/safebox/firewall-policy.sha256
"${SUDO[@]}" test -r "$baseline" || { echo '[FAIL] Firewall-Baseline fehlt.' >&2; exit 1; }
actual_hash="$(python3 - "$live_json" <<'PYHASH'
import hashlib,json,sys
j=json.load(open(sys.argv[1]))
def clean(x):
    if isinstance(x,dict): return {k:clean(v) for k,v in sorted(x.items()) if k not in {'handle'}}
    if isinstance(x,list): return [clean(v) for v in x]
    return x
j={'nftables':[clean(o) for o in j.get('nftables',[]) if 'metainfo' not in o]}
b=json.dumps(j,sort_keys=True,separators=(',',':')).encode()
print(hashlib.sha256(b).hexdigest())
PYHASH
)"
# awk script uses its own $n fields, which must remain literal.
# shellcheck disable=SC2016
expected_hash="$("${SUDO[@]}" awk '{print $1; exit}' "$baseline")"
[[ "$actual_hash" == "$expected_hash" ]] || { echo '[FAIL] Komplette nftables-Policy weicht von der installierten Baseline ab.' >&2; exit 1; }

# Vollständige Objekt-/Regelzählung: keine zusätzlichen Chains, Sets oder Regeln.
python3 - "$live_json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))['nftables']
allowed={'table','set','chain','rule','metainfo'}
for obj in j:
    extra=set(obj)-allowed
    if extra:
        raise SystemExit(f'[FAIL] Unerwartetes nftables-Objekt: {sorted(extra)}')
sets=[o['set']['name'] for o in j if 'set' in o]
chains=[o['chain']['name'] for o in j if 'chain' in o]
if sorted(sets)!=sorted(['blocked_v4','host_v4','local_v4']):
    raise SystemExit(f'[FAIL] Unerwartete Sets: {sets}')
if sorted(chains)!=sorted(['input','output','forward']):
    raise SystemExit(f'[FAIL] Unerwartete Chains: {chains}')
counts={c:0 for c in chains}
for o in j:
    if 'rule' in o: counts[o['rule']['chain']]=counts.get(o['rule']['chain'],0)+1
expected={'input':6,'output':7,'forward':16}
if counts!=expected:
    raise SystemExit(f'[FAIL] Unerwartete Regelanzahl: {counts}, erwartet {expected}')
PY

extract_ipv4(){
  local setname=$1
  "${SUDO[@]}" nft list set inet safebox_guard "$setname" 2>/dev/null |
    grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' | sort -u
}

mapfile -t got_blocked < <(extract_ipv4 blocked_v4)
printf '%s\n' "${expected_blocked[@]}" | sort -u >"$live_json.expected"
printf '%s\n' "${got_blocked[@]}" | sort -u >"$live_json.got"
cmp -s "$live_json.expected" "$live_json.got" || { echo '[FAIL] blocked_v4 weicht von der Soll-Policy ab.' >&2; rm -f "$live_json.expected" "$live_json.got"; exit 1; }
rm -f "$live_json.expected" "$live_json.got"

addr_dump="$(ip -4 -o addr show)" || { echo '[FAIL] Host-Adressen nicht ermittelbar' >&2; exit 1; }
route_dump="$(ip -4 -o route show table all)" || { echo '[FAIL] Policy-Routen nicht ermittelbar' >&2; exit 1; }
# Literal embedded program/test syntax: $ belongs to that program, not Bash.
# shellcheck disable=SC2016
mapfile -t expected_hosts < <(printf '%s\n' "$addr_dump" | awk '{split($4,a,"/"); print a[1]}' | sort -u)
mapfile -t got_hosts < <(extract_ipv4 host_v4 | sed 's#/32$##')
[[ "$(printf '%s\n' "${expected_hosts[@]}" | sort -u)" == "$(printf '%s\n' "${got_hosts[@]}" | sort -u)" ]] || { echo '[FAIL] host_v4 ist nicht exakt aktuell.' >&2; exit 1; }

mapfile -t expected_local < <(
  printf '%s\n' "$route_dump" |
    python3 "${SAFEBOX_LIBEXEC:-/usr/local/libexec/safebox}/local-routes.py"
)
mapfile -t got_local < <(extract_ipv4 local_v4)
[[ "$(printf '%s\n' "${expected_local[@]}" | sort -u)" == "$(printf '%s\n' "${got_local[@]}" | sort -u)" ]] || { echo '[FAIL] local_v4 ist nicht exakt aktuell.' >&2; exit 1; }

expected_rules=(
'iifname "virbr-safebox" drop'
'iifname "virbr-safebox-inst" meta nfproto ipv6 drop'
'iifname "virbr-safebox-inst" ip saddr { 0.0.0.0, 10.77.0.100 } udp sport 68 dport 67 accept'
'iifname "virbr-safebox-inst" ip saddr 10.77.0.100 ip daddr 10.77.0.1 udp dport 53 accept'
'iifname "virbr-safebox-inst" ip saddr 10.77.0.100 ip daddr 10.77.0.1 tcp dport 53 accept'
'iifname "virbr-safebox-inst" drop'
'oifname "virbr-safebox" meta nfproto ipv6 drop'
'oifname "virbr-safebox" ct state established,related accept'
'oifname "virbr-safebox" drop'
'oifname "virbr-safebox-inst" meta nfproto ipv6 drop'
'oifname "virbr-safebox-inst" udp sport 67 dport 68 accept'
'oifname "virbr-safebox-inst" ct state established,related accept'
'oifname "virbr-safebox-inst" drop'
'iifname "virbr-safebox" meta nfproto ipv6 drop'
'oifname "virbr-safebox" meta nfproto ipv6 drop'
'iifname "virbr-safebox" ip saddr != 10.77.0.100 drop'
'iifname "virbr-safebox-inst" ip saddr != 10.77.0.100 drop'
'iifname "virbr-safebox" ip daddr @blocked_v4 drop'
'iifname "virbr-safebox-inst" ip daddr @blocked_v4 drop'
'iifname "virbr-safebox" ip daddr @host_v4 drop'
'iifname "virbr-safebox-inst" ip daddr @host_v4 drop'
'iifname "virbr-safebox" ip daddr @local_v4 drop'
'iifname "virbr-safebox-inst" ip daddr @local_v4 drop'
'oifname "virbr-safebox-inst" ct state established,related accept'
)
for rule in "${expected_rules[@]}"; do
  grep -Fq "$rule" <<<"$live_txt" || { echo "[FAIL] Firewall-Regel fehlt: $rule" >&2; exit 1; }
done

echo '[PASS] SafeBox-Firewall vollständig und ohne zusätzliche Regeln bestätigt.'
