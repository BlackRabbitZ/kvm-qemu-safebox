#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re,sys,urllib.parse
root=Path(sys.argv[1])
errors=[]
for md in root.rglob('*.md'):
    if any(x in md.parts for x in ('.git','dist')): continue
    text=md.read_text(encoding='utf-8')
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)',text):
        target=target.strip().split()[0].strip('<>')
        if not target or target.startswith(('#','http://','https://','mailto:')): continue
        target=urllib.parse.unquote(target.split('#',1)[0])
        if not target: continue
        p=(md.parent/target).resolve()
        try: p.relative_to(root.resolve())
        except ValueError:
            errors.append(f'{md.relative_to(root)} -> außerhalb des Repos: {target}'); continue
        if not p.exists(): errors.append(f'{md.relative_to(root)} -> fehlt: {target}')
if errors:
    print('\n'.join('[FAIL] '+x for x in errors),file=sys.stderr); raise SystemExit(1)
print('[PASS] Relative Markdown-Links sind gültig.')
PY
