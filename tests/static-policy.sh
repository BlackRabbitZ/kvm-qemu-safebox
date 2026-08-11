#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; FAIL=1; }

RUNTIME="$ROOT/vm/templates/runtime.xml.in"
INSTALLER="$ROOT/vm/templates/installer.xml.in"

for f in "$RUNTIME" "$INSTALLER"; do
  if grep -q "controller type='usb' model='none'" "$f"; then pass "USB-Controller explizit aus: ${f##*/}"; else fail "USB nicht aus: $f"; fi
  if ! grep -Eq '<hostdev|<filesystem|<channel|<redirdev|<smartcard|<shmem|<sound|<audio' "$f"; then pass "Keine verbotene Host-Integration: ${f##*/}"; else fail "Verbotenes Gerät gefunden: $f"; fi
  if grep -q "clipboard copypaste='no'" "$f"; then pass "Clipboard aus: ${f##*/}"; else fail "Clipboard nicht aus: $f"; fi
  if grep -q "filetransfer enable='no'" "$f"; then pass "SPICE-Dateitransfer aus: ${f##*/}"; else fail "Dateitransfer nicht aus: $f"; fi
  if grep -q '<nosharepages/>' "$f"; then pass "KSM/Memory-Merging aus: ${f##*/}"; else fail "nosharepages fehlt: $f"; fi
  if grep -q "<listen type='none'/>" "$f"; then pass "Kein frei lauschender SPICE-Port: ${f##*/}"; else fail "SPICE listen nicht none: $f"; fi
  if grep -q "<pmu state='off'/>" "$f"; then pass "Virtuelle PMU aus: ${f##*/}"; else fail "PMU nicht aus: $f"; fi
  if grep -q "<vmport state='off'/>" "$f"; then pass "VMware-vmport aus: ${f##*/}"; else fail "vmport nicht aus: $f"; fi
  if grep -q "feature policy='disable' name='vmx'" "$f" && grep -q "feature policy='disable' name='svm'" "$f"; then
    pass "Nested-Virtualisierung aus: ${f##*/}"
  else
    fail "Nested-Virtualisierung nicht explizit aus: $f"
  fi
done

exit "$FAIL"
