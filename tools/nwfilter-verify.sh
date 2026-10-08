#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C
CONFIG=${SAFEBOX_CONFIG_FILE:-/etc/safebox/defaults.conf}
[[ -r "$CONFIG" ]] || { echo "FEHLER: Konfiguration fehlt: $CONFIG" >&2; exit 2; }
# shellcheck source=/dev/null
source "$CONFIG"
SUDO=(); [[ ${EUID} -eq 0 ]] || SUDO=(sudo)
for c in virsh python3; do command -v "$c" >/dev/null || exit 1; done

hash_xml(){
  python3 "${SAFEBOX_LIBEXEC:-/usr/local/libexec/safebox}/nwfilter-canon.py"
}
verify_one(){
  local name=$1
  local source=$2
  local live actual expected
  "${SUDO[@]}" test -r "$source" || { echo "[FAIL] nwfilter XML fehlt: $source" >&2; exit 1; }
  [[ "$("${SUDO[@]}" stat -c %U "$source")" == root ]] || { echo "[FAIL] nwfilter XML nicht root-owned: $source" >&2; exit 1; }
  live="$("${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" nwfilter-dumpxml "$name" 2>/dev/null)" || { echo "[FAIL] nwfilter fehlt: $name" >&2; exit 1; }
  actual="$(hash_xml <<<"$live")"
  expected="$("${SUDO[@]}" cat "$source" | hash_xml)"
  [[ "$actual" == "$expected" ]] || { echo "[FAIL] Live-nwfilter weicht vom Projekt-XML ab: $name" >&2; exit 1; }
}

verify_one "$SAFEBOX_NWFILTER" "$SAFEBOX_NWFILTER_XML"
verify_one "$SAFEBOX_INSTALL_NWFILTER" "$SAFEBOX_INSTALL_NWFILTER_XML"

"${SUDO[@]}" test -r "$SAFEBOX_NWFILTER_BASELINE" || { echo '[FAIL] nwfilter-Baseline fehlt.' >&2; exit 1; }
actual="$("${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" nwfilter-dumpxml "$SAFEBOX_NWFILTER" | hash_xml)"
# AWK code must not undergo shell parameter expansion; the $1 belongs to awk.
# shellcheck disable=SC2016
expected="$("${SUDO[@]}" awk '{print $1; exit}' "$SAFEBOX_NWFILTER_BASELINE")"
[[ "$actual" == "$expected" ]] || { echo '[FAIL] Runtime-nwfilter weicht von der installierten Baseline ab.' >&2; exit 1; }
echo '[PASS] Runtime- und Installer-nwfilter entsprechen exakt den root-owned Projektdefinitionen.'
