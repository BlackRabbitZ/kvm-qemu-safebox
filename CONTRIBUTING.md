# Beitragen

Beiträge sind willkommen, solange sie die Sicherheitsgrenzen nicht stillschweigend aufweichen.

## Vor einem Pull Request

```bash
make check
# entspricht u. a.:
bash -n safebox install/*.sh network/*.sh guest/*.sh tests/*.sh tools/*.sh
shellcheck safebox install/*.sh network/*.sh guest/*.sh tests/*.sh tools/*.sh
./tests/static-policy.sh
./tests/network-policy.sh
xmllint --noout network/safebox-net.xml vm/templates/*.xml.in
```

Änderungen, die Host-Freigaben, Passthrough, zusätzliche Channels, Shared Memory, Clipboard, Dateiübertragung oder Bridged Networking einführen, müssen in der PR-Beschreibung ausdrücklich als Änderung des Threat Models erklärt werden.
