#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
pass(){ printf '[PASS] %s\n' "$1"; }
fail(){ printf '[FAIL] %s\n' "$1"; FAIL=1; }
check_grep(){
  local pattern=$1 file=$2 success=$3 failure=$4
  if grep -q -- "$pattern" "$file"; then
    pass "$success"
  else
    fail "$failure"
  fi
}
RUNTIME="$ROOT/vm/templates/runtime.xml.in"
INSTALLER="$ROOT/vm/templates/installer.xml.in"

for f in "$RUNTIME" "$INSTALLER"; do
  base="${f##*/}"
  check_grep "controller type='usb' model='none'" "$f" \
    "USB-Controller explizit aus: $base" "USB nicht aus: $f"

  if ! grep -Eq '<hostdev|<filesystem|<channel|<redirdev|<smartcard|<shmem|<sound|<audio|<rng|<tpm|<vsock|<watchdog' "$f"; then
    pass "Keine verbotene Host-Integration: $base"
  else
    fail "Verbotenes Gerät gefunden: $f"
  fi

  check_grep "clipboard copypaste='no'" "$f" \
    "Clipboard aus: $base" "Clipboard nicht aus: $f"
  check_grep "filetransfer enable='no'" "$f" \
    "SPICE-Dateitransfer aus: $base" "Dateitransfer nicht aus: $f"
  check_grep '<nosharepages/>' "$f" \
    "KSM/Memory-Merging aus: $base" "nosharepages fehlt: $f"
  check_grep "<listen type='none'/>" "$f" \
    "Kein frei lauschender SPICE-Port: $base" "SPICE listen nicht none: $f"
  check_grep "<pmu state='off'/>" "$f" \
    "Virtuelle PMU aus: $base" "PMU nicht aus: $f"
  check_grep "<vmport state='off'/>" "$f" \
    "VMware-vmport aus: $base" "vmport nicht aus: $f"
  check_grep "seclabel type='dynamic' model='apparmor'" "$f" \
    "AppArmor-Seclabel explizit: $base" "AppArmor-Seclabel fehlt: $f"
  check_grep "discard='ignore'" "$f" \
    "Gast-Discard zur Host-Storage-Schicht deaktiviert: $base" "discard ist nicht ignore: $f"

  if grep -q "feature policy='disable' name='vmx'" "$f" \
     && grep -q "feature policy='disable' name='svm'" "$f"; then
    pass "Nested-Virtualisierung aus: $base"
  else
    fail "Nested-Virtualisierung nicht explizit aus: $f"
  fi
done

check_grep "filterref filter='clean-traffic'" "$INSTALLER" \
  "Installer nutzt Anti-Spoofing-nwfilter" "Installer-nwfilter fehlt"
check_grep "filterref filter='\$SAFEBOX_NWFILTER'" "$ROOT/safebox" \
  "Runtime-Netzblock nutzt libvirt clean-traffic" "Runtime-nwfilter fehlt"
check_grep 'security_require_confined = 1' "$ROOT/host/harden-libvirt.sh" \
  "Host verbietet unconfined Gäste" "security_require_confined fehlt"
check_grep 'seccomp_sandbox = 1' "$ROOT/host/harden-libvirt.sh" \
  "Host erzwingt QEMU-seccomp" "seccomp_sandbox fehlt"
check_grep 'max_core = 0' "$ROOT/host/harden-libvirt.sh" \
  "Host deaktiviert QEMU-Core-Dumps" "max_core=0 fehlt"
check_grep 'dump_guest_core = 0' "$ROOT/host/harden-libvirt.sh" \
  "Host schließt Gast-RAM aus Core-Dumps aus" "dump_guest_core=0 fehlt"

check_grep "CTRL_IP_LEARNING' value='dhcp'" "$INSTALLER" \
  "Installer nutzt DHCP-Snooping für nwfilter" "DHCP-Snooping im Installer fehlt"
check_grep "parameter name='IP' value='\$SAFEBOX_GUEST_IP'" "$ROOT/safebox" \
  "Runtime-nwfilter erzwingt feste Gast-IP" "Feste Runtime-IP im nwfilter fehlt"
check_grep "source network='safebox-install-net'" "$INSTALLER" \
  "Installer nutzt getrenntes Installationsnetz" "Installer-Netztrennung fehlt"
check_grep 'ipv4.method manual' "$ROOT/guest/harden.sh" \
  "Gast-Härtung konfiguriert statische Runtime-IPv4" "Statische Runtime-IPv4 fehlt"
check_grep 'ipv6.method disabled' "$ROOT/guest/harden.sh" \
  "NetworkManager-IPv6 im Runtime-Profil deaktiviert" "NetworkManager-IPv6-Härtung fehlt"
check_grep "<dns enable='no'/>" "$ROOT/network/safebox-net.xml" \
  "Runtime-libvirt-DNS deaktiviert" "Runtime-libvirt-DNS nicht deaktiviert"

if ! grep -q '<dhcp>' "$ROOT/network/safebox-net.xml"; then
  pass "Runtime-libvirt-DHCP entfernt"
else
  fail "Runtime-libvirt-DHCP ist noch aktiv"
fi

if ! grep -Eq 'usermod.*(libvirt|kvm)' "$ROOT/install/install-host.sh"; then
  pass "Installer vergibt keine pauschalen libvirt/kvm-Gruppenrechte"
else
  fail "Installer erweitert libvirt/kvm-Gruppenrechte"
fi

exit "$FAIL"
