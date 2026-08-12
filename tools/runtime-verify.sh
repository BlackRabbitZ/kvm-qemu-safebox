#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/config/defaults.conf"

DOMAIN="${1:-}"
MODE="${2:-auto}"
EXPECTED_DISK="${3:-}"
[[ -n "$DOMAIN" ]] || { echo "Verwendung: $0 DOMAIN [runtime|installer|offline|auto] [EXPECTED_DISK]" >&2; exit 2; }

SUDO=()
if [[ ${EUID} -ne 0 ]]; then SUDO=(sudo); fi
PASS=0; FAIL=0
ok(){ printf '\033[32m[PASS]\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad(){ printf '\033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }

need(){ command -v "$1" >/dev/null 2>&1 || { bad "Programm fehlt: $1"; return 1; }; }
need virsh || exit 1
need xmllint || exit 1

if ! "${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" dominfo "$DOMAIN" >/dev/null 2>&1; then
  bad "Domain existiert nicht: $DOMAIN"
  exit 1
fi

state="$("${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" domstate "$DOMAIN" 2>/dev/null || true)"
if grep -qiE 'running|laufend|idle|paused|angehalten' <<<"$state"; then
  ok "Domain läuft: $DOMAIN"
else
  bad "Domain ist nicht laufend: $state"
fi

xml="$(mktemp)"
trap 'rm -f "$xml"' EXIT
"${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" dumpxml "$DOMAIN" > "$xml" || {
  bad "Live-Domain-XML konnte nicht gelesen werden"
  exit 1
}

x(){ xmllint --xpath "$1" "$xml" 2>/dev/null; }
count(){ x "count($1)"; }
assert_count(){ local path=$1 expected=$2 msg=$3 got; got="$(count "$path")"; [[ "$got" == "$expected" ]] && ok "$msg" || bad "$msg (gefunden: $got, erwartet: $expected)"; }
assert_xpath(){ local expr=$1 msg=$2; [[ "$(x "boolean($expr)")" == "true" ]] && ok "$msg" || bad "$msg"; }

# Angriffsfläche: keine Host-Integrations-/Passthrough-Geräte.
for node in hostdev filesystem channel redirdev smartcard shmem sound audio rng tpm vsock watchdog serial parallel console panic iommu crypto memory lease hub; do
  assert_count "/domain/devices/$node" 0 "Kein <$node>-Gerät"
done
assert_xpath "/domain[@type='kvm']" "Domain verwendet KVM"
assert_count "/domain/devices/emulator" 1 "Genau ein QEMU-Emulator"
assert_xpath "/domain/devices/emulator[text()='/usr/bin/qemu-system-x86_64']" "Erwarteter QEMU-Systememulator"
assert_xpath "/domain/os/type[@arch='x86_64']" "Gastarchitektur ist x86_64"
assert_xpath "/domain/memoryBacking/nosharepages" "Memory Sharing/KSM für die Domain deaktiviert"
assert_xpath "/domain/devices/controller[@type='usb' and @model='none']" "USB-Controller explizit deaktiviert"
assert_xpath "/domain/devices/memballoon[@model='none']" "Memory Balloon deaktiviert"
assert_xpath "/domain/features/pmu[@state='off']" "Virtuelle PMU deaktiviert"
assert_xpath "/domain/features/vmport[@state='off']" "VMware vmport deaktiviert"
assert_xpath "/domain/cpu/feature[@name='vmx' and @policy='disable']" "Intel Nested Virtualization deaktiviert"
assert_xpath "/domain/cpu/feature[@name='svm' and @policy='disable']" "AMD Nested Virtualization deaktiviert"
assert_xpath "/domain/seclabel[@model='apparmor' and @type='dynamic']" "Domain verlangt dynamisches AppArmor-Confinement"

assert_count "/domain/devices/graphics" 1 "Genau ein Grafikgerät"
assert_xpath "/domain/devices/graphics[@type='spice']/listen[@type='none']" "SPICE lauscht auf keinem Netzwerk-Socket"
assert_xpath "/domain/devices/graphics[@type='spice']/clipboard[@copypaste='no']" "SPICE-Clipboard deaktiviert"
assert_xpath "/domain/devices/graphics[@type='spice']/filetransfer[@enable='no']" "SPICE-Dateitransfer deaktiviert"
assert_xpath "/domain/devices/graphics[@type='spice']/gl[@enable='no']" "SPICE OpenGL deaktiviert"
assert_count "/domain/devices/video" 1 "Genau ein virtuelles Videogerät"
assert_xpath "/domain/devices/video/model[@type='virtio']" "Videogerät verwendet VirtIO"

assert_count "/domain/devices/disk[@device='disk']" 1 "Genau eine beschreibbare virtuelle Systemdisk"
assert_xpath "/domain/devices/disk[@device='disk']/driver[@type='qcow2']" "Systemdisk verwendet explizit QCOW2"
assert_xpath "/domain/devices/disk[@device='disk']/target[@bus='virtio']" "Systemdisk verwendet VirtIO"
if [[ -n "$EXPECTED_DISK" ]]; then
  actual_disk="$(x 'string(/domain/devices/disk[@device="disk"]/source/@file)')"
  [[ "$actual_disk" == "$EXPECTED_DISK" ]] && ok "Live-Domain verwendet erwartetes Overlay" || bad "Unerwartete Live-Disk: $actual_disk"
fi

if [[ "$MODE" == "auto" ]]; then
  case "$DOMAIN" in
    safebox-offline-*) MODE=offline ;;
    safebox-installer) MODE=installer ;;
    *) MODE=runtime ;;
  esac
fi
[[ "$MODE" == "online" ]] && MODE=runtime  # Abwärtskompatibler Alias.

if [[ "$MODE" == "offline" ]]; then
  assert_count "/domain/devices/disk[@device='cdrom']" 0 "Offline-Runtime enthält kein CD-ROM"
  assert_count "/domain/devices/interface" 0 "Offline-Modus enthält keine Netzwerkkarte"
elif [[ "$MODE" == "installer" ]]; then
  assert_count "/domain/devices/disk[@device='cdrom']" 1 "Installer enthält genau ein CD-ROM"
  assert_xpath "/domain/devices/disk[@device='cdrom']/source[@file='$SAFEBOX_INSTALL_ISO']" "Installer verwendet ausschließlich die vertrauenswürdige ISO-Kopie"
  assert_xpath "/domain/devices/disk[@device='cdrom']/readonly" "Installer-ISO ist schreibgeschützt"
  assert_count "/domain/devices/interface" 1 "Installer enthält genau eine Netzwerkkarte"
  assert_xpath "/domain/devices/interface[@type='network']/source[@network='$SAFEBOX_INSTALL_NETWORK_NAME']" "Installer nutzt ausschließlich das getrennte Installationsnetz"
  assert_xpath "/domain/devices/interface/mac[@address='$SAFEBOX_MAC']" "Erwartete feste MAC-Adresse"
  assert_xpath "/domain/devices/interface/model[@type='virtio']" "VirtIO-Netzwerkmodell"
  assert_xpath "/domain/devices/interface/rom[@bar='off']" "NIC Option-ROM deaktiviert"
  assert_xpath "/domain/devices/interface/port[@isolated='yes']" "libvirt-Port-Isolation aktiv"
  assert_xpath "/domain/devices/interface/filterref[@filter='$SAFEBOX_NWFILTER']/parameter[@name='CTRL_IP_LEARNING' and @value='dhcp']" "Installer-nwfilter nutzt DHCP-Snooping"
else
  assert_count "/domain/devices/disk[@device='cdrom']" 0 "Runtime enthält kein CD-ROM"
  assert_count "/domain/devices/interface" 1 "Runtime enthält genau eine Netzwerkkarte"
  assert_xpath "/domain/devices/interface[@type='network']/source[@network='$SAFEBOX_NETWORK']" "Runtime-Interface nutzt ausschließlich safebox-net"
  assert_xpath "/domain/devices/interface/mac[@address='$SAFEBOX_MAC']" "Erwartete feste MAC-Adresse"
  assert_xpath "/domain/devices/interface/model[@type='virtio']" "VirtIO-Netzwerkmodell"
  assert_xpath "/domain/devices/interface/rom[@bar='off']" "NIC Option-ROM deaktiviert"
  assert_xpath "/domain/devices/interface/port[@isolated='yes']" "libvirt-Port-Isolation aktiv"
  assert_xpath "/domain/devices/interface/filterref[@filter='$SAFEBOX_NWFILTER']/parameter[@name='IP' and @value='$SAFEBOX_GUEST_IP']" "Runtime-nwfilter erzwingt die feste Gast-IP"
fi

# QEMU-Prozess finden. Libvirt legt auf Linux regulär eine PID-Datei an;
# als robuste Rückfallebene wird über die Domain-UUID gesucht.
pid=""
for pf in "/run/libvirt/qemu/$DOMAIN.pid" "/var/run/libvirt/qemu/$DOMAIN.pid"; do
  if "${SUDO[@]}" test -r "$pf"; then
    pid="$("${SUDO[@]}" cat "$pf" 2>/dev/null || true)"
    [[ "$pid" =~ ^[0-9]+$ ]] && break
    pid=""
  fi
done
if [[ -z "$pid" ]]; then
  uuid="$("${SUDO[@]}" virsh -c "$SAFEBOX_CONNECT_URI" domuuid "$DOMAIN" 2>/dev/null || true)"
  if [[ -n "$uuid" ]]; then
    pid="$(ps -eo pid=,args= | awk -v u="$uuid" 'index($0,u){print $1; exit}')"
  fi
fi

if [[ "$pid" =~ ^[0-9]+$ ]] && "${SUDO[@]}" test -r "/proc/$pid/status"; then
  ok "QEMU-Prozess gefunden (PID $pid)"
  status="$("${SUDO[@]}" cat "/proc/$pid/status")"
  uid_line="$(awk '/^Uid:/{print $2, $3, $4, $5}' <<<"$status")"
  if awk '{for(i=1;i<=NF;i++) if($i==0) exit 1; exit 0}' <<<"$uid_line"; then
    ok "QEMU läuft vollständig non-root (UIDs: $uid_line)"
  else
    bad "QEMU besitzt UID 0 (UIDs: $uid_line)"
  fi

  seccomp="$(awk '/^Seccomp:/{print $2}' <<<"$status")"
  [[ "$seccomp" == "2" ]] && ok "QEMU läuft mit Seccomp-Filtermodus 2" || bad "QEMU Seccomp ist nicht Filtermodus 2 (Wert: ${seccomp:-unbekannt})"

  aa="$("${SUDO[@]}" cat "/proc/$pid/attr/current" 2>/dev/null || true)"
  if [[ -n "$aa" && "$aa" != unconfined* && "$aa" == *libvirt* ]]; then
    ok "QEMU ist durch ein libvirt-AppArmor-Profil confined: $aa"
  else
    bad "QEMU-AppArmor-Profil nicht sicher bestätigt: ${aa:-leer}"
  fi

  mnt_qemu="$("${SUDO[@]}" readlink "/proc/$pid/ns/mnt" 2>/dev/null || true)"
  mnt_init="$("${SUDO[@]}" readlink /proc/1/ns/mnt 2>/dev/null || true)"
  if [[ -n "$mnt_qemu" && -n "$mnt_init" && "$mnt_qemu" != "$mnt_init" ]]; then
    ok "QEMU besitzt einen separaten Mount-Namespace"
  else
    bad "Separater QEMU-Mount-Namespace nicht bestätigt"
  fi

  cg="$("${SUDO[@]}" cat "/proc/$pid/cgroup" 2>/dev/null || true)"
  if grep -qiE 'libvirt|machine-qemu|machine.slice' <<<"$cg"; then
    ok "QEMU ist in einer dedizierten libvirt/systemd-Cgroup"
  else
    bad "Dedizierte QEMU-Cgroup nicht bestätigt"
  fi
else
  bad "QEMU-Prozess/PID konnte nicht sicher bestimmt werden"
fi

printf '\nRuntime-Ergebnis: %d PASS, %d FAIL\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
