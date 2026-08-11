# Hardening-Entscheidungen

## Deaktiviert

| Funktion | Status | Grund |
|---|---:|---|
| Host-Verzeichnisse | AUS | Kein direkter Dateisystemkanal |
| virtiofs / 9p | AUS | Keine Host-Dateifreigaben |
| USB-Passthrough | AUS | Keine echten USB-Geräte im Gast |
| PCI-Passthrough | AUS | Keine direkte Gerätezuweisung |
| Shared Memory / KSM-Merging | AUS | `nosharepages` verhindert Shared-Page-Merging |
| Shared Clipboard | AUS | Datenfluss Host↔Gast reduzieren |
| Drag & Drop | AUS | Keine Dateiübertragung über GUI |
| SPICE File Transfer | AUS | Keine SPICE-Dateiübertragung |
| QEMU Guest Agent | AUS | Kein Managementkanal in den Gast |
| Host-Sockets/Channels | AUS | Keine zusätzlichen Character-Devices |
| Host SSH | AUS | Host-Firewall blockiert Gast→Host |
| Bridged Networking | AUS | Kein Layer-2-Zugang zum LAN |
| USB-Controller | AUS | Gerätklasse komplett entfernen |
| Memory Balloon | AUS | Nicht benötigtes virtuelles Gerät entfernen |
| SPICE OpenGL | AUS | Kein 3D/DRM-Render-Node-Zugriff nötig |

## Aktiv

- virtuelle Tastatur und Maus/Tablet
- virtio-gpu ohne 3D
- virtio-block
- virtio-net nur in Online-Modi
- lokales SPICE-Display über libvirt ohne freies Listen-Interface
- isoliertes NAT mit Host-/LAN-Guard

## Dateirechte der Images

Während der Debian-Installation muss QEMU die Basisdisk beschreiben können. Beim `seal-base` wechselt das Projekt anschließend auf `root:<QEMU-Gruppe>` und Mode `0440`. Beschreibbare Persistent-/Disposable-Overlays gehören dagegen dem QEMU-Dienstbenutzer und haben `0600`. Die Storage-Verzeichnisse selbst bleiben root-owned mit `0750`.

## CPU-/Machine-Oberfläche

- Nested Virtualization (`vmx`/`svm`) ist explizit deaktiviert.
- Die virtuelle PMU ist deaktiviert.
- `vmport` ist deaktiviert.

Diese Funktionen werden für den XFCE-Arbeitsgast nicht benötigt und werden deshalb nicht angeboten.
