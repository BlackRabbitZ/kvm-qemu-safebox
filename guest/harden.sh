#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${EUID} -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

[[ -f /etc/debian_version ]] || { echo "FEHLER: Gast-Härtung ist für Debian vorgesehen." >&2; exit 1; }
command -v systemctl >/dev/null || { echo "FEHLER: systemd wird benötigt." >&2; exit 1; }

# Runtime-Netzparameter. Sie entsprechen config/defaults.conf des Projekts.
SAFEBOX_MAC="${SAFEBOX_MAC:-52:54:00:77:00:10}"
SAFEBOX_GUEST_IP="${SAFEBOX_GUEST_IP:-10.77.0.100}"
SAFEBOX_PREFIX="${SAFEBOX_PREFIX:-24}"
SAFEBOX_GATEWAY="${SAFEBOX_GATEWAY:-10.77.0.1}"
SAFEBOX_DNS_PRIMARY="${SAFEBOX_DNS_PRIMARY:-9.9.9.9}"
SAFEBOX_DNS_SECONDARY="${SAFEBOX_DNS_SECONDARY:-149.112.112.112}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  apparmor apparmor-utils nftables unattended-upgrades ca-certificates network-manager

# Bewusst keine Host/Gast-Komfortagenten oder typischen Netzwerkserver.
for pkg in qemu-guest-agent spice-vdagent openssh-server avahi-daemon cups-daemon; do
  # ${Status} wird absichtlich von dpkg-query ausgewertet, nicht von der Shell.
  # shellcheck disable=SC2016
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'ok installed'; then
    apt-get purge -y "$pkg"
  fi
done
apt-get autoremove -y --purge

install -m 0644 "$SCRIPT_DIR/nftables.conf" /etc/nftables.conf
install -m 0644 "$SCRIPT_DIR/99-safebox-hardening.conf" /etc/sysctl.d/99-safebox-hardening.conf

systemctl enable --now apparmor.service
aa-status --enabled >/dev/null 2>&1 || { echo "FEHLER: AppArmor im Gast nicht aktiv." >&2; exit 1; }
systemctl enable --now nftables.service
nft -c -f /etc/nftables.conf
nft list table inet filter >/dev/null

# Auch nach späterer Paketinstallation dürfen diese Dienste nicht versehentlich
# aus dem gehärteten Basisimage heraus exponiert werden.
for unit in ssh.service ssh.socket avahi-daemon.service avahi-daemon.socket cups.service cups.socket; do
  systemctl disable --now "$unit" 2>/dev/null || true
  systemctl mask "$unit" 2>/dev/null || true
done

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'APT'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT
systemctl enable --now apt-daily.timer apt-daily-upgrade.timer

# Runtime benötigt bewusst kein DHCP/DNS auf dem Host. Das aktuell per DHCP
# installierte NetworkManager-Profil wird deshalb für den NÄCHSTEN Boot auf
# eine feste IPv4 + externe DNS-Resolver umgestellt. Die laufende Verbindung
# bleibt unangetastet, damit der Härtungslauf sauber fertig werden kann.
command -v nmcli >/dev/null 2>&1 || { echo "FEHLER: nmcli fehlt trotz network-manager-Paket." >&2; exit 1; }
iface=""
for addr_file in /sys/class/net/*/address; do
  [[ -r "$addr_file" ]] || continue
  if [[ "$(tr '[:upper:]' '[:lower:]' < "$addr_file")" == "${SAFEBOX_MAC,,}" ]]; then
    iface="$(basename -- "$(dirname -- "$addr_file")")"
    break
  fi
done
[[ -n "$iface" ]] || { echo "FEHLER: SafeBox-NIC mit MAC $SAFEBOX_MAC nicht gefunden." >&2; exit 1; }

connection="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null | head -n1)"
[[ -n "$connection" && "$connection" != "--" ]] || { echo "FEHLER: Kein aktives NetworkManager-Profil für $iface gefunden." >&2; exit 1; }

nmcli connection modify "$connection" \
  connection.autoconnect yes \
  ipv4.method manual \
  ipv4.addresses "$SAFEBOX_GUEST_IP/$SAFEBOX_PREFIX" \
  ipv4.gateway "$SAFEBOX_GATEWAY" \
  ipv4.dns "$SAFEBOX_DNS_PRIMARY,$SAFEBOX_DNS_SECONDARY" \
  ipv4.ignore-auto-dns yes \
  ipv6.method disabled

# Persistente Verifikation der Profilwerte; ein Fehler verhindert das Versiegeln.
[[ "$(nmcli -g ipv4.method connection show "$connection")" == "manual" ]] || { echo "FEHLER: statische IPv4-Konfiguration wurde nicht gespeichert." >&2; exit 1; }
grep -Fq "$SAFEBOX_GUEST_IP/$SAFEBOX_PREFIX" < <(nmcli -g ipv4.addresses connection show "$connection") || { echo "FEHLER: erwartete Runtime-IP fehlt im NetworkManager-Profil." >&2; exit 1; }
[[ "$(nmcli -g ipv6.method connection show "$connection")" == "disabled" ]] || { echo "FEHLER: IPv6 ist im NetworkManager-Profil nicht deaktiviert." >&2; exit 1; }

sysctl --system >/dev/null
install -d -m 0755 /etc/safebox
cat > /etc/safebox/hardened <<MARKER
version=0.2.1
network=static
ipv4=$SAFEBOX_GUEST_IP/$SAFEBOX_PREFIX
gateway=$SAFEBOX_GATEWAY
ipv6=disabled
MARKER
chmod 0644 /etc/safebox/hardened

echo "[OK] Gast-Härtung angewendet und verifiziert."
echo "[OK] Runtime-Profil auf statische IPv4 ohne Host-DHCP/DNS vorbereitet."
echo "[INFO] Debian-Gast jetzt vollständig herunterfahren und danach das Basisimage versiegeln."
