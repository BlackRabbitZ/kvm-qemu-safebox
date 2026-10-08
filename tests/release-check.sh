#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '\n' <"$ROOT/VERSION")"
[[ "$VERSION" == 0.5.1-rc5 ]] || { echo "[FAIL] VERSION=$VERSION" >&2; exit 1; }
grep -Fq "SAFEBOX_VERSION=\"$VERSION\"" "$ROOT/config/defaults.conf"
grep -Fq "version=$VERSION" "$ROOT/guest/harden.sh"
# Grund: Wörtlicher Such-/Testtext, Expansion wäre hier falsch.
# shellcheck disable=SC2016
grep -Fq 'version=$SAFEBOX_VERSION' "$ROOT/tools/verify-base-guest.sh"
grep -Fq BlackRabbitZ "$ROOT/NOTICE"
grep -Fq 'Esmaralda Haze' "$ROOT/README.md"
grep -Fq 'https://github.com/BlackRabbitZ/kvm-qemu-safebox' "$ROOT/README.md"
grep -Fq 'v0.5.1-rc5' "$ROOT/release/RELEASE_NOTES.md"
for profile in hardened balanced performance; do [[ -f "$ROOT/profiles/$profile.conf" ]]; done
for f in tools/build-release.sh tools/generate-sbom.sh tools/verify-release.sh tools/verify-signed-tag.sh tools/xml-policy-check.py; do [[ -x "$ROOT/$f" ]] || { echo "[FAIL] Nicht ausführbar: $f" >&2; exit 1; }; done
for f in safebox install/*.sh host/*.sh network/*.sh guest/*.sh tools/*.sh tests/*.sh; do
  for p in "$ROOT"/$f; do [[ -x "$p" ]] || { echo "[FAIL] Execute-Bit fehlt: ${p#"$ROOT"/}" >&2; exit 1; }; done
done
if grep -R -Fq '0.5.0-alpha2' "$ROOT" --exclude='CHANGELOG.md' --exclude='release-check.sh' --exclude-dir=dist; then echo '[FAIL] Alpha2-Referenz außerhalb CHANGELOG.' >&2; exit 1; fi
if grep -R -Fq '0.5.0-alpha1' "$ROOT" --exclude='CHANGELOG.md' --exclude='release-check.sh' --exclude-dir=dist; then echo '[FAIL] Alpha1-Referenz außerhalb CHANGELOG.' >&2; exit 1; fi
bash "$ROOT/tests/docs-links.sh"
python3 -m py_compile "$ROOT/tools/xml-policy-check.py"
echo '[PASS] RC-Release-Metadaten, Execute-Bits, Links und Versionen konsistent.'
