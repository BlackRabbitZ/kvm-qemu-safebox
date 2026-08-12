# Runtime-Attestation

Statische XML-Templates allein beweisen nicht, wie libvirt eine VM tatsächlich gestartet hat. Deshalb prüft SafeBox nach jedem Start die Live-Konfiguration und den QEMU-Prozess.

## Live-Domain-XML

Geprüft werden unter anderem:

- keine `hostdev`, `filesystem`, `channel`, `redirdev`, `shmem`, `sound`, `audio`, `rng`, `tpm`, `vsock` oder `watchdog`
- USB-Controller `model='none'`
- `nosharepages`
- Memory Balloon aus
- Nested Virtualization aus
- SPICE `listen=none`, Clipboard/Filetransfer/GL aus
- genau eine QCOW2-Systemdisk
- Installer: genau eine `safebox-install-net`-NIC mit fester MAC, Port-Isolation und `clean-traffic` + DHCP-Snooping
- Runtime: genau eine `safebox-net`-NIC mit fester MAC, Port-Isolation und `clean-traffic` + explizitem `IP=10.77.0.100`
- Offline: keine NIC
- dynamisches AppArmor-Seclabel

## Live-QEMU-Prozess

Über `/proc/<pid>` werden geprüft:

- keine UID ist 0
- `Seccomp: 2`
- AppArmor-Profil ist nicht `unconfined` und stammt aus libvirt
- separater Mount-Namespace gegenüber PID 1
- dedizierte libvirt/systemd-Cgroup

## Reaktion auf Fehler

Die Runtime-Attestation ist keine reine Diagnose. Wird sie direkt nach einem SafeBox-Start nicht bestanden, zerstört `safebox` die Domain automatisch. Disposable-Overlays werden anschließend entfernt.
