# RC5 – Hardware-Abnahme, Grenzen und Prüfschritte

**WICHTIG:** `make check` beweist **keine** Hardware-Isolation. Alle Echt-KVM-Tests
müssen auf dem Zielhost unter Debian 13 mit KVM, QEMU/libvirt, AppArmor,
systemd, /dev/kvm und LUKS2 durchgeführt werden. Das Release wurde hier
**nicht** auf echter KVM-Hardware ausgeführt; die Freigabe ist somit ausstehend.

## Ablauf

1. Physisch getrennten, dedizierten Linux-Rechner verwenden: Ethernet trennen,
   Wi-Fi und Bluetooth deaktivieren (vorzugsweise Firmware/Hardware-Schalter).
   Andere libvirt-Gastsysteme ausschalten, Updates/Firmware/Microcode prüfen.
2. Projektquellen vor `sudo` unabhängig prüfen. `sudo bash ./install/install-host.sh`
   installiert aktualisierte, root-owned Helfer. Den Host vor Ort kontrollieren.
3. LUKS2 für `/var/lib/safebox` prüfen und ein frisches **RC5-Basisimage** versiegeln.
   Eine bestehende RC4-Basis erfüllt die RC5-Versionierung nicht.
4. `sudo bash ./safebox hardware-test` startet **ausschließlich ein harmloses**
   Test-Gastsystem als kurzlebige Live-KVM-VM, ohne NIC und ohne Sample.
   Geprüft werden: `/dev/kvm`, AppArmor, qemu.conf, QEMU-Gate, LUKS2,
   die Basisintegrität, Policy-XML und libvirt-Schema, live erzwungene
   Geräte-/Netzwerk- und Prozesseinschränkungen, systemd-Watchdog,
   tatsächliche Abschaltung über `kill-domain.sh` und unabhängige QEMU-Abwesenheit.
5. Bei Erfolg werden Prüfpunkte in einem root-only JSON gespeichert:
   `/var/lib/safebox/qualification/acceptance.json`. Der Nachweis gilt 12h,
   nur für **diesen Bootvorgang** und diese geprüften Hostdateien.
6. `sudo bash ./safebox gate-check` prüft den Nachweis nochmals.
   `sudo bash ./safebox start offline` und `... start malware DATEI` verweigern
   ohne gültigen Nachweis den Start.
7. **Unabhängig zusätzlich manuell prüfen:** `virsh dumpxml`, `ip link`/`lspci`
   im Gastsystem, Betrieb an physisch getrenntem Netzwerk, ausführliche
   Host-Paketmitschnitte mit einer **harmlosen** Gast-Testdatei, QEMU-Sockets,
   ungeplante Ausfälle einschließlich libvirt und Watchdog. Nach jedem Test:
   `virsh list --all`, `proc-absence.py --all`, Journallogs und tatsächliches
   Aufräumen prüfen. 30 Minuten Beobachtung eines benignen Gasts empfohlen.

## Was dieser Test nicht beweist

- Keine Gewähr gegen neue/0-day VM-Escapes oder CPU-Seitenkanäle, DMA oder
  Firmware-Angriffe.
- Keine automatisierte physische Trennung von WLAN/Ethernet; diese muss vom
  Betreiber geprüft werden.
- Die Watchdog-Laufzeit und gezielte Kill-Ausführung werden am echten Gast
  geprüft; alle denkbaren Ausfall-/Race-Szenarien sind **nicht** abgedeckt.
- Es erfolgt **kein** Test mit echter unbekannter Malware und keine Prüfung
  eines Windows-Gasts; Debian-Gast ist die geprüfte Referenz.
- Verschlüsselung *at rest* ist kein per-Session-Crypto-Erase.

**Entscheidung:** Ein PASS bedeutet "geprüfte Bedingungen auf diesem Host
aktuell erfüllt", **nicht** "sicher gegen beliebige Malware". Hohe Risiken nur
in einem dedizierten und unabhängig abgenommenen Labor untersuchen.
