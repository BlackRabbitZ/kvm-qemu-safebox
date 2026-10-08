#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }; pass(){ echo "[PASS] $*"; }

# Permission regression: demonstrate why unprivileged -f/-d is invalid for root-owned 0750 storage,
# then require privileged tests in all previously affected paths.
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir "$T/protected"; touch "$T/protected/persistent.qcow2"; chmod 0750 "$T/protected"
if command -v runuser >/dev/null && id nobody >/dev/null 2>&1; then
  if runuser -u nobody -- test -f "$T/protected/persistent.qcow2" 2>/dev/null; then fail 'Testfixture: nobody konnte unerwartet geschützte Datei statten'; fi
fi
# shellcheck disable=SC2016 -- Verbatim-Codefragment: absichtlich keine Variablenexpansion.
grep -Fq 'set_qemu_owner "$disk"' "$ROOT/safebox" || fail 'Readonly/ACL-Owner des Overlays fehlt'
# shellcheck disable=SC2016 -- Verbatim-Codefragment: absichtlich keine Variablenexpansion.
grep -Fq '"${SUDO[@]}" test -d "$SAFEBOX_SESSIONS_DIR"' "$ROOT/safebox" || fail 'Cleanup-Verzeichnisprüfung ist nicht privilegiert'
pass 'Storage-Rechtefehler ist als Verhalten/Quellpfad abgesichert'

! grep -Fq '/tmp/safebox-nwfilter.xml' "$ROOT/install/install-runtime-helpers.sh" || fail 'Vorhersehbare root-/tmp-Datei wieder vorhanden'
grep -Fq 'mktemp -p /run/safebox/tmp' "$ROOT/install/install-runtime-helpers.sh" || fail 'Sicheres root-owned mktemp fehlt'
pass 'Root-Tempdateien verwenden geschützten Runtime-Pfad'

! grep -Eq 'usermod .*libvirt|gpasswd .* -a .*libvirt' "$ROOT/install/install-host.sh" || fail 'Installer vergibt wieder dauerhafte libvirt-Gruppenrechte'
pass 'Installer vergibt keine libvirt-Gruppenrechte'

grep -Fq '/var/lib/dpkg/status' "$ROOT/tools/verify-base-guest.sh" || fail 'Offline-Gastprüfung vertraut weiterhin nur dem Marker'
for p in qemu-guest-agent spice-vdagent openssh-server avahi-daemon cups-daemon; do grep -Fq "$p" "$ROOT/tools/verify-base-guest.sh" || fail "Offline-Paketprüfung fehlt: $p"; done
pass 'Gast-Härtung prüft reale Offline-Paketzustände'

grep -Fq 'SAFEBOX_NWFILTER="safebox-runtime-filter"' "$ROOT/config/defaults.conf" || fail 'Projekt-eigener nwfilter nicht konfiguriert'
grep -Fq "<filter name='safebox-runtime-filter'" "$ROOT/network/safebox-runtime-filter.xml" || fail 'Projekt-eigener nwfilter fehlt'
pass 'nwfilter ist projekt-owned statt distro-clean-traffic'

# Root runtime must use installed immutable helpers, not sudo on mutable checkout code.
! grep -Fq 'sudo bash "$ROOT/network/apply-firewall.sh"' "$ROOT/safebox" || fail 'Mutable Repo-Firewall wird wieder als root ausgeführt'
# shellcheck disable=SC2016 -- Verbatim-Codefragment: absichtlich keine Variablenexpansion.
grep -Fq '$SAFEBOX_LIBEXEC/apply-firewall.sh' "$ROOT/safebox" || fail 'Installierter root-owned Firewall-Helper wird nicht genutzt'
pass 'Root-Runtime nutzt installierte Helper'

# Helper integrity must be checked before domain creation.
start_block="$(awk '/^start_vm\(\)/,/^detect_domain\(\)/' "$ROOT/safebox")"
pre="$(grep -n "installed_helpers_ok || die" <<<"$start_block" | head -n1 | cut -d: -f1)"
# shellcheck disable=SC2016 -- Verbatim-Codefragment: absichtlich keine Variablenexpansion.
create="$(grep -n 'virsh -c "$SAFEBOX_CONNECT_URI" create' <<<"$start_block" | head -n1 | cut -d: -f1)"
[[ "$pre" =~ ^[0-9]+$ && "$create" =~ ^[0-9]+$ && "$pre" -lt "$create" ]] || fail 'Helper-Attestation erfolgt nicht vor VM-Start'
pass 'Helper-Attestation erfolgt vor VM-Start'

grep -Fq 'SAFEBOX_VERIFY_BASE_HASH="1"' "$ROOT/config/defaults.conf" || fail 'Base-Hash ist wieder per Environment abschaltbar'
# shellcheck disable=SC2016 -- Verbatim-Codefragment: absichtlich keine Variablenexpansion.
grep -Fq 'verify_overlay "$disk"' "$ROOT/safebox" || fail 'Overlay-Integrität wird vor Start nicht geprüft'
pass 'Basis-/Overlay-Integrität ist fail-closed'

grep -Fq 'RELEASE_SIGNER_FINGERPRINT' "$ROOT/.github/workflows/release.yml" || fail 'Release-Signer ist nicht gepinnt'
grep -Fq 'VALIDSIG' "$ROOT/tools/verify-signed-tag.sh" || fail 'Signer-Fingerprint wird nicht aus kryptografischem Ergebnis geprüft'
pass 'Release verlangt explizit erlaubten Signer-Fingerprint'

echo '[PASS] RC2-Regressionen für alle im RC1-Audit gefundenen Fehler aktiv.'
