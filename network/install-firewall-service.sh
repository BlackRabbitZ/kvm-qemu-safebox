#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ ${EUID} -ne 0 ]]; then exec sudo -- /usr/bin/bash "$0" "$@"; fi
install -d -m 0755 /usr/local/libexec/safebox
install -m 0755 "$ROOT/apply-firewall.sh" /usr/local/libexec/safebox/apply-firewall.sh
install -m 0644 "$ROOT/safebox-firewall.service" /etc/systemd/system/safebox-firewall.service
systemctl daemon-reload
systemctl enable --now safebox-firewall.service
/usr/bin/bash /usr/local/libexec/safebox/apply-firewall.sh
