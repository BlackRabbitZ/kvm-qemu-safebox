#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v gpg >/dev/null || { echo 'GPG fehlt; signierter Release-Test kann nicht bestanden werden.' >&2; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
export GNUPGHOME="$T/gnupg"
mkdir -m 0700 "$GNUPGHOME"
gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key \
  'SafeBox Integration Test <safebox-test@example.invalid>' ed25519 sign 0 >/dev/null 2>&1
FPR="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1=="fpr" {print $10; exit}')"
[[ "$FPR" =~ ^[0-9A-Fa-f]{40}$ ]] || exit 1
VERSION="$(cat "$ROOT/VERSION")"
base="kvm-qemu-safebox-$VERSION"
for ext in zip tar.gz spdx.json; do printf 'integrity test %s\n' "$ext" >"$T/$base.$ext"; done
(cd "$T" && sha256sum "$base.zip" "$base.tar.gz" "$base.spdx.json" >"$base.sha256")
for ext in zip tar.gz spdx.json sha256; do
  gpg --batch --armor --detach-sign --local-user "$FPR" --output "$T/$base.$ext.asc" "$T/$base.$ext" 2>/dev/null
done
SAFEBOX_SIGNING_FINGERPRINT="$FPR" bash "$ROOT/tools/verify-release.sh" "$T" "$VERSION" >/dev/null || exit 1
echo '[PASS] Signiertes Paket mit exakt erwartetem Fingerprint akzeptiert'
if SAFEBOX_SIGNING_FINGERPRINT=0000000000000000000000000000000000000000 bash "$ROOT/tools/verify-release.sh" "$T" "$VERSION" >/dev/null 2>&1; then
  echo '[FAIL] Falscher GPG-Signer-Fingerprint akzeptiert' >&2; exit 1
fi
echo '[PASS] Falscher Fingerprint zuverlässig abgelehnt'
mv "$T/$base.zip.asc" "$T/removed.asc"
if SAFEBOX_SIGNING_FINGERPRINT="$FPR" bash "$ROOT/tools/verify-release.sh" "$T" "$VERSION" >/dev/null 2>&1; then
  echo '[FAIL] Fehlende GPG-Release-Signatur akzeptiert' >&2; exit 1
fi
mv "$T/removed.asc" "$T/$base.zip.asc"
echo '[PASS] Fehlende detached Signatur zuverlässig abgelehnt'
printf '\nTAMPERED\n' >>"$T/$base.zip"
if SAFEBOX_SIGNING_FINGERPRINT="$FPR" bash "$ROOT/tools/verify-release.sh" "$T" "$VERSION" >/dev/null 2>&1; then
  echo '[FAIL] Manipuliertes ZIP akzeptiert' >&2; exit 1
fi
echo '[PASS] Manipuliertes Artefakt zuverlässig abgelehnt'
