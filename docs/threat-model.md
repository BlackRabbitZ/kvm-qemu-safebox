# Threat Model

## Ziel

Eine Desktop-VM für Browser, Downloads, Entwicklungswerkzeuge und andere potenziell riskante Workloads, bei der ein kompromittierter Gast möglichst wenig Möglichkeiten hat, den Host oder das lokale Netzwerk zu erreichen.

## Angreifer-Modell

Wir gehen davon aus, dass innerhalb der VM beliebiger Code mit Benutzer- oder Root-Rechten ausgeführt werden kann.

## Geschützt werden sollen

- Host-Dateisystem und Host-Dienste
- lokale LAN-Geräte wie Router, NAS, Drucker und andere Rechner
- Host-Zwischenablage und Host-Dateien
- physische USB-/PCI-Geräte
- persistente Arbeitsdaten bei Disposable-Sitzungen

## Bewusst nicht versprochen

SafeBox garantiert **keine Unausbrechbarkeit**. Unbekannte Schwachstellen in Linux/KVM, QEMU, libvirt, Firmware, CPU/Mikrocode oder Gerätmodellen können theoretisch Isolation überwinden. Ebenfalls nicht abgedeckt sind physische Angriffe, kompromittierte Host-Administratoren oder ein bereits kompromittierter Host.

## Annahmen

- Der Host ist aktuell gepatcht.
- KVM/QEMU/libvirt stammen aus vertrauenswürdigen Distribution-Repositories.
- Keine fremden QCOW2-Basisimages werden blind übernommen.
- Benutzer aktiviert keine zusätzlichen Host-Geräte/Freigaben außerhalb dieses Projekts.
