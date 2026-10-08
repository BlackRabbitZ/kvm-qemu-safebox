# SafeBox-Profile

Alle Profile behalten dieselben Sicherheitsgrenzen bei. Sie unterscheiden sich ausschließlich bei Ressourcenlimits.

| Profil | RAM | vCPU | CPU-Limit | Disk-Bandbreite | IOPS | Zweck |
|---|---:|---:|---:|---:|---:|---|
| `hardened` | 6 GiB | 4 | 70 % | 128 MiB/s | 12.000 | Standard, konservativ |
| `balanced` | 8 GiB | 4 | 85 % | 256 MiB/s | 20.000 | Alltag / Entwicklung |
| `performance` | 12 GiB | 8 | 100 % | 512 MiB/s | 40.000 | Leistungsstarker Host |

Keines der Profile aktiviert USB-/PCI-Passthrough, 3D/OpenGL, Shared Clipboard, Host-Dateifreigaben, `vhost`, Nested Virtualization oder zusätzliche Gast-Agenten.
