# RC2-Sicherheitsaudit: Korrekturstand 0.5.1-rc3

**Prüfgegenstand:** Das komplette RC2-Quellarchiv aus dem Audit vom 08.10.2026.  
**Ergebnis:** Technische Korrekturen für die klar nachgewiesenen Programmfehler, zusätzliche Regressionstests, verbleibende offene Betriebs-/Risikogrenzen. **Keine Freigabe für aktive unbekannte Malware.**

| Befund | Stand RC3 | Änderung / offener Nachweis |
|---|---|---|
| SBX-01 Installer-XML | **Codekorrektur + reproduzierter Negativ-/Positivtest** | Installer verlangt jetzt `safebox-install-filter` ohne unbegründete DHCP-Learning-Parameter. Beide Originaltemplates werden der echten XML-Allowlist unterzogen. |
| SBX-02 Cleanup bei libvirt-Ausfall | **Codekorrektur** | `assert_no_running` verlangt erfolgreiche libvirt-Inventare und unabhängige /proc-Prüfung; Fehler sperren Cleanup. |
| SBX-03 Löschung bei `virsh`-Fehler | **Codekorrektur** | Disposable-Overlay und Identität bleiben bei unklarem QEMU-Zustand erhalten; auch Startfehler löschen keine möglicherweise geöffneten Dateien. |
| SBX-04 Schein-Erfolg des Kill-Dienstes | **Codekorrektur + Mock-Test** | Kill liefert nur nach erfolgreicher libvirt- und /proc-Abwesenheitskontrolle Erfolg; bei libvirt-Ausfall immer nonzero, auch nach versuchter validierter PID-Beendigung. |
| SBX-05 XML-Hash kannonisch | **Codekorrektur + Test** | Zentrale XML-Normalisierung sortiert Attribute, ignoriert leere Formatierung sowie libvirt-UUID, erkennt aber Regeländerungen. Realer `nwfilter-dumpxml`-Test ausstehend. |
| SBX-06 SPICE ohne Listener | **Codekorrektur; echter Viewer-Test offen** | CLI startet `virt-viewer --connect` über libvirt statt remote-viewer mit `domdisplay`-URI. Kein offener TCP-SPICE-Port. |
| SBX-07 Auskommentierte QEMU-Settings | **Codekorrektur + Test** | Aktive Einstellungen geparst; fehlende oder doppelte Werte sind Fehler. Harden-Skript normalisiert Duplikate. |
| SBX-08 LAN/VPN/Policy-Routing | **Teilkorrektur, Architekturgrenze offen** | Alle IPv4-Routentabellen plus lokale Präfixe berücksichtigt, CIDRs konsolidiert; öffentliche Hairpin-/Proxy-Relays und Routing über vorgeschaltete Router benötigen physische Netztests/externen Gateway. |
| SBX-09 Route/Adresswechsel | **Fail-Closed wie bisher; Restproblem offen** | Firewall und Watchdog vergleichen den aktuellen Zustand. Unmittelbare atomare Absicherung eines Netzwechsels ohne Latenz ist nicht implementiert. |
| SBX-10 Gast-Härtung | **Teilprüfung; Live-Attestation offen** | Offline-Paket-/Dateiprüfungen vorhanden. Effektive Dienste/AppArmor/nftables im gebooteten Gast noch nicht getestet. |
| SBX-11 Debian-CVE-Abdeckung | **Offen, dokumentiert** | Versions-Gate bleibt begrenzt; kein vollständiger distributionsspezifischer Schwachstellen-Feed/Backport-Abgleich. |
| SBX-12 Artefaktsignierung | **CI-Pfad verschärft; echter Release offen** | CI veröffentlicht nur bei vorhandenen Signier-Secret, passenden Fingerprint und allen vier gültig signierten Artefakten. Das von diesem Chat erzeugte ZIP ist nur ein lokales **unsigniertes Quellcodearchiv**. |
| SBX-13 Signer-Kontrolle | **Codekorrektur** | Release-Verifikation erfordert expliziten Fingerprint und alle vier detached Signaturen, andernfalls FAIL. |
| SBX-14 Laufende Domains | **Codekorrektur** | `security-check` iteriert über alle sichtbaren aktiven SafeBox-Domains statt nur die erste. |
| SBX-15 Sichere Datenlöschung | **Bewusst offen** | `rm` garantiert kein Crypto-Erase; verschlüsseltes Storage + Schlüsselvernichtung wären zusätzliche Infrastruktur. |
| SBX-16 Tests erkennen Installer nicht | **Codekorrektur + Regressionstests** | `tests/audit-regressions.sh` testet Installer-, Runtime- und Offline-Templates und die wichtigsten Fehler-/Manipulationszustände. |

## Lokale Prüfungen

Ausführung ohne echte KVM-VM oder Netzverkehr: `make check`, `make release-check`, `bash tests/audit-regressions.sh`, `bash -n` der Shell-Skripte, Python-Kompilierung sowie Quellpaket-Build. **Keine** Sandbox-Penetrationstests oder QEMU-Binäranalyse.

## Vor jeder produktiven Freigabe auf echtem Debian-13-Testhost

1. Vor Upgrade alle VMs beenden, Daten sichern, alte RC2-Base/Overlays auf einem dedizierten Testhost neu versiegeln bzw. neu erstellen; nie bei laufender VM aktualisieren.
2. `bash ./install/install-host.sh` aus einem geprüften root-owned Codecheckout; alle root-owned Runtime-Helfer werden synchron installiert.
3. `bash ./safebox doctor` und `bash ./safebox security-check` müssen fehlerfrei sein. Konfiguration einschließlich nwfilter-Dump und nftables-Regeln manuell gegen tatsächliches Host-Routing vergleichen.
4. Den echten ISO-Installer komplett durchlaufen, im Gast `bash ./guest/harden.sh` (nach Anleitung) ausführen, VM herunterfahren, Base versiegeln, drei Profile und offline/online/persistent/disposable testen.
5. Während einer **harmlosen** Test-VM systematisch libvirt stoppen/isolieren, aktive QEMU-PID validieren, Kill-Eskalation protokollieren; sicherstellen, dass weder Overlay noch Identität vor erwiesener Beendigung gelöscht werden.
6. SPICE-Konsole prüfen; Clipboard, Dateitransfer, Host-Share, PCI/USB, IPv6, QMP-TCP, DNS-/DHCP-Listener jeweils aktiv nachweisen.
7. Auf separatem isoliertem Gateway sämtliche Host-IP-, VPN-, VLAN-, Policy-Table-, NAT-, Hairpin-, DNS-, IPv6- und Router-Neukonfigurationsfälle mit Paketmitschnitt prüfen. Ein fehlgeschlagener Test blockiert die Freigabe.
8. Gästeboot prüfen (`sudo nft list ruleset`, `aa-status`, `systemctl`, `ss -lntup`, Paket-/Kernelupdates), Host-/Gast-Limits mit harmlosen Lasttests messen.
9. Die reale Debian-QEMU/libvirt/Kernel-Patchliste gegen den aktuellen Debian Security Tracker und tatsächlich aktivierte Geräte prüfen. Keine CVE-Freigabe allein anhand numerischer QEMU-Version.
10. Bei hohem Risiko dedizierten physischen Host und externes Egress-Gateway einsetzen; vor der Malware-Nutzung einen zweiten unabhängigen Audit durchführen.

**Wichtig:** „Im Quellcode korrigiert“ ist nicht gleich „auf dem echten Host sicher bewiesen“. Fail-Closed ist hier die Entscheidung, unklare Zustände zu melden und keine unbewiesene Bereinigung durchzuführen. Es garantiert keinen absolut wirksamen Kill bei einem beschädigten/kompromittierten Host.
