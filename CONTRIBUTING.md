# Contributing

Beiträge sind willkommen, solange sie das Sicherheitsmodell nachvollziehbar erhalten.

## Vor einem Pull Request

```bash
make release-check
```

muss erfolgreich durchlaufen.

## Sicherheitsrelevante Änderungen

Änderungen an folgenden Bereichen benötigen passende Regressionstests:

- VM-Geräte / libvirt XML
- Netzwerkpfad / nftables / nwfilter
- Watchdog / Kill-Pfad
- root-owned Runtime-Helfer
- Host-Integration
- Passthrough-/Sharing-Funktionen
- Ressourcenlimits
- Release-/Supply-Chain-Logik

Ein neues Profil darf ausschließlich Ressourcenwerte ändern und keine Sicherheitsgrenze lockern.

## Security Bugs

Potenzielle VM-Escape-, Host-Privilege-Escalation-, Firewall-Bypass- oder Watchdog-Bypass-Funde bitte nach Möglichkeit über GitHubs private Security-Advisory-Funktion melden. Siehe [`SECURITY.md`](SECURITY.md).
