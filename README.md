<p align="right">
  🌐 <strong>Sprache / Language:</strong>&nbsp;
  <a href="README.md"><img alt="Deutsch (aktiv)" src="https://img.shields.io/badge/DE-Deutsch%20%E2%9C%93-2563eb?style=flat-square" /></a>
  <a href="README_EN.md"><img alt="Switch to English" src="https://img.shields.io/badge/EN-English-64748b?style=flat-square" /></a>
</p>

<div align="center">

# 🛡️ KVM/QEMU SafeBox

**Härtungsorientierte, vollständig offline konfigurierte Linux-Sandbox für die manuelle Untersuchung verdächtiger Software.**

*Debian 13 · KVM/QEMU · libvirt · flüchtige VMs · Defense in Depth*

[![Version](https://img.shields.io/badge/Version-v0.5.1--rc5-2563eb?style=flat-square)](CHANGELOG.md)
[![System](https://img.shields.io/badge/Host-Debian%2013-a80030?logo=debian&logoColor=white&style=flat-square)](https://www.debian.org/)
[![Virtualisierung](https://img.shields.io/badge/Virtualisierung-KVM%20%2F%20QEMU-6d28d9?style=flat-square)](https://www.qemu.org/)
[![Isolation](https://img.shields.io/badge/Analyse--Netzwerk-KEINE%20NIC-166534?style=flat-square)](docs/threat-model.md)
[![Freigabe](https://img.shields.io/badge/Malware--Freigabe-AUSSTEHEND-d97706?style=flat-square)](docs/validation-rc5.md)
[![CI](https://github.com/BlackRabbitZ/kvm-qemu-safebox/actions/workflows/ci.yml/badge.svg)](https://github.com/BlackRabbitZ/kvm-qemu-safebox/actions/workflows/ci.yml)
[![Lizenz](https://img.shields.io/badge/Lizenz-Apache--2.0-0f766e?style=flat-square)](LICENSE)

[**Schnellstart**](#-schnellstart) · [**Installation**](#-installation-auf-debian-13) · [**Sicherheitstests**](#-sicherheitstests-und-abnahme) · [**Bedienung**](#-bedienung) · [**Credits**](#-projekt-und-credits)

</div>

> [!CAUTION]
> **Release Candidate – keine Freigabe für unbekannte, aktive Malware.** Die automatisierten Repository-Tests ersetzen keinen Nachweis auf einem echten KVM-Host. RC5 bringt dafür einen Live-Test und ein verpflichtendes Security Gate mit; die Ergebnisse müssen **auf deinem Zielrechner** geprüft werden. Ein bestandener Test garantiert weder Schutz vor unbekannten VM-Escapes noch vor kompromittierter Host-Firmware. Verwende für hochriskante Proben einen **dedizierten und physisch vom Netzwerk getrennten Rechner**.


## 📑 Inhaltsverzeichnis

- [Über das Projekt](#-über-das-projekt)
- [Sicherheitsarchitektur](#-sicherheitsarchitektur)
- [Schnellstart](#-schnellstart)
- [Systemvoraussetzungen](#-systemvoraussetzungen)
- [Installation auf Debian 13](#-installation-auf-debian-13)
- [Debian-Basis-VM einrichten](#-debian-basis-vm-einrichten)
- [Sicherheitstests und Abnahme](#-sicherheitstests-und-abnahme)
- [Bedienung](#-bedienung)
- [Update von einer älteren Version](#-update-von-einer-älteren-version)
- [Fehlerbehebung](#-fehlerbehebung)
- [Sicherheitsgrenzen und bekannte Einschränkungen](#-sicherheitsgrenzen-und-bekannte-einschränkungen)
- [Projektstruktur und Dokumentation](#-projektstruktur-und-dokumentation)
- [Projekt und Credits](#-projekt-und-credits)

---

## 🔎 Über das Projekt

**SafeBox** ist eine Open-Source-Sandbox auf Basis von **KVM/QEMU und libvirt** für die **manuelle Analyse verdächtiger Linux-Dateien**. Der Gast wird grundsätzlich als nicht vertrauenswürdig angesehen – auch dann, wenn darin ein Angreifer Administrator- bzw. `root`-Rechte besitzt.

**Schwerpunkte:** möglichst kleine Geräteschnittstelle zum Host, konsequente Offline-Analyse, überprüfbare VM-Konfiguration, beschränkte Ressourcen, temporäre Laufwerke und eine verpflichtende **Hardware-Abnahme vor dem Start**.

SafeBox ist bewusst **keine** automatisierte Detonations- oder Malware-Analyseplattform: Es gibt keine automatische C2-Simulation, keine Berichte über Malware-Verhalten und keinen unterstützten Windows-Gast. Windows-PE-Dateien können in Debian **statisch** untersucht, aber nicht nativ als Windows-Prozess ausgeführt werden.

### Unterstützte Betriebsarten

| Modus | Zweck | Netzwerk | Persistenz | RC5 |
|:--|:--|:--:|:--:|:--:|
| `start offline` | Unveränderten, harmlosen Testgast starten | ❌ Keine NIC | Flüchtig | ✅ |
| `start malware DATEI` | Probe als schreibgeschütztes ISO einhängen | ❌ Keine NIC | Flüchtig | ✅, nach Abnahme |
| `create-base` | Vertrauenswürdiges Debian-Basisimage installieren | Separates temporäres Installationsnetz | Basisimage | ✅ |
| `start disposable` | Frühere vernetzte Disposable-Runtime | — | — | ⛔ Deaktiviert |
| `start persistent` | Frühere persistente Runtime | — | — | ⛔ Deaktiviert |
| `setup-network` | Früheres Runtime-Netz konfigurieren | — | — | ⛔ Deaktiviert |

## 🏗️ Sicherheitsarchitektur

```text
       DEDIZIERTER DEBIAN-13-HOST (für Hochrisiko physisch offline)
┌───────────────────────────────────────────────────────────────────┐
│  libvirt (qemu:///system) · KVM/QEMU · AppArmor · Seccomp          │
│  Root-owned Runtime-Helfer · XML-/Prozessprüfung · Watchdog        │
│                                                                   │
│        versiegeltes Debian-13-Basisimage (SHA-256)                 │
│                         │                                         │
│                  temporäres QCOW2-Overlay                        │
│                         │                                         │
│            ┌────────────▼─────────────────────┐                   │
│            │ Debian 13 / XFCE Analyse-VM      │                   │
│            │  ✓ schreibgeschütztes Sample-ISO │                   │
│            │  ✓ virtuelle Anzeige/Eingabe     │                   │
│            │  ✗ kein Netzwerkadapter          │                   │
│            │  ✗ keine Host-Dateifreigabe      │                   │
│            │  ✗ kein USB-/PCI-Passthrough     │                   │
│            │  ✗ kein Clipboard / Guest Agent │                   │
│            └──────────────────────────────────┘                   │
│                                                                   │
│     Sitzungsdateien auf geprüftem LUKS2-verschlüsseltem Storage  │
└───────────────────────────────────────────────────────────────────┘
```

| Schutzschicht | Gewollte Eigenschaft | Nachweis / Grenze |
|---|---|---|
| **Netzwerk** | Keine NIC in der Analyse-Domain | Domain-XML **und** Gast prüfen; kein Beweis gegen Hypervisor-Escapes |
| **Hostgeräte** | Kein USB-/PCI-Passthrough, vsock oder Host-Filesystem | XML-Allowlist und Laufzeitprüfung |
| **Gastintegration** | Kein Clipboard, Dateitransfer, Shared Folder oder Guest Agent | Geräte-/Kanal-Konfiguration kontrollieren |
| **QEMU-Prozess** | Nicht als `root`, AppArmor, Seccomp, eigene Cgroup/Namespace | Live-Prüfung auf dem Zielhost erforderlich |
| **Datenträger** | Versiegelte Basis + temporäres Overlay; LUKS2-Unterbau | LUKS2 ist **keine** garantierte Schlüsselvernichtung pro Sitzung |
| **Abschaltung** | Watchdog und Kill-Helfer mit separater Prozessprüfung | Fehlerfälle praktisch testen; unklarer Zustand verhindert Löschen |
| **Startberechtigung** | Security Gate verlangt frischen Live-Test | Gültig höchstens **12 Stunden** und nur für aktuellen Boot/Host-Fingerprint |

Technische Details: [Bedrohungsmodell](docs/threat-model.md) · [Host-Härtung](docs/hardening.md) · [Einschränkungen](docs/limitations.md).

---

## ⚡ Schnellstart

Die Reihenfolge ist absichtlich streng. **Bis einschließlich Schritt 5 ausschließlich mit vertrauenswürdiger Software arbeiten.**

| Schritt | Aufgabe | Verweis |
|:--:|---|---|
| **1** | Debian-13-Host und LUKS2-Speicher vorbereiten | [Voraussetzungen](#-systemvoraussetzungen) |
| **2** | RC5-Quellcode prüfen und Host-Komponenten installieren | [Installation](#-installation-auf-debian-13) |
| **3** | Verifiziertes Debian-ISO installieren, Gast härten, Basis versiegeln | [Basis-VM](#-debian-basis-vm-einrichten) |
| **4** | `make check` und `make release-check` ausführen | [Repository-Tests](#1-repository-tests-ohne-malware) |
| **5** | `hardware-test`, `gate-check` und manuelle Offline-Prüfungen durchführen | [Host-Abnahme](#2-echter-kvm-hardwaretest) |
| **6** | Erst nach dokumentierter Sicherheitsabnahme harmlose Probe testen | [Bedienung](#-bedienung) |

### Wichtigste Kommandos

```bash
make check                           # Code-/Regressionstests (kein KVM-Live-Nachweis)
make release-check                   # zusätzlich Release-/Signatur-Negativtests
sudo bash ./safebox doctor           # vollständiger Konfigurationsstatus
sudo bash ./safebox hardware-test    # harmloser Live-KVM-Test auf dem Zielhost
sudo bash ./safebox gate-check       # gültigen Nachweis nachprüfen
sudo bash ./safebox start offline    # flüchtiger Gast, OHNE Netzwerkkarte
sudo bash ./safebox status           # Laufzeitstatus
```

---

## 💻 Systemvoraussetzungen

| Komponente | Anforderung / Hinweis |
|---|---|
| Host-Betriebssystem | **Debian 13** (Referenz- und Zielsystem von RC5) |
| Virtualisierung | Intel VT-x oder AMD-V, funktionierendes **`/dev/kvm`** |
| Dienste | QEMU, systemweites libvirt, systemd, AppArmor, nftables |
| Werkzeuge | Python 3, `qemu-img`, `virsh`, `virt-viewer`, `genisoimage`, `cryptsetup`, `jq` u. a. (Installer installiert Abhängigkeiten) |
| Arbeitsspeicher | Standardprofil **6 GiB VM-RAM** plus Reserve für Debian-Host; Host-RAM entsprechend größer dimensionieren |
| Datenträger | Ausreichend Platz für **50 GiB Basisdisk** und temporäre Overlays sowie Storage-Reserve |
| Speicherung | `/var/lib/safebox` muss auf einem **nachweisbar LUKS2-verschlüsselten** Volume liegen |
| Umgebung | Für Hochrisiko-Malware: **separater physischer Rechner ohne aktive Netzwerkverbindung** |

Vorprüfung auf dem **Host** (noch keine Malware verwenden):

```bash
cat /etc/os-release
lscpu | grep -E 'Virtualization|Virtualisierung' || true
ls -l /dev/kvm
findmnt -T /var/lib/safebox -o TARGET,SOURCE,FSTYPE
lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS
```

> [!WARNING]
> **Verschlüsselung nicht blind einrichten.** Das Formatieren eines LUKS2-Volumes kann sämtliche vorhandenen Daten zerstören. SafeBox legt selbst **keine** verschlüsselte Partition an. Falls `/var/lib/safebox` noch nicht existiert, zuerst ein geeignetes LUKS2-Dateisystem planen/einrichten und danach erneut prüfen. Auch Swap, Ruhezustand, Dumps, Snapshots und Backups müssen berücksichtigt werden.

## 📥 Installation auf Debian 13

> [!WARNING]
> Der Installer installiert Pakete, ändert die **globale** `/etc/libvirt/qemu.conf`, richtet Firewall- und systemd-Komponenten ein und aktiviert AppArmor. **Nicht ungeprüft auf einem produktiv genutzten Virtualisierungshost ausführen.** Nur aus einem **vertrauenswürdigen, gegen Änderungen geschützten Checkout** mit Root-Rechten starten.

**1. Vollständigen RC5-Projektstand bereitstellen.** Entweder das RC5-Releasepaket entpacken oder – **erst wenn RC5 auf GitHub veröffentlicht ist** – das Repository klonen:

```bash
git clone https://github.com/BlackRabbitZ/kvm-qemu-safebox.git
cd kvm-qemu-safebox
cat VERSION                   # muss 0.5.1-rc5 ausgeben
```

**2. Quellcode, Konfiguration und Änderungen prüfen.** Insbesondere [`install/install-host.sh`](install/install-host.sh), [`host/harden-libvirt.sh`](host/harden-libvirt.sh) und [`network/install-firewall-service.sh`](network/install-firewall-service.sh) vor einem Root-Aufruf lesen. Dieses lokal erstellte RC5-Archiv ist **nicht kryptografisch signiert**; ein bloßer SHA-256-Hash aus derselben unsignierten Quelle beweist keinen vertrauenswürdigen Herausgeber.

**3. Host installieren und anschließend diagnostizieren:**

```bash
sudo bash ./install/install-host.sh
sudo bash ./safebox doctor
```

`doctor` kann während der Ersteinrichtung **`NOT READY`** melden, solange das versiegelte Base-Image und die echte Hardware-Abnahme fehlen. Das ist zunächst erwartbar, **kein Grund, Prüfungen zu umgehen**.

**4. Installation überprüfen:**

```bash
sudo aa-status --enabled
sudo virsh -c qemu:///system capabilities >/dev/null && echo 'libvirt erreichbar'
sudo bash ./safebox security-check
```

Die Prüfschritte gelten für einen dedizierten Host; bestehende andere VMs können von den globalen Härtungseinstellungen betroffen sein.

## 🧱 Debian-Basis-VM einrichten

### 1. Original-ISO überprüfen und Installer starten

Offizielle **Debian-13-Netinst-ISO**, dazu passende `SHA256SUMS` und die Signaturdatei `SHA256SUMS.sign` aus vertrauenswürdigen Debian-Quellen beziehen. Den Signaturschritt nicht überspringen.

```bash
sudo bash ./safebox verify-debian-iso /pfad/debian-13-amd64-netinst.iso /pfad/SHA256SUMS /pfad/SHA256SUMS.sign
sudo bash ./safebox create-base       /pfad/debian-13-amd64-netinst.iso /pfad/SHA256SUMS /pfad/SHA256SUMS.sign
```

Im Debian-Installer **XFCE**, einen minimalen Gast und **keinen SSH-Server** wählen. Das **separate Installationsnetz** dient ausschließlich dem Aufbau einer vertrauenswürdigen Basis, **niemals** der Untersuchung von Malware.

Falls kein Viewer erscheint:

```bash
bash ./safebox viewer safebox-installer
```

Der Viewer verwendet lokale libvirt-Zugriffsrechte; auf einem entsprechend abgeschotteten Host kann eine gesonderte, autorisierte Konsolensitzung erforderlich sein. Normale Benutzer sollten **nicht pauschal** der privilegierten `libvirt`-Gruppe hinzugefügt werden.

### 2. Gast härten

**Im frisch installierten Debian-Gast**, nicht auf dem Host:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/BlackRabbitZ/kvm-qemu-safebox.git
cd kvm-qemu-safebox
cat VERSION                   # Version 0.5.1-rc5 sicherstellen
sudo bash ./guest/harden.sh
sudo poweroff
```

Der Gast kann alternativ mit vorab geprüften RC5-Dateien versorgt werden. `guest/harden.sh` entfernt unnötige Integrationen, setzt Firewall-/Kernel-Vorgaben und konfiguriert den **für die Installation vorhandenen** Netzadapter. Die spätere Analyse-VM startet **ohne** diesen Adapter. [Härtungsdetails](docs/hardening.md).

### 3. Basis versiegeln

**Zurück auf dem Host – nach vollständigem Gast-Shutdown:**

```bash
sudo bash ./safebox seal-base
sudo bash ./safebox doctor
```

Die Versiegelung überprüft die Basis, entfernt die Installer-Umgebung und legt SHA-256-/Versionsmetadaten an. Eine Basis aus **RC4 oder älter** wird für RC5 nicht akzeptiert: neu erstellen und versiegeln, nicht an Metadaten herumändern.

---

## 🧪 Sicherheitstests und Abnahme

> [!IMPORTANT]
> **Drei unterschiedliche Prüfarten:** `make check` testet Code/Regeln, `hardware-test` führt eine **harmlose reale KVM-VM** aus, und die **manuelle Abnahme** kontrolliert zusätzliche Host-/Gast-Eigenschaften. Nur gemeinsam liefern sie einen belastbareren Nachweis – **keine** Garantie gegen unbekannte Schwachstellen.

### 1. Repository-Tests (ohne Malware)

Im RC5-Projektverzeichnis:

```bash
make check
make release-check
```

| Test | Was wird geprüft? | Aussage |
|---|---|---|
| `make check` | Bash-/Python-Syntax, Policy, Profile, XML-Mutationen, Watchdog-/libvirt-Fehlerfälle über Mocks, RC4-Isolationstests, RC5-Gate-Negativtests | **Kein** Nachweis einer real laufenden VM |
| `make release-check` | Vorherige Tests + Versionsdaten, Dokumentationslinks, Release-Artefakte, Prüfsummen und Signatur-/Negativtests | **Kein** Sicherheitsnachweis für unbekannte Malware |
| `python3 tests/rc5-security-gate.py` | Gate lehnt abgelaufene/manipulierte/unpassende Testnachweise ab | Reiner Test der Prüf-Logik |

**Soll:** Kommandos beenden sich mit Exitcode `0`; bei `[FAIL]` Fehler untersuchen. Ein grüner CI-Badge ersetzt keinen Hardwaretest.

### 2. Echter KVM-Hardwaretest

Nur auf dem **dedizierten Debian-13-Zielhost** mit funktionsfähigem `/dev/kvm`, versiegelter RC5-Basis und LUKS2-Speicher. **Vorher alle anderen libvirt-VMs beenden.** Es wird **keine Malware gestartet**.

```bash
sudo bash ./safebox hardware-test
sudo bash ./safebox gate-check
sudo bash ./safebox doctor
```

Der Hardwaretest prüft – soweit vom Code implementiert – unter anderem `/dev/kvm`, installierte root-eigene Prüfkomponenten, AppArmor-/QEMU-Konfiguration, LUKS2, die Integrität der Basis, erlaubte Domain-Geräte, die live gestartete QEMU-Prozessisolation, den aktiven systemd-Watchdog sowie **Kill und Prozessabwesenheit** nach dem Test.

**Erwartete Kernmeldungen bei erfolgreichem Lauf** (weitere Ausgaben sind möglich):

```text
[PASS] RC5 REAL-KVM-TEST: PASS, Security Gate für diesen Boot 12h gültig.
[PASS] RC5 Security Gate: Live-Abnahme gültig; Host unverändert; 12h/Boot-Bindung.
```

- Ein neuer Test **widerruft einen alten PASS zunächst**. Schlägt er fehl, gibt es **keine neue Freigabe**.
- Der Gate-Nachweis liegt root-geschützt unter `/var/lib/safebox/qualification/acceptance.json`.
- Die Gültigkeit endet nach **höchstens zwölf Stunden**, beim **Neustart** oder bei relevanten Änderungen am geprüften Hostzustand.
- **Nicht** die JSON-Datei bearbeiten, Gating-Code deaktivieren oder einen grünen Status von einem anderen Host übertragen.

### 3. Manuelle Isolationsprüfung mit harmloser VM

**Erst nach bestandenem Gate; weiterhin ohne echte Schadsoftware:**

```bash
sudo bash ./safebox start offline hardened
```

In einem **zweiten Host-Terminal** (während der Gast läuft):

```bash
sudo virsh -c qemu:///system list --name
sudo bash ./safebox status
sudo bash ./safebox verify-runtime
sudo virsh -c qemu:///system dumpxml DOMAINNAME > /tmp/safebox-live.xml
```

`DOMAINNAME` durch den tatsächlichen Namen aus `virsh list --name` ersetzen. Die XML-Datei prüfen: Im Analysemodus **keine** `<interface>`-Geräte, keine Host-Filesystemfreigaben, keine Passthrough-Geräte und keine unerwarteten Kommunikationskanäle. Da XML-Angaben allein nicht alles beweisen, **im harmlosen Gast** zusätzlich kontrollieren:

```bash
ip -br link               # normalerweise nur lo; keine Ethernet-/WLAN-NIC
lspci                     # keine unerwarteten Host-/Passthrough-Geräte
lsblk                     # erwartete virtuelle Laufwerke
```

**Außerdem manuell abnehmen:** physische Host-Netztrennung, QEMU-AppArmor-/Seccomp-Zustand, funktionierenden Watchdog, keine fremden laufenden VMs, erfolgte Host-/Firmware-Updates und Logs. Die empfohlene zusätzliche Beobachtung eines harmlosen Gasts dauert **mindestens 30 Minuten**. Ausfalltests an libvirt oder systemd **nur kontrolliert auf dem dedizierten Testhost** ausführen, danach erneut vollständig abnehmen.

**Nach dem regulären Gast-Shutdown**, vom Host:

```bash
sudo virsh -c qemu:///system list --name
sudo python3 ./tools/proc-absence.py --all
sudo bash ./safebox cleanup
sudo bash ./safebox gate-check
```

> [!WARNING]
> `cleanup` **niemals erzwingen**, wenn ein QEMU-Prozess noch läuft oder libvirt seinen Zustand nicht sicher melden kann. Unklare Prozesszustände müssen untersucht werden; die Sicherheitslogik lässt Dateien dann bewusst stehen. Sitzungs-Overlays zu löschen ist **keine kryptografische Löschgarantie**.

### 4. Wann gilt die Prüfung als bestanden?

| Kriterium | Bewertung |
|---|:---:|
| Repository-/Regressionstests ohne Fehler | ☐ |
| `hardware-test` auf **diesem** Host mit `[PASS]` | ☐ |
| `gate-check` für aktuellen Boot und Konfiguration gültig | ☐ |
| Keine NIC/Hostfreigaben/Passthrough-Geräte im laufenden Gast | ☐ |
| AppArmor, Seccomp, Watchdog und QEMU-Prozessrechte live geprüft | ☐ |
| QEMU nach Shutdown nachweislich beendet | ☐ |
| Host physisch vom Netzwerk getrennt (Hochrisiko) | ☐ |
| Updates, Restrisiken und Testprotokoll dokumentiert | ☐ |

**Erst nach allen notwendigen Kontrollen** eine weitere Verwendung beurteilen. `[PASS]` heißt *„die geprüften Bedingungen waren zu diesem Zeitpunkt erfüllt“*, **nicht** *„beliebige Malware kann nicht ausbrechen“*. Weitere Anweisungen: [RC5-Hardware-Abnahme](docs/validation-rc5.md) · [Testübersicht](docs/testing.md).

---

## 🎛️ Bedienung

### Profile anzeigen

```bash
bash ./safebox profiles
```

| Profil | VM-RAM | vCPU | Charakter |
|---|---:|---:|---|
| `hardened` | 6 GiB | 4 | Standard; konservative Ressourcenbegrenzungen |
| `balanced` | 8 GiB | 4 | Mehr RAM/I/O bei gleichen Isolationsregeln |
| `performance` | 12 GiB | 8 | Höherer Ressourcenbedarf, gleiche Geräteverbote |

### Leere Offline-VM starten

```bash
sudo bash ./safebox start offline hardened
```

`start` wartet nach dem Start auf das Ende der Sitzung. Den Gast **regulär herunterfahren** und die erfolgreiche Bereinigung kontrollieren. Bei GUI-Problemen kann `bash ./safebox viewer DOMAINNAME` in einer berechtigten Desktop-Sitzung helfen.

### Verdächtige Datei manuell untersuchen

**Nur nach dokumentierter Abnahme und vorzugsweise ausschließlich in einem isolierten Labor.** Für den ersten Durchlauf eine **harmlose Testdatei** verwenden.

```bash
sudo bash ./safebox start malware /absoluter/pfad/zu/testdatei.bin hardened
```

- Die Quelldatei muss eine **reguläre Datei** (kein Symlink) mit maximal **256 MiB** sein.
- SafeBox erstellt eine schreibgeschützte ISO und stellt den Inhalt im Gast als **`sample.bin`** bereit.
- Der Analyse-Gast besitzt **keine NIC**, keinen Shared Folder und keinen freigegebenen Host-Clipboard.
- Die Probe wird **nicht auf dem Host ausgeführt**; dennoch muss die Host-seitige Dateiverarbeitung als Angriffsfläche betrachtet werden.

**Im Gast:**

```bash
sudo mkdir -p /mnt/probe
sudo mount -o ro /dev/sr0 /mnt/probe
ls -lah /mnt/probe
sha256sum /mnt/probe/sample.bin
```

Nach dem regulären Gast-Shutdown entfernt SafeBox die temporären Sitzungskomponenten **erst nach bestätigter QEMU-Abwesenheit**. Dateien können bei Fehlern zurückbleiben. **Das entfernt keine Daten mit garantierter forensischer Unwiederbringlichkeit.** Keine manuellen Hostfreigaben, Netzwerkkarten oder USB-Geräte hinzufügen, um die Untersuchung zu vereinfachen.

### Diagnose- und Wartungsbefehle

| Befehl | Zweck |
|---|---|
| `sudo bash ./safebox doctor` | Host- und Security-Gate-Status (READY/NOT READY) |
| `sudo bash ./safebox gate-check` | Vorhandene Hardware-Abnahme prüfen |
| `sudo bash ./safebox hardware-test` | Neue Live-KVM-Abnahme mit harmloser Test-VM |
| `sudo bash ./safebox status` | Laufende SafeBox-Domain und Laufzeitstatus |
| `sudo bash ./safebox verify-runtime` | Live-Domain, QEMU-Prozess und Storage prüfen |
| `sudo bash ./safebox cleanup` | Sichere Bereinigung nach bestätigtem VM-Ende |
| `bash ./safebox profiles` | Verfügbare Ressourcenprofile |
| `make check` | Lokale Tests der Repository-Logik |
| `make release-check` | Zusätzliche Release- und Artefakttests |

## 🔁 Update von einer älteren Version

**RC5 ändert das Sicherheitsmodell absichtlich:** alte vernetzte und persistente Analysemodi entfallen. Für ein Upgrade von RC4 oder älteren Versionen:

1. Vorherige SafeBox-Domains **regulär beenden** und die tatsächliche QEMU-Prozessabwesenheit feststellen.
2. Alte Daten sichern, aber **alte Overlay-Sitzungen nicht** als RC5-Laufzeitdaten übernehmen.
3. Vollständigen **RC5-Projektstand** prüfen; aktualisierte Helfer mittels `sudo bash ./install/install-host.sh` installieren.
4. LUKS2-Unterbau erneut kontrollieren; das **Debian-Basisimage unter RC5 neu installieren/härten/versiegeln**.
5. `make check`, `make release-check`, `hardware-test` und manuelle Sicherheitsabnahme erneut durchführen.

**Nicht** lediglich `VERSION`, die JSON-Metadaten oder Prüfsummen umschreiben, um die Versionsbindung zu umgehen.

## 🧰 Fehlerbehebung

| Symptom | Mögliche Ursache | Nächster Schritt |
|---|---|---|
| `Configuration status: NOT READY` | Fehlende Hostvoraussetzungen, Base-Image, LUKS2 oder Gate-Nachweis | `[FAIL]`-Zeilen in `sudo bash ./safebox doctor` prüfen |
| `Keine gültige KVM-Hardware-Abnahme` | Noch kein erfolgreicher Live-Test, neuer Boot oder 12h überschritten | `sudo bash ./safebox hardware-test`, danach `gate-check` |
| `Kein echtes /dev/kvm` | CPU-Virtualisierung aus oder KVM nicht verfügbar | BIOS/UEFI und Host-KVM prüfen; nicht per Mock umgehen |
| `Runtime-Helfer fehlen/abweichend` | Neuer Quellcode, aber alte installierte Root-Helfer | Quellcode verifizieren; `sudo bash ./install/install-host.sh` erneut ausführen |
| `Storage nicht auf LUKS2` | Speicherpfad liegt nicht auf nachgewiesenem verschlüsseltem Volume | Storage-Konfiguration prüfen; **nicht** unbedacht formatieren |
| `Basis wurde mit ... versiegelt` | RC4/RC3-Basis mit falscher Versionsbindung | RC5-Gastbasis neu erstellen und versiegeln |
| VM startet, Viewer öffnet sich nicht | Fehlende GUI-/libvirt-Berechtigung | Desktop-/Viewer-Setup und lokale Zugriffskontrolle prüfen |
| Cleanup verweigert Löschung | libvirt nicht erreichbar oder QEMU-Zustand unsicher | Prozesse und Journald untersuchen; **keine** erzwungene Löschung |
| `hardware-test` schlägt fehl | Reale Policy-/Geräte-/Prozessabweichung | Fehlerprotokoll sichern, Ursache beseitigen, vollständigen Test wiederholen |

Diagnose nur mit harmlosen Testdaten. **Schutzmechanismen nicht temporär deaktivieren**, um einen Fehler „zu beheben“.

## ⚠️ Sicherheitsgrenzen und bekannte Einschränkungen

- **Unbekannte VM-Escapes** in QEMU/KVM, dem Linux-Kernel oder Firmware/CPU sind durch RC5 nicht ausgeschlossen.
- Der Host muss vertrauenswürdig bleiben; ein kompromittierter Root-Account kann die Isolationsmechanismen manipulieren.
- **Keine automatische Host-Netztrennung:** Das Fehlen einer VM-NIC ersetzt für Hochrisiko-Malware keinen physisch getrennten Analyse-PC.
- **Keine Windows-Ausführungsumgebung** und keine automatische Malware-Verhaltensanalyse.
- **LUKS2 schützt ruhende Daten**, liefert aber keine Sitzungsschlüssel-Vernichtung; Swap, Dumps, Snapshots und Backups bleiben gesonderte Risiken.
- **Kein garantierter Datenvernichtungsnachweis** beim Löschen eines temporären QCOW2-Overlays.
- Zeit- und Konfigurationstests können nicht sämtliche Race Conditions, Side Channels, Hardwarefehler oder Denial-of-Service-Szenarien abdecken.
- Eine erfolgreich bestandene RC5-Hardware-Abnahme ist **keine pauschale Freigabe für beliebige unbekannte Malware**; sie dokumentiert nur konkret geprüfte Eigenschaften dieses Hosts.

Für Sicherheitsmeldungen bitte die [Security Policy](SECURITY.md) verwenden. Fehlende Tests und Einschränkungen sind zusätzlich in [RC5-Audit](docs/security-audit-rc5.md) und [RC5-Validierungsplan](docs/validation-rc5.md) dokumentiert.

## 📁 Projektstruktur und Dokumentation

```text
kvm-qemu-safebox/
├── safebox                    # Zentrale CLI
├── config/                    # Version und Sicherheitsvorgaben
├── install/                   # Host-Installation und Runtime-Helfer
├── host/                      # libvirt-/QEMU-Härtung
├── guest/                     # Debian-Gast-Härtung
├── vm/templates/              # libvirt-Domain-XML-Templates
├── tools/                     # Attestation, Security Gate, Hardwaretest
├── network/                   # Installer-Netzwerk und Firewall-Helfer
├── profiles/                  # Ressourcenprofile
├── tests/                     # Regressionen, Mutationen, Signaturtests
├── docs/                      # Bedrohungsmodell, Abnahme und Grenzen
├── .github/workflows/         # GitHub Actions
├── SECURITY.md                # Sicherheitsmeldungen
├── ATTRIBUTION.md             # Herkunft der Projektidee
└── NOTICE                     # Copyright- und Attribution-Hinweise
```

**Weiterlesen:** [Architektur](docs/architecture.md) · [Host-Härtung](docs/hardening.md) · [Threat Model](docs/threat-model.md) · [Testkonzept](docs/testing.md) · [RC5-Abnahme](docs/validation-rc5.md) · [Changelog](CHANGELOG.md) · [Beitragen](CONTRIBUTING.md) · [Release-Verfahren](docs/releases.md).

## ❤️ Projekt und Credits

> **💡 Projektidee: Esmaralda Haze**  
> Vielen Dank an **Esmaralda Haze** für die ursprüngliche Idee zu KVM/QEMU SafeBox.
>
> **🛠️ Technische Umsetzung, Entwicklung und Erweiterungen: [BlackRabbitZ](https://github.com/BlackRabbitZ)**  
> Projekt-Repository: **https://github.com/BlackRabbitZ/kvm-qemu-safebox**

Das Projekt wird unter der **Apache License 2.0** veröffentlicht. Weitere Hinweise und die festgehaltene Zuordnung der Beiträge stehen in [LICENSE](LICENSE), [NOTICE](NOTICE) und [ATTRIBUTION.md](ATTRIBUTION.md).

<div align="center">

**Sicherheit zuerst: testen → auf echter Hardware abnehmen → Restrisiken beurteilen → erst dann verwenden.**

</div>
