# Architektur

SafeBox folgt einem **Defense-in-Depth- und Fail-Closed-Modell**. Der Runtime-Gast wird als potenziell vollständig kompromittiert betrachtet.

```text
Internet
   │
libvirt NAT
   │
nftables safebox_guard
   ├── Runtime Gast -> Host: DROP ALL
   ├── Runtime Host -> Gast: keine neuen Verbindungen
   ├── RFC1918/Spezialziele: DROP
   └── IPv6: DROP ALL in beide Richtungen
   │
libvirt nwfilter clean-traffic
   └── MAC/IP/ARP Anti-Spoofing
   │
virbr-safebox
   │
virtio-net
   │
Debian 13 + XFCE
   └── statische IPv4 10.77.0.100/24
```

Die Debian-Erstinstallation nutzt eine **separate Bootstrap-Grenze**:

```text
safebox-install-net / virbr-safebox-inst
   ├── DHCP/DNS nur während Installation
   ├── sonst Gast -> Host: DROP
   ├── LAN/Spezialziele: DROP
   └── wird durch seal-base entfernt
```

## Host-Sicherheitsgrenzen

1. **KVM** trennt Gast- und Host-Ausführung über Hardwarevirtualisierung.
2. **Minimiertes QEMU-Gerätemodell**: keine Host-Dateisysteme, kein USB-/PCI-Passthrough, keine Zusatzchannels, kein Guest Agent, kein Audio, kein Ballooning, kein 3D.
3. **AppArmor** ist hostweit für libvirt-QEMU verpflichtend; unconfined Gäste werden abgelehnt.
4. **QEMU seccomp** wird hostweit aktiviert.
5. **libvirt nwfilter** blockiert MAC-/IPv4-/ARP-Spoofing direkt am virtuellen Interface.
6. **nftables Host-Guard** blockiert Host/LAN/IPv6 unabhängig vom Gast.
7. **Keine Runtime-Host-Dienste auf der VM-Bridge**: kein libvirt-DHCP und kein libvirt-DNS.
8. **Immutable Base + QCOW2-Overlay** trennt die Basis von Sitzungsschreibzugriffen.
9. **Runtime-Attestation** prüft den tatsächlich gestarteten QEMU-Prozess und das Live-XML. Bei Fehler wird die VM beendet.

## Vertrauensgrenze

Gast-Sysctls, Gast-Firewall, Gast-AppArmor und die statische Gast-IP sind nützliche Zusatzschichten, aber **keine Host-Sicherheitsannahme**. Root im Gast darf sie verändern können, ohne dass dadurch Host/LAN/IPv6-Isolation oder die hostseitige Quell-IP-Policy aufgehoben wird.
