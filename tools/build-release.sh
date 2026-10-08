#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '\n' <"$ROOT/VERSION")"
OUT="$ROOT/dist"; SIGN_KEY=''
while (($#)); do
  case "$1" in
    --output) OUT=${2:?}; shift 2;;
    --sign) SIGN_KEY=${2:?}; shift 2;;
    *) echo "usage: $0 [--output DIR] [--sign GPG_KEY_ID]" >&2; exit 2;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || { echo "FEHLER: Ungültige SemVer-Version: $VERSION" >&2; exit 1; }
command -v python3 >/dev/null; command -v sha256sum >/dev/null
# One deterministic timestamp drives tar.gz and SPDX creation. Same source commit => same artifacts.
if [[ -z "${SOURCE_DATE_EPOCH:-}" ]]; then
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    SOURCE_DATE_EPOCH="$(git -C "$ROOT" log -1 --format=%ct)"
  else
    SOURCE_DATE_EPOCH=1704067200
  fi
fi
export SOURCE_DATE_EPOCH
if [[ ${SAFEBOX_SKIP_RELEASE_CHECK:-0} != 1 ]]; then make -C "$ROOT" release-check; fi
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
base="kvm-qemu-safebox-$VERSION"
zipfile="$OUT/$base.zip"; tarfile="$OUT/$base.tar.gz"; sbom="$OUT/$base.spdx.json"; sums="$OUT/$base.sha256"
rm -f "$zipfile" "$tarfile" "$sbom" "$sums" "$zipfile.asc" "$tarfile.asc" "$sbom.asc" "$sums.asc"
"$ROOT/tools/generate-sbom.sh" "$sbom" >/dev/null
python3 - "$ROOT" "$zipfile" "$tarfile" "$base" <<'PY'
from pathlib import Path
import gzip,io,os,sys,tarfile,zipfile
root=Path(sys.argv[1]).resolve(); zpath=Path(sys.argv[2]); tpath=Path(sys.argv[3]); prefix=sys.argv[4]
exclude={'.git','dist','__pycache__'}
files=[]
for p in sorted(root.rglob('*')):
    if not p.is_file(): continue
    rel=p.relative_to(root)
    if any(part in exclude for part in rel.parts): continue
    if rel.as_posix().endswith(('.zip','.tar.gz','.asc','.sha256')): continue
    files.append((p,rel))
epoch=int(os.environ.get('SOURCE_DATE_EPOCH','1704067200'))
with zipfile.ZipFile(zpath,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p,rel in files:
        zi=zipfile.ZipInfo(f'{prefix}/{rel.as_posix()}')
        zi.date_time=(2024,1,1,0,0,0)
        zi.create_system=3
        zi.compress_type=zipfile.ZIP_DEFLATED
        mode=0o755 if os.access(p,os.X_OK) else 0o644
        zi.external_attr=(mode & 0xFFFF)<<16
        z.writestr(zi,p.read_bytes())
with open(tpath,'wb') as raw:
    with gzip.GzipFile(fileobj=raw,mode='wb',mtime=epoch,filename='') as gz:
        with tarfile.open(fileobj=gz,mode='w') as t:
            for p,rel in files:
                data=p.read_bytes(); ti=tarfile.TarInfo(f'{prefix}/{rel.as_posix()}')
                ti.size=len(data); ti.mtime=epoch; ti.uid=0; ti.gid=0; ti.uname='root'; ti.gname='root'; ti.mode=0o755 if os.access(p,os.X_OK) else 0o644
                t.addfile(ti,io.BytesIO(data))
PY
(
  cd "$OUT"
  sha256sum "$(basename "$zipfile")" "$(basename "$tarfile")" "$(basename "$sbom")" >"$(basename "$sums")"
)
if [[ -n "$SIGN_KEY" ]]; then
  command -v gpg >/dev/null || { echo 'FEHLER: gpg fehlt.' >&2; exit 1; }
  for f in "$zipfile" "$tarfile" "$sbom" "$sums"; do gpg --batch --yes --armor --detach-sign --local-user "$SIGN_KEY" --output "$f.asc" "$f"; done
fi
printf '[OK] Release gebaut:\n  %s\n  %s\n  %s\n  %s\n' "$zipfile" "$tarfile" "$sbom" "$sums"
[[ -z "$SIGN_KEY" ]] || printf '[OK] Detached GPG-Signaturen erstellt.\n'
