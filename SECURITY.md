# Security Policy

**Aktueller Prüfstand:** v0.5.1-rc5. Stable wird erst nach einem realen End-to-End-Test auf Debian 13/KVM freigegeben.

## Unterstützte Versionen

| Version | Status |
|---|---|
| `0.5.1-rc5` | 🧪 Pflicht-Security-Gate, echte KVM-Abnahme auf Hardware noch ausstehend |
| `0.5.1-rc4` | 🧪 Security-Release-Candidate / nicht für reale Malware freigegeben |
| `0.5.0` | ⚠️ durch RC1 ersetzt |
| `0.4.x` | ⚠️ nur Migration / keine neuen Härtungsfeatures |
| `< 0.4` | ❌ nicht empfohlen |

Für Tests soll aktuell `0.5.1-rc5` verwendet werden. Ein neuer Stable-Stand wird erst nach dem dokumentierten realen Debian-13/KVM-End-to-End-Test freigegeben.

## Sicherheitsversprechen

KVM/QEMU SafeBox ist eine **Defense-in-Depth-Sandbox**. Das Projekt versucht, die Angriffsfläche eines potenziell vollständig kompromittierten Linux-Gastes zu minimieren und nach einem möglichen Fehler in einer Schicht weitere Schutzgrenzen aufrechtzuerhalten.

SafeBox verspricht **keine absolute VM-Escape-Sicherheit**. Unbekannte Schwachstellen in Linux/KVM, QEMU, libvirt, CPU, Microcode, Firmware oder Hardware können die Schutzannahmen durchbrechen.

## Sicherheitsgrenzen

Der sichere Standard verlangt unter anderem:

- QEMU als non-root
- AppArmor-Confinement
- QEMU-seccomp
- separaten Mount-Namespace
- KSM aus
- Nested Virtualization aus
- kein USB-/PCI-Passthrough
- kein 9p/virtiofs
- kein QEMU Guest Agent
- kein Shared Clipboard / SPICE File Transfer
- kein 3D/OpenGL
- kein Audio, TPM oder vsock
- isoliertes NAT statt Bridge
- IPv6 aus
- Host-/LAN-/lokale-Netze blockiert
- strikte Domain-XML-Allowlist
- root-owned Runtime-Helfer
- kontinuierlichen Fail-Closed-Watchdog
- CPU-/RAM-/I/O-/Storage-Grenzen

Die drei Profile `hardened`, `balanced` und `performance` verändern ausschließlich Ressourcenlimits. Sie dürfen keine Sicherheitsgrenze lockern.

## Fail-Closed-Prinzip

Eine Online-SafeBox soll nicht starten bzw. weiterlaufen, wenn eine erforderliche Schutzgrenze nicht bestätigt werden kann. Dazu gehören insbesondere:

- QEMU/CVE-Gate
- Runtime-XML-Attestation
- nftables-Sollpolicy
- AppArmor
- seccomp
- non-root QEMU
- Mount-Namespace
- Storage-/Overlay-Bindung
- Watchdog-Lebenszyklus

Ein Ausfall des Watchdogs ist über `OnFailure=` an einen separaten root-owned Kill-Service gekoppelt.

## Sicherheitsupdates und CVE-Gate

Das integrierte QEMU-Gate blockiert bekannte, im Projekt modellierte unsichere Versionsbereiche für netzwerkfähige Sessions. Das Gate ersetzt **keine** Paketupdates und ist keine vollständige CVE-Datenbank.

Vor der Nutzung riskanter Inhalte:

```bash
sudo apt update
sudo apt full-upgrade
bash ./safebox security-check
```

Wenn `security-check` mit `Configuration status: NOT READY` endet, sollte keine riskante Online-Session gestartet werden.

## Release- und Supply-Chain-Sicherheit

Stable-Releases unterstützen:

- signierte annotierte Git-Tags
- SHA-256-Manifeste
- SPDX-2.3 Source-SBOM
- optionale detached GPG-Signaturen für Release-Artefakte

Details: [`docs/releases.md`](docs/releases.md).

Ein Signaturergebnis ist nur so vertrauenswürdig wie die unabhängige Verifikation des verwendeten Signierschlüssels.

## Was nicht abgedeckt ist

Nicht garantiert geschützt werden können insbesondere:

- unbekannte Hypervisor-/Kernel-0days
- CPU-/Firmware-/Microcode-Angriffe
- bestimmte Side-Channels
- ein bereits kompromittierter Host
- ein bösartiger Host-Administrator/root
- physischer Host-Zugriff
- externe Router-/NAT-Sonderfälle
- Social Engineering oder freiwillige Übertragung von Daten aus der VM

Für hochriskante Malware-Analyse ist ein **dedizierter physisch getrennter Analysehost** weiterhin die stärkere Grenze.

## Schwachstellen melden

Bitte sicherheitskritische Funde wie VM-Escape, Host-Privilege-Escalation, Firewall-Bypass, Watchdog-Bypass oder Supply-Chain-Probleme möglichst **nicht zuerst mit funktionsfähigem Exploit öffentlich posten**.

Bevorzugter Weg:

1. GitHub → Repository → **Security**
2. **Report a vulnerability / Private vulnerability reporting**, sofern verfügbar
3. Reproduktionsschritte, betroffene Version und erwartetes/ tatsächliches Verhalten angeben

Normale Funktionsfehler ohne Sicherheitsauswirkung können als reguläres Issue gemeldet werden.

## Security-Test-Suite

```bash
make release-check
```

Der Release-Test enthält statische Checks, XML-Manipulationstests, dynamische Watchdog-Fail-Closed-Tests, Profil-Grenztests sowie Release-/SBOM-Prüfungen.

## Original

https://github.com/BlackRabbitZ/kvm-qemu-safebox

## RC2-spezifische Sicherheitskorrekturen

`v0.5.1-rc5` behebt die im RC1-Audit gefundenen regressionskritischen Punkte: geschützte Storage-Pfade werden privilegiert geprüft, `shutdown`/`in shutdown`/`crashed` werden im Watchdog getrennt behandelt, root-seitige Tempdateien liegen nicht mehr unter vorhersehbaren `/tmp`-Namen, der Installer vergibt keine dauerhafte `libvirt`-Gruppenmitgliedschaft, der Runtime-Pfad verwendet root-owned Helper und einen projekt-eigenen nwfilter, und der Gast-Sealer prüft reale DPKG-Paketzustände.

Das SATA/AHCI-Gerätemodell bleibt eine bewusste Rest-Angriffsfläche, weil der Hardened-Default die derzeit problematischen VirtIO-Netz-/Blockpfade vermeidet. Bekannte gastgetriggerte AHCI-DoS-Risiken werden daher als verbleibende Verfügbarkeitsgrenze behandelt, nicht als "CVE-frei" dargestellt.

Ein echter End-to-End-Boot-Test auf einem physischen Debian-13/KVM-Host bleibt vor einer Stable-Freigabe zwingend erforderlich.

## RC4 – Malware-Isolationsstatus

**Unbekannte Malware ist noch nicht freigegeben.** Die Analysesitzung ist NIC-los (`start malware`), flüchtig und nutzt readonly ISO-Import sowie verpflichtenden LUKS2-Unterbau. Diese Maßnahmen ersetzen weder physisch getrennte Analysehardware noch reale KVM/libvirt/AppArmor/SPICE-Tests. Die RC4-Hardware-Abnahme steht unter [docs/validation-rc4.md](docs/validation-rc4.md), die offenen Risiken unter [docs/security-audit-rc4.md](docs/security-audit-rc4.md).
