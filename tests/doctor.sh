#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/config/defaults.conf"

PASS=0; WARN=0; FAIL=0
ok(){ printf '\033[32m[OK]\033[0m   %s\n' "$*"; PASS=$((PASS+1)); }
warn(){ printf '\033[33m[WARN]\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
bad(){ printf '\033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }

if [[ -e /dev/kvm ]]; then ok "/dev/kvm vorhanden"; else bad "/dev/kvm fehlt – Virtualisierung im BIOS/UEFI prüfen"; fi
if command -v qemu-system-x86_64 >/dev/null; then ok "QEMU vorhanden"; else bad "QEMU fehlt"; fi
if command -v virsh >/dev/null; then ok "virsh vorhanden"; else bad "virsh fehlt"; fi
if command -v nft >/dev/null; then ok "nftables vorhanden"; else bad "nftables fehlt"; fi

if command -v aa-status >/dev/null 2>&1; then
  if aa-status --enabled >/dev/null 2>&1; then ok "AppArmor aktiviert"; else warn "AppArmor installiert, aber nicht aktiviert"; fi
else
  warn "aa-status nicht vorhanden"
fi

if command -v qemu-system-x86_64 >/dev/null 2>&1; then
  if qemu-system-x86_64 -sandbox help >/dev/null 2>&1; then ok "QEMU seccomp/-sandbox unterstützt"; else warn "QEMU -sandbox konnte nicht bestätigt werden"; fi
fi

if command -v virsh >/dev/null 2>&1; then
  CAPS="$(virsh -c "$SAFEBOX_CONNECT_URI" capabilities 2>/dev/null || true)"
  if grep -q '<model>apparmor</model>' <<<"$CAPS"; then
    ok "libvirt meldet AppArmor als Security Model"
  elif grep -q '<model>selinux</model>' <<<"$CAPS"; then
    ok "libvirt meldet SELinux als Security Model"
  else
    warn "Kein libvirt MAC-Security-Model (AppArmor/SELinux) bestätigt"
  fi
fi

if virsh -c "$SAFEBOX_CONNECT_URI" net-info "$SAFEBOX_NETWORK" >/dev/null 2>&1; then
  if virsh -c "$SAFEBOX_CONNECT_URI" net-info "$SAFEBOX_NETWORK" 2>/dev/null | grep -qE 'Active:[[:space:]]+yes|Aktiv:[[:space:]]+ja'; then
    ok "SafeBox-Netz aktiv"
  else
    warn "SafeBox-Netz definiert, aber nicht aktiv"
  fi
else
  warn "SafeBox-Netz noch nicht definiert"
fi

if sudo -n nft list table inet safebox_guard >/dev/null 2>&1 || nft list table inet safebox_guard >/dev/null 2>&1; then
  ok "Host-Firewall safebox_guard aktiv"
else
  warn "safebox_guard nicht bestätigt (ggf. sudo-Recht oder setup-network ausführen)"
fi

if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled safebox-firewall.service >/dev/null 2>&1; then
  ok "SafeBox-Firewall für Host-Neustarts aktiviert"
else
  warn "Persistenter safebox-firewall.service nicht bestätigt"
fi

if [[ -f "$SAFEBOX_BASE_IMAGE" ]]; then
  ok "Basis-Image vorhanden"
  MODE="$(stat -c '%a' "$SAFEBOX_BASE_IMAGE" 2>/dev/null || true)"
  OWNER="$(stat -c '%U' "$SAFEBOX_BASE_IMAGE" 2>/dev/null || true)"
  if [[ "$MODE" == "440" ]]; then ok "Basis-Image ist Mode 0440"; else warn "Basis-Image ist nicht Mode 0440"; fi
  if [[ "$OWNER" == "root" ]]; then ok "Basis-Image gehört root"; else warn "Basis-Image gehört nicht root"; fi
else
  warn "Basis-Image noch nicht erstellt"
fi

if "$ROOT/tests/static-policy.sh" >/dev/null && "$ROOT/tests/network-policy.sh" >/dev/null; then
  ok "Statische VM-/Netzwerk-Sicherheitsrichtlinien bestanden"
else
  bad "Statische VM-/Netzwerk-Sicherheitsrichtlinie fehlgeschlagen"
fi

printf '\nErgebnis: %d OK, %d Warnungen, %d Fehler\n' "$PASS" "$WARN" "$FAIL"
[[ "$FAIL" -eq 0 ]]
