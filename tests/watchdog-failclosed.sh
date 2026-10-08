#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
LIB="$T/libexec"; RUN="$T/run"; mkdir -p "$LIB" "$RUN/identities"
cat >"$T/config.conf" <<EOF2
SAFEBOX_CONNECT_URI="qemu:///system"
SAFEBOX_LIBEXEC="$LIB"
SAFEBOX_RUNTIME_DIR="$RUN"
SAFEBOX_WATCH_INTERVAL=2
SAFEBOX_QEMU_MIN_NETWORK_VERSION="10.0.14"
SAFEBOX_QEMU_BLOCK_11_BELOW="11.1.2"
EOF2
make_helper(){ local name=$1 body=$2; printf '#!/usr/bin/env bash\nset -Eeuo pipefail\n%s\n' "$body" >"$LIB/$name"; chmod 0755 "$LIB/$name"; }
# shellcheck disable=SC2016
# The next mock-helper bodies are literal shell source and must expand only in the child process.
make_helper runtime-verify.sh 'exit "${MOCK_RUNTIME_RC:-0}"'
# shellcheck disable=SC2016
make_helper firewall-verify.sh 'exit "${MOCK_FIREWALL_RC:-0}"'
# shellcheck disable=SC2016
make_helper nwfilter-verify.sh 'exit "${MOCK_NWFILTER_RC:-0}"'
# shellcheck disable=SC2016
make_helper qemu-security-check.sh 'exit "${MOCK_QEMU_RC:-0}"'
# shellcheck disable=SC2016
make_helper storage-verify.sh 'exit "${MOCK_STORAGE_RC:-0}"'
# shellcheck disable=SC2016
make_helper domain-pid.sh 'if [[ "${MOCK_PID_RC:-1}" == 0 ]]; then echo 999999; exit 0; fi; exit 1'
# shellcheck disable=SC2016
make_helper kill-domain.sh 'printf "%s\n" "$1" >> "${SAFEBOX_TEST_KILL_MARKER:?}"; exit 0'
# shellcheck disable=SC2016
make_helper sample-verify.sh 'exit "${MOCK_SAMPLE_RC:-0}"'
# shellcheck disable=SC2016
make_helper proc-absence.py 'exit "${MOCK_PROC_RC:-0}"'
cat >"$T/virsh" <<'EOFV'
#!/usr/bin/env bash
set -Eeuo pipefail
cmd=''
for a in "$@"; do case "$a" in list|dominfo|domstate) cmd=$a; break;; esac; done
case "${MOCK_VIRSH_SCENARIO:-running}:$cmd" in
  down:list) exit 1;; missing:dominfo) exit 1;;
  shutoff:domstate|shutofflive:domstate) echo 'shut off';;
  shutdown:domstate) echo 'shutdown';;
  inshutdown:domstate) echo 'in shutdown';;
  crashed:domstate|crashedlive:domstate) echo 'crashed';;
  *) if [[ "$cmd" == domstate ]]; then echo 'running'; fi;;
esac
EOFV
chmod 0755 "$T/virsh"
run_case(){
  local name=$1
  local scenario=$2
  local expect_rc=$3
  local expect_kill=$4
  local pidrc=${5:-1}
  local mock_name=${6:-}
  local mock_value=${7:-}
  local mode=${8:-offline}
  local marker="$T/$name.kill"
  local rc=0
  rm -f "$marker"
  local -a env_args=(SAFEBOX_TESTING=1 SAFEBOX_WATCH_MAX_LOOPS=1 SAFEBOX_VIRSH_BIN="$T/virsh" SAFEBOX_SLEEP_BIN=/bin/true SAFEBOX_TEST_KILL_MARKER="$marker" MOCK_VIRSH_SCENARIO="$scenario" MOCK_PID_RC="$pidrc" MOCK_PROC_RC="$([[ "$pidrc" == 0 ]] && echo 1 || echo 0)" SAFEBOX_CONFIG_FILE="$T/config.conf")
  [[ -z "$mock_name" ]] || env_args+=("$mock_name=$mock_value")
  set +e; env "${env_args[@]}" bash "$ROOT/tools/runtime-watch.sh" safebox-offline-test "$mode" /tmp/test.qcow2 >/dev/null 2>&1; rc=$?; set -e
  [[ "$rc" -eq "$expect_rc" ]] || { echo "[FAIL] $name: Exitcode $rc statt $expect_rc" >&2; exit 1; }
  if [[ "$expect_kill" == yes ]]; then [[ -s "$marker" ]] || { echo "[FAIL] $name: Kill-Service nicht ausgelöst" >&2; exit 1; }; else [[ ! -e "$marker" ]] || { echo "[FAIL] $name: Kill unerwartet" >&2; exit 1; }; fi
  echo "[PASS] Watchdog: $name"
}
run_case libvirt-down down 1 yes 1
run_case domain-disappeared missing 0 yes 1
run_case clean-shutoff shutoff 0 no 1
run_case shutoff-qemu-alive shutofflive 1 yes 0
run_case clean-crashed crashed 0 no 1
run_case crashed-qemu-alive crashedlive 1 yes 0
# shutdown states are transitional and must remain under observation; one loop exits only due test loop limit, no kill.
run_case shutdown-transitional shutdown 0 no 1
run_case in-shutdown-transitional inshutdown 0 no 1
run_case firewall-fail-installer running 1 yes 1 MOCK_FIREWALL_RC 1 installer
run_case nwfilter-fail-installer running 1 yes 1 MOCK_NWFILTER_RC 1 installer
run_case runtime-fail running 1 yes 1 MOCK_RUNTIME_RC 1
run_case storage-fail running 1 yes 1 MOCK_STORAGE_RC 1
run_case malware-sample-change running 1 yes 1 MOCK_SAMPLE_RC 1 malware
run_case forbidden-network-runtime running 1 yes 1 '' '' disposable
grep -Fq 'OnFailure=' "$ROOT/safebox"
grep -Fq 'kill-domain.sh %I' "$ROOT/systemd/safebox-kill@.service"
echo '[PASS] Watchdog-Zustände und Fail-Closed-Pfade dynamisch getestet.'
