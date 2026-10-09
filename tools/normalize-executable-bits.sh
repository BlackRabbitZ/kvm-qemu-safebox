#!/usr/bin/env bash
# Build-tree normalization for checkouts made through browser uploads / Windows.
# Called explicitly by CI. It does not change the Git index or skip security checks.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$ROOT"
shopt -s nullglob
files=(safebox install/*.sh host/*.sh network/*.sh guest/*.sh tools/*.sh tools/*.py tests/*.sh)
if [[ ${#files[@]} -le 1 ]]; then echo '[FAIL] No scripts found to normalize' >&2; exit 1; fi
for file in "${files[@]}"; do
  [[ -f "$file" && ! -L "$file" ]] || { printf '[FAIL] Unsafe or missing script: %s\n' "$file" >&2; exit 1; }
  [[ -r "$file" ]] || { printf '[FAIL] Script is not readable: %s\n' "$file" >&2; exit 1; }
  case "$file" in
    safebox|*.sh|tools/*.py) ;;
    *) printf '[FAIL] Unexpected executable path: %s\n' "$file" >&2; exit 1 ;;
  esac
  chmod 0755 -- "$file"
done
printf '[OK] Executable modes normalized for %s checked-out source scripts.\n' "${#files[@]}"
