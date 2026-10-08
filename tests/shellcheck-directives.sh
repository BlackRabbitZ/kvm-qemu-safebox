#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PYCODE'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
errors = []
valid = re.compile(r"^\s*# shellcheck (?:disable=SC[0-9]{4}(?:,SC[0-9]{4})*|source=/dev/null|shell=(?:bash|sh))\s*$")
for path in [root/'safebox', *root.rglob('*.sh')]:
    for i, line in enumerate(path.read_text(encoding='utf-8').splitlines(), start=1):
        if re.match(r"^\s*# shellcheck\b", line) and not valid.fullmatch(line):
            errors.append(f"{path.relative_to(root)}:{i}: invalid ShellCheck directive: {line.strip()}")
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('[PASS] ShellCheck-Direktiven entsprechen der geprüften Syntax-Untermenge.')
PYCODE
