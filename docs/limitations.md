# Bekannte Grenzen – RC4

SafeBox v0.5.1-rc5 liefert eine strukturell offline gehaltene Linux-VM und Prüfskripte. Das ist **keine Garantie für Malware-Eindämmung**.

**Schwerwiegende Rest-Risiken:**

- KVM, QEMU, libvirt, der Host-Kernel und emulierte SATA-/Grafik-/Input-Geräte können unbekannte Sicherheitslücken aufweisen. Es gibt keine vollständig perfekte VM-Escape-Barriere.
- Ein bereits kompromittierter Host-Administrator oder Firmware/CPU wird nicht geschützt.
- Wenn der Host physisch ans Netz angeschlossen ist, bleibt sein Netzwerkstack aktiv. Eine fehlende Gast-NIC begrenzt normale Exfiltration, schützt aber nicht gegen eine erfolgreiche Gast-zu-Host-Eskalation.
- AppArmor, Seccomp, non-root QEMU, Mount-Namespace, SPICE und die libvirt-Domain müssen auf dem realen Zielhost getestet werden; lokale statische Tests sind kein E2E-Nachweis.
- CPU-Side-Channels, RAM, verschlüsselter/unverschlüsselter Swap, Hibernation, Host-Core-Dumps und Backups erfordern ein separates Schutzkonzept.
- LUKS2 vor Runtime ist verpflichtend, aber das Dateilöschen entfernt **keinen Sitzungsschlüssel**; kryptografische Löschung pro VM ist nicht implementiert.
- Der Watchdog kann unklare QEMU-Zustände melden und die Beendigung anfordern, aber keine Abschaltung eines beschädigten Hosts garantieren.
- Die ISO-Erstellung ruft das Host-Programm `genisoimage` auf; das Kopieren der Probe und die ISO-Generator-Mocks wurden lokal getestet, keine reale Integration durchgeführt.
- Die Guest-Basis ist Debian 13 XFCE, keine validierte Windows-VM. Windows-EXEs können nur statisch untersucht werden, nicht nativ gestartet.
- Netzlose Malware kann andere Verhaltensweisen zeigen als online laufende Schadsoftware.
- Versionsabhängige CVEs müssen gegen Debian Security Tracker, Kernel-Patches, AppArmor und Hardware aktualisiert bewertet werden; die Projektchecks decken nicht alle möglichen CVEs ab.
- Base-Erstellung nutzt weiterhin den vernetzten Installer. **Dort keine unbekannte Malware ausführen.**

**Empfehlung:** Dedizierte Analysehardware, physisch ohne Verbindung zu einem produktiven Netzwerk, regelmäßig gepatchte Host-Systeme und unabhängige KVM-E2E-Abnahme nach [validation-rc4.md](validation-rc4.md).
