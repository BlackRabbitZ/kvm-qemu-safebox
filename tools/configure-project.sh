#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PH_GITHUB='YOUR_''GITHUB_USERNAME'
PH_NAME='YOUR_''NAME'

usage() {
  cat <<'USAGE'
Verwendung:
  ./tools/configure-project.sh GITHUB_USERNAME "DEIN NAME"

Beispiel:
  ./tools/configure-project.sh maxmustermann "Max Mustermann"

Trägt GitHub-Benutzername und Urhebername in die Release-/Attributionsfelder
von README, NOTICE, CI-Badge und Service-Dokumentation ein.
USAGE
}

[[ $# -eq 2 ]] || { usage; exit 1; }
GITHUB_USER=$1
DISPLAY_NAME=$2

[[ "$GITHUB_USER" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]] || {
  echo "FEHLER: Ungültig aussehender GitHub-Benutzername: $GITHUB_USER" >&2
  exit 1
}
[[ -n "$DISPLAY_NAME" ]] || { echo "FEHLER: Name darf nicht leer sein." >&2; exit 1; }

python3 - "$ROOT" "$GITHUB_USER" "$DISPLAY_NAME" "$PH_GITHUB" "$PH_NAME" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
github_user = sys.argv[2]
display_name = sys.argv[3]
ph_github = sys.argv[4]
ph_name = sys.argv[5]

allowed_suffixes = {'.md', '.yml', '.yaml', '.service', '.conf', '.nft', '.xml', '.in', '.sh', ''}
changed = []
for path in root.rglob('*'):
    if not path.is_file() or '.git' in path.parts:
        continue
    if path.name == 'LICENSE':
        continue
    if path.suffix not in allowed_suffixes and path.name not in {'NOTICE', 'Makefile', 'VERSION'}:
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    new = text.replace(ph_github, github_user).replace(ph_name, display_name)
    if new != text:
        path.write_text(new, encoding='utf-8')
        changed.append(path.relative_to(root))

for path in changed:
    print(f'[OK] {path}')
if not changed:
    print('[INFO] Keine Release-Platzhalter mehr gefunden – vermutlich bereits konfiguriert.')
PY

if grep -R --exclude-dir=.git -nE "${PH_GITHUB}|${PH_NAME}" "$ROOT" >/dev/null 2>&1; then
  echo "[WARN] Es sind noch Release-Platzhalter vorhanden:" >&2
  grep -R --exclude-dir=.git -nE "${PH_GITHUB}|${PH_NAME}" "$ROOT" >&2 || true
  exit 2
fi

echo "[OK] Projektattribution konfiguriert. Jetzt: make release-check"
