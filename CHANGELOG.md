
### CI-Korrektur 3 (v0.5.1-rc5, ohne Versionswechsel)

- Ungültige ShellCheck-Direktiven mit Kommentartext nach `--` entfernt (SC1073/SC1072).
- `SC2015`-Anfälligkeit der Sample-Größenprüfung durch explizite Bedingung ersetzt.
- PID-/UUID-Argumenteniteration überarbeitet, damit ShellCheck den Schleifenindex als verwendet erkennt (SC2034).
- Regressionstest gegen ungültige ShellCheck-Direktiven in `make check` aufgenommen.
- Kein neuer Sicherheitsnachweis für KVM oder unbekannte Malware.

## v0.5.1-rc5 – Real KVM Test & Security Gate

- Benigner Echt-KVM-Smoke-Test mit eigenem Offline-Overlay (kein Malware-Sample),
  produktivem XML-/Runtime-/Storage-Validator, AppArmor/Seccomp und systemd-Watchdog.
- Tatsächlicher Kill-Domain-Pfad und unabhängige `/proc`-Nachkontrolle.
- Root-only Testnachweis, Boot-/Maschinen-/Kernel-/Komponentenbindung und 12h TTL;
  Testnachweis wird vor jedem erneuten Abnahmetest entzogen.
- Pflicht-Gate **vor jeder** Offline-/Malware-VM-Datenträgererstellung; Fehler stoppt Start.
- Negative Unit-Tests für stale/forged/missing Evidence; keine CI-Schein-Freigabe.
- Keine unbekannten VM-Escapes nachgewiesen oder widerlegt; Hardwaretest und
  physische Isolation weiterhin auf dem Zielhost zu absolvieren.

# Changelog

## 0.5.1-rc4 — Sicherheitskorrekturen zum RC2-Audit

- Installer-Filter stimmt nun mit der eigenen XML-Allowlist überein; produktive Templates werden in echten Positiv-/Negativtests geprüft.
- Aufräumen und Disposable-Löschen verweigern unklare libvirt-Zustände und laufende oder nicht attestierbare QEMU-Prozesse.
- Root-Eigenidentitäten, sichere QEMU-/UUID-/Startzeit-PID-Validierung und unabhängiger /proc-Inventarcheck verbessern die Trennung von Prozessende und libvirt-Verbindungsfehler.
- Kill-Dienst meldet bei libvirt-Ausfall keinen Schein-Erfolg mehr; Quarantäne der Artefakte bei fehlendem Beweis einer Beendigung.
- nwfilter-SHA256 semantisch kanonisiert, ohne Regeländerungen wegzunormalisieren.
- Grafik-CLI verwendet virt-viewer mit libvirt-FD-Zugriff statt unpassender remote-viewer-SPICE-URI.
- Host-Härtungsprüfung ignoriert Kommentare und lehnt doppelte aktive Parameter ab.
- IPv4-Netzwerkregeln berücksichtigen die Routentabellen einschließlich Policy-Routing und VPN-Zielen; Routingabfrage muss erfolgreich sein.
- Sicherheitsprüfung umfasst alle laufenden SafeBox-Domains, statt nur die erste.
- GitHub-Release verlangt ein mit dem gepinnten Fingerprint signiertes Artefaktset; lokal gebaute nicht signierte Testartefakte sind ausdrücklich keine Releases.
- Neue detaillierte Audit-Regressionstests. Reale Live-KVM-/Netz-/Guest-/CVE-/Crypto-Erasure-Testmatrix steht aus.


## 0.5.1-rc2

Bugfix-/Regression-Release ohne neue Komfortfunktionen.

- Hardened-Default wechselt Systemdisk von `virtio-blk` auf SATA und NIC von `virtio-net` auf `e1000e`, um die aktuell bekannten offenen Pfade CVE-2024-8612 bzw. CVE-2026-66900 im Debian-13-QEMU-Standardstand nicht zu exponieren.
- Debian-13-QEMU 10.0.13 ist dadurch im Standardprofil wieder nutzbar; ein Rückwechsel auf verwundbares VirtIO-Netzwerk bleibt fail-closed.
- `qemu-system-modules-spice` wird explizit installiert.
- Base-Hash/Metadaten werden ausschließlich über privilegierte Lesezugriffe geprüft; Base-Version wird zwingend an die SafeBox-Version gebunden.
- AppArmor muss im laufenden QEMU-Prozess `enforce` sein; erwarteter QEMU-Dienstbenutzer und leere effektive/permitted/ambient Capabilities werden attestiert.
- Watchdog behandelt eine aus libvirt verschwundene Domain fail-closed und attestiert zusätzlich den libvirt-nwfilter.
- nftables wird über einen root-owned Hash der vollständig normalisierten Live-Policy überwacht.
- Release-Tag-Prüfung verwendet echte `git verify-tag`-Kryptografie statt eines Signatur-Textmarkers.
- Release-Build setzt ein deterministisches `SOURCE_DATE_EPOCH`; ZIP, tar.gz, SBOM und Prüfsummen werden auf Reproduzierbarkeit getestet.
- Lock-Datei ist nicht mehr world-writable.
- Neue Regressionstests schreiben alle im v0.5.0-Audit gefundenen Fehler fest.

## 0.5.0

### Stable Release – Phase 3

- Finalisierung der dreistufigen Security-/Isolation-Überarbeitung.
- Neue Ressourcenprofile `hardened`, `balanced` und `performance`; alle Profile behalten dieselben Sicherheitsgrenzen bei.
- Dynamische Watchdog-Fail-Closed-Tests für libvirt-, Firewall-, Runtime- und Storage-Ausfälle.
- XML-Manipulationstests gegen Clipboard, Hostdev, Channel, vhost, zusätzliche Disks, VirtIO-Video, VAPIC, KSM und Filesystem-Sharing.
- Zusätzlicher Python-basierter Domain-XML-Allowlist-Validator, der von der Runtime-Attestation mitverwendet wird.
- Stable-Release-Pipeline mit reproduzierbaren ZIP-/tar.gz-Artefakten, SHA-256-Manifest und SPDX-2.3 Source-SBOM.
- Optional detached GPG-signierbare Release-Artefakte und signierbare annotierte Git-Tags.
- GitHub-Release-Workflow erstellt nach einem signierten annotierten Tag einen Draft Release.
- Release-Checks um Profile, SBOM, Artefakte, Execute-Bits, relative Dokumentationslinks und Versionskonsistenz erweitert.
- README und SECURITY.md vollständig für den Stable-Release überarbeitet.
- Temp-Verzeichnis-Fallback verbessert, wenn `XDG_RUNTIME_DIR` nicht verfügbar ist.
- Runtime-Helfer-Synchronität prüft nun auch Dateiinhalt (`cmp`) und den XML-Policy-Validator.
- Installer-Runtime-Identität wird bei Watchdog-Fehlern und beim Versiegeln sauber entfernt.

## 0.5.0-alpha2

### Phase 2 – Isolation, Stabilität und DoS-Schutz

- Harte CPU-Quota über libvirt `cputune` für Runtime und Installer.
- Harte Disk-I/O-Limits für Bandbreite und IOPS über `iotune`.
- Storage-Reserve vor dem Start sowie kontinuierliche Überwachung von freiem Host-Speicher und Overlay-Allokation.
- Basis- und Overlay-Metadaten binden Sessions an Base-ID, SHA-256, SafeBox-Version, Domain und Diskpfad.
- `flock` verhindert parallele mutierende SafeBox-Verwaltungsoperationen.
- `umask 077` und `mktemp`/geschützte Runtime-Verzeichnisse reduzieren Temp-/Race-Risiken.
- Stärkere PID-/Domain-Zuordnung über QEMU-Binary, Domainname, libvirt-UUID und Prozess-Startzeit.
- Root-owned Runtime-Identität erlaubt fail-closed PID-Validierung auch bei ausgefallenem libvirt.
- libvirt TCP/TLS Remote-Management wird deaktiviert und von `security-check` geprüft.
- QEMU-Monitor/QMP darf nicht über TCP/Telnet/UDP exponiert sein.
- Neue Befehle: `security-check`, `verify-runtime`, `status` und `cleanup`.
- Automatisches Cleanup verwaister Disposable-/Offline-Overlays und Watchdog-Units.

## 0.5.0-alpha1

### Phase 1 – Security-kritisch

- QEMU/CVE-Sicherheitsgate für bekannte verwundbare virtio-net-Versionen; Netzwerkbetrieb wird fail-closed blockiert.
- Watchdog mit `OnFailure=` an root-owned `safebox-kill@.service` gekoppelt.
- Normaler VM-Shutdown wird über `domstate` erkannt und beendet den Watchdog sauber.
- Netzwerkbackend explizit auf QEMU-Userspace gesetzt und in der Runtime attestiert.
- Direkt verbundene Host-/VPN-/Firmennetze werden dynamisch in `local_v4` aufgenommen und geblockt.
- Firewall-Attestation prüft Sets, Chains, Regelanzahlen und dynamische Inhalte gegen die Soll-Policy.
- Geräte-Allowlist verschärft: exakte Laufwerksanzahl, begrenzte PCIe-Root-Ports und strengere Laufwerks-/NIC-Prüfung.

## 0.4.0

### Sicherheit

- Watchdog und Runtime-Attestation werden nicht mehr direkt aus dem Benutzer-Checkout als root ausgeführt.
- Sicherheitskritische Runtime-Helfer werden root-owned nach `/usr/local/libexec/safebox/` installiert.
- Installierte SafeBox-Konfiguration wird root-owned unter `/etc/safebox/defaults.conf` gehalten.
- Watchdog startet mit `Restart=on-failure` und wird nach dem Start auf aktiven systemd-Zustand geprüft.
- Bei libvirt-Ausfall versucht der Watchdog die Domain fail-closed zu beenden; direkter PID-Fallback nur nach Domain-/QEMU-Zuordnung.
- Geräte-Attestation von Denylist-orientiert auf strengere Soll-/Allowlist-Prüfung erweitert.
- VirtIO Packed Rings für Disk und NIC explizit deaktiviert und attestiert.
- RAM-, Swap-, vCPU- und IOThread-Werte werden live gegen den Sollzustand geprüft.
- Standard-Grafik von VirtIO-VGA auf Bochs Display umgestellt, um den VGA-/VirtIO-GPU-Pfad im sicheren Standardprofil zu vermeiden.
- Debian-Installationsmedien werden über `SHA256SUMS.sign` + Debian Archive Keyring authentifiziert und anschließend gehasht.
- Ressourcen- und Watchdog-Konfiguration wird validiert.

### Netzwerk

- First-Run-Reihenfolge korrigiert: libvirt-Bridge wird vor dem Aufbau des dynamischen Host-IP-Firewall-Sets erstellt.
- Firewall-Attestation bleibt kontinuierlicher Bestandteil des Runtime-Watchdogs.
- Gast-Netzwerktest prüft jetzt die aktive nftables-SafeBox-Policy statt irreführender Loopback-Porttests.

### Stabilität / Dokumentation

- Professionell überarbeitete README mit Architektur, Threat Model, Quick Start, Betriebsarten und klaren Sicherheitsgrenzen.
- Root-owned Runtime-Helfer werden durch `doctor` auf Synchronität und sichere Dateirechte geprüft.

## [0.5.1-rc4] – Offline Malware-Sandbox Hardening (08.10.2026)

- Breaking: Malware-/Offline-Runtime ohne jegliche NIC, Legacy network-/persistent-Modi deaktiviert.
- Readonly ISO-Import von regulären Samples (Größenlimit, O_NOFOLLOW, O_EXCL, SHA-256).
- LUKS2-Unterbau wird zum Runtime-Start zwingend hostseitig nachgewiesen; keine Crypto-Erase-Behauptung.
- ISO-Integrität in Runtime-Watchdog eingebunden; fehlgeschlagene QEMU-Identitätsaufnahme führt zum Kill-Versuch; Regressionen/Mutationstests erweitert.
- Debian-13-KVM-Hardwareprüfung und offener Risiko-/Freigabestatus dokumentiert.
