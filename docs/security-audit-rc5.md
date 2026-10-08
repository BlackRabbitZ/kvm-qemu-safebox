# RC5 – Implementierter Fixstatus (Stand: Codeprüfung, kein Live-Host)

| Bereich | Implementierung | Ausführung auf Zielhost |
|---|---|---|
| Real-KVM-Smoke-Test | ✅ In `hardware-acceptance.py` implementiert | ⚠️ Noch nicht ausgeführt |
| Offline-VM ohne NIC, Shares, USB | ✅ XML-/Runtime-Gate unverändert | ⚠️ Live-Verifikation ausstehend |
| AppArmor, Seccomp, UID, Namespaces | ✅ Im echten VM-Prozess geprüft | ⚠️ Live-Verifikation ausstehend |
| Produktiver Kill + Watchdog | ✅ In benignem Test eingeschlossen | ⚠️ Live-Verifikation ausstehend |
| LUKS2, Basis/Overlay-Bindung | ✅ Echt-Host-Prüfpfad | ⚠️ Live-Verifikation ausstehend |
| Security Gate vor VM-Start | ✅ In `start_vm` vor Overlay/ISO und `virsh create` | ✅ Negativtests/Codeprüfung |
| Altnachweis, Neustart, Hoständerung | ✅ 12h TTL, Boot-ID, Host-Hashes | ✅ Negativ-Unit-Tests |
| Schutz vor allen VM-Escapes | ❌ Nicht garantierbar | ❌ Nicht nachgewiesen |
| Freigabe unbekannter Malware | 🔒 Durch Gate gesperrt bis Live-PASS | ❌ Freigabe nicht erteilt |

**Keine Echthardware-Tests in der Erstellungsumgebung:** `/dev/kvm`, `virsh`,
libvirt-Daemon und ein reales verschlüsseltes Host-Volume sind nicht verfügbar.
Keine automatische oder nachträgliche Freigabe vortäuschen.
