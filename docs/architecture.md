# Architektur v0.5.1-rc5

Trusted Debian-13-Host (KVM/libvirt/QEMU) → root-owned Helfer und Hardware-/Versionsprüfungen → **zero-NIC** Malware-VM im Disposable-Modus.

Gast-Geräte: SATA-Systemdisk aus schreibgeschützter, gehashter Basis + flüchtigem qcow2-Overlay, optional schreibgeschütztes Sample-ISO als zusätzliches SATA-CD-ROM, PS/2-Eingabe, Bochs-Video, SPICE ohne TCP-Listener/Clipboard/Transfer. Keine PCI-/USB-Hostgeräte, Dateifreigaben, Guest Agents oder Netzschnittstellen.

Sicherheitsprüfungen: Template-basierte VM-XML-Allowlist vor und nach Start, Prozess-/AppArmor-/Seccomp-/Namespace-Attestation, ISO-Hash/Permissions, LUKS2-Storage-Preflight, systemd-Watchdog mit Kill-Fallback, Cleanup nur bei bestätigter Prozessabwesenheit.

Installer-NAT ist explizit **kein Bestandteil der Malware-VM**. Installer dient ausschließlich zum Aufbau der Debian-Basis.

Grenzen und E2E-Prüfung: [threat-model.md](threat-model.md), [validation-rc4.md](validation-rc4.md).
