# 🛡️ KVM-QEMU-SafeBox

> [!NOTE]
> **Idee & Umsetzung:** Die ursprüngliche Idee für dieses Projekt stammt von **Esmaralda Haze**. Sie ist nicht meine eigene Idee – ich, **BlackRabbitZ**, habe sie technisch umgesetzt und als dieses Repository realisiert.

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](#)
[![Guest](https://img.shields.io/badge/Guest-Debian%2013%20%2B%20XFCE-A81D33?logo=debian&logoColor=white)](https://www.debian.org/releases/trixie/)
[![Hypervisor](https://img.shields.io/badge/Hypervisor-KVM%20%2F%20QEMU-6C5CE7)](https://www.qemu.org/)
[![libvirt](https://img.shields.io/badge/libvirt-isolated%20NAT-2F8F9D)](https://libvirt.org/)
[![Security](https://img.shields.io/badge/security-defense--in--depth-success)](SECURITY.md)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![CI](https://github.com/BlackRabbitZ/kvm-qemu-safebox/actions/workflows/ci.yml/badge.svg)](https://github.com/BlackRabbitZ/kvm-qemu-safebox/actions/workflows/ci.yml)

**KVM-QEMU-SafeBox** baut eine bewusst minimal integrierte Desktop-VM mit **Debian 13 (Trixie) + XFCE**. Die VM hat Internetzugang, soll aber standardmäßig **keinen normalen Zugriff auf Host, LAN, Host-Dateien, USB-/PCI-Geräte, Zwischenablage oder Host/Gast-Dateitransfer** besitzen.

> [!IMPORTANT]
> SafeBox ist Defense in Depth, keine mathematische Sicherheitsgarantie. Unbekannte Schwachstellen in Kernel/KVM, QEMU, libvirt, Firmware oder Hardware können theoretisch eine VM-Isolation überwinden.

## Was ist deaktiviert?

| Host/Gast-Funktion | Status |
|---|:---:|
| Host-Verzeichnisse | ❌ AUS |
| virtiofs / 9p | ❌ AUS |
| USB-Passthrough | ❌ AUS |
| PCI-Passthrough | ❌ AUS |
| USB-Controller im Gast | ❌ AUS |
| Shared Memory / KSM-Merging | ❌ AUS |
| Shared Clipboard | ❌ AUS |
| Drag & Drop | ❌ AUS |
| SPICE File Transfer | ❌ AUS |
| QEMU Guest Agent | ❌ AUS |
| zusätzliche Host-Sockets/Channels | ❌ AUS |
| Host-SSH aus der VM | ❌ BLOCKIERT |
| Bridged Networking | ❌ AUS |
| SPICE OpenGL/3D | ❌ AUS |
| Memory Balloon | ❌ AUS |
| Nested Virtualization (VMX/SVM) | ❌ AUS |
| virtuelle PMU | ❌ AUS |
| VMware vmport | ❌ AUS |

### Trotzdem normal bedienbar

| Funktion | Status |
|---|:---:|
| Virtuelle Tastatur | ✅ AN |
| Virtuelle Maus / Tablet | ✅ AN |
| XFCE Desktop | ✅ AN |
| Browser / Terminal | ✅ AN |
| Copy & Paste **innerhalb** der VM | ✅ AN |
| Internet über isoliertes NAT | ✅ AN |
| Disposable-Sitzungen | ✅ AN |
| Persistente Arbeits-VM | ✅ AN |
| Offline-Sitzungen | ✅ AN |

Maus und Tastatur werden **nicht als echte USB-Geräte durchgereicht**. QEMU stellt dem Gast virtuelle Eingabegeräte bereit.

---

## Architektur

```text
                           INTERNET
                              │
                              ▼
                    ┌──────────────────┐
                    │ Linux Host       │
                    │ libvirt + KVM    │
                    │ QEMU + AppArmor  │
                    └────────┬─────────┘
                             │
                     NAT + nftables
                             │
           ┌─────────────────┴─────────────────┐
           │ virbr-safebox / 10.77.0.0/24     │
           │                                   │
           │ VM → Host      DROP               │
           │ VM → RFC1918   DROP               │
           │ VM → LAN       DROP               │
           │ VM → DHCP/DNS  ALLOW              │
           │ VM → Internet  ALLOW              │
           └─────────────────┬─────────────────┘
                             │
                     virtio-net / NAT
                             │
                    ┌────────▼────────┐
                    │ Debian 13 XFCE  │
                    │ SafeBox Guest   │
                    └─────────────────┘
```

Libvirt-NAT allein ist hier nicht die komplette Sicherheitsgrenze. `network/safebox-guard.nft` ergänzt eine eigene Host-Regelmenge, die von `virbr-safebox` nur DHCP/DNS zum Host erlaubt, DNS auf die fest zugewiesene Gast-IP beschränkt, geroutete Pakete mit unerwarteter IPv4-Quelladresse verwirft und Zugriffe auf private/Spezial-Zielnetze blockiert.

Zusätzlich setzt das libvirt-Netz `port isolated='yes'`, sodass SafeBox-Gäste auf derselben Linux-Bridge voneinander isoliert werden.

---

# Installation

## 1. Voraussetzungen

Empfohlen:

- Linux-Host mit Intel VT-x oder AMD-V
- Debian 12/13 als Host für den derzeit getesteten Installationspfad
- aktiviertes KVM (`/dev/kvm`)
- ca. 60 GB freier Speicher
- 8 GB Host-RAM oder mehr empfohlen
- Debian-13-amd64-Netinst-ISO

Debian 13 „Trixie“ ist die Zielversion des Gasts.

## 2. Repository klonen

```bash
git clone https://github.com/BlackRabbitZ/kvm-qemu-safebox.git
cd kvm-qemu-safebox
```

Die Original-Attribution ist bereits fest auf **BlackRabbitZ** und dieses Repository gesetzt. Für eine normale Installation musst du daran nichts ändern.

> **Hinweis zu Windows/GitHub Desktop:** Windows-Dateisysteme übernehmen das Unix-Executable-Bit beim ersten Commit nicht immer. SafeBox ruft Repository-Skripte deshalb bewusst über `bash` auf. Die CI und die dokumentierten Befehle funktionieren damit auch dann, wenn eine `.sh`-Datei im Git-Index als `100644` statt `100755` gespeichert wurde.

Optional kannst du die Release-/Attributionsprüfung ausführen:

```bash
make release-check
```

## 3. Host-Abhängigkeiten installieren

```bash
sudo bash ./install/install-host.sh
```

Danach einmal ab- und wieder anmelden, falls dein Benutzer neu zu `libvirt`/`kvm` hinzugefügt wurde.

Prüfen:

```bash
bash ./safebox doctor
```

## 4. Debian-ISO herunterladen

Nutze das offizielle Debian-13-Netinst-Image von Debian.org und prüfe idealerweise die veröffentlichten Checksummen/Signaturen.

Beispielpfad:

```text
~/Downloads/debian-13.6.0-amd64-netinst.iso
```

## 5. SafeBox-Netzwerk einrichten

```bash
bash ./safebox setup-network
```

Das erstellt:

```text
Netz:      safebox-net
Bridge:    virbr-safebox
Subnetz:   10.77.0.0/24
Gateway:   10.77.0.1
VM-IP:     10.77.0.100
```

und installiert zusätzlich `safebox-firewall.service`. Dadurch wird `inet/safebox_guard` **vor libvirt** geladen und bleibt auch nach Host-Neustarts aktiv.

Prüfen:

```bash
sudo nft list table inet safebox_guard
virsh -c qemu:///system net-dumpxml safebox-net
```

## 6. Basis-VM erstellen

```bash
bash ./safebox create-base ~/Downloads/debian-13.6.0-amd64-netinst.iso
```

Falls sich das Fenster nicht automatisch öffnet:

```bash
bash ./safebox viewer safebox-installer
```

### Debian-Installation

Im Debian-Installer:

1. **Graphical install** wählen.
2. Sprache/Region/Tastatur auswählen.
3. Einen normalen Benutzer anlegen.
4. Partitionierung innerhalb der virtuellen Disk durchführen.
5. Bei der Softwareauswahl **XFCE** auswählen.
6. Einen SSH-Server **nicht** auswählen.
7. Installation abschließen und in das frisch installierte Debian neu starten; noch nicht endgültig herunterfahren.

> [!TIP]
> Der Installer nutzt virtuelle PS/2-Eingabe, damit Tastatur und Maus bereits im Installer ohne USB funktionieren. Das Runtime-Profil verwendet anschließend virtuelle VirtIO-Eingabe.

## 7. Gast **vor dem Versiegeln** härten

Nach der Debian-Installation in das frisch installierte System booten. Klone dieses Repository **innerhalb der VM über das Internet** und führe im Debian-Gast aus:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/BlackRabbitZ/kvm-qemu-safebox.git
cd kvm-qemu-safebox
sudo bash ./guest/harden.sh
sudo reboot
```

Nach dem Neustart kurz prüfen, dass XFCE, Maus/Tastatur und Internet funktionieren. Danach den Gast vollständig herunterfahren.

## 8. Basis versiegeln

Auf dem **Host**:

```bash
bash ./safebox seal-base
```

Das führt `qemu-img check` aus, entfernt die kopierte Installer-ISO und setzt das Basisimage auf `root:<QEMU-Gruppe>` mit `0440` (schreibgeschützt). Alle späteren persistenten oder temporären Sitzungen verwenden QCOW2-Overlays und schreiben nicht in die Basis.

Die versiegelte Basis gehört **root**, nicht dem QEMU-Prozess. QEMU erhält nur Leserechte über seine Gruppe. Dadurch kann der QEMU-Prozess die Basis nicht einfach per `chmod` wieder beschreibbar machen.


Das Gastskript:

- aktiviert AppArmor
- aktiviert eine eingehend restriktive nftables-Firewall
- aktiviert unattended-upgrades
- setzt konservative Kernel-/Netzwerk-Sysctls
- entfernt `qemu-guest-agent` und `spice-vdagent`, falls vorhanden
- deaktiviert SSH/Avahi/CUPS, falls als Dienste vorhanden
- deaktiviert IPv6 für das IPv4-only-Netzprofil von v0.1

> [!IMPORTANT]
> `bash ./safebox start ...` verweigert den Start, solange das Basisimage nicht auf `0440` versiegelt ist. Damit wird verhindert, dass die vermeintlich unveränderliche Basis versehentlich als Arbeitsdisk benutzt wird.

---

# Benutzung

## Disposable

```bash
bash ./safebox start disposable
```

```text
debian13-xfce-base.qcow2   [read-only]
            │
            └── safebox-disposable-....qcow2
                         │
                         └── nach sauberem VM-Ende gelöscht
```

Änderungen landen nur im temporären Overlay.

## Persistent

```bash
bash ./safebox start persistent
```

Das Overlay:

```text
/var/lib/libvirt/images/safebox/persistent.qcow2
```

bleibt erhalten. Das Basisimage wird trotzdem nicht verändert.

## Offline

```bash
bash ./safebox start offline
```

Hier wird **gar keine virtuelle Netzwerkkarte** in die Domain eingefügt.

## Status

```bash
bash ./safebox status
```

## Sicherheitscheck

Auf dem Host:

```bash
bash ./safebox doctor
make check
```

Innerhalb einer gestarteten Online-SafeBox kann zusätzlich geprüft werden, ob Internet funktioniert, private Ziele blockiert sind und TCP/22 des Host-Gateways nicht erreichbar ist:

```bash
bash ./tests/guest-network-test.sh
```

## Verwaiste Disposable-Overlays bereinigen

Falls ein Startskript hart beendet wurde:

```bash
bash ./safebox cleanup-sessions
```

Noch aktive/definierte Domains werden dabei übersprungen.

---

# Sicherheitsdetails

## SPICE

SPICE bleibt ausschließlich als lokaler Grafikpfad für die Bedienung erhalten. Im Domain-XML sind explizit gesetzt:

```xml
<graphics type='spice' autoport='yes'>
  <listen type='none'/>
  <clipboard copypaste='no'/>
  <filetransfer enable='no'/>
  <gl enable='no'/>
</graphics>
```

Es gibt **keinen** `spicevmc`-Channel und keinen `spice-vdagent` im gehärteten Gast.

## Memory-Merging / KSM

Beide Domain-Profile enthalten:

```xml
<memoryBacking>
  <nosharepages/>
</memoryBacking>
```

Dadurch weist libvirt den Hypervisor an, Shared-Page-Merging/KSM für die SafeBox-Domain zu deaktivieren.

## USB

Der USB-Bus wird explizit deaktiviert:

```xml
<controller type='usb' model='none'/>
```

Dadurch bleibt virtuelle Tastatur-/Mauseingabe möglich, ohne echte USB-Geräte zuzuweisen.

## CPU-/Machine-Minimierung

Die Domain deaktiviert Nested Virtualization (`vmx`/`svm`), die virtuelle PMU und `vmport` explizit. Diese Funktionen werden für einen normalen XFCE-Desktop nicht benötigt und sollen dem Gast daher gar nicht erst angeboten werden.

## QEMU seccomp

Aktuelle libvirt/QEMU-Stacks können QEMU mit seccomp-Sandboxing starten. SafeBox prüft mit `bash ./safebox doctor`, ob die lokale QEMU-Version `-sandbox` unterstützt. SafeBox fügt **keine rohe QEMU-Commandline** in das Domain-XML ein, sondern überlässt die Prozess-Sandbox dem libvirt-Sicherheitsstack des Hosts.

## AppArmor

Auf Debian wird AppArmor installiert/aktiviert. Libvirt kann den QEMU-Prozess über seinen Security Driver zusätzlich einschränken. Der genaue aktive Security Driver hängt vom Host-Build und der Host-Konfiguration ab.

---

# Was SafeBox nicht kann

- keine Garantie gegen unbekannte KVM/QEMU-Escapes
- kein Schutz, wenn der Host bereits kompromittiert ist
- kein Schutz vor Datenabfluss **ins Internet** während einer Online-Sitzung
- keine Anonymisierung deiner Internetverbindung
- kein Ersatz für Updates, Backups und separates Geheimnismanagement

Mehr dazu: [`docs/threat-model.md`](docs/threat-model.md) und [`docs/limitations.md`](docs/limitations.md).

---

# Repository-Struktur

```text
kvm-qemu-safebox/
├── safebox
├── README.md
├── LICENSE
├── NOTICE
├── ATTRIBUTION.md
├── SECURITY.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── Makefile
├── VERSION
├── .github/
│   ├── workflows/ci.yml
│   └── dependabot.yml
├── config/
│   └── defaults.conf
├── docs/
│   ├── architecture.md
│   ├── hardening.md
│   ├── limitations.md
│   ├── networking.md
│   └── threat-model.md
├── guest/
│   ├── harden.sh
│   ├── nftables.conf
│   └── 99-safebox-hardening.conf
├── install/
│   └── install-host.sh
├── tools/
│   └── verify-attribution.sh
├── network/
│   ├── safebox-net.xml
│   ├── safebox-guard.nft
│   ├── safebox-firewall.service
│   ├── install-firewall-service.sh
│   ├── apply-firewall.sh
│   └── remove-firewall.sh
├── tests/
│   ├── doctor.sh
│   ├── guest-network-test.sh
│   ├── network-policy.sh
│   ├── release-check.sh
│   ├── render-smoke.sh
│   └── static-policy.sh
└── vm/templates/
    ├── installer.xml.in
    └── runtime.xml.in
```

---

# Quellen / technische Referenzen

- Debian 13 / Trixie: https://www.debian.org/releases/trixie/
- Debian Installer: https://www.debian.org/releases/trixie/debian-installer/
- libvirt Domain XML: https://libvirt.org/formatdomain.html
- libvirt Network XML: https://libvirt.org/formatnetwork.html
- libvirt Firewalling: https://libvirt.org/firewall.html
- QEMU System Invocation / seccomp: https://www.qemu.org/docs/master/system/qemu-manpage.html

---

# Lizenz und Original-Attribution

Dieses Projekt steht unter der **Apache License 2.0**.

**Originalautor / Copyright:** BlackRabbitZ  
**Original-Repository:** https://github.com/BlackRabbitZ/kvm-qemu-safebox

Zusätzlich enthält das Repository eine [`NOTICE`](NOTICE)-Datei mit der dauerhaften Original-Attribution. Bei der Weitergabe einer veränderten oder abgeleiteten Version müssen die Bedingungen der Apache License 2.0 eingehalten werden. Dazu gehören insbesondere die dort vorgesehenen Lizenz- und Copyright-Hinweise, die Kennzeichnung geänderter Dateien sowie die Übernahme der einschlägigen Attribution-Hinweise aus `NOTICE` in lesbarer Form.

Der Hinweis auf **BlackRabbitZ** und das Original-Repository ist im Projekt fest hinterlegt und soll bei weitergegebenen abgeleiteten Versionen erhalten bleiben.

Prüfen kannst du das jederzeit mit:

```bash
make release-check
```

Siehe auch [`ATTRIBUTION.md`](ATTRIBUTION.md) und [`NOTICE`](NOTICE).
