# Netzwerkmodell

SafeBox trennt **Installation** und **Runtime** bewusst in zwei libvirt-Netze.

## Runtime: `safebox-net`

```text
Netz       safebox-net
Bridge     virbr-safebox
Subnetz    10.77.0.0/24
Gateway    10.77.0.1
Gast       10.77.0.100/24 (statisch)
MAC        52:54:00:77:00:10
DHCP       aus
Host-DNS   aus
IPv6       hostseitig vollständig geblockt
```

`network/safebox-net.xml` enthält absichtlich **kein `<dhcp>`** und setzt `<dns enable='no'/>`. Damit soll libvirt für das Runtime-Netz keinen DNS-/DHCP-Dienst bereitstellen. Nach dem Start prüft SafeBox zusätzlich, dass kein unerwarteter `dnsmasq`-Prozess für `safebox-net` läuft.

### Runtime Host-Policy

Erlaubt ist nur:

- ausgehender IPv4-Zugriff auf nicht blockierte öffentliche Ziele
- Rückverkehr für vom Gast initiierte Verbindungen

Hostseitig blockiert werden:

- **sämtlicher Gast→Host-Verkehr auf `virbr-safebox`**
- neue Host→Gast-Verbindungen
- neue weitergeleitete Eingangsverbindungen
- RFC1918
- Loopback, Link-Local, CGNAT und weitere Spezialbereiche
- unerwartete IPv4-Quelladressen
- **sämtlicher IPv6-Verkehr in beide Richtungen**

IPv6 wird absichtlich auf dem Host verworfen. Eine Root-Shell im Gast kann daher nicht durch Reaktivieren von IPv6 die Netzgrenze umgehen.

## Installation: `safebox-install-net`

```text
Netz       safebox-install-net
Bridge     virbr-safebox-inst
Subnetz    10.77.0.0/24
Gateway    10.77.0.1
Gast       feste DHCP-Lease 10.77.0.100
DHCP/DNS   nur für Bootstrap/Installation
```

Dieses Netz wird nur von `create-base` für die vertrauenswürdige Debian-Erstinstallation verwendet. Der nftables-Guard erlaubt hier nur DHCP/DNS zum Host; sonstiger Gast→Host-Verkehr bleibt gesperrt. `seal-base` zerstört und undefiniert das Installationsnetz wieder.

Untrusted/riskante Workloads dürfen niemals im Installationsnetz betrieben werden.

## Anti-Spoofing

Beide Online-Domains verwenden `clean-traffic`, der auf libvirts `clean-traffic` aufbaut.

- **Installer:** `CTRL_IP_LEARNING=dhcp`, damit die feste Bootstrap-Lease sicher gelernt werden kann.
- **Runtime:** `IP=10.77.0.100`, weil der gehärtete Gast statisch konfiguriert ist.

Der nftables-Guard erzwingt zusätzlich unabhängig vom nwfilter `10.77.0.100` als einzige erlaubte geroutete IPv4-Quelladresse.

## Kein Netzwerk-Autostart

Beide SafeBox-Netze haben keinen Autostart. Vor jeder Netzwerkaktivierung wird zuerst der nftables-Guard geladen/verifiziert und der nwfilter geprüft. Ein vorhandenes libvirt-Netz muss exakt der erwarteten Policy entsprechen; Abweichungen führen zum Abbruch.

## Öffentliche DNS-Resolver

`guest/harden.sh` setzt standardmäßig:

```text
9.9.9.9
149.112.112.112
```

Die Werte lassen sich beim Härtungslauf über `SAFEBOX_DNS_PRIMARY` und `SAFEBOX_DNS_SECONDARY` überschreiben. Private/LAN-DNS-Ziele funktionieren absichtlich nicht, weil der Host-Guard private Adressbereiche blockiert.

## Grenzen

Ein öffentliches Internetziel kann serverseitig selbst Zugriff auf andere Netze besitzen. SafeBox kann die Infrastruktur eines entfernten Dienstes nicht beurteilen. Online-Modus verhindert auch keine Exfiltration zu öffentlichen Zielen. Für vollständig netzlose Arbeit `start offline` verwenden.
