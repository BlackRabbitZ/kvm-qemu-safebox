# GitHub Actions: `Nicht ausführbar` / fehlende Unix-Ausführungsrechte

## Ursache

`tests/release-check.sh` hat mit `[FAIL] Nicht ausführbar: tools/build-release.sh`
korrekt erkannt, dass das betreffende Skript auf dem GitHub-Actions-Runner nicht als
Programm ausführbar war. Bash-Syntax und ShellCheck können trotzdem erfolgreich sein:
Es handelt sich um **Git-Dateimodus-Metadaten** (`100644` statt `100755`).
Ein normales Hochladen über die GitHub-Webseite kann Ausführungsbits einer
lokalen ZIP-Datei nicht zuverlässig in Git-Tree-Modi übertragen.

## Umgesetzte Abhilfe

Der CI-Workflow und der Release-Workflow rufen direkt nach `actions/checkout`
mit `bash tools/normalize-executable-bits.sh` eine eng begrenzte
Normalisierung auf. Die Datei verarbeitet nur das Hauptprogramm und die bekannten
Skriptgruppen; bei fehlenden Dateien oder Symlinks scheitert sie.
`release-check.sh` prüft weiterhin auf echte Ausführbarkeit. Die
Release-Artefakt-Regression prüft zusätzlich die ausführbaren Dateimodi in ZIP.
Das ist keine Abschaltung der Sicherheitsprüfungen.

## Dauerhaft richtige Dateimodi in Git (Windows/PowerShell)

Das Normalisieren im CI-Runner ändert **nicht** die Dateimodi im Git-Index.
Auf einem lokalen Git-Checkout des Repositories können die korrekten Modi
unabhängig vom Windows-Dateisystem so in Git eingetragen werden:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\set-git-executable-bits.ps1
git diff --cached --summary
git commit -m "Fix Unix executable file modes"
git push
```

Vor dem Commit die angezeigten Dateimodi prüfen. Wer das Skript nicht ausführen
möchte, kann alternativ für jede betroffene Datei
`git update-index --chmod=+x -- tools/build-release.sh` verwenden.

## Lokal auf Debian/Linux überprüfen

```bash
bash tools/normalize-executable-bits.sh
bash tests/release-check.sh
bash tests/release-artifacts.sh
make lint
make check
```

`make lint` erfordert die separate Installation von `shellcheck`.
Ein erfolgreicher Repository-Test ist **kein** KVM-Isolationsnachweis und
**keine** Malware-Freigabe. Echte Hardwaretests bleiben erforderlich.
