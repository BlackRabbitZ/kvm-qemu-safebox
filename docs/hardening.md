# Härtung

## QEMU / libvirt

SafeBox verlangt:

- `security_driver = "apparmor"`
- `security_default_confined = 1`
- `security_require_confined = 1`
- `seccomp_sandbox = 1`
- Core-Dumps aus
- eigener Mount-Namespace
- kein Remote-Management über libvirt TCP/TLS

Die Runtime-Attestation bestätigt zusätzlich, dass QEMU non-root, AppArmor-confined und mit Seccomp-Filter läuft.

## Domain

- q35 / x86_64
- KSM aus (`nosharepages`)
- privates anonymes Memory-Backing
- Nested Virtualization aus
- VAPIC aus
- PMU / vmport aus
- Ballooning aus
- Bochs-Display
- SPICE nur lokal/FD-basiert
- Clipboard, Filetransfer und OpenGL aus
- Packed Virtqueues aus
- QEMU-Userspace-Netzwerkbackend explizit

## Gast

`guest/harden.sh` aktiviert AppArmor, nftables und automatische Sicherheitsupdates, deaktiviert IPv6 und entfernt unnötige Host-Integrationsdienste wie `qemu-guest-agent` und `spice-vdagent`.

## Profile

`hardened`, `balanced` und `performance` dürfen ausschließlich Ressourcenlimits ändern. Die CI prüft, dass Profil-Dateien keine sicherheitsrelevanten Variablen setzen.
