# Changelog

Alle nennenswerten Änderungen an KVM-QEMU-SafeBox werden hier dokumentiert.

## [0.1.0] - 2026-08-11

### Hinzugefügt

- Debian-13-XFCE-Basisworkflow über KVM/QEMU/libvirt
- Disposable-, Persistent- und Offline-Modus über QCOW2-Overlays
- dediziertes libvirt-NAT `safebox-net`
- persistenter nftables-Host-/LAN-Guard
- feste DHCP-Zuordnung und Quell-IP-Prüfung
- libvirt-Port-Isolation
- deaktivierte Host-Dateifreigaben, USB-/PCI-Passthrough, Clipboard, SPICE-Dateitransfer und Guest Agent
- explizit deaktivierter USB-Controller, KSM/Memory-Merging, Memory Balloon und SPICE-OpenGL
- deaktivierte Nested Virtualization, virtuelle PMU und `vmport`
- root-eigenes schreibgeschütztes Basisimage (`0440`)
- Gast-Härtung mit AppArmor, nftables, unattended-upgrades und Sysctls
- `doctor`, statische Sicherheitsprüfungen, Netzwerk-Policy-Test und Render-Smoke-Test
- GitHub Actions CI mit minimalen Rechten und fest gepinnter Checkout-Action
- Apache-2.0-Lizenz mit `NOTICE` für Original-Attribution
