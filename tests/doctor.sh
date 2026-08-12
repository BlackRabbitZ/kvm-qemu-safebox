#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/config/defaults.conf"

SUDO=(); [[ ${EUID} -eq 0 ]] || SUDO=(sudo)
PASS=0; WARN=0; FAIL=0
ok(){ printf '\033[32m[OK]\033[0m   %s\n' "$*"; PASS=$((PASS+1)); }
warn(){ printf '\033[33m[WARN]\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
bad(){ printf '\033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }

for cmd in qemu-system-x86_64 qemu-img virsh nft xmllint jq sha256sum aa-status pgrep; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd vorhanden"
  else
    bad "$cmd fehlt"
  fi
done

if [[ -e /dev/kvm ]]; then
  ok "/dev/kvm vorhanden"
else
  bad "/dev/kvm fehlt – Hardwarevirtualisierung prüfen"
fi

if command -v aa-status >/dev/null 2>&1 && aa-status --enabled >/dev/null 2>&1; then
  ok "AppArmor aktiviert"
else
  bad "AppArmor ist nicht aktiv"
fi

if command -v qemu-system-x86_64 >/dev/null 2>&1 && qemu-system-x86_64 -sandbox help >/dev/null 2>&1; then
  ok "QEMU unterstützt die seccomp-Sandbox"
else
  bad "QEMU-seccomp/-sandbox konnte nicht bestätigt werden"
fi

if [[ -f "$SAFEBOX_QEMU_CONF" ]]; then
  conf="$("${SUDO[@]}" cat "$SAFEBOX_QEMU_CONF" 2>/dev/null || true)"
  if grep -Eq '^security_driver[[:space:]]*=[[:space:]]*"apparmor"[[:space:]]*$' <<<"$conf"; then
    ok "qemu.conf erzwingt AppArmor"
  else
    bad "qemu.conf: security_driver=apparmor fehlt"
  fi
  if grep -Eq '^security_default_confined[[:space:]]*=[[:space:]]*1[[:space:]]*$' <<<"$conf"; then
    ok "QEMU-Gäste standardmäßig confined"
  else
    bad "security_default_confined=1 fehlt"
  fi
  if grep -Eq '^security_require_confined[[:space:]]*=[[:space:]]*1[[:space:]]*$' <<<"$conf"; then
    ok "Unconfined QEMU-Gäste werden abgelehnt"
  else
    bad "security_require_confined=1 fehlt"
  fi
  if grep -Eq '^seccomp_sandbox[[:space:]]*=[[:space:]]*1[[:space:]]*$' <<<"$conf"; then
    ok "QEMU-seccomp hostweit aktiviert"
  else
    bad "seccomp_sandbox=1 fehlt"
  fi
  if grep -Eq '^max_core[[:space:]]*=[[:space:]]*0[[:space:]]*$' <<<"$conf"; then
    ok "QEMU-Core-Dumps deaktiviert"
  else
    bad "max_core=0 fehlt"
  fi
  if grep -Eq '^dump_guest_core[[:space:]]*=[[:space:]]*0[[:space:]]*$' <<<"$conf"; then
    ok "Gast-RAM in QEMU-Core-Dumps deaktiviert"
  else
    bad "dump_guest_core=0 fehlt"
  fi
else
  bad "$SAFEBOX_QEMU_CONF fehlt"
fi

qemu_account=""
for u in libvirt-qemu qemu; do
  if id -u "$u" >/dev/null 2>&1; then qemu_account="$u"; break; fi
done
if [[ -n "$qemu_account" && "$(id -u "$qemu_account")" != 0 ]]; then
  ok "Dedizierter non-root QEMU-Benutzer vorhanden: $qemu_account"
else
  bad "Kein dedizierter non-root QEMU-Dienstbenutzer gefunden"
fi

if command -v virsh >/dev/null 2>&1; then
  caps="$("${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" capabilities 2>/dev/null || true)"
  if grep -q '<model>apparmor</model>' <<<"$caps"; then
    ok "libvirt meldet AppArmor als Security Model"
  else
    bad "libvirt-AppArmor-Security-Model nicht bestätigt"
  fi

  clean="$("${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" nwfilter-dumpxml clean-traffic 2>/dev/null || true)"
  if [[ -n "$clean" ]] && grep -q "filter='no-mac-spoofing'" <<<"$clean" && grep -q "filter='no-ip-spoofing'" <<<"$clean" && grep -q "filter='no-arp-spoofing'" <<<"$clean"; then
    ok "libvirt clean-traffic Anti-Spoofing-Filter vorhanden"
  else
    bad "libvirt clean-traffic Filter fehlt/unvollständig"
  fi

  [[ -n "$clean" ]] && ok "SafeBox verwendet direkt libvirt clean-traffic"
fi

if "${SUDO[@]}" nft list table inet safebox_guard >/dev/null 2>&1; then
  live="$("${SUDO[@]}" nft list table inet safebox_guard)"
  if grep -Fq 'iifname "virbr-safebox" meta nfproto ipv6 drop' <<<"$live"; then
    ok "Runtime-IPv6 Gast->Host blockiert"
  else
    bad "Runtime IPv6-DROP fehlt"
  fi
  if grep -Fq 'oifname "virbr-safebox" meta nfproto ipv6 drop' <<<"$live"; then
    ok "Runtime-IPv6 Host->Gast blockiert"
  else
    bad "Runtime IPv6-DROP Richtung Gast fehlt"
  fi
  if grep -Fq 'iifname "virbr-safebox" drop' <<<"$live"; then
    ok "Runtime-Gast->Host vollständig geblockt"
  else
    bad "Runtime Gast->Host-DROP fehlt"
  fi
  if grep -Fq 'iifname "virbr-safebox" ip saddr != 10.77.0.100 drop' <<<"$live"; then
    ok "Runtime IPv4 Source-Spoofing hostseitig blockiert"
  else
    bad "Runtime IPv4 Source-Spoofing-Regel fehlt"
  fi
  if grep -Fq 'iifname "virbr-safebox-inst" drop' <<<"$live"; then
    ok "Installer-Gast->Host standardmäßig geblockt"
  else
    bad "Installer Gast->Host-DROP fehlt"
  fi
else
  bad "safebox_guard ist nicht aktiv"
fi

if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled safebox-firewall.service >/dev/null 2>&1 && systemctl is-active --quiet safebox-firewall.service; then
  ok "Persistenter SafeBox-Firewall-Service aktiv"
else
  bad "safebox-firewall.service nicht aktiv/aktiviert"
fi

if "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" net-info "$SAFEBOX_NETWORK" >/dev/null 2>&1; then
  tmp="$(mktemp)"
  "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" net-dumpxml "$SAFEBOX_NETWORK" > "$tmp"
  if [[ "$(xmllint --xpath 'string(/network/forward/@mode)' "$tmp" 2>/dev/null)" == nat \
     && "$(xmllint --xpath 'string(/network/bridge/@name)' "$tmp" 2>/dev/null)" == "$SAFEBOX_BRIDGE" \
     && "$(xmllint --xpath 'string(/network/port/@isolated)' "$tmp" 2>/dev/null)" == yes \
     && "$(xmllint --xpath 'count(/network/ip)' "$tmp" 2>/dev/null)" == 1 \
     && "$(xmllint --xpath 'count(/network/ip/dhcp)' "$tmp" 2>/dev/null)" == 0 \
     && "$(xmllint --xpath 'count(/network/dns[@enable="no"])' "$tmp" 2>/dev/null)" == 1 ]]; then
    ok "Runtime-libvirt-Netz: NAT, statisch, ohne Host-DHCP/DNS"
  else
    bad "Runtime-libvirt-Netz weicht von der SafeBox-Policy ab"
  fi
  rm -f "$tmp"

  if "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" net-info "$SAFEBOX_NETWORK" 2>/dev/null | grep -qE '^Active:[[:space:]]+yes$'; then
    if pgrep -af '[d]nsmasq' 2>/dev/null | grep -Fq "/$SAFEBOX_NETWORK.conf"; then
      bad "Unerwarteter dnsmasq-Prozess am Runtime-Netz"
    else
      ok "Kein dnsmasq-Prozess am aktiven Runtime-Netz"
    fi
  fi
else
  warn "Runtime-Netz noch nicht definiert – wird beim ersten Online-Start angelegt"
fi

if "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" net-info "$SAFEBOX_INSTALL_NETWORK_NAME" >/dev/null 2>&1; then
  tmp="$(mktemp)"
  "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" net-dumpxml "$SAFEBOX_INSTALL_NETWORK_NAME" > "$tmp"
  if [[ "$(xmllint --xpath 'string(/network/bridge/@name)' "$tmp" 2>/dev/null)" == "$SAFEBOX_INSTALL_BRIDGE" \
     && "$(xmllint --xpath 'string(/network/ip/dhcp/host/@ip)' "$tmp" 2>/dev/null)" == "$SAFEBOX_GUEST_IP" ]]; then
    if "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" net-info "$SAFEBOX_INSTALL_NETWORK_NAME" 2>/dev/null | grep -qE '^Active:[[:space:]]+yes$'; then
      warn "Installationsnetz ist aktiv – korrekt nur während create-base/Installation"
    else
      warn "Installationsnetz ist noch definiert, aber inaktiv – seal-base entfernt es"
    fi
  else
    bad "Definiertes Installationsnetz weicht von der erwarteten Policy ab"
  fi
  rm -f "$tmp"
else
  ok "Installationsnetz ist außerhalb der Installation nicht vorhanden"
fi

if [[ -f "$SAFEBOX_BASE_IMAGE" ]]; then
  if [[ "$("${SUDO[@]}" stat -c '%a' "$SAFEBOX_BASE_IMAGE" 2>/dev/null)" == 440 ]]; then
    ok "Basis-Image Mode 0440"
  else
    bad "Basis-Image ist nicht Mode 0440"
  fi
  if [[ "$("${SUDO[@]}" stat -c '%U' "$SAFEBOX_BASE_IMAGE" 2>/dev/null)" == root ]]; then
    ok "Basis-Image gehört root"
  else
    bad "Basis-Image gehört nicht root"
  fi
  if [[ -f "$SAFEBOX_BASE_HASH" ]] && "${SUDO[@]}" sha256sum -c "$SAFEBOX_BASE_HASH" >/dev/null 2>&1; then
    ok "SHA-256-Siegel des Basis-Images gültig"
  else
    bad "SHA-256-Siegel des Basis-Images fehlt/ist ungültig"
  fi
else
  warn "Basis-Image noch nicht erstellt"
fi

if bash "$ROOT/tests/static-policy.sh" >/dev/null && bash "$ROOT/tests/network-policy.sh" >/dev/null && bash "$ROOT/tests/render-smoke.sh" >/dev/null; then
  ok "Statische VM-/Netzwerk-/Render-Policies bestanden"
else
  bad "Statische Sicherheitsprüfung fehlgeschlagen"
fi

running="$("${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" list --name 2>/dev/null | grep -E '^safebox-' || true)"
if [[ -n "$running" ]]; then
  while IFS= read -r domain; do
    [[ -n "$domain" ]] || continue
    if bash "$ROOT/tools/runtime-verify.sh" "$domain" auto >/dev/null; then
      ok "Runtime-Attestation bestanden: $domain"
    else
      bad "Runtime-Attestation fehlgeschlagen: $domain"
    fi
  done <<<"$running"
else
  warn "Keine laufende SafeBox-Domain – Runtime-Attestation aktuell nicht ausführbar"
fi

printf '\nErgebnis: %d OK, %d Warnungen, %d Fehler\n' "$PASS" "$WARN" "$FAIL"
[[ "$FAIL" -eq 0 ]]
