#!/usr/bin/env bash
set -uo pipefail
umask 077
export LC_ALL=C
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG=${SAFEBOX_CONFIG_FILE:-$ROOT/config/defaults.conf}
# shellcheck source=/dev/null
source "$CONFIG"
export SAFEBOX_RAM_MIB SAFEBOX_VCPUS SAFEBOX_MEM_HARD_MIB SAFEBOX_IOTHREADS SAFEBOX_CPU_PERIOD_US SAFEBOX_CPU_MAX_PERCENT SAFEBOX_DISK_TOTAL_BYTES_SEC SAFEBOX_DISK_TOTAL_IOPS_SEC SAFEBOX_NET_BACKEND SAFEBOX_NETWORK SAFEBOX_INSTALL_NETWORK_NAME SAFEBOX_MAC SAFEBOX_GUEST_IP SAFEBOX_NWFILTER SAFEBOX_INSTALL_NWFILTER
DOMAIN="${1:-}"; MODE="${2:-auto}"; EXPECTED_DISK="${3:-}"; EXPECTED_ISO="${4:-}"; [[ -n "$DOMAIN" ]] || exit 2
SUDO=(); [[ ${EUID} -eq 0 ]] || SUDO=(sudo); PASS=0; FAIL=0
ok(){ echo "[PASS] $*"; PASS=$((PASS+1)); }
bad(){ echo "[FAIL] $*" >&2; FAIL=$((FAIL+1)); }

safe_tmp_base="${XDG_RUNTIME_DIR:-/tmp}"
[[ -d "$safe_tmp_base" && -w "$safe_tmp_base" ]] || safe_tmp_base=/tmp
safe_tmp_dir="$safe_tmp_base/safebox-${UID}"
if [[ ! -d "$safe_tmp_dir" ]]; then mkdir -m 0700 -- "$safe_tmp_dir" 2>/dev/null || true; fi
[[ -d "$safe_tmp_dir" && ! -L "$safe_tmp_dir" && "$(stat -c %u "$safe_tmp_dir" 2>/dev/null)" == "$UID" ]] || { bad 'Sicheres Temp-Verzeichnis konnte nicht verwendet werden'; exit 1; }
xml="$(mktemp -p "$safe_tmp_dir" runtime.XXXXXX.xml)"; trap 'rm -f "$xml"' EXIT

TESTING="${SAFEBOX_TESTING:-0}"
TEST_XML="${SAFEBOX_TEST_XML_FILE:-}"
SKIP_PROCESS_CHECKS=0
if [[ "$TESTING" == 1 && -n "$TEST_XML" ]]; then
  [[ -f "$TEST_XML" ]] || { bad "Test-XML fehlt: $TEST_XML"; exit 1; }
  cp -- "$TEST_XML" "$xml" || exit 1
  SKIP_PROCESS_CHECKS=1
else
  "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" dominfo "$DOMAIN" >/dev/null 2>&1 || { bad "Domain fehlt: $DOMAIN"; exit 1; }
  "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" dumpxml "$DOMAIN" >"$xml" || exit 1
fi
x(){ xmllint --xpath "$1" "$xml" 2>/dev/null; }
count(){ x "count($1)"; }
ac(){ local p=$1 e=$2 m=$3 g; g="$(count "$p")"; if [[ "$g" == "$e" ]]; then ok "$m"; else bad "$m (gefunden $g, erwartet $e)"; fi; }
ax(){ if [[ "$(x "boolean($1)")" == true ]]; then ok "$2"; else bad "$2"; fi; }

[[ "$MODE" == auto ]] && case "$DOMAIN" in safebox-malware-*) MODE=malware;; safebox-offline-*) MODE=offline;; safebox-installer) MODE=installer;; safebox-persistent) MODE=persistent;; safebox-disposable-*) MODE=disposable;; *) MODE=runtime;; esac
XML_POLICY="${SAFEBOX_LIBEXEC:-/usr/local/libexec/safebox}/xml-policy-check.py"
[[ -x "$XML_POLICY" ]] || XML_POLICY="$ROOT/tools/xml-policy-check.py"
if python3 "$XML_POLICY" "$xml" "$MODE" "$EXPECTED_DISK" "$EXPECTED_ISO" >/dev/null; then ok 'Statische Domain-XML-Allowlist'; else bad 'Statische Domain-XML-Allowlist verletzt'; fi
cpu_quota=$(( SAFEBOX_VCPUS * SAFEBOX_CPU_PERIOD_US * SAFEBOX_CPU_MAX_PERCENT / 100 ))

# Harte Top-Level-Allowlist der emulierten Geräte.
allowed='emulator disk controller interface input graphics video memballoon'
mapfile -t nodes < <(python3 - "$xml" <<'NODEPY'
import sys,xml.etree.ElementTree as ET
r=ET.parse(sys.argv[1]).getroot(); d=r.find('devices')
print('\n'.join(sorted({c.tag for c in d})))
NODEPY
)
for n in "${nodes[@]}"; do grep -qw "$n" <<<"$allowed" || bad "Nicht erlaubter Geräte-Knoten: <$n>"; done

ax "/domain[@type='kvm']" 'KVM aktiv'
ax "/domain/os/type[@arch='x86_64' and @machine='q35']" 'q35/x86_64'
ax "/domain/memoryBacking/nosharepages and /domain/memoryBacking/source[@type='anonymous'] and /domain/memoryBacking/access[@mode='private']" 'Private Memory-Backing ohne KSM'
ax "/domain/memory[@unit='MiB' and number(text())=$SAFEBOX_RAM_MIB] and /domain/currentMemory[@unit='MiB' and number(text())=$SAFEBOX_RAM_MIB]" 'Gast-RAM exakt'
ax "/domain/memtune/hard_limit[@unit='MiB' and number(text())=$SAFEBOX_MEM_HARD_MIB] and /domain/memtune/swap_hard_limit[@unit='MiB' and number(text())=$SAFEBOX_MEM_HARD_MIB]" 'RAM-/Swap-Hard-Limit exakt'
ax "/domain/vcpu[number(text())=$SAFEBOX_VCPUS and @placement='static']" 'vCPU-Zahl exakt'
ax "/domain/iothreads[number(text())=$SAFEBOX_IOTHREADS]" 'IOThread-Zahl exakt'
ax "/domain/cputune/global_period[number(text())=$SAFEBOX_CPU_PERIOD_US] and /domain/cputune/global_quota[number(text())=$cpu_quota]" 'CPU-Hard-Quota exakt'
ax "/domain/features/hyperv/vapic[@state='off']" 'KVM VAPIC aus'
ax "/domain/features/pmu[@state='off'] and /domain/features/vmport[@state='off']" 'PMU/vmport aus'
ax "/domain/cpu[@mode='host-model']/feature[@name='vmx' and @policy='disable'] and /domain/cpu[@mode='host-model']/feature[@name='svm' and @policy='disable']" 'Nested Virtualization aus'
ax "/domain/seclabel[@model='apparmor' and @type='dynamic']" 'AppArmor verlangt'
# Keine benutzerdefinierte QEMU-Commandline darf die libvirt-Grenzen umgehen.
ac "/*[local-name()='domain']/*[local-name()='commandline']" 0 'Keine qemu:commandline-Erweiterung'

ac "/domain/devices/emulator" 1 'Genau ein Emulator'
ax "/domain/devices/emulator[text()='/usr/bin/qemu-system-x86_64']" 'Erwarteter Emulator'
ac "/domain/devices/controller[@type='pci' and @model='pcie-root' and @index='0']" 1 'Genau ein PCIe-Root-Controller'
ac "/domain/devices/controller[@type='usb' and @model='none']" 1 'USB aus'
ax "count(/domain/devices/controller[@type='pci' and @model='pcie-root-port']) <= 8" 'PCIe-Root-Ports auf maximal 8 begrenzt'
ac "/domain/devices/controller[@type='sata' and @index='0']" 1 'Genau ein SATA-Controller'
if [[ $MODE == installer ]]; then
  ac "/domain/devices/disk" 2 'Installer exakt zwei Laufwerke'
else
  ac "/domain/devices/disk" 1 'Runtime exakt ein Laufwerk'
fi
ac "/domain/devices/controller[not((@type='pci' and (@model='pcie-root' or @model='pcie-root-port')) or (@type='usb' and @model='none') or (@type='sata' and @index='0'))]" 0 'Keine unerlaubten Controller'
ac "/domain/devices/memballoon" 1 'Genau ein Balloon-Platzhalter'
ax "/domain/devices/memballoon[@model='none']" 'Balloon aus'

ac "/domain/devices/graphics" 1 'Genau eine Grafik'
ax "/domain/devices/graphics[@type='spice']/listen[@type='none']" 'SPICE ohne Netzwerk-Listener'
ax "/domain/devices/graphics/clipboard[@copypaste='no'] and /domain/devices/graphics/filetransfer[@enable='no'] and /domain/devices/graphics/gl[@enable='no']" 'Clipboard/Filetransfer/OpenGL aus'
ac "/domain/devices/video" 1 'Genau ein Video'
ax "/domain/devices/video/model[@type='bochs' and @heads='1' and @primary='yes']" 'Bochs-Display ohne VirtIO-VGA-Pfad'

ac "/domain/devices/disk[@device='disk']" 1 'Genau eine Systemdisk'
ax "/domain/devices/disk[@device='disk' and @type='file']/driver[@name='qemu' and @type='qcow2' and @cache='none' and @io='native' and @discard='ignore' and not(@iothread) and not(@packed)]" 'QCOW2 SATA ohne VirtIO-spezifische Optionen'
ax "/domain/devices/disk[@device='disk']/iotune/total_bytes_sec[number(text())=$SAFEBOX_DISK_TOTAL_BYTES_SEC] and /domain/devices/disk[@device='disk']/iotune/total_iops_sec[number(text())=$SAFEBOX_DISK_TOTAL_IOPS_SEC]" 'Disk-I/O-Hard-Limits exakt'
ax "/domain/devices/disk[@device='disk']/target[@dev='$SAFEBOX_DISK_TARGET' and @bus='$SAFEBOX_DISK_BUS']" 'Systemdisk-Bus exakt'
ac "/domain/devices/disk[@device='disk']/readonly" 0 'Systemdisk beschreibbar nur im Overlay'
ac "/domain/devices/disk[@device='disk']/source[not(@file)]" 0 'Keine fremde Disk-Quelle'
if [[ -n "$EXPECTED_DISK" ]]; then
  if [[ "$(x 'string(/domain/devices/disk[@device="disk"]/source/@file)')" == "$EXPECTED_DISK" ]]; then ok 'Erwartetes Overlay'; else bad 'Unerwartetes Overlay'; fi
fi

if [[ "$MODE" == offline || "$MODE" == malware ]]; then
  ac "/domain/devices/interface" 0 'Offline ohne NIC'
  if [[ "$MODE" == malware ]]; then
    ac "/domain/devices/disk[@device='cdrom']" 1 'Malware exakt ein Sample-CDROM'
    ax "/domain/devices/disk[@device='cdrom' and @type='file']/driver[@name='qemu' and @type='raw'] and /domain/devices/disk[@device='cdrom']/target[@dev='sdb' and @bus='sata'] and /domain/devices/disk[@device='cdrom']/readonly" 'Sample-CDROM hardwareseitig readonly'
    if [[ -n "$EXPECTED_ISO" && "$(x 'string(/domain/devices/disk[@device="cdrom"]/source/@file)')" == "$EXPECTED_ISO" ]]; then ok 'Sample-ISO-Pfad attestiert'; else bad 'Sample-ISO-Pfad nicht attestiert'; fi
  else
    ac "/domain/devices/disk[@device='cdrom']" 0 'Offline ohne CD-ROM'
  fi
  ac "/domain/devices/input" 2 'Genau zwei Eingabegeräte'
  ac "/domain/devices/input[@type='keyboard' and @bus='ps2']" 1 'PS/2-Tastatur'
  ac "/domain/devices/input[@type='mouse' and @bus='ps2']" 1 'PS/2-Maus'
elif [[ "$MODE" == installer ]]; then
  ac "/domain/devices/interface" 1 'Installer eine NIC'
  ac "/domain/devices/disk[@device='cdrom' and @type='file']" 1 'Installer genau ein CD-ROM'
  ax "/domain/devices/disk[@device='cdrom']/driver[@name='qemu' and @type='raw'] and /domain/devices/disk[@device='cdrom']/target[@dev='sdb' and @bus='sata'] and /domain/devices/disk[@device='cdrom']/readonly" 'Installer-CD-ROM exakt'
  ac "/domain/devices/input" 2 'Installer genau zwei Eingabegeräte'
  ac "/domain/devices/input[@type='keyboard' and @bus='ps2']" 1 'Installer PS/2-Tastatur'
  ac "/domain/devices/input[@type='mouse' and @bus='ps2']" 1 'Installer PS/2-Maus'
  ax "/domain/devices/interface[source/@network='$SAFEBOX_INSTALL_NETWORK_NAME' and model/@type='$SAFEBOX_NET_MODEL' and not(driver) and rom/@bar='off' and port/@isolated='yes']" 'Installer-NIC exakt'
  ax "/domain/devices/interface/mac[@address='$SAFEBOX_MAC']" 'Installer feste MAC'
  ax "/domain/devices/interface/filterref[@filter='$SAFEBOX_INSTALL_NWFILTER']" 'Installer projekt-eigener nwfilter'
else
  ac "/domain/devices/interface" 1 'Runtime eine NIC'
  ac "/domain/devices/disk[@device='cdrom']" 0 'Runtime ohne CD-ROM'
  ac "/domain/devices/input" 2 'Genau zwei Eingabegeräte'
  ac "/domain/devices/input[@type='keyboard' and @bus='ps2']" 1 'PS/2-Tastatur'
  ac "/domain/devices/input[@type='mouse' and @bus='ps2']" 1 'PS/2-Maus'
  ax "/domain/devices/interface[source/@network='$SAFEBOX_NETWORK' and model/@type='$SAFEBOX_NET_MODEL' and not(driver) and rom/@bar='off' and port/@isolated='yes']" 'Runtime-NIC exakt'
  ax "/domain/devices/interface/mac[@address='$SAFEBOX_MAC']" 'Feste MAC'
  ax "/domain/devices/interface/filterref[@filter='$SAFEBOX_NWFILTER']/parameter[@name='IP' and @value='$SAFEBOX_GUEST_IP']" 'Anti-Spoof feste IP'
  ax "/domain/devices/interface/filterref/parameter[@name='CTRL_IP_LEARNING' and @value='none']" 'IP-Learning aus'
fi

for node in hostdev filesystem channel redirdev smartcard shmem sound audio rng tpm vsock watchdog serial parallel console panic iommu crypto memory lease hub; do ac "/domain/devices/$node" 0 "Kein <$node>"; done

if (( SKIP_PROCESS_CHECKS )); then
  ok 'Testmodus: Live-Prozessprüfung übersprungen'
else
PID_HELPER="${SAFEBOX_LIBEXEC:-/usr/local/libexec/safebox}/domain-pid.sh"
[[ -x "$PID_HELPER" ]] || PID_HELPER="$ROOT/tools/domain-pid.sh"
pid="$(SAFEBOX_CONFIG_FILE="$CONFIG" "$PID_HELPER" "$DOMAIN" 2>/dev/null || true)"
if [[ "$pid" =~ ^[0-9]+$ ]] && "${SUDO[@]}" test -r "/proc/$pid/status"; then
  status="$("${SUDO[@]}" cat "/proc/$pid/status")"
  expected_uid="$(id -u "${SAFEBOX_EXPECTED_QEMU_USER:-libvirt-qemu}" 2>/dev/null || true)"
  # Literal embedded program/test syntax: $ belongs to that program, not Bash.
  # shellcheck disable=SC2016
  uid_line="$(awk '/^Uid:/{print $2, $3, $4, $5}' <<<"$status")"
  if [[ "$expected_uid" =~ ^[0-9]+$ ]] && awk -v u="$expected_uid" '{for(i=1;i<=NF;i++) if($i!=u) exit 1}' <<<"$uid_line"; then ok 'QEMU läuft als erwarteter Dienstbenutzer'; else bad 'QEMU UID weicht vom erwarteten Dienstbenutzer ab'; fi
  for cap in CapEff CapPrm CapAmb; do
    v="$(awk -v k="$cap:" '$1==k{print $2}' <<<"$status")"
    if [[ "${v:-}" == 0000000000000000 ]]; then ok "$cap = 0"; else bad "$cap nicht leer"; fi
  done
  # Literal embedded program/test syntax: $ belongs to that program, not Bash.
  # shellcheck disable=SC2016
  if [[ "$(awk '/^Seccomp:/{print $2}' <<<"$status")" == 2 ]]; then ok 'Seccomp Filter aktiv'; else bad 'Seccomp nicht bestätigt'; fi
  aa="$("${SUDO[@]}" cat "/proc/$pid/attr/current" 2>/dev/null || true)"
  if [[ "$aa" == *libvirt* && "$aa" == *'(enforce)'* ]]; then ok 'AppArmor enforce aktiv'; else bad "AppArmor nicht im Enforce-Modus: ${aa:-unbekannt}"; fi
  qmnt="$("${SUDO[@]}" readlink "/proc/$pid/ns/mnt" 2>/dev/null || true)"; imnt="$("${SUDO[@]}" readlink /proc/1/ns/mnt 2>/dev/null || true)"
  if [[ -n "$qmnt" && -n "$imnt" && "$qmnt" != "$imnt" ]]; then ok 'Mount-Namespace separat'; else bad 'Mount-Namespace nicht isoliert'; fi

  # QEMU-Monitor/QMP darf nicht über TCP/Telnet exponiert sein.
  cmdline="$("${SUDO[@]}" cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' '\n' || true)"
  if python3 - "$cmdline" <<'PY'
import sys
args=sys.argv[1].splitlines()
bad=False
for i,a in enumerate(args):
    if a in ('-monitor','-qmp') and i+1 < len(args):
        v=args[i+1].lower()
        if v.startswith(('tcp:','telnet:','udp:')): bad=True
    if 'id=charmonitor' in a.lower() and any(x in a.lower() for x in ('host=','port=','tcp:','telnet:')): bad=True
raise SystemExit(1 if bad else 0)
PY
  then ok 'QEMU-Monitor nur lokal/FD-basiert'; else bad 'QEMU-Monitor über Netzwerk exponiert'; fi
else
  bad 'QEMU PID/Domain-Zuordnung nicht eindeutig bestätigt'
fi
fi

printf '\nRuntime-Ergebnis: %d PASS, %d FAIL\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
