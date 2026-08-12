#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${1:-$SCRIPT_DIR/safebox-guard.nft}"

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

command -v nft >/dev/null || { echo "FEHLER: nftables ist nicht installiert." >&2; exit 1; }
[[ -r "$RULES_FILE" ]] || { echo "FEHLER: Regeldatei fehlt: $RULES_FILE" >&2; exit 1; }

if nft list table inet safebox_guard >/dev/null 2>&1; then
  # Löschen + Neuaufbau in EINER nft-Transaktion. Die Vorprüfung bewertet
  # exakt dieselbe Transaktion gegen das Live-Ruleset.
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  {
    echo 'delete table inet safebox_guard'
    sed '1{/^#!/d;}' "$RULES_FILE"
  } > "$tmp"
  nft -c -f "$tmp"
  nft -f "$tmp"
else
  nft -c -f "$RULES_FILE"
  nft -f "$RULES_FILE"
fi

live="$(nft list table inet safebox_guard)"
for rule in \
  'iifname "virbr-safebox" meta nfproto ipv6 drop' \
  'oifname "virbr-safebox" meta nfproto ipv6 drop' \
  'iifname "virbr-safebox" drop' \
  'oifname "virbr-safebox" drop' \
  'iifname "virbr-safebox" ip saddr != 10.77.0.100 drop' \
  'iifname "virbr-safebox-inst" meta nfproto ipv6 drop' \
  'oifname "virbr-safebox-inst" meta nfproto ipv6 drop' \
  'iifname "virbr-safebox-inst" drop' \
  'oifname "virbr-safebox-inst" drop' \
  'iifname "virbr-safebox-inst" ip saddr != 10.77.0.100 drop'; do
  grep -Fq "$rule" <<<"$live" || { echo "FEHLER: Pflichtregel fehlt nach Firewall-Ladevorgang: $rule" >&2; exit 1; }
done

echo "[OK] nftables-Tabelle inet/safebox_guard atomar geladen und verifiziert."
