#!/usr/bin/env bash
# Innerhalb der laufenden SafeBox ausführen.
set -uo pipefail

PASS=0; FAIL=0; WARN=0
ok(){ printf '\033[32m[PASS]\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad(){ printf '\033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
warn(){ printf '\033[33m[WARN]\033[0m %s\n' "$*"; WARN=$((WARN+1)); }

GATEWAY="$(ip -4 route show default 2>/dev/null | awk 'NR==1 {print $3}')"
if [[ -z "$GATEWAY" ]]; then
  bad "Kein IPv4-Default-Gateway gefunden."
else
  ok "Default-Gateway vorhanden: $GATEWAY"
fi

if command -v curl >/dev/null 2>&1; then
  if curl -fsS --connect-timeout 5 --max-time 10 https://deb.debian.org/ >/dev/null; then
    ok "Öffentliches Internet per HTTPS erreichbar."
  else
    bad "Öffentliches Internet per HTTPS nicht erreichbar."
  fi

  # Die Guard-Regel soll private Ziele nicht erreichbar machen. Ein HTTP-Fehler
  # oder Timeout gilt hier als gewünschtes Ergebnis. Dieser Test sendet keine Daten.
  if curl -fsS --connect-timeout 2 --max-time 3 http://192.168.1.1/ >/dev/null 2>&1; then
    bad "Privates Ziel 192.168.1.1 ist erreichbar – Host-Guard prüfen!"
  else
    ok "Privates Ziel 192.168.1.1 ist nicht erreichbar."
  fi
else
  warn "curl fehlt; Internet-/LAN-Test übersprungen."
fi

if [[ -n "$GATEWAY" ]]; then
  # Host-Port 22 darf aus der VM nicht erreichbar sein. /dev/tcp ist Bash-intern.
  if timeout 2 bash -c "</dev/tcp/$GATEWAY/22" >/dev/null 2>&1; then
    bad "Host-Gateway TCP/22 ist erreichbar – Gast→Host-Guard prüfen!"
  else
    ok "Host-Gateway TCP/22 nicht erreichbar."
  fi
fi

printf '\nErgebnis: %d PASS, %d WARN, %d FAIL\n' "$PASS" "$WARN" "$FAIL"
[[ "$FAIL" -eq 0 ]]
