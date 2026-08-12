# Grenzen und bekannte Einschränkungen

- **Keine 100-%-Garantie gegen VM-Escapes.** SafeBox reduziert Angriffsfläche, kann unbekannte Fehler in KVM/QEMU/libvirt/Kernel/Hardware aber nicht ausschließen.
- **Debian-/AppArmor-Zielprofil.** v0.2.0 erzwingt AppArmor und ist damit nicht ohne Anpassung für SELinux-Hosts gedacht.
- **Systemweite libvirt-Härtung.** Die verwalteten `qemu.conf`-Optionen wirken auf alle QEMU-Domains der Systeminstanz.
- **IPv4-only.** IPv6 wird im Gast deaktiviert und zusätzlich hostseitig vollständig verworfen.
- **Kein Host↔Gast-Clipboard oder Drag & Drop.**
- **Kein USB-/PCI-Passthrough.**
- **Kein Audio / 3D.**
- **Disposable ist kein Secure Erase.** Das Overlay wird logisch gelöscht; physische Rückstände auf SSD/CoW/Snapshots/Backups sind damit nicht garantiert beseitigt.
- **Kein Schutz vor Exfiltration ins öffentliche Internet.** Eine Online-VM darf öffentliche Ziele erreichen.
- **Externe Dienste können intern weiterleiten.** Ein öffentliches Ziel kann selbst Zugriff auf andere Netze haben.
- **CPU-/Mikroarchitektur bleibt eine Grenze.** Cache-/Transient-Execution-/SMT-Seitenkanäle und unbekannte CPU-/Mikrocodefehler können durch eine VM-Konfiguration nicht vollständig ausgeschlossen werden. Für besonders sensible Hosts sind aktueller Mikrocode und ggf. deaktiviertes SMT zusätzliche Betriebsmaßnahmen.
- **Host muss aktuell und vertrauenswürdig sein.** SafeBox kann einen bereits kompromittierten Host nicht retten.
