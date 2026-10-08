#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ${EUID} -ne 0 ]]; then exec sudo -- /usr/bin/bash "$0" "$@"; fi

install -d -m 0755 -o root -g root /usr/local/libexec/safebox /etc/safebox
install -d -m 0700 -o root -g root /run/safebox /run/safebox/tmp

for f in security_gate.py hardware-acceptance.py runtime-watch.sh runtime-verify.sh firewall-verify.sh qemu-security-check.sh kill-domain.sh domain-pid.sh storage-verify.sh nwfilter-verify.sh xml-policy-check.py proc-absence.py nwfilter-canon.py check-host-qemu-config.py local-routes.py stage-sample.py sample-verify.sh storage-crypto-check.py; do
  install -m 0755 -o root -g root "$ROOT/tools/$f" "/usr/local/libexec/safebox/$f"
done
install -m 0644 -o root -g root "$ROOT/vm/templates/runtime.xml.in" /usr/local/libexec/safebox/runtime.xml.in
install -m 0755 -o root -g root "$ROOT/network/apply-firewall.sh" /usr/local/libexec/safebox/apply-firewall.sh
install -m 0644 -o root -g root "$ROOT/config/defaults.conf" /etc/safebox/defaults.conf
install -m 0644 -o root -g root "$ROOT/network/safebox-runtime-filter.xml" /etc/safebox/safebox-runtime-filter.xml
install -m 0644 -o root -g root "$ROOT/network/safebox-install-filter.xml" /etc/safebox/safebox-install-filter.xml
install -m 0644 -o root -g root "$ROOT/systemd/safebox-kill@.service" /etc/systemd/system/safebox-kill@.service
install -m 0644 -o root -g root "$ROOT/systemd/safebox-tmpfiles.conf" /usr/lib/tmpfiles.d/safebox.conf
systemd-tmpfiles --create /usr/lib/tmpfiles.d/safebox.conf

# Define the project-owned nwfilter. The XML source itself is root-owned, so the
# installed baseline is independent of distro-provided clean-traffic filters.
virsh -c qemu:///system nwfilter-define /etc/safebox/safebox-runtime-filter.xml >/dev/null
virsh -c qemu:///system nwfilter-define /etc/safebox/safebox-install-filter.xml >/dev/null

tmp="$(mktemp -p /run/safebox/tmp nwfilter.XXXXXX.xml)"
trap 'rm -f -- "$tmp"' EXIT
virsh -c qemu:///system nwfilter-dumpxml safebox-runtime-filter >"$tmp"
python3 "$ROOT/tools/nwfilter-canon.py" <"$tmp" | awk '{print $1 "  safebox-runtime-filter"}' >/etc/safebox/nwfilter.sha256
chown root:root /etc/safebox/nwfilter.sha256
chmod 0400 /etc/safebox/nwfilter.sha256

systemctl daemon-reload
printf '[OK] Root-owned Runtime-Helfer, eigener nwfilter und Fail-Closed Kill-Service installiert.\n'
