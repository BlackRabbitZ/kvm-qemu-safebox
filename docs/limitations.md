# Grenzen und bekannte Einschränkungen

- **Keine 100-%-Garantie gegen VM-Escapes.** Das Projekt reduziert Angriffsfläche, beseitigt aber keine unbekannten Hypervisor-Lücken.
- **IPv4-only in v0.1.** IPv6 wird im gehärteten Gast deaktiviert.
- **Kein Host↔Gast-Clipboard.** Copy/Paste innerhalb des Debian-Gasts funktioniert normal.
- **Keine Drag-&-Drop-Dateien vom Host.** Dateien müssen aus dem Internet geladen oder auf kontrolliertem Weg anderweitig übertragen werden.
- **Kein USB-Passthrough.** USB-Sticks, Webcams, FIDO-Keys etc. stehen der VM nicht direkt zur Verfügung.
- **Kein Audio in v0.1.** Ein Audio-Gerät ist absichtlich nicht definiert.
- **Host-Skript apt-basiert.** Debian als Host ist der primär getestete Zielpfad.
- **Disposable schützt nicht vor Datenabfluss während der Sitzung.** Was die VM über das Internet senden kann, kann sie während der laufenden Session exfiltrieren.
