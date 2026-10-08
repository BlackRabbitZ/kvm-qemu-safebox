#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
PASS=0; FAIL=0
ok(){ echo "[PASS] $*"; PASS=$((PASS+1)); }
bad(){ echo "[FAIL] $*" >&2; FAIL=$((FAIL+1)); }
# Literal embedded program/test syntax: $ belongs to that program, not Bash.
# shellcheck disable=SC2016
IP="$(ip -4 -o addr show scope global | awk '{split($4,a,"/"); print a[1]; exit}')"
# Literal embedded program/test syntax: $ belongs to that program, not Bash.
# shellcheck disable=SC2016
GW="$(ip -4 route show default | awk '{print $3; exit}')"
if [[ "$IP" == 10.77.0.100 ]]; then ok "Statische IP: $IP"; else bad "Erwartet 10.77.0.100, gefunden ${IP:-keine}"; fi
if [[ "$GW" == 10.77.0.1 ]]; then ok "Gateway: $GW"; else bad "Erwartet 10.77.0.1, gefunden ${GW:-keines}"; fi
if curl -fsS --max-time 8 https://deb.debian.org/ >/dev/null; then ok 'Öffentliches HTTPS funktioniert'; else bad 'Öffentliches HTTPS fehlgeschlagen'; fi
if command -v nft >/dev/null 2>&1 && nft list table inet safebox_guest >/dev/null 2>&1; then
  live="$(nft list table inet safebox_guest)"
  if grep -Fq 'ip daddr @blocked_v4 drop' <<<"$live"; then ok 'Gast-Firewall blockiert private/reservierte IPv4-Ziele'; else bad 'Gast-Firewall-Regel fehlt'; fi
  if grep -Fq 'meta nfproto ipv6 drop' <<<"$live"; then ok 'Gast-Firewall blockiert IPv6'; else bad 'IPv6-Drop-Regel fehlt'; fi
else
  bad 'SafeBox-Gast-Firewall nicht aktiv'
fi
if ip -6 route show default | grep -q .; then bad 'IPv6-Default-Route vorhanden'; else ok 'Keine IPv6-Default-Route'; fi
printf '\nGast-Netzwerktest: %d PASS, %d FAIL\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
