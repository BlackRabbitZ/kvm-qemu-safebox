#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT=${1:-"$ROOT/dist/kvm-qemu-safebox-$(<"$ROOT/VERSION").spdx.json"}
mkdir -p "$(dirname -- "$OUT")"
python3 - "$ROOT" "$OUT" <<'PY'
from pathlib import Path
import datetime,hashlib,json,os,sys
root=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve(); version=(root/'VERSION').read_text().strip()
exclude_dirs={'.git','dist','__pycache__'}
exclude_suffixes={'.zip','.tar.gz','.asc'}
files=[]
for p in sorted(root.rglob('*')):
    if not p.is_file(): continue
    rel=p.relative_to(root).as_posix()
    if any(part in exclude_dirs for part in p.relative_to(root).parts): continue
    if rel.endswith('.sha256') or any(rel.endswith(s) for s in exclude_suffixes): continue
    data=p.read_bytes(); sha=hashlib.sha256(data).hexdigest(); sid='SPDXRef-File-'+hashlib.sha256(rel.encode()).hexdigest()[:20]
    files.append({'fileName':'./'+rel,'SPDXID':sid,'checksums':[{'algorithm':'SHA256','checksumValue':sha}],'licenseConcluded':'NOASSERTION','copyrightText':'NOASSERTION'})
tree=hashlib.sha256(''.join(f['checksums'][0]['checksumValue'] for f in files).encode()).hexdigest()
epoch=os.getenv('SOURCE_DATE_EPOCH')
when=datetime.datetime.fromtimestamp(int(epoch),datetime.timezone.utc) if epoch else datetime.datetime.now(datetime.timezone.utc)
doc={
 'spdxVersion':'SPDX-2.3','dataLicense':'CC0-1.0','SPDXID':'SPDXRef-DOCUMENT',
 'name':f'kvm-qemu-safebox-{version}-source-sbom',
 'documentNamespace':f'https://github.com/BlackRabbitZ/kvm-qemu-safebox/spdx/{version}/{tree[:24]}',
 'creationInfo':{'created':when.replace(microsecond=0).isoformat().replace('+00:00','Z'),'creators':['Tool: kvm-qemu-safebox/tools/generate-sbom.sh','Organization: BlackRabbitZ']},
 'documentDescribes':['SPDXRef-Package-SafeBox'],
 'packages':[{'name':'kvm-qemu-safebox','SPDXID':'SPDXRef-Package-SafeBox','versionInfo':version,'downloadLocation':'https://github.com/BlackRabbitZ/kvm-qemu-safebox','filesAnalyzed':True,'licenseConcluded':'Apache-2.0','licenseDeclared':'Apache-2.0','copyrightText':'Copyright BlackRabbitZ'}],
 'files':files,
 'relationships':[{'spdxElementId':'SPDXRef-Package-SafeBox','relationshipType':'CONTAINS','relatedSpdxElement':f['SPDXID']} for f in files]
}
out.write_text(json.dumps(doc,ensure_ascii=False,sort_keys=True,indent=2)+'\n',encoding='utf-8')
PY
printf '[OK] SPDX-2.3 Source-SBOM: %s\n' "$OUT"
