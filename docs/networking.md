# Netzwerkmodell RC4

Im Betrieb `start malware` sowie `start offline` wird dem QEMU-Gast **überhaupt keine NIC zugeteilt** (`/domain/devices/interface` = 0). Das ist absichtlich stärker als der bisherige NAT-/Router-/Firewall-Ansatz aus RC3: Routingänderungen, VPNs oder Host-Firewalls können ohne Schnittstelle keinen normalen Guest-IP-Verkehr ermöglichen.

Die Installationsphase `create-base` nutzt ein getrenntes, vorübergehendes `safebox-install-net` mit vorliegenden nftables-/nwfilter-Regeln und muss separat validiert werden. **In dieser Phase nur vertrauenswürdiges Debian installieren und aktualisieren; niemals Malware ausführen.** `setup-network` für Runtime ist in RC4 deaktiviert.

Eine NIC-lose VM bedeutet **nicht**, dass nach einem unbekannten VM-Escape kein Host-Netzzugriff möglich wäre. Auf dedizierter Analysehardware deshalb alle physischen Funk- und Kabelnetzverbindungen vor der Malware-Analyse trennen. Der Live-Testplan steht in [validation-rc4.md](validation-rc4.md).
