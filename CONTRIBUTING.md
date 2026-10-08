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


## ShellCheck lokal ausführen

GitHub Actions führt ShellCheck für **alle** Bash-Dateien aus. `bash -n` und `make check` ersetzen diesen Test nicht.

```bash
sudo apt-get install -y shellcheck
make lint
make check
```

Ein Pull Request ist erst CI-bereit, wenn sowohl `make lint` als auch `make check` erfolgreich sind.
