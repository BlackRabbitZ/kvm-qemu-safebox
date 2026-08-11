# Architektur

## Sicherheitsgrenzen

```text
                       Internet
                          │
                    Host-Uplink
                          │
                  libvirt NAT + nftables
                          │
            ┌─────────────┴─────────────┐
            │      Linux-Host           │
            │                           │
            │  VM→Host: DROP            │
            │  LAN/RFC1918: DROP        │
            │  DHCP/DNS: ALLOW          │
            │                           │
            │    virbr-safebox          │
            └─────────────┬─────────────┘
                          │
                 VirtIO-Netzwerkkarte
                          │
               ┌──────────┴──────────┐
               │ Debian 13 + XFCE    │
               │                     │
               │ kein virtiofs       │
               │ kein 9p             │
               │ kein USB/PCI pass   │
               │ kein guest-agent    │
               │ kein shared clip    │
               └─────────────────────┘
```

Die Sicherheitsstrategie ist **Defense in Depth**. Keine einzelne Schicht wird als unfehlbar betrachtet.

## Schichten

1. **KVM** trennt Gast- und Host-Ausführung über Hardwarevirtualisierung.
2. **QEMU/libvirt** stellen nur eine bewusst kleine Menge virtueller Geräte bereit.
3. **Libvirt-Security-Driver** (auf Debian typischerweise AppArmor) begrenzen den QEMU-Prozess.
4. **QEMU seccomp** kann die erlaubten Systemaufrufe zusätzlich reduzieren, sofern der lokale libvirt/QEMU-Sicherheitsstack die QEMU-Sandbox tatsächlich aktiviert. `doctor` prüft die QEMU-Fähigkeit, nicht allein dadurch deren Live-Aktivierung.
5. **Dediziertes NAT-Netz** verhindert Bridging in das physische LAN.
6. **nftables `safebox_guard`** blockiert Gast→Host und private/Spezial-Zielnetze.
7. **Immutable Base + QCOW2-Overlay** trennt vertrauenswürdige Basis von Arbeitssitzungen.
8. **Gast-Härtung** reduziert Dienste und eingehende Netzwerkfläche im Debian-Gast.

## Eingabegeräte

Maus und Tastatur funktionieren weiterhin. Es werden **virtuelle** Eingabegeräte emuliert; echte Host-USB-Geräte werden nicht durchgereicht. Das Runtime-Profil nutzt `virtio`-Keyboard und `virtio`-Tablet. Der Debian-Installer nutzt PS/2-Eingabe für maximale Installer-Kompatibilität – ebenfalls vollständig virtuell.
