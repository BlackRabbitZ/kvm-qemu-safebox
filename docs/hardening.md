# Hardening-Entscheidungen

## Host

SafeBox verwaltet einen Block in `/etc/libvirt/qemu.conf`:

```ini
security_driver = "apparmor"
security_default_confined = 1
security_require_confined = 1
seccomp_sandbox = 1
max_core = 0
dump_guest_core = 0
```

QEMU-Core-Dumps werden zusätzlich deaktiviert, um unnötige persistente Kopien von Prozess- bzw. Gastdaten nach Abstürzen zu vermeiden.

Vor der Änderung wird eine zeitgestempelte Sicherung erstellt. Kann libvirt danach nicht erfolgreich neu geladen werden oder meldet es kein AppArmor-Security-Model, wird die vorherige Konfiguration restauriert.

Der normale Desktop-Benutzer wird nicht automatisch Mitglied von `libvirt` oder `kvm`. Managementoperationen laufen gezielt über `sudo`.

## Domain-Oberfläche

Deaktiviert sind insbesondere:

- Host-Verzeichnisse, virtiofs, 9p
- USB- und PCI-Passthrough
- USB-Controller
- Guest Agent und Zusatzchannels
- SPICE Clipboard und Filetransfer
- SPICE OpenGL/3D
- Audio
- RNG/TPM/vsock/watchdog (nicht definiert)
- Memory Balloon
- Page Sharing/KSM (`nosharepages`)
- Nested Virtualization (`vmx`/`svm`)
- PMU und `vmport`
- Gast-Discard zur Host-Storage-Schicht (`discard='ignore'`)

Beide Domain-Templates verlangen zusätzlich ein dynamisches AppArmor-Seclabel.

## Images

Während der Installation darf der QEMU-Dienstbenutzer die Basisdisk schreiben. `seal-base` setzt anschließend:

```text
Owner: root:<QEMU-Gruppe>
Mode:  0440
```

Zusätzlich wird eine SHA-256-Prüfdatei erzeugt und vor jedem Start verifiziert. Persistent-/Disposable-Overlays müssen QCOW2 sein und exakt auf dieses Basisimage zeigen.

## Firewall-Updates

Die neue nftables-Datei wird zuerst mit `nft -c` validiert. Existiert die Guard-Tabelle bereits, werden Löschen und Neuerzeugung in **einer `nft -f`-Transaktion** durchgeführt. Eine syntaktisch fehlerhafte neue Policy darf nicht zuerst die funktionierende alte Tabelle entfernen.

## Netzwerk-Härtung

Die Bootstrap-/Installationsphase und die Runtime verwenden getrennte libvirt-Netze. Nur das Installationsnetz stellt DHCP/DNS bereit. Das Runtime-Netz besitzt weder DHCP noch einen libvirt-DNS-Server; der Gast wird vor dem Versiegeln durch `guest/harden.sh` statisch auf `10.77.0.100/24` konfiguriert.

Der Runtime-Interface-Filter referenziert direkt libvirts `clean-traffic` und übergibt `IP=10.77.0.100`. Dadurch wird keine eigene Filter-Wrapperlogik benötigt. Der Host-Guard erzwingt dieselbe Quell-IP zusätzlich auf nftables-Ebene und blockiert die Runtime-Bridge vollständig in Richtung Host.

Das getrennte Installationsnetz verwendet ausschließlich während des Bootstrap-Vorgangs `CTRL_IP_LEARNING=dhcp`. `seal-base` entfernt dieses Netz nach Ende der Installation.
