# RC4 – Verbindliche Validierung auf echter Hardware (noch nicht bestanden)

**Status:** Die hier aufgeführten Prüfungen können in der Chat-Umgebung ohne KVM/libvirt/verschlüsselte Blockgeräte nicht durchgeführt werden. Für die manuelle Ausführung echter unbekannter Malware ist vorab ein kontrollierter, dedizierter Testhost erforderlich.

## A. Vertrauensanker und physische Trennung

- Dedizierte Maschine, BIOS/UEFI, TPM-/Secure-Boot-Status, Firmware/CPU-Microcode dokumentieren.
- Vor Malware: Ethernet physisch abstecken, Wi-Fi/Bluetooth deaktivieren (BIOS/RFKill) und mit externer Beobachtung nachweisen, dass keine Verbindung besteht.
- Host-Updates und Base-Installation nur im sauberen Bootstrap, keine unbekannten Proben dort ausführen.
- Root-owned Quellverzeichnis und installierte Helfer auf Write-Bits, Signaturen und Hashes prüfen.

## B. Storage und Gast

- LUKS2-Volume nach tatsächlichem `findmnt`-, `lsblk`- und `cryptsetup status` nachweisen; Host-Swap, Core-Dumps, Backups und Crash-Reports berücksichtigen.
- Ein Test-Overlay anlegen und nach QEMU-Ende verwerfen. Keine Datenvernichtung behaupten; bei Bedarf Schlüssellöschung am *eigenen* Volume separat erproben.
- Base-Image auf Hashbindung und Schreibschutz prüfen. Im Gast effektive Dienste, nftables, AppArmor, `ss -lntup` kontrollieren.
- Windows PE nicht als native Debian-Analyse bewerten.

## C. XML und Geräte/Exfiltration

1. `sudo virsh -c qemu:///system dumpxml DOMAIN` sichern; `interface` muss **0** sein (nicht nur Link=down). Ebenso 0: hostdev, filesystem, channel, redirdev, vsock, parallel/serial, virtiofs/9p, TPM, USB-Geräte.
2. `graphics` ohne Netzwerk-Listener, Clipboard/Filetransfer aus. Tatsächliche TCP/UDP-Listener und QMP-Sockets gegen `ss -lntup` prüfen.
3. Sample-ISO muss genau 1× vorhanden sein; `readonly` und Pfadbindung in XML, QEMU-Prozess, File-Besitz, Rechten, Hash; ohne Sample genau 0×.
4. Im Gast auf PCI- und Netzwerkgerätelisten prüfen: `ip link`, `ip a`, `lspci -nn`, `lsusb`, `ethtool`. Eine virtio-NIC, emulierte NIC oder Passthrough-Karte ist ein **No-Go**.
5. Versuch einer ausgehenden Verbindung zu kontrollierter externer Sensoradresse bei physisch getrennter Testumgebung; Paketmitschnitt am Host/extern muss null Gast-IP-Pakete nachweisen. Bridge-/VPN-Änderungen dürfen keine Verbindung erzeugen.

## D. Störungs- und Kill-Tests (nur mit harmlosem Testprogramm)

- `libvirt`-Dienst anhalten, Socket invalidieren, API-Aufrufe zeitweilig blockieren. Watchdog muss Fehler protokollieren und Kill veranlassen.
- Testen, ob bei unerreichbarem libvirt ein überlebender QEMU anhand `/proc`, Starttime, UUID nicht fälschlicherweise gelöscht wird.
- `systemd`-Watchdog beenden und sein `OnFailure`-Verhalten mit tatsächlichem QEMU-Prozess prüfen.
- XML nach Start bewusst manipulieren (nur mit harmloser VM) – Attestation muss verweigern.
- Speicherreserve über kontrollierte Test-Overlays knapp werden lassen – Stop/Timeout und fehlende Datenlöschung bei Ungewissheit prüfen.
- Während laufender VM Sample-Hash/Rechte verändern: Watchdog muss stoppen, ohne Daten vorher zu löschen.
- Externe Messungen und vollständige Logs bereitstellen; `make check` allein gilt **nicht** als Nachweis.

## E. Freigabe

Freigabe nur nach dokumentierten PASS für A–D auf dem **tatsächlichen** Host, Updates nach Debian Security Tracker, unabhängigem Review und Wiederholung bei Änderungen an Kernel, QEMU/libvirt, CPU, BIOS/UEFI oder Konfiguration.

> Selbst nach bestandenem Validierungsplan bleibt das Risiko unbekannter VM-Escapes bestehen. Für besonders riskante Proben den gesamten Host physisch isolieren.
