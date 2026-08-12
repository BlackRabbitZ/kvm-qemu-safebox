#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
pass(){ printf '[PASS] %s\n' "$1"; }
fail(){ printf '[FAIL] %s\n' "$1"; FAIL=1; }
RUNTIME="$ROOT/vm/templates/runtime.xml.in"
INSTALLER="$ROOT/vm/templates/installer.xml.in"

for f in "$RUNTIME" "$INSTALLER"; do
  base="${f##*/}"
  grep -q "controller type='usb' model='none'" "$f" && pass "USB-Controller explizit aus: $base" || fail "USB nicht aus: $f"
  if ! grep -Eq '<hostdev|<filesystem|<channel|<redirdev|<smartcard|<shmem|<sound|<audio|<rng|<tpm|<vsock|<watchdog' "$f"; then pass "Keine verbotene Host-Integration: $base"; else fail "Verbotenes Gerät gefunden: $f"; fi
  grep -q "clipboard copypaste='no'" "$f" && pass "Clipboard aus: $base" || fail "Clipboard nicht aus: $f"
  grep -q "filetransfer enable='no'" "$f" && pass "SPICE-Dateitransfer aus: $base" || fail "Dateitransfer nicht aus: $f"
  grep -q '<nosharepages/>' "$f" && pass "KSM/Memory-Merging aus: $base" || fail "nosharepages fehlt: $f"
  grep -q "<listen type='none'/>" "$f" && pass "Kein frei lauschender SPICE-Port: $base" || fail "SPICE listen nicht none: $f"
  grep -q "<pmu state='off'/>" "$f" && pass "Virtuelle PMU aus: $base" || fail "PMU nicht aus: $f"
  grep -q "<vmport state='off'/>" "$f" && pass "VMware-vmport aus: $base" || fail "vmport nicht aus: $f"
  grep -q "seclabel type='dynamic' model='apparmor'" "$f" && pass "AppArmor-Seclabel explizit: $base" || fail "AppArmor-Seclabel fehlt: $f"
  grep -q "discard='ignore'" "$f" && pass "Gast-Discard zur Host-Storage-Schicht deaktiviert: $base" || fail "discard ist nicht ignore: $f"
  if grep -q "feature policy='disable' name='vmx'" "$f" && grep -q "feature policy='disable' name='svm'" "$f"; then
    pass "Nested-Virtualisierung aus: $base"
  else
    fail "Nested-Virtualisierung nicht explizit aus: $f"
  fi
done

grep -q "filterref filter='clean-traffic'" "$INSTALLER" && pass "Installer nutzt Anti-Spoofing-nwfilter" || fail "Installer-nwfilter fehlt"
grep -q "filterref filter='\$SAFEBOX_NWFILTER'" "$ROOT/safebox" && pass "Runtime-Netzblock nutzt libvirt clean-traffic" || fail "Runtime-nwfilter fehlt"
grep -q 'security_require_confined = 1' "$ROOT/host/harden-libvirt.sh" && pass "Host verbietet unconfined Gäste" || fail "security_require_confined fehlt"
grep -q 'seccomp_sandbox = 1' "$ROOT/host/harden-libvirt.sh" && pass "Host erzwingt QEMU-seccomp" || fail "seccomp_sandbox fehlt"
grep -q 'max_core = 0' "$ROOT/host/harden-libvirt.sh" && pass "Host deaktiviert QEMU-Core-Dumps" || fail "max_core=0 fehlt"
grep -q 'dump_guest_core = 0' "$ROOT/host/harden-libvirt.sh" && pass "Host schließt Gast-RAM aus Core-Dumps aus" || fail "dump_guest_core=0 fehlt"

grep -q "CTRL_IP_LEARNING' value='dhcp'" "$INSTALLER" && pass "Installer nutzt DHCP-Snooping für nwfilter" || fail "DHCP-Snooping im Installer fehlt"
grep -q "parameter name='IP' value='\$SAFEBOX_GUEST_IP'" "$ROOT/safebox" && pass "Runtime-nwfilter erzwingt feste Gast-IP" || fail "Feste Runtime-IP im nwfilter fehlt"
grep -q "source network='safebox-install-net'" "$INSTALLER" && pass "Installer nutzt getrenntes Installationsnetz" || fail "Installer-Netztrennung fehlt"
grep -q 'ipv4.method manual' "$ROOT/guest/harden.sh" && pass "Gast-Härtung konfiguriert statische Runtime-IPv4" || fail "Statische Runtime-IPv4 fehlt"
grep -q 'ipv6.method disabled' "$ROOT/guest/harden.sh" && pass "NetworkManager-IPv6 im Runtime-Profil deaktiviert" || fail "NetworkManager-IPv6-Härtung fehlt"
grep -q "<dns enable='no'/>" "$ROOT/network/safebox-net.xml" && pass "Runtime-libvirt-DNS deaktiviert" || fail "Runtime-libvirt-DNS nicht deaktiviert"
if ! grep -q '<dhcp>' "$ROOT/network/safebox-net.xml"; then pass "Runtime-libvirt-DHCP entfernt"; else fail "Runtime-libvirt-DHCP ist noch aktiv"; fi
if ! grep -Eq 'usermod.*(libvirt|kvm)' "$ROOT/install/install-host.sh"; then pass "Installer vergibt keine pauschalen libvirt/kvm-Gruppenrechte"; else fail "Installer erweitert libvirt/kvm-Gruppenrechte"; fi

exit "$FAIL"
