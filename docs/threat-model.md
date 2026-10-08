# Bedrohungsmodell RC4 – manuelle Offline-Malware-Analyse

## Vertrauenswürdig (Annahme, nicht kryptografisch bewiesen)

- Dedizierte Host-Hardware, vertrauenswürdige Firmware, Bootkette und Kernel/KVM
- Administrator und root-owned, geprüfte Installations- und Laufzeithelfer
- AppArmor, Seccomp, libvirt, QEMU und die im Offline-Betrieb verwendete Storage-Schicht
- AES-/LUKS2-Schlüsselmanagement des Hosts und der darunterliegende Blockgerätepfad

## Als kompromittiert betrachtet

- Gesamter Debian-Gast einschließlich root sowie aller darin ausgeführten Dateien und Analysewerkzeuge
- Die Dateiinhalte der importierten Malware-Probe und sämtliche Gast-Datenträgerdaten
- Gästeingaben an emulierte Geräte (SATA, Tastatur, Maus, Video, virtuelle CD-ROM)

## Ziele

1. **Null Netzwerkschnittstellen in allen Malware-/Offline-Runtime-VMs.** Keine reinen nftables-/DNS-Ausweichtricks als primäre Sicherheitsgrenze.
2. Kein Host-Filesystem-Sharing, PCI-/USB-Passthrough, vsock, qemu-guest-agent, SPICE-Clipboard oder Filetransfer.
3. Schutz durch nicht-root QEMU, AppArmor, Seccomp, Namespace, CPU-/RAM-/I/O-Budgets.
4. Ein readonly Sample-ISO an den tatsächlich beabsichtigten Pfad und SHA-256 binden.
5. Alle Sessions flüchtig; niemals bei unklarem QEMU-/libvirt-Prozesszustand löschen oder Erfolg melden.
6. LUKS2 als zwingenden Host-Storage-Unterbau vor Malware-Runtime bestätigen.

## Außerhalb des Sicherheitsversprechens

- VM-Escapes durch unbekannte QEMU-/KVM-/Kernel-/CPU-/Firmware-Schwachstellen
- Bösartiger/kompromittierter Host-root, manipulierter Installer oder Lieferkettenangriff
- Seitenkanäle, Host-Swap, Speicherabbilder, SSD-Remanenz, Backups
- Kryptografische Schlüsselvernichtung **pro Session** (nicht implementiert)
- Online-Malware-Kommunikation, Netzverhalten, vollständige automatische Malware-Analyse
- Native Ausführung von Windows-EXEs in Debian

Für den offenen Live-Testplan siehe [validation-rc4.md](validation-rc4.md).
