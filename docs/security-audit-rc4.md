# KVM/QEMU SafeBox 0.5.1-rc4 – Security-Fixstatus

**Prüfobjekt:** RC3 Quellarchive als Ausgangspunkt, RC4 Quellcode nach gezieltem Security-Hardening.  
**Bewertung:** Code-Härtung und automatisierte Regressionen liegen vor. **Keine Freigabe für reale unbekannte Malware ohne physische Host-Validierung.**

## Sicherheitsmaßnahmen

| Bereich | RC4 | Nachweisgrad |
|---|---|---|
| Netzwerkisolation | Legacy-Modi disposable/persistent abgeschaltet; Malware und Offline besitzen **0 NICs**. Installer ist getrennt. | Positive/negative XML-Validator- und CLI-Tests. Kein echter KVM-Netztest. |
| Malware-Import | Nur reguläre Dateien, max. 256 MiB, keine Quell-Symlinks. ISO wird aus kopierten Bytes erzeugt; CD-ROM readonly, `sample.bin` im Gast. | Dateirechte, O_EXCL, SHA-Mutationen mit Generator-Mock. Echtes genisoimage/libvirt ausstehend. |
| Geräteminimierung | Kein Host-Sharing, Clipboard, Agent, USB/PCI passthrough, nested virt, 3D. | XML-Allowlist- und Mutationstests. Nicht auf Live-Host attestiert. |
| Storage | Start verweigert, wenn LUKS2-Unterbau nicht attestierbar. Flüchtige QCOW2-Overlays; kein persistent-Malware-Modus. | `findmnt`/`lsblk`/`cryptsetup` Fail-Closed-Logik mit Mocks. Reales LUKS2 ausstehend. |
| Watchdog | Malware-Mode prüft die ISO fortlaufend, nutzt das Offline-CVE-Gate und den Kill-Dienst. Fehlende QEMU-Prozessidentität nach erfolgreichem Start löst VM-Kill aus, statt ohne Watchdog fortzufahren. | Mock-Fail-Closed Tests für Runtime, Sample, libvirt und Prozessstatus; Identitätsfehler-Abbruch im Code ergänzt. E2E ausstehend. |
| Basis | RC4-Versionsbindung, Hash, Backing-Image/Metadaten. | Statische + Simulationstests; realer Gast noch nicht gebaut. |
| Privilegien | Root-owned Runtime-Helfer müssen exakt mit Quelle übereinstimmen. | Vorstart-Codeprüfungen vorhanden; Root-Checkout-/Supply-Chain-Vertrauen bleibt Betreiberpflicht. |
| Release | Hash + SPDX/Reproduzierbarkeit, Signaturen verpflichtend für offiziellen Release-Pfad. | Build-/Signatur-Negativtests; hier **nur unsigniertes ZIP**. |

## Bekannte offene Punkte

1. **Kein echter QEMU/libvirt-/SPICE-/AppArmor-/Seccomp-/KVM-End-to-End-Test.** Tatsächlich vorhandene Host-Devices/Channels und Runtime-Namespaces können nur am Zielhost bestätigt werden.
2. **Keine pro-Session-Schlüsselvernichtung.** LUKS2 schützt verschlüsselte Blöcke im Ruhezustand, wenn das Volume gesperrt und der Schlüssel geschützt ist. Entfernen einer Datei auf einem geöffneten LUKS2-Dateisystem ist kein kryptografisches Löschen. VM-Arbeitsspeicher, Swap, Host-Backups/Dumps bleiben relevant.
3. **Kein umfassender Debian CVE-/Backport-Abgleich.** Versionsgate verhindert lediglich einige bekannte Modellkombinationen; aktuelle Security Tracker-/Kernelpflege erforderlich.
4. **Keine garantierte VM-Escape-Prävention** gegen unbekannte Hypervisor-/Kernel-/Hardware-Schwachstellen. Physische Host-Isolation empfohlen.
5. **Kein Windows-Gast** für native dynamische Windows-Malware-Ausführung. Debian-13-XFCE-Gast muss separat validiert werden.
6. **Malware ist offline.** Netzgestützte Proben verhalten sich eventuell anders; das ist ein absichtlicher Sicherheitskompromiss, keine Analysefunktion.
7. **Installer weiterhin vernetzt:** für saubere OS-Installation, nicht als Malware-Sandbox einsetzen. Legacy libvirt-Domains vor Migration manuell prüfen.

## Reproduzierbare lokale Tests

```bash
make check
make release-check
bash tests/rc4-malware-isolation.sh
```

**Keine** echte Malware, keine echte QEMU-VM, kein echtes LUKS-Volume und keine Gastnetzwerk-Pakete wurden durch das Chat-Audit gestartet. Die vollständige Hardware-Abnahme ist in [validation-rc4.md](validation-rc4.md) definiert.
