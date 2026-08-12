# 🛡️ KVM-QEMU-SafeBox

> [!NOTE]
> **Idee & Umsetzung:** Die ursprüngliche Idee für dieses Projekt stammt von **Esmaralda Haze**. Sie ist nicht meine eigene Idee – ich, **BlackRabbitZ**, habe sie technisch umgesetzt und als dieses Repository realisiert.

[![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)](#)
[![Guest](https://img.shields.io/badge/Guest-Debian%2013%20%2B%20XFCE-A81D33?logo=debian&logoColor=white)](https://www.debian.org/releases/trixie/)
[![Hypervisor](https://img.shields.io/badge/Hypervisor-KVM%20%2F%20QEMU-6C5CE7)](https://www.qemu.org/)
[![Security](https://img.shields.io/badge/security-fail--closed-success)](SECURITY.md)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![CI](https://github.com/BlackRabbitZ/kvm-qemu-safebox/actions/workflows/ci.yml/badge.svg)](https://github.com/BlackRabbitZ/kvm-qemu-safebox/actions/workflows/ci.yml)

**KVM-QEMU-SafeBox** ist eine bewusst minimal integrierte Desktop-VM für potenziell riskante Workloads. Das Sicherheitsmodell nimmt an, dass der Gast vollständig kompromittiert sein kann und ein Angreifer dort **Root** besitzt.

> [!IMPORTANT]
> SafeBox reduziert die Angriffsfläche und erzwingt mehrere unabhängige Sicherheitsgrenzen. Sie kann unbekannte Schwachstellen in Linux/KVM, QEMU, libvirt, CPU/Mikrocode oder Hardware nicht mathematisch ausschließen.

## Sicherheitsmodell in v0.2.0

```text
                          INTERNET
                             │
                        libvirt NAT
                             │
                    ┌────────▼────────┐
                    │ nftables Guard  │
                    │ Host/LAN DROP   │
                    │ IPv6 DROP ALL   │
                    └────────┬────────┘
                             │
                    libvirt nwfilter
                  MAC/IP/ARP Anti-Spoof
                             │
                     virbr-safebox
                             │
                 ┌───────────▼──────────┐
                 │ Debian 13 XFCE       │
                 │ Gast = untrusted     │
                 │ statisch 10.77.0.100 │
                 └──────────────────────┘

Runtime-Bridge:
  • KEIN DHCP-Dienst auf dem Host
  • KEIN DNS-Dienst auf dem Host
  • Gast -> Host vollständig DROP
  • IPv6 in beide Richtungen DROP
  • RFC1918/Sonderziele DROP
  • nur Antworten auf vom Gast initiierte Internet-Verbindungen zurück

QEMU auf dem Host:
  • non-root
  • AppArmor verpflichtend
  • seccomp verpflichtend
  • eigener Mount-Namespace
  • dedizierte Cgroup
  • Runtime-Attestation nach jedem Start
```

Für die **vertrauenswürdige Debian-Erstinstallation** existiert separat `safebox-install-net` / `virbr-safebox-inst`. Nur dort werden temporär DHCP und DNS bereitgestellt. `seal-base` entfernt dieses Installationsnetz wieder vollständig. Der normale Runtime-Gast wird nie daran angeschlossen.

## Was explizit deaktiviert ist

| Funktion | Status |
|---|:---:|
| Host-Verzeichnisse / virtiofs / 9p | ❌ AUS |
| USB-/PCI-Passthrough | ❌ AUS |
| USB-Controller | ❌ AUS |
| Shared Clipboard | ❌ AUS |
| Drag & Drop / SPICE File Transfer | ❌ AUS |
| QEMU Guest Agent / zusätzliche Channels | ❌ AUS |
| Bridged Networking zum LAN | ❌ AUS |
| SPICE OpenGL / 3D | ❌ AUS |
| Audio | ❌ AUS |
| Memory Balloon | ❌ AUS |
| KSM / Page Sharing | ❌ AUS |
| Nested Virtualization VMX/SVM | ❌ AUS |
| virtuelle PMU / VMware vmport | ❌ AUS |
| IPv6 aus/zur SafeBox | ❌ HOSTSEITIG GEBLOCKT |
| Runtime-DHCP auf dem Host | ❌ AUS |
| Runtime-DNS auf dem Host | ❌ AUS |
| SafeBox-Netzwerk-Autostart | ❌ AUS |

## Fail-closed statt Warnungen

Eine SafeBox startet nur, wenn die erwarteten Schutzschichten vorhanden sind. Nach dem Start überprüft `tools/runtime-verify.sh` die **tatsächlich laufende** Domain und den QEMU-Prozess. Unter anderem werden geprüft:

- Live-Domain-XML statt nur Repository-Templates
- keine Host-Integration/Passthrough-Geräte
- SPICE `listen=none`, Clipboard/Filetransfer/GL aus
- Runtime genau eine NIC, Offline keine NIC
- Installer und Runtime verwenden unterschiedliche libvirt-Netze
- Installer: Anti-Spoofing-`nwfilter` mit DHCP-Snooping
- Runtime: Anti-Spoofing-`nwfilter` mit fest gepinnter IPv4
- Runtime-Netz: kein DHCP und kein libvirt-DNS
- kein unerwarteter Runtime-`dnsmasq`-Prozess
- QEMU läuft ohne UID 0
- Linux `Seccomp: 2`
- QEMU läuft in einem libvirt-AppArmor-Profil
- separater Mount-Namespace
- dedizierte libvirt/systemd-Cgroup

Fehlschlag bedeutet: **VM wird automatisch beendet.**

---

# Installation

## 1. Host vorbereiten

Primäres Zielsystem ist ein aktueller **Debian-13-Host** mit Intel VT-x oder AMD-V und `/dev/kvm`.

```bash
git clone https://github.com/BlackRabbitZ/kvm-qemu-safebox.git
cd kvm-qemu-safebox
sudo bash ./install/install-host.sh
```

Der Installer:

- installiert KVM/QEMU/libvirt sowie Network-/nwfilter-Komponenten
- aktiviert AppArmor
- erzwingt in `/etc/libvirt/qemu.conf`:

```ini
security_driver = "apparmor"
security_default_confined = 1
security_require_confined = 1
seccomp_sandbox = 1
max_core = 0
dump_guest_core = 0
```

- deaktiviert QEMU-Core-Dumps
- installiert den persistenten `safebox-firewall.service`
- fügt den normalen Desktop-Benutzer **nicht** automatisch zu `libvirt` oder `kvm` hinzu

> [!WARNING]
> Die Einstellungen in `qemu.conf` gelten für die **systemweite libvirt-QEMU-Instanz**. SafeBox ist für einen bewusst gehärteten Host gedacht. Vorhandene andere VMs müssen mit verpflichtendem Confinement kompatibel sein.

Danach:

```bash
bash ./safebox doctor
```

## 2. Basis-VM installieren

Eine offizielle Debian-13-Netinst-ISO verwenden und deren Prüfsumme/Signatur separat über Debian verifizieren.

```bash
bash ./safebox create-base ~/Downloads/debian-13.x.x-amd64-netinst.iso
```

`create-base` richtet automatisch das getrennte **Installationsnetz** ein. Falls zuvor das sichere Runtime-Netz aktiv war, wird es nach erfolgreicher Policy-Prüfung für die Installation gestoppt.

Falls kein Fenster erscheint:

```bash
bash ./safebox viewer safebox-installer
```

Im Debian-Installer:

- XFCE auswählen
- **keinen SSH-Server** installieren
- nur die vertrauenswürdige Basisinstallation/Härtung durchführen
- das Installationsnetz nicht für spätere riskante Workloads verwenden

## 3. Gast härten und auf statisches Runtime-Netz umstellen

Vor dem Versiegeln im frisch installierten Debian-Gast:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/BlackRabbitZ/kvm-qemu-safebox.git
cd kvm-qemu-safebox
sudo bash ./guest/harden.sh
sudo poweroff
```

Das Skript:

- installiert/aktiviert AppArmor, nftables und unattended-upgrades
- entfernt bzw. maskiert Guest Agent, SPICE-Agent, SSH-Server, Avahi und CUPS
- setzt konservative Kernel-/Netzwerk-Sysctls
- konfiguriert das SafeBox-NIC-Profil für den nächsten Boot statisch auf `10.77.0.100/24`
- setzt Gateway `10.77.0.1`
- deaktiviert IPv6 zusätzlich im NetworkManager-Profil
- setzt standardmäßig `9.9.9.9` und `149.112.112.112` als öffentliche DNS-Resolver

> [!IMPORTANT]
> Nach `guest/harden.sh` die Installer-VM **vollständig herunterfahren** und anschließend versiegeln. Die statische Konfiguration wird beim ersten Runtime-Boot aktiv. Für die Host-Sicherheit wird der Gastkonfiguration trotzdem nicht vertraut; dieselbe IP/IPv6-Policy wird hostseitig erzwungen.

## 4. Basis versiegeln

Auf dem Host:

```bash
bash ./safebox seal-base
```

Dabei werden:

1. die Installer-Domain entfernt,
2. `safebox-install-net` gestoppt und undefiniert,
3. `qemu-img check` ausgeführt,
4. die Installer-ISO entfernt,
5. das Basisimage auf `root:<QEMU-Gruppe>` / `0440` gesetzt,
6. eine SHA-256-Prüfdatei erzeugt.

Vor jedem späteren Start wird das Base-Image erneut gegen diesen Hash geprüft.

## 5. Runtime-Netz optional vorab prüfen

Nicht zwingend erforderlich – jeder Online-Start richtet es selbst fail-closed ein:

```bash
bash ./safebox setup-network
```

Erwartete Runtime-Werte:

```text
Netz:      safebox-net
Bridge:    virbr-safebox
Subnetz:   10.77.0.0/24
Gateway:   10.77.0.1
Gast-IP:   10.77.0.100 (statisch im Gast + hostseitig gepinnt)
MAC:       52:54:00:77:00:10
DHCP:      AUS
Host-DNS:  AUS
IPv6:      HOSTSEITIG DROP ALL
```

Ein bereits vorhandenes libvirt-Netz wird mit `net-dumpxml` geprüft. Abweichungen führen zum Startabbruch. Das Netzwerk wird absichtlich **nicht autogestartet**.

---

# Benutzung

## Disposable

```bash
bash ./safebox start disposable
```

Temporäres QCOW2-Overlay, das nach Ende der transienten Domain logisch gelöscht wird.

## Persistent

```bash
bash ./safebox start persistent
```

Dauerhaftes Overlay unter:

```text
/var/lib/libvirt/images/safebox/persistent.qcow2
```

Das Backing-Image wird vor dem Start geprüft und muss exakt das versiegelte SafeBox-Basisimage sein.

## Offline

```bash
bash ./safebox start offline
```

Das Domain-XML enthält **keine virtuelle Netzwerkkarte**.

## Laufende VM nochmals prüfen

```bash
bash ./safebox verify-runtime
```

oder:

```bash
bash ./safebox verify-runtime safebox-persistent
```

## Gesamtdiagnose / Repository-Prüfung

```bash
bash ./safebox doctor
make release-check
```

## Verwaiste Disposable-Overlays entfernen

```bash
bash ./safebox cleanup-sessions
```

---

# Wichtige Grenzen

SafeBox bietet **keine Garantie gegen unbekannte VM-Escapes**. Sie schützt außerdem nicht gegen einen bereits kompromittierten Host, kompromittierten Host-Administrator, bösartige Firmware oder unbekannte Hardware-/CPU-Schwachstellen. Der Host sollte aktuell, minimal und vertrauenswürdig gehalten werden.

Online-Sitzungen dürfen weiterhin mit nicht blockierten öffentlichen Internetzielen kommunizieren. Ein kompromittierter Gast kann deshalb Daten ins Internet exfiltrieren. SafeBox ist Netzwerk-/Host-Isolation, **kein Anonymisierungsnetzwerk**.

**Disposable bedeutet nicht „forensisch sicher gelöscht“.** `rm` entfernt das Overlay logisch aus dem Dateisystem; auf SSDs, CoW-Dateisystemen, Snapshots oder Backups kann physische Rekonstruktion nicht pauschal ausgeschlossen werden. Für sensible Systeme sollte der Host-Speicher vollständig verschlüsselt sein.

Mehr dazu:

- [`docs/threat-model.md`](docs/threat-model.md)
- [`docs/hardening.md`](docs/hardening.md)
- [`docs/networking.md`](docs/networking.md)
- [`docs/runtime-attestation.md`](docs/runtime-attestation.md)
- [`docs/limitations.md`](docs/limitations.md)

---

# Repository-Struktur

```text
kvm-qemu-safebox/
├── safebox
├── host/
│   └── harden-libvirt.sh
├── install/
│   └── install-host.sh
├── network/
│   ├── safebox-net.xml
│   ├── safebox-install-net.xml
│   ├── safebox-guard.nft
│   ├── apply-firewall.sh
│   └── safebox-firewall.service
├── vm/templates/
│   ├── installer.xml.in
│   └── runtime.xml.in
├── guest/
│   ├── harden.sh
│   ├── nftables.conf
│   └── 99-safebox-hardening.conf
├── tools/
│   ├── runtime-verify.sh
│   └── verify-attribution.sh
├── tests/
├── docs/
└── .github/workflows/ci.yml
```

# Lizenz / Attribution

Apache License 2.0. Siehe [`LICENSE`](LICENSE), [`NOTICE`](NOTICE) und [`ATTRIBUTION.md`](ATTRIBUTION.md).
