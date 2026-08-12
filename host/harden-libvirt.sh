#!/usr/bin/env bash
set -Eeuo pipefail

QEMU_CONF="${SAFEBOX_QEMU_CONF:-/etc/libvirt/qemu.conf}"
BEGIN_MARK='# BEGIN KVM-QEMU-SafeBox managed hardening'
END_MARK='# END KVM-QEMU-SafeBox managed hardening'

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

command -v systemctl >/dev/null || { echo 'FEHLER: systemd wird benötigt.' >&2; exit 1; }
command -v virsh >/dev/null || { echo 'FEHLER: virsh fehlt.' >&2; exit 1; }
command -v aa-status >/dev/null || { echo 'FEHLER: aa-status fehlt.' >&2; exit 1; }
[[ -f "$QEMU_CONF" ]] || { echo "FEHLER: $QEMU_CONF fehlt." >&2; exit 1; }

aa-status --enabled >/dev/null 2>&1 || {
  echo 'FEHLER: AppArmor ist nicht aktiviert. SafeBox verweigert unconfined QEMU.' >&2
  exit 1
}

# Vor dem Schreiben festlegen, welche Daemon-Architektur tatsächlich verwendet
# wird. SafeBox startet nicht parallel monolithische und modulare QEMU-Daemons.
libvirt_unit=''
if systemctl is-active --quiet virtqemud.service || systemctl is-active --quiet virtqemud.socket; then
  libvirt_unit='virtqemud.service'
elif systemctl is-active --quiet libvirtd.service || systemctl is-active --quiet libvirtd.socket; then
  libvirt_unit='libvirtd.service'
elif systemctl list-unit-files libvirtd.socket 2>/dev/null | grep -q '^libvirtd\.socket'; then
  systemctl enable --now libvirtd.socket
  libvirt_unit='libvirtd.service'
else
  echo 'FEHLER: Keine unterstützte libvirt-Systeminstanz gefunden.' >&2
  exit 1
fi

backup="${QEMU_CONF}.safebox-backup-$(date +%Y%m%d-%H%M%S)"
cp -a -- "$QEMU_CONF" "$backup"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

rollback() {
  local reason=$1
  cp -a -- "$backup" "$QEMU_CONF"
  if ! systemctl restart "$libvirt_unit"; then
    echo "KRITISCH: Backup wurde restauriert, aber $libvirt_unit konnte danach nicht neu gestartet werden." >&2
  fi
  echo "FEHLER: $reason Vorherige qemu.conf restauriert: $backup" >&2
  exit 1
}

# Vorhandenen SafeBox-Block und aktive Varianten aller verwalteten Einstellungen
# entfernen. Danach gibt es genau einen autoritativen Block am Dateiende.
awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
  $0 == begin { managed=1; next }
  $0 == end   { managed=0; next }
  managed { next }
  /^[[:space:]]*(security_driver|security_default_confined|security_require_confined|seccomp_sandbox|max_core|dump_guest_core)[[:space:]]*=/ { next }
  { print }
' "$QEMU_CONF" > "$tmp"

cat >> "$tmp" <<'BLOCK'

# BEGIN KVM-QEMU-SafeBox managed hardening
# Debian-Zielprofil: QEMU muss per AppArmor confined laufen.
security_driver = "apparmor"
security_default_confined = 1
security_require_confined = 1
# QEMUs eingebaute seccomp-Sandbox darf nicht deaktiviert werden.
seccomp_sandbox = 1
# Keine QEMU-Core-Dumps mit potenziell sensitiven Prozess-/Gastdaten.
max_core = 0
dump_guest_core = 0
# END KVM-QEMU-SafeBox managed hardening
BLOCK

install -m 0644 -o root -g root "$tmp" "$QEMU_CONF"

if ! systemctl restart "$libvirt_unit"; then
  rollback "libvirt konnte mit der Hardening-Konfiguration nicht neu geladen werden."
fi

conf="$(cat "$QEMU_CONF")" || rollback "qemu.conf konnte nach dem Schreiben nicht gelesen werden."
if ! grep -Eq '^security_driver[[:space:]]*=[[:space:]]*"apparmor"[[:space:]]*$' <<<"$conf" ||
   ! grep -Eq '^security_default_confined[[:space:]]*=[[:space:]]*1[[:space:]]*$' <<<"$conf" ||
   ! grep -Eq '^security_require_confined[[:space:]]*=[[:space:]]*1[[:space:]]*$' <<<"$conf" ||
   ! grep -Eq '^seccomp_sandbox[[:space:]]*=[[:space:]]*1[[:space:]]*$' <<<"$conf" ||
   ! grep -Eq '^max_core[[:space:]]*=[[:space:]]*0[[:space:]]*$' <<<"$conf" ||
   ! grep -Eq '^dump_guest_core[[:space:]]*=[[:space:]]*0[[:space:]]*$' <<<"$conf"; then
  rollback "Die geschriebenen Hardening-Werte konnten nicht exakt verifiziert werden."
fi

if ! caps="$(virsh -c qemu:///system capabilities 2>/dev/null)"; then
  rollback "libvirt-Capabilities konnten nach der Härtung nicht gelesen werden."
fi
if ! grep -q '<model>apparmor</model>' <<<"$caps"; then
  rollback "libvirt meldet nach der Härtung kein AppArmor-Security-Model."
fi

echo '[OK] libvirt/QEMU-Härtung aktiv: AppArmor verpflichtend, unconfined Gäste verboten, seccomp aktiv, Core-Dumps aus.'
echo "[INFO] Backup der vorherigen qemu.conf: $backup"
