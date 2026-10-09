#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
VERSION="$(tr -d '\n' <"$ROOT/VERSION")"
base="kvm-qemu-safebox-$VERSION"
SAFEBOX_SKIP_RELEASE_CHECK=1 bash "$ROOT/tools/build-release.sh" --output "$T" >/dev/null
for f in "$base.zip" "$base.tar.gz" "$base.spdx.json" "$base.sha256"; do [[ -s "$T/$f" ]] || { echo "[FAIL] Release-Artefakt fehlt: $f" >&2; exit 1; }; done
(cd "$T" && sha256sum -c "$base.sha256" >/dev/null)
if SAFEBOX_SIGNING_FINGERPRINT='' bash "$ROOT/tools/verify-release.sh" "$T" "$VERSION" >/dev/null 2>&1; then echo "[FAIL] Unsiginiertes Archiv wurde als signiertes Release akzeptiert" >&2; exit 1; fi

T2="$(mktemp -d)"
trap 'rm -rf "$T" "$T2"' EXIT
SAFEBOX_SKIP_RELEASE_CHECK=1 SOURCE_DATE_EPOCH=1704067200 bash "$ROOT/tools/build-release.sh" --output "$T2" >/dev/null
for f in "$base.zip" "$base.tar.gz" "$base.spdx.json" "$base.sha256"; do
  cmp -s "$T/$f" "$T2/$f" || { echo "[FAIL] Nicht reproduzierbares Artefakt: $f" >&2; exit 1; }
done
python3 - "$T/$base.spdx.json" "$VERSION" <<'PY'
import json,sys
p,v=sys.argv[1:]; j=json.load(open(p,encoding='utf-8'))
assert j['spdxVersion']=='SPDX-2.3'
assert j['packages'][0]['versionInfo']==v
names={f['fileName'] for f in j['files']}
for needed in ('./README.md','./SECURITY.md','./safebox','./tools/runtime-verify.sh','./LICENSE'):
    assert needed in names, needed
assert len(j['files']) >= 40
PY
python3 - "$T/$base.zip" "$VERSION" <<'PY'
import sys,zipfile
p,v=sys.argv[1:]; prefix=f'kvm-qemu-safebox-{v}/'
with zipfile.ZipFile(p) as z:
    names=set(z.namelist())
    for name in ('safebox', 'tools/build-release.sh', 'tools/generate-sbom.sh', 'tools/security_gate.py', 'tests/release-check.sh'):
        info=z.getinfo(prefix+name)
        assert info.create_system == 3, f'No Unix permission metadata: {name}'
        assert ((info.external_attr >> 16) & 0o111) == 0o111, f'Missing executable bits in ZIP: {name}'
    for name in ('README.md','config/defaults.conf'):
        info=z.getinfo(prefix+name)
        assert (info.external_attr >> 16) & 0o111 == 0, f'Unexpected executable bit in ZIP: {name}'
for n in ('README.md','SECURITY.md','VERSION','safebox','profiles/hardened.conf'):
    assert prefix+n in names, n
assert not any('/dist/' in x or '/.git/' in x for x in names)
PY
tar -tzf "$T/$base.tar.gz" >"$T/tar.list"
grep -Fxq "$base/README.md" "$T/tar.list"
echo '[PASS] Release-ZIP, tar.gz, SHA-256 und SPDX-SBOM reproduzierbar erzeugt und verifiziert.'
