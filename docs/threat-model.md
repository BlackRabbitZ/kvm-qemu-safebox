# Threat Model

## Angreifer

SafeBox nimmt an, dass innerhalb der VM beliebiger Code mit **Root-Rechten** ausgeführt werden kann. Gast-Firewall, Gast-Sysctls und Gast-AppArmor dürfen daher nicht als Host-Sicherheitsgrenze betrachtet werden.

## Zu schützende Ressourcen

- Host-Dateisystem und Host-Dienste
- LAN-Geräte wie Router, NAS, Drucker und andere Rechner
- Host-Zwischenablage und Host-Dateien
- physische USB-/PCI-Geräte
- unverändertes Basisimage
- Sitzungstrennung bei Disposable-Modus

## Primäre Sicherheitsgrenzen

- KVM/QEMU/libvirt-Prozessisolation
- verpflichtendes AppArmor
- QEMU-seccomp
- separate Namespaces/Cgroups
- minimiertes virtuelles Gerätemodell
- libvirt `clean-traffic` mit fest gepinnter Runtime-IP
- getrennte Bootstrap-/Runtime-Netze; keine Runtime-DHCP/DNS-Dienste auf dem Host
- hostseitiges nftables
- kein Bridging
- hostseitiger kompletter IPv6-DROP
- immutable Base + überprüfte Backing-Chain
- Runtime-Attestation

## Bewusst nicht versprochen

Keine Garantie gegen unbekannte VM-Escapes, CPU-/Mikrocodefehler oder kompromittierte Host-Administratoren. Ein bereits kompromittierter Host liegt außerhalb des Modells. Online-Sitzungen können Daten an öffentliche Internetziele senden.
