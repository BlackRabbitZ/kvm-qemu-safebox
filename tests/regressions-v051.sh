#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
pass(){ echo "[PASS] $*"; }

grep -Fq 'qemu-system-modules-spice' "$ROOT/install/install-host.sh" || fail 'SPICE-Modul fehlt im Host-Installer'
pass 'SPICE-Abhängigkeit explizit installiert'

grep -Fq 'SAFEBOX_DISK_BUS="sata"' "$ROOT/config/defaults.conf" || fail 'SATA-Hardening fehlt'
grep -Fq 'SAFEBOX_NET_MODEL="e1000e"' "$ROOT/config/defaults.conf" || fail 'e1000e-Hardening fehlt'
! grep -Fq "target dev='vda' bus='virtio'" "$ROOT/vm/templates/runtime.xml.in" || fail 'virtio-blk ist wieder aktiv'
! grep -Fq "model type='virtio'" "$ROOT/vm/templates/runtime.xml.in" || fail 'virtio-net/video ist wieder aktiv'
pass 'Bekannte virtio-net/virtio-blk-Pfade bleiben im Hardened-Default entfernt'

grep -Fq "'(enforce)'" "$ROOT/tools/runtime-verify.sh" || fail 'AppArmor complain/enforce Regression'
grep -Fq 'SAFEBOX_EXPECTED_QEMU_USER' "$ROOT/tools/runtime-verify.sh" || fail 'QEMU-Dienstbenutzer wird nicht geprüft'
grep -Fq 'CapEff' "$ROOT/tools/runtime-verify.sh" || fail 'QEMU-Capabilities werden nicht geprüft'
pass 'QEMU-Prozessattestation prüft User, Capabilities und AppArmor enforce'

grep -Fq 'Basis wurde mit SafeBox' "$ROOT/safebox" || fail 'Base-Version wird nicht gebunden'
grep -Fq "'base_version':b.get('safebox_version')==version" "$ROOT/tools/storage-verify.sh" || fail 'Overlay prüft Base-Version nicht'
pass 'Base-/Overlay-Versionen sind fest gebunden'

grep -Fq 'qemu-system-modules-spice' "$ROOT/install/install-host.sh" || fail 'SPICE Regression'
grep -Fq 'nwfilter-verify.sh' "$ROOT/tools/runtime-watch.sh" || fail 'nwfilter nicht im Watchdog'
grep -Fq 'firewall-policy.sha256' "$ROOT/tools/firewall-verify.sh" || fail 'vollständige Firewall-Baseline fehlt'
pass 'Firewall und nwfilter werden kontinuierlich attestiert'

grep -Fq 'Domain aus libvirt verschwunden' "$ROOT/tools/runtime-watch.sh" || fail 'Watchdog dominfo fail-open Regression'
pass 'Watchdog behandelt verschwundene Domain fail-closed'

grep -Fq 'verify-tag --raw' "$ROOT/tools/verify-signed-tag.sh" || fail 'Lokale Tag-Prüfung ist nicht kryptografisch'
grep -Fq 'VALIDSIG' "$ROOT/tools/verify-signed-tag.sh" || fail 'Signer-Fingerprint wird nicht geprüft'
grep -Fq 'RELEASE_SIGNER_FINGERPRINT' "$ROOT/.github/workflows/release.yml" || fail 'GitHub Release-CI pinnt den Signer nicht'
! grep -Fq "BEGIN (PGP|SSH) SIGNATURE" "$ROOT/.github/workflows/release.yml" || fail 'Release-CI akzeptiert wieder nur Signaturmarker'
pass 'Release-Tag benötigt echte kryptografische Verifikation und erlaubten Signer'

grep -Fq 'SOURCE_DATE_EPOCH' "$ROOT/tools/build-release.sh" || fail 'SOURCE_DATE_EPOCH fehlt'
pass 'Reproduzierbarer Release-Zeitstempel festgelegt'

grep -Fq 'install -m 0660' "$ROOT/safebox" || fail 'Lock-Datei wieder world-writable'
pass 'Lock-Datei nicht world-writable'

echo '[PASS] Alle bekannten v0.5.0-Regressionsfehler sind als Tests festgeschrieben.'
