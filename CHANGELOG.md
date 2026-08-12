# Changelog

Alle nennenswerten Änderungen an KVM-QEMU-SafeBox werden hier dokumentiert.

## [0.2.0] - 2026-08-12

### Sicherheits-Härtung

- Hostseitiger vollständiger IPv6-DROP für `virbr-safebox` in beide Richtungen
- getrenntes Installations- und Runtime-Netz (`safebox-install-net` / `safebox-net`)
- Runtime-Netz ohne libvirt-DHCP und ohne libvirt-DNS; unerwarteter Runtime-`dnsmasq` führt zum Abbruch
- statische Runtime-IPv4 im Gast plus hostseitiges `IP=10.77.0.100` im `clean-traffic`-Filter
- symmetrischer Host-/Forward-Guard: keine neuen Host→Gast- oder eingehend weitergeleiteten Verbindungen
- libvirt `clean-traffic` Anti-Spoofing mit DHCP-Snooping
- verpflichtendes AppArmor über `security_require_confined = 1`
- verpflichtendes QEMU-seccomp über `seccomp_sandbox = 1`
- QEMU-Core-Dumps über `max_core = 0` / `dump_guest_core = 0` deaktiviert
- explizite dynamische AppArmor-Seclabels in den Domain-Templates
- Runtime-Attestation des Live-Domain-XMLs und QEMU-Prozesses
- Fail-closed VM-Abbruch bei fehlendem AppArmor/seccomp/non-root/Namespace/Cgroup-Nachweis
- Live-Verifikation des bestehenden libvirt-Netzes vor jedem Online-Start
- SafeBox-Netzwerk-Autostart deaktiviert; Firewall wird zuerst geladen
- atomarer nftables-Replacement-Pfad nach vorherigem Syntaxcheck
- SHA-256-Integritätsprüfung des versiegelten Basisimages vor jedem Start
- QCOW2-Backing-Chain-Prüfung für Session-/Persistent-Overlays
- kein Root-Fallback bei unbekanntem QEMU-Dienstbenutzer
- normale Benutzer werden nicht mehr automatisch zu `libvirt`/`kvm` hinzugefügt
- Gast-Discard zur Host-Storage-Schicht deaktiviert
- zusätzliche konservative Gast-Sysctls und stärkerer Dienstabbau

### Qualität

- CI führt jetzt den vollständigen `make release-check` aus
- libvirt-Schema-Validierung gerenderter Domain-, Network- und nwfilter-XMLs
- erweiterte statische und Netzwerk-Policy-Tests
- neue Dokumentation zur Runtime-Attestation

## [0.1.0] - 2026-08-11

### Hinzugefügt

- Debian-13-XFCE-Basisworkflow über KVM/QEMU/libvirt
- Disposable-, Persistent- und Offline-Modus über QCOW2-Overlays
- dediziertes libvirt-NAT `safebox-net`
- persistenter nftables-Host-/LAN-Guard
- feste DHCP-Zuordnung und Quell-IP-Prüfung
- libvirt-Port-Isolation
- minimierte Host/Gast-Integration
- root-eigenes schreibgeschütztes Basisimage (`0440`)
- Gast-Härtung mit AppArmor, nftables, unattended-upgrades und Sysctls
- CI und statische Sicherheitsprüfungen
- Apache-2.0-Lizenz mit `NOTICE`
