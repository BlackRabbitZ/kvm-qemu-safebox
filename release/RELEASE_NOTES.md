# SafeBox v0.5.1-rc5 – Real-KVM Security Gate

- Pflicht-Hosttest mit harmloser Live-KVM-VM: `sudo bash ./safebox hardware-test`.
- Root-owned, auf aktuellen Boot und Hostkomponenten gebundener Abnahmenachweis für 12 Stunden.
- Ohne gültigen Nachweis wird **jeder Offline- und Malware-VM-Start abgelehnt**.
- Live-Test prüft XML-Allowlist, Storage-LUKS2, QEMU-Laufzeit, AppArmor, Seccomp,
  Watchdog, echte VM-Abschaltung und unabhängige `/proc`-Prozessabwesenheit.
- CI-Mocks beweisen **keine** echten KVM-Isolationseigenschaften. Unbekannte VM-Escapes
  sind weiterhin möglich; physisch isolierten dedizierten Host verwenden.
- Das RC5-ZIP ist nicht automatisch kryptografisch signiert.

# v0.5.1-rc5 – Manuelle Malware-Untersuchung / Offline-Hardening

> **Release Candidate – noch nicht für echte unbekannte Malware freigegeben.** Der Quellcode ist statisch und mit Regressionstests geprüft. Ein Debian-13-KVM-/libvirt-/SPICE-End-to-End-Test auf dedizierter Hardware fehlt.

## Hauptänderungen gegenüber RC3

- **Keine vernetzten Runtime-VMs mehr:** nur `start offline [PROFIL]` oder `start malware DATEI [PROFIL]`.
- **Keine persistenten Malware-VMs** und kein `setup-network` für Runtime.
- Neue harte libvirt-XML-Allowlist für **zero-NIC** und ein optionales readonly ISO-CDROM.
- Malware-Datei wird ohne Host-Ausführung in ein ISO mit neutralem Namen `sample.bin` übernommen (max. 256 MiB); Quelle muss regulär und kein Symlink sein.
- Root-owned ISO, `0440`, SHA-256-Manifest und Prüfung auch durch den Watchdog.
- Runtime-Storage muss auf vom Host attestiertem **LUKS2** liegen; andernfalls Start verweigert.
- Fehler bei der QEMU-Identitätsaufnahme nach Start lösen einen sofortigen Kill-Versuch aus; Laufzeitbewertung und Kill-System wurden für Mode `malware` angepasst; Artefakte bleiben bei ungeklärtem VM-Prozesszustand erhalten.
- Neue CLI-, XML-Mutations-, Sample-/LUKS2- und Watchdog-Regressionsfälle.
- Aktualisierte README, Bedrohungsmodell, technische Einschränkungen, Hardware-Validierungscheckliste und Fixstatus.

## Nicht enthalten / ausdrückliche Grenzen

- Keine automatisch erstellten Windows-Gäste, Netzwerk-C2-Simulation, automatische Malware-Telemetrie.
- Keine automatische Storage-Formatierung, keine pro-Session-Krypto-Löschung, keine nachgewiesene Datenträgerbereinigung durch `rm`.
- Kein realer libvirt/KVM-Hardware-Penetrationstest, kein vollständiger CVE-/Backport-Nachweis.
- ZIP ist **kein signierter Release**; GitHub-Release-Signierung separat prüfen.

**Breaking Change:** RC3-Base-Images und alte persistent-vernetzte Modi sind nicht rückwärtskompatibel. Vor Upgrade VMs vollständig beenden, QEMU-Prozesse nachweisen, RC4 installieren und unter RC4 neu versiegeln.

Details: [RC4-Audit](../docs/security-audit-rc4.md), [Host-Abnahmeplan](../docs/validation-rc4.md).
