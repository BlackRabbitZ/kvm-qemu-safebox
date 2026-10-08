# Tests

## Standard

```bash
make check
```

Prüft Syntax, statische Security-/Network-/Resource-Policies, Profile, XML-Rendering, manipulierte Domain-XMLs und dynamische Watchdog-Ausfälle.

## Release

```bash
make release-check
```

Ergänzt Versions-/Dokumentationsprüfungen sowie einen vollständigen Testbau von ZIP, tar.gz, SHA-256-Manifest und SPDX-SBOM.

## Manipulierte XMLs

`tests/mutated-xml.sh` erzeugt eine gültige Referenzdomain und manipuliert sie anschließend einzeln. Unter anderem müssen Clipboard, Hostdev, Channel, `vhost`, zusätzliche Disks, VirtIO-Video, aktiviertes VAPIC, KSM und Filesystem-Sharing abgelehnt werden.

## Watchdog-Fail-Closed

`tests/watchdog-failclosed.sh` verwendet kontrollierte Mocks und simuliert:

- libvirt nicht erreichbar
- Firewall-Attestation fehlgeschlagen
- Runtime-Attestation fehlgeschlagen
- Storage-Attestation fehlgeschlagen
- normalen Domain-Shutdown

Die ersten vier Fälle müssen den Kill-Pfad auslösen; ein normaler Shutdown darf das nicht.

## Echter Hosttest

CI kann keinen vollständigen KVM-Boot mit dem produktiven Host-Setup ersetzen. Vor einem Stable-Rollout empfiehlt sich deshalb zusätzlich ein Integrationstest auf einem dedizierten Debian-13-KVM-Host.

## RC4: Offline-Malware-Regressionen

`tests/rc4-malware-isolation.sh` prüft, dass Legacy-Modi abgelehnt werden, saubere Zero-NIC-XML akzeptiert wird und NIC, rw-ISO, zusätzliche ISO, Pfadtausch, USB, Host-Filesystem, Clipboard sowie VirtIO-Disk-Manipulationen blockiert werden. Root-seitig testet es Sample-SHA-256, Berechtigungen, Symlink-Ablehnung und LUKS2-Check mit **Mocks**. Die Produktivpfade müssen auf dem tatsächlichen Debian-13-Host mit echter KVM-VM getestet werden. Siehe [validation-rc4.md](validation-rc4.md).

## RC5: echte KVM-Testfunktion

`python3 tests/rc5-security-gate.py` prüft nur das **negative Gate-Verhalten**
mit künstlichen Daten (alt, manipuliert, falscher Boot, unvollständig).
Die eigentliche Prüfung `sudo bash ./safebox hardware-test` ist **kein Mock**:
sie benötigt einen echten dedizierten KVM-/libvirt-Linux-Host. Auf der
CI-Maschine wird **niemals** eine Hardwarefreigabe vorgetäuscht.
Siehe [validation-rc5.md](validation-rc5.md).
