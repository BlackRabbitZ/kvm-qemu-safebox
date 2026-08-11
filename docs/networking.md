# Netzwerkmodell

SafeBox verwendet **kein Bridged Networking**. Das virtuelle Netz `safebox-net` nutzt libvirt-NAT über `virbr-safebox`.

## Erlaubt

- DHCP zum libvirt-dnsmasq auf dem Host
- DNS zum libvirt-dnsmasq auf dem Host
- ausgehender Zugriff auf öffentliche Internetziele
- Antworten auf vom Gast initiierte Internetverbindungen

## Blockiert

- sonstiger Gast→Host-Verkehr
- RFC1918: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- Loopback-/Link-Local-/CGNAT- und weitere Spezialbereiche
- IPv6 ULA/Link-Local/Multicast in der Guard-Tabelle
- Kommunikation zwischen SafeBox-Gästen durch libvirt-Port-Isolation

## Warum DNS/DHCP zum Host erlaubt sind

Bei einem libvirt-NAT-Netz stellt der Host für den virtuellen Link DHCP und DNS bereit. Diese beiden Dienste werden deshalb gezielt freigegeben; andere Host-Ports werden verworfen.

## Bekannte Grenze

Eine Domain kann einen öffentlich gerouteten Dienst erreichen, der wiederum Zugriff auf dein internes Netz hat. Netzisolation ersetzt deshalb keine Sicherheitsprüfung externer Dienste. VPNs auf dem Host können außerdem öffentliche oder private Routen verändern; die RFC1918-Sperren bleiben zwar bestehen, aber benutzerdefinierte Unternehmensnetze sollten zusätzlich in `blocked_v4`/`blocked_v6` eingetragen werden.

## Persistenz auf dem Host

`setup-network` installiert `safebox-firewall.service`. Die Guard-Tabelle wird damit bei jedem Host-Start erneut geladen und ist in der systemd-Reihenfolge vor `libvirtd.service`/`virtqemud.service` eingeordnet. So soll ein automatisch startendes libvirt-Netz nicht ohne die zusätzliche SafeBox-Guard-Regel aktiv werden.
