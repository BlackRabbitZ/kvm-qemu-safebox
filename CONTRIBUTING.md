# Beitragen

Beiträge sind willkommen, solange sie die Sicherheitsgrenzen nicht stillschweigend aufweichen.

## Vor einem Pull Request

```bash
bash -n safebox install/*.sh network/*.sh guest/*.sh tests/*.sh
shellcheck safebox install/*.sh network/*.sh guest/*.sh tests/*.sh
./tests/static-policy.sh
xmllint --noout network/safebox-net.xml vm/templates/*.xml.in
```

Änderungen, die Host-Freigaben, Passthrough, zusätzliche Channels, Shared Memory, Clipboard, Dateiübertragung oder Bridged Networking einführen, müssen in der PR-Beschreibung ausdrücklich als Änderung des Threat Models erklärt werden.
