#!/usr/bin/env bash
set -Eeuo pipefail
DIR=${1:-dist}; VERSION=${2:-$(tr -d '\n' <"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/VERSION")}
base="kvm-qemu-safebox-$VERSION"; sums="$DIR/$base.sha256"
EXPECTED="${SAFEBOX_SIGNING_FINGERPRINT:-${RELEASE_SIGNER_FINGERPRINT:-}}"
[[ "$EXPECTED" =~ ^[A-Fa-f0-9]{40}$ ]] || { echo '[FAIL] Erwarteten 40-stelligen GPG-Fingerprint als SAFEBOX_SIGNING_FINGERPRINT angeben.' >&2; exit 1; }
[[ -f "$sums" ]] || { echo "[FAIL] Prüfsummendatei fehlt: $sums" >&2; exit 1; }
command -v gpg >/dev/null || exit 1
for f in "$DIR/$base.zip" "$DIR/$base.tar.gz" "$DIR/$base.spdx.json" "$sums"; do
  [[ -s "$f" && -s "$f.asc" ]] || { echo "[FAIL] Artefakt/Signatur fehlt: $f" >&2; exit 1; }
  # Validate VALIDSIG, not merely that GPG accepts some imported public key.
  result="$(gpg --batch --status-fd 1 --verify "$f.asc" "$f" 2>/dev/null)" || exit 1
  # Literal embedded program/test syntax: $ belongs to that program, not Bash.
  # shellcheck disable=SC2016
  actual="$(awk '/^\[GNUPG:\] VALIDSIG / {print toupper($3); exit}' <<<"$result")"
  [[ "$actual" == "${EXPECTED^^}" ]] || { echo "[FAIL] Signer $actual statt $EXPECTED" >&2; exit 1; }
done
(cd "$DIR" && sha256sum -c "$(basename "$sums")")
echo '[PASS] Alle vier Release-Dateien mit angeheftetem, erwarteten GPG-Signer und SHA-256 verifiziert.'
