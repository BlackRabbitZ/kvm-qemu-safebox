#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_AUTHOR='BlackRabbitZ'
EXPECTED_REPO='https://github.com/BlackRabbitZ/kvm-qemu-safebox'

check_contains() {
  local file=$1
  local expected=$2

  if ! grep -Fq -- "$expected" "$ROOT/$file"; then
    printf '[FAIL] %s enthält die erwartete Attribution nicht: %s\n' "$file" "$expected" >&2
    return 1
  fi
}

status=0

check_contains NOTICE "$EXPECTED_AUTHOR" || status=1
check_contains NOTICE "$EXPECTED_REPO" || status=1
check_contains ATTRIBUTION.md "$EXPECTED_AUTHOR" || status=1
check_contains ATTRIBUTION.md "$EXPECTED_REPO" || status=1
check_contains README.md "$EXPECTED_AUTHOR" || status=1
check_contains README.md "$EXPECTED_REPO" || status=1
check_contains network/safebox-firewall.service "$EXPECTED_REPO" || status=1

if (( status != 0 )); then
  exit "$status"
fi

printf '[PASS] Original-Attribution für %s ist vollständig vorhanden.\n' "$EXPECTED_AUTHOR"
printf '[PASS] Original-Repository: %s\n' "$EXPECTED_REPO"
